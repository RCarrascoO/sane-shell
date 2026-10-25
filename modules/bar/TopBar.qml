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
        color: Theme.surfaceContainerHigh
    }

    // Bar contents
    Item {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }

        // LEFT CLUSTER: Pixel App Launcher + Workspaces (+ Title on Primary)
        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            // App Launcher Button (Pixel Apps Pill)
            Rectangle {
                implicitHeight: 24
                implicitWidth: 32
                radius: 12
                color: launcherMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "apps"
                    iconSize: 16
                    color: Theme.primary
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

        // RIGHT CLUSTER
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

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

            TrayPill {
                visible: root.isPrimaryMonitor && (SystemTray.items.values.length > 0)
            }

            SystemPill {
                visible: root.isPrimaryMonitor
                screenTarget: root.screenTarget
            }
        }
    }
}
