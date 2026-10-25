pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var screenTarget: null
    readonly property bool isPopupOpen: Theme.activePopup === "quicksettings"

    implicitHeight: 24
    implicitWidth: sysRow.implicitWidth + 20
    radius: 12
    color: isPopupOpen
        ? Theme.primary
        : (sysMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        id: sysRow
        anchors.centerIn: parent
        spacing: 8

        // Network status icon
        MaterialSymbol {
            text: "lan"
            iconSize: 14
            color: root.isPopupOpen ? Theme.onPrimary : Theme.primary
        }

        // Audio volume icon + percentage
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: SystemStats.isMuted ? "volume_off" : (SystemStats.volume > 50 ? "volume_up" : "volume_down")
                iconSize: 14
                color: root.isPopupOpen
                    ? Theme.onPrimary
                    : (SystemStats.isMuted ? Theme.error : Theme.onSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.volume}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.DemiBold
                }
                color: root.isPopupOpen
                    ? Theme.onPrimary
                    : (SystemStats.isMuted ? Theme.error : Theme.onSurface)
            }
        }

        // Theme indicator icon
        MaterialSymbol {
            text: Theme.isDark ? "dark_mode" : "light_mode"
            iconSize: 14
            color: root.isPopupOpen ? Theme.onPrimary : Theme.primary
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
