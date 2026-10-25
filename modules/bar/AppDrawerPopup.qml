pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

StyledPopup {
    id: root
    popupId: "appdrawer"
    keyboardFocus: WlrKeyboardFocus.OnDemand
    popupY: 30

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            appsProcess.running = true;
            drawerContent.resetSearch();
        }
    }

    contentItem: Rectangle {
        id: drawerContent
        implicitWidth: 620
        implicitHeight: 520
        radius: 28
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        property var rawApps: []
        property int selectedIndex: 0

        function resetSearch() {
            searchInput.text = "";
            selectedIndex = 0;
            searchInput.forceActiveFocus();
        }

        function filterApps() {
            const q = searchInput.text.trim().toLowerCase();
            filteredModel.clear();
            for (let app of rawApps) {
                if (!q ||
                    app.name.toLowerCase().includes(q) ||
                    (app.genericName && app.genericName.toLowerCase().includes(q)) ||
                    (app.comment && app.comment.toLowerCase().includes(q)) ||
                    (app.categories && app.categories.toLowerCase().includes(q))) {
                    filteredModel.append(app);
                }
            }
            if (selectedIndex >= filteredModel.count) {
                selectedIndex = 0;
            }
        }

        function launchApp(execCmd, terminal) {
            Theme.activePopup = "";
            if (terminal) {
                Quickshell.execDetached(["kitty", "-e", "sh", "-c", execCmd]);
            } else {
                Quickshell.execDetached(["sh", "-c", execCmd + " &"]);
            }
        }

        Process {
            id: appsProcess
            command: ["/home/sane/.local/bin/agy-tool", "apps"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const parsed = JSON.parse(text);
                        if (Array.isArray(parsed)) {
                            drawerContent.rawApps = parsed;
                            drawerContent.filterApps();
                        }
                    } catch(e) {}
                }
            }
        }

        ListModel {
            id: filteredModel
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // 1. M3 Search Bar (Capsule height: 48, radius: 24)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 24
                color: Theme.surfaceContainerHigh
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.primary : Theme.outlineVariant

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialSymbol {
                        text: "search"
                        iconSize: 22
                        color: searchInput.activeFocus ? Theme.primary : Theme.colOnSurfaceVariant
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 13
                        }
                        color: Theme.colOnSurface
                        clip: true
                        selectByMouse: true
                        focus: true

                        onTextChanged: drawerContent.filterApps()

                        Keys.onDownPressed: {
                            if (drawerContent.selectedIndex + 4 < filteredModel.count) {
                                drawerContent.selectedIndex += 4;
                            } else if (filteredModel.count > 0) {
                                drawerContent.selectedIndex = filteredModel.count - 1;
                            }
                            appGrid.positionViewAtIndex(drawerContent.selectedIndex, GridView.Contain);
                        }

                        Keys.onUpPressed: {
                            if (drawerContent.selectedIndex - 4 >= 0) {
                                drawerContent.selectedIndex -= 4;
                            } else {
                                drawerContent.selectedIndex = 0;
                            }
                            appGrid.positionViewAtIndex(drawerContent.selectedIndex, GridView.Contain);
                        }

                        Keys.onLeftPressed: {
                            if (drawerContent.selectedIndex > 0) {
                                drawerContent.selectedIndex--;
                                appGrid.positionViewAtIndex(drawerContent.selectedIndex, GridView.Contain);
                            }
                        }

                        Keys.onRightPressed: {
                            if (drawerContent.selectedIndex + 1 < filteredModel.count) {
                                drawerContent.selectedIndex++;
                                appGrid.positionViewAtIndex(drawerContent.selectedIndex, GridView.Contain);
                            }
                        }

                        Keys.onReturnPressed: {
                            if (filteredModel.count > 0 && drawerContent.selectedIndex >= 0 && drawerContent.selectedIndex < filteredModel.count) {
                                const selected = filteredModel.get(drawerContent.selectedIndex);
                                drawerContent.launchApp(selected.exec, selected.terminal);
                            }
                        }

                        Keys.onEscapePressed: {
                            Theme.activePopup = "";
                        }

                        // Placeholder Text
                        StyledText {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Buscar aplicaciones..."
                            font: searchInput.font
                            color: Theme.colOnSurfaceVariant
                        }
                    }

                    RippleButton {
                        visible: searchInput.text.length > 0
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: Theme.surfaceContainerHighest
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 16
                            color: Theme.colOnSurfaceVariant
                        }
                    }
                }
            }

            // 2. Grid of Applications (4 columns)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    cellWidth: 144
                    cellHeight: 104
                    model: filteredModel

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        required property string name
                        required property string icon
                        required property string exec
                        required property bool terminal
                        required property int index

                        width: 136
                        height: 96

                        readonly property bool isSelected: drawerContent.selectedIndex === index

                        Rectangle {
                            id: appCard
                            anchors.fill: parent
                            radius: 16
                            color: parent.isSelected
                                ? Theme.secondaryContainer
                                : (itemMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                            border.width: parent.isSelected ? 2 : 1
                            border.color: parent.isSelected ? Theme.primary : Theme.outlineVariant

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                width: parent.width - 16

                                // Icon
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 40
                                    implicitHeight: 40

                                    IconImage {
                                        id: appIconImg
                                        anchors.fill: parent
                                        source: Quickshell.iconPath(appCard.parent.icon, "application-x-executable")
                                        visible: status === Image.Ready
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: !appIconImg.visible
                                        text: "apps"
                                        iconSize: 32
                                        color: parent.parent.parent.isSelected ? Theme.colOnSecondaryContainer : Theme.primary
                                    }
                                }

                                // Name
                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: appCard.parent.name
                                    font {
                                        family: Appearance.font.family.main
                                        pixelSize: 11
                                        weight: parent.parent.isSelected ? Font.Bold : Font.Medium
                                    }
                                    color: parent.parent.isSelected ? Theme.colOnSecondaryContainer : Theme.colOnSurface
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    drawerContent.selectedIndex = appCard.parent.index;
                                    drawerContent.launchApp(appCard.parent.exec, appCard.parent.terminal);
                                }
                            }
                        }
                    }
                }

                // Empty state message
                StyledText {
                    anchors.centerIn: parent
                    visible: filteredModel.count === 0 && drawerContent.rawApps.length > 0
                    text: "No se encontraron aplicaciones"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 13
                    }
                    color: Theme.colOnSurfaceVariant
                }
            }
        }
    }
}
