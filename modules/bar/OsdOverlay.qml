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

    implicitWidth: SystemStats.osdType === "media" ? 360 : 280
    implicitHeight: SystemStats.osdType === "media" ? 80 : 64
    color: "transparent"

    visible: SystemStats.osdVisible

    // 1. NON-MEDIA OSD (Volume / Brightness)
    Rectangle {
        visible: SystemStats.osdType !== "media"
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

    // 2. MEDIA OSD (MPRIS with album art & track info)
    Rectangle {
        visible: SystemStats.osdType === "media"
        anchors.centerIn: parent
        width: 340
        height: 68
        radius: 24
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outlineVariant

        opacity: SystemStats.osdVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Album Art or Music Icon
            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: 12
                color: Theme.secondaryContainer
                clip: true

                Image {
                    id: osdArtImg
                    anchors.fill: parent
                    source: (SystemStats.osdArtUrl && SystemStats.osdArtUrl.length > 8 && SystemStats.osdArtUrl !== "file:///") ? SystemStats.osdArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !osdArtImg.visible
                    text: "music_note"
                    iconSize: 22
                    color: Theme.colOnSecondaryContainer
                }
            }

            // Track Title & Artist
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: SystemStats.osdTitle.length > 0 ? SystemStats.osdTitle : "Reproducción"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 12
                        weight: Font.Bold
                    }
                    color: Theme.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: SystemStats.osdSubtitle.length > 0 ? SystemStats.osdSubtitle : "PipeWire MPRIS"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 10
                    }
                    color: Theme.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Right squircle badge with action symbol
            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: 12
                color: Theme.primary

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: SystemStats.osdIcon
                    iconSize: 20
                    color: Theme.colOnPrimary
                }
            }
        }
    }
}
