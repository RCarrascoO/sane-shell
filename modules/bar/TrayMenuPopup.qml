pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PopupWindow {
    id: root

    property QsMenuHandle menuHandle: null

    function open() {
        visible = true;
    }

    function close() {
        visible = false;
    }

    visible: false
    color: "transparent"

    implicitWidth: Math.max(180, card.implicitWidth + 8)
    implicitHeight: card.implicitHeight + 8

    // Dismiss overlay to capture clicks outside on Wayland/Niri
    PanelWindow {
        id: backdrop
        visible: root.visible
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sane-shell:traymenu-backdrop"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.menuHandle
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4

        implicitWidth: entriesColumn.implicitWidth + 16
        implicitHeight: entriesColumn.implicitHeight + 16

        radius: 16
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        ColumnLayout {
            id: entriesColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: menuOpener.children

                delegate: Item {
                    id: delegateItem
                    required property QsMenuEntry modelData

                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 9 : 32

                    // Separator line
                    Rectangle {
                        visible: delegateItem.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // Interactive menu entry
                    Rectangle {
                        id: btnBg
                        visible: !delegateItem.modelData.isSeparator
                        anchors.fill: parent
                        radius: 8
                        color: itemMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                        opacity: delegateItem.modelData.enabled ? 1.0 : 0.45

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: delegateItem.modelData.enabled
                            cursorShape: delegateItem.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: {
                                if (!delegateItem.modelData.enabled) return;
                                delegateItem.modelData.triggered();
                                root.close();
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Optional checkbox/radio icon
                            Item {
                                visible: delegateItem.modelData.buttonType !== QsMenuButtonType.None
                                implicitWidth: 16
                                implicitHeight: 16

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: delegateItem.modelData.checkState === Qt.Checked ? "check" : ""
                                    color: Theme.primary
                                }
                            }

                            // Optional Entry Icon
                            Item {
                                visible: delegateItem.modelData.icon.length > 0
                                implicitWidth: 16
                                implicitHeight: 16

                                IconImage {
                                    anchors.centerIn: parent
                                    source: delegateItem.modelData.icon
                                    implicitWidth: 16
                                    implicitHeight: 16
                                }
                            }

                            // Text Label
                            StyledText {
                                Layout.fillWidth: true
                                text: delegateItem.modelData.text
                                font.pixelSize: 13
                                color: Theme.colOnSurface
                                elide: Text.ElideRight
                            }

                            // Submenu indicator
                            MaterialSymbol {
                                visible: delegateItem.modelData.hasChildren
                                iconSize: 16
                                text: "chevron_right"
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
