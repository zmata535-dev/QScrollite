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
    WlrLayershell.layer: switcherWindow.pendingSystemAction.length > 0
        ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-app-switcher"
    // Only take keyboard focus while the pointer is over the switcher, so
    // applications remain able to receive keyboard input outside the bar.
    WlrLayershell.keyboardFocus: (switcherWindow.pendingSystemAction.length > 0) ||
        (switcherWindow.service.open && containerHoverHandler.hovered)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        Region { item: systemActionDialog }
        Region { item: container }
        Region { item: appContextMenu }
    }

    color: "transparent"

    property var now: service.clockNow
    property int processRssKiB: 0
    property real appsScrollX: 0
    property string focusAtOpen: ""
    property string pendingIconFocusWindowId: ""
    property string pendingIconLaunchAppId: ""
    property int pendingIconLaunchAttempts: 0
    property bool focusedIconScrollPending: true
    readonly property bool hasFocusedApp: !!focusedTiledAppWindow()
    property var contextMenuWindow: null
    property real contextMenuX: 0
    property real contextMenuY: 0
    property bool controlsPointerFollowPending: false
    property string pendingSystemAction: ""
    property string raisedCardBeforeSystemAction: ""

    function requestSystemAction(action) {
        if (!pendingSystemAction.length) {
            raisedCardBeforeSystemAction = String(service.raisedCardModule || "")
            service.raiseCardModule("session-confirmation")
        }
        pendingSystemAction = action
    }

    function finishSystemActionConfirmation() {
        pendingSystemAction = ""
        service.raiseCardModule(raisedCardBeforeSystemAction)
        raisedCardBeforeSystemAction = ""
    }

    function cancelSystemAction() {
        finishSystemActionConfirmation()
    }

    function confirmSystemAction() {
        var action = pendingSystemAction
        finishSystemActionConfirmation()
        if (action) switcherWindow.service.runSystemAction(action)
    }

    function systemActionLabel(action) {
        if (action === "shutdown") return "Shut down"
        if (action === "reboot") return "Restart"
        if (action === "logout") return "Log out"
        return "Continue"
    }

    onPendingSystemActionChanged: {
        if (pendingSystemAction.length > 0) {
            switcherLeaveTimer.stop()
            service.appSwitcherClosePending = false
        } else if (service.open && !containerHoverHandler.hovered) {
            switcherLeaveTimer.restart()
        }
    }

    IdleMonitor {
        enabled: switcherWindow.pendingSystemAction.length > 0 &&
            !switcherWindow.service.hasPlayingMedia()
        timeout: Math.max(1, Number(switcherWindow.service.idleLockTimeout) || 1)
        respectInhibitors: false
        onIsIdleChanged: {
            if (isIdle) switcherWindow.cancelSystemAction()
        }
    }

    Timer {
        id: switcherControlsPointerTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (!switcherWindow.visible || !switcherControlsMouse.visible) return
            var point = switcherControlsMouse.mapToGlobal(
                switcherControlsMouse.width / 2,
                switcherControlsMouse.height / 2
            )
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.dispatch(hl.dsp.cursor.move({ x = " + Math.round(point.x)
                    + ", y = " + Math.round(point.y) + " }))"
            ])
            switcherHoverResetTimer.restart()
        }
    }

    Timer {
        id: switcherHoverResetTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (!switcherWindow.visible || !switcherWindow.service.open) return
            switcherWindow.controlsPointerFollowPending = false
            // The pointer was just moved to the toggle's new center. Trust
            // that target instead of the hover state sampled during relayout.
            switcherWindow.service.appSwitcherHovered = true
            switcherWindow.service.appSwitcherClosePending = false
            switcherLeaveTimer.stop()
        }
    }

    function toggleSwitcherSystemControls() {
        switcherLeaveTimer.stop()
        switcherHoverResetTimer.stop()
        controlsPointerFollowPending = true
        service.appSwitcherHovered = false
        service.appSwitcherClosePending = false
        service.showSwitcherSystemControls = !service.showSwitcherSystemControls
        switcherControlsPointerTimer.restart()
    }

    function pinnedAppMatchesWindow(appId, win) {
        var target = switcherWindow.service.normalizedDesktopEntryId(appId).toLowerCase()
        if (!target || !win) return false
        var entry = switcherWindow.service.appEntryForWindow(win)
        if (entry && switcherWindow.service.normalizedDesktopEntryId(entry.id).toLowerCase() === target)
            return true
        return switcherWindow.service.normalizedDesktopEntryId(win.appId).toLowerCase() === target
    }

    function activeWindowMatchesPinnedApp(appId, activeId) {
        for (var i = 0; i < switcherWindow.service.workspaces.length; i++) {
            var windows = switcherWindow.service.workspaces[i].windows || []
            for (var j = 0; j < windows.length; j++) {
                if (String(windows[j].id) === activeId && pinnedAppMatchesWindow(appId, windows[j]))
                    return true
            }
        }
        return false
    }

    function findWindowForPinnedApp(appId) {
        var workspaces = switcherWindow.service.workspaces || []
        for (var i = 0; i < workspaces.length; i++) {
            var windows = workspaces[i].windows || []
            for (var j = 0; j < windows.length; j++) {
                if (pinnedAppMatchesWindow(appId, windows[j])) return windows[j]
            }
        }
        return null
    }

    function beginPinnedAppLaunch(appId) {
        pendingIconFocusWindowId = ""
        pendingIconLaunchAppId = switcherWindow.service.normalizedDesktopEntryId(appId)
        pendingIconLaunchAttempts = 0
        switcherLeaveTimer.stop()
        switcherWindow.service.appSwitcherClosePending = false
        switcherWindow.service.launchPinnedApp(appId)
        pinnedAppLaunchTimer.start()
    }

    function beginAppWindowLaunch(win) {
        if (!win) return
        var entry = switcherWindow.service.appEntryForWindow(win)
        if (!entry || !entry.id) {
            switcherWindow.service.launchAppForWindow(win)
            return
        }
        pendingIconFocusWindowId = ""
        pendingIconLaunchAppId = switcherWindow.service.normalizedDesktopEntryId(entry.id)
        pendingIconLaunchAttempts = 0
        switcherLeaveTimer.stop()
        switcherWindow.service.appSwitcherClosePending = false
        switcherWindow.service.launchAppForWindow(win)
        pinnedAppLaunchTimer.start()
    }

    onPendingIconLaunchAppIdChanged: {
        if (pendingIconLaunchAppId.length > 0) {
            switcherLeaveTimer.stop()
            service.appSwitcherClosePending = false
        } else if (service.open && !containerHoverHandler.hovered) {
            switcherLeaveTimer.restart()
        }
    }

    function focusLaunchedPinnedApp() {
        if (!pendingIconLaunchAppId) {
            pinnedAppLaunchTimer.stop()
            return
        }
        pendingIconLaunchAttempts++
        switcherWindow.service.refresh()
        var win = findWindowForPinnedApp(pendingIconLaunchAppId)
        if (win) {
            pendingIconFocusWindowId = String(win.id || "")
            pendingIconLaunchAppId = ""
            pinnedAppLaunchTimer.stop()
            switcherWindow.service.focusWindow(win, true)
            return
        }
        if (pendingIconLaunchAttempts >= 40) {
            pendingIconLaunchAppId = ""
            pinnedAppLaunchTimer.stop()
        }
    }

    Timer {
        id: pinnedAppLaunchTimer
        interval: 250
        repeat: true
        onTriggered: switcherWindow.focusLaunchedPinnedApp()
    }

    function resolveFocusChange() {
        var activeId = String(switcherWindow.service.activeWindowId || "")
        if (!switcherWindow.visible || !switcherWindow.service.open || !activeId) return
        if (!switcherWindow.focusAtOpen) {
            switcherWindow.focusAtOpen = activeId
            return
        }
        if (activeId === switcherWindow.focusAtOpen) return

        var activatedByIcon = activeId === switcherWindow.pendingIconFocusWindowId
            || (switcherWindow.pendingIconLaunchAppId.length > 0
                && activeWindowMatchesPinnedApp(switcherWindow.pendingIconLaunchAppId, activeId))
        if (activatedByIcon) {
            switcherWindow.focusAtOpen = activeId
            switcherWindow.pendingIconFocusWindowId = ""
            switcherWindow.pendingIconLaunchAppId = ""
        } else {
            switcherWindow.service.closeSwitcher()
        }
    }

    Timer {
        id: focusChangeTimer
        interval: 120
        repeat: false
        onTriggered: switcherWindow.resolveFocusChange()
    }

    Timer {
        id: switcherLeaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (switcherWindow.pendingSystemAction.length > 0 ||
                    switcherWindow.pendingIconLaunchAppId.length > 0) {
                switcherWindow.service.appSwitcherClosePending = false
                return
            }
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
                switcherWindow.contextMenuWindow = null
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

    function focusedTiledAppWindow() {
        for (var i = 0; i < switcherWindow.service.workspaces.length; i++) {
            var windows = switcherWindow.service.workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                if (windows[j].focused && !windows[j].floating) return windows[j];
            }
        }
        return null;
    }

    function setFocusedColumnWidth(percent) {
        var win = focusedTiledAppWindow();
        if (win) switcherWindow.service.setWindowColumnWidth(win, percent);
    }

    function reorderWindowByDrop(sourceWin, targetWin, insertAfter) {
        if (!sourceWin || !targetWin || sourceWin.floating || targetWin.floating ||
                String(sourceWin.id) === String(targetWin.id) ||
                String(sourceWin.workspaceId) !== String(targetWin.workspaceId)) return;

        var workspace = null;
        var workspaces = switcherWindow.service.workspaces || [];
        for (var i = 0; i < workspaces.length; i++) {
            if (String(workspaces[i].id) === String(sourceWin.workspaceId)) {
                workspace = workspaces[i];
                break;
            }
        }
        if (!workspace) return;

        var windows = workspace.windows || [];
        var columns = [];
        var sourceColumn = -1;
        var targetColumn = -1;
        for (var j = 0; j < windows.length; j++) {
            var x = Number(windows[j].x || 0);
            var columnIndex = columns.length - 1;
            if (columnIndex < 0 || Math.abs(columns[columnIndex].x - x) > 0.5) {
                columns.push({ x: x, ids: [] });
                columnIndex++;
            }
            columns[columnIndex].ids.push(String(windows[j].id));
            if (String(windows[j].id) === String(sourceWin.id)) sourceColumn = columnIndex;
            if (String(windows[j].id) === String(targetWin.id)) targetColumn = columnIndex;
        }
        if (sourceColumn < 0 || targetColumn < 0 || sourceColumn === targetColumn) return;

        var destination = targetColumn;
        if (sourceColumn < targetColumn) {
            if (!insertAfter) destination--;
        } else if (sourceColumn > targetColumn) {
            if (insertAfter) destination++;
        } else {
            return;
        }
        switcherWindow.service.moveWindowByColumns(sourceWin, destination - sourceColumn);
    }

    function reorderPinnedByDrop(sourceId, targetId, insertAfter) {
        if (!sourceId || !targetId || String(sourceId) === String(targetId)) return;
        switcherWindow.service.reorderPinnedApps(sourceId, targetId, insertAfter);
    }

    function toggleFocusedFullscreen() {
        var win = focusedTiledAppWindow();
        if (win) switcherWindow.service.toggleWindowFullscreen(win);
    }

    function scrollToFocusedIcon(iconItem) {
        if (!focusedIconScrollPending) return
        Qt.callLater(function() {
            if (!switcherWindow.visible || !iconItem) return
            var strip = switcherWindow.service.showSwitcherSystemControls
                ? fullAppsStripLoader.item : compactAppsStripLoader.item
            if (!strip || !strip.flickableRef) return
            var flickable = strip.flickableRef
            var iconPosition = iconItem.mapToItem(flickable.contentItem, 0, 0)
            var nextX = flickable.contentX
            if (iconPosition.x < flickable.contentX)
                nextX = iconPosition.x
            else if (iconPosition.x + iconItem.width > flickable.contentX + flickable.width)
                nextX = iconPosition.x + iconItem.width - flickable.width

            flickable.contentX = Math.max(0, Math.min(
                flickable.contentWidth - flickable.width,
                nextX
            ))
            switcherWindow.focusedIconScrollPending = false
        })
    }

    LazyLoader {
        active: switcherWindow.visible && switcherWindow.service.showRssUsage
            && switcherWindow.service.showSwitcherSystemControls

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
                font.pixelSize: 20
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
            focusChangeTimer.restart()
        }
    }

    // Keyboard handling
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (!switcherWindow.pendingSystemAction)
                    switcherWindow.service.closeSwitcher(true)
                event.accepted = true
            } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ControlModifier)) {
                switcherWindow.service.openGDictCalc("")
                event.accepted = true
            } else {
                if (switcherWindow.contextMenuWindow !== null || !event.text || !event.text.trim()) return
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
                switcherWindow.service.openAppMenu(event.text)
                event.accepted = true
            }
        }
    }

    // Floating Switcher Bar anchored near top-left
    GlowBorder { targetItem: container; cornerRadius: container.radius }

    Component {
        id: appsWorkspaceStripComponent

            // Main Horizontal Apps & Workspaces Strip
            Item {
                id: mainAppsStrip
                property var stripContainerRef: appsStripContainer
                property var flickableRef: appsFlickable
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: switcherWindow.service.showSwitcherSystemControls ? -1 : 360
                implicitHeight: switcherWindow.service.showSwitcherSystemControls ? 54 : 46

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#070b12"
                    border.width: 0
                }

            RowLayout {
                anchors.fill: parent
                anchors.margins: switcherWindow.service.showSwitcherSystemControls ? 4 : 2
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

                Rectangle {
                    id: appsStripContainer
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: switcherWindow.service.showSwitcherSystemControls ? 46 : 42
                    radius: 8
                    color: "transparent"
                    border.width: 0

                Flickable {
                id: appsFlickable
                anchors.fill: parent
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                contentWidth: appsRow.childrenRect.width + 10
                contentHeight: appsStripContainer.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Component.onCompleted: contentX = switcherWindow.appsScrollX
                onContentXChanged: switcherWindow.appsScrollX = contentX
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
                    anchors.left: parent.left
                    anchors.leftMargin: 5
                    anchors.verticalCenter: parent.verticalCenter

                    // Show pinned apps that are not currently running.
                    Repeater {
                        model: switcherWindow.inactivePinnedApps

                        delegate: Rectangle {
                            id: pinnedAppCard
                            required property var modelData
                            readonly property string pinnedAppId: String(modelData.id || "")
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: "#070b12"
                            border.width: 0
                            opacity: pinnedDragHandler.active ? 0.55 : 1

                            Drag.active: pinnedDragHandler.active
                            Drag.source: pinnedAppCard
                            Drag.keys: ["qscrollite-pinned-app"]
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 4
                                height: parent.height + 4
                                radius: 10
                                color: "#202a3a"
                                visible: pinnedAppHover.hovered
                            }

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

                            HoverHandler {
                                id: pinnedAppHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onTapped: function(eventPoint) {
                                    if (eventPoint.position.x >= pinnedAppCard.width - 5 &&
                                            eventPoint.position.y >= 0 && eventPoint.position.y <= 8)
                                        return
                                    switcherWindow.beginPinnedAppLaunch(modelData.id)
                                }
                            }

                            Rectangle {
                                id: unpinBadge
                                width: 13
                                height: 13
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -4
                                anchors.rightMargin: -5
                                z: 4
                                radius: 5
                                visible: pinnedAppHover.hovered || unpinMouse.containsMouse
                                color: "#f0a04b"
                                border.color: "#111722"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    color: "#17202c"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: unpinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: switcherWindow.service.unpinApp(modelData.id)
                                }
                            }

                            DragHandler {
                                id: pinnedDragHandler
                                target: null
                                acceptedButtons: Qt.LeftButton
                                enabled: !unpinMouse.containsMouse
                            }

                            DropArea {
                                anchors.fill: parent
                                z: 2
                                keys: ["qscrollite-pinned-app"]
                                onDropped: function(drop) {
                                    var source = drop.source
                                    if (!source || !source.pinnedAppId) return
                                    switcherWindow.reorderPinnedByDrop(
                                        source.pinnedAppId,
                                        pinnedAppCard.pinnedAppId,
                                        drop.x >= width / 2
                                    )
                                    drop.acceptProposedAction()
                                }
                            }

                            ShellToolTip {
                                parent: pinnedAppCard
                                visible: pinnedAppHover.hovered
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
                            color: "#0d121c"
                            border.width: 0
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
                                            readonly property var appWindowData: modelData
                                            width: 32
                                            height: 32
                                            radius: 9
                                            opacity: appDragHandler.active ? 0.55 : 1

                                            Drag.active: appDragHandler.active
                                            Drag.source: appCard
                                            Drag.keys: ["qscrollite-app-window"]
                                            Drag.hotSpot.x: width / 2
                                            Drag.hotSpot.y: height / 2

                                            color: modelData.focused ? "#792c5568" : "#070b12"
                                            border.color: container.border.color
                                            border.width: modelData.focused ? 1 : 0

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width + 4
                                                height: parent.height + 4
                                                radius: 10
                                                color: "#202a3a"
                                                visible: appHover.hovered && !modelData.focused
                                            }

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

                                            HoverHandler {
                                                id: appHover
                                                cursorShape: Qt.PointingHandCursor
                                                onHoveredChanged: {
                                                    if (hovered) {
                                                    switcherWindow.service.hoveredWindow = modelData;
                                                    } else if (switcherWindow.service.hoveredWindow === modelData) {
                                                        switcherWindow.service.hoveredWindow = null;
                                                    }
                                                }
                                            }

                                            ShellToolTip {
                                                id: appInfoTooltip
                                                parent: appCard
                                                visible: appHover.hovered
                                                text: (modelData.appId || "Application") + ": " + (modelData.title || "Untitled")
                                            }

                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton
                                                onTapped: {
                                                    switcherWindow.pendingIconFocusWindowId = String(modelData.id || "")
                                                    switcherWindow.pendingIconLaunchAppId = ""
                                                    switcherWindow.service.focusWindow(modelData, true)
                                                }
                                                onDoubleTapped: function(eventPoint, button) {
                                                    switcherWindow.beginAppWindowLaunch(modelData)
                                                }
                                            }

                                            TapHandler {
                                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                                onTapped: function(eventPoint, button) {
                                                    var menuPoint = appCard.mapToItem(
                                                        switcherWindow.contentItem,
                                                        eventPoint.position.x,
                                                        eventPoint.position.y
                                                    )
                                                    switcherWindow.showAppContextMenu(modelData, menuPoint)
                                                }
                                            }

                                            DragHandler {
                                                id: appDragHandler
                                                target: null
                                                acceptedButtons: Qt.LeftButton
                                            }

                                            DropArea {
                                                anchors.fill: parent
                                                z: 2
                                                keys: ["qscrollite-app-window"]
                                                onDropped: function(drop) {
                                                    var source = drop.source
                                                    if (!source || !source.appWindowData) return
                                                    switcherWindow.reorderWindowByDrop(
                                                        source.appWindowData,
                                                        modelData,
                                                        drop.x >= width / 2
                                                    )
                                                    drop.acceptProposedAction()
                                                }
                                            }

                                            Rectangle {
                                                id: closeAppButton
                                                z: 3
                                                width: 16
                                                height: 16
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.topMargin: -4
                                                anchors.rightMargin: -5
                                                radius: 5
                                                visible: appHover.hovered || closeAppMouse.containsMouse
                                                color: appHover.hovered ? "#a83245" : "#71303d"
                                                border.color: "#ff9aa8"
                                                border.width: 1

                                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                                    text: "×"
                                                    color: "#ffffff"
                                                    font.pixelSize: 13}

                                                MouseArea {
                                                    id: closeAppMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        switcherWindow.service.closeWindow(modelData)
                                                    }
                                                }

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
                    z: 3
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: parent.height
                    visible: appsFlickable.contentWidth > appsFlickable.width + 1
                        && !appsFlickable.atXBeginning
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#cc070b12" }
                        GradientStop { position: 1.0; color: "#00070b12" }
                    }
                }

                Rectangle {
                    z: 3
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: parent.height
                    visible: appsFlickable.contentWidth > appsFlickable.width + 1
                        && !appsFlickable.atXEnd
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00070b12" }
                        GradientStop { position: 1.0; color: "#cc070b12" }
                    }
                }
                }
            }
            }

    }

    Component {
        id: compositorIndicatorComponent

Rectangle {
                    radius: 11
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#354765" }
                        GradientStop { position: 0.48; color: "#263650" }
                        GradientStop { position: 1.0; color: "#19263b" }
                    }
                    border.width: 0
                    implicitWidth: 22
                    implicitHeight: 22

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        height: 1
                        radius: 1
                        color: "#b5e4f2"
                        opacity: 0.3
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: compText
                        anchors.centerIn: parent
                        text: ""
                        color: "#e3f8ff"
                        font.pixelSize: 15}
                }
    }

    Component {
        id: brightnessIndicatorComponent

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
                    }
                }
    }

    Component {
        id: bluetoothIndicatorComponent

Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: bluetoothMouse.containsMouse ? "#273650"
                        : (switcherWindow.service.bluetoothConnected ? "#1c2a42" : "#161d2a")
                    border.color: bluetoothMouse.containsMouse ? "#abc7ff"
                        : (switcherWindow.service.bluetoothConnected ? "#5476a4" : "#2b364a")
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: switcherWindow.service.bluetoothPowered ? "󰂯" : "󰂲"
                        color: bluetoothMouse.containsMouse ? "#abc7ff"
                            : (switcherWindow.service.bluetoothConnected ? "#abc7ff" : "#8092ab")
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
                    }
                }
    }

    Component {
        id: networkIndicatorComponent

Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: networkMouse.containsMouse ? "#273650"
                        : (switcherWindow.service.networkConnected ? "#1c2a42" : "#161d2a")
                    border.color: networkMouse.containsMouse ? "#abc7ff"
                        : (switcherWindow.service.networkConnected ? "#5476a4" : "#2b364a")
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: switcherWindow.service.networkConnected ? "󰖩" : "󰖪"
                        color: networkMouse.containsMouse ? "#abc7ff"
                            : (switcherWindow.service.networkConnected ? "#abc7ff" : "#8092ab")
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: networkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
    }

    Component {
        id: bottomControlsComponent

RowLayout {
                visible: switcherWindow.service.showSwitcherSystemControls
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
                        font.pixelSize: 20
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
                        font.pixelSize: 20
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
                    color: qSysMonMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: qSysMonMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰻠"
                        color: qSysMonMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: qSysMonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openQSysMon()
                        ShellToolTip {
                            parent: qSysMonMouse
                            visible: qSysMonMouse.containsMouse
                            text: "QSysMon · System Monitor"
                        }
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
                        anchors.fill: parent
                        text: "󰒓"
                        color: idleSettingsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                        text: "󰋩"
                        color: wallpaperMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
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
                    onTriggered: switcherWindow.requestSystemAction(action)
                    action: "logout"
                    glyph: "⇥"
                }

                SystemActionButton {
                    onTriggered: switcherWindow.requestSystemAction(action)
                    action: "reboot"
                    glyph: "↻"
                }

                SystemActionButton {
                    onTriggered: switcherWindow.requestSystemAction(action)
                    action: "shutdown"
                    glyph: "⏻"
                }
            }
    }

    Component {
        id: switcherDateComponent

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: Qt.formatDateTime(switcherWindow.now, "dddd, dd MMM yy")
                            color: "#94a3b8"
                            font.pixelSize: 10
                        }
    }

    Component {
        id: optionalControlsDividerComponent
        Rectangle {
            implicitHeight: 1
            color: "#1f2838"
        }
    }

    Component {
        id: optionalControlsSpacerComponent
        Item {}
    }

    Component {
        id: compactSettingsButtonComponent
        Rectangle {
            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: hiddenSettingsMouse.containsMouse ? "#273650" : "#161d2a"
            border.color: hiddenSettingsMouse.containsMouse ? "#abc7ff" : "#2b364a"
            border.width: 1

            Text {
                anchors.fill: parent
                text: "󰒓"
                color: hiddenSettingsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: hiddenSettingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switcherWindow.service.openIdleConfig()
            }
        }
    }

    Component {
        id: compactShutdownButtonComponent
        SystemActionButton {
            onTriggered: switcherWindow.requestSystemAction(action)
            action: "shutdown"
            glyph: "⏻"
        }
    }

    Rectangle {
        id: systemActionDialog
        anchors.fill: parent
        z: 200
        visible: switcherWindow.pendingSystemAction.length > 0
        color: "#99080c16"

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(360, parent.width - 40)
            height: dialogColumn.implicitHeight + 32
            radius: 12
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: switcherWindow.systemActionLabel(switcherWindow.pendingSystemAction) + "?"
                    color: "#f0f2fa"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: "Are you sure you want to " + switcherWindow.pendingSystemAction + "?"
                    color: "#aab5c7"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    ShellButton {
                        text: "Cancel"
                        onClicked: switcherWindow.cancelSystemAction()
                    }

                    ShellButton {
                        text: switcherWindow.systemActionLabel(switcherWindow.pendingSystemAction)
                        accent: true
                        onClicked: switcherWindow.confirmSystemAction()
                    }
                }
            }
        }
    }

    Rectangle {
        id: container
        x: switcherWindow.service.switcherPlacement === "bottom-center"
            ? (switcherWindow.width - width) / 2 : 0
        y: switcherWindow.service.switcherPlacement === "bottom-center"
            ? switcherWindow.height - height : 0

        width: Math.min(switcherWindow.width - 32, Math.max(
            550,
            Math.min(switcherWindow.width - 32, Math.max(500, mainCol.implicitWidth + 16)) * 0.9 + 17
        ))
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
                if (switcherWindow.controlsPointerFollowPending) return
                if (switcherWindow.pendingSystemAction.length > 0) {
                    switcherLeaveTimer.stop()
                    switcherWindow.service.appSwitcherClosePending = false
                    return
                }
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
                id: headerRow
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

                        Loader {
                            active: switcherWindow.service.showSwitcherSystemControls
                            visible: switcherWindow.service.showSwitcherSystemControls
                            sourceComponent: switcherDateComponent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openCalendar()
                    }
                }

                Loader {
                    active: !switcherWindow.service.showSwitcherSystemControls
                    visible: !switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    sourceComponent: nextWorkspaceButtonComponent
                }

                Loader {
                    active: !switcherWindow.service.showSwitcherSystemControls
                    visible: !switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    sourceComponent: compactSettingsButtonComponent
                }

                Loader {
                    active: !switcherWindow.service.showSwitcherSystemControls
                    visible: !switcherWindow.service.showSwitcherSystemControls
                    sourceComponent: compactShutdownButtonComponent
                }

                Loader {
                    id: compactAppsStripLoader
                    active: !switcherWindow.service.showSwitcherSystemControls
                    visible: !switcherWindow.service.showSwitcherSystemControls
                    Layout.fillWidth: true
                    Layout.minimumWidth: 80
                    Layout.preferredWidth: 360
                    Layout.preferredHeight: 46
                    sourceComponent: appsWorkspaceStripComponent
                }

                Loader {
                    active: switcherWindow.service.showSwitcherSystemControls
                    visible: switcherWindow.service.showSwitcherSystemControls
                    Layout.fillWidth: true
                    sourceComponent: optionalControlsSpacerComponent
                }

                // Compositor Chip
                Loader {
                    active: switcherWindow.service.showSwitcherSystemControls
                    visible: switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    sourceComponent: compositorIndicatorComponent
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: gDictCalcHeaderMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: gDictCalcHeaderMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        color: gDictCalcHeaderMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: gDictCalcHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openGDictCalc("")
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: clipboardMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: clipboardMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅍"
                        color: clipboardMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        visible: switcherWindow.service.clipboardHistory.length > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -4
                        anchors.rightMargin: -5
                        width: Math.max(12, clipboardCount.implicitWidth + 5)
                        height: 12
                        radius: 6
                        color: "#abc7ff"
                        border.color: "#111722"
                        border.width: 1

                        Text {
                            id: clipboardCount
                            anchors.centerIn: parent
                            text: switcherWindow.service.clipboardHistory.length > 99
                                ? "99+" : String(switcherWindow.service.clipboardHistory.length)
                            color: "#111722"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 7
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: clipboardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.service.openClipboardManager()
                        ShellToolTip {
                            parent: clipboardMouse
                            visible: clipboardMouse.containsMouse
                            text: "Clipboard Manager · " + switcherWindow.service.clipboardHistory.length + " items"
                        }
                    }
                }

                RowLayout {
                    visible: switcherWindow.hasFocusedApp
                    spacing: 4

                    Repeater {
                        model: [
                            { value: switcherWindow.service.columnWidthSmall, name: "Narrow", glyphWidth: 5 },
                            { value: switcherWindow.service.columnWidthMedium, name: "Normal", glyphWidth: 10 },
                            { value: switcherWindow.service.columnWidthLarge, name: "Wide", glyphWidth: 15 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 22
                            implicitHeight: 22
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

                        }
                    }
                }

                // Fullscreen control follows the column-width presets.
                Rectangle {
                    visible: switcherWindow.hasFocusedApp
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

                }

                // Audio mixer
                Rectangle {
                    Layout.leftMargin: 9
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
                    }
                }

                // Backlight control follows volume.
                Loader {
                    active: switcherWindow.service.showSwitcherSystemControls
                    visible: switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    sourceComponent: brightnessIndicatorComponent
                }

                // Bluetooth power toggle
                Loader {
                    active: switcherWindow.service.showSwitcherSystemControls
                    visible: switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    sourceComponent: bluetoothIndicatorComponent
                }

                // Network status indicator
                Loader {
                    active: switcherWindow.service.showSwitcherSystemControls
                    visible: switcherWindow.service.showSwitcherSystemControls
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    sourceComponent: networkIndicatorComponent
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
                            if (mouse.button === Qt.LeftButton)
                                switcherWindow.service.notificationService.openCenter()
                            else
                                switcherWindow.service.notificationService.toggleDnd()
                        }
                    }

                    Rectangle {
                        id: unreadBadge
                        visible: switcherWindow.service.unreadNotificationCount > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -5
                        anchors.rightMargin: -5
                        z: 2
                        implicitWidth: unreadCountText.implicitWidth + 8
                        implicitHeight: 14
                        radius: 7
                        color: "#e34f68"
                        border.color: "#111722"
                        border.width: 1

                        Text {
                            id: unreadCountText
                            anchors.centerIn: parent
                            text: switcherWindow.service.unreadNotificationCount > 99
                                ? "99+" : String(switcherWindow.service.unreadNotificationCount)
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            id: unreadCountMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcherWindow.service.notificationService.openCenter()
                        }

                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: switcherControlsMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: switcherControlsMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: switcherWindow.service.showSwitcherSystemControls ? "🢗" : "🢕"
                        color: switcherControlsMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: switcherControlsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcherWindow.toggleSwitcherSystemControls()
                    }
                }

            }

            // Divider Line
            Loader {
                active: switcherWindow.service.showSwitcherSystemControls
                visible: switcherWindow.service.showSwitcherSystemControls
                Layout.fillWidth: true
                sourceComponent: optionalControlsDividerComponent
            }

            Loader {
                id: fullAppsStripLoader
                active: switcherWindow.service.showSwitcherSystemControls
                visible: switcherWindow.service.showSwitcherSystemControls
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                sourceComponent: appsWorkspaceStripComponent
            }

            Loader {
                active: switcherWindow.service.showSwitcherSystemControls
                visible: switcherWindow.service.showSwitcherSystemControls
                Layout.fillWidth: true
                sourceComponent: optionalControlsDividerComponent
            }

            Loader {
                active: switcherWindow.service.showSwitcherSystemControls
                visible: switcherWindow.service.showSwitcherSystemControls
                Layout.fillWidth: true
                sourceComponent: bottomControlsComponent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 90
        visible: switcherWindow.contextMenuWindow !== null
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: {
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
        }
    }

}
