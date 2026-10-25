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
        readonly property int full: Theme.shape.full
        readonly property int extraLarge: Theme.shape.extraLarge
        readonly property int large: Theme.shape.large
        readonly property int medium: Theme.shape.medium
        readonly property int small: Theme.shape.small
        readonly property int extraSmall: Theme.shape.extraSmall
        readonly property int normal: Theme.shape.large
    }

    readonly property QtObject font: QtObject {
        readonly property QtObject family: QtObject {
            readonly property string main: "Roboto Flex"
            readonly property string numbers: "JetBrainsMono Nerd Font"
        }
        readonly property QtObject pixelSize: QtObject {
            readonly property int larger: 15
            readonly property int small: 12
            readonly property int smallie: 11
        }
    }

    readonly property QtObject inir: QtObject {
        readonly property color colText: Theme.colOnSurface
    }

    readonly property QtObject colors: QtObject {
        readonly property color colLayer0Border: Theme.outline
        readonly property color colLayer0Hover: Theme.surfaceContainerHighest
        readonly property color colLayer1: Theme.surfaceContainer
        readonly property color colLayer1Hover: Theme.surfaceContainerHigh
        readonly property color colOnLayer1: Theme.colOnSurface
        readonly property color colOnSurface: Theme.colOnSurface
        readonly property color colOnSurfaceVariant: Theme.colOnSurfaceVariant
        readonly property color colPrimary: Theme.primary
        readonly property color colSecondary: Theme.secondary
        readonly property color colSubtext: Theme.colOnSurfaceVariant
        readonly property color colWarning: Theme.warning
        readonly property color colError: Theme.error
        readonly property color colSuccess: Theme.success
        readonly property color colSurface: Theme.surface
        readonly property color colSurfaceContainer: Theme.surfaceContainer
        readonly property color colSurfaceContainerLow: Theme.surfaceContainerLow
        readonly property color colSurfaceContainerHigh: Theme.surfaceContainerHigh
    }
}
