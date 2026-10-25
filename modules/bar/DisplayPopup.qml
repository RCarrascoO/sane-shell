pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

StyledPopup {
    id: root
    popupId: "displays"

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            displaysProcess.running = true;
        }
    }

    contentItem: Rectangle {
        id: popupContent
        implicitWidth: 500
        implicitHeight: 510
        radius: 28
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        property var displaysData: []

        Process {
            id: displaysProcess
            command: ["/home/sane/.local/bin/agy-tool", "displays"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const parsed = JSON.parse(text);
                        if (Array.isArray(parsed)) {
                            popupContent.displaysData = parsed;
                        }
                    } catch(e) {}
                }
            }
        }

        function applyDisplay(outName, mode, tf, pos) {
            Quickshell.execDetached(["/home/sane/.local/bin/agy-tool", "set-display", outName, mode || "-", tf || "-", pos || "-"]);
            reloadTimer.restart();
        }

        Timer {
            id: reloadTimer
            interval: 350
            repeat: false
            onTriggered: {
                if (!displaysProcess.running) displaysProcess.running = true;
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 18
            contentHeight: contentCol.implicitHeight
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 14

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: "display_settings"
                        iconSize: 22
                        color: Theme.primary
                    }

                    StyledText {
                        text: "Pantallas y Luz Nocturna"
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 16
                            weight: Font.Bold
                        }
                        color: Theme.colOnSurface
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: Theme.surfaceContainerHigh
                        colBackgroundHover: Theme.surfaceContainerHighest
                        onClicked: Theme.activePopup = ""

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 16
                            color: Theme.colOnSurface
                        }
                    }
                }

                // ==========================================
                // SECCIÓN 1: LUZ NOCTURNA (wlsunset)
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: nlCol.implicitHeight + 24
                    radius: 20
                    color: Theme.surfaceContainerLow
                    border.width: 1
                    border.color: Theme.outlineVariant

                    ColumnLayout {
                        id: nlCol
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 10

                        // Switch & status header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                text: "nightlight"
                                iconSize: 20
                                color: SystemStats.nightLightActive ? Theme.warning : Theme.colOnSurfaceVariant
                            }

                            StyledText {
                                text: "Luz Nocturna"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 13
                                    weight: Font.Bold
                                }
                                color: Theme.colOnSurface
                            }

                            Rectangle {
                                implicitHeight: 22
                                implicitWidth: tempLabel.implicitWidth + 14
                                radius: 11
                                color: SystemStats.nightLightActive ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                                StyledText {
                                    id: tempLabel
                                    anchors.centerIn: parent
                                    text: `${SystemStats.nightLightTemp}K`
                                    font {
                                        family: Appearance.font.family.numbers
                                        pixelSize: 11
                                        weight: Font.DemiBold
                                    }
                                    color: SystemStats.nightLightActive ? Theme.colOnSecondaryContainer : Theme.colOnSurfaceVariant
                                }
                            }

                            Item { Layout.fillWidth: true }

                            M3Switch {
                                checked: SystemStats.nightLightActive
                                onToggled: SystemStats.toggleNightLight()
                            }
                        }

                        // M3 Temperature Slider
                        M3Slider {
                            Layout.fillWidth: true
                            from: 2500
                            to: 6000
                            value: SystemStats.nightLightTemp
                            icon: "thermostat"
                            onMoved: val => SystemStats.setNightLightTemp(val)
                        }

                        // Quick Kelvin Presets
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "2800K Cálido+", temp: 2800 },
                                    { label: "3500K Noche", temp: 3500 },
                                    { label: "4000K Normal", temp: 4000 },
                                    { label: "5000K Suave", temp: 5000 }
                                ]

                                RippleButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    buttonRadius: 14
                                    colBackground: (SystemStats.nightLightTemp === modelData.temp)
                                        ? Theme.primary
                                        : Theme.surfaceContainerHigh
                                    colBackgroundHover: (SystemStats.nightLightTemp === modelData.temp)
                                        ? Theme.primary
                                        : Theme.surfaceContainerHighest
                                    onClicked: {
                                        SystemStats.setNightLightTemp(modelData.temp);
                                    }

                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData.label
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: 10
                                            weight: Font.Medium
                                        }
                                        color: (SystemStats.nightLightTemp === parent.parent.modelData.temp)
                                            ? Theme.colOnPrimary
                                            : Theme.colOnSurface
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // SECCIÓN 2: MONITORES Y RESOLUCIONES (Niri)
                // ==========================================
                StyledText {
                    text: "Monitores y Configuración de Pantalla"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 13
                        weight: Font.Bold
                    }
                    color: Theme.colOnSurface
                }

                Repeater {
                    model: popupContent.displaysData

                    Rectangle {
                        required property var modelData
                        id: monitorCard
                        Layout.fillWidth: true
                        implicitHeight: monCol.implicitHeight + 20
                        radius: 18
                        color: Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Theme.outlineVariant

                        ColumnLayout {
                            id: monCol
                            anchors {
                                fill: parent
                                margins: 12
                            }
                            spacing: 8

                            // Monitor Header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialSymbol {
                                    text: (monitorCard.modelData.transform === "90" || monitorCard.modelData.transform === "270")
                                        ? "stay_current_portrait"
                                        : "desktop_windows"
                                    iconSize: 20
                                    color: Theme.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        text: `${monitorCard.modelData.name} • ${monitorCard.modelData.model}`
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: 12
                                            weight: Font.Bold
                                        }
                                        color: Theme.colOnSurface
                                    }

                                    StyledText {
                                        text: `Actual: ${monitorCard.modelData.currentMode} (${monitorCard.modelData.transform})`
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: 10
                                        }
                                        color: Theme.colOnSurfaceVariant
                                    }
                                }
                            }

                            // Resolution Mode Chips
                            StyledText {
                                text: "Modos de Resolución:"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                    weight: Font.DemiBold
                                }
                                color: Theme.colOnSurfaceVariant
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: monitorCard.modelData.modes ? monitorCard.modelData.modes.slice(0, 5) : []

                                    RippleButton {
                                        required property string modelData
                                        implicitHeight: 26
                                        implicitWidth: resText.implicitWidth + 16
                                        buttonRadius: 13
                                        readonly property bool isCurrent: monitorCard.modelData.currentMode === modelData
                                        colBackground: isCurrent ? Theme.primary : Theme.surfaceContainerHigh
                                        colBackgroundHover: isCurrent ? Theme.primary : Theme.surfaceContainerHighest
                                        onClicked: {
                                            popupContent.applyDisplay(monitorCard.modelData.name, modelData, monitorCard.modelData.transform, "-");
                                        }

                                        contentItem: StyledText {
                                            id: resText
                                            anchors.centerIn: parent
                                            text: parent.parent.modelData
                                            font {
                                                family: Appearance.font.family.numbers
                                                pixelSize: 10
                                                weight: Font.Medium
                                            }
                                            color: parent.parent.isCurrent ? Theme.colOnPrimary : Theme.colOnSurface
                                        }
                                    }
                                }
                            }

                            // Orientation / Rotation Chips
                            StyledText {
                                text: "Orientación:"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                    weight: Font.DemiBold
                                }
                                color: Theme.colOnSurfaceVariant
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: [
                                        { label: "Normal (0°)", tf: "Normal" },
                                        { label: "Vertical (90°)", tf: "90" },
                                        { label: "Invertido (180°)", tf: "180" },
                                        { label: "Vertical (270°)", tf: "270" }
                                    ]

                                    RippleButton {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 26
                                        buttonRadius: 13
                                        readonly property bool isCurrent: monitorCard.modelData.transform.toLowerCase() === modelData.tf.toLowerCase()
                                        colBackground: isCurrent ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                                        colBackgroundHover: isCurrent ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                                        onClicked: {
                                            popupContent.applyDisplay(monitorCard.modelData.name, "-", modelData.tf, "-");
                                        }

                                        contentItem: StyledText {
                                            anchors.centerIn: parent
                                            text: parent.parent.modelData.label
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: 9
                                                weight: Font.Medium
                                            }
                                            color: parent.parent.isCurrent ? Theme.colOnSecondaryContainer : Theme.colOnSurface
                                        }
                                    }
                                }
                            }

                            // Position Chips (only for secondary monitor HDMI-A-1)
                            ColumnLayout {
                                visible: monitorCard.modelData.name === "HDMI-A-1"
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    text: "Posición respecto al Monitor Principal:"
                                    font {
                                        family: Appearance.font.family.main
                                        pixelSize: 10
                                        weight: Font.DemiBold
                                    }
                                    color: Theme.colOnSurfaceVariant
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { label: "A la Derecha", pos: "right" },
                                            { label: "A la Izquierda", pos: "left" },
                                            { label: "Arriba", pos: "above" },
                                            { label: "Abajo", pos: "below" }
                                        ]

                                        RippleButton {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 26
                                            buttonRadius: 13
                                            readonly property bool isCurrent: (modelData.pos === "right" && monitorCard.modelData.x >= 1360) || (modelData.pos === "left" && monitorCard.modelData.x < 0)
                                            colBackground: isCurrent ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                                            colBackgroundHover: isCurrent ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                                            onClicked: {
                                                popupContent.applyDisplay(monitorCard.modelData.name, "-", "-", modelData.pos);
                                            }

                                            contentItem: StyledText {
                                                anchors.centerIn: parent
                                                text: parent.parent.modelData.label
                                                font {
                                                    family: Appearance.font.family.main
                                                    pixelSize: 9
                                                    weight: Font.Medium
                                                }
                                                color: parent.parent.isCurrent ? Theme.colOnSecondaryContainer : Theme.colOnSurface
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
