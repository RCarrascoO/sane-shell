pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Hardware stats
    property int cpuPercent: 0
    property alias cpuUsage: root.cpuPercent

    property int ramPercent: 0
    property string ramUsedGB: "0.0"
    property alias ramUsedGb: root.ramUsedGB

    property int gpuTemp: 40
    property bool deckActive: false

    // Audio & Display
    property int volume: 50
    property bool isMuted: false
    property int brightness: 100
    property bool _audioInitialized: false

    // Network
    property string networkType: "ethernet" // "ethernet" | "wifi" | "disconnected"
    property bool ethernetConnected: true
    property bool wifiConnected: false
    property bool wifiEnabled: true
    property string wifiSsid: ""

    // Bluetooth
    property bool bluetoothEnabled: false
    property bool bluetoothConnected: false
    property string bluetoothDevice: ""

    // Night Light
    property bool nightLightActive: false
    property int nightLightTemp: 4000

    // OSD State
    property bool osdVisible: false
    property string osdType: "volume" // "volume" | "brightness" | "media"
    property int osdValue: 50
    property string osdIcon: "volume_up"
    property string osdTitle: ""
    property string osdSubtitle: ""
    property string osdArtUrl: ""

    property real _prevIdle: 0
    property real _prevTotal: 0
    property string _prevMediaTitle: ""

    Timer {
        id: osdHideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.osdVisible = false;
        }
    }

    function triggerOsd(type, value, icon, durationMs) {
        osdType = type;
        osdValue = Math.round(value);
        osdIcon = icon;
        osdVisible = true;
        osdHideTimer.interval = durationMs ? durationMs : 2000;
        osdHideTimer.restart();
    }

    function setVolume(pct) {
        const val = Math.max(0, Math.min(100, pct));
        volActionProcess.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", (val / 100.0).toFixed(2)];
        volActionProcess.running = true;
        root.volume = val;
        triggerOsd("volume", val, isMuted ? "volume_off" : (val === 0 ? "volume_mute" : (val < 50 ? "volume_down" : "volume_up")));
    }

    function changeVolume(delta) {
        const val = Math.max(0, Math.min(100, root.volume + delta));
        setVolume(val);
    }

    function toggleMute() {
        volActionProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volActionProcess.running = true;
        root.isMuted = !root.isMuted;
        triggerOsd("volume", root.volume, root.isMuted ? "volume_off" : (root.volume === 0 ? "volume_mute" : (root.volume < 50 ? "volume_down" : "volume_up")));
    }

    function setBrightness(pct) {
        const val = Math.max(0, Math.min(100, pct));
        root.brightness = val;
        brightActionProcess.command = ["brightnessctl", "set", `${val}%`];
        brightActionProcess.running = true;
        triggerOsd("brightness", val, val < 30 ? "brightness_low" : (val < 70 ? "brightness_medium" : "brightness_high"));
    }

    function changeBrightness(delta) {
        const val = Math.max(5, Math.min(100, root.brightness + delta));
        setBrightness(val);
    }

    function setNightLightTemp(temp) {
        const clamped = Math.max(2500, Math.min(6500, Math.round(temp / 100) * 100));
        root.nightLightTemp = clamped;
        Quickshell.execDetached(["sh", "-c", `printf '%d\\n' ${clamped} > "$HOME/.cache/sane-shell-nightlight.txt"`]);
        if (root.nightLightActive) {
            Quickshell.execDetached(["sh", "-c", `pkill -x wlsunset; wlsunset -t ${clamped} -T 6501 &`]);
        }
    }

    function toggleWifi() {
        const newState = root.wifiEnabled ? "off" : "on";
        Quickshell.execDetached(["nmcli", "radio", "wifi", newState]);
        root.wifiEnabled = !root.wifiEnabled;
        refreshTimer.restart();
    }

    function toggleBluetooth() {
        if (root.bluetoothEnabled) {
            Quickshell.execDetached(["sh", "-c", "bluetoothctl power off; rfkill block bluetooth"]);
            root.bluetoothEnabled = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "rfkill unblock bluetooth; bluetoothctl power on"]);
            root.bluetoothEnabled = true;
        }
        refreshTimer.restart();
    }

    function toggleNightLight() {
        if (root.nightLightActive) {
            Quickshell.execDetached(["pkill", "-x", "wlsunset"]);
            root.nightLightActive = false;
        } else {
            Quickshell.execDetached(["sh", "-c", `wlsunset -t ${root.nightLightTemp} -T 6501 &`]);
            root.nightLightActive = true;
        }
        refreshTimer.restart();
    }

    // Media action & read processes
    Process { id: mediaActionProcess }

    Process {
        id: mediaReadProcess
        command: ["playerctl", "metadata", "--format", "{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const line = text.trim();
                    if (line.length > 0) {
                        const parts = line.split("|||");
                        root.osdTitle = parts[1] || "Reproducción";
                        root.osdSubtitle = parts[2] || "MPRIS";
                        root.osdArtUrl = parts[3] || "";
                        root.triggerOsd("media", 0, root.osdIcon, 2500);
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: mediaReadTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (!mediaReadProcess.running) mediaReadProcess.running = true;
        }
    }

    function triggerMediaAction(action) {
        let sym = "play_arrow";
        if (action === "play-pause") {
            sym = "play_arrow";
        } else if (action === "next") {
            sym = "skip_next";
        } else if (action === "previous") {
            sym = "skip_previous";
        }
        root.osdIcon = sym;

        mediaActionProcess.command = ["playerctl", action];
        mediaActionProcess.running = true;
        mediaReadTimer.restart();
    }

    Process { id: volActionProcess }
    Process { id: brightActionProcess }

    Component.onCompleted: {
        loadNightLightProcess.running = true;
    }

    Process {
        id: loadNightLightProcess
        command: ["sh", "-c", "cat $HOME/.cache/sane-shell-nightlight.txt 2>/dev/null || echo 4000"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val) && val >= 2500 && val <= 6500) {
                    root.nightLightTemp = val;
                }
            }
        }
    }

    // Refresh command combining fast shell reads
    Process {
        id: statsProcess
        command: [
            "sh", "-c",
            "cat /proc/stat | head -n 1; echo '---'; " +
            "grep -E '^(MemTotal|AnonPages|Shmem|Slab|SReclaimable):' /proc/meminfo; echo '---'; " +
            "cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1; echo '---'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; echo '---'; " +
            "nmcli -t -f TYPE,STATE dev 2>/dev/null; echo '---'; " +
            "nmcli radio wifi 2>/dev/null; echo '---'; " +
            "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2; echo '---'; " +
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo '1' || echo '0'; echo '---'; " +
            "bluetoothctl devices Connected 2>/dev/null | head -n 1; echo '---'; " +
            "pgrep -x wlsunset >/dev/null && echo '1' || echo '0'; echo '---'; " +
            "playerctl metadata --format '{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}' 2>/dev/null | head -n 1; echo '---'; " +
            "pgrep -x niri-deck >/dev/null && echo '1' || echo '0'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const sections = text.split("---\n");
                    if (sections.length >= 10) {
                        // 0. CPU
                        const cpuLine = sections[0].trim();
                        const parts = cpuLine.split(/\s+/).slice(1).map(Number);
                        if (parts.length >= 4) {
                            const idle = parts[3] + (parts[4] || 0);
                            let total = 0;
                            for (let i = 0; i < parts.length; i++) total += parts[i];
                            if (root._prevTotal > 0) {
                                const diffTotal = total - root._prevTotal;
                                const diffIdle = idle - root._prevIdle;
                                if (diffTotal > 0) {
                                    root.cpuPercent = Math.max(0, Math.min(100, Math.round((1.0 - diffIdle / diffTotal) * 100)));
                                }
                            }
                            root._prevTotal = total;
                            root._prevIdle = idle;
                        }

                        // 1. RAM (Real Active Memory: AnonPages + Shmem + Unreclaimable Slab)
                        const memLines = sections[1].trim().split("\n");
                        let totalKB = 0, anonKB = 0, shmemKB = 0, slabKB = 0, sreclaimKB = 0;
                        for (let line of memLines) {
                            const val = parseInt(line.replace(/\D/g, "")) || 0;
                            if (line.startsWith("MemTotal:")) totalKB = val;
                            else if (line.startsWith("AnonPages:")) anonKB = val;
                            else if (line.startsWith("Shmem:")) shmemKB = val;
                            else if (line.startsWith("Slab:")) slabKB = val;
                            else if (line.startsWith("SReclaimable:")) sreclaimKB = val;
                        }
                        if (totalKB > 0) {
                            const usedKB = anonKB + shmemKB + Math.max(0, slabKB - sreclaimKB);
                            root.ramPercent = Math.max(0, Math.min(100, Math.round((usedKB / totalKB) * 100)));
                            root.ramUsedGB = (usedKB / (1024 * 1024)).toFixed(1);
                        }

                        // 2. GPU Temp
                        const gpuRaw = sections[2].trim();
                        if (gpuRaw.length > 0) {
                            const tempVal = parseInt(gpuRaw);
                            if (!isNaN(tempVal)) {
                                root.gpuTemp = Math.round(tempVal > 1000 ? tempVal / 1000 : tempVal);
                            }
                        }

                        // 3. Audio (with external change detection for OSD)
                        const audioLine = sections[3].trim();
                        const newMuted = audioLine.includes("[MUTED]");
                        const volMatch = audioLine.match(/Volume:\s+([0-9.]+)/);
                        const oldVol = root.volume;
                        const oldMuted = root.isMuted;
                        root.isMuted = newMuted;
                        if (volMatch) {
                            root.volume = Math.round(parseFloat(volMatch[1]) * 100);
                        }

                        if (root._audioInitialized) {
                            if (oldVol !== root.volume || oldMuted !== root.isMuted) {
                                root.triggerOsd("volume", root.volume, root.isMuted ? "volume_off" : (root.volume === 0 ? "volume_mute" : (root.volume < 50 ? "volume_down" : "volume_up")));
                            }
                        } else {
                            root._audioInitialized = true;
                        }

                        // 4. Network
                        const devLines = sections[4].trim();
                        root.ethernetConnected = devLines.includes("ethernet:connected");

                        // 5. Wi-Fi status
                        const wifiStatus = sections[5].trim();
                        root.wifiEnabled = (wifiStatus === "enabled");

                        // 6. Wi-Fi SSID
                        const ssid = sections[6].trim();
                        root.wifiSsid = ssid;
                        root.wifiConnected = (ssid.length > 0);

                        if (root.ethernetConnected) {
                            root.networkType = "ethernet";
                        } else if (root.wifiConnected) {
                            root.networkType = "wifi";
                        } else {
                            root.networkType = "disconnected";
                        }

                        // 7. Bluetooth powered
                        root.bluetoothEnabled = (sections[7].trim() === "1");

                        // 8. Bluetooth connected device
                        const btDev = sections[8].trim();
                        root.bluetoothDevice = btDev;
                        root.bluetoothConnected = (btDev.length > 0);

                        // 9. Night Light (wlsunset)
                        root.nightLightActive = (sections[9].trim() === "1");

                        // 10. Auto-detect track change in background
                        if (sections.length > 10) {
                            const mediaLine = sections[10].trim();
                            if (mediaLine.length > 0) {
                                const mparts = mediaLine.split("|||");
                                const mstatus = mparts[0] || "";
                                const mtitle = mparts[1] || "";
                                const martist = mparts[2] || "";
                                const mart = mparts[3] || "";
                                if (mtitle.length > 0 && mtitle !== root._prevMediaTitle && mstatus === "Playing") {
                                    if (root._prevMediaTitle !== "") {
                                        root.osdTitle = mtitle;
                                        root.osdSubtitle = martist;
                                        root.osdArtUrl = mart;
                                        root.triggerOsd("media", 0, "music_note", 2500);
                                    }
                                    root._prevMediaTitle = mtitle;
                                }
                            }
                        }

                        // 11. niri-deck active companion
                        if (sections.length > 11) {
                            root.deckActive = (sections[11].trim() === "1");
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProcess.running) statsProcess.running = true;
        }
    }
}
