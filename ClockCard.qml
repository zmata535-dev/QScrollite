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
    WlrLayershell.namespace: "quickshell-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var now: service.clockNow
    property bool colonVisible: service.clockColonVisible
    property real fractureProgress: 0
    property real slideCloseProgress: 0
    property int fractureSeed: 1
    readonly property real closeFade: Math.max(fractureProgress, slideCloseProgress)
    readonly property string dateLabel: Qt.formatDate(now, "dddd, dd MMM yyyy")

    Timer {
        id: pointerStartupGuard
        interval: 350
        repeat: false
    }

    function closeClock() {
        service.requestClockClose()
    }

    function startFracture() {
        if (!service.clockCloseRequested || fractureAnimation.running) return
        fractureProgress = 0
        fractureSeed = Math.floor(Math.random() * 2147483647)
        fractureAnimation.start()
    }

    function startSlideClose() {
        if (!service.clockSlideCloseRequested || slideCloseAnimation.running) return
        slideCloseProgress = 0
        slideCloseAnimation.start()
    }

    function finishClockClose() {
        service.clockOpen = false
        service.clockCloseRequested = false
        service.clockSlideCloseRequested = false
        fractureProgress = 0
        slideCloseProgress = 0
    }

    Connections {
        target: root.service
        function onClockCloseRequestedChanged() { root.startFracture() }
        function onClockSlideCloseRequestedChanged() { root.startSlideClose() }
    }

    NumberAnimation {
        id: fractureAnimation
        target: root
        property: "fractureProgress"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
        onFinished: {
            root.finishClockClose()
        }
    }

    NumberAnimation {
        id: slideCloseAnimation
        target: root
        property: "slideCloseProgress"
        from: 0
        to: 1
        duration: 480
        easing.type: Easing.InCubic
        onFinished: root.finishClockClose()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            root.closeClock()
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            color: "#35080c16"
            opacity: 1 - root.closeFade

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: {
                    if (!pointerStartupGuard.running) root.closeClock()
                }
                onPressed: root.closeClock()
                onClicked: root.closeClock()
                onWheel: root.closeClock()
            }
        }

        GlowBorder {
            targetItem: card
            cornerRadius: card.radius
            opacity: 1 - root.closeFade
        }

        Rectangle {
            id: card
            width: Math.min(369, (root.width - 32) * 0.69)
            height: 212
            anchors.centerIn: parent
            radius: 14
            color: Qt.rgba(17 / 255, 23 / 255, 34 / 255, root.service.clockCardBackgroundOpacity / 100)
            border.color: "#3b4a63"
            border.width: 1
            opacity: 1 - root.closeFade
            scale: 1 - root.slideCloseProgress * 0.82
            transform: Translate {
                y: -((root.height + card.height) / 2) * root.slideCloseProgress
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: {
                    if (!pointerStartupGuard.running) root.closeClock()
                }
                onPressed: root.closeClock()
                onClicked: root.closeClock()
                onWheel: root.closeClock()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: Qt.formatDateTime(root.now, "HH")
                        color: root.service.idleClockTextColor
font.pixelSize: root.service.idleClockTextSize
horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.preferredWidth: 36
                        text: ":"
                        color: root.service.idleClockTextColor
                        opacity: root.colonVisible ? 1 : 0.18
font.pixelSize: root.service.idleClockTextSize * 0.94
horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: Qt.formatDateTime(root.now, "mm")
                        color: root.service.idleClockTextColor
font.pixelSize: root.service.idleClockTextSize
horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 14
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.dateLabel
                        color: "#94a3b8"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.weight: Font.Light
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        visible: root.service.unreadNotificationCount > 0
                        spacing: 4

                        Text {
                            text: "󰂚"
                            color: "#c0c0d8"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 17
                        }

                        Text {
                            text: String(root.service.unreadNotificationCount)
                            color: "#c0c0d8"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        GlassShatter { targetItem: card; progress: root.fractureProgress; seed: root.fractureSeed }
    }

    Component.onCompleted: {
        pointerStartupGuard.start()
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            root.startFracture()
            root.startSlideClose()
        })
    }
}
