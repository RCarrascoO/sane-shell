pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool compact: false
    property var screenTarget: null
    readonly property bool isPopupOpen: Theme.activePopup === "calendar"

    implicitHeight: 26
    implicitWidth: clockContent.implicitWidth + 20
    radius: 13
    color: isPopupOpen
        ? Theme.primary
        : (clockMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)

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
        return `${days[d.getDay()]}, ${d.getDate()} ${months[d.getMonth()]}`;
    }

    function formatBigDate(d) {
        const days = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
        const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
        return `${days[d.getDay()]}, ${d.getDate()} de ${months[d.getMonth()]}`;
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
                weight: Font.DemiBold
            }
            color: root.isPopupOpen ? Theme.onPrimary : Theme.onSurface
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            Theme.activePopup = (Theme.activePopup === "calendar") ? "" : "calendar";
        }
    }

    // M3 Official Docked Date Picker Popup (m3.material.io/components/date-pickers/specs)
    StyledPopup {
        id: calPopup
        popupId: "calendar"
        hoverTarget: root
        screenTarget: root.screenTarget
        hoverActivates: false

        contentItem: Rectangle {
            implicitWidth: 320
            implicitHeight: calCol.implicitHeight + 32
            color: "transparent"

            ColumnLayout {
                id: calCol
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 12

                // 1. M3 HEADER: "FECHA ACTUAL" Label + Big Date
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "FECHA ACTUAL"
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 11
                            weight: Font.DemiBold
                            letterSpacing: 1.2
                        }
                        color: Theme.onSurfaceVariant
                    }

                    StyledText {
                        text: root.formatBigDate(root.currentTime)
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 24
                            weight: Font.Bold
                        }
                        color: Theme.onSurface
                    }
                }

                // Month / Year Row
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: {
                            const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                            return `${months[root.currentTime.getMonth()]} ${root.currentTime.getFullYear()}`;
                        }
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 14
                            weight: Font.DemiBold
                        }
                        color: Theme.primary
                    }
                    Item { Layout.fillWidth: true }
                }

                // M3 Divider line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outlineVariant
                }

                // 2. DAYS OF WEEK HEADER (L M X J V S D)
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
                            font {
                                family: Appearance.font.family.main
                                pixelSize: 11
                                weight: Font.Bold
                            }
                            color: Theme.onSurfaceVariant
                        }
                    }
                }

                // 3. DAYS GRID (M3 36x36 Circle for Today)
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
                            id: dayCell
                            required property var modelData
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: modelData.isToday
                                ? Theme.primary
                                : (dayMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")

                            Behavior on color { ColorAnimation { duration: 120 } }

                            StyledText {
                                anchors.centerIn: parent
                                visible: parent.modelData.day > 0
                                text: String(parent.modelData.day)
                                font {
                                    family: Appearance.font.family.numbers
                                    pixelSize: 12
                                    weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                }
                                color: parent.modelData.isToday ? Theme.onPrimary : Theme.onSurface
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: parent.modelData.day > 0
                                enabled: parent.modelData.day > 0
                            }
                        }
                    }
                }
            }
        }
    }
}
