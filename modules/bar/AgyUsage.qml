pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var screenTarget: null
    property var quotaData: null
    readonly property int percentage: quotaData?.primaryPercentage ?? 100
    readonly property real fraction: quotaData?.primaryFraction ?? 1.0
    readonly property bool busy: quotaData?.busy ?? false
    readonly property bool running: quotaData?.running ?? false
    readonly property bool isPopupOpen: Theme.activePopup === "agy"

    implicitHeight: 26
    implicitWidth: contentRow.implicitWidth + 20
    radius: 13
    color: isPopupOpen
        ? Theme.primary
        : (agyMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.secondaryContainer)

    Behavior on color {
        ColorAnimation { duration: 150 }
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

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // Centered Ring indicator with perfectly aligned Gemini icon
        Item {
            implicitWidth: 16
            implicitHeight: 16
            Layout.alignment: Qt.AlignVCenter

            ClippedOutlineCircularProgress {
                anchors.fill: parent
                lineWidth: 2
                value: root.fraction
                colPrimary: root.isPopupOpen
                    ? Theme.onPrimary
                    : (root.percentage <= 15
                        ? Theme.error
                        : (root.percentage <= 40 ? Theme.warning : Theme.secondary))
                colSecondary: root.isPopupOpen ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(1, 1, 1, 0.15)
                enableAnimation: true
            }

            CustomIcon {
                anchors.centerIn: parent
                source: "google-gemini-symbolic"
                width: 10
                height: 10
                colorize: true
                color: root.isPopupOpen
                    ? Theme.onPrimary
                    : (root.busy ? Theme.primary : Theme.onSecondaryContainer)

                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Percentage text en color tonal M3
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: `${root.percentage}%`
            font {
                family: Appearance.font.family.numbers
                pixelSize: Appearance.font.pixelSize.smallie
                weight: Font.DemiBold
            }
            color: root.isPopupOpen
                ? Theme.onPrimary
                : (root.percentage <= 15 ? Theme.error : (root.percentage <= 40 ? Theme.warning : Theme.onSecondaryContainer))
        }
    }

    MouseArea {
        id: agyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                Theme.activePopup = (Theme.activePopup === "agy") ? "" : "agy";
            } else if (mouse.button === Qt.MiddleButton) {
                focusProcess.running = true;
            } else if (mouse.button === Qt.RightButton) {
                quotaProcess.running = true;
            }
        }
    }

    AgyUsagePopup {
        id: usagePopup
        hoverTarget: root
        screenTarget: root.screenTarget
        quotaData: root.quotaData
        isHorizontalScreen: (root.window?.screen?.width ?? 1360) > (root.window?.screen?.height ?? 768)
        onRequestRefresh: {
            if (!quotaProcess.running) {
                quotaProcess.running = true;
            }
        }
    }
}
