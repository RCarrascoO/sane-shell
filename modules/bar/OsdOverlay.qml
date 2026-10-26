pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    property var screenTarget: null

    // ========================================================
    // 1. MEDIA OSD WINDOW (Top Center, below TopBar)
    // ========================================================
    PanelWindow {
        id: mediaWindow
        screen: root.screenTarget
        visible: SystemStats.osdVisible && SystemStats.osdType === "media"
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "sane-shell:osd-media"

        anchors {
            top: true
        }

        margins {
            top: 42
        }

        implicitWidth: 360
        implicitHeight: 80

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: 68
            radius: 24
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant

            opacity: mediaWindow.visible ? 1.0 : 0.0
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
                    implicitWidth: 46
                    implicitHeight: 46
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

    // ========================================================
    // 2. VOLUME OSD WINDOW (Vertical on Right, Android 16 style)
    // ========================================================
    PanelWindow {
        id: volumeWindow
        screen: root.screenTarget
        visible: SystemStats.osdVisible && SystemStats.osdType === "volume"
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "sane-shell:osd-volume"

        anchors {
            right: true
        }

        margins {
            right: 16
        }

        implicitWidth: 68
        implicitHeight: 240

        Rectangle {
            anchors.centerIn: parent
            width: 52
            height: 220
            radius: 26
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant

            opacity: volumeWindow.visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 10

                // Percentage on top
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `${SystemStats.osdValue}%`
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: 11
                        weight: Font.Bold
                    }
                    color: Theme.colOnSurface
                }

                // Center: Vertical progress bar growing bottom-to-top
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    implicitWidth: 10

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: Theme.surfaceContainer
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * Math.max(0, Math.min(100, SystemStats.osdValue)) / 100
                        radius: 5
                        color: SystemStats.isMuted ? Theme.error : Theme.primary

                        Behavior on height {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }

                // Bottom: Volume / Mute icon
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: SystemStats.osdIcon
                    iconSize: 22
                    color: SystemStats.isMuted ? Theme.error : Theme.primary
                }
            }
        }
    }

    // ========================================================
    // 3. BRIGHTNESS OSD WINDOW (Vertical on Left, Android 16 style)
    // ========================================================
    PanelWindow {
        id: brightnessWindow
        screen: root.screenTarget
        visible: SystemStats.osdVisible && SystemStats.osdType === "brightness"
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "sane-shell:osd-brightness"

        anchors {
            left: true
        }

        margins {
            left: 16
        }

        implicitWidth: 68
        implicitHeight: 240

        Rectangle {
            anchors.centerIn: parent
            width: 52
            height: 220
            radius: 26
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant

            opacity: brightnessWindow.visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 10

                // Percentage on top
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `${SystemStats.osdValue}%`
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: 11
                        weight: Font.Bold
                    }
                    color: Theme.colOnSurface
                }

                // Center: Vertical progress bar growing bottom-to-top
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    implicitWidth: 10

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: Theme.surfaceContainer
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * Math.max(0, Math.min(100, SystemStats.osdValue)) / 100
                        radius: 5
                        color: Theme.primary

                        Behavior on height {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }

                // Bottom: Brightness icon
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: SystemStats.osdIcon
                    iconSize: 22
                    color: Theme.primary
                }
            }
        }
    }
}
