pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string screenName: "DVI-D-1"
    property bool showTitle: true

    spacing: 8

    // Workspaces pill container
    Rectangle {
        implicitHeight: 22
        implicitWidth: wsRow.implicitWidth + 16
        radius: 11
        color: Theme.surfaceContainer

        RowLayout {
            id: wsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: NiriState.workspacesFor(root.screenName)

                Rectangle {
                    id: wsRect
                    required property var modelData

                    height: 10
                    radius: 5

                    // Android 16 expressive pill dynamic width
                    width: modelData.isActive ? 26 : (modelData.hasWindows ? 10 : 8)
                    color: modelData.isActive
                        ? Theme.primary
                        : (modelData.hasWindows ? Theme.onSurfaceVariant : Theme.outline)

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NiriState.focusWorkspace(wsRect.modelData.idx)
                    }
                }
            }
        }
    }

    // Active Window Title (only on main monitor)
    Item {
        visible: root.showTitle && (NiriState.activeWindowTitle.length > 0)
        implicitHeight: 22
        implicitWidth: Math.min(260, titleText.implicitWidth + 16)

        Rectangle {
            anchors.fill: parent
            radius: 11
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)

            StyledText {
                id: titleText
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                text: NiriState.activeWindowTitle
                font {
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Medium
                }
                color: Theme.onSurface
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
