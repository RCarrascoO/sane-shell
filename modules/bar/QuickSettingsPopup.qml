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
                        font.pixelSize: 12
                        color: Theme.onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                // Apps circular button
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: Theme.surfaceContainer
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
                    colBackground: Theme.surfaceContainer
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
                    colBackground: Theme.surfaceContainer
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

            // 2. THICK ANDROID 16 PILL VOLUME SLIDER (44px)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 22
                color: Theme.surfaceContainerHigh
                clip: true

                // Filled Bar
                Rectangle {
                    id: volFill
                    height: parent.height
                    width: Math.max(44, parent.width * (SystemStats.volume / 100.0))
                    radius: 22
                    color: SystemStats.isMuted ? Theme.surfaceContainerHighest : Theme.primary

                    Behavior on width {
                        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                    }
                }

                // Inside items: Icon & Volume Percentage
                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 16
                    }

                    MaterialSymbol {
                        text: SystemStats.isMuted ? "volume_off" : (SystemStats.volume > 50 ? "volume_up" : "volume_down")
                        iconSize: 20
                        color: SystemStats.isMuted ? Theme.error : Theme.onPrimary
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: `${SystemStats.volume}%`
                        font {
                            family: Appearance.font.family.numbers
                            pixelSize: 12
                            weight: Font.Bold
                        }
                        color: (SystemStats.volume > 20 && !SystemStats.isMuted) ? Theme.onPrimary : Theme.onSurface
                    }
                }

                // Drag / Click area
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateVol(mouse) {
                        const ratio = Math.max(0, Math.min(1, mouse.x / width));
                        SystemStats.setVolume(Math.round(ratio * 100));
                    }
                    onClicked: mouse => {
                        if (mouse.x <= 44) {
                            SystemStats.toggleMute();
                        } else {
                            updateVol(mouse);
                        }
                    }
                    onPositionChanged: mouse => {
                        if (pressed) updateVol(mouse);
                    }
                }
            }

            // 3. 2x3 GRID OF ANDROID 16 PILL QUICK SETTINGS TILES (height: 58, radius: 29)
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
                            rightMargin: 16
                        }
                        spacing: 12

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
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onPrimary
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Conectado"
                                font.pixelSize: 10
                                color: Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                elide: Text.ElideRight
                            }
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
                            rightMargin: 16
                        }
                        spacing: 12

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
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: SystemStats.isMuted ? Theme.onSurface : Theme.onPrimary
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: SystemStats.isMuted ? "Silenciado" : `${SystemStats.volume}% • PipeWire`
                                font.pixelSize: 10
                                color: SystemStats.isMuted
                                    ? Theme.onSurfaceVariant
                                    : Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Tile 3: Tema Oscuro
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
                            leftMargin: 16
                            rightMargin: 16
                        }
                        spacing: 12

                        MaterialSymbol {
                            text: Theme.isDark ? "dark_mode" : "light_mode"
                            iconSize: 22
                            color: Theme.isDark ? Theme.onPrimary : Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: "Tema Oscuro"
                                font {
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.isDark ? Theme.onPrimary : Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Theme.isDark ? "Catppuccin Mocha" : "Catppuccin Latte"
                                font.pixelSize: 10
                                color: Theme.isDark
                                    ? Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8)
                                    : Theme.onSurfaceVariant
                                elide: Text.ElideRight
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
                            rightMargin: 16
                        }
                        spacing: 12

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
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Región de pantalla"
                                font.pixelSize: 10
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
                            rightMargin: 16
                        }
                        spacing: 12

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
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: `CPU ${SystemStats.cpuUsage}% • ${SystemStats.ramUsedGb}G`
                                font.pixelSize: 10
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
                            rightMargin: 16
                        }
                        spacing: 12

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
                                    pixelSize: 12
                                    weight: Font.Bold
                                }
                                color: Theme.onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Historial Cliphist"
                                font.pixelSize: 10
                                color: Theme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // 4. MEDIA PLAYER CARD (MPRIS via playerctl)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 20
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outline

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    // Thumbnail / Music Icon
                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 42
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
                                pixelSize: 12
                                weight: Font.Bold
                            }
                            color: Theme.onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.mediaArtist.length > 0 ? root.mediaArtist : "PipeWire MPRIS"
                            font.pixelSize: 10
                            color: Theme.onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    // Media Controls (Prev, Play/Pause, Next)
                    RowLayout {
                        spacing: 4

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Theme.surfaceContainerHigh
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "previous"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 18
                                color: Theme.onSurface
                            }
                        }

                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: Theme.primary
                            colBackgroundHover: Theme.primary
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "play-pause"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.mediaStatus === "Playing" ? "pause" : "play_arrow"
                                iconSize: 20
                                color: Theme.onPrimary
                            }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Theme.surfaceContainerHigh
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "next"]);
                                mediaProcess.running = true;
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 18
                                color: Theme.onSurface
                            }
                        }
                    }
                }
            }

            // 5. ANDROID 16 BOTTOM FOOTER BAR
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // User pill
                Rectangle {
                    implicitHeight: 32
                    implicitWidth: userRow.implicitWidth + 16
                    radius: 16
                    color: Theme.surfaceContainer

                    RowLayout {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "account_circle"
                            iconSize: 16
                            color: Theme.primary
                        }

                        StyledText {
                            text: "sane • CachyOS"
                            font {
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
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: Theme.surfaceContainer
                    colBackgroundHover: Theme.surfaceContainerHigh
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
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: Theme.surfaceContainer
                    colBackgroundHover: Theme.surfaceContainerHigh
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
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: Theme.surfaceContainer
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
