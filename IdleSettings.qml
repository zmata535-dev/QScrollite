import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-idle-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool clockPreviewVisible: false
    property real clockPreviewFractureProgress: 0
    property real clockPreviewSlideProgress: 0
    property real clockPreviewSlideStartX: 0
    property bool clockPreviewClosing: false
    property int clockPreviewShatterSeed: 1
    property var clockPreviewNow: new Date()
    property bool clockPreviewColonVisible: true

    Timer {
        interval: 500
        repeat: true
        running: root.clockPreviewVisible
        onTriggered: {
            root.clockPreviewNow = new Date()
            root.clockPreviewColonVisible = !root.clockPreviewColonVisible
        }
    }

    function closeCard() {
        service.idleConfigOpen = false
    }

    function toggleClockPreview() {
        if (clockPreviewClosing) return
        if (!clockPreviewVisible) {
            clockPreviewFractureProgress = 0
            clockPreviewSlideProgress = 0
            clockPreviewVisible = true
        } else {
            if (service.clockShatterAnimationEnabled) {
                clockPreviewClosing = true
                clockPreviewShatterSeed = Math.floor(Math.random() * 2147483647)
                previewFractureAnimation.start()
            } else if (service.clockSlideAnimationEnabled) {
                clockPreviewClosing = true
                clockPreviewSlideStartX = clockPreviewCard.x
                previewSlideAnimation.start()
            } else {
                clockPreviewVisible = false
            }
        }
    }

    NumberAnimation {
        id: previewFractureAnimation
        target: root
        property: "clockPreviewFractureProgress"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
        onFinished: {
            root.clockPreviewVisible = false
            root.clockPreviewClosing = false
            root.clockPreviewFractureProgress = 0
        }
    }

    NumberAnimation {
        id: previewSlideAnimation
        target: root
        property: "clockPreviewSlideProgress"
        from: 0
        to: 1
        duration: 480
        easing.type: Easing.InCubic
        onFinished: {
            root.clockPreviewVisible = false
            root.clockPreviewClosing = false
            root.clockPreviewSlideProgress = 0
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeCard()

        Rectangle {
            anchors.fill: parent
            color: "#99080c16"

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeCard()
            }
        }

        GlowBorder {
            targetItem: clockPreviewCard
            cornerRadius: clockPreviewCard.radius
            visible: root.clockPreviewVisible
            opacity: 1 - Math.max(root.clockPreviewFractureProgress, root.clockPreviewSlideProgress)
        }

        Rectangle {
            id: clockPreviewCard
            x: root.clockPreviewSlideProgress > 0
                ? root.clockPreviewSlideStartX + ((root.width - width) / 2 - root.clockPreviewSlideStartX) * root.clockPreviewSlideProgress
                : card.x + card.width + 24
            y: (root.height - height) / 2 - ((root.height + height) / 2) * root.clockPreviewSlideProgress
            width: Math.min(442, Math.max(204, (root.width - card.width - 64) * 0.85))
            height: 212
            radius: 18
            visible: root.clockPreviewVisible
            opacity: 1 - Math.max(root.clockPreviewFractureProgress, root.clockPreviewSlideProgress)
            scale: 1 - root.clockPreviewSlideProgress * 0.82
            color: Qt.rgba(17 / 255, 23 / 255, 34 / 255, root.service.clockCardBackgroundOpacity / 100)
            border.color: "#3b4a63"
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: Qt.formatDateTime(root.clockPreviewNow, "HH")
                        color: root.service.idleClockTextColor
                        font.pixelSize: root.service.idleClockTextSize * Math.min(1, clockPreviewCard.width / 442)
horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.preferredWidth: 30
                        text: ":"
                        color: root.service.idleClockTextColor
                        opacity: root.clockPreviewColonVisible ? 1 : 0.18
                        font.pixelSize: root.service.idleClockTextSize * 0.94 * Math.min(1, clockPreviewCard.width / 442)
horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: Qt.formatDateTime(root.clockPreviewNow, "mm")
                        color: root.service.idleClockTextColor
                        font.pixelSize: root.service.idleClockTextSize * Math.min(1, clockPreviewCard.width / 442)
horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                    Layout.bottomMargin: 14
                    text: Qt.formatDate(root.clockPreviewNow, "dddd, dd MMM yyyy")
                    color: "#94a3b8"
font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        GlassShatter {
            targetItem: clockPreviewCard
            progress: root.clockPreviewFractureProgress
            seed: root.clockPreviewShatterSeed
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: root.clockPreviewVisible
                ? Math.min(480, Math.max(300, (root.width - 64) * 0.48))
                : Math.min(480, root.width - 32)
            height: Math.min(760, root.height - 32)
            x: root.clockPreviewVisible
                ? Math.max(16, (root.width - width - clockPreviewCard.width - 24) / 2)
                : (root.width - width) / 2
            y: (root.height - height) / 2
            radius: 16
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Idle timer settings"
                        color: "#e2e8f0"
                        font.pixelSize: 17}

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 6
                        color: closeMouse.containsMouse ? "#3b1e28" : "#161d2a"
                        border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeCard()
                        }
                    }
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                    text: "Set how many seconds of inactivity trigger each action."
                    color: "#94a3b8"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Show compact clock"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.compactClockTimeout
                        onValueModified: root.service.compactClockTimeout = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Show full clock card"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleClockTimeout
                        onValueModified: root.service.idleClockTimeout = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Dim display to 10%"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleDimTimeout
                        onValueModified: root.service.idleDimTimeout = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Turn display off"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleDisplayOffTimeout
                        onValueModified: root.service.idleDisplayOffTimeout = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Lock screen"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleLockTimeout
                        onValueModified: root.service.idleLockTimeout = value
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Global column width presets"
                    color: "#abc7ff"
                    font.pixelSize: 12}

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 8

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Narrow (%)"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 10; to: 100; editable: true
                        value: root.service.columnWidthSmall
                        onValueModified: root.service.columnWidthSmall = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Normal (%)"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 10; to: 100; editable: true
                        value: root.service.columnWidthMedium
                        onValueModified: root.service.columnWidthMedium = value
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Wide (%)"; color: "#dce5f2"; font.pixelSize: 11 }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        from: 10; to: 100; editable: true
                        value: root.service.columnWidthLarge
                        onValueModified: root.service.columnWidthLarge = value
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                RowLayout {
                    Layout.fillWidth: true

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Clock card appearance"
                        color: "#abc7ff"
                        font.pixelSize: 12}

                    ShellButton {

                        font.pixelSize: 10
                        text: root.clockPreviewVisible ? "Hide preview" : "Preview"
                        enabled: !root.clockPreviewClosing
                        onClicked: root.toggleClockPreview()
                    }
                }

                ShellCheckBox {

                    font.pixelSize: 12
                    text: "Shatter glass when hiding the clock card"
                    checked: root.service.clockShatterAnimationEnabled
                    onToggled: {
                        root.service.clockShatterAnimationEnabled = checked
                        if (checked) root.service.clockSlideAnimationEnabled = false
                    }
                }

                ShellCheckBox {
                    font.pixelSize: 12
                    text: "Slide to the top and shrink when hiding the clock card"
                    checked: root.service.clockSlideAnimationEnabled
                    onToggled: {
                        root.service.clockSlideAnimationEnabled = checked
                        if (checked) root.service.clockShatterAnimationEnabled = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Clock text color"
                        color: "#dce5f2"
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        color: root.service.idleClockTextColor
                        border.color: "#64748b"
                    }

                    ShellTextField {

                        implicitHeight: 24

                        font.pixelSize: 11
                        id: colorField
                        Layout.preferredWidth: 112
                        text: root.service.idleClockTextColor
                        placeholderText: "#e2e8f0"
                        maximumLength: 7
                        onEditingFinished: {
                            if (/^#[0-9a-fA-F]{6}$/.test(text)) {
                                root.service.idleClockTextColor = text
                            } else {
                                text = root.service.idleClockTextColor
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Clock font size"
                        color: "#dce5f2"
                        font.pixelSize: 11
                    }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        from: 32; to: 160; editable: true
                        value: root.service.idleClockTextSize
                        onValueModified: root.service.idleClockTextSize = value
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Compact clock font size"
                        color: "#dce5f2"
                        font.pixelSize: 11
                    }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        from: 12; to: 72; editable: true
                        value: root.service.compactClockTextSize
                        onValueModified: root.service.compactClockTextSize = value
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: "Card background opacity (%)"
                        color: "#dce5f2"
                        font.pixelSize: 11
                    }
                    ShellSpinBox {
                        implicitHeight: 24
                        font.pixelSize: 10
                        from: 0; to: 100; editable: true
                        value: root.service.clockCardBackgroundOpacity
                        onValueModified: root.service.clockCardBackgroundOpacity = value
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }

                RowLayout {
                    Layout.fillWidth: true

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: root.service.idleApplyStatus
                        color: root.service.idleApplyStatus.indexOf("Could not") === 0 ? "#ffb4ab" : "#94a3b8"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    ShellButton {

                        font.pixelSize: 10
                        text: "Apply"
                        accent: true
                        enabled: !root.service.idleApplyProcess.running
                        onClicked: root.service.applyIdleSettings()
                    }
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
}
