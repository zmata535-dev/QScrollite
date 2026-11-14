import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edge

    required property var modelData
    required property var service

    screen: modelData
    visible: true
    color: "transparent"
    implicitWidth: screen.width

    anchors {
        left: true
        right: true
        top: true
    }

    implicitHeight: 12

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-compact-clock-hotcorner"
    exclusionMode: ExclusionMode.Ignore

    Timer {
        id: closeOnExitTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!edge.service.compactClockCardHovered)
                edge.service.closeCompactClock()
        }
    }

    MouseArea {
        width: parent.width * 0.20
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        acceptedButtons: edge.service.compactClockOpen
            ? Qt.LeftButton | Qt.RightButton
            : Qt.NoButton
        hoverEnabled: true
        onEntered: {
            closeOnExitTimer.stop()
            edge.service.showCompactClockFromEdge()
        }
        onExited: closeOnExitTimer.restart()
        onPressed: function(mouse) {
            if (!edge.service.compactClockOpen) return
            if (mouse.button === Qt.LeftButton) {
                edge.service.closeCompactClock()
                edge.service.openCalendar()
            } else {
                edge.service.closeCompactClock()
            }
        }
    }
}
