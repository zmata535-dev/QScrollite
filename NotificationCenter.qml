import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    implicitWidth: screen.width
    implicitHeight: screen.height
    visible: service.notificationCenterOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: service.switcherService && service.switcherService.raisedCardModule === "notifications"
        ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real targetRightMargin: 16
    property real cardRightMargin: targetRightMargin
    property bool closing: false

    function openFromRight() {
        if (!root.visible || closing) return
        closing = false
        slideOut.stop()
        var offscreen = -(card.width > 0 ? card.width + 32 : 460)
        cardRightMargin = offscreen
        slideIn.from = offscreen
        slideIn.to = targetRightMargin
        slideIn.restart()
    }

    function closeWithSlide() {
        if (closing) return
        closing = true
        slideIn.stop()
        var offscreen = -(card.width > 0 ? card.width + 32 : 460)
        slideOut.from = cardRightMargin
        slideOut.to = offscreen
        slideOut.restart()
    }

    function urgencyColor(item) {
        if (!item) return "#a2b0d1"
        if (item.urgency === NotificationUrgency.Critical) return "#d79aa6"
        if (item.urgency === NotificationUrgency.Low) return "#91b99e"
        return "#a2b0d1"
    }

    function urgencyTitleColor(item) {
        if (!item) return "#d8def0"
        if (item.urgency === NotificationUrgency.Critical) return "#f0cbd3"
        if (item.urgency === NotificationUrgency.Low) return "#cde7d6"
        return "#d8def0"
    }

    function urgencyBodyColor(item) {
        if (!item) return "#c5cfe2"
        if (item.urgency === NotificationUrgency.Critical) return "#e2c3cb"
        if (item.urgency === NotificationUrgency.Low) return "#bcd9c8"
        return "#c5cfe2"
    }

    function urgencyBackground(item, hovered) {
        if (!item) return Qt.rgba(0.2, 0.25, 0.35, 0.69)
        var hex = item.urgency === NotificationUrgency.Critical
            ? (hovered ? "#5a3945" : "#4a303a")
            : (item.urgency === NotificationUrgency.Low
                ? (hovered ? "#374f43" : "#2c4138")
                : (hovered ? "#3a455c" : "#30384b"))
        var tint = Qt.color(hex)
        return Qt.rgba(tint.r, tint.g, tint.b, 0.69)
    }

    onVisibleChanged: {
        if (visible) {
            closing = false
            if (service.switcherService)
                service.switcherService.raiseCardModule("notifications")
            openFromRight()
        } else {
            closing = false
            slideIn.stop()
            slideOut.stop()
            cardRightMargin = targetRightMargin
        }
    }

    onWidthChanged: {
        if (visible && root.width > 0 && !closing && !slideIn.running && cardRightMargin !== targetRightMargin) {
            cardRightMargin = targetRightMargin
        }
    }

    Component.onCompleted: {
        if (visible) {
            if (service.switcherService)
                service.switcherService.raiseCardModule("notifications")
            openFromRight()
        }
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "cardRightMargin"
        duration: 280
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "cardRightMargin"
        duration: 220
        easing.type: Easing.InCubic
        onFinished: {
            root.closing = false
            root.cardRightMargin = root.targetRightMargin
            root.service.closeCenter()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeWithSlide()

        Rectangle {
            anchors.fill: parent
            color: "#35080c16"
            MouseArea {
                anchors.fill: parent
                onClicked: root.closeWithSlide()
            }
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: Math.min(315, root.width > 64 ? root.width - 32 : 315)
            height: Math.min(680, root.height > 64 ? root.height - 32 : 680)
            anchors.right: parent.right
            anchors.rightMargin: root.cardRightMargin
            anchors.verticalCenter: parent.verticalCenter
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    Rectangle {
                        visible: root.service.unread.length > 0
                        implicitWidth: clearLabel.implicitWidth + 14
                        implicitHeight: 24
                        radius: 6
                        color: clearMouse.containsMouse ? "#3b1e28" : "#161d2a"
                        border.color: clearMouse.containsMouse ? "#ff6b81" : "#2b364a"
                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: clearMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.dismissAllUnread()
                        }
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 6
                        color: closeMouse.containsMouse ? "#3b1e28" : "#161d2a"
                        border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeWithSlide()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.service.unread.length === 0
                        text: "No unread notifications"
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 12
                    }

                    ListView {
                        anchors.fill: parent
                        spacing: 8
                        clip: true
                        model: root.service.unread
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 92
                            radius: 9
                            color: root.urgencyBackground(modelData, notificationMouse.containsMouse)
                            border.color: root.urgencyColor(modelData)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.appName + (modelData.summary ? " · " + modelData.summary : "")
                                        color: root.urgencyTitleColor(modelData)
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.body
                                        color: root.urgencyBodyColor(modelData)
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 10
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 6
                                    color: dismissMouse.containsMouse ? "#3b1e28" : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: dismissMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        id: dismissMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.service.dismiss(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: notificationMouse
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton)
                                        root.service.activate(modelData)
                                    else
                                        root.service.dismiss(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
