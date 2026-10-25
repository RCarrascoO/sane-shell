pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

StyledPopup {
    id: root

    popupId: "quicksettings"
    hoverActivates: false

    property var currentTime: new Date()
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaStatus: "Stopped" // "Playing" | "Paused" | "Stopped"
    property string mediaArtUrl: ""

    function formatTime(d) {
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return `${hh}:${mm}`;
    }

    function formatDate(d) {
        const days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
        const months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        return `${days[d.getDay()]}, ${d.getDate()} de ${months[d.getMonth()]}`;
    }

    contentItem: Rectangle {
        implicitWidth: 380
        implicitHeight: mainLayout.implicitHeight + 32
        color: "transparent"

        Timer {
            interval: 1000
            running: root.shouldBeOpen
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                root.currentTime = new Date();
            }
        }

        Timer {
            interval: 2000
            running: root.shouldBeOpen
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!mediaProcess.running) {
                    mediaProcess.running = true;
                }
            }
        }

        Process {
            id: mediaProcess
            command: ["playerctl", "metadata", "--format", "{{title}}///{{artist}}///{{status}}///{{mpris:artUrl}}"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const raw = text.trim();
                        if (!raw || raw.length === 0) {
                            root.mediaTitle = "";
                            root.mediaArtist = "";
                            root.mediaStatus = "Stopped";
                            root.mediaArtUrl = "";
                            return;
                        }
                        const parts = raw.split("///");
                        root.mediaTitle = (parts[0] || "").trim();
                        root.mediaArtist = (parts[1] || "").trim();
                        root.mediaStatus = (parts[2] || "Stopped").trim();
                        root.mediaArtUrl = (parts[3] || "").trim();
                    } catch(e) {
                        root.mediaTitle = "";
                        root.mediaArtist = "";
                        root.mediaStatus = "Stopped";
                        root.mediaArtUrl = "";
                    }
                }
            }
        }

        ColumnLayout {
            id: mainLayout
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 14

            // 1. TOP PIXEL SHADE HEADER
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    spacing: 1
                    StyledText {
                        text: root.formatTime(root.currentTime)
                        font {
                            family: Appearance.font.family.numbers
                            pixelSize: 28
                            weight: Font.Bold
                        }
                        color: Theme.onSurface
                    }
                    StyledText {
                        text: root.formatDate(root.currentTime)
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 12
                        }
                        color: Theme.onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                // Apps circular button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["fuzzel"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "apps"
                        iconSize: 18
                        color: Theme.onSurface
                    }
                }

                // Audio Mixer circular button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["pavucontrol"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "tune"
                        iconSize: 18
                        color: Theme.onSurface
                    }
                }

                // Screenshot circular button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["niri", "msg", "action", "screenshot"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "photo_camera"
                        iconSize: 18
                        color: Theme.onSurface
                    }
                }
            }

            // 2. M3 TONAL CARD CON M3SLIDER (Split-Track Slider Oficial M3 Expressive)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: m3VolSlider.implicitHeight + 16
                radius: 24
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.outlineVariant

                M3Slider {
                    id: m3VolSlider
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 8
                    }
                    value: SystemStats.volume
                    from: 0
                    to: 100
                    isMuted: SystemStats.isMuted
                    icon: SystemStats.isMuted ? "volume_off" : (SystemStats.volume > 50 ? "volume_up" : "volume_down")
                    onMoved: val => SystemStats.setVolume(val)
                    onIconClicked: SystemStats.toggleMute()
                }
            }

            // 3. 2x3 GRID OF M3 PILL QUICK SETTINGS TILES (height: 58, radius: 29)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                // Tile 1: Internet / Ethernet
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: Theme.primary
                    colBackgroundHover: Theme.primary
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["nm-connection-editor"]);
                    }

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "lan"
                            iconSize: 22
                            color: Theme.onPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Ethernet"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onPrimary
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Conectado"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                elide: Text.ElideRight
                            }
                        }

                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: 16
                            color: Theme.onPrimary
                        }
                    }
                }

                // Tile 2: Sonido / PipeWire
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: SystemStats.isMuted ? Theme.surfaceContainerHigh : Theme.primary
                    colBackgroundHover: SystemStats.isMuted ? Theme.surfaceContainerHighest : Theme.primary
                    onClicked: SystemStats.toggleMute()

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: SystemStats.isMuted ? "volume_off" : "volume_up"
                            iconSize: 22
                            color: SystemStats.isMuted ? Theme.error : Theme.onPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Sonido"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: SystemStats.isMuted ? Theme.onSurface : Theme.onPrimary
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: SystemStats.isMuted ? "Silenciado" : `${SystemStats.volume}% • PipeWire`
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: SystemStats.isMuted
                                    ? Theme.onSurfaceVariant
                                    : Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                elide: Text.ElideRight
                            }
                        }

                        // Subaction indicator
                        MaterialSymbol {
                            text: "tune"
                            iconSize: 16
                            color: SystemStats.isMuted ? Theme.onSurfaceVariant : Theme.onPrimary
                        }
                    }
                }

                // Tile 3: Tema Oscuro con M3Switch
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: Theme.isDark ? Theme.primary : Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.isDark ? Theme.primary : Theme.surfaceContainerHighest
                    onClicked: Theme.toggleTheme()

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 8
                        }
                        spacing: 6

                        MaterialSymbol {
                            text: Theme.isDark ? "dark_mode" : "light_mode"
                            iconSize: 20
                            color: Theme.isDark ? Theme.onPrimary : Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Tema Oscuro"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 11
                                    weight: Font.Bold
                                }
                                color: Theme.isDark ? Theme.onPrimary : Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Theme.isDark ? "Mocha" : "Latte"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: Theme.isDark
                                    ? Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                    : Theme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        // Compact M3 Switch
                        Item {
                            implicitWidth: 36
                            implicitHeight: 22

                            M3Switch {
                                anchors.centerIn: parent
                                scale: 0.7
                                checked: Theme.isDark
                                onToggled: Theme.toggleTheme()
                            }
                        }
                    }
                }

                // Tile 4: Captura
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["niri", "msg", "action", "screenshot"]);
                    }

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "photo_camera"
                            iconSize: 22
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Captura"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Región de pantalla"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: Theme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Tile 5: Rendimiento RX 570
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["corectrl"]);
                    }

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "speed"
                            iconSize: 22
                            color: SystemStats.gpuTemp >= 75 ? Theme.error : Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: `GPU ${SystemStats.gpuTemp}°C`
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: `CPU ${SystemStats.cpuUsage}% • ${SystemStats.ramUsedGb}G`
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: Theme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Tile 6: Portapapeles
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 58
                    buttonRadius: 29
                    colBackground: Theme.surfaceContainerHigh
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["sh", "-c", "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"]);
                    }

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "content_paste"
                            iconSize: 22
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Portapapeles"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Historial Cliphist"
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: 10
                                }
                                color: Theme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // 4. MEDIA PLAYER CARD (MPRIS via playerctl en Theme.secondaryContainer)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                radius: 20
                color: Theme.secondaryContainer
                border.width: 1
                border.color: Theme.outlineVariant

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 10

                    // Thumbnail / Music Icon
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 12
                        color: Theme.surfaceContainerHigh
                        clip: true

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: (root.mediaArtUrl && root.mediaArtUrl.length > 8 && root.mediaArtUrl !== "file:///") ? root.mediaArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !albumArt.visible
                            text: "music_note"
                            iconSize: 22
                            color: Theme.primary
                        }
                    }

                    // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.mediaTitle.length > 0 ? root.mediaTitle : "Sin reproducción multimedia"
                            font {
                                family: Appearance.font.family.main
                                pixelSize: 12
                                weight: Font.Bold
                            }
                            color: Theme.onSecondaryContainer
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.mediaArtist.length > 0 ? root.mediaArtist : "PipeWire MPRIS"
                            font {
                                family: Appearance.font.family.main
                                pixelSize: 10
                            }
                            color: Qt.rgba(Theme.onSecondaryContainer.r, Theme.onSecondaryContainer.g, Theme.onSecondaryContainer.b, 0.75)
                            elide: Text.ElideRight
                        }
                    }

                    // Media Controls (Prev, Squircle Play/Pause, Next)
                    RowLayout {
                        spacing: 6

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Theme.surfaceContainerHighest
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "previous"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 18
                                color: Theme.onSecondaryContainer
                            }
                        }

                        // M3 Expressive Squircle Play/Pause Button (42x42, radius 14)
                        RippleButton {
                            implicitWidth: 42
                            implicitHeight: 42
                            buttonRadius: 14
                            colBackground: Theme.primary
                            colBackgroundHover: Theme.primary
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "play-pause"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.mediaStatus === "Playing" ? "pause" : "play_arrow"
                                iconSize: 22
                                color: Theme.onPrimary
                            }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Theme.surfaceContainerHighest
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "next"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 18
                                color: Theme.onSecondaryContainer
                            }
                        }
                    }
                }
            }

            // 5. ANDROID 16 / M3 BOTTOM FOOTER BAR
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // User pill
                Rectangle {
                    implicitHeight: 34
                    implicitWidth: userRow.implicitWidth + 18
                    radius: 17
                    color: Theme.surfaceContainerLow
                    border.width: 1
                    border.color: Theme.outlineVariant

                    RowLayout {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "account_circle"
                            iconSize: 18
                            color: Theme.primary
                        }

                        StyledText {
                            text: "sane • CachyOS"
                            font {
                                family: Appearance.font.family.main
                                pixelSize: 11
                                weight: Font.Medium
                            }
                            color: Theme.onSurface
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Lock button
                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: 17
                    colBackground: Theme.surfaceContainerLow
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["swaylock"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "lock"
                        iconSize: 16
                        color: Theme.onSurface
                    }
                }

                // Restart Niri/Shell
                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: 17
                    colBackground: Theme.surfaceContainerLow
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["niri", "msg", "action", "load-config-file"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: Theme.onSurface
                    }
                }

                // Power Off
                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: 17
                    colBackground: Theme.surfaceContainerLow
                    colBackgroundHover: Theme.error
                    onClicked: {
                        Theme.activePopup = "";
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        iconSize: 16
                        color: Theme.error
                    }
                }
            }
        }
    }
}
