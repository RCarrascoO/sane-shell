//@ pragma UseQApplication
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
import qs.services

ShellRoot {
    id: root

    IpcHandler {
        target: "shell"

        function togglePopup(name: string) {
            Theme.togglePopup(name);
        }

        function togglePopupOn(name: string, screenName: string) {
            Theme.togglePopupOn(name, screenName);
        }

        function closePopups() {
            Theme.closePopups();
        }

        function toggleTheme() {
            Theme.toggleTheme();
        }

        function setVolume(pct: int) {
            SystemStats.setVolume(pct);
        }

        function changeVolume(delta: int) {
            SystemStats.changeVolume(delta);
        }

        function toggleMute() {
            SystemStats.toggleMute();
        }

        function setBrightness(pct: int) {
            SystemStats.setBrightness(pct);
        }

        function changeBrightness(delta: int) {
            SystemStats.changeBrightness(delta);
        }

        function triggerMedia(action: string) {
            SystemStats.triggerMediaAction(action);
        }
    }

    function screenForName(name: string): var {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i];
            }
        }
        return Quickshell.screens[0];
    }

    Variants {
        model: Quickshell.screens
        TopBar {
            required property var modelData
            screenTarget: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        OsdOverlay {
            required property var modelData
            screenTarget: modelData
        }
    }

    AppDrawerPopup {
        id: appDrawer
        screenTarget: root.screenForName(Theme.activePopupScreen)
    }

    WallpaperPopup {
        id: wallpaperPicker
        screenTarget: root.screenForName(Theme.activePopupScreen)
    }

    DisplayPopup {
        id: displayPopup
        screenTarget: root.screenForName(Theme.activePopupScreen)
    }
}
