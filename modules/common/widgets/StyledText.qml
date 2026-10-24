pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Text {
    id: root

    property bool animateChange: false
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    property var defaultFont: shouldUseNumberFont ? Appearance.font.family.numbers : Appearance.font.family.main

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: defaultFont
        pixelSize: Appearance.font.pixelSize.small
    }
    color: Theme.onSurface
    linkColor: Theme.primary
}
