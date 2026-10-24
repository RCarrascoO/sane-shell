pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Item {
    id: root

    property real iconSize: 16
    property real fill: 0
    property string text: ""
    property color color: Theme.onSurface
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignVCenter

    implicitWidth: iconSize
    implicitHeight: iconSize

    Text {
        id: iconText
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        text: root.text
        color: root.color
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        renderType: Text.NativeRendering

        font {
            family: "Material Symbols Rounded"
            pixelSize: root.iconSize
        }
    }
}
