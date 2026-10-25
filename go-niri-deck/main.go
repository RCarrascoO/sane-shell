package main

import (
	"bufio"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

//go:embed web/*
var webFiles embed.FS

// -------------------------------------------------------------
// Models
// -------------------------------------------------------------

type TelemetryState struct {
	RAM        string `json:"ram"`
	CPU        int    `json:"cpu"`
	GPU        int    `json:"gpu"`
	FocusedApp string `json:"focused_app"`
}

type AudioStream struct {
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Volume float64 `json:"volume"`
	Muted  bool    `json:"muted"`
}

type AudioState struct {
	MasterVol   float64       `json:"master_vol"`
	MasterMuted bool          `json:"master_muted"`
	MicMuted    bool          `json:"mic_muted"`
	Streams     []AudioStream `json:"streams"`
}

type WorkspaceItem struct {
	ID        int    `json:"id"`
	Idx       int    `json:"idx"`
	Output    string `json:"output"`
	IsActive  bool   `json:"is_active"`
	IsFocused bool   `json:"is_focused"`
}

type WorkspacesState struct {
	DVI  []WorkspaceItem `json:"dvi"`
	HDMI []WorkspaceItem `json:"hdmi"`
}

type MediaState struct {
	Title  string `json:"title"`
	Status string `json:"status"`
}

type FullState struct {
	Telemetry  TelemetryState  `json:"telemetry"`
	Audio      AudioState      `json:"audio"`
	Workspaces WorkspacesState `json:"workspaces"`
	Media      MediaState      `json:"media"`
}

type ClientCommand struct {
	Cmd    string  `json:"cmd"`
	Action string  `json:"action"`
	ID     string  `json:"id"`
	Volume float64 `json:"volume"`
}

// -------------------------------------------------------------
// Hub & WebSocket Management
// -------------------------------------------------------------

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Hub struct {
	clients    map[*websocket.Conn]bool
	broadcast  chan []byte
	register   chan *websocket.Conn
	unregister chan *websocket.Conn
	mu         sync.Mutex
}

func newHub() *Hub {
	return &Hub{
		clients:    make(map[*websocket.Conn]bool),
		broadcast:  make(chan []byte),
		register:   make(chan *websocket.Conn),
		unregister: make(chan *websocket.Conn),
	}
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				client.Close()
			}
			h.mu.Unlock()
		case message := <-h.broadcast:
			h.mu.Lock()
			for client := range h.clients {
				err := client.WriteMessage(websocket.TextMessage, message)
				if err != nil {
					client.Close()
					delete(h.clients, client)
				}
			}
			h.mu.Unlock()
		}
	}
}

// -------------------------------------------------------------
// System Queries
// -------------------------------------------------------------

var (
	lastCPUTotal uint64
	lastCPUIdle  uint64
)

func getCPUUsage() int {
	file, err := os.Open("/proc/stat")
	if err != nil {
		return 0
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	if scanner.Scan() {
		line := scanner.Text()
		fields := strings.Fields(line)
		if len(fields) >= 5 && fields[0] == "cpu" {
			var total, idle uint64
			for i := 1; i < len(fields); i++ {
				val, _ := strconv.ParseUint(fields[i], 10, 64)
				total += val
				if i == 4 { // idle
					idle = val
				}
			}

			diffTotal := total - lastCPUTotal
			diffIdle := idle - lastCPUIdle

			lastCPUTotal = total
			lastCPUIdle = idle

			if diffTotal > 0 {
				usage := 100 - (diffIdle * 100 / diffTotal)
				return int(usage)
			}
		}
	}
	return 0
}

func getRAMUsage() string {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		return "-- MB"
	}
	defer file.Close()

	var totalKB, availKB uint64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "MemTotal:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				totalKB, _ = strconv.ParseUint(parts[1], 10, 64)
			}
		} else if strings.HasPrefix(line, "MemAvailable:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				availKB, _ = strconv.ParseUint(parts[1], 10, 64)
			}
		}
		if totalKB > 0 && availKB > 0 {
			break
		}
	}

	if totalKB > 0 && availKB > 0 && totalKB >= availKB {
		usedMB := (totalKB - availKB) / 1024
		return fmt.Sprintf("%d MB", usedMB)
	}
	return "-- MB"
}

func getGPUTemp() int {
	data, err := os.ReadFile("/sys/class/hwmon/hwmon1/temp1_input")
	if err != nil {
		// Try fallback card0 path
		matches, _ := filepath.Glob("/sys/class/drm/card0/device/hwmon/hwmon*/temp1_input")
		if len(matches) > 0 {
			data, err = os.ReadFile(matches[0])
		}
	}
	if err == nil {
		valStr := strings.TrimSpace(string(data))
		val, parseErr := strconv.Atoi(valStr)
		if parseErr == nil {
			return val / 1000
		}
	}
	return 0
}

func getFocusedApp() string {
	cmd := exec.Command("niri", "msg", "--json", "focused-window")
	out, err := cmd.Output()
	if err != nil {
		return "Niri"
	}

	var data struct {
		Title string `json:"title"`
		AppID string `json:"app_id"`
	}
	if jsonErr := json.Unmarshal(out, &data); jsonErr == nil {
		if data.Title != "" {
			return data.Title
		}
		if data.AppID != "" {
			return data.AppID
		}
	}
	return "Niri"
}

// -------------------------------------------------------------
// Audio Queries (wpctl)
// -------------------------------------------------------------

func parseWPVolume(target string) (float64, bool) {
	cmd := exec.Command("wpctl", "get-volume", target)
	out, err := cmd.Output()
	if err != nil {
		return 0.0, false
	}
	str := strings.TrimSpace(string(out))
	isMuted := strings.Contains(str, "[MUTED]")

	re := regexp.MustCompile(`Volume:\s+([0-9.]+)`)
	matches := re.FindStringSubmatch(str)
	if len(matches) >= 2 {
		val, _ := strconv.ParseFloat(matches[1], 64)
		return val, isMuted
	}
	return 0.0, isMuted
}

func getAudioStreams() []AudioStream {
	cmd := exec.Command("wpctl", "status")
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	var streams []AudioStream
	lines := strings.Split(string(out), "\n")
	inStreams := false

	streamRegex := regexp.MustCompile(`^\s+(\d+)\.\s+([^\s].*)$`)

	for _, line := range lines {
		if strings.Contains(line, "Streams:") {
			inStreams = true
			continue
		}
		if inStreams {
			if strings.TrimSpace(line) == "" || (!strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") && !strings.Contains(line, "├") && !strings.Contains(line, "└")) {
				inStreams = false
				break
			}
			// Skip sub-routing lines (like "155. output_FR > ...")
			if strings.Contains(line, ">") {
				continue
			}

			matches := streamRegex.FindStringSubmatch(line)
			if len(matches) >= 3 {
				id := matches[1]
				name := strings.TrimSpace(matches[2])
				// Clean name
				if idx := strings.Index(name, "["); idx != -1 {
					name = strings.TrimSpace(name[:idx])
				}
				if name == "speech-dispatcher-dummy" {
					continue
				}

				vol, muted := parseWPVolume(id)
				streams = append(streams, AudioStream{
					ID:     id,
					Name:   name,
					Volume: vol,
					Muted:  muted,
				})
			}
		}
	}
	return streams
}

// -------------------------------------------------------------
// Workspaces (Niri IPC)
// -------------------------------------------------------------

func getWorkspaces() WorkspacesState {
	cmd := exec.Command("niri", "msg", "--json", "workspaces")
	out, err := cmd.Output()
	var state WorkspacesState
	if err != nil {
		return state
	}

	var rawList []struct {
		ID        int    `json:"id"`
		Idx       int    `json:"idx"`
		Output    string `json:"output"`
		IsActive  bool   `json:"is_active"`
		IsFocused bool   `json:"is_focused"`
	}

	if err := json.Unmarshal(out, &rawList); err != nil {
		return state
	}

	for _, w := range rawList {
		item := WorkspaceItem{
			ID:        w.ID,
			Idx:       w.Idx,
			Output:    w.Output,
			IsActive:  w.IsActive,
			IsFocused: w.IsFocused,
		}
		if strings.Contains(w.Output, "DVI") {
			state.DVI = append(state.DVI, item)
		} else if strings.Contains(w.Output, "HDMI") {
			state.HDMI = append(state.HDMI, item)
		}
	}
	return state
}

// -------------------------------------------------------------
// Media State (playerctl)
// -------------------------------------------------------------

func getMediaState() MediaState {
	cmdStatus := exec.Command("playerctl", "status")
	outStatus, _ := cmdStatus.Output()
	status := strings.TrimSpace(string(outStatus))

	var title string
	if status != "" {
		cmdMeta := exec.Command("playerctl", "metadata", "--format", "{{title}} - {{artist}}")
		outMeta, _ := cmdMeta.Output()
		title = strings.TrimSpace(string(outMeta))
		if strings.HasSuffix(title, " - ") {
			title = strings.TrimSuffix(title, " - ")
		}
	}

	return MediaState{
		Title:  title,
		Status: status,
	}
}

// -------------------------------------------------------------
// Full State Aggregator
// -------------------------------------------------------------

func collectFullState() FullState {
	masterVol, masterMuted := parseWPVolume("@DEFAULT_AUDIO_SINK@")
	_, micMuted := parseWPVolume("@DEFAULT_AUDIO_SOURCE@")

	return FullState{
		Telemetry: TelemetryState{
			RAM:        getRAMUsage(),
			CPU:        getCPUUsage(),
			GPU:        getGPUTemp(),
			FocusedApp: getFocusedApp(),
		},
		Audio: AudioState{
			MasterVol:   masterVol,
			MasterMuted: masterMuted,
			MicMuted:    micMuted,
			Streams:     getAudioStreams(),
		},
		Workspaces: getWorkspaces(),
		Media:      getMediaState(),
	}
}

// -------------------------------------------------------------
// Action Handlers
// -------------------------------------------------------------

func handleClientCommand(msg ClientCommand) {
	switch msg.Cmd {
	case "set-master-volume":
		volStr := fmt.Sprintf("%.2f", msg.Volume)
		_ = exec.Command("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volStr).Run()
	case "toggle-mic":
		_ = exec.Command("wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle").Run()
	case "set-stream-volume":
		if msg.ID != "" {
			volStr := fmt.Sprintf("%.2f", msg.Volume)
			_ = exec.Command("wpctl", "set-volume", msg.ID, volStr).Run()
		}
	case "niri-action":
		if msg.Action != "" {
			parts := strings.Fields(msg.Action)
			args := append([]string{"msg", "action"}, parts...)
			_ = exec.Command("niri", args...).Run()
		}
	case "media-action":
		if msg.Action != "" {
			_ = exec.Command("playerctl", msg.Action).Run()
		}
	}
}

// -------------------------------------------------------------
// ADB Auto-Reverse Tunnel Daemon
// -------------------------------------------------------------

func startADBWatcher(port int) {
	go func() {
		portStr := strconv.Itoa(port)
		reverseArg := fmt.Sprintf("tcp:%s", portStr)
		for {
			out, err := exec.Command("adb", "devices").Output()
			if err == nil && strings.Contains(string(out), "\tdevice") {
				// Phone is connected with ADB authorized, setup reverse tunnel
				_ = exec.Command("adb", "reverse", reverseArg, reverseArg).Run()
			}
			time.Sleep(5 * time.Second)
		}
	}()
}

// -------------------------------------------------------------
// Main Application
// -------------------------------------------------------------

func main() {
	port := flag.Int("port", 8080, "Port to run niri-deck on")
	noADB := flag.Bool("no-adb", false, "Disable automatic ADB reverse tunnel")
	flag.Parse()

	log.Printf("🚀 Iniciando sane-deck (Material Design 3) en :%d", *port)

	if !*noADB {
		startADBWatcher(*port)
		log.Printf("🔌 Watcher ADB activo: conectará automáticamente el puerto %d vía USB-C", *port)
	}

	hub := newHub()
	go hub.run()

	// Ticker to broadcast state every 400ms to all connected clients
	go func() {
		ticker := time.NewTicker(400 * time.Millisecond)
		defer ticker.Stop()
		for range ticker.C {
			if len(hub.clients) == 0 {
				continue
			}
			state := collectFullState()
			payload, err := json.Marshal(state)
			if err == nil {
				hub.broadcast <- payload
			}
		}
	}()

	// Sub-filesystem for embedded web static files
	webSubFS, err := fs.Sub(webFiles, "web")
	if err != nil {
		log.Fatalf("Error inicializando embedded web assets: %v", err)
	}

	http.Handle("/", http.FileServer(http.FS(webSubFS)))

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("Error upgrading websocket: %v", err)
			return
		}
		hub.register <- conn

		// Send initial state immediately
		initialState := collectFullState()
		if payload, err := json.Marshal(initialState); err == nil {
			_ = conn.WriteMessage(websocket.TextMessage, payload)
		}

		go func() {
			defer func() {
				hub.unregister <- conn
			}()
			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					break
				}
				var cmd ClientCommand
				if jsonErr := json.Unmarshal(message, &cmd); jsonErr == nil {
					handleClientCommand(cmd)
					// Trigger rapid refresh
					quickState := collectFullState()
					if quickPayload, err := json.Marshal(quickState); err == nil {
						hub.broadcast <- quickPayload
					}
				}
			}
		}()
	})

	addr := fmt.Sprintf("0.0.0.0:%d", *port)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Error en servidor HTTP: %v", err)
	}
}
