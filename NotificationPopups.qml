import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

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
                color: "#111722"
                border.color: "#8da9d6"
                border.width: 1

                GlowBorder {
                    targetItem: toastCard
                    cornerRadius: toastCard.radius
                    spread: 3
                    glowColor: "#8da9d6"
                    accentGlowColor: "#8da9d6"
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
                            color: "#c0c0d8"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: modelData.body
                            color: "#e2e8f0"
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
                        color: dismissMouse.containsMouse ? "#34445f" : "transparent"
                        Text { anchors.centerIn: parent; text: "×"; color: "#c0c0d8"; font.pixelSize: 17 }
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
                    onClicked: root.service.activate(modelData)
                    ShellToolTip {
                        parent: cardMouse
                        visible: cardMouse.containsMouse
                        text: "Click to focus " + modelData.appName
                    }
                }
            }
        }
    }
}
