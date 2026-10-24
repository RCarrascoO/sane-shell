pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property bool inirEverywhere: false
    readonly property bool zzzEverywhere: false
    readonly property bool animationsEnabled: true

    readonly property QtObject sizes: QtObject {
        readonly property int barHeight: 24
        readonly property int elevationMargin: 8
        readonly property int verticalBarWidth: 30
    }
    readonly property QtObject rounding: QtObject {
        readonly property int full: 999
        readonly property int normal: 16
        readonly property int small: 10
    }
    readonly property QtObject font: QtObject {
        readonly property QtObject family: QtObject {
            readonly property string main: "Inter"
            readonly property string numbers: "JetBrainsMono Nerd Font"
        }
        readonly property QtObject pixelSize: QtObject {
            readonly property int larger: 15
            readonly property int small: 12
            readonly property int smallie: 11
        }
    }
    readonly property QtObject inir: QtObject {
        readonly property color colText: Theme.onSurface
    }
    readonly property QtObject colors: QtObject {
        readonly property color colLayer0Border: Theme.outline
        readonly property color colLayer0Hover: Theme.surfaceContainerHigh
        readonly property color colLayer1: Theme.surfaceContainer
        readonly property color colLayer1Hover: Theme.surfaceContainerHigh
        readonly property color colOnLayer1: Theme.onSurface
        readonly property color colOnSurface: Theme.onSurface
        readonly property color colOnSurfaceVariant: Theme.onSurfaceVariant
        readonly property color colPrimary: Theme.primary
        readonly property color colSecondary: Theme.secondary
        readonly property color colSubtext: Theme.onSurfaceVariant
        readonly property color colWarning: Theme.warning
        readonly property color colError: Theme.error
        readonly property color colSuccess: Theme.success
        readonly property color colSurface: Theme.surface
        readonly property color colSurfaceContainer: Theme.surfaceContainer
    }
}
