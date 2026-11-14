import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    visible: service.notificationCenterOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: pairedWithCalendar ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    readonly property bool pairedWithCalendar: service.switcherService
        ? (service.switcherService.calendarOpen || service.switcherService.calendarPending) : false
    readonly property real pairedCalendarWidth: Math.min(388, (root.width - 48) * 0.38)
    readonly property real pairedNotificationWidth: Math.min(560, (root.width - 48) * 0.56)
    property var pairedInputRegion: Region { item: card }
    mask: pairedWithCalendar ? pairedInputRegion : null

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.service.closeCenter()

        Rectangle {
            anchors.fill: parent
            color: root.pairedWithCalendar ? "transparent" : "#35080c16"
            MouseArea {
                anchors.fill: parent
                onClicked: root.service.closeCenter()
            }
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: root.pairedWithCalendar
                ? root.pairedNotificationWidth : Math.min(560, root.width - 32)
            height: Math.min(520, root.height - 32)
            x: root.pairedWithCalendar
                ? (root.width - root.pairedCalendarWidth - 14 - root.pairedNotificationWidth) / 2
                    + root.pairedCalendarWidth + 14
                : (root.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    Text {
                        visible: root.service.unread.length > 0
                        text: "Clear all"
                        color: clearMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 10
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            anchors.margins: -6
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
                            onClicked: root.service.closeCenter()
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
                            height: 82
                            radius: 9
                            color: notificationMouse.containsMouse ? "#202a3a" : "#161d2a"
                            border.color: "#2b364a"

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
                                        color: "#c0c0d8"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.body
                                        color: "#e2e8f0"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 10
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 2
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
                                        text: "×"
                                        color: dismissMouse.containsMouse ? "#ffb3ba" : "#8092ab"
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
