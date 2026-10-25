package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	cacheFile      = "/tmp/antigravity_quota_cache.json"
	stateCacheFile = "/tmp/antigravity_ls_state.json"
	cacheTTL       = 15 * time.Second
)

func getHomeDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "/home/sane"
	}
	return home
}

func getGeminiWebFile() string {
	return filepath.Join(getHomeDir(), ".cache/sane-shell/gemini_web_quota.json")
}

// -------------------------------------------------------------
// Time formatting
// -------------------------------------------------------------

func formatRelativeTime(isoStr string) string {
	if isoStr == "" {
		return ""
	}
	// Try parsing ISO8601 / RFC3339
	t, err := time.Parse(time.RFC3339Nano, isoStr)
	if err != nil {
		t, err = time.Parse(time.RFC3339, isoStr)
		if err != nil {
			return isoStr
		}
	}

	diff := time.Until(t)
	totalSec := int(diff.Seconds())
	if totalSec <= 0 {
		return "Ahora"
	}

	days := totalSec / 86400
	rem := totalSec % 86400
	hours := rem / 3600
	rem = rem % 3600
	minutes := rem / 60

	if days > 0 {
		return fmt.Sprintf("%dd %dh", days, hours)
	} else if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}

// -------------------------------------------------------------
// Live Task State (DB)
// -------------------------------------------------------------

type dbRow struct {
	NotFullyIdle int    `json:"not_fully_idle"`
	Title        string `json:"title"`
	Status       string `json:"status"`
}

func getLiveTaskState() (bool, string, string) {
	dbPath := filepath.Join(getHomeDir(), ".gemini/antigravity/conversation_summaries.db")
	if _, err := os.Stat(dbPath); err != nil {
		return false, "", ""
	}

	cmd := exec.Command("sqlite3", "-readonly", "-json", dbPath,
		"SELECT not_fully_idle, title, status FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1;")
	out, err := cmd.Output()
	if err != nil {
		return false, "", ""
	}

	var rows []dbRow
	if err := json.Unmarshal(out, &rows); err != nil || len(rows) == 0 {
		return false, "", ""
	}

	busy := rows[0].NotFullyIdle == 1 || strings.Contains(rows[0].Status, "RUNNING")
	return busy, rows[0].Title, rows[0].Status
}

// -------------------------------------------------------------
// Language Server Connection
// -------------------------------------------------------------

type lsState struct {
	Pid  int    `json:"pid"`
	Csrf string `json:"csrf"`
	Port int    `json:"port"`
}

func getLSConnection() (string, int) {
	// 1. Check cached state
	if data, err := os.ReadFile(stateCacheFile); err == nil {
		var s lsState
		if json.Unmarshal(data, &s) == nil && s.Pid > 0 {
			if _, err := os.Stat(fmt.Sprintf("/proc/%d", s.Pid)); err == nil && s.Csrf != "" && s.Port > 0 {
				return s.Csrf, s.Port
			}
		}
	}

	// 2. Scan /proc
	var targetPid int
	var csrfToken string

	matches, err := filepath.Glob("/proc/[0-9]*/cmdline")
	if err == nil {
		for _, p := range matches {
			content, err := os.ReadFile(p)
			if err != nil {
				continue
			}
			parts := bytes.Split(content, []byte{0})
			hasLS := false
			for _, part := range parts {
				if bytes.Contains(part, []byte("language_server")) {
					hasLS = true
					break
				}
			}
			if !hasLS {
				continue
			}

			// Extract pid
			seg := strings.Split(p, "/")
			if len(seg) >= 3 {
				pid, err := strconv.Atoi(seg[2])
				if err == nil {
					for i, part := range parts {
						if string(part) == "--csrf_token" && i+1 < len(parts) {
							targetPid = pid
							csrfToken = string(parts[i+1])
							break
						}
					}
				}
			}
			if targetPid > 0 && csrfToken != "" {
				break
			}
		}
	}

	if targetPid == 0 || csrfToken == "" {
		return "", 0
	}

	// 3. Find port in log
	var port int
	logPath := filepath.Join(getHomeDir(), ".config/Antigravity/logs/language_server.log")
	if logData, err := os.ReadFile(logPath); err == nil {
		re := regexp.MustCompile(`listening on random port at (\d+) for HTTP`)
		lines := strings.Split(string(logData), "\n")
		for _, line := range lines {
			if strings.Contains(line, "for HTTP") && strings.Contains(line, "listening on random port at") {
				m := re.FindStringSubmatch(line)
				if len(m) > 1 {
					if p, err := strconv.Atoi(m[1]); err == nil {
						port = p
					}
				}
			}
		}
	}

	if targetPid > 0 && csrfToken != "" && port > 0 {
		s := lsState{Pid: targetPid, Csrf: csrfToken, Port: port}
		if b, err := json.Marshal(s); err == nil {
			_ = os.WriteFile(stateCacheFile, b, 0644)
		}
	}

	return csrfToken, port
}

// -------------------------------------------------------------
// Fetch Quota
// -------------------------------------------------------------

type quotaCache struct {
	Timestamp float64         `json:"timestamp"`
	Data      json.RawMessage `json:"data"`
}

func fetchQuota() []byte {
	now := float64(time.Now().Unix())
	if data, err := os.ReadFile(cacheFile); err == nil {
		var c quotaCache
		if json.Unmarshal(data, &c) == nil {
			if now-c.Timestamp < cacheTTL.Seconds() {
				return c.Data
			}
		}
	}

	csrf, port := getLSConnection()
	if csrf == "" || port == 0 {
		return nil
	}

	url := fmt.Sprintf("http://127.0.0.1:%d/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary", port)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer([]byte("{}")))
	if err != nil {
		return nil
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-codeium-csrf-token", csrf)

	client := &http.Client{Timeout: 1500 * time.Millisecond}
	resp, err := client.Do(req)
	if err != nil {
		_ = os.Remove(stateCacheFile)
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		_ = os.Remove(stateCacheFile)
		return nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}

	c := quotaCache{
		Timestamp: now,
		Data:      body,
	}
	if cb, err := json.Marshal(c); err == nil {
		_ = os.WriteFile(cacheFile, cb, 0644)
	}

	return body
}

// -------------------------------------------------------------
// Gemini Web Quota
// -------------------------------------------------------------

func getGeminiWebQuota() map[string]any {
	targetFile := getGeminiWebFile()
	data, err := os.ReadFile(targetFile)
	if err != nil {
		// Fallback to inir path if not yet written
		fallback := filepath.Join(getHomeDir(), ".config/quickshell/inir/scripts/gemini_web_quota.json")
		data, err = os.ReadFile(fallback)
		if err != nil {
			return nil
		}
	}

	var parsed map[string]any
	if err := json.Unmarshal(data, &parsed); err != nil {
		return nil
	}

	updatedAt, ok := parsed["_updatedAt"].(float64)
	if !ok {
		return nil
	}

	if float64(time.Now().Unix())-updatedAt > 48*3600 {
		return nil
	}

	return parsed
}

// -------------------------------------------------------------
// Subcommand: Quota
// -------------------------------------------------------------

func runQuota() {
	busy, currentTask, _ := getLiveTaskState()
	quotaRawBytes := fetchQuota()

	type BucketOut struct {
		BucketId     string  `json:"bucketId"`
		DisplayName  string  `json:"displayName"`
		Percentage   int     `json:"percentage"`
		Fraction     float64 `json:"fraction"`
		ResetIn      string  `json:"resetIn"`
		RawResetTime string  `json:"rawResetTime"`
	}

	type GroupOut struct {
		DisplayName string      `json:"displayName"`
		Description string      `json:"description"`
		Buckets     []BucketOut `json:"buckets"`
	}

	type Output struct {
		Available         bool       `json:"available"`
		Running           bool       `json:"running"`
		Busy              bool       `json:"busy"`
		CurrentTask       string     `json:"currentTask"`
		PrimaryPercentage int        `json:"primaryPercentage"`
		PrimaryFraction   float64    `json:"primaryFraction"`
		PrimaryLabel      string     `json:"primaryLabel"`
		PrimaryResetIn    string     `json:"primaryResetIn"`
		Groups            []GroupOut `json:"groups"`
	}

	out := Output{
		Available:         quotaRawBytes != nil,
		Running:           quotaRawBytes != nil,
		Busy:              busy,
		CurrentTask:       currentTask,
		PrimaryPercentage: 100,
		PrimaryFraction:   1.0,
		PrimaryLabel:      "5h Limit",
		PrimaryResetIn:    "",
		Groups:            make([]GroupOut, 0),
	}

	if quotaRawBytes != nil {
		var lsResponse struct {
			Response struct {
				Groups []struct {
					DisplayName string `json:"displayName"`
					Description string `json:"description"`
					Buckets     []struct {
						BucketId          string  `json:"bucketId"`
						DisplayName       string  `json:"displayName"`
						RemainingFraction float64 `json:"remainingFraction"`
						ResetTime         string  `json:"resetTime"`
					} `json:"buckets"`
				} `json:"groups"`
			} `json:"response"`
		}

		if err := json.Unmarshal(quotaRawBytes, &lsResponse); err == nil {
			for _, g := range lsResponse.Response.Groups {
				gOut := GroupOut{
					DisplayName: g.DisplayName,
					Description: g.Description,
					Buckets:     make([]BucketOut, 0),
				}
				for _, b := range g.Buckets {
					frac := b.RemainingFraction
					pct := int(frac*100.0 + 0.5)
					resetRel := formatRelativeTime(b.ResetTime)
					bOut := BucketOut{
						BucketId:     b.BucketId,
						DisplayName:  b.DisplayName,
						Percentage:   pct,
						Fraction:     frac,
						ResetIn:      resetRel,
						RawResetTime: b.ResetTime,
					}
					gOut.Buckets = append(gOut.Buckets, bOut)

					if b.BucketId == "gemini-5h" {
						out.PrimaryPercentage = pct
						out.PrimaryFraction = frac
						out.PrimaryLabel = "5h Limit"
						out.PrimaryResetIn = resetRel
					}
				}
				out.Groups = append(out.Groups, gOut)
			}
		}
	}

	// Web quota
	webData := getGeminiWebQuota()
	if webData != nil {
		out.Available = true
		tierLabel, _ := webData["tier"].(string)
		if tierLabel == "" {
			tierLabel = "Gemini Web"
		}
		modelLabel, _ := webData["model"].(string)
		desc := fmt.Sprintf("Zen Browser (%s)", tierLabel)
		if modelLabel != "" {
			desc = fmt.Sprintf("Zen Browser (%s - %s)", tierLabel, modelLabel)
		}

		var webBuckets []BucketOut
		if rawBuckets, ok := webData["buckets"].([]any); ok && len(rawBuckets) > 0 {
			for _, item := range rawBuckets {
				if bm, ok := item.(map[string]any); ok {
					bId, _ := bm["bucketId"].(string)
					bName, _ := bm["displayName"].(string)
					bReset, _ := bm["resetIn"].(string)
					bRawReset, _ := bm["rawResetTime"].(string)
					pct := 100
					if p, ok := bm["percentage"].(float64); ok {
						pct = int(p)
					}
					frac := 1.0
					if f, ok := bm["fraction"].(float64); ok {
						frac = f
					}
					webBuckets = append(webBuckets, BucketOut{
						BucketId:     bId,
						DisplayName:  bName,
						Percentage:   pct,
						Fraction:     frac,
						ResetIn:      bReset,
						RawResetTime: bRawReset,
					})
				}
			}
		} else {
			pct := 100
			if p, ok := webData["percentage"].(float64); ok {
				pct = int(p)
			}
			frac := 1.0
			if f, ok := webData["fraction"].(float64); ok {
				frac = f
			}
			resetIn, _ := webData["resetIn"].(string)
			webBuckets = append(webBuckets, BucketOut{
				BucketId:     "gemini-web-budget",
				DisplayName:  "Presupuesto de Cómputo",
				Percentage:   pct,
				Fraction:     frac,
				ResetIn:      resetIn,
				RawResetTime: "",
			})
		}

		out.Groups = append(out.Groups, GroupOut{
			DisplayName: "Gemini Web (Zen)",
			Description: desc,
			Buckets:     webBuckets,
		})
	}

	jsonBytes, _ := json.Marshal(out)
	fmt.Println(string(jsonBytes))
}

// -------------------------------------------------------------
// Subcommand: Bridge (Native Messaging)
// -------------------------------------------------------------

func runBridge() {
	var length uint32
	err := binary.Read(os.Stdin, binary.LittleEndian, &length)
	if err != nil || length == 0 {
		sendBridgeResponse(map[string]any{"status": "error", "message": "No data or failed to read length"})
		return
	}

	buf := make([]byte, length)
	_, err = io.ReadFull(os.Stdin, buf)
	if err != nil {
		sendBridgeResponse(map[string]any{"status": "error", "message": "Failed to read full message payload"})
		return
	}

	var data map[string]any
	if err := json.Unmarshal(buf, &data); err != nil {
		sendBridgeResponse(map[string]any{"status": "error", "message": err.Error()})
		return
	}

	data["_updatedAt"] = float64(time.Now().Unix())

	targetFile := getGeminiWebFile()
	_ = os.MkdirAll(filepath.Dir(targetFile), 0755)

	tmpTarget := targetFile + ".tmp"
	fileBytes, err := json.MarshalIndent(data, "", "  ")
	if err == nil {
		if err := os.WriteFile(tmpTarget, fileBytes, 0644); err == nil {
			_ = os.Rename(tmpTarget, targetFile)
		}
	}

	sendBridgeResponse(map[string]any{"status": "ok", "saved": true})
}

func sendBridgeResponse(resp map[string]any) {
	bytesResp, _ := json.Marshal(resp)
	length := uint32(len(bytesResp))
	_ = binary.Write(os.Stdout, binary.LittleEndian, length)
	_, _ = os.Stdout.Write(bytesResp)
}

// -------------------------------------------------------------
// Subcommand: Focus
// -------------------------------------------------------------

func runFocus(target string) {
	out, err := exec.Command("niri", "msg", "-j", "windows").Output()
	if err == nil {
		var windows []struct {
			ID    int    `json:"id"`
			AppID string `json:"app_id"`
		}
		if json.Unmarshal(out, &windows) == nil {
			for _, w := range windows {
				if target == "zen" && w.AppID == "zen" {
					_ = exec.Command("niri", "msg", "action", "focus-window", "--id", strconv.Itoa(w.ID)).Run()
					return
				} else if target != "zen" && w.AppID == "antigravity" {
					_ = exec.Command("niri", "msg", "action", "focus-window", "--id", strconv.Itoa(w.ID)).Run()
					return
				}
			}
		}
	}

	if target == "zen" {
		cmd := exec.Command("gtk-launch", "zen")
		_ = cmd.Start()
	} else {
		cmd := exec.Command("/opt/Antigravity/antigravity")
		_ = cmd.Start()
	}
}

// -------------------------------------------------------------
// Subcommand: Apps (Desktop Entries)
// -------------------------------------------------------------

type AppEntry struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	GenericName string `json:"genericName"`
	Comment     string `json:"comment"`
	Icon        string `json:"icon"`
	Exec        string `json:"exec"`
	Categories  string `json:"categories"`
	Terminal    bool   `json:"terminal"`
}

func runApps() {
	dirs := []string{
		filepath.Join(getHomeDir(), ".local/share/applications"),
		"/usr/local/share/applications",
		"/usr/share/applications",
	}

	seen := make(map[string]bool)
	var apps []AppEntry
	reField := regexp.MustCompile(`%[a-zA-Z]`)

	for _, dir := range dirs {
		files, err := os.ReadDir(dir)
		if err != nil {
			continue
		}

		for _, f := range files {
			if f.IsDir() || !strings.HasSuffix(f.Name(), ".desktop") {
				continue
			}

			id := f.Name()
			if seen[id] {
				continue
			}
			seen[id] = true

			fullPath := filepath.Join(dir, f.Name())
			data, err := os.ReadFile(fullPath)
			if err != nil {
				continue
			}

			lines := strings.Split(string(data), "\n")
			inEntry := false
			entry := AppEntry{ID: id}
			noDisplay := false
			isApp := false

			for _, rawLine := range lines {
				line := strings.TrimSpace(rawLine)
				if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
					inEntry = (line == "[Desktop Entry]")
					continue
				}
				if !inEntry || strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
					continue
				}

				parts := strings.SplitN(line, "=", 2)
				key := strings.TrimSpace(parts[0])
				val := strings.TrimSpace(parts[1])

				switch key {
				case "Type":
					if val == "Application" {
						isApp = true
					}
				case "NoDisplay":
					if strings.EqualFold(val, "true") {
						noDisplay = true
					}
				case "Hidden":
					if strings.EqualFold(val, "true") {
						noDisplay = true
					}
				case "Name":
					if entry.Name == "" {
						entry.Name = val
					}
				case "GenericName":
					if entry.GenericName == "" {
						entry.GenericName = val
					}
				case "Comment":
					if entry.Comment == "" {
						entry.Comment = val
					}
				case "Icon":
					if entry.Icon == "" {
						entry.Icon = val
					}
				case "Exec":
					if entry.Exec == "" {
						entry.Exec = strings.TrimSpace(reField.ReplaceAllString(val, ""))
					}
				case "Categories":
					if entry.Categories == "" {
						entry.Categories = val
					}
				case "Terminal":
					if strings.EqualFold(val, "true") {
						entry.Terminal = true
					}
				}
			}

			if isApp && !noDisplay && entry.Name != "" && entry.Exec != "" {
				apps = append(apps, entry)
			}
		}
	}

	sort.Slice(apps, func(i, j int) bool {
		return strings.ToLower(apps[i].Name) < strings.ToLower(apps[j].Name)
	})

	bytesOut, _ := json.Marshal(apps)
	os.Stdout.Write(bytesOut)
	fmt.Println()
}

// -------------------------------------------------------------
// Subcommand: Toggle Popup
// -------------------------------------------------------------

func runTogglePopup(name string) {
	if name == "" {
		name = "appdrawer"
	}
	_ = exec.Command("qs", "ipc", "-c", "sane-shell", "call", "shell", "togglePopup", name).Run()
}

// -------------------------------------------------------------
// Main entry
// -------------------------------------------------------------

func main() {
	cmd := "quota"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	} else if strings.HasSuffix(os.Args[0], "bridge") {
		cmd = "bridge"
	}

	switch cmd {
	case "bridge":
		runBridge()
	case "focus":
		target := "antigravity"
		if len(os.Args) > 2 && os.Args[2] == "zen" {
			target = "zen"
		}
		runFocus(target)
	case "focus-zen":
		runFocus("zen")
	case "apps":
		runApps()
	case "toggle-popup":
		name := "appdrawer"
		if len(os.Args) > 2 {
			name = os.Args[2]
		}
		runTogglePopup(name)
	case "toggle-drawer":
		runTogglePopup("appdrawer")
	case "quota":
		fallthrough
	default:
		runQuota()
	}
}
