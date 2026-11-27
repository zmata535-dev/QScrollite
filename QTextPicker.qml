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
    visible: service.qTextPickerOpen
    color: "#99080c16"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: service.raisedCardModule === "qtextpicker" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-qtextpicker"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    property real cardX: -700
    property real openTargetX: 16

    function positionOppositeFocusedWindow() {
        var targetX = PanelPlacement.oppositeTargetX(service, root.screen.x,
            root.width, card.width, 16)
        var margin = Math.min(16, Math.max(0, (root.width - card.width) / 2))
        openTargetX = Math.max(margin, Math.min(targetX, root.width - card.width - margin))
    }

    function openFromLeft() {
        Qt.callLater(function() {
            if (!root.visible || card.width <= 0 || root.width <= 0) return
            root.positionOppositeFocusedWindow()
            root.cardX = PanelPlacement.leftEntryX(root.screen.x, card.width, 16)
            slideIn.to = root.openTargetX
            slideIn.restart()
        })
    }

    function repositionAfterFocusChange() {
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
        function onActiveWindowIdChanged() { root.repositionAfterFocusChange() }
        function onOpenChanged() { if (!root.service.open) root.repositionAfterFocusChange() }
    }

    onVisibleChanged: {
        if (visible) openFromLeft()
        else slideIn.stop()
    }
    Component.onCompleted: if (visible) openFromLeft()

    function close() { service.qTextPickerOpen = false }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: card
        x: root.cardX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(640, root.width - 32)
        height: Math.min(560, root.height - 40)
        radius: 14
        color: "#111722"
        border.color: "#3b4a63"
        border.width: 1
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "QTextPicker"
                    color: "#e2e8f0"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                ShellButton { text: "×"; onClicked: root.close() }
            }

            Text {
                Layout.fillWidth: true
                text: "Click Select screen area, then drag over the text. A bright cyan outline marks your selection."
                color: "#9aa8be"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                ShellButton {
                    text: service.qTextPickerCapturing ? "Selecting…" : "Select screen area"
                    accent: true
                    enabled: !service.qTextPickerCapturing
                    onClicked: service.captureScreenText()
                }
                ShellButton {
                    text: "Copy text"
                    enabled: service.qTextPickerResult.length > 0
                    onClicked: service.copyQTextPickerResult()
                }
                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                text: service.qTextPickerStatus
                color: service.qTextPickerStatus.indexOf("failed") >= 0 ||
                    service.qTextPickerStatus.indexOf("Install") === 0 ? "#ffb4ab" : "#abc7ff"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            TextArea {
                id: resultArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Component.onCompleted: text = service.qTextPickerResult
                placeholderText: "Captured text appears here…"
                color: "#e2e8f0"
                placeholderTextColor: "#728097"
                selectionColor: "#5476a4"
                selectedTextColor: "#ffffff"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 12
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                background: Rectangle {
                    color: "#0b1019"
                    radius: 8
                    border.color: resultArea.activeFocus ? "#5476a4" : "#273448"
                }
                onTextChanged: {
                    if (text !== service.qTextPickerResult)
                        service.qTextPickerResult = text
                }

                Connections {
                    target: root.service
                    function onQTextPickerResultChanged() {
                        if (resultArea.text !== root.service.qTextPickerResult)
                            resultArea.text = root.service.qTextPickerResult
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Uses grim, slurp, and Tesseract OCR (English)."
                    color: "#728097"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
                ShellButton { text: "Done"; onClicked: root.close() }
            }
        }
    }
}
