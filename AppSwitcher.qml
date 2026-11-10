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

    // Keep hot-corner surfaces (Overlay layer) interactive above the full-screen panel.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-app-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    color: "#35080c16"

    property var now: new Date()
    property bool focusedIconScrollPending: true
    property var contextMenuWindow: null
    property real contextMenuX: 0
    property real contextMenuY: 0
    function showAppContextMenu(win, point) {
        contextMenuWindow = win;
        contextMenuX = Math.max(8, Math.min(width - 264, point.x));
        contextMenuY = Math.max(8, Math.min(height - appContextMenu.height - 8, point.y));
    }

    function invokeAppContextAction(action, value) {
        var win = contextMenuWindow;
        contextMenuWindow = null;
        if (!win) return;

        if (action === "focus") switcherWindow.service.focusWindow(win);
        else if (action === "launch") switcherWindow.service.launchAppForWindow(win);
        else if (action === "close") switcherWindow.service.closeWindow(win);
        else if (action === "close-all") switcherWindow.service.closeAppWindows(win);
        else if (action === "toggle-pin") switcherWindow.service.toggleWindowAppPinned(win);
        else if (action === "fullscreen") switcherWindow.service.toggleWindowFullscreen(win);
    }

    function focusedAppWindow() {
        for (var i = 0; i < switcherWindow.service.workspaces.length; i++) {
            var windows = switcherWindow.service.workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                if (windows[j].focused) return windows[j];
            }
        }
        return null;
    }

    function setFocusedColumnWidth(percent) {
        var win = focusedAppWindow();
        if (win) switcherWindow.service.setWindowColumnWidth(win, percent);
    }

    function toggleFocusedFullscreen() {
        var win = focusedAppWindow();
        if (win) switcherWindow.service.toggleWindowFullscreen(win);
    }

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

            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
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
            switcherWindow.service.closeSwitcher(true);
        }
    }

    // Keyboard handling
    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            switcherWindow.service.closeSwitcher(true);
        }
    }

    // Floating Switcher Bar anchored near top-left
    GlowBorder { targetItem: container; cornerRadius: container.radius }

    Rectangle {
        id: container
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 16
            leftMargin: 16
        }

        width: Math.min(switcherWindow.width - 32, Math.max(560, mainCol.implicitWidth + 28)) * 0.9
        height: mainCol.implicitHeight + 24

        color: "#111622"
        radius: 14
        border.color: "#3b4a63"
        border.width: 1

        // Prevent background clicks through the panel
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {}
            onEntered: switcherWindow.service.appSwitcherHovered = true
            onExited: {
                Qt.callLater(function() {
                    switcherWindow.service.appSwitcherHovered = false
                    if (switcherWindow.service.appSwitcherClosePending)
                        switcherWindow.service.closeSwitcher(true)
                })
            }
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

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: Qt.formatDateTime(switcherWindow.now, "HH:mm")
                            color: "#f1f5f9"
                            font.pixelSize: 20}

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: Qt.formatDateTime(switcherWindow.now, "dddd, dd MMM yy")
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

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: compText
                        anchors.centerIn: parent
                        text: switcherWindow.service.activeCompositor.toUpperCase()
                        color: "#abc7ff"
                        font.pixelSize: 9}
                }

                // Configure the idle timers and clock card appearance
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: idleSettingsMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "◷"
                        color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 24
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

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "▧"
                        color: wallpaperMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: wallpaperMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.toggleWallpaperSelector()
                    }
                }

                RowLayout {
                    spacing: 4

                    Repeater {
                        model: [
                            { value: switcherWindow.service.columnWidthSmall, name: "Narrow", glyphWidth: 5 },
                            { value: switcherWindow.service.columnWidthMedium, name: "Normal", glyphWidth: 10 },
                            { value: switcherWindow.service.columnWidthLarge, name: "Wide", glyphWidth: 15 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 40
                            implicitHeight: 24
                            radius: 6
                            color: widthButtonMouse.containsMouse ? "#273650" : "#161d2a"
                            border.color: widthButtonMouse.containsMouse ? "#abc7ff" : "#2b364a"
                            border.width: 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: modelData.glyphWidth
                                height: 13
                                radius: 1
                                color: "transparent"
                                border.width: 1
                                border.color: widthButtonMouse.containsMouse ? "#abc7ff" : "#a5b4c8"
                            }

                            MouseArea {
                                id: widthButtonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: switcherWindow.setFocusedColumnWidth(modelData.value)
                            }

                            ToolTip.visible: widthButtonMouse.containsMouse
                            ToolTip.text: modelData.name + " column width"
                            ToolTip.delay: 450
                        }
                    }
                }

                // Keep fullscreen immediately after the Wide column button.
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: fullscreenFocusedMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: fullscreenFocusedMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "⛶"
                        color: fullscreenFocusedMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 21
                    }

                    MouseArea {
                        id: fullscreenFocusedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.toggleFocusedFullscreen()
                    }

                    ToolTip.visible: fullscreenFocusedMouse.containsMouse
                    ToolTip.text: "Toggle fullscreen"
                    ToolTip.delay: 450
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
                        radius: 6
                        color: appMenuMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: appMenuMouse.containsMouse ? "#abc7ff" : "#2b364a"
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
                                            color: appMenuMouse.containsMouse ? "#abc7ff" : "#8092ab"
                                        }
                                    }
                                }
                            }

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.alignment: Qt.AlignHCenter
                                text: "Apps"
                                color: appMenuMouse.containsMouse ? "#abc7ff" : "#8092ab"
                                font.pixelSize: 9}
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

                                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                        text: modelData.name || modelData.id
                                        color: "#abc7ff"
                                        font.pixelSize: 10}
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

                                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                                    text: (modelData.appId || modelData.title || "?").substring(0, 1).toUpperCase()
                                                    color: "#abc7ff"
                                                    font.pixelSize: 14}
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
                                                acceptedButtons: Qt.LeftButton
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

                                                    contentItem: Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: appInfoTooltip.text
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

                                            TapHandler {
                                                acceptedButtons: Qt.RightButton
                                                onTapped: function(eventPoint, button) {
                                                    var menuPoint = appCard.mapToItem(
                                                        switcherWindow.contentItem,
                                                        eventPoint.position.x,
                                                        eventPoint.position.y
                                                    )
                                                    switcherWindow.showAppContextMenu(modelData, menuPoint)
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

                                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                                    text: "×"
                                                    color: "#ffffff"
                                                    font.pixelSize: 15}

                                            }

                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state fallback (if 0 windows open)
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.verticalCenter: parent.verticalCenter
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

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Workspace"
                    color: "#8092ab"
                    font.pixelSize: 10
                }

                Loader {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    sourceComponent: nextWorkspaceButtonComponent
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: reloadHyprlandMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: reloadHyprlandMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "↻"
                        color: reloadHyprlandMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: reloadHyprlandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.reloadHyprlandConfig()
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: "Reload Hyprland config"
                    }
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: restartQuickshellMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: restartQuickshellMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "⟳"
                        color: restartQuickshellMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: restartQuickshellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.restartQuickshell()
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: "Restart Quickshell"
                    }
                }

                Item { Layout.fillWidth: true }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Session"
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

    MouseArea {
        anchors.fill: parent
        z: 90
        visible: switcherWindow.contextMenuWindow !== null
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: switcherWindow.contextMenuWindow = null
    }

    GlowBorder {
        targetItem: appContextMenu
        cornerRadius: appContextMenu.radius
        spread: 3
    }

    Rectangle {
        id: appContextMenu
        x: switcherWindow.contextMenuX
        y: switcherWindow.contextMenuY
        z: 100
        width: 256
        height: contextMenuContent.implicitHeight + 16
        visible: switcherWindow.contextMenuWindow !== null
        radius: 10
        color: "#f2111722"
        border.color: "#3b4a63"
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: contextMenuContent
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.preferredHeight: 24
                text: switcherWindow.contextMenuWindow
                    ? (switcherWindow.contextMenuWindow.appId || switcherWindow.contextMenuWindow.title || "Application")
                    : "Application"
                color: "#abc7ff"
                font.pixelSize: 11
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: [
                    {
                        label: switcherWindow.contextMenuWindow && switcherWindow.service.isWindowAppPinned(switcherWindow.contextMenuWindow)
                            ? "Unpin from launcher" : "Pin to launcher",
                        action: "toggle-pin"
                    },
                    { label: "Focus window", action: "focus" },
                    { label: "Launch another instance", action: "launch" },
                    { label: "Close window", action: "close" },
                    { label: "Close all windows from this app", action: "close-all" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 6
                    color: contextActionMouse.containsMouse ? "#273650" : "transparent"

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: modelData.label
                        color: contextActionMouse.containsMouse ? "#abc7ff" : "#dce5f2"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: contextActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.invokeAppContextAction(modelData.action)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 6
                color: fullscreenMenuMouse.containsMouse ? "#273650" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "⛶"; color: "#dce5f2"; font.pixelSize: 14 }
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Toggle fullscreen"; color: fullscreenMenuMouse.containsMouse ? "#abc7ff" : "#dce5f2"; font.pixelSize: 11 }
                }

                MouseArea {
                    id: fullscreenMenuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switcherWindow.invokeAppContextAction("fullscreen")
                }
            }
        }
    }

}
