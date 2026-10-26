pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    property var screenTarget: null
    property var activeMenu: null

    visible: (SystemTray.items.values.length > 0) || SystemStats.deckActive
    implicitHeight: 26
    implicitWidth: visible ? (trayRow.implicitWidth + 16) : 0

    // M3 Connected Segment con SystemPill
    topLeftRadius: 13
    bottomLeftRadius: 13
    topRightRadius: 4
    bottomRightRadius: 4

    color: Theme.surfaceContainer

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items.values

            MouseArea {
                id: trayItemArea
                required property var modelData
                implicitWidth: 16
                implicitHeight: 16
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                TrayMenuPopup {
                    id: trayMenu
                    menuHandle: trayItemArea.modelData.menu
                    screen: root.screenTarget ?? null
                    onVisibleChanged: {
                        if (!visible && root.activeMenu === trayMenu) {
                            root.activeMenu = null;
                        }
                    }
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayItemArea.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItemArea.modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton && trayItemArea.modelData.hasMenu) {
                        if (root.activeMenu && root.activeMenu !== trayMenu) {
                            root.activeMenu.close();
                        }
                        if (trayMenu.visible) {
                            trayMenu.close();
                            root.activeMenu = null;
                        } else {
                            const pos = trayItemArea.mapToItem(null, 0, 0);
                            trayMenu.targetX = pos.x - 60;
                            trayMenu.open();
                            root.activeMenu = trayMenu;
                        }
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: trayItemArea.modelData.icon
                }
            }
        }

        // sane-deck Companion active indicator
        MouseArea {
            id: deckItemArea
            visible: SystemStats.deckActive
            implicitWidth: 16
            implicitHeight: 16
            cursorShape: Qt.PointingHandCursor

            MaterialSymbol {
                anchors.centerIn: parent
                text: "developer_board"
                iconSize: 16
                color: Theme.primary
            }

            onClicked: {
                Quickshell.execDetached(["zen-browser", "http://localhost:8080"]);
            }
        }
    }
}
