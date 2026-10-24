pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property string activeWindowTitle: ""
    property int focusedWindowId: 0

    function workspacesFor(outputName) {
        const res = [];
        for (let i = 0; i < workspaces.length; i++) {
            const ws = workspaces[i];
            if (ws.output === outputName) {
                // Determine if workspace has windows
                let hasWindows = false;
                for (let j = 0; j < windows.length; j++) {
                    if (windows[j].workspace_id === ws.id) {
                        hasWindows = true;
                        break;
                    }
                }
                res.push({
                    id: ws.id,
                    idx: ws.idx,
                    output: ws.output,
                    isActive: ws.is_active ?? false,
                    isFocused: ws.is_focused ?? false,
                    hasWindows: hasWindows
                });
            }
        }
        res.sort((a, b) => a.idx - b.idx);
        return res;
    }

    function focusWorkspace(idx) {
        focusWsProcess.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        focusWsProcess.running = true;
    }

    Process {
        id: focusWsProcess
    }

    // Refresh state query
    function refresh() {
        if (!queryWsProcess.running) queryWsProcess.running = true;
        if (!queryWinProcess.running) queryWinProcess.running = true;
        if (!queryFocusedProcess.running) queryFocusedProcess.running = true;
    }

    Process {
        id: queryWsProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text) || [];
                } catch(e) {}
            }
        }
    }

    Process {
        id: queryWinProcess
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text) || [];
                } catch(e) {}
            }
        }
    }

    Process {
        id: queryFocusedProcess
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const win = JSON.parse(text);
                    root.activeWindowTitle = win?.title ?? "";
                    root.focusedWindowId = win?.id ?? 0;
                } catch(e) {
                    root.activeWindowTitle = "";
                    root.focusedWindowId = 0;
                }
            }
        }
    }

    // Fast event-stream listener
    Process {
        id: eventStreamProcess
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.refresh();
            }
        }
        onExited: {
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!eventStreamProcess.running) {
                eventStreamProcess.running = true;
            }
        }
    }

    // Polling backup timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
