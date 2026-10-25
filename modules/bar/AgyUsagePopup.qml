pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: popup
    popupId: "agy"
    hoverActivates: false

    property var quotaData: null
    property bool isHorizontalScreen: true
    signal requestRefresh()

    // Dynamic filtering of groups: Antigravity IDE groups vs Zen Browser
    readonly property var allGroups: popup.quotaData?.groups ?? []
    readonly property var ideGroups: {
        const res = [];
        for (let i = 0; i < allGroups.length; i++) {
            if (allGroups[i].displayName !== "Gemini Web (Zen)") {
                res.push(allGroups[i]);
            }
        }
        return res;
    }
    readonly property var webGroup: {
        for (let i = 0; i < allGroups.length; i++) {
            if (allGroups[i].displayName === "Gemini Web (Zen)") {
                return allGroups[i];
            }
        }
        return null;
    }

    // Extract dynamic web model tag if available from description e.g. "Zen Browser (Gemini Pro - Flash Alto)"
    readonly property string webModelName: {
        if (!popup.webGroup || !popup.webGroup.description) return "Flash Alto";
        const parts = popup.webGroup.description.split("-");
        if (parts.length > 1) {
            return parts[parts.length - 1].replace(")", "").trim();
        }
        return "Flash Alto";
    }

    // ==========================================
    // REUSABLE COMPONENT: QuotaBucketItem
    // ==========================================
    component QuotaBucketItem: ColumnLayout {
        id: bucketItem
        required property var bucketData
        Layout.fillWidth: true
        spacing: 3

        // Metric label + percentage
        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: bucketItem.bucketData.displayName
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }

            StyledText {
                text: `${bucketItem.bucketData.percentage}%`
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                    weight: Font.Bold
                }
                color: bucketItem.bucketData.percentage <= 15
                    ? Appearance.colors.colError
                    : (bucketItem.bucketData.percentage <= 40 ? Appearance.colors.colWarning : Appearance.colors.colOnLayer1)
            }
        }

        // Modern horizontal progress track
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, bucketItem.bucketData.fraction))
                height: parent.height
                radius: 2
                color: bucketItem.bucketData.percentage <= 15
                    ? Appearance.colors.colError
                    : (bucketItem.bucketData.percentage <= 40 ? Appearance.colors.colWarning : "#52B768")

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }

        // Countdown reset text
        RowLayout {
            visible: (bucketItem.bucketData.resetIn ?? "").length > 0
            spacing: 4
            MaterialSymbol {
                text: "schedule"
                iconSize: 11
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: (bucketItem.bucketData.displayName.includes("Uso actual") || bucketItem.bucketData.displayName.includes("semanal"))
                    ? Translation.tr("Se restablece en %1").arg(bucketItem.bucketData.resetIn)
                    : Translation.tr("Resets in %1").arg(bucketItem.bucketData.resetIn)
                font.pixelSize: Appearance.font.pixelSize.smallie - 1
                color: Appearance.colors.colSubtext
            }
        }

        Item { height: 2 }
    }

    // ==========================================
    // REUSABLE COMPONENT: IdeCard
    // ==========================================
    component IdeCard: Rectangle {
        id: ideCard
        Layout.fillWidth: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        implicitHeight: ideContentCol.implicitHeight + 20

        ColumnLayout {
            id: ideContentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 8

            // Card header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "terminal"
                    iconSize: 14
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: "Antigravity IDE"
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Bold
                    }
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 16
                    width: localTag.implicitWidth + 8
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.06)
                    StyledText {
                        id: localTag
                        anchors.centerIn: parent
                        text: "Local"
                        font.pixelSize: 9
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
                opacity: 0.3
            }

            // Repeater over dynamic IDE groups
            Repeater {
                model: popup.ideGroups
                delegate: ColumnLayout {
                    id: ideGroupCol
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 5

                    // Group display name
                    StyledText {
                        text: ideGroupCol.modelData.displayName
                        font {
                            pixelSize: Appearance.font.pixelSize.smallie
                            weight: Font.DemiBold
                        }
                        color: Appearance.colors.colSubtext
                    }

                    // Buckets
                    Repeater {
                        model: ideGroupCol.modelData.buckets ?? []
                        delegate: QuotaBucketItem {
                            required property var modelData
                            bucketData: modelData
                        }
                    }

                    // Separator between groups
                    Rectangle {
                        visible: ideGroupCol.index < (popup.ideGroups.length - 1)
                        Layout.fillWidth: true
                        height: 1
                        color: Appearance.colors.colLayer0Border
                        opacity: 0.2
                    }
                }
            }
        }
    }

    // ==========================================
    // REUSABLE COMPONENT: WebCard
    // ==========================================
    component WebCard: Rectangle {
        id: webCard
        visible: popup.webGroup !== null
        Layout.fillWidth: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        implicitHeight: webContentCol.implicitHeight + 20

        ColumnLayout {
            id: webContentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 8

            // Card header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "travel_explore"
                    iconSize: 15
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: "Zen Browser"
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Bold
                    }
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                // PRO plan badge
                Rectangle {
                    height: 17
                    width: proLabel.implicitWidth + 8
                    radius: 3
                    color: Qt.rgba(0.5, 0.3, 0.9, 0.25)
                    border.width: 1
                    border.color: Qt.rgba(0.6, 0.4, 1.0, 0.4)
                    StyledText {
                        id: proLabel
                        anchors.centerIn: parent
                        text: "PRO"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: "#C084FC"
                    }
                }

                // Model badge
                Rectangle {
                    height: 17
                    width: modelLabel.implicitWidth + 8
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    StyledText {
                        id: modelLabel
                        anchors.centerIn: parent
                        text: popup.webModelName
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
                opacity: 0.3
            }

            // Web Buckets
            Repeater {
                model: popup.webGroup?.buckets ?? []
                delegate: QuotaBucketItem {
                    required property var modelData
                    bucketData: modelData
                }
            }
        }
    }

    // ==========================================
    // REUSABLE COMPONENT: TaskFooter
    // ==========================================
    component TaskFooter: Rectangle {
        visible: (popup.quotaData?.currentTask ?? "").length > 0
        Layout.fillWidth: true
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        implicitHeight: taskRow.implicitHeight + 8

        RowLayout {
            id: taskRow
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 6

            MaterialSymbol {
                text: "chat"
                iconSize: 14
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: popup.quotaData?.currentTask ?? ""
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }
    }

    // ==========================================
    // REUSABLE COMPONENT: QuickActionButtons
    // ==========================================
    component QuickActionButtons: RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 30
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            onClicked: Quickshell.execDetached(["/home/sane/.local/bin/agy-tool", "focus"])

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 5
                MaterialSymbol {
                    text: "terminal"
                    iconSize: 13
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Antigravity")
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 30
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            onClicked: Quickshell.execDetached(["/home/sane/.local/bin/agy-tool", "focus", "zen"])

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 5
                MaterialSymbol {
                    text: "travel_explore"
                    iconSize: 13
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: Translation.tr("Gemini Web")
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }

    contentItem: Item {
        implicitWidth: popup.isHorizontalScreen ? 660 : 360
        implicitHeight: mainLayout.implicitHeight + 24

        ColumnLayout {
            id: mainLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 10

            // ==========================================
            // HEADER
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomIcon {
                    source: "google-gemini-symbolic"
                    width: 20
                    height: 20
                    colorize: true
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("Cuotas de Modelos")
                    font {
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: Font.DemiBold
                    }
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                // Live status chip
                RowLayout {
                    spacing: 5
                    Rectangle {
                        width: 7; height: 7; radius: 3.5
                        color: (popup.quotaData?.busy ?? false) ? Appearance.colors.colPrimary : "#52B768"
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: popup.quotaData?.busy ?? false
                            NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }
                    StyledText {
                        text: (popup.quotaData?.busy ?? false) ? Translation.tr("Generando") : Translation.tr("Sincronizado")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: (popup.quotaData?.busy ?? false) ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                }

                // Refresh Button
                RippleButton {
                    id: refreshBtn
                    implicitWidth: 26; implicitHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        rotateAnim.restart();
                        popup.requestRefresh();
                    }
                    contentItem: MaterialSymbol {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 15
                        color: Appearance.colors.colSubtext
                    }
                    RotationAnimation {
                        id: rotateAnim
                        target: refreshIcon
                        property: "rotation"
                        from: 0; to: 360
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    StyledToolTip { text: Translation.tr("Refrescar cuotas") }
                }
            }

            // ==========================================
            // RESPONSIVE BODY: SIDE-BY-SIDE (HORIZONTAL) OR STACKED (VERTICAL)
            // ==========================================
            Loader {
                Layout.fillWidth: true
                sourceComponent: popup.isHorizontalScreen ? horizontalLayout : verticalLayout
            }

            // 1. Horizontal Screen Layout (Side by side)
            Component {
                id: horizontalLayout
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.alignment: Qt.AlignTop

                    // Left Column: Antigravity IDE
                    IdeCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 340
                        Layout.alignment: Qt.AlignTop
                    }

                    // Right Column: Zen Browser + Task + Actions
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 300
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        WebCard {
                            Layout.fillWidth: true
                        }

                        TaskFooter {
                            Layout.fillWidth: true
                        }

                        QuickActionButtons {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // 2. Vertical Screen Layout (Stacked)
            Component {
                id: verticalLayout
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IdeCard {
                        Layout.fillWidth: true
                    }

                    WebCard {
                        Layout.fillWidth: true
                    }

                    TaskFooter {
                        Layout.fillWidth: true
                    }

                    QuickActionButtons {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
