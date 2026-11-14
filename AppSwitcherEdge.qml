import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edge

    required property var modelData
    required property var service

    screen: modelData
    visible: service.bottomAppSwitcherEnabled
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
        width: parent.width * 0.20
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: edge.service.openSwitcher("bottom-center")
    }
}
