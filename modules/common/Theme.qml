pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isDark: true
    property string activePopup: ""

    // ========================================================
    // MATERIAL DESIGN 3 OFFICIAL TOKENS (Catppuccin Mocha / Latte)
    // ========================================================

    // Surfaces (5-tier hierarchy)
    readonly property color barBackground: isDark ? "#11111b" : "#dce0e8" // Crust
    readonly property color surfaceDim: isDark ? "#11111b" : "#dce0e8"
    readonly property color surface: isDark ? "#181825" : "#eff1f5" // Mantle
    readonly property color surfaceBright: isDark ? "#313244" : "#ffffff"
    readonly property color surfaceContainerLowest: isDark ? "#11111b" : "#ffffff"
    readonly property color surfaceContainerLow: isDark ? "#181825" : "#e6e9ef"
    readonly property color surfaceContainer: isDark ? "#1e1e2e" : "#dce0e8" // Base
    readonly property color surfaceContainerHigh: isDark ? "#313244" : "#ccd0da" // Surface0
    readonly property color surfaceContainerHighest: isDark ? "#45475a" : "#bcc0cc" // Surface1

    // Primary Roles & Containers
    readonly property color primary: isDark ? "#b4befe" : "#7287fd" // Pixel Lavender
    readonly property color onPrimary: isDark ? "#11111b" : "#ffffff"
    readonly property color primaryContainer: isDark ? "#3b4261" : "#dbe1ff"
    readonly property color onPrimaryContainer: isDark ? "#dbe1ff" : "#00174b"

    // Secondary Roles & Containers
    readonly property color secondary: isDark ? "#89b4fa" : "#1e66f5" // Pixel Blue
    readonly property color onSecondary: isDark ? "#11111b" : "#ffffff"
    readonly property color secondaryContainer: isDark ? "#2e3c56" : "#d8e2ff"
    readonly property color onSecondaryContainer: isDark ? "#d8e2ff" : "#001a41"

    // Tertiary Roles & Containers
    readonly property color tertiary: isDark ? "#cba6f7" : "#8839ef" // Mauve
    readonly property color tertiaryContainer: isDark ? "#433458" : "#f2daff"
    readonly property color onTertiaryContainer: isDark ? "#f2daff" : "#2c0051"

    // Outline & Boundaries
    readonly property color outline: isDark ? "#6c7086" : "#7c7f93"
    readonly property color outlineVariant: isDark ? "#313244" : "#ccd0da"

    // Content & Typography
    readonly property color onSurface: isDark ? "#cdd6f4" : "#4c4f69"
    readonly property color onSurfaceVariant: isDark ? "#a6adc8" : "#6c6f85"

    // Semantic Status Colors
    readonly property color warning: isDark ? "#f9e2af" : "#df8e1d"
    readonly property color error: isDark ? "#f38ba8" : "#d20f39"
    readonly property color success: isDark ? "#a6e3a1" : "#40a02b"

    // M3 Shape Scale Tokens
    readonly property QtObject shape: QtObject {
        readonly property real extraSmall: 4
        readonly property real small: 8
        readonly property real medium: 12
        readonly property real large: 16
        readonly property real largeIncreased: 20
        readonly property real extraLarge: 28
        readonly property real full: 999
    }

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
