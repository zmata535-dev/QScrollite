import QtQuick

Item {
    id: root

    required property Item targetItem
    property int spread: 4
    property color glowColor: "#3b4a63"
    property color accentGlowColor: "#3b4a63"
    property real offsetY: 0
    property real cornerRadius: 14

    x: targetItem.x - spread
    y: targetItem.y - spread
    width: targetItem.width + spread * 2
    height: targetItem.height + spread * 2
    z: targetItem.z
    visible: targetItem.visible
    opacity: targetItem.opacity

    transform: Translate { y: root.offsetY }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(0, root.cornerRadius) + root.spread
        color: "transparent"
        border.color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.14)
        border.width: root.spread + 1
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, root.cornerRadius) + 2
        color: "transparent"
        border.color: Qt.rgba(root.accentGlowColor.r, root.accentGlowColor.g, root.accentGlowColor.b, 0.28)
        border.width: 2
    }
}
