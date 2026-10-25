//@ pragma ShellId sane-shell
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env LD_LIBRARY_PATH=/home/sane/.local/lib
//@ pragma DefaultEnv QT_LOGGING_RULES=quickshell.dbus.properties=false;qt.qpa.wayland.textinput.warning=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.bar

ShellRoot {
    id: root

    IpcHandler {
        target: "shell"

        function togglePopup(name: string) {
            Theme.togglePopup(name);
        }

        function closePopups() {
            Theme.closePopups();
        }

        function toggleTheme() {
            Theme.toggleTheme();
        }
    }

    Variants {
        model: Quickshell.screens
        TopBar {
            required property var modelData
            screenTarget: modelData
        }
    }
}
