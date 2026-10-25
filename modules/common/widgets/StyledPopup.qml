pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    property string popupId: ""
    property Item hoverTarget: null
    property var screenTarget: null
    property bool hoverActivates: false
    property bool closeOnOutsideClick: true
    property bool popupHovered: false
    property bool isOpen: false
    property int keyboardFocus: WlrKeyboardFocus.None
    property int popupY: 6
    default property Item contentItem

    signal requestClose()

    readonly property bool shouldBeOpen: {
        if (hoverTarget && !hoverTarget.visible) return false;
        if (popupId !== "") {
            return Theme.activePopup === popupId;
        }
        if (isOpen) return true;
        if (!hoverActivates || !hoverTarget) return false;
        return (hoverTarget.containsMouse ?? false) || popupHovered;
    }

    // Dismiss any popup when Escape is pressed
    Shortcut {
        sequence: "Escape"
        enabled: root.shouldBeOpen
        onActivated: {
            if (root.popupId !== "") {
                Theme.activePopup = "";
            }
            root.isOpen = false;
            root.requestClose();
        }
    }

    // Floating PanelWindow covering screen below the bar for click-outside dismissal
    PanelWindow {
        id: popupWindow
        visible: root.shouldBeOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sane-shell:popup"
        WlrLayershell.keyboardFocus: root.keyboardFocus
        screen: root.screenTarget ?? null

        readonly property int barHeight: (popupWindow.screen?.name === "DVI-D-1") ? 34 : 30

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        margins {
            top: popupWindow.barHeight
            bottom: 0
            left: 0
            right: 0
        }

        // Click outside area to dismiss popup
        MouseArea {
            id: outsideDismissArea
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: {
                if (root.popupId !== "") {
                    Theme.activePopup = "";
                }
                root.isOpen = false;
                root.requestClose();
            }
        }

        readonly property real targetX: {
            const scrWidth = popupWindow.screen?.width ?? 1360;
            if (!root.hoverTarget) {
                return Math.max(10, (scrWidth - popupContainer.width) / 2);
            }
            try {
                const mapPos = root.hoverTarget.mapToItem(null, 0, 0);
                const idealX = mapPos.x + (root.hoverTarget.width - popupContainer.width) / 2;
                return Math.max(10, Math.min(idealX, scrWidth - popupContainer.width - 10));
            } catch(e) {
                return 10;
            }
        }

        Rectangle {
            id: popupContainer
            x: popupWindow.targetX
            y: root.popupY
            width: root.contentItem ? root.contentItem.implicitWidth : 300
            height: root.contentItem ? root.contentItem.implicitHeight : 200

            radius: 28
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
            clip: true

            // Consume clicks inside container so outside dismissal is not triggered
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {}
                onContainsMouseChanged: {
                    root.popupHovered = containsMouse;
                }
            }

            // Smooth fade and scale transition
            opacity: popupWindow.visible ? 1.0 : 0.0
            scale: popupWindow.visible ? 1.0 : 0.96

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Item {
                id: contentHolder
                anchors.fill: parent
                children: root.contentItem ? [root.contentItem] : []
            }
        }
    }
}
