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
    visible: service.toasts.length > 0
    implicitWidth: 380
    implicitHeight: Math.min(service.toasts.length, 5) * 96 + Math.max(0, Math.min(service.toasts.length, 5) - 1) * 8 + 20
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    exclusionMode: ExclusionMode.Ignore

    function urgencyColor(item) {
        if (item.urgency === NotificationUrgency.Critical) return "#b91c1c"
        if (item.urgency === NotificationUrgency.Low) return "#91b99e"
        return "#a2b0d1"
    }

    function urgencyTitleColor(item) {
        if (item.urgency === NotificationUrgency.Critical) return "#fecaca"
        if (item.urgency === NotificationUrgency.Low) return "#cde7d6"
        return "#d8def0"
    }

    function urgencyBodyColor(item) {
        if (item.urgency === NotificationUrgency.Critical) return "#fca5a5"
        if (item.urgency === NotificationUrgency.Low) return "#bcd9c8"
        return "#c5cfe2"
    }

    function urgencyBackground(item, hovered) {
        var hex = item.urgency === NotificationUrgency.Critical
            ? (hovered ? "#5c1010" : "#450a0a")
            : (item.urgency === NotificationUrgency.Low
                ? (hovered ? "#374f43" : "#2c4138")
                : (hovered ? "#3a455c" : "#30384b"))
        var tint = Qt.color(hex)
        return Qt.rgba(tint.r, tint.g, tint.b, 0.69)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        Repeater {
            model: root.service.toasts.slice(0, 5)
            delegate: Rectangle {
                id: toastCard
                required property var modelData
                width: root.width - 8
                height: 96
                radius: 14
                color: root.urgencyBackground(modelData, cardMouse.containsMouse)
                border.color: root.urgencyColor(modelData)
                border.width: 1

                GlowBorder {
                    targetItem: toastCard
                    cornerRadius: toastCard.radius
                    spread: 3
                    glowColor: root.urgencyColor(modelData)
                    accentGlowColor: root.urgencyColor(modelData)
                }

                Timer {
                    interval: Math.max(1, root.service.timeoutSeconds) * 1000
                    running: true
                    repeat: false
                    onTriggered: root.service.removeToast(modelData.id)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 10

                    Image {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
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
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: modelData.body
                            color: root.urgencyBodyColor(modelData)
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 23
                        implicitHeight: 23
                        radius: 6
                        color: dismissMouse.containsMouse ? root.urgencyColor(modelData) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: root.urgencyTitleColor(modelData)
                            font.pixelSize: 17
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
                    id: cardMouse
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
                    ShellToolTip {
                        parent: cardMouse
                        visible: cardMouse.containsMouse
                        text: "Left-click to focus " + modelData.appName + " · right-click to dismiss"
                    }
                }
            }
        }
    }
}
