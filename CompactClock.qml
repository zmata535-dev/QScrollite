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
    exclusionMode: ExclusionMode.Ignore

    property var now: new Date()
    property bool colonVisible: true
    property real slideY: -18

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
        interval: 500
        repeat: true
        running: root.visible
        onTriggered: {
            root.now = new Date()
            root.colonVisible = !root.colonVisible
        }
    }

    Item {
        anchors.fill: parent

        MouseArea {
            id: activityArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: root.service.closeCompactClock()
            onWheel: root.service.closeCompactClock()
        }

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

        Button {
            id: clockButton
            x: compactCard.x + (compactCard.width - width) / 2
            y: Math.max(0, compactCard.y + (compactCard.height - height) / 2)
            width: Math.max(compactCard.width, clockButtonText.implicitWidth) + 36
            height: Math.max(compactCard.height, clockButtonText.implicitHeight) + 36
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
            onClicked: {
                root.service.closeCompactClock()
                root.service.openCalendar()
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
            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.service.closeCompactClock()
                    root.service.openCalendar()
                } else {
                    root.service.closeCompactClock()
                }
            }
        }
    }
}
