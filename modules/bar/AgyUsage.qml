pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: root

    property var quotaData: null
    readonly property int percentage: quotaData?.primaryPercentage ?? 100
    readonly property real fraction: quotaData?.primaryFraction ?? 1.0
    readonly property bool busy: quotaData?.busy ?? false
    readonly property bool running: quotaData?.running ?? false

    implicitHeight: Appearance.sizes.barHeight
    implicitWidth: contentRow.implicitWidth + 12
    hoverEnabled: true

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            focusProcess.running = true;
        } else if (mouse.button === Qt.RightButton) {
            quotaProcess.running = true;
        }
    }

    // Process to focus or launch Antigravity
    Process {
        id: focusProcess
        command: ["/home/sane/.local/bin/agy-tool", "focus"]
    }

    // Quota fetching process
    Process {
        id: quotaProcess
        command: ["/home/sane/.local/bin/agy-tool", "quota"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.quotaData = data;
                } catch(e) {}
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.busy ? 8000 : 25000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!quotaProcess.running) {
                quotaProcess.running = true;
            }
        }
    }

    // Hover background pill
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        radius: Appearance.rounding.full
        color: root.containsMouse ? Appearance.colors.colLayer0Hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        // Centered Ring indicator with perfectly aligned Gemini icon
        Item {
            implicitWidth: 20
            implicitHeight: 20
            Layout.alignment: Qt.AlignVCenter

            ClippedOutlineCircularProgress {
                anchors.fill: parent
                lineWidth: 2
                value: root.fraction
                colPrimary: root.percentage <= 15
                    ? Appearance.colors.colError
                    : (root.percentage <= 40
                        ? Appearance.colors.colWarning
                        : (Appearance.inirEverywhere ? Appearance.inir.colText : "#52B768"))
                colSecondary: Qt.rgba(1, 1, 1, 0.15)
                enableAnimation: true
            }

            CustomIcon {
                anchors.centerIn: parent
                source: "google-gemini-symbolic"
                width: 12
                height: 12
                colorize: true
                color: root.busy
                    ? Appearance.colors.colPrimary
                    : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant)

                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Percentage text
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: `${root.percentage}%`
            font {
                family: Appearance.zzzEverywhere ? Appearance.font.family.numbers : Appearance.font.family.main
                pixelSize: Appearance.font.pixelSize.small
                weight: Font.Medium
            }
            color: root.percentage <= 15
                ? Appearance.colors.colError
                : (root.percentage <= 40 ? Appearance.colors.colWarning : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1))
        }
    }

    AgyUsagePopup {
        id: usagePopup
        hoverTarget: root
        quotaData: root.quotaData
        isHorizontalScreen: (root.window?.screen?.width ?? 1360) > (root.window?.screen?.height ?? 768)
        onRequestRefresh: {
            if (!quotaProcess.running) {
                quotaProcess.running = true;
            }
        }
    }
}
