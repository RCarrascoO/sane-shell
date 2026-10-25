pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real value: 50
    property real from: 0
    property real to: 100
    property string icon: "volume_up"
    property bool isMuted: false

    signal moved(real val)
    signal iconClicked()

    implicitHeight: 44
    implicitWidth: 320

    readonly property real ratio: Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property real handleWidth: sliderMouse.pressed ? 6 : 4
    readonly property real handleCenter: Math.max(38, Math.min(width - 42, 38 + ratio * (width - 80)))
    readonly property real gap: 6

    // 1. ACTIVE TRACK (Left)
    Rectangle {
        id: activeTrack
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        height: 40
        width: Math.max(0, root.handleCenter - root.gap - (root.handleWidth / 2))

        topLeftRadius: 16
        bottomLeftRadius: 16
        topRightRadius: 4
        bottomRightRadius: 4

        color: root.isMuted ? Theme.surfaceContainerHighest : Theme.primary
        clip: true

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        // Icon inside active track
        MaterialSymbol {
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: root.icon
            iconSize: 20
            color: root.isMuted ? Theme.error : Theme.onPrimary
        }
    }

    // 2. M3 EXPRESSIVE HANDLE (Center vertical bar with gap)
    Rectangle {
        id: handle
        x: root.handleCenter - (width / 2)
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: 44
        radius: root.handleWidth / 2
        color: root.isMuted ? Theme.onSurfaceVariant : Theme.primary

        Behavior on width {
            NumberAnimation { duration: 100 }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // 3. INACTIVE TRACK (Right)
    Rectangle {
        id: inactiveTrack
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleCenter + root.gap + (root.handleWidth / 2)
        height: 40
        width: Math.max(0, root.width - x)

        topLeftRadius: 4
        bottomLeftRadius: 4
        topRightRadius: 16
        bottomRightRadius: 16

        color: Theme.secondaryContainer
        clip: true

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        // Percentage label
        StyledText {
            anchors {
                right: stopDot.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: `${Math.round(root.value)}%`
            font {
                family: Appearance.font.family.numbers
                pixelSize: 12
                weight: Font.Bold
            }
            color: Theme.onSecondaryContainer
        }

        // M3 Official Stop Dot indicator
        Rectangle {
            id: stopDot
            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            width: 4
            height: 4
            radius: 2
            color: Theme.onSecondaryContainer
        }
    }

    // 4. INTERACTION AREA
    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function updateFromMouse(mouseX) {
            const r = Math.max(0, Math.min(1, (mouseX - 36) / (root.width - 72)));
            const newVal = Math.round(root.from + r * (root.to - root.from));
            if (newVal !== root.value) {
                root.value = newVal;
                root.moved(newVal);
            }
        }

        onClicked: mouse => {
            if (mouse.x <= 36) {
                root.iconClicked();
            } else {
                updateFromMouse(mouse.x);
            }
        }

        onPositionChanged: mouse => {
            if (pressed) {
                updateFromMouse(mouse.x);
            }
        }
    }
}
