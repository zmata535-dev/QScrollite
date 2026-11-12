import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: true
    // Keep this full-screen surface non-reserving so the card can travel to
    // screen center before the full clock opens.
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Keep the top-edge trigger above this full-screen surface so it retains
    // hover tracking while the compact clock is visible.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-compact-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        Region { item: compactCard }
        Region { item: clockButton }
        Region { item: notificationBadge }
    }

    property var now: new Date()
    property bool colonVisible: true
    property real slideY: -18

    function openClockDestination() {
        root.service.closeCompactClock()
        openDestinationTimer.restart()
    }

    Timer {
        id: openDestinationTimer
        interval: 180
        repeat: false
        onTriggered: root.service.openCalendarFromCompactClock()
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "slideY"
        from: -18
        to: 0
        duration: 320
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "slideY"
        from: root.slideY
        to: root.service.compactClockCloseToCenter
            ? Math.max(8, (root.height - compactCard.height) / 2)
            : -18
        duration: root.service.compactClockCloseToCenter ? 400 : 240
        easing.type: Easing.InCubic
        onStopped: {
            if (root.service.compactClockClosing)
                root.service.finishCompactClockClose()
        }
    }

    Connections {
        target: root.service
        function onCompactClockOpenChanged() {
            if (root.service.compactClockOpen) {
                slideOut.stop()
                root.slideY = -18
                slideIn.start()
            }
        }
        function onCompactClockClosingChanged() {
            if (root.service.compactClockClosing) {
                slideIn.stop()
                slideOut.start()
            } else if (root.service.compactClockOpen) {
                slideOut.stop()
                root.slideY = -18
                slideIn.start()
            }
        }
    }

    Component.onCompleted: slideIn.start()

    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: {
            root.now = new Date()
            root.colonVisible = !root.colonVisible
        }
    }

    Item {
        anchors.fill: parent

        GlowBorder {
            targetItem: compactCard
            cornerRadius: compactCard.radius
        }

        Rectangle {
            id: compactCard
            x: (root.width - width) / 2
            y: root.slideY
            width: 69
            height: 18
            radius: 12
            color: Qt.rgba(17 / 255, 23 / 255, 34 / 255, root.service.clockCardBackgroundOpacity / 100)
            border.color: "#3b4a63"
            border.width: 1

        }

        Rectangle {
            id: notificationBadge
            visible: root.service.unreadNotificationCount > 0
            x: compactCard.x + compactCard.width - 3
            y: compactCard.y - 3
            z: 14
            width: root.service.unreadNotificationCount > 9 ? 17 : 10
            height: 10
            radius: 5
            color: "#ef6478"
            border.color: "#111622"
            border.width: 1
            Text {
                anchors.centerIn: parent
                visible: root.service.unreadNotificationCount > 9
                text: root.service.unreadNotificationCount > 99 ? "99+" : String(root.service.unreadNotificationCount)
                color: "#111622"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 7
                font.bold: true
            }
            ShellToolTip {
                parent: notificationBadgeMouse
                visible: notificationBadgeMouse.containsMouse
                text: root.service.unreadNotificationCount + " unread notification" + (root.service.unreadNotificationCount === 1 ? "" : "s")
            }
            MouseArea {
                id: notificationBadgeMouse
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        Button {
            id: clockButton
            x: compactCard.x
            y: compactCard.y
            width: compactCard.width
            height: compactCard.height
            z: 11
            padding: 0
            text: Qt.formatDateTime(root.now, "HH") + (root.colonVisible ? ":" : " ") + Qt.formatDateTime(root.now, "mm")
            background: Item {}
            contentItem: Text {
                id: clockButtonText
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: compactCard.y + compactCard.height / 2 - height / 2 - clockButton.y
                text: clockButton.text
                color: "#ffffff"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.weight: Font.Light
                font.pixelSize: root.service.compactClockTextSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: clockButtonPointer
            anchors.fill: clockButton
            z: 12
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            property bool pointerWasOverClock: false
            onEntered: pointerWasOverClock = true
            onExited: {
                if (pointerWasOverClock) {
                    pointerWasOverClock = false
                    root.service.closeCompactClock()
                }
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.openClockDestination()
                } else {
                    root.service.closeCompactClock()
                }
            }
        }
    }
}
