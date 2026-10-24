pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isDark: true

    readonly property color barBackground: isDark ? "#181825" : "#e6e9ef"
    readonly property color surface: isDark ? "#1e1e2e" : "#eff1f5"
    readonly property color surfaceContainer: isDark ? "#313244" : "#ccd0da"
    readonly property color surfaceContainerHigh: isDark ? "#45475a" : "#bcc0cc"
    readonly property color outline: isDark ? "#585b70" : "#acb0be"
    readonly property color primary: isDark ? "#b4befe" : "#7287fd"
    readonly property color secondary: isDark ? "#89b4fa" : "#1e66f5"
    readonly property color onPrimary: isDark ? "#11111b" : "#eff1f5"
    readonly property color onSurface: isDark ? "#cdd6f4" : "#4c4f69"
    readonly property color onSurfaceVariant: isDark ? "#a6adc8" : "#6c6f85"
    readonly property color warning: isDark ? "#f9e2af" : "#df8e1d"
    readonly property color error: isDark ? "#f38ba8" : "#d20f39"
    readonly property color success: isDark ? "#a6e3a1" : "#40a02b"

    readonly property string themeFile: Quickshell.env("HOME") + "/.cache/sane-shell-theme.json"

    function toggleTheme() {
        isDark = !isDark;
        saveTheme();
        toggleScriptProcess.running = true;
    }

    function saveTheme() {
        try {
            const data = JSON.stringify({ isDark: root.isDark });
            saveProcess.command = ["sh", "-c", "echo '" + data + "' > " + root.themeFile];
            saveProcess.running = true;
        } catch(e) {}
    }

    Process {
        id: saveProcess
    }

    Process {
        id: toggleScriptProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell/sane-shell/scripts/toggle-theme.sh", root.isDark ? "dark" : "light"]
    }

    // Load initial theme from file on completed
    Component.onCompleted: {
        loadProcess.running = true;
    }

    Process {
        id: loadProcess
        command: ["sh", "-c", "cat " + root.themeFile + " 2>/dev/null || echo '{\"isDark\":true}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed && typeof parsed.isDark === "boolean") {
                        root.isDark = parsed.isDark;
                    }
                } catch(e) {}
            }
        }
    }
}
