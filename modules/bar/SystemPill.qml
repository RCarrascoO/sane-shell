pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    implicitHeight: 22
    implicitWidth: sysRow.implicitWidth + 20
    radius: 11
    color: sysMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        id: sysRow
        anchors.centerIn: parent
        spacing: 8

        // System Tray Items
        RowLayout {
            spacing: 6
            visible: SystemTray.items.values.length > 0

            Repeater {
                model: SystemTray.items.values

                MouseArea {
                    id: trayItemArea
                    required property var modelData
                    implicitWidth: 16
                    implicitHeight: 16
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            modelData.secondaryActivate();
                        }
                    }

                    IconImage {
                        anchors.fill: parent
                        source: trayItemArea.modelData.icon
                    }
                }
            }
        }

        // Separator if tray has items
        StyledText {
            visible: SystemTray.items.values.length > 0
            text: "•"
            font.pixelSize: 10
            color: Theme.outline
        }

        // Network status icon
        MaterialSymbol {
            text: "lan"
            iconSize: 13
            color: Theme.primary
        }

        // Audio volume icon + percentage
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: SystemStats.isMuted ? "volume_off" : (SystemStats.volume > 50 ? "volume_up" : "volume_down")
                iconSize: 13
                color: SystemStats.isMuted ? Theme.error : Theme.onSurfaceVariant
            }
            StyledText {
                text: `${SystemStats.volume}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Medium
                }
                color: SystemStats.isMuted ? Theme.error : Theme.onSurface
            }
        }

        // Theme indicator icon
        MaterialSymbol {
            text: Theme.isDark ? "dark_mode" : "light_mode"
            iconSize: 13
            color: Theme.primary
        }
    }

    MouseArea {
        id: sysMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: quickSettings.isOpen = !quickSettings.isOpen
    }

    QuickSettingsPopup {
        id: quickSettings
        hoverTarget: root
        hoverActivates: false
    }
}
