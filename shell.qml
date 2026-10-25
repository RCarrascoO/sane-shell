//@ pragma ShellId sane-shell
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QT_LOGGING_RULES=quickshell.dbus.properties=false;qt.qpa.wayland.textinput.warning=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import qs.modules.bar

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        TopBar {
            required property var modelData
            screenTarget: modelData
        }
    }
}
