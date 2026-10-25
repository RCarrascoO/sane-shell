pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

StyledPopup {
    id: root
    popupId: "wallpaper"

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            scanProcess.running = true;
        }
    }

    contentItem: Rectangle {
        implicitWidth: 520
        implicitHeight: 440
        radius: 28
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        Process {
            id: scanProcess
            command: [
                "sh", "-c",
                "find /home/sane/Imágenes/Wallpapers/ -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' \\) -printf '%f\\t%p\\n' 2>/dev/null | sort"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    wallpaperModel.clear();
                    for (let line of lines) {
                        if (!line) continue;
                        const parts = line.split("\t");
                        if (parts.length >= 2) {
                            wallpaperModel.append({ "name": parts[0], "path": parts[1] });
                        }
                    }
                }
            }
        }

        ListModel {
            id: wallpaperModel
        }

        function applyWallpaper(wpPath) {
            Quickshell.execDetached(["sh", "-c", `pkill swaybg; swaybg -i "${wpPath}" -m fill &`]);
            Quickshell.execDetached(["sh", "-c", `printf '%s\\n' "${wpPath}" > "$HOME/.cache/sane-shell-wallpaper.txt"`]);
            Quickshell.execDetached(["sh", "-c", `sed -i -E 's|("swaybg" "-i" ")[^"]*(" "-m" "fill")|\\1${wpPath}\\2|' "$HOME/.config/niri/config.d/50-startup.kdl"`]);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header M3
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "wallpaper"
                    iconSize: 22
                    color: Theme.primary
                }

                StyledText {
                    text: "Fondos de Pantalla"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 16
                        weight: Font.Bold
                    }
                    color: Theme.colOnSurface
                }

                StyledText {
                    text: `(${wallpaperModel.count})`
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: 12
                    }
                    color: Theme.colOnSurfaceVariant
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: Theme.activePopup = ""

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: Theme.colOnSurface
                    }
                }
            }

            // GridView con miniaturas
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    cellWidth: 156
                    cellHeight: 96
                    model: wallpaperModel

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        required property string name
                        required property string path
                        required property int index

                        width: 150
                        height: 90

                        Rectangle {
                            id: thumbCard
                            anchors.fill: parent
                            radius: 14
                            color: Theme.surfaceContainerLow
                            clip: true
                            border.width: thumbMouse.containsMouse ? 2 : 1
                            border.color: thumbMouse.containsMouse ? Theme.primary : Theme.outlineVariant

                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Image {
                                anchors.fill: parent
                                source: parent.parent.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(240, 135)
                                cache: true
                            }

                            // Dark overlay with subtle title on hover
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.45)
                                opacity: thumbMouse.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                StyledText {
                                    anchors {
                                        bottom: parent.bottom
                                        left: parent.left
                                        right: parent.right
                                        margins: 6
                                    }
                                    text: thumbCard.parent.name
                                    font {
                                        family: Appearance.font.family.main
                                        pixelSize: 9
                                        weight: Font.Medium
                                    }
                                    color: "#ffffff"
                                    elide: Text.ElideMiddle
                                }
                            }

                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.contentItem.applyWallpaper(thumbCard.parent.path);
                                    Theme.activePopup = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
