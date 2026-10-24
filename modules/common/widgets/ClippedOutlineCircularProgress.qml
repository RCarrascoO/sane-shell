pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property int implicitSize: 18
    property int lineWidth: 2
    property real value: 0
    property color colPrimary: Theme.primary
    property color colSecondary: Qt.rgba(1, 1, 1, 0.15)
    property real gapAngle: 360 / 18
    property bool enableAnimation: true
    property int animationDuration: 600
    property var easingType: Easing.OutCubic

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    property real degree: Math.max(0, Math.min(1, value)) * 360
    property real centerX: root.width / 2
    property real centerY: root.height / 2
    property real arcRadius: root.implicitSize / 2 - root.lineWidth / 2
    property real startAngle: -90

    Behavior on degree {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.colPrimary
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle + root.gapAngle
                sweepAngle: Math.max(0, root.degree - root.gapAngle * 2)
            }
        }

        ShapePath {
            strokeColor: root.colSecondary
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle + root.degree + root.gapAngle
                sweepAngle: Math.max(0, 360 - root.degree - root.gapAngle * 2)
            }
        }
    }
}
