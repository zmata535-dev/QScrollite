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
    WlrLayershell.namespace: "quickshell-idle-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function closeCard() {
        service.idleConfigOpen = false
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeCard()

        Rectangle {
            anchors.fill: parent
            color: "#99080c16"

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeCard()
            }
        }

        Rectangle {
            id: card
            width: Math.min(480, root.width - 32)
            height: Math.min(610, root.height - 32)
            anchors.centerIn: parent
            radius: 16
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Idle timer settings"
                        color: "#e2e8f0"
                        font.pixelSize: 19
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 8
                        color: closeMouse.containsMouse ? "#3b1e28" : "#1a2230"
                        border.color: closeMouse.containsMouse ? "#ff6b81" : "#35445c"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#ffb3ba" : "#94a3b8"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeCard()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Set how many seconds of inactivity trigger each action."
                    color: "#94a3b8"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Text { text: "Show clock card"; color: "#dce5f2"; font.pixelSize: 13 }
                    SpinBox {
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleClockTimeout
                        onValueModified: root.service.idleClockTimeout = value
                    }

                    Text { text: "Dim display to 10%"; color: "#dce5f2"; font.pixelSize: 13 }
                    SpinBox {
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleDimTimeout
                        onValueModified: root.service.idleDimTimeout = value
                    }

                    Text { text: "Turn display off"; color: "#dce5f2"; font.pixelSize: 13 }
                    SpinBox {
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleDisplayOffTimeout
                        onValueModified: root.service.idleDisplayOffTimeout = value
                    }

                    Text { text: "Lock screen"; color: "#dce5f2"; font.pixelSize: 13 }
                    SpinBox {
                        Layout.fillWidth: true
                        from: 1; to: 3600; editable: true
                        value: root.service.idleLockTimeout
                        onValueModified: root.service.idleLockTimeout = value
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#283448" }

                Text {
                    text: "Clock card appearance"
                    color: "#abc7ff"
                    font.pixelSize: 14
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Clock text color"
                        color: "#dce5f2"
                        font.pixelSize: 13
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        color: root.service.idleClockTextColor
                        border.color: "#64748b"
                    }

                    TextField {
                        id: colorField
                        Layout.preferredWidth: 112
                        text: root.service.idleClockTextColor
                        placeholderText: "#e2e8f0"
                        maximumLength: 7
                        color: "#111722"
                        onEditingFinished: {
                            if (/^#[0-9a-fA-F]{6}$/.test(text)) {
                                root.service.idleClockTextColor = text
                            } else {
                                text = root.service.idleClockTextColor
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Clock font size"
                        color: "#dce5f2"
                        font.pixelSize: 13
                    }
                    SpinBox {
                        from: 32; to: 160; editable: true
                        value: root.service.idleClockTextSize
                        onValueModified: root.service.idleClockTextSize = value
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.service.idleApplyStatus
                        color: root.service.idleApplyStatus.indexOf("Could not") === 0 ? "#ffb4ab" : "#94a3b8"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "Apply"
                        enabled: !root.service.idleApplyProcess.running
                        onClicked: root.service.applyIdleSettings()
                    }
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
}
