import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    visible: controlVisible
    width: 220
    height: 62
    anchors { top: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-qtextpicker-cancel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { Region { item: cancelCard } }

    property bool controlVisible: false

    Timer {
        id: controlTimer
        interval: 900
        repeat: false
        running: root.service.qTextPickerCapturing && !root.controlVisible
        onTriggered: root.controlVisible = true
    }

    Connections {
        target: root.service
        function onQTextPickerCapturingChanged() {
            if (!root.service.qTextPickerCapturing) root.controlVisible = false
        }
    }

    Rectangle {
        id: cancelCard
        visible: root.controlVisible && root.service.qTextPickerCapturing
        width: 196
        height: 42
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.rightMargin: 12
        radius: 9
        color: "#e6111722"
        border.color: "#68d7ff"
        border.width: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Selecting text…"
                color: "#e2e8f0"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 10
            }

            Rectangle {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 26
                radius: 6
                color: cancelMouse.containsMouse ? "#5a2730" : "#39202a"
                border.color: "#ff8a96"

                Text {
                    anchors.centerIn: parent
                    text: root.service.qTextPickerCancelRequested ? "Canceling…" : "Cancel"
                    color: "#ffd5d9"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.service.qTextPickerCancelRequested
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.cancelScreenTextCapture()
                }
            }
        }
    }
}
