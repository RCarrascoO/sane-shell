pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    implicitHeight: 22
    implicitWidth: hwRow.implicitWidth + 20
    radius: 11
    color: Theme.surfaceContainer

    RowLayout {
        id: hwRow
        anchors.centerIn: parent
        spacing: 6

        // CPU
        RowLayout {
            spacing: 3
            MaterialSymbol {
                text: "memory"
                iconSize: 13
                color: SystemStats.cpuPercent > 80 ? Theme.error : (SystemStats.cpuPercent > 50 ? Theme.warning : Theme.onSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.cpuPercent}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Medium
                }
                color: SystemStats.cpuPercent > 80 ? Theme.error : (SystemStats.cpuPercent > 50 ? Theme.warning : Theme.onSurface)
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
                text: "speed"
                iconSize: 13
                color: SystemStats.ramPercent > 85 ? Theme.error : Theme.onSurfaceVariant
            }
            StyledText {
                text: `${SystemStats.ramUsedGB}G`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Medium
                }
                color: SystemStats.ramPercent > 85 ? Theme.error : Theme.onSurface
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
                iconSize: 13
                color: SystemStats.gpuTemp >= 75 ? Theme.error : (SystemStats.gpuTemp >= 65 ? Theme.warning : Theme.onSurfaceVariant)
            }
            StyledText {
                text: `${SystemStats.gpuTemp}°`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Medium
                }
                color: SystemStats.gpuTemp >= 75 ? Theme.error : (SystemStats.gpuTemp >= 65 ? Theme.warning : Theme.onSurface)
            }
        }
    }
}
