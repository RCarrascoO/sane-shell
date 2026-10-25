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
    // REUSABLE COMPONENT: QuotaBucketItem (con M3LinearProgress)
    // ==========================================
    component QuotaBucketItem: ColumnLayout {
        id: bucketItem
        required property var bucketData
        Layout.fillWidth: true
        spacing: 4

        // Metric label + percentage
        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: bucketItem.bucketData.displayName
                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.smallie
                }
                color: Theme.onSurface
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
                    ? Theme.error
                    : (bucketItem.bucketData.percentage <= 40 ? Theme.warning : Theme.secondary)
            }
        }

        // M3 Official Linear Progress con Gap + Stop Dot
        M3LinearProgress {
            Layout.fillWidth: true
            implicitHeight: 6
            value: Math.max(0, Math.min(1, bucketItem.bucketData.fraction))
            colPrimary: bucketItem.bucketData.percentage <= 15
                ? Theme.error
                : (bucketItem.bucketData.percentage <= 40 ? Theme.warning : Theme.secondary)
            colSecondary: Theme.secondaryContainer
        }

        // Countdown reset text
        RowLayout {
            visible: (bucketItem.bucketData.resetIn ?? "").length > 0
            spacing: 4
            MaterialSymbol {
                text: "schedule"
                iconSize: 11
                color: Theme.onSurfaceVariant
            }
            StyledText {
                text: (bucketItem.bucketData.displayName.includes("Uso actual") || bucketItem.bucketData.displayName.includes("semanal"))
                    ? Translation.tr("Se restablece en %1").arg(bucketItem.bucketData.resetIn)
                    : Translation.tr("Resets in %1").arg(bucketItem.bucketData.resetIn)
                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.smallie - 1
                }
                color: Theme.onSurfaceVariant
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
        radius: 20
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant
        implicitHeight: ideContentCol.implicitHeight + 20

        ColumnLayout {
            id: ideContentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 10

            // Card header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "terminal"
                    iconSize: 16
                    color: Theme.primary
                }

                StyledText {
                    text: "Antigravity IDE"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Bold
                    }
                    color: Theme.onSurface
                }

                Item { Layout.fillWidth: true }

                // M3 Chip
                Rectangle {
                    height: 20
                    width: localTag.implicitWidth + 10
                    radius: 6
                    color: Theme.primaryContainer
                    StyledText {
                        id: localTag
                        anchors.centerIn: parent
                        text: "Local"
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 10
                            weight: Font.DemiBold
                        }
                        color: Theme.onPrimaryContainer
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
            }

            // Repeater over dynamic IDE groups
            Repeater {
                model: popup.ideGroups
                delegate: ColumnLayout {
                    id: ideGroupCol
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6

                    // Group display name
                    StyledText {
                        text: ideGroupCol.modelData.displayName
                        font {
                            family: Appearance.font.family.main
                            pixelSize: Appearance.font.pixelSize.smallie
                            weight: Font.DemiBold
                        }
                        color: Theme.onSurfaceVariant
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
                        color: Theme.outlineVariant
                        opacity: 0.5
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
        radius: 20
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant
        implicitHeight: webContentCol.implicitHeight + 20

        ColumnLayout {
            id: webContentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 10

            // Card header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "travel_explore"
                    iconSize: 16
                    color: Theme.secondary
                }

                StyledText {
                    text: "Zen Browser"
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.Bold
                    }
                    color: Theme.onSurface
                }

                Item { Layout.fillWidth: true }

                // PRO plan badge M3 Tertiary Container
                Rectangle {
                    height: 20
                    width: proLabel.implicitWidth + 10
                    radius: 6
                    color: Theme.tertiaryContainer
                    StyledText {
                        id: proLabel
                        anchors.centerIn: parent
                        text: "PRO"
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 10
                            weight: Font.Bold
                        }
                        color: Theme.onTertiaryContainer
                    }
                }

                // Model badge M3 Primary Container
                Rectangle {
                    height: 20
                    width: modelLabel.implicitWidth + 10
                    radius: 6
                    color: Theme.primaryContainer
                    StyledText {
                        id: modelLabel
                        anchors.centerIn: parent
                        text: popup.webModelName
                        font {
                            family: Appearance.font.family.main
                            pixelSize: 10
                            weight: Font.DemiBold
                        }
                        color: Theme.onPrimaryContainer
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
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
        radius: 12
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant
        implicitHeight: taskRow.implicitHeight + 10

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
                color: Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                text: popup.quotaData?.currentTask ?? ""
                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.smallie
                }
                color: Theme.onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }

    // ==========================================
    // REUSABLE COMPONENT: QuickActionButtons (M3 Filled Tonal Buttons)
    // ==========================================
    component QuickActionButtons: RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: 20
            colBackground: Theme.secondaryContainer
            colBackgroundHover: Theme.surfaceContainerHighest
            onClicked: Quickshell.execDetached(["/home/sane/.local/bin/agy-tool", "focus"])

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "terminal"
                    iconSize: 16
                    color: Theme.onSecondaryContainer
                }
                StyledText {
                    text: Translation.tr("Antigravity")
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.smallie
                        weight: Font.DemiBold
                    }
                    color: Theme.onSecondaryContainer
                }
            }
        }

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: 20
            colBackground: Theme.secondaryContainer
            colBackgroundHover: Theme.surfaceContainerHighest
            onClicked: Quickshell.execDetached(["/home/sane/.local/bin/agy-tool", "focus", "zen"])

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "travel_explore"
                    iconSize: 16
                    color: Theme.onSecondaryContainer
                }
                StyledText {
                    text: Translation.tr("Gemini Web")
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.smallie
                        weight: Font.DemiBold
                    }
                    color: Theme.onSecondaryContainer
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
                margins: 14
            }
            spacing: 12

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
                    color: Theme.primary
                }

                StyledText {
                    text: Translation.tr("Cuotas de Modelos")
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: Font.Bold
                    }
                    color: Theme.onSurface
                }

                Item { Layout.fillWidth: true }

                // Live status chip M3
                Rectangle {
                    height: 22
                    width: liveStatusRow.implicitWidth + 12
                    radius: 11
                    color: Theme.surfaceContainerLow
                    border.width: 1
                    border.color: Theme.outlineVariant

                    RowLayout {
                        id: liveStatusRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: (popup.quotaData?.busy ?? false) ? Theme.primary : Theme.success
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: popup.quotaData?.busy ?? false
                                NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }
                        StyledText {
                            text: (popup.quotaData?.busy ?? false) ? Translation.tr("Generando") : Translation.tr("Sincronizado")
                            font {
                                family: Appearance.font.family.main
                                pixelSize: 10
                                weight: Font.Medium
                            }
                            color: (popup.quotaData?.busy ?? false) ? Theme.primary : Theme.onSurfaceVariant
                        }
                    }
                }

                // Refresh Button
                RippleButton {
                    id: refreshBtn
                    implicitWidth: 30; implicitHeight: 30
                    buttonRadius: 15
                    colBackground: Theme.surfaceContainerLow
                    colBackgroundHover: Theme.surfaceContainerHighest
                    onClicked: {
                        rotateAnim.restart();
                        popup.requestRefresh();
                    }
                    contentItem: MaterialSymbol {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: Theme.onSurfaceVariant
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
