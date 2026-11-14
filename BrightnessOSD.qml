import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var service

    screen: Quickshell.screens[0]
    visible: service.brightnessOsdVisible
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qscrollite-brightness-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: card }

    GlowBorder { targetItem: card; cornerRadius: card.radius }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        width: 260
        height: 46
        radius: 12
        color: "#eb111722"
        border.color: "#3b4a63"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰛨"
                    color: "#c0c0d8"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.service.brightnessPercent + "%"
                    color: "#c0c0d8"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 9
                }
            }

            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                implicitHeight: 18
                from: 1
                to: 100
                stepSize: 1
                value: root.service.brightnessPercent
                onMoved: root.service.setBrightness(value)

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#252f40"
                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: "#e5d887"
                    }
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 13
                    height: 13
                    radius: 7
                    color: "#f0dd89"
                    border.color: "#fff0b3"
                    border.width: 1
                }
            }
        }
    }
}
