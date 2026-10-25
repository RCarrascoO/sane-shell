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
        implicitHeight: 24
        implicitWidth: wsRow.implicitWidth + 16
        radius: 12
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

                    // Android 16 expressive dynamic capsule indicators
                    height: modelData.isActive ? 10 : 8
                    radius: modelData.isActive ? 5 : 4
                    width: modelData.isActive ? 28 : (modelData.hasWindows ? 10 : 8)
                    color: modelData.isActive
                        ? Theme.primary
                        : (modelData.hasWindows ? Theme.onSurfaceVariant : Theme.outline)

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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

    // Active Window Title Pill (Capsule showing active app)
    Rectangle {
        visible: root.showTitle && (NiriState.activeWindowTitle.length > 0)
        implicitHeight: 24
        implicitWidth: Math.min(240, titleText.implicitWidth + 20)
        radius: 12
        color: Theme.surfaceContainer

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
