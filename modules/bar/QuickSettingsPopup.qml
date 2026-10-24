pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: root

    contentItem: Rectangle {
        implicitWidth: 340
        implicitHeight: mainLayout.implicitHeight + 24
        color: "transparent"

        ColumnLayout {
            id: mainLayout
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 14

            // Header: User & Session
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Avatar pill / Greeting
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: Theme.primary

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "person"
                        iconSize: 20
                        color: Theme.onPrimary
                    }
                }

                ColumnLayout {
                    spacing: 0
                    StyledText {
                        text: "sane"
                        font {
                            pixelSize: 14
                            weight: Font.Bold
                        }
                        color: Theme.onSurface
                    }
                    StyledText {
                        text: "CachyOS • Niri"
                        font.pixelSize: 11
                        color: Theme.onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                // Lock button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainer
                    colBackgroundHover: Theme.surfaceContainerHigh
                    onClicked: {
                        root.isOpen = false;
                        Quickshell.execDetached(["swaylock"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "lock"
                        iconSize: 18
                        color: Theme.onSurface
                    }
                }

                // Power button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainer
                    colBackgroundHover: Theme.error
                    onClicked: {
                        root.isOpen = false;
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        iconSize: 18
                        color: Theme.error
                    }
                }
            }

            // Quick Settings Tiles (Android 16 2-column tiles)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                // Tile 1: Network
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    buttonRadius: 26
                    colBackground: Theme.primary
                    colBackgroundHover: Theme.primary

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "lan"
                            iconSize: 22
                            color: Theme.onPrimary
                        }

                        ColumnLayout {
                            spacing: 1
                            StyledText {
                                text: "Ethernet"
                                font {
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onPrimary
                            }
                            StyledText {
                                text: "Conectado"
                                font.pixelSize: 10
                                color: Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                            }
                        }
                    }
                }

                // Tile 2: Theme Switcher (Mocha / Latte)
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    buttonRadius: 26
                    colBackground: Theme.isDark ? Theme.surfaceContainerHigh : Theme.primary
                    colBackgroundHover: Theme.surfaceContainerHigh
                    onClicked: Theme.toggleTheme()

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: Theme.isDark ? "dark_mode" : "light_mode"
                            iconSize: 22
                            color: Theme.isDark ? Theme.primary : Theme.onPrimary
                        }

                        ColumnLayout {
                            spacing: 1
                            StyledText {
                                text: Theme.isDark ? "Mocha" : "Latte"
                                font {
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.isDark ? Theme.onSurface : Theme.onPrimary
                            }
                            StyledText {
                                text: Theme.isDark ? "Oscuro" : "Claro"
                                font.pixelSize: 10
                                color: Theme.isDark ? Theme.onSurfaceVariant : Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                            }
                        }
                    }
                }
            }

            // Volume Slider Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 16
                color: Theme.surfaceContainer

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 12

                    // Mute / Unmute icon button
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: "transparent"
                        colBackgroundHover: Theme.surfaceContainerHigh
                        onClicked: SystemStats.toggleMute()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: SystemStats.isMuted ? "volume_off" : (SystemStats.volume > 50 ? "volume_up" : "volume_down")
                            iconSize: 20
                            color: SystemStats.isMuted ? Theme.error : Theme.primary
                        }
                    }

                    // Interactive slider track
                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        height: 12
                        radius: 6
                        color: Theme.surfaceContainerHigh

                        Rectangle {
                            height: parent.height
                            width: Math.max(12, parent.width * (SystemStats.volume / 100.0))
                            radius: 6
                            color: SystemStats.isMuted ? Theme.onSurfaceVariant : Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function updateVol(mouse) {
                                const ratio = Math.max(0, Math.min(1, mouse.x / width));
                                SystemStats.setVolume(Math.round(ratio * 100));
                            }
                            onClicked: mouse => updateVol(mouse)
                            onPositionChanged: mouse => {
                                if (pressed) updateVol(mouse);
                            }
                        }
                    }

                    StyledText {
                        text: `${SystemStats.volume}%`
                        font {
                            family: Appearance.font.family.numbers
                            pixelSize: 11
                            weight: Font.Bold
                        }
                        color: Theme.onSurface
                    }
                }
            }
        }
    }
}
