pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property alias contentItem: contentHolder.data
    property color colBackground: Theme.surfaceContainer
    property color colBackgroundHover: Theme.surfaceContainerHigh
    property real buttonRadius: 10
    property bool buttonHovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed

    signal clicked()

    implicitWidth: 100
    implicitHeight: 30

    radius: buttonRadius
    color: mouseArea.containsMouse ? root.colBackgroundHover : root.colBackground

    scale: pressed ? 0.96 : (mouseArea.containsMouse ? 1.02 : 1.0)

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
