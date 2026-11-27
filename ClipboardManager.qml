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
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: service.raisedCardModule === "clipboard" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard-manager"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { Region { item: card } }
    property real cardX: -600
    property real openTargetX: 12
    property bool openingScheduled: false

    function focusedWindowGeometry() {
        var activeId = String(service.activeWindowId || "")
        var workspaces = service.workspaces || []
        for (var i = 0; i < workspaces.length; i++) {
            var windows = workspaces[i].windows || []
            for (var j = 0; j < windows.length; j++) {
                if (String(windows[j].id) === activeId) return windows[j]
            }
        }
        return null
    }

    function positionOppositeFocusedWindow() {
        var margin = 12
        var activeWindow = focusedWindowGeometry()
        if (!activeWindow) {
            openTargetX = PanelPlacement.oppositeTargetX(service, root.screen.x,
                root.width, card.width, margin)
            return
        }

        var screenX = Number(root.screen.x || 0)
        var windowLeft = Number(activeWindow.x || 0) - screenX
        var windowRight = windowLeft + Number(activeWindow.width || 0)
        var leftSpace = Math.max(0, windowLeft - margin)
        var rightSpace = Math.max(0, root.width - windowRight - margin)
        var windowCenter = windowLeft + Number(activeWindow.width || 0) / 2
        var preferRight = windowCenter < root.width / 2

        if (preferRight && rightSpace >= card.width)
            openTargetX = root.width - card.width - margin
        else if (!preferRight && leftSpace >= card.width)
            openTargetX = margin
        else if (leftSpace >= card.width)
            openTargetX = margin
        else if (rightSpace >= card.width)
            openTargetX = root.width - card.width - margin
        else
            openTargetX = leftSpace >= rightSpace ? margin : root.width - card.width - margin
    }

    function openFromOppositeSide() {
        if (!visible || slideIn.running || openingScheduled) return
        openingScheduled = true
        Qt.callLater(function() {
            root.openingScheduled = false
            if (!root.visible || card.width <= 0 || root.width <= 0) return
            positionOppositeFocusedWindow()
            cardX = PanelPlacement.leftEntryX(root.screen.x, card.width, 12)
            slideIn.to = openTargetX
            slideIn.restart()
        })
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
            openFromOppositeSide()
        } else {
            slideIn.stop()
        }
    }

    Component.onCompleted: {
        if (visible) openFromOppositeSide()
    }

    onWidthChanged: {
        if (visible && !slideIn.running && cardX !== openTargetX)
            openFromOppositeSide()
    }

    function close() {
        service.clipboardOpen = false
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.close()
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
            width: Math.min(560, root.width - 32) * 0.6
            height: Math.min(620, root.height - 64)
            x: root.cardX
            y: (parent.height - height) / 2
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
            focus: false

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onPressedChanged: {
                    if (pressed) root.service.raiseCardModule("clipboard")
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: root.service.raiseCardModule("clipboard")
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Clipboard Manager"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }
                    ShellButton {
                        id: captureTextButton
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 26
                        text: "▤"
                        onClicked: root.service.openQTextPicker()
                        ShellToolTip {
                            parent: captureTextButton
                            visible: captureTextButton.hovered
                            text: "Capture text"
                        }
                    }
                    ShellButton {
                        id: clearHistoryButton
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 26
                        text: "⌫"
                        danger: true
                        enabled: root.service.clipboardHistory.length > 0
                        onClicked: root.service.clearClipboardHistory()
                        ShellToolTip {
                            parent: clearHistoryButton
                            visible: clearHistoryButton.hovered
                            text: "Clear history"
                        }
                    }
                    ShellButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 26
                        text: "×"
                        onClicked: root.close()
                    }
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
                        height: Math.max(48, contentText.implicitHeight + 12)
                        radius: 7
                        color: itemMouse.containsMouse ? "#202a3a" : "#161d2a"
                        border.color: itemMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text {
                            id: contentText
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 42
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            text: root.previewText(modelData)
                            color: "#dce5f2"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: contentText
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.copyClipboardHistoryItem(modelData)
                        }

                        ShellButton {
                            id: moveToNoteButton
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 24
                            text: "➜▤"
                            leftPadding: 1
                            rightPadding: 1
                            font.family: "DejaVu Sans"
                            font.pixelSize: 12
                            onClicked: root.service.moveClipboardHistoryItemToNote(modelData)

                            ShellToolTip {
                                parent: moveToNoteButton
                                visible: moveToNoteButton.hovered
                                text: "Move to Note"
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        parent: historyList
                        anchors.top: historyList.top
                        anchors.right: historyList.right
                        anchors.bottom: historyList.bottom
                    }

                    Rectangle {
                        anchors.top: historyList.top
                        anchors.left: historyList.left
                        anchors.right: historyList.right
                        height: 14
                        z: 2
                        visible: historyList.contentY > 1
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#ee111722" }
                            GradientStop { position: 1; color: "#00111722" }
                        }
                    }

                    Rectangle {
                        anchors.bottom: historyList.bottom
                        anchors.left: historyList.left
                        anchors.right: historyList.right
                        height: 14
                        z: 2
                        visible: historyList.contentY + historyList.height < historyList.contentHeight - 1
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#00111722" }
                            GradientStop { position: 1; color: "#ee111722" }
                        }
                    }

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
