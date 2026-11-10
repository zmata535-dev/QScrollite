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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-compact-clock-hotcorner"
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
        width: parent.width * 0.10
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onEntered: edge.service.showCompactClockFromEdge()
        onExited: edge.service.closeCompactClock()
    }
}
