import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: switcherWindow

    required property var service

    screen: Quickshell.screens[0]
    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-app-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    color: "#35080c16"

    property var now: new Date()
    property bool focusedIconScrollPending: true

    function scrollToFocusedIcon(iconItem) {
        if (!focusedIconScrollPending) return
        Qt.callLater(function() {
            if (!switcherWindow.visible || !iconItem) return
            var point = iconItem.mapToItem(appsFlickable.contentItem, iconItem.width / 2, iconItem.height / 2)
            appsFlickable.contentX = Math.max(0, Math.min(
                appsFlickable.contentWidth - appsFlickable.width,
                point.x - appsFlickable.width / 2
            ))
            switcherWindow.focusedIconScrollPending = false
        })
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: switcherWindow.visible
        onTriggered: {
            switcherWindow.now = new Date();
        }
    }

    Component {
        id: nextWorkspaceButtonComponent

        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 6
            color: nextWorkspaceMouse.containsMouse ? "#273650" : "#161d2a"
            border.color: nextWorkspaceMouse.containsMouse ? "#abc7ff" : "#2b364a"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "↓"
                color: nextWorkspaceMouse.containsMouse ? "#abc7ff" : "#8092ab"
                font.pixelSize: 15
            }

            MouseArea {
                id: nextWorkspaceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switcherWindow.service.nextWorkspace()
            }
        }
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: {
            switcherWindow.service.closeSwitcher();
        }
    }

    // Keyboard handling
    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            switcherWindow.service.closeSwitcher();
        }
    }

    // Floating Switcher Bar anchored near top-left
    Rectangle {
        id: container
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 16
            leftMargin: 16
        }

        width: Math.min(switcherWindow.width - 32, Math.max(380, mainCol.implicitWidth + 28))
        height: mainCol.implicitHeight + 24

        color: "#111622"
        radius: 14
        border.color: "#283448"
        border.width: 1

        // Prevent background clicks through the panel
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: {}
        }

        ColumnLayout {
            id: mainCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 10

            // Header Row (Clock, Date, Compositor Chip, Preview Toggle, Close)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Two-line Clock and Date
                Item {
                    implicitWidth: clockDisplay.implicitWidth
                    implicitHeight: clockDisplay.implicitHeight

                    ColumnLayout {
                        id: clockDisplay
                        spacing: 1

                        Text {
                            text: Qt.formatDateTime(switcherWindow.now, "HH:mm")
                            color: "#f1f5f9"
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Text {
                            text: Qt.formatDateTime(switcherWindow.now, "dddd, dd MMM yy")
                            color: "#94a3b8"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openCalendar()
                    }
                }

                Item { Layout.fillWidth: true }

                // Compositor Chip
                Rectangle {
                    color: "#182234"
                    radius: 5
                    border.color: "#2c3b54"
                    border.width: 1
                    implicitWidth: compText.implicitWidth + 12
                    implicitHeight: 22

                    Text {
                        id: compText
                        anchors.centerIn: parent
                        text: switcherWindow.service.activeCompositor.toUpperCase()
                        color: "#abc7ff"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                // Configure the idle timers and clock card appearance
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: idleSettingsMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "◷"
                        color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: idleSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openIdleConfig()
                    }
                }

                // Open the wallpaper picker
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: wallpaperMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: wallpaperMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "▧"
                        color: wallpaperMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: wallpaperMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.toggleWallpaperSelector()
                    }
                }

                // Close Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: closeMouse.containsMouse ? "#3b1e28" : "#1a202d"
                    border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"
                    border.width: 1

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
                        onClicked: {
                            switcherWindow.service.closeSwitcher();
                        }
                    }
                }
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1f2838"
            }

            // Main Horizontal Apps & Workspaces Strip
            Flickable {
                id: appsFlickable
                Layout.fillWidth: true
                implicitHeight: 82
                contentWidth: appsRow.childrenRect.width
                contentHeight: 74
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Let a mouse wheel scroll the long strip horizontally too.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        if (appsFlickable.contentWidth <= appsFlickable.width) return
                        appsFlickable.contentX = Math.max(0, Math.min(
                            appsFlickable.contentWidth - appsFlickable.width,
                            appsFlickable.contentX - wheel.angleDelta.y
                        ))
                        wheel.accepted = true
                    }
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Row {
                    id: appsRow
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter

                    // 1. FIRST ICON: BUTTON FOR THE QUICKShell APP MENU
                    Rectangle {
                        id: appMenuBtn
                        width: 54
                        height: 64
                        radius: 10
                        color: appMenuMouse.containsMouse ? "#273650" : "#192233"
                        border.color: appMenuMouse.containsMouse ? "#abc7ff" : "#384a6b"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            // Launcher grid / icon
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 32
                                height: 32
                                radius: 8
                                color: "#25344e"

                                // Grid of 4 rounded dots
                                Grid {
                                    anchors.centerIn: parent
                                    columns: 2
                                    spacing: 4
                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            width: 7
                                            height: 7
                                            radius: 2
                                            color: appMenuMouse.containsMouse ? "#abc7ff" : "#8ba6d9"
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Apps"
                                color: appMenuMouse.containsMouse ? "#abc7ff" : "#8ca0be"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: appMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switcherWindow.service.openAppMenu();
                            }
                        }
                    }

                    // Vertical Separator
                    Rectangle {
                        width: 1
                        height: 48
                        color: "#263246"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 2. WORKSPACES (DIVIDED HORIZONTALLY, EXCLUDING EMPTY)
                    Repeater {
                        model: switcherWindow.service.workspaces

                        // Workspace Column / Pill Group
                        Rectangle {
                            id: wsBox
                            radius: 10
                            color: "#151b27"
                            border.color: "#232d3f"
                            border.width: 1
                            implicitWidth: wsContentRow.implicitWidth + 14
                            implicitHeight: 64

                            Row {
                                id: wsContentRow
                                anchors.centerIn: parent
                                spacing: 8

                                // Workspace Label Badge
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 48
                                    radius: 6
                                    color: "#1c2536"
                                    border.color: "#2e3e57"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name || modelData.id
                                        color: "#abc7ff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                // Open Apps in this workspace (Sorted by layout position)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Repeater {
                                        model: modelData.windows

                                        // App Icon Button
                                        Rectangle {
                                            id: appCard
                                            width: 48
                                            height: 48
                                            radius: 9

                                            color: modelData.focused ? "#22334f" : (appMouse.containsMouse ? "#202a3a" : "#18202d")
                                            border.color: modelData.focused ? "#abc7ff" : (appMouse.containsMouse ? "#4e6285" : "#2a364a")
                                            border.width: modelData.focused ? 2 : 1

                                            Component.onCompleted: {
                                                if (modelData.focused) switcherWindow.scrollToFocusedIcon(appCard)
                                            }

                                            // App Icon Image
                                            Image {
                                                id: iconImg
                                                anchors.centerIn: parent
                                                width: 30
                                                height: 30
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                source: modelData.icon || ""
                                                visible: status === Image.Ready && source !== ""
                                            }

                                            // Fallback initial letter badge if icon not loaded
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 30
                                                height: 30
                                                radius: 6
                                                color: "#26354c"
                                                visible: !iconImg.visible

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (modelData.appId || modelData.title || "?").substring(0, 1).toUpperCase()
                                                    color: "#abc7ff"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }
                                            }

                                            // Focus Indicator Dot
                                            Rectangle {
                                                anchors {
                                                    bottom: parent.bottom
                                                    bottomMargin: 3
                                                    horizontalCenter: parent.horizontalCenter
                                                }
                                                width: 4
                                                height: 4
                                                radius: 2
                                                color: "#abc7ff"
                                                visible: !!modelData.focused
                                            }

                                            MouseArea {
                                                id: appMouse
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    top: parent.top
                                                    bottom: parent.bottom
                                                    topMargin: -10
                                                }
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                ToolTip {
                                                    id: appInfoTooltip
                                                    parent: appCard
                                                    visible: appMouse.containsMouse
                                                    delay: 450
                                                    timeout: 12000
                                                    text: (modelData.appId || "Application") + ": " + (modelData.title || "Untitled")

                                                    background: Rectangle {
                                                        color: "#EB000000"
                                                        radius: 6
                                                    }

                                                    contentItem: Text {
                                                        text: appInfoTooltip.text
                                                        color: "#c0c0d8"
                                                        font.pixelSize: 11
                                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                    }
                                                }

                                                onEntered: {
                                                    switcherWindow.service.hoveredWindow = modelData;
                                                }

                                                onExited: {
                                                    if (switcherWindow.service.hoveredWindow === modelData) {
                                                        switcherWindow.service.hoveredWindow = null;
                                                    }
                                                }

                                                onClicked: function(mouse) {
                                                    var point = appMouse.mapToItem(appCard, mouse.x, mouse.y)
                                                    if (point.x >= appCard.width - 18 && point.y >= -10 && point.y <= 8) {
                                                        switcherWindow.service.closeWindow(modelData)
                                                    } else {
                                                        switcherWindow.service.focusWindow(modelData)
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: closeAppButton
                                                z: 2
                                                width: 18
                                                height: 18
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.topMargin: -10
                                                radius: 5
                                                visible: appMouse.containsMouse
                                                color: appMouse.containsMouse ? "#a83245" : "#71303d"
                                                border.color: "#ff9aa8"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    color: "#ffffff"
                                                    font.pixelSize: 15
                                                    font.bold: true
                                                }

                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state fallback (if 0 windows open)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: switcherWindow.service.workspaces.length === 0
                        text: "No open applications"
                        color: "#6b7d99"
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1f2838"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Workspace"
                    color: "#8092ab"
                    font.pixelSize: 10
                }

                Loader {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    sourceComponent: nextWorkspaceButtonComponent
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Session"
                    color: "#8092ab"
                    font.pixelSize: 10
                }

                SystemActionButton {
                    service: switcherWindow.service
                    action: "logout"
                    glyph: "⇥"
                }

                SystemActionButton {
                    service: switcherWindow.service
                    action: "reboot"
                    glyph: "↻"
                }

                SystemActionButton {
                    service: switcherWindow.service
                    action: "shutdown"
                    glyph: "⏻"
                }
            }
        }
    }
}
