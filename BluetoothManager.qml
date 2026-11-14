import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    visible: service.bluetoothOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qscrollite-bluetooth-manager"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.service.closeBluetoothManager()

        Rectangle {
            anchors.fill: parent
            color: "#35080c16"
            MouseArea {
                anchors.fill: parent
                onClicked: root.service.closeBluetoothManager()
            }
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: Math.min(580, root.width - 32)
            height: Math.min(560, root.height - 32)
            anchors.centerIn: parent
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
                        text: "Bluetooth"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 16
                    }
                    ShellButton {
                        visible: !root.service.bluetoothDaemonReady
                            && root.service.bluetoothMessage !== "No Bluetooth adapter found"
                        font.pixelSize: 10
                        text: "Start service"
                        enabled: !root.service.bluetoothServiceStartProcess.running
                        onClicked: root.service.startBluetoothService(false)
                    }
                    ShellButton {
                        font.pixelSize: 10
                        text: root.service.bluetoothPowered ? "Power off" : "Power on"
                        onClicked: root.service.setBluetoothPower(!root.service.bluetoothPowered)
                    }
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 6
                        color: closeMouse.containsMouse ? "#3b1e28" : "#161d2a"
                        border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.closeBluetoothManager()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.service.bluetoothScanning ? "Scanning for nearby devices…" : "Nearby and known devices"
                        color: "#94a3b8"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 10
                    }
                    ShellButton {
                        font.pixelSize: 10
                        text: root.service.bluetoothScanning ? "Scanning…" : "Scan"
                        enabled: root.service.bluetoothDaemonReady && root.service.bluetoothPowered
                            && !root.service.bluetoothScanning
                        onClicked: root.service.scanBluetooth()
                    }
                    ShellButton {
                        font.pixelSize: 10
                        text: "Refresh"
                        enabled: !root.service.bluetoothRefreshProcess.running
                        onClicked: root.service.refreshBluetooth()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                Text {
                    Layout.fillWidth: true
                    visible: root.service.bluetoothMessage.length > 0
                    text: root.service.bluetoothMessage
                    color: "#abc7ff"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: deviceColumn.implicitHeight
                        ScrollBar.vertical: ScrollBar { }

                        Column {
                            id: deviceColumn
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.service.bluetoothDevices
                                delegate: Rectangle {
                                    required property var modelData
                                    width: deviceColumn.width
                                    height: 58
                                    radius: 8
                                    color: "#151e2c"
                                    border.color: "#2b364a"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: "#dce5f2"
                                                font.family: "JetBrainsMono Nerd Font Mono"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.address
                                                color: "#8092ab"
                                                font.family: "JetBrainsMono Nerd Font Mono"
                                                font.pixelSize: 9
                                            }
                                        }

                                        ShellButton {
                                            font.pixelSize: 9
                                            text: "Pair"
                                            enabled: root.service.bluetoothDaemonReady && root.service.bluetoothPowered
                                            onClicked: root.service.pairBluetooth(modelData.address)
                                        }
                                        ShellButton {
                                            font.pixelSize: 9
                                            text: "Connect"
                                            enabled: root.service.bluetoothDaemonReady && root.service.bluetoothPowered
                                            onClicked: root.service.connectBluetooth(modelData.address)
                                        }
                                        ShellButton {
                                            font.pixelSize: 9
                                            text: "Disconnect"
                                            enabled: root.service.bluetoothDaemonReady && root.service.bluetoothPowered
                                            onClicked: root.service.disconnectBluetooth(modelData.address)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.service.bluetoothDevices.length === 0 && !root.service.bluetoothMessage
                        text: "No devices found yet. Start a scan to discover nearby devices."
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 10
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Pair first, then connect. Some devices may ask for confirmation."
                    color: "#64748b"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
