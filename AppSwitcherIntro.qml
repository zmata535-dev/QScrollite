import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: introWindow

    signal handoff()
    signal finished()

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
    WlrLayershell.namespace: "quickshell-app-switcher-intro"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    // t = 0: Fake top bar (bottom-row on left, top-row clock center + icons right) + bottom dock (middle strip)
    // t = 1: Unified AppSwitcher layout at bottom-center
    property real morphProgress: 0
    property real overlayOpacity: 1
    property var now: new Date()

    readonly property real cardWidth: Math.min(introWindow.width - 32, 610)
    readonly property real cardHeight: 132
    readonly property real cardX: (introWindow.width - cardWidth) / 2
    readonly property real cardY: introWindow.height - cardHeight

    readonly property real topBarY: 10
    readonly property real topBarHeight: 34
    readonly property real topBarLeftX: 16
    readonly property real topBarRightX: introWindow.width - 16

    function lerp(a, b, t) {
        return a + (b - a) * t
    }

    SequentialAnimation {
        id: introSequence
        running: true

        PauseAnimation { duration: 450 }

        NumberAnimation {
            target: introWindow
            property: "morphProgress"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.InOutCubic
        }

        PauseAnimation { duration: 550 }

        ScriptAction {
            script: introWindow.handoff()
        }

        NumberAnimation {
            target: introWindow
            property: "overlayOpacity"
            from: 1
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: introWindow.finished()
        }
    }

    Item {
        anchors.fill: parent
        opacity: introWindow.overlayOpacity

        // 1. Fake Top Bar container (fades out as its left & center+right parts detach)
        Rectangle {
            id: fakeTopBar
            x: introWindow.topBarLeftX
            y: introWindow.topBarY
            width: introWindow.width - 32
            height: introWindow.topBarHeight
            radius: 10
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
            opacity: Math.max(0, 1 - introWindow.morphProgress * 1.4)
        }

        // 2. Real AppSwitcher card shell at bottom-center (fades in as parts assemble)
        GlowBorder {
            targetItem: targetCard
            cornerRadius: targetCard.radius
            opacity: introWindow.morphProgress
        }

        Rectangle {
            id: targetCard
            x: introWindow.lerp((introWindow.width - dockStrip.width - 18) / 2, introWindow.cardX, introWindow.morphProgress)
            y: introWindow.lerp(introWindow.height - 72, introWindow.cardY, introWindow.morphProgress)
            width: introWindow.lerp(dockStrip.width + 18, introWindow.cardWidth, introWindow.morphProgress)
            height: introWindow.lerp(62, introWindow.cardHeight, introWindow.morphProgress)
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            // Subtle dividers matching AppSwitcher
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                y: 38
                height: 1
                color: "#222e42"
                opacity: Math.max(0, (introWindow.morphProgress - 0.55) / 0.45)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                y: 98
                height: 1
                color: "#222e42"
                opacity: Math.max(0, (introWindow.morphProgress - 0.55) / 0.45)
            }
        }

        // 3. TOP ROW PART (Center clock + Right system icons in fake top bar -> Top row of AppSwitcher)
        // 3a. Clock + Date (Fake top bar center -> AppSwitcher top-left)
        RowLayout {
            id: topClockGroup
            readonly property real startX: (introWindow.width - implicitWidth) / 2
            readonly property real startY: introWindow.topBarY + (introWindow.topBarHeight - implicitHeight) / 2
            readonly property real endX: introWindow.cardX + 10
            readonly property real endY: introWindow.cardY + 7
            x: introWindow.lerp(startX, endX, introWindow.morphProgress)
            y: introWindow.lerp(startY, endY, introWindow.morphProgress)
            spacing: 6

            ColumnLayout {
                spacing: -4
                Text {
                    text: Qt.formatDateTime(introWindow.now, "HH:mm")
                    color: "#f1f5f9"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.weight: Font.Light
                    font.pixelSize: 17
                }
                Text {
                    text: Qt.formatDate(introWindow.now, "ddd dd MMM")
                    color: "#8092ab"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.weight: Font.Light
                    font.pixelSize: 8
                }
            }
        }

        // 3b. Right icons of top row (Fake top bar right -> AppSwitcher top-right)
        Row {
            id: topRightGroup
            readonly property real startX: introWindow.topBarRightX - implicitWidth - 10
            readonly property real startY: introWindow.topBarY + (introWindow.topBarHeight - implicitHeight) / 2
            readonly property real endX: introWindow.cardX + introWindow.cardWidth - implicitWidth - 10
            readonly property real endY: introWindow.cardY + 10
            x: introWindow.lerp(startX, endX, introWindow.morphProgress)
            y: introWindow.lerp(startY, endY, introWindow.morphProgress)
            spacing: 4

            Rectangle {
                width: 22; height: 22; radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#354765" }
                    GradientStop { position: 1.0; color: "#19263b" }
                }
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: "#e3f8ff"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 14
                }
            }

            Repeater {
                model: ["?", "󰅍", "󰕾", "󰛨", "󰂯", "󰖩", "󰂚", "⌄"]
                delegate: Rectangle {
                    required property string modelData
                    width: 22; height: 22; radius: 6
                    color: "#161d2a"
                    border.color: "#2b364a"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 13
                    }
                }
            }
        }

        // 4. MIDDLE PART (Dock at bottom-center -> Middle strip of AppSwitcher)
        Rectangle {
            id: dockStrip
            readonly property real startW: Math.min(introWindow.width - 64, 430)
            readonly property real endW: introWindow.cardWidth - 18
            readonly property real startX: (introWindow.width - startW) / 2
            readonly property real startY: introWindow.height - 68
            readonly property real endX: introWindow.cardX + 9
            readonly property real endY: introWindow.cardY + 42

            x: introWindow.lerp(startX, endX, introWindow.morphProgress)
            y: introWindow.lerp(startY, endY, introWindow.morphProgress)
            width: introWindow.lerp(startW, endW, introWindow.morphProgress)
            height: 52
            radius: 8
            color: "#070b12"
            clip: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                spacing: 6

                // App menu launcher icon
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; radius: 8
                    color: "#18202d"
                    border.color: "#2a364a"
                    border.width: 1
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: 3
                        Repeater {
                            model: 4
                            Rectangle { width: 5; height: 5; radius: 1; color: "#abc7ff" }
                        }
                    }
                }

                // Part 1: Fake pinned apps (not running)
                Repeater {
                    model: ["#7aa2f7", "#9ece6a", "#bb9af7"]
                    delegate: Rectangle {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 9
                        color: "#141b28"
                        border.color: "#263246"
                        border.width: 1
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 4
                            color: modelData
                            opacity: 0.85
                        }
                    }
                }

                // Vertical separator between pinned apps and workspaces
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 32
                    color: "#263246"
                }

                // Part 2: Fake workspace pill groups with open apps
                Repeater {
                    model: [
                        { label: "1", apps: [
                            { color: "#7dcfff", focused: true },
                            { color: "#e0af68", focused: false }
                        ]},
                        { label: "2", apps: [
                            { color: "#f7768e", focused: false },
                            { color: "#89b4fa", focused: false }
                        ]}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 10
                        color: "#0d121c"
                        implicitWidth: wsRow.implicitWidth + 10
                        implicitHeight: 38

                        Row {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 26
                                radius: 6
                                color: "#1c2536"
                                border.color: "#2e3e57"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: "#abc7ff"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.weight: Font.Light
                                    font.pixelSize: 10
                                }
                            }

                            Repeater {
                                model: modelData.apps
                                delegate: Rectangle {
                                    required property var modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32; height: 32; radius: 9
                                    color: modelData.focused ? "#792c5568" : "#141b28"
                                    border.color: modelData.focused ? "#3b4a63" : "#263246"
                                    border.width: 1
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 16; height: 16; radius: 4
                                        color: modelData.color
                                        opacity: 0.85
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 5. BOTTOM PART (Left part of fake top bar -> Bottom row of AppSwitcher)
        Row {
            id: bottomRowGroup
            readonly property real startX: introWindow.topBarLeftX + 10
            readonly property real startY: introWindow.topBarY + (introWindow.topBarHeight - implicitHeight) / 2
            readonly property real endX: introWindow.cardX + 10
            readonly property real endY: introWindow.cardY + 102
            x: introWindow.lerp(startX, endX, introWindow.morphProgress)
            y: introWindow.lerp(startY, endY, introWindow.morphProgress)
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Workspace"
                color: "#8092ab"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.weight: Font.Light
                font.pixelSize: 10
            }

            Repeater {
                model: ["+", "↻", "⟳", "󰒓", "󰍃", "󰜉", "⏻"]
                delegate: Rectangle {
                    required property string modelData
                    width: 22; height: 22; radius: 6
                    color: "#161d2a"
                    border.color: "#2b364a"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
