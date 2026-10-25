pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: root

    required property var screenTarget

    screen: screenTarget
    color: Theme.barBackground

    readonly property bool isPrimaryMonitor: (screenTarget?.name ?? "") === "DVI-D-1"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: isPrimaryMonitor ? 34 : 30
    exclusiveZone: isPrimaryMonitor ? 34 : 30

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "sane-shell:bar"

    // Subtle bottom border
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: Theme.outlineVariant
    }

    // Bar contents
    Item {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }

        // LEFT CLUSTER: M3 Segmented Group (Apps Button + Workspaces)
        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            // App Launcher Button (M3 Segment con Workspaces)
            Rectangle {
                implicitHeight: 26
                implicitWidth: 34
                topLeftRadius: 13
                bottomLeftRadius: 13
                topRightRadius: 4
                bottomRightRadius: 4
                color: launcherMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.primaryContainer

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "apps"
                    iconSize: 16
                    color: Theme.onPrimaryContainer
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["fuzzel"])
                }
            }

            WorkspacesPill {
                screenName: root.screenTarget?.name ?? "DVI-D-1"
                showTitle: root.isPrimaryMonitor
            }
        }

        // CENTER CLUSTER: Clock (Primary Monitor)
        ClockPill {
            id: centerClock
            visible: root.isPrimaryMonitor
            anchors.centerIn: parent
            compact: false
            screenTarget: root.screenTarget
        }

        // RIGHT CLUSTER: M3 Segmented Elements
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            // Secondary monitor: compact clock
            ClockPill {
                visible: !root.isPrimaryMonitor
                compact: true
                screenTarget: root.screenTarget
            }

            // Primary monitor right cluster
            HardwarePill {
                visible: root.isPrimaryMonitor
            }

            AgyUsage {
                visible: root.isPrimaryMonitor
                screenTarget: root.screenTarget
            }

            // M3 Segmented Group (Tray + System Cluster)
            RowLayout {
                visible: root.isPrimaryMonitor
                spacing: 2

                TrayPill {
                    id: trayPill
                    visible: SystemTray.items.values.length > 0
                }

                SystemPill {
                    screenTarget: root.screenTarget
                    hasLeftSibling: trayPill.visible
                }
            }
        }
    }
}
