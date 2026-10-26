pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    property QsMenuHandle menuHandle: null
    property QsMenuHandle activeHandle: null
    property var handleHistory: []
    property real targetX: 100

    function open() {
        handleHistory = [];
        activeHandle = menuHandle;
        visible = true;
    }

    function close() {
        visible = false;
        handleHistory = [];
        activeHandle = menuHandle;
    }

    onVisibleChanged: {
        if (!visible) {
            // panel closed
        }
    }

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sane-shell:traymenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int barHeight: (root.screen?.name === "DVI-D-1") ? 34 : 30

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: root.barHeight
        bottom: 0
        left: 0
        right: 0
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.activeHandle ?? root.menuHandle
    }

    // 1. Outside dismiss background
    MouseArea {
        id: outsideDismissArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.close()
    }

    // 2. Card popup positioned relative to targetX
    Rectangle {
        id: card
        x: Math.max(10, Math.min(root.targetX, (root.screen?.width ?? 1360) - width - 10))
        y: 6
        width: Math.max(180, entriesColumn.implicitWidth + 24)
        height: entriesColumn.implicitHeight + 16

        radius: 16
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true

        // Absorb clicks on empty card areas so outside dismiss is not triggered
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: {}
        }

        ColumnLayout {
            id: entriesColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            // Back button when inside a submenu
            RippleButton {
                visible: root.handleHistory.length > 0
                Layout.fillWidth: true
                implicitHeight: 32
                implicitWidth: 160
                buttonRadius: 8
                colBackground: "transparent"
                colBackgroundHover: Theme.surfaceContainerHighest
                onClicked: {
                    const hist = root.handleHistory.slice();
                    const prev = hist.pop();
                    root.handleHistory = hist;
                    root.activeHandle = prev;
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6
                    MaterialSymbol {
                        text: "arrow_back"
                        iconSize: 16
                        color: Theme.primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Volver"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }
            }

            Repeater {
                model: menuOpener.children

                delegate: Item {
                    id: delegateItem
                    required property QsMenuEntry modelData

                    Layout.fillWidth: true
                    implicitWidth: entryRow.implicitWidth + 24
                    implicitHeight: modelData.isSeparator ? 9 : 32

                    // Separator line
                    Rectangle {
                        visible: delegateItem.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // Interactive menu entry
                    Rectangle {
                        id: btnBg
                        visible: !delegateItem.modelData.isSeparator
                        anchors.fill: parent
                        radius: 8
                        color: itemMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                        opacity: delegateItem.modelData.enabled ? 1.0 : 0.45

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: delegateItem.modelData.enabled
                            cursorShape: delegateItem.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: {
                                if (!delegateItem.modelData.enabled) return;
                                if (delegateItem.modelData.hasChildren) {
                                    const hist = root.handleHistory.slice();
                                    hist.push(root.activeHandle ?? root.menuHandle);
                                    root.handleHistory = hist;
                                    root.activeHandle = delegateItem.modelData;
                                    return;
                                }
                                delegateItem.modelData.triggered();
                                root.close();
                            }
                        }

                        RowLayout {
                            id: entryRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Optional checkbox/radio icon
                            Item {
                                visible: delegateItem.modelData.buttonType !== QsMenuButtonType.None
                                implicitWidth: 16
                                implicitHeight: 16

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: delegateItem.modelData.checkState === Qt.Checked ? "check" : ""
                                    color: Theme.primary
                                }
                            }

                            // Optional Entry Icon
                            Item {
                                visible: delegateItem.modelData.icon.length > 0
                                implicitWidth: 16
                                implicitHeight: 16

                                IconImage {
                                    anchors.centerIn: parent
                                    source: delegateItem.modelData.icon
                                    implicitWidth: 16
                                    implicitHeight: 16
                                }
                            }

                            // Text Label
                            StyledText {
                                Layout.fillWidth: true
                                text: delegateItem.modelData.text
                                font.pixelSize: 13
                                color: Theme.colOnSurface
                                elide: Text.ElideRight
                            }

                            // Submenu indicator
                            MaterialSymbol {
                                visible: delegateItem.modelData.hasChildren
                                iconSize: 16
                                text: "chevron_right"
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
