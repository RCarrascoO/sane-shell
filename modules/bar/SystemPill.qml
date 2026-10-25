pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var screenTarget: null
    property bool hasLeftSibling: false
    readonly property bool isPopupOpen: Theme.activePopup === "quicksettings"

    implicitHeight: 26
    implicitWidth: sysRow.implicitWidth + 20

    // M3 Connected Segment con TrayPill
    topLeftRadius: root.hasLeftSibling ? 4 : 13
    bottomLeftRadius: root.hasLeftSibling ? 4 : 13
    topRightRadius: 13
    bottomRightRadius: 13

    color: isPopupOpen
        ? Theme.primary
        : (sysMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        id: sysRow
        anchors.centerIn: parent
        spacing: 6

        // 1. Network status icon (LAN or Wi-Fi)
        MaterialSymbol {
            text: SystemStats.networkType === "ethernet"
                ? "lan"
                : (SystemStats.networkType === "wifi" ? "wifi" : "wifi_off")
            iconSize: 14
            color: root.isPopupOpen ? Theme.colOnPrimary : Theme.primary
        }

        // 2. Bluetooth (visible when active)
        MaterialSymbol {
            visible: SystemStats.bluetoothEnabled
            text: SystemStats.bluetoothConnected ? "bluetooth_connected" : "bluetooth"
            iconSize: 14
            color: root.isPopupOpen ? Theme.colOnPrimary : Theme.primary
        }

        // 3. Night Light (visible when active)
        MaterialSymbol {
            visible: SystemStats.nightLightActive
            text: "nightlight"
            iconSize: 14
            color: root.isPopupOpen ? Theme.colOnPrimary : Theme.warning
        }

        // 4. Audio volume icon + percentage
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: SystemStats.isMuted
                    ? "volume_off"
                    : (SystemStats.volume === 0 ? "volume_mute" : (SystemStats.volume > 50 ? "volume_up" : "volume_down"))
                iconSize: 14
                color: root.isPopupOpen
                    ? Theme.colOnPrimary
                    : (SystemStats.isMuted ? Theme.error : Theme.colOnSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.volume}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.DemiBold
                }
                color: root.isPopupOpen
                    ? Theme.colOnPrimary
                    : (SystemStats.isMuted ? Theme.error : Theme.colOnSurface)
            }
        }

        // 5. Theme indicator icon
        MaterialSymbol {
            text: Theme.isDark ? "dark_mode" : "light_mode"
            iconSize: 14
            color: root.isPopupOpen ? Theme.colOnPrimary : Theme.primary
        }
    }

    MouseArea {
        id: sysMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            Theme.activePopup = (Theme.activePopup === "quicksettings") ? "" : "quicksettings";
        }
    }

    QuickSettingsPopup {
        id: quickSettings
        hoverTarget: root
        screenTarget: root.screenTarget
    }
}
