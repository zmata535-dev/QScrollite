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

    implicitHeight: 1

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-compact-clock-hotcorner"
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
        width: parent.width * 0.20
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        acceptedButtons: edge.service.compactClockOpen
            ? Qt.LeftButton | Qt.RightButton
            : Qt.NoButton
        hoverEnabled: true
        onEntered: {
            edge.service.cancelCompactClockPointerExit()
            edge.service.showCompactClockFromEdge()
        }
        onExited: edge.service.scheduleCompactClockPointerExit(300)
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
