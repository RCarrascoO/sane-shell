pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    visible: SystemTray.items.values.length > 0
    implicitHeight: 24
    implicitWidth: visible ? (trayRow.implicitWidth + 16) : 0
    radius: 12
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
}
