pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    implicitHeight: 24
    implicitWidth: hwRow.implicitWidth + 20
    radius: 12
    color: hwMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        id: hwRow
        anchors.centerIn: parent
        spacing: 6

        // CPU
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: "memory"
                iconSize: 14
                color: SystemStats.cpuPercent >= 80 ? Theme.error : (SystemStats.cpuPercent >= 50 ? Theme.warning : Theme.onSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.cpuPercent}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.DemiBold
                }
                color: SystemStats.cpuPercent >= 80 ? Theme.error : (SystemStats.cpuPercent >= 50 ? Theme.warning : Theme.onSurface)
            }
        }

        StyledText {
            text: "•"
            font.pixelSize: 10
            color: Theme.outline
        }

        // RAM
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: "developer_board"
                iconSize: 14
                color: SystemStats.ramPercent >= 85 ? Theme.error : (SystemStats.ramPercent >= 70 ? Theme.warning : Theme.onSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.ramUsedGB}G`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.DemiBold
                }
                color: SystemStats.ramPercent >= 85 ? Theme.error : (SystemStats.ramPercent >= 70 ? Theme.warning : Theme.onSurface)
            }
        }

        StyledText {
            text: "•"
            font.pixelSize: 10
            color: Theme.outline
        }

        // GPU Temp (RX 570)
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: "thermostat"
                iconSize: 14
                color: SystemStats.gpuTemp >= 75 ? Theme.error : (SystemStats.gpuTemp >= 60 ? Theme.warning : Theme.success)
            }
            StyledText {
                text: `${SystemStats.gpuTemp}°`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.DemiBold
                }
                color: SystemStats.gpuTemp >= 75 ? Theme.error : (SystemStats.gpuTemp >= 60 ? Theme.warning : Theme.onSurface)
            }
        }
    }

    MouseArea {
        id: hwMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
    }
}
