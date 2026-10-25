pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    radius: 16

    color: checked ? Theme.primary : Theme.surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: Theme.outline

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    Behavior on border.width {
        NumberAnimation { duration: 150 }
    }

    // M3 Thumb with embedded check icon when active
    Rectangle {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked
            ? (parent.width - width - 4)
            : (switchMouse.pressed ? 2 : 4)

        width: root.checked ? 24 : (switchMouse.pressed ? 24 : 16)
        height: root.checked ? 24 : (switchMouse.pressed ? 24 : 16)
        radius: width / 2

        color: root.checked ? Theme.colOnPrimary : Theme.outline

        Behavior on x {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "check"
            iconSize: 14
            color: Theme.primary
            opacity: root.checked ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: switchMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
