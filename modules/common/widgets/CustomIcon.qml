pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property bool colorize: false
    property color color: "white"
    property string source: ""
    property string iconFolder: Qt.resolvedUrl(Quickshell.shellPath("assets/icons"))

    implicitWidth: 20
    implicitHeight: 20

    IconImage {
        id: iconImage
        anchors.fill: parent
        source: {
            if (!root.source || root.source.length === 0)
                return "";
            if (root.source.startsWith("/") || root.source.startsWith("file://") || root.source.startsWith("qrc:/"))
                return root.source;
            const customPath = iconFolder + "/" + root.source;
            return customPath;
        }
        implicitSize: root.height
    }

    Loader {
        active: root.colorize
        anchors.fill: iconImage
        sourceComponent: ColorOverlay {
            source: iconImage
            color: root.color
        }
    }
}
