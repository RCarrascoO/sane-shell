pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    property Item hoverTarget: null
    property bool hoverActivates: true
    property bool closeOnOutsideClick: false
    property bool popupHovered: false
    property bool isOpen: false
    default property Item contentItem

    signal requestClose()

    readonly property bool shouldBeOpen: {
        if (isOpen) return true;
        if (!hoverActivates || !hoverTarget) return false;
        return (hoverTarget.containsMouse ?? false) || popupHovered;
    }

    // Floating PanelWindow under the bar
    PanelWindow {
        id: popupWindow
        visible: root.shouldBeOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sane-shell:popup"

        anchors {
            top: true
            left: true
        }

        readonly property real targetX: {
            if (!root.hoverTarget) return 10;
            try {
                const mapPos = root.hoverTarget.mapToItem(null, 0, 0);
                const idealX = mapPos.x + (root.hoverTarget.width - popupContainer.width) / 2;
                const scrWidth = popupWindow.screen?.width ?? 1360;
                return Math.max(10, Math.min(idealX, scrWidth - popupContainer.width - 10));
            } catch(e) {
                return 10;
            }
        }

        margins {
            top: 34
            left: popupWindow.targetX
        }

        implicitWidth: popupContainer.implicitWidth + 20
        implicitHeight: popupContainer.implicitHeight + 20

        MouseArea {
            id: popupMouseArea
            anchors.fill: popupContainer
            hoverEnabled: true
            onContainsMouseChanged: {
                root.popupHovered = containsMouse;
            }
        }

        Rectangle {
            id: popupContainer
            anchors.centerIn: parent
            implicitWidth: root.contentItem ? root.contentItem.implicitWidth : 300
            implicitHeight: root.contentItem ? root.contentItem.implicitHeight : 200

            radius: 20
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline

            // Smooth fade and scale transition
            opacity: popupWindow.visible ? 1.0 : 0.0
            scale: popupWindow.visible ? 1.0 : 0.95

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Item {
                id: contentHolder
                anchors.fill: parent
                children: root.contentItem ? [root.contentItem] : []
            }
        }
    }
}
