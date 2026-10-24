pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool compact: false

    implicitHeight: 22
    implicitWidth: clockContent.implicitWidth + 20
    radius: 11
    color: clockMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    property var currentTime: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    function formatTime(d) {
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        return `${hh}:${mm}`;
    }

    function formatDate(d) {
        const days = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
        const months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
        return `${days[d.getDay()]} ${d.getDate()} ${months[d.getMonth()]}`;
    }

    RowLayout {
        id: clockContent
        anchors.centerIn: parent
        spacing: 6

        StyledText {
            text: root.compact
                ? root.formatTime(root.currentTime)
                : `${root.formatTime(root.currentTime)}  •  ${root.formatDate(root.currentTime)}`
            font {
                family: Appearance.font.family.numbers
                pixelSize: Appearance.font.pixelSize.smallie
                weight: Font.Medium
            }
            color: Theme.onSurface
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: calPopup.isOpen = !calPopup.isOpen
    }

    // Calendar Popup
    StyledPopup {
        id: calPopup
        hoverTarget: root
        hoverActivates: false

        contentItem: Rectangle {
            implicitWidth: 260
            implicitHeight: calCol.implicitHeight + 24
            color: "transparent"

            ColumnLayout {
                id: calCol
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: {
                            const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                            return `${months[root.currentTime.getMonth()]} ${root.currentTime.getFullYear()}`;
                        }
                        font {
                            pixelSize: Appearance.font.pixelSize.larger
                            weight: Font.Bold
                        }
                        color: Theme.primary
                    }
                    Item { Layout.fillWidth: true }
                }

                // Days of week header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        StyledText {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.onSurfaceVariant
                        }
                    }
                }

                // Days grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4

                    readonly property var daysList: {
                        const year = root.currentTime.getFullYear();
                        const month = root.currentTime.getMonth();
                        const firstDayIndex = (new Date(year, month, 1).getDay() + 6) % 7; // Mon = 0
                        const totalDays = new Date(year, month + 1, 0).getDate();
                        const today = root.currentTime.getDate();

                        const res = [];
                        for (let i = 0; i < firstDayIndex; i++) {
                            res.push({ day: 0, isToday: false });
                        }
                        for (let d = 1; d <= totalDays; d++) {
                            res.push({ day: d, isToday: d === today });
                        }
                        return res;
                    }

                    Repeater {
                        model: parent.daysList

                        Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: modelData.isToday ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                visible: parent.modelData.day > 0
                                text: String(parent.modelData.day)
                                font {
                                    family: Appearance.font.family.numbers
                                    pixelSize: 11
                                    weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                }
                                color: parent.modelData.isToday ? Theme.onPrimary : Theme.onSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
