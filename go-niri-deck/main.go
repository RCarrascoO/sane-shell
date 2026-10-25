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
	"sort"
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

type PhoneState struct {
	Battery    int  `json:"battery"`
	Charging   bool `json:"charging"`
	Brightness int  `json:"brightness"`
	Connected  bool `json:"connected"`
}

type AudioStream struct {
	Name   string   `json:"name"`
	IDs    []string `json:"ids"`
	Volume float64  `json:"volume"`
	Muted  bool     `json:"muted"`
}

type AudioState struct {
	MasterVol   float64       `json:"master_vol"`
	MasterMuted bool          `json:"master_muted"`
	MicMuted    bool          `json:"mic_muted"`
	DefaultSink string        `json:"default_sink"`
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
	Phone      PhoneState      `json:"phone"`
	Audio      AudioState      `json:"audio"`
	Workspaces WorkspacesState `json:"workspaces"`
	Media      MediaState      `json:"media"`
}

type ClientCommand struct {
	Cmd    string  `json:"cmd"`
	Action string  `json:"action"`
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Output string  `json:"output"`
	Idx    int     `json:"idx"`
	Volume float64 `json:"volume"`
}

// -------------------------------------------------------------
// Hub & WebSocket Management (Thread-Safe)
// -------------------------------------------------------------

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type SafeConn struct {
	conn    *websocket.Conn
	writeMu sync.Mutex
}

func (s *SafeConn) WriteMessage(messageType int, data []byte) error {
	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	return s.conn.WriteMessage(messageType, data)
}

func (s *SafeConn) Close() error {
	return s.conn.Close()
}

type Hub struct {
	clients    map[*SafeConn]bool
	broadcast  chan []byte
	register   chan *SafeConn
	unregister chan *SafeConn
	mu         sync.Mutex
}

func newHub() *Hub {
	return &Hub{
		clients:    make(map[*SafeConn]bool),
		broadcast:  make(chan []byte, 16),
		register:   make(chan *SafeConn),
		unregister: make(chan *SafeConn),
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
		return "-- GB"
	}
	defer file.Close()

	var totalKB, anonKB, shmemKB, slabKB, sreclaimKB uint64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			val, _ := strconv.ParseUint(parts[1], 10, 64)
			if strings.HasPrefix(line, "MemTotal:") {
				totalKB = val
			} else if strings.HasPrefix(line, "AnonPages:") {
				anonKB = val
			} else if strings.HasPrefix(line, "Shmem:") {
				shmemKB = val
			} else if strings.HasPrefix(line, "Slab:") {
				slabKB = val
			} else if strings.HasPrefix(line, "SReclaimable:") {
				sreclaimKB = val
			}
		}
	}

	if totalKB > 0 {
		var activeSlab uint64
		if slabKB > sreclaimKB {
			activeSlab = slabKB - sreclaimKB
		}
		usedKB := anonKB + shmemKB + activeSlab
		usedMB := usedKB / 1024
		if usedMB < 1000 {
			return fmt.Sprintf("%d MB", usedMB)
		}
		usedGB := float64(usedKB) / (1024.0 * 1024.0)
		return fmt.Sprintf("%.1f GB", usedGB)
	}
	return "-- GB"
}

func getGPUTemp() int {
	matches, _ := filepath.Glob("/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input")
	if len(matches) > 0 {
		data, err := os.ReadFile(matches[0])
		if err == nil {
			val, _ := strconv.Atoi(strings.TrimSpace(string(data)))
			if val > 1000 {
				return val / 1000
			}
			return val
		}
	}
	// fallback hwmon search
	hwMatches, _ := filepath.Glob("/sys/class/hwmon/hwmon*/temp1_input")
	for _, m := range hwMatches {
		data, err := os.ReadFile(m)
		if err == nil {
			val, _ := strconv.Atoi(strings.TrimSpace(string(data)))
			if val > 1000 {
				return val / 1000
			}
			if val > 0 {
				return val
			}
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
// Phone Integration Queries (via ADB)
// -------------------------------------------------------------

var (
	cachedPhoneState PhoneState
	lastPhoneCheck   time.Time
)

func getPhoneState() PhoneState {
	if time.Since(lastPhoneCheck) < 3*time.Second {
		return cachedPhoneState
	}
	lastPhoneCheck = time.Now()

	out, err := exec.Command("adb", "shell", "dumpsys battery | grep -E 'level|status'; settings get system screen_brightness").Output()
	if err != nil {
		cachedPhoneState = PhoneState{Connected: false}
		return cachedPhoneState
	}

	lines := strings.Split(string(out), "\n")
	state := PhoneState{Connected: true}

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "level:") {
			parts := strings.Fields(trimmed)
			if len(parts) >= 2 {
				lvl, _ := strconv.Atoi(parts[1])
				state.Battery = lvl
			}
		} else if strings.HasPrefix(trimmed, "status:") {
			parts := strings.Fields(trimmed)
			if len(parts) >= 2 {
				// status: 2 = charging, 5 = full
				st, _ := strconv.Atoi(parts[1])
				state.Charging = (st == 2 || st == 5)
			}
		} else if trimmed != "" && !strings.Contains(trimmed, ":") {
			// Screen brightness number
			br, err := strconv.Atoi(trimmed)
			if err == nil {
				state.Brightness = br
			}
		}
	}

	cachedPhoneState = state
	return state
}

// -------------------------------------------------------------
// Audio Queries (PipeWire / pw-dump / wpctl)
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

func getDefaultSink() string {
	cmd := exec.Command("wpctl", "status")
	out, err := cmd.Output()
	if err != nil {
		return "57"
	}
	lines := strings.Split(string(out), "\n")
	inSinks := false
	for _, line := range lines {
		if strings.Contains(line, "Sinks:") {
			inSinks = true
			continue
		}
		if inSinks {
			if strings.Contains(line, "Sources:") {
				break
			}
			if strings.Contains(line, "*") {
				re := regexp.MustCompile(`\*\s+(\d+)\.`)
				m := re.FindStringSubmatch(line)
				if len(m) >= 2 {
					return m[1]
				}
			}
		}
	}
	return "57"
}

// Clean and aggregate real applications using pw-dump
func getAudioStreamsClean() []AudioStream {
	out, err := exec.Command("pw-dump").Output()
	if err != nil {
		return nil
	}

	var rawItems []struct {
		ID   int `json:"id"`
		Info struct {
			Props map[string]interface{} `json:"props"`
		} `json:"info"`
	}

	if err := json.Unmarshal(out, &rawItems); err != nil {
		return nil
	}

	apps := make(map[string]*AudioStream)

	for _, item := range rawItems {
		props := item.Info.Props
		if props == nil {
			continue
		}

		mediaClass, _ := props["media.class"].(string)
		if mediaClass != "Stream/Output/Audio" {
			continue
		}

		appName, _ := props["application.name"].(string)
		if appName == "" {
			appName, _ = props["node.name"].(string)
		}

		// Filter system/virtual artifacts
		if appName == "" ||
			appName == "speech-dispatcher-dummy" ||
			appName == "Easy Effects Source" ||
			strings.HasPrefix(appName, "monitor_") ||
			strings.HasPrefix(appName, "input_") ||
			strings.Contains(appName, "Easy Effects") {
			continue
		}

		nodeID := strconv.Itoa(item.ID)

		if existing, ok := apps[appName]; ok {
			existing.IDs = append(existing.IDs, nodeID)
		} else {
			apps[appName] = &AudioStream{
				Name: appName,
				IDs:  []string{nodeID},
			}
		}
	}

	var result []AudioStream
	for _, stream := range apps {
		if len(stream.IDs) > 0 {
			vol, muted := parseWPVolume(stream.IDs[0])
			stream.Volume = vol
			stream.Muted = muted
		}
		result = append(result, *stream)
	}

	// Sort streams alphabetically for UI stability
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name < result[j].Name
	})

	return result
}

// -------------------------------------------------------------
// Workspaces (Niri IPC - Ordered Ascending)
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

	// Fix: Sort ascending by Idx so 1, 2, 3 are in natural order
	sort.Slice(state.DVI, func(i, j int) bool {
		return state.DVI[i].Idx < state.DVI[j].Idx
	})
	sort.Slice(state.HDMI, func(i, j int) bool {
		return state.HDMI[i].Idx < state.HDMI[j].Idx
	})

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
		Phone: getPhoneState(),
		Audio: AudioState{
			MasterVol:   masterVol,
			MasterMuted: masterMuted,
			MicMuted:    micMuted,
			DefaultSink: getDefaultSink(),
			Streams:     getAudioStreamsClean(),
		},
		Workspaces: getWorkspaces(),
		Media:      getMediaState(),
	}
}

// -------------------------------------------------------------
// Action Handlers
// -------------------------------------------------------------

var lastStreamsCache []AudioStream

func focusApp(target string) {
	out, err := exec.Command("niri", "msg", "-j", "windows").Output()
	if err == nil {
		var windows []struct {
			ID    int    `json:"id"`
			AppID string `json:"app_id"`
			Title string `json:"title"`
		}
		if json.Unmarshal(out, &windows) == nil {
			targetLower := strings.ToLower(target)
			for _, w := range windows {
				appLower := strings.ToLower(w.AppID)
				titleLower := strings.ToLower(w.Title)
				if strings.Contains(appLower, targetLower) || strings.Contains(titleLower, targetLower) {
					_ = exec.Command("niri", "msg", "action", "focus-window", "--id", strconv.Itoa(w.ID)).Run()
					return
				}
			}
		}
	}

	// Fallback to launching the app if no window is currently open
	switch strings.ToLower(target) {
	case "zen":
		_ = exec.Command("zen-browser").Start()
	case "vesktop":
		_ = exec.Command("vesktop").Start()
	case "kitty":
		_ = exec.Command("kitty").Start()
	case "antigravity":
		_ = exec.Command("antigravity").Start()
	}
}

func handleClientCommand(msg ClientCommand) {
	switch msg.Cmd {
	case "set-master-volume":
		volStr := fmt.Sprintf("%.2f", msg.Volume)
		_ = exec.Command("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volStr).Run()

	case "toggle-mic":
		_ = exec.Command("wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle").Run()

	case "set-default-sink":
		if msg.ID != "" {
			_ = exec.Command("wpctl", "set-default", msg.ID).Run()
		}

	case "set-stream-volume":
		volStr := fmt.Sprintf("%.2f", msg.Volume)
		if msg.Name != "" {
			// Find all IDs associated with this application name
			for _, s := range lastStreamsCache {
				if s.Name == msg.Name {
					for _, id := range s.IDs {
						_ = exec.Command("wpctl", "set-volume", id, volStr).Run()
					}
					break
				}
			}
		}

	case "focus-app":
		if msg.Action != "" {
			focusApp(msg.Action)
		}

	case "focus-workspace":
		if msg.Output != "" {
			_ = exec.Command("niri", "msg", "action", "focus-monitor", msg.Output).Run()
		}
		if msg.Idx > 0 {
			_ = exec.Command("niri", "msg", "action", "focus-workspace", strconv.Itoa(msg.Idx)).Run()
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

	case "set-phone-brightness":
		brVal := int(msg.Volume)
		if brVal < 5 {
			brVal = 5
		}
		if brVal > 255 {
			brVal = 255
		}
		_ = exec.Command("adb", "shell", "settings", "put", "system", "screen_brightness", strconv.Itoa(brVal)).Run()

	case "toggle-phone-screen":
		_ = exec.Command("adb", "shell", "input", "keyevent", "26").Run()
	}
}

// -------------------------------------------------------------
// ADB Auto-Reverse Tunnel & Immersive Policy Daemon
// -------------------------------------------------------------

func startADBWatcher(port int) {
	go func() {
		portStr := strconv.Itoa(port)
		reverseArg := fmt.Sprintf("tcp:%s", portStr)
		for {
			out, err := exec.Command("adb", "devices").Output()
			if err == nil && strings.Contains(string(out), "\tdevice") {
				// Reverse tunnel
				_ = exec.Command("adb", "reverse", reverseArg, reverseArg).Run()
				// Automatically enforce Android edge-to-edge immersive mode
				_ = exec.Command("adb", "shell", "settings put global policy_control immersive.full=*").Run()
				// Ensure screen stays on while connected to USB
				_ = exec.Command("adb", "shell", "settings put global stay_on_while_plugged_in 7").Run()
			}
			time.Sleep(6 * time.Second)
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

	log.Printf("🚀 Iniciando sane-deck v2 (Material Design 3) en :%d", *port)

	if !*noADB {
		startADBWatcher(*port)
		log.Printf("🔌 Watcher ADB activo: puerto %d + modo inmersivo activado", *port)
	}

	hub := newHub()
	go hub.run()

	// Broadcast state every 400ms to all connected clients
	go func() {
		ticker := time.NewTicker(400 * time.Millisecond)
		defer ticker.Stop()
		for range ticker.C {
			if len(hub.clients) == 0 {
				continue
			}
			state := collectFullState()
			lastStreamsCache = state.Audio.Streams
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
		safe := &SafeConn{conn: conn}
		hub.register <- safe

		// Initial state
		initialState := collectFullState()
		lastStreamsCache = initialState.Audio.Streams
		if payload, err := json.Marshal(initialState); err == nil {
			_ = safe.WriteMessage(websocket.TextMessage, payload)
		}

		go func() {
			defer func() {
				hub.unregister <- safe
			}()
			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					break
				}
				var cmd ClientCommand
				if jsonErr := json.Unmarshal(message, &cmd); jsonErr == nil {
					handleClientCommand(cmd)
					// Quick refresh
					quickState := collectFullState()
					lastStreamsCache = quickState.Audio.Streams
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
