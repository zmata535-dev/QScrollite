import QtQuick
import QtQuick.Controls

ToolTip {
    id: root

    delay: 450
    timeout: 12000
    padding: 6

    background: Rectangle {
        color: "#EB000000"
        radius: 6
    }

    contentItem: Text {
        text: root.text
        color: "#c0c0d8"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.weight: Font.Light
        font.pixelSize: 11
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }
}
