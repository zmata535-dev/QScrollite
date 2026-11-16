import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edge

    required property var modelData
    required property var service

    screen: modelData
    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: 1
    implicitHeight: modelData ? modelData.height : 1
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-hot-edge-right"
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: triggerArea }

    MouseArea {
        id: triggerArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height * 0.20
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: edge.service.showQNote()
    }
}
