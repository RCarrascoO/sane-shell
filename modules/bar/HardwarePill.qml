pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    implicitHeight: 26
    implicitWidth: segRow.implicitWidth

    RowLayout {
        id: segRow
        anchors.fill: parent
        spacing: 2

        // 1. SEGMENTO IZQUIERDO (CPU): esquinas exteriores redondeadas, interiores rectas
        Rectangle {
            implicitHeight: 26
            implicitWidth: cpuContent.implicitWidth + 16
            topLeftRadius: 13
            bottomLeftRadius: 13
            topRightRadius: 4
            bottomRightRadius: 4
            color: hwMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: cpuContent
                anchors.centerIn: parent
                spacing: 4

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
        }

        // 2. SEGMENTO CENTRAL (RAM): esquinas rectas M3
        Rectangle {
            implicitHeight: 26
            implicitWidth: ramContent.implicitWidth + 16
            radius: 4
            color: hwMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: ramContent
                anchors.centerIn: parent
                spacing: 4

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
        }

        // 3. SEGMENTO DERECHO (GPU Temp): esquinas interiores rectas, exteriores redondeadas
        Rectangle {
            implicitHeight: 26
            implicitWidth: gpuContent.implicitWidth + 16
            topLeftRadius: 4
            bottomLeftRadius: 4
            topRightRadius: 13
            bottomRightRadius: 13
            color: hwMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: gpuContent
                anchors.centerIn: parent
                spacing: 4

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
    }

    MouseArea {
        id: hwMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
    }
}
