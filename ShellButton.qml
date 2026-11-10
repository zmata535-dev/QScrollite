import QtQuick
import QtQuick.Controls

Button {
    id: root

    font.family: "JetBrainsMono Nerd Font Mono"
    font.weight: Font.Light
    property bool selected: false
    property bool accent: false
    property bool danger: false

    implicitHeight: 30
    font.pixelSize: 12

    background: Rectangle {
        radius: 6
        color: !root.enabled ? "#141922"
            : (root.down ? (root.danger ? "#3b1e28" : "#1d2a3e")
            : (root.hovered ? (root.danger ? "#3b1e28" : "#273650")
            : (root.accent || root.selected ? "#22334f" : "#161d2a")))
        border.width: 1
        border.color: !root.enabled ? "#222936"
            : ((root.hovered || root.down) ? (root.danger ? "#ff6b81" : "#abc7ff")
            : (root.accent || root.selected ? "#5476a4" : "#2b364a"))
    }

    contentItem: Text { text: root.text
        color: !root.enabled ? "#657188"
            : (root.danger && (root.hovered || root.down) ? "#ffb3ba"
            : (root.accent || root.selected ? "#abc7ff" : (root.hovered ? "#abc7ff" : "#dce5f2")))
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
