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
    implicitHeight: 12

    anchors {
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-app-switcher-bottom-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: triggerArea }

    MouseArea {
        id: triggerArea
        width: parent.width * 0.10
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (edge.service.open)
                edge.service.closeSwitcher(true)
            else
                edge.service.openSwitcher("bottom-center")
        }
    }
}
