import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "PanelPlacement.js" as PanelPlacement

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: service.clipboardOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: service.raisedCardModule === "clipboard" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard-manager"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    property real cardX: -600
    property real openTargetX: 12

    function positionOppositeFocusedWindow() {
        openTargetX = PanelPlacement.oppositeTargetX(service, root.screen.x,
            root.width, card.width, 12)
    }

    function openFromOppositeSide() {
        positionOppositeFocusedWindow()
        cardX = PanelPlacement.entryX(openTargetX, root.width, card.width, root.screen.x, 12)
        slideIn.to = openTargetX
        slideIn.restart()
    }

    function repositionAfterSwitcher() {
        Qt.callLater(function() {
            if (!root.visible || PanelPlacement.switcherActive(root.service)) return
            root.positionOppositeFocusedWindow()
            slideIn.stop()
            slideIn.to = root.openTargetX
            slideIn.restart()
        })
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "cardX"
        to: root.openTargetX
        duration: 300
        easing.type: Easing.OutCubic
    }

    Connections {
        target: root.service
        function onActiveWindowIdChanged() { root.repositionAfterSwitcher() }
        function onOpenChanged() { if (!root.service.open) root.repositionAfterSwitcher() }
        function onAppSwitcherHoveredChanged() {
            if (!root.service.appSwitcherHovered) root.repositionAfterSwitcher()
        }
    }

    onVisibleChanged: {
        if (visible) {
            service.raiseCardModule("clipboard")
            if (!slideIn.running) openFromOppositeSide()
        } else {
            slideIn.stop()
        }
    }

    Component.onCompleted: {
        if (visible && !slideIn.running) openFromOppositeSide()
    }

    function close() {
        service.clipboardOpen = false
    }

    function previewText(value) {
        return String(value || "").replace(/\r\n/g, "\n").replace(/\n/g, "  ↵  ")
    }

    Item {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            width: Math.min(560, root.width - 32)
            height: Math.min(620, root.height - 64)
            x: root.cardX
            y: (parent.height - height) / 2
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
            focus: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Clipboard Manager"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }
                    Item { Layout.fillWidth: true }
                    ShellButton {
                        text: "Capture text"
                        onClicked: root.service.openQTextPicker()
                    }
                    ShellButton {
                        text: "Clear"
                        enabled: root.service.clipboardHistory.length > 0
                        onClicked: root.service.clearClipboardHistory()
                    }
                    ShellButton { text: "×"; onClicked: root.close() }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Select an item to copy it again · text history is kept while Quickshell is running"
                    color: "#8092ab"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: root.service.clipboardHistory
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property string modelData
                        width: historyList.width
                        height: Math.max(48, Math.min(90, contentText.implicitHeight + 18))
                        radius: 7
                        color: itemMouse.containsMouse ? "#202a3a" : "#161d2a"
                        border.color: itemMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text {
                            id: contentText
                            anchors.fill: parent
                            anchors.margins: 10
                            text: root.previewText(modelData)
                            color: "#dce5f2"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.copyClipboardHistoryItem(modelData)
                        }
                    }

                    ScrollBar.vertical: ScrollBar { }

                    Text {
                        anchors.centerIn: parent
                        visible: root.service.clipboardHistory.length === 0
                        text: "Clipboard history is empty"
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
