pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Item {
    id: root

    property real value: 0.0 // 0.0 to 1.0
    property color colPrimary: Theme.primary
    property color colSecondary: Theme.secondaryContainer
    property real gap: 4

    implicitHeight: 6
    implicitWidth: 200

    readonly property real clampedVal: Math.max(0, Math.min(1, value))
    readonly property real activeWidth: clampedVal <= 0.01
        ? 0
        : (clampedVal >= 0.99 ? width : Math.max(height, (width - gap) * clampedVal))

    // 1. ACTIVE TRACK (Left segment)
    Rectangle {
        id: activeBar
        visible: root.activeWidth > 0
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        height: root.height
        width: root.activeWidth
        radius: root.height / 2
        color: root.colPrimary

        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }

    // 2. INACTIVE TRACK (Right segment with gap)
    Rectangle {
        id: inactiveTrack
        visible: width > 2
        anchors.verticalCenter: parent.verticalCenter
        x: activeBar.width > 0 ? (activeBar.width + root.gap) : 0
        height: root.height
        width: Math.max(0, root.width - x)
        radius: root.height / 2
        color: root.colSecondary
        clip: true

        // M3 Official Stop Dot at the end of inactive track
        Rectangle {
            anchors {
                right: parent.right
                rightMargin: 1
                verticalCenter: parent.verticalCenter
            }
            width: Math.max(2, root.height - 2)
            height: Math.max(2, root.height - 2)
            radius: width / 2
            color: root.colPrimary
            opacity: root.clampedVal < 0.98 ? 0.7 : 0.0
        }
    }
}
