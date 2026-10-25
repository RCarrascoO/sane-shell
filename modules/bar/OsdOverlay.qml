pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

PanelWindow {
    id: root

    property var screenTarget: null
    screen: screenTarget

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
    }

    margins {
        bottom: 48
    }

    implicitWidth: 280
    implicitHeight: 64
    color: "transparent"

    visible: SystemStats.osdVisible

    // M3 Expressive Pill Card
    Rectangle {
        anchors.centerIn: parent
        width: 260
        height: 52
        radius: 26
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outlineVariant

        opacity: SystemStats.osdVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            MaterialSymbol {
                text: SystemStats.osdIcon
                iconSize: 22
                color: (SystemStats.osdType === "volume" && SystemStats.isMuted) ? Theme.error : Theme.primary
            }

            // M3 Linear Progress bar
            Item {
                Layout.fillWidth: true
                implicitHeight: 8

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.surfaceContainer
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(100, SystemStats.osdValue)) / 100
                    radius: 4
                    color: (SystemStats.osdType === "volume" && SystemStats.isMuted) ? Theme.error : Theme.primary

                    Behavior on width {
                        NumberAnimation { duration: 100 }
                    }
                }
            }

            StyledText {
                text: `${SystemStats.osdValue}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: 12
                    weight: Font.Bold
                }
                color: Theme.colOnSurface
            }
        }
    }
}
