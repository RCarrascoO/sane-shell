pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isDark: true
    property string activePopup: ""

    // Android 16 / Material 3 Expressive Catppuccin Tokens
    readonly property color barBackground: isDark ? "#11111b" : "#dce0e8" // Crust
    readonly property color surface: isDark ? "#181825" : "#e6e9ef" // Mantle (Shade bg)
    readonly property color surfaceContainer: isDark ? "#1e1e2e" : "#eff1f5" // Base (Cards)
    readonly property color surfaceContainerHigh: isDark ? "#313244" : "#ccd0da" // Surface0 (Inactive pill/tile)
    readonly property color surfaceContainerHighest: isDark ? "#45475a" : "#bcc0cc" // Surface1 (Hover state)
    readonly property color outline: isDark ? "#45475a" : "#bcc0cc" // Border
    readonly property color primary: isDark ? "#b4befe" : "#7287fd" // Pixel Lavender
    readonly property color secondary: isDark ? "#89b4fa" : "#1e66f5" // Pixel Blue
    readonly property color onPrimary: isDark ? "#11111b" : "#eff1f5" // Deep contrast
    readonly property color onSurface: isDark ? "#cdd6f4" : "#4c4f69" // Text
    readonly property color onSurfaceVariant: isDark ? "#a6adc8" : "#6c6f85" // Muted text
    readonly property color warning: isDark ? "#f9e2af" : "#df8e1d"
    readonly property color error: isDark ? "#f38ba8" : "#d20f39"
    readonly property color success: isDark ? "#a6e3a1" : "#40a02b"

    readonly property string themeFile: Quickshell.env("HOME") + "/.cache/sane-shell-theme.json"

    function togglePopup(name) {
        activePopup = (activePopup === name) ? "" : name;
    }

    function closePopups() {
        activePopup = "";
    }

    function toggleTheme() {
        isDark = !isDark;
        saveTheme();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/sane-shell/scripts/toggle-theme.sh", root.isDark ? "dark" : "light"]);
    }

    function saveTheme() {
        Quickshell.execDetached(["sh", "-c", "printf '{\"isDark\":%s}\\n' " + (root.isDark ? "true" : "false") + " > " + root.themeFile]);
    }

    // Load initial theme from file on start
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
