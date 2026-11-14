import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    visible: service.volumeOsdVisible
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qscrollite-volume-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: card }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        width: 208
        height: 54
        radius: 12
        color: "#eb111722"
        border.color: "#3b4a63"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.service.volumeMuted ? "󰝟  Muted" : "󰕾  Volume"
                    color: "#c0c0d8"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.service.volumeMuted ? "" : root.service.volumePercent + "%"
                    color: "#c0c0d8"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: "#252f40"
                Rectangle {
                    width: parent.width * (root.service.volumeMuted ? 0 : root.service.volumePercent / 100)
                    height: parent.height
                    radius: parent.radius
                    color: root.service.volumeMuted ? "#8092ab" : "#8fd8cf"
                }
            }
        }
    }
}
