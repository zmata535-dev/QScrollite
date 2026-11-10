import QtQuick
import QtQuick.Controls

CheckBox {
    id: root

    font.family: "JetBrainsMono Nerd Font Mono"
    font.weight: Font.Light
spacing: 8
    palette.text: "#dce5f2"
    palette.highlight: "#5476a4"
    palette.highlightedText: "#ffffff"

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: root.leftPadding
        y: (root.height - height) / 2
        radius: 4
        color: root.checked ? "#22334f" : "#161d2a"
        border.width: 1
        border.color: root.activeFocus ? "#abc7ff" : (root.checked ? "#5476a4" : "#2b364a")

        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
            text: "✓"
            color: "#abc7ff"
            font.pixelSize: 12
visible: root.checked
        }
    }

    contentItem: Text { text: root.text
        color: root.enabled ? "#dce5f2" : "#657188"
        font: root.font
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + root.spacing
    }
}
