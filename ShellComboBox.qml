import QtQuick
import QtQuick.Controls

ComboBox {
    id: root

    font.family: "JetBrainsMono Nerd Font Mono"
    font.weight: Font.Light
    font.pixelSize: 12
    implicitHeight: 26
    palette.text: "#dce5f2"
    palette.highlight: "#273650"
    palette.highlightedText: "#f1f5f9"

    contentItem: Text {
        leftPadding: 9
        rightPadding: 26
        text: root.displayText
        color: "#dce5f2"
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - 8
        y: (root.height - height) / 2
        text: "⌄"
        color: root.activeFocus ? "#abc7ff" : "#8092ab"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 13
    }

    background: Rectangle {
        radius: 6
        color: "#161d2a"
        border.width: 1
        border.color: root.activeFocus ? "#abc7ff" : "#2b364a"
    }

    delegate: ItemDelegate {
        width: root.width
        height: 28
        text: root.textAt(index)
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: parent.text
            color: parent.highlighted ? "#abc7ff" : "#dce5f2"
            font: root.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 4
            color: parent.highlighted ? "#202a3a" : "transparent"
        }
    }

    popup: Popup {
        y: root.height + 3
        width: root.width
        padding: 4
        implicitHeight: Math.min(optionList.implicitHeight + padding * 2, 240)

        background: Rectangle {
            radius: 8
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
        }

        contentItem: ListView {
            id: optionList
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }
    }
}
