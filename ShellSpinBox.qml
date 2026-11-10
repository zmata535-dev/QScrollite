import QtQuick
import QtQuick.Controls

SpinBox {
    id: root

    font.family: "JetBrainsMono Nerd Font Mono"
    font.weight: Font.Light
implicitHeight: 30
    font.pixelSize: 12
    palette.text: "#dce5f2"
    palette.base: "#161d2a"
    palette.buttonText: "#8092ab"
    palette.highlight: "#5476a4"
    palette.highlightedText: "#ffffff"

    background: Rectangle {
        radius: 6
        color: "#161d2a"
        border.width: 1
        border.color: root.activeFocus ? "#abc7ff" : "#2b364a"
    }
}
