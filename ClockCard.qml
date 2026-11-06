import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var now: new Date()
    property bool colonVisible: true
    readonly property string dateLabel: Qt.formatDate(now, "dddd, dd MMM yyyy")

    function closeClock() {
        service.clockOpen = false
    }

    Timer {
        interval: 500
        repeat: true
        running: root.visible
        onTriggered: {
            root.now = new Date()
            root.colonVisible = !root.colonVisible
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeClock()

        Rectangle {
            anchors.fill: parent
            color: "#99080c16"

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeClock()
            }
        }

        Rectangle {
            id: card
            width: Math.min(520, root.width - 32)
            height: 212
            anchors.centerIn: parent
            radius: 18
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(root.now, "HH")
                        color: root.service.idleClockTextColor
                        font.family: "Cantarell"
                        font.pixelSize: root.service.idleClockTextSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.preferredWidth: 36
                        text: ":"
                        color: root.service.idleClockTextColor
                        opacity: root.colonVisible ? 1 : 0.18
                        font.family: "Cantarell"
                        font.pixelSize: root.service.idleClockTextSize * 0.94
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(root.now, "mm")
                        color: root.service.idleClockTextColor
                        font.family: "Cantarell"
                        font.pixelSize: root.service.idleClockTextSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 14
                    text: root.dateLabel
                    color: "#94a3b8"
                    font.family: "Cantarell"
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
}
