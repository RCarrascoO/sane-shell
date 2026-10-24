pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var screenTarget

    screen: screenTarget
    color: Theme.barBackground

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30
    exclusiveZone: 30

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "sane-shell:bar"

    readonly property bool isPrimaryMonitor: (screenTarget?.name ?? "") === "DVI-D-1" || (screenTarget?.width ?? 1360) > (screenTarget?.height ?? 768)

    // Full width bar layout
    Item {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }

        // LEFT: Workspaces (+ Title on Primary)
        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            WorkspacesPill {
                screenName: root.screenTarget?.name ?? "DVI-D-1"
                showTitle: root.isPrimaryMonitor
            }
        }

        // CENTER: Clock (on Primary monitor)
        Item {
            visible: root.isPrimaryMonitor
            anchors.centerIn: parent
            implicitWidth: centerClock.implicitWidth
            implicitHeight: centerClock.implicitHeight

            ClockPill {
                id: centerClock
                compact: false
            }
        }

        // RIGHT: Components
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            // On Secondary monitor, show compact clock on the right
            ClockPill {
                visible: !root.isPrimaryMonitor
                compact: true
            }

            // Primary monitor right cluster
            HardwarePill {
                visible: root.isPrimaryMonitor
            }

            AgyUsage {
                visible: root.isPrimaryMonitor
            }

            SystemPill {
                visible: root.isPrimaryMonitor
            }
        }
    }
}
