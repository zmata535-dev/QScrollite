import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    required property var service
    required property string action
    required property string glyph

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse
            ? (root.action === "shutdown" || root.action === "reboot" ? "#3b1e28" : "#273650")
            : "#161d2a"
        border.color: mouse.containsMouse
            ? (root.action === "shutdown" || root.action === "reboot" ? "#ff6b81" : "#abc7ff")
            : "#2b364a"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: mouse.containsMouse
                ? (root.action === "shutdown" || root.action === "reboot" ? "#ffb3ba" : "#abc7ff")
                : "#8092ab"
            font.pixelSize: 14
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.service.runSystemAction(root.action)
            ToolTip.visible: containsMouse
            ToolTip.delay: 600
            ToolTip.text: root.action.charAt(0).toUpperCase() + root.action.slice(1)
        }
    }
}
