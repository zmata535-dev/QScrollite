import QtQuick
import QtQuick.Controls

TextField {
    id: root

    font.family: "JetBrainsMono Nerd Font Mono"
    font.weight: Font.Light
    color: "#dce5f2"
    placeholderTextColor: "#8092ab"
    selectionColor: "#5476a4"
    selectedTextColor: "#ffffff"
    font.pixelSize: 13
    leftPadding: 10
    rightPadding: 10

    background: Rectangle {
        radius: 6
        color: "#161d2a"
        border.width: 1
        border.color: root.activeFocus ? "#abc7ff" : "#2b364a"
    }
}
