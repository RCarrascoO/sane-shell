pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpuPercent: 0
    property alias cpuUsage: root.cpuPercent

    property int ramPercent: 0
    property string ramUsedGB: "0.0"
    property alias ramUsedGb: root.ramUsedGB

    property int gpuTemp: 40
    property int volume: 50
    property bool isMuted: false
    property string networkType: "ethernet" // "ethernet" | "wifi" | "disconnected"

    property real _prevIdle: 0
    property real _prevTotal: 0

    function setVolume(pct) {
        const val = Math.max(0, Math.min(100, pct)) / 100.0;
        volActionProcess.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", val.toFixed(2)];
        volActionProcess.running = true;
        root.volume = Math.round(val * 100);
    }

    function toggleMute() {
        volActionProcess.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volActionProcess.running = true;
        root.isMuted = !root.isMuted;
    }

    Process {
        id: volActionProcess
    }

    // Refresh command combining fast shell reads
    Process {
        id: statsProcess
        command: [
            "sh", "-c",
            "cat /proc/stat | head -n 1; echo '---'; " +
            "grep -E '^(MemTotal|AnonPages|Shmem|Slab|SReclaimable):' /proc/meminfo; echo '---'; " +
            "cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1; echo '---'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const sections = text.split("---\n");
                    if (sections.length >= 4) {
                        // 1. CPU
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

                        // 2. RAM (Real Active Memory: AnonPages + Shmem + Unreclaimable Slab)
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

                        // 3. GPU Temp
                        const gpuRaw = sections[2].trim();
                        if (gpuRaw.length > 0) {
                            const tempVal = parseInt(gpuRaw);
                            if (!isNaN(tempVal)) {
                                root.gpuTemp = Math.round(tempVal > 1000 ? tempVal / 1000 : tempVal);
                            }
                        }

                        // 4. Audio
                        const audioLine = sections[3].trim();
                        root.isMuted = audioLine.includes("[MUTED]");
                        const volMatch = audioLine.match(/Volume:\s+([0-9.]+)/);
                        if (volMatch) {
                            root.volume = Math.round(parseFloat(volMatch[1]) * 100);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProcess.running) statsProcess.running = true;
        }
    }
}
