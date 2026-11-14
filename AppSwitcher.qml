import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    // Keep hot-corner surfaces (Overlay layer) interactive above the panel.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-app-switcher"
    // Keep Escape handling while the pointer is on the switcher. Outside the
    // bar, release keyboard focus so click-through text fields can receive keys.
    WlrLayershell.keyboardFocus: switcherWindow.service.appSwitcherHovered
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: outsideClickArea
        Region { item: container }
        Region { item: appContextMenu }
    }

    color: "#35080c16"

    property var now: service.clockNow
    property int processRssKiB: 0
    property string focusAtOpen: ""
    property bool focusedIconScrollPending: true
    property var contextMenuWindow: null
    property real contextMenuX: 0
    property real contextMenuY: 0

    Timer {
        id: switcherLeaveTimer
        interval: 1560
        repeat: false
        onTriggered: {
            if (containerHoverHandler.hovered) {
                switcherWindow.service.appSwitcherHovered = true
                return
            }

            switcherWindow.service.appSwitcherHovered = false
            if (!switcherWindow.visible || !switcherWindow.service.open) return
            if (switcherWindow.service.appSwitcherClosePending ||
                    (switcherWindow.service.autoHideAppSwitcherOnPointerLeave &&
                     switcherWindow.contextMenuWindow === null))
                switcherWindow.service.closeSwitcher(true)
        }
    }

    Connections {
        target: switcherWindow.service
        function onOpenChanged() {
            if (!switcherWindow.service.open) {
                switcherLeaveTimer.stop()
                return
            }

            switcherWindow.service.volumeReadTimer.restart()

            // The switcher can open while the pointer is already outside its
            // bar (for example from a hot edge). Start the same leave delay in
            // that case; entering the bar stops it in HoverHandler below.
            if (!containerHoverHandler.hovered)
                switcherLeaveTimer.restart()
        }
    }

    // A full-screen input target lets a click outside the bar dismiss it.
    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: switcherWindow.service.closeSwitcher(true)
    }

    property var inactivePinnedApps: {
        var result = []
        var pins = switcherWindow.service.pinnedApps || []
        var entries = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values)
            ? DesktopEntries.applications.values : []
        for (var i = 0; i < pins.length; i++) {
            var pinnedId = String(pins[i])
            var entry = null
            for (var j = 0; j < entries.length; j++) {
                var entryId = String(entries[j].id || "")
                if (entryId && !entryId.endsWith(".desktop")) entryId += ".desktop"
                if (entryId.toLowerCase() === pinnedId.toLowerCase()) {
                    entry = entries[j]
                    break
                }
            }
            if (entry && !switcherWindow.service.pinnedAppIsRunning(pinnedId)) result.push(entry)
        }
        return result
    }

    function appIconSource(iconName) {
        var value = String(iconName || "")
        if (!value) return Quickshell.iconPath("application-x-executable", true)
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
        if (value.charAt(0) === "/") return "file://" + value
        return Quickshell.iconPath(value, true) || Quickshell.iconPath("application-x-executable", true)
    }

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

    LazyLoader {
        active: switcherWindow.visible && switcherWindow.service.showRssUsage

        Item {
            Process {
                id: rssProcess
                command: ["ps", "-o", "rss=", "-p", String(Quickshell.processId)]
                running: false

                stdout: StdioCollector {
                    onTextChanged: {
                        var value = parseInt(text.trim())
                        if (!isNaN(value)) switcherWindow.processRssKiB = value
                    }
                }
            }

            Timer {
                interval: 2000
                repeat: true
                running: true
                onTriggered: if (!rssProcess.running) rssProcess.running = true
            }

            Component.onCompleted: rssProcess.running = true
        }
    }

    Component {
        id: nextWorkspaceButtonComponent

        Rectangle {
            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: nextWorkspaceMouse.containsMouse ? "#273650" : "#161d2a"
            border.color: nextWorkspaceMouse.containsMouse ? "#abc7ff" : "#2b364a"
            border.width: 1

            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                text: "+"
                color: nextWorkspaceMouse.containsMouse ? "#abc7ff" : "#8092ab"
                font.pixelSize: 14
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

    // The window mask lets pointer input pass through everywhere outside the
    // switcher bar. Close the bar if that input focuses another application.
    Connections {
        target: switcherWindow.service
        function onActiveWindowIdChanged() {
            var activeId = String(switcherWindow.service.activeWindowId || "")
            if (!switcherWindow.visible || !switcherWindow.service.open || !activeId) return
            if (!switcherWindow.focusAtOpen) {
                switcherWindow.focusAtOpen = activeId
            } else if (activeId !== switcherWindow.focusAtOpen) {
                switcherWindow.service.closeSwitcher()
            }
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
        x: switcherWindow.service.switcherPlacement === "bottom-center"
            ? Math.max(16, (switcherWindow.width - width) / 2) : 16
        y: switcherWindow.service.switcherPlacement === "bottom-center"
            ? Math.max(16, switcherWindow.height - height - 28) : 16

        width: Math.min(switcherWindow.width - 32, Math.max(500, mainCol.implicitWidth + 16)) * 0.9
        height: mainCol.implicitHeight + 14

        color: "#111722"
        radius: 14
        border.color: "#3b4a63"
        border.width: 1

        // Prevent background clicks through the panel
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        HoverHandler {
            id: containerHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    switcherLeaveTimer.stop()
                    switcherWindow.service.appSwitcherHovered = true
                } else {
                    switcherLeaveTimer.restart()
                }
            }
        }

        ColumnLayout {
            id: mainCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 7
                leftMargin: 9
                rightMargin: 9
            }
            spacing: 5

            // Header Row (Clock, Date, Compositor Chip, Preview Toggle, Close)
            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                // Two-line Clock and Date
                Item {
                    implicitWidth: clockDisplay.implicitWidth
                    implicitHeight: clockDisplay.implicitHeight

                    ColumnLayout {
                        id: clockDisplay
                        spacing: 1

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: Qt.formatDateTime(switcherWindow.now, "HH:mm")
                            color: "#f1f5f9"
                            font.pixelSize: 18}

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: Qt.formatDateTime(switcherWindow.now, "dddd, dd MMM yy")
                            color: "#94a3b8"
                            font.pixelSize: 10
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

                // Audio mixer
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: volumeMouse.containsMouse ? "#273650"
                        : (switcherWindow.service.volumeMuted ? "#32191f"
                            : (switcherWindow.service.volumePercent >= 100 ? "#343124" : "#161d2a"))
                    border.color: volumeMouse.containsMouse ? "#abc7ff"
                        : (switcherWindow.service.volumeMuted ? "#8f3544"
                            : (switcherWindow.service.volumePercent >= 100 ? "#d8c36f" : "#2b364a"))
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: switcherWindow.service.volumeMuted ? "󰝟" : "󰕾"
                        color: volumeMouse.containsMouse ? "#abc7ff"
                            : (switcherWindow.service.volumeMuted ? "#a94753"
                                : (switcherWindow.service.volumePercent >= 100 ? "#f0dd89" : "#8092ab"))
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: volumeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                switcherWindow.service.toggleVolumeMute()
                            else
                                switcherWindow.service.openVolumeControl()
                        }
                        onWheel: function(event) {
                            switcherWindow.service.adjustVolume(event.angleDelta.y > 0 ? 1 : -1)
                            event.accepted = true
                        }
                        ShellToolTip {
                            parent: volumeMouse
                            visible: volumeMouse.containsMouse
                            text: "Scroll: adjust volume · Left-click: mixer · Right-click: "
                                + (switcherWindow.service.volumeMuted ? "unmute" : "mute")
                        }
                    }
                }

                // Bluetooth power toggle
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: bluetoothMouse.containsMouse ? "#273650"
                        : (switcherWindow.service.bluetoothPowered ? "#1b3034" : "#161d2a")
                    border.color: bluetoothMouse.containsMouse ? "#abc7ff"
                        : (switcherWindow.service.bluetoothPowered ? "#5b9b95" : "#2b364a")
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: switcherWindow.service.bluetoothPowered ? "󰂯" : "󰂲"
                        color: bluetoothMouse.containsMouse ? "#abc7ff"
                            : (switcherWindow.service.bluetoothPowered ? "#8fd8cf" : "#8092ab")
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: bluetoothMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                switcherWindow.service.toggleBluetooth()
                            else
                                switcherWindow.service.manageBluetooth()
                        }
                        ShellToolTip {
                            parent: bluetoothMouse
                            visible: bluetoothMouse.containsMouse
                            text: "Left-click: manage devices · Right-click: power "
                                + (switcherWindow.service.bluetoothPowered ? "off" : "on")
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: dndMouse.containsMouse ? "#273650" : (switcherWindow.service.doNotDisturb ? "#3a2935" : "#161d2a")
                    border.color: switcherWindow.service.doNotDisturb ? "#ef8295" : (dndMouse.containsMouse ? "#abc7ff" : "#2b364a")
                    border.width: 1

                    Text {
                        id: dndLabel
                        anchors.centerIn: parent
                        text: switcherWindow.service.doNotDisturb ? "󰂛" : "󰂚"
                        color: switcherWindow.service.doNotDisturb ? "#ef8295" : (dndMouse.containsMouse ? "#abc7ff" : "#8092ab")
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                                switcherWindow.service.notificationService.openCenter()
                            else
                                switcherWindow.service.notificationService.toggleDnd()
                        }
                    }

                    ShellToolTip {
                        parent: dndMouse
                        visible: dndMouse.containsMouse
                        text: (switcherWindow.service.doNotDisturb ? "Do Not Disturb: on (left-click to disable)" : "Do Not Disturb: off (left-click to enable)")
                            + " · right-click for notifications"
                            + " · " + switcherWindow.service.unreadNotificationCount + " unread"
                    }
                }

                Rectangle {
                    visible: switcherWindow.service.unreadNotificationCount > 0
                    implicitWidth: unreadCountText.implicitWidth + 8
                    implicitHeight: 16
                    radius: 6
                    color: "#202a3a"
                    border.color: "#526584"
                    border.width: 1

                    Text {
                        id: unreadCountText
                        anchors.centerIn: parent
                        text: switcherWindow.service.unreadNotificationCount > 99
                            ? "99+" : String(switcherWindow.service.unreadNotificationCount)
                        color: "#c0c0d8"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 9
                    }

                    MouseArea {
                        id: unreadCountMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.notificationService.openCenter()
                    }

                    ShellToolTip {
                        parent: unreadCountMouse
                        visible: unreadCountMouse.containsMouse
                        text: "Open notification center"
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: brightnessMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: brightnessMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰛨"
                        color: brightnessMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: brightnessMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.showBrightnessOsd()
                        onWheel: function(event) {
                            switcherWindow.service.adjustBrightness(event.angleDelta.y > 0 ? 1 : -1)
                            event.accepted = true
                        }
                        ShellToolTip {
                            parent: brightnessMouse
                            visible: brightnessMouse.containsMouse
                            text: "Click: brightness slider · Scroll: adjust brightness"
                        }
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
                            implicitWidth: 32
                            implicitHeight: 20
                            radius: 6
                            color: widthButtonMouse.containsMouse ? "#273650" : "#161d2a"
                            border.color: widthButtonMouse.containsMouse ? "#abc7ff" : "#2b364a"
                            border.width: 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: modelData.glyphWidth
                                height: 11
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

                            ShellToolTip {
                                parent: widthButtonMouse
                                visible: widthButtonMouse.containsMouse
                                text: modelData.name + " column width"
                            }
                        }
                    }
                }

                // Keep fullscreen immediately after the Wide column button.
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: fullscreenFocusedMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: fullscreenFocusedMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "⛶"
                        color: fullscreenFocusedMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: fullscreenFocusedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.toggleFocusedFullscreen()
                    }

                    ShellToolTip {
                        parent: fullscreenFocusedMouse
                        visible: fullscreenFocusedMouse.containsMouse
                        text: "Toggle fullscreen"
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
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Keep the launcher fixed while the window and pinned app
                // strip scrolls independently.
                Rectangle {
                    id: appMenuBtn
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    implicitWidth: 34
                    implicitHeight: 34
                    width: 34
                    height: 34
                    radius: 8
                    color: appMenuMouse.containsMouse ? "#202a3a" : "#18202d"
                    border.color: appMenuMouse.containsMouse ? "#abc7ff" : "#2a364a"
                    border.width: 1

                    Image {
                        id: appMenuThemeIcon
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: Quickshell.iconPath("view-app-grid-symbolic", true)
                            || Quickshell.iconPath("applications-all", true)
                            || ""
                        visible: status === Image.Ready
                    }

                    Grid {
                        anchors.centerIn: parent
                        visible: !appMenuThemeIcon.visible
                        columns: 2
                        spacing: 3
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 2
                                color: appMenuMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            }
                        }
                    }

                    MouseArea {
                        id: appMenuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openAppMenu()
                    }
                }

                Flickable {
                id: appsFlickable
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: 38
                contentWidth: appsRow.childrenRect.width
                contentHeight: 38
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
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    // Show pinned apps that are not currently running.
                    Repeater {
                        model: switcherWindow.inactivePinnedApps

                        delegate: Rectangle {
                            required property var modelData
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: pinnedAppMouse.containsMouse ? "#202a3a" : "#18202d"
                            border.width: 0

                            Image {
                                id: pinnedAppIcon
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: switcherWindow.appIconSource(modelData.icon)
                                visible: status === Image.Ready && source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !pinnedAppIcon.visible
                                text: String(modelData.name || modelData.id || "?").substring(0, 1).toUpperCase()
                                color: "#abc7ff"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: pinnedAppMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switcherWindow.service.launchPinnedApp(modelData.id)
                                    switcherWindow.service.closeSwitcher(true)
                                }
                            }

                            ShellToolTip {
                                parent: pinnedAppMouse
                                visible: pinnedAppMouse.containsMouse
                                text: modelData.name || modelData.id
                            }
                        }
                    }

                    // Vertical Separator
                    Rectangle {
                        width: 1
                        height: 32
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
                            implicitWidth: wsContentRow.implicitWidth + 10
                            implicitHeight: 38

                            Row {
                                id: wsContentRow
                                anchors.centerIn: parent
                                spacing: 6

                                // Workspace Label Badge
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 26
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
                                            width: 32
                                            height: 32
                                            radius: 9

                                            color: modelData.focused ? "#22334f" : (appMouse.containsMouse ? "#202a3a" : "#18202d")
                                            border.width: 0

                                            Component.onCompleted: {
                                                if (modelData.focused) switcherWindow.scrollToFocusedIcon(appCard)
                                            }

                                            // App Icon Image
                                            Image {
                                                id: iconImg
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                source: modelData.icon || ""
                                                visible: status === Image.Ready && source !== ""
                                            }

                                            // Fallback initial letter badge if icon not loaded
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 24
                                                height: 24
                                                radius: 5
                                                color: "#26354c"
                                                visible: !iconImg.visible

                                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                                    text: (modelData.appId || modelData.title || "?").substring(0, 1).toUpperCase()
                                                    color: "#abc7ff"
                                                    font.pixelSize: 12}
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
                                                    topMargin: -4
                                                }
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton
                                                ShellToolTip {
                                                    id: appInfoTooltip
                                                    parent: appCard
                                                    visible: appMouse.containsMouse
                                                    text: (modelData.appId || "Application") + ": " + (modelData.title || "Untitled")
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
                                                        switcherWindow.service.closeSwitcher(true)
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
                                                width: 16
                                                height: 16
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.topMargin: -4
                                                anchors.rightMargin: -5
                                                radius: 5
                                                visible: appMouse.containsMouse
                                                color: appMouse.containsMouse ? "#a83245" : "#71303d"
                                                border.color: "#ff9aa8"
                                                border.width: 1

                                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                                    text: "×"
                                                    color: "#ffffff"
                                                    font.pixelSize: 13}

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
                        ShellToolTip {
                            parent: reloadHyprlandMouse
                            visible: reloadHyprlandMouse.containsMouse
                            text: "Reload Hyprland config"
                        }
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
                        ShellToolTip {
                            parent: restartQuickshellMouse
                            visible: restartQuickshellMouse.containsMouse
                            text: "Restart Quickshell"
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitWidth: switcherWindow.service.showRssUsage ? 80 : 0
                    implicitHeight: 22

                    Text {
                        anchors.centerIn: parent
                        visible: switcherWindow.service.showRssUsage && switcherWindow.processRssKiB > 0
                        text: "RSS " + (switcherWindow.processRssKiB / 1024).toFixed(0) + " MiB"
                        color: "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: idleSettingsMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "◷"
                        color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }
                    MouseArea {
                        id: idleSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openIdleConfig()
                        ShellToolTip {
                            parent: idleSettingsMouse
                            visible: idleSettingsMouse.containsMouse
                            text: "Settings"
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: wallpaperMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: wallpaperMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "▧"
                        color: wallpaperMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: wallpaperMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.toggleWallpaperSelector()
                        ShellToolTip {
                            parent: wallpaperMouse
                            visible: wallpaperMouse.containsMouse
                            text: "Wallpaper"
                        }
                    }
                }

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
        onClicked: function(mouse) {
            var point = container.mapFromItem(switcherWindow, mouse.x, mouse.y)
            if (!container.contains(point))
                switcherWindow.service.closeSwitcher(true)
            switcherWindow.contextMenuWindow = null
        }
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
        color: "#111722"
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
                    { label: "Launch another instance", action: "launch" },
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
        }
    }

}
