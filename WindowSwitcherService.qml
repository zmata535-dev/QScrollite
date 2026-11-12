import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    property var wallpaperService: null
    property var notificationService: null
    property var pendingNotificationSender: null
    property bool open: false
    property string switcherPlacement: "top-left"
    property bool appSwitcherHovered: false
    property bool appSwitcherClosePending: false
    property bool appMenuOpen: false
    property bool appMenuPending: false
    property bool calendarOpen: false
    property bool calendarPending: false
    property bool clockOpen: false
    property bool compactClockOpen: false
    property bool compactClockPending: false
    property bool compactClockClosing: false
    property bool compactClockCloseToCenter: false
    property bool clockCloseRequested: false
    property bool clockSlideCloseRequested: false
    property bool idleConfigOpen: false
    property string idleApplyStatus: ""
    property alias idleClockTimeout: idleSettings.clockTimeout
    property alias compactClockTimeout: idleSettings.compactClockTimeout
    property alias compactClockEnabled: idleSettings.compactClockEnabled
    property alias clockCardEnabled: idleSettings.clockCardEnabled
    property alias dimDisplayEnabled: idleSettings.dimDisplayEnabled
    onCompactClockEnabledChanged: {
        if (!compactClockEnabled) {
            compactClockOpenTimer.stop();
            compactClockPending = false;
            closeCompactClock();
        }
    }
    onClockCardEnabledChanged: {
        if (!clockCardEnabled) {
            clockOpenTimer.stop();
            if (clockOpen) requestClockClose();
        }
    }
    property alias idleDimTimeout: idleSettings.dimTimeout
    property alias idleDisplayOffTimeout: idleSettings.displayOffTimeout
    property alias idleLockTimeout: idleSettings.lockTimeout
    property alias idleClockTextColor: idleSettings.clockTextColor
    property alias idleClockTextSize: idleSettings.clockTextSize
    property alias compactClockTextSize: idleSettings.compactClockTextSize
    property alias iconTheme: idleSettings.iconTheme
    property alias clockCardBackgroundOpacity: idleSettings.clockCardBackgroundOpacity
    property alias clockShatterAnimationEnabled: idleSettings.clockShatterAnimationEnabled
    property alias clockSlideAnimationEnabled: idleSettings.clockSlideAnimationEnabled
    property alias showRssUsage: idleSettings.showRssUsage
    property alias emptyWorkspaceAction: idleSettings.emptyWorkspaceAction
    onEmptyWorkspaceActionChanged: lastEmptyWorkspaceKey = ""
    property alias pinnedApps: pinnedAppsStore.pinnedApps
    property alias columnWidthSmall: idleSettings.columnWidthSmall
    property alias columnWidthMedium: idleSettings.columnWidthMedium
    property alias columnWidthLarge: idleSettings.columnWidthLarge
    property bool previewOnHover: false
    property var workspaces: []
    property var hoveredWindow: null
    property string activeCompositor: "hyprland"
    property string activeWindowId: ""
    property string activeWorkspaceId: ""
    property string lastEmptyWorkspaceKey: ""
    property bool isRefreshing: false

    readonly property int unreadNotificationCount: notificationService ? notificationService.unread.length : 0
    readonly property bool doNotDisturb: notificationService ? notificationService.doNotDisturb : false

    property var idleSettingsFile: FileView {
        id: idleSettingsFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/idle-settings.json"
        onAdapterUpdated: {
            writeAdapter();
            service.idleApplyStatus = "Pending changes — press Apply";
        }
        onSaveFailed: function(error) {
            service.idleApplyStatus = "Could not save settings"
            console.warn("[IdleSettings] Save failed:", error)
        }

        JsonAdapter {
            id: idleSettings
            property int clockTimeout: 9
            property int compactClockTimeout: 3
            property bool compactClockEnabled: true
            property bool clockCardEnabled: true
            property bool dimDisplayEnabled: true
            property int dimTimeout: 15
            property int displayOffTimeout: 21
            property int lockTimeout: 26
            property string clockTextColor: "#e2e8f0"
            property string iconTheme: "Suru++"
            property int clockTextSize: 96
            property int compactClockTextSize: 36
            property int clockCardBackgroundOpacity: 100
            property bool clockShatterAnimationEnabled: true
            property bool clockSlideAnimationEnabled: false
            property bool showRssUsage: false
            property string emptyWorkspaceAction: "none"
            property int columnWidthSmall: 50
            property int columnWidthMedium: 69
            property int columnWidthLarge: 92
        }
    }

    property var pinnedAppsFile: FileView {
        id: pinnedAppsFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/pinned-apps.json"
        onAdapterUpdated: writeAdapter()
        onSaveFailed: function(error) { console.warn("[AppPins] Save failed:", error) }

        JsonAdapter {
            id: pinnedAppsStore
            property list<string> pinnedApps: []
        }
    }

    property var idleApplyProcess: Process {
        id: idleApplyProcess
        running: false
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                service.idleApplyStatus = "GTK/Qt theme saved; hypridle restarted"
            } else {
                service.idleApplyStatus = "Apply failed (exit " + exitCode + ")"
                console.warn("[IdleSettings] Apply script exited with code", exitCode, exitStatus)
            }
        }
        stderr: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) console.warn("[IdleSettings]", text.trim())
            }
        }
    }

    function detectCompositor() {
        var envComp = (Quickshell.env("QS_COMPOSITOR") || "").toString().trim().toLowerCase();
        if (envComp === "niri" || envComp === "hyprland") {
            activeCompositor = envComp;
            return;
        }

        var niriSock = Quickshell.env("NIRI_SOCKET");
        var desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toString().toLowerCase();
        var hyprSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");

        if ((niriSock && niriSock !== "") || desktop.indexOf("niri") !== -1) {
            activeCompositor = "niri";
        } else if ((hyprSig && hyprSig !== "") || desktop.indexOf("hyprland") !== -1) {
            activeCompositor = "hyprland";
        } else {
            activeCompositor = "hyprland";
        }
    }

    function resolveAppIcon(appId, title) {
        if (!appId) appId = "";
        appId = appId.toString().trim();

        // The Sakura window class is not itself an installed icon name on
        // this system; the sakura.desktop entry uses terminal-tango.
        if (appId.toLowerCase().indexOf("sakura") !== -1) {
            var sakuraIcon = Quickshell.iconPath("terminal-tango");
            if (sakuraIcon && sakuraIcon.length > 0) return sakuraIcon;
        }

        // 1. Try DesktopEntries.heuristicLookup
        try {
            var entry = DesktopEntries.heuristicLookup(appId);
            if (entry && entry.icon) {
                var p = Quickshell.iconPath(entry.icon);
                if (p && p.length > 0) return p;
            }
        } catch(e) {}

        // 2. Direct icon lookup
        var pDirect = Quickshell.iconPath(appId);
        if (pDirect && pDirect.length > 0) return pDirect;

        var pLower = Quickshell.iconPath(appId.toLowerCase());
        if (pLower && pLower.length > 0) return pLower;

        // 3. Known mappings
        var lower = appId.toLowerCase();
        if (lower.indexOf("kitty") !== -1) return Quickshell.iconPath("kitty");
        if (lower.indexOf("thunar") !== -1) return Quickshell.iconPath("org.xfce.thunar") || Quickshell.iconPath("thunar");
        if (lower.indexOf("gedit") !== -1) return Quickshell.iconPath("org.gnome.gedit") || Quickshell.iconPath("gedit");
        if (lower.indexOf("firefox") !== -1) return Quickshell.iconPath("firefox");
        if (lower.indexOf("code") !== -1) return Quickshell.iconPath("code") || Quickshell.iconPath("visual-studio-code");

        // 4. Fallback
        return Quickshell.iconPath("application-x-executable") || Quickshell.iconPath("window") || "";
    }

    // Process for fetching window list
    property var fetchProcess: Process {
        id: fetchProc
        command: {
            if (service.activeCompositor === "niri") {
                return ["bash", "-c", "niri msg -j windows 2>/dev/null; echo '---SPLIT---'; niri msg -j workspaces 2>/dev/null"];
            } else {
                return ["bash", "-c", "hyprctl -j clients 2>/dev/null; echo '---SPLIT---'; hyprctl -j activewindow 2>/dev/null; echo '---ACTIVEWS---'; hyprctl -j activeworkspace 2>/dev/null"];
            }
        }
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                if (!text || text.trim().length === 0) {
                    service.isRefreshing = false;
                    return;
                }

                try {
                    var parts = text.split("---SPLIT---");
                    var rawClients = parts[0] ? parts[0].trim() : "";
                    var rawExtra = parts[1] ? parts[1].trim() : "";

                    if (service.activeCompositor === "niri") {
                        parseNiri(rawClients, rawExtra);
                    } else {
                        var hyprParts = rawExtra.split("---ACTIVEWS---");
                        parseHyprland(rawClients, hyprParts[0] || "", hyprParts[1] || "");
                    }
                } catch(e) {
                    console.log("[WindowSwitcher] Error parsing windows:", e);
                }
                service.isRefreshing = false;
            }
        }
    }

    function parseHyprland(clientsJson, activeJson, activeWorkspaceJson) {
        if (!clientsJson) return;
        var clients = JSON.parse(clientsJson);
        var activeAddr = "";
        try {
            if (activeJson) {
                var act = JSON.parse(activeJson);
                activeAddr = act.address || "";
            }
        } catch(e) {}

        service.activeWindowId = activeAddr;
        var activeWorkspace = activeWorkspaceJson ? JSON.parse(activeWorkspaceJson) : {};
        service.activeWorkspaceId = activeWorkspace.id !== undefined ? String(activeWorkspace.id) : "";
        var activeWorkspaceWindowCount = 0;
        if (service.activeWorkspaceId) {
            for (var activeIndex = 0; activeIndex < clients.length; activeIndex++) {
                var clientWorkspace = clients[activeIndex].workspace;
                if (clientWorkspace && String(clientWorkspace.id) === service.activeWorkspaceId)
                    activeWorkspaceWindowCount++;
            }
            updateEmptyWorkspaceAction(activeWorkspaceWindowCount === 0);
        }

        var wsMap = {};
        for (var i = 0; i < clients.length; i++) {
            var c = clients[i];
            if (!c.workspace || c.workspace.id === undefined) continue;
            var wsId = c.workspace.id;
            var wsName = c.workspace.name || wsId.toString();

            if (!wsMap[wsId]) {
                wsMap[wsId] = {
                    id: wsId,
                    name: wsName,
                    windows: []
                };
            }

            var appId = c.class || c.initialClass || "";
            var icon = resolveAppIcon(appId, c.title);

            wsMap[wsId].windows.push({
                id: c.address,
                title: c.title || "Window",
                appId: appId,
                icon: icon,
                workspaceId: wsId,
                workspaceName: wsName,
                x: (c.at && c.at.length > 0) ? c.at[0] : 0,
                y: (c.at && c.at.length > 1) ? c.at[1] : 0,
                width: (c.size && c.size.length > 0) ? c.size[0] : 0,
                height: (c.size && c.size.length > 1) ? c.size[1] : 0,
                focused: c.address === activeAddr
            });
        }

        var wsList = [];
        var keys = Object.keys(wsMap);
        for (var k = 0; k < keys.length; k++) {
            var ws = wsMap[keys[k]];
            if (ws.windows.length === 0) continue; // Exclude empty workspaces

            // SORT BY LAYOUT POSITION: x (at[0]) then y (at[1])
            ws.windows.sort(function(a, b) {
                if (a.x !== b.x) return a.x - b.x;
                return a.y - b.y;
            });

            wsList.push(ws);
        }

        wsList.sort(function(a, b) {
            return a.id - b.id;
        });

        service.workspaces = wsList;
    }

    function parseNiri(windowsJson, workspacesJson) {
        if (!windowsJson) return;
        var windows = JSON.parse(windowsJson);
        var focusedWorkspaceId = "";
        var workspaces = workspacesJson ? JSON.parse(workspacesJson) : [];
        for (var workspaceIndex = 0; workspaceIndex < workspaces.length; workspaceIndex++) {
            if (workspaces[workspaceIndex].is_focused) {
                focusedWorkspaceId = String(workspaces[workspaceIndex].id);
                break;
            }
        }
        service.activeWorkspaceId = focusedWorkspaceId;
        service.activeWindowId = "";
        var focusedWorkspaceWindowCount = 0;
        for (var windowIndex = 0; windowIndex < windows.length; windowIndex++) {
            if (String(windows[windowIndex].workspace_id) === focusedWorkspaceId)
                focusedWorkspaceWindowCount++;
        }
        if (focusedWorkspaceId)
            updateEmptyWorkspaceAction(focusedWorkspaceWindowCount === 0);

        var wsMap = {};

        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];
            var wsId = w.workspace_id || 1;
            if (!wsMap[wsId]) {
                wsMap[wsId] = {
                    id: wsId,
                    name: wsId.toString(),
                    windows: []
                };
            }

            var colIdx = 0;
            var rowIdx = 0;
            if (w.layout && w.layout.pos_in_scrolling_layout) {
                colIdx = w.layout.pos_in_scrolling_layout[0] || 0;
                rowIdx = w.layout.pos_in_scrolling_layout[1] || 0;
            } else if (w.layout && w.layout.tile_pos_in_workspace_view) {
                colIdx = w.layout.tile_pos_in_workspace_view[0] || 0;
                rowIdx = w.layout.tile_pos_in_workspace_view[1] || 0;
            }

            var appId = w.app_id || "";
            var icon = resolveAppIcon(appId, w.title);

            if (w.is_focused) {
                service.activeWindowId = w.id.toString();
            }

            wsMap[wsId].windows.push({
                id: w.id,
                title: w.title || "Window",
                appId: appId,
                icon: icon,
                workspaceId: wsId,
                workspaceName: wsId.toString(),
                x: colIdx,
                y: rowIdx,
                width: (w.layout && w.layout.window_size) ? w.layout.window_size[0] : 0,
                height: (w.layout && w.layout.window_size) ? w.layout.window_size[1] : 0,
                focused: !!w.is_focused
            });
        }

        var wsList = [];
        var keys = Object.keys(wsMap);
        for (var k = 0; k < keys.length; k++) {
            var ws = wsMap[keys[k]];
            if (ws.windows.length === 0) continue; // Exclude empty workspaces

            // SORT BY LAYOUT POSITION: column index (x), then row (y)
            ws.windows.sort(function(a, b) {
                if (a.x !== b.x) return a.x - b.x;
                return a.y - b.y;
            });

            wsList.push(ws);
        }

        wsList.sort(function(a, b) {
            return a.id - b.id;
        });

        service.workspaces = wsList;
    }

    function refresh() {
        if (isRefreshing) return;
        isRefreshing = true;
        detectCompositor();
        fetchProc.running = true;
    }

    function updateEmptyWorkspaceAction(isEmpty) {
        if (!activeWorkspaceId) return;
        if (!isEmpty) {
            lastEmptyWorkspaceKey = "";
            return;
        }

        var key = activeCompositor + ":" + activeWorkspaceId;
        if (lastEmptyWorkspaceKey === key) return;
        lastEmptyWorkspaceKey = key;

        if (open || appMenuOpen || appMenuPending || calendarOpen || calendarPending ||
                clockOpen || idleConfigOpen || compactClockOpen || compactClockPending)
            return;

        if (emptyWorkspaceAction === "clock")
            openClock();
        else if (emptyWorkspaceAction === "switcher")
            openSwitcher();
    }

    // Auto-refresh timer while switcher is open
    property var liveTimer: Timer {
        interval: 500
        repeat: true
        running: service.open
        onTriggered: {
            service.refresh();
        }
    }

    property var workspaceMonitorTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: service.refresh()
    }

    function openSwitcher(placement) {
        switcherPlacement = placement === "bottom-center" ? "bottom-center" : "top-left";
        cancelCompactClockForAppPanels();
        appSwitcherHovered = false;
        appSwitcherClosePending = false;
        detectCompositor();
        workspaces = [];
        activeWindowId = "";
        refresh();
        open = true;
    }

    function cancelCompactClockForAppPanels() {
        compactClockOpenTimer.stop();
        compactClockPending = false;
        closeCompactClock();
    }

    function closeSwitcher(force) {
        if (open && appSwitcherHovered && force !== true) {
            appSwitcherClosePending = true;
            return false;
        }
        open = false;
        appSwitcherClosePending = false;
        appSwitcherHovered = false;
        hoveredWindow = null;
        return true;
    }

    function toggle() {
        if (open) {
            closeSwitcher(true);
        } else {
            openSwitcher();
        }
    }

    function focusWindow(win) {
        if (!win || win.id === undefined) return;

        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", win.id.toString()]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + win.id + "\" })"]);
        }
        closeSwitcher(true);
    }

    function focusNotificationSender(notification) {
        if (!notification) return;
        pendingNotificationSender = {
            desktopEntry: String(notification.desktopEntry || ""),
            appName: String(notification.appName || "")
        };
        refresh();
        notificationFocusTimer.restart();
    }

    function resolveNotificationSender(notification) {
        if (!notification) return;
        var senderId = String(notification.desktopEntry || "").toLowerCase();
        var senderName = String(notification.appName || "").toLowerCase();
        var normalizedSender = senderId.endsWith(".desktop") ? senderId : senderId + ".desktop";
        var match = null;
        for (var i = 0; i < workspaces.length && !match; i++) {
            var windows = workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                var win = windows[j];
                var app = String(win.appId || "").toLowerCase();
                var entry = appEntryForWindow(win);
                var entryId = entry ? normalizedDesktopEntryId(entry.id).toLowerCase() : "";
                if ((normalizedSender !== ".desktop" && (entryId === normalizedSender || app === senderId || app + ".desktop" === normalizedSender)) ||
                    (senderName && (app === senderName || String(win.title || "").toLowerCase() === senderName))) {
                    match = win;
                    break;
                }
            }
        }
        if (match) {
            focusWindow(match);
            return;
        }

        var launchId = senderId;
        if (!launchId && senderName) {
            var senderEntry = null;
            try { senderEntry = DesktopEntries.heuristicLookup(senderName); } catch (e) {}
            if (senderEntry && senderEntry.id) launchId = String(senderEntry.id);
        }
        if (launchId) {
            if (!launchId.endsWith(".desktop")) launchId += ".desktop";
            Quickshell.execDetached(["gtk-launch", launchId]);
        }
    }

    property var notificationFocusTimer: Timer {
        interval: 650
        repeat: false
        onTriggered: {
            var pending = service.pendingNotificationSender;
            service.pendingNotificationSender = null;
            service.resolveNotificationSender(pending);
        }
    }

    function closeWindow(win) {
        if (!win || win.id === undefined || win.id === null) return;
        var id = win.id.toString();

        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", id]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = \"address:" + id + "\" })"]);
        }
    }

    function setWindowColumnWidth(win, percent) {
        if (!win || win.id === undefined || win.id === null) return;
        var id = String(win.id);
        var value = Math.max(10, Math.min(100, Number(percent)));
        if (activeCompositor === "niri") {
            // Niri's column-width action applies to the focused window.
            Quickshell.execDetached(["bash", "-c", "niri msg action focus-window --id \"$1\" && niri msg action set-column-width \"$2%\"", "qs-column-width", id, String(value)]);
        } else {
            // Hyprland's scrolling layout resizes the currently focused column
            // through colresize; this does not change focus or move the pointer.
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"colresize " + String(value / 100) + "\")"]);
        }
    }

    function toggleWindowFullscreen(win) {
        if (!win || win.id === undefined || win.id === null) return;
        var id = String(win.id);
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["bash", "-c", "niri msg action focus-window --id \"$1\" && niri msg action fullscreen-window", "qs-fullscreen", id]);
        } else {
            var escapedId = id.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ window = \"address:" + escapedId + "\", action = \"toggle\" })"]);
        }
    }

    function launchAppForWindow(win) {
        if (!win) return;
        var entry = null;
        try { entry = DesktopEntries.heuristicLookup(win.appId || win.title || ""); } catch (e) {}
        if (!entry || !entry.id) return;
        var id = String(entry.id);
        if (!id.endsWith(".desktop")) id += ".desktop";
        Quickshell.execDetached(["gtk-launch", id]);
    }

    function appEntryForWindow(win) {
        if (!win) return null;
        try { return DesktopEntries.heuristicLookup(win.appId || win.title || ""); } catch (e) { return null; }
    }

    function normalizedDesktopEntryId(id) {
        var value = String(id || "").trim();
        if (value && !value.endsWith(".desktop")) value += ".desktop";
        return value;
    }

    function pinnedAppIsRunning(id) {
        var targetId = normalizedDesktopEntryId(id).toLowerCase();
        if (!targetId) return false;
        for (var i = 0; i < workspaces.length; i++) {
            var windows = workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                var entry = appEntryForWindow(windows[j]);
                if (entry && normalizedDesktopEntryId(entry.id).toLowerCase() === targetId) return true;
                if (normalizedDesktopEntryId(windows[j].appId).toLowerCase() === targetId) return true;
            }
        }
        return false;
    }

    function launchPinnedApp(id) {
        var entryId = normalizedDesktopEntryId(id);
        if (entryId) Quickshell.execDetached(["gtk-launch", entryId]);
    }

    function isWindowAppPinned(win) {
        var entry = appEntryForWindow(win);
        if (!entry || !entry.id) return false;
        var appId = String(entry.id);
        if (!appId.endsWith(".desktop")) appId += ".desktop";
        return pinnedApps.indexOf(appId) >= 0;
    }

    function toggleWindowAppPinned(win) {
        var entry = appEntryForWindow(win);
        if (!entry || !entry.id) return;
        var appId = String(entry.id);
        if (!appId.endsWith(".desktop")) appId += ".desktop";
        var updated = pinnedApps.slice(0);
        var index = updated.indexOf(appId);
        if (index >= 0) updated.splice(index, 1);
        else updated.push(appId);
        pinnedApps = updated;
    }

    function closeAppWindows(win) {
        if (!win || !win.appId) return;
        var appId = String(win.appId).toLowerCase();
        for (var i = 0; i < workspaces.length; i++) {
            var windows = workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                if (String(windows[j].appId || "").toLowerCase() === appId) closeWindow(windows[j]);
            }
        }
    }

    function switchWorkspace(workspaceId) {
        if (workspaceId === undefined || workspaceId === null) return;
        var id = workspaceId.toString();
        if (!id) return;

        if (activeCompositor === "niri") {
            var niriId = Number(id);
            if (!isFinite(niriId)) return;
            var request = JSON.stringify({ Action: { FocusWorkspace: { reference: { Id: niriId } } } });
            Quickshell.execDetached(["bash", "-c", "printf '%s\\n' '" + request + "' | niri msg raw-request"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", id]);
        }
        closeSwitcher(true);
    }

    function nextWorkspace() {
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"+1\" })"]);
        }
        closeSwitcher(true);
    }

    function reloadHyprlandConfig() {
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function restartQuickshell() {
        var home = (Quickshell.env("HOME") || "").toString();
        Quickshell.execDetached(["bash", home + "/.config/quickshell/bin/qs-ctl", "restart"]);
    }

    function runSystemAction(action) {
        var command = [];
        if (action === "logout") {
            if (activeCompositor === "niri") {
                command = ["niri", "msg", "action", "quit", "--skip-confirmation"];
            } else {
                command = ["hyprctl", "dispatch", "hl.dsp.exit()"];
            }
        } else if (action === "reboot") {
            command = ["systemctl", "reboot"];
        } else if (action === "shutdown") {
            command = ["systemctl", "poweroff"];
        } else {
            console.warn("[SystemActions] Unknown action:", action);
            return;
        }

        closeSwitcher(true);
        Quickshell.execDetached(command);
    }

    property var calendarTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            service.calendarPending = false;
            service.calendarOpen = true;
        }
    }

    property var clockOpenTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: {
            var wallpaperOpen = service.wallpaperService && service.wallpaperService.selectorOpen;
            if (service.compactClockOpen || service.open || service.appMenuOpen || service.appMenuPending ||
                    service.calendarOpen || service.calendarPending || service.idleConfigOpen ||
                    service.wallpaperToggleTimer.running || wallpaperOpen) {
                restart();
                return;
            }
            service.clockCloseRequested = false;
            service.clockSlideCloseRequested = false;
            service.clockOpen = true;
        }
    }

    property var compactClockOpenTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (!service.compactClockPending) return;
            var wallpaperOpen = service.wallpaperService && service.wallpaperService.selectorOpen;
            if (service.open || service.appMenuOpen || service.appMenuPending) {
                service.compactClockPending = false;
                return;
            }
            if (service.calendarOpen || service.calendarPending || service.clockOpen ||
                    service.clockCloseRequested || service.idleConfigOpen || wallpaperOpen ||
                    service.wallpaperToggleTimer.running) {
                restart();
                return;
            }
            service.compactClockPending = false;
            service.compactClockOpen = true;
        }
    }

    function openCalendar() {
        closeSwitcher();
        calendarPending = true;
        calendarTimer.restart();
    }

    function openCalendarFromCompactClock() {
        closeSwitcher();
        calendarPending = true;
        if (unreadNotificationCount > 0 && notificationService)
            notificationService.openCenter();
        calendarTimer.restart();
    }

    function openClock() {
        if (!clockCardEnabled) return;
        compactClockOpenTimer.stop();
        compactClockPending = false;
        closeCompactClock(true);
        clockCloseRequested = false;
        clockSlideCloseRequested = false;
        clockOpen = false;
        clockOpenTimer.stop();
        closeSwitcher();
        appMenuTimer.stop();
        appMenuPending = false;
        appMenuOpen = false;
        calendarPending = false;
        calendarTimer.stop();
        calendarOpen = false;
        idleConfigOpen = false;
        wallpaperToggleTimer.stop();
        if (wallpaperService) wallpaperService.closeSelector();
        clockOpenTimer.start();
    }

    function closeClockOnActivity() {
        closeCompactClock();

        // The idle command that requests the full card can itself produce an
        // immediate resume callback. Let the short transition finish first;
        // once visible, activity closes the full card below.
        if (clockOpenTimer.running) {
            return "opening";
        }

        requestClockClose();
        return "closed";
    }

    function showCompactClock() {
        requestCompactClock();
    }

    function showCompactClockFromEdge() {
        requestCompactClock();
    }

    function requestCompactClock() {
        if (!compactClockEnabled) return;
        if (open || appMenuOpen || appMenuPending) {
            compactClockOpenTimer.stop();
            compactClockPending = false;
            return;
        }
        closeSwitcher();
        appMenuTimer.stop();
        appMenuPending = false;
        appMenuOpen = false;
        calendarTimer.stop();
        calendarPending = false;
        calendarOpen = false;
        clockOpenTimer.stop();
        if (clockOpen) requestClockClose();
        idleConfigOpen = false;
        wallpaperToggleTimer.stop();
        if (wallpaperService) wallpaperService.closeSelector();

        if (compactClockOpen) {
            // Do not reverse an activity or pointer-leave dismissal just
            // because the idle/edge trigger fires again during its animation.
            return;
        } else {
            compactClockPending = true;
            compactClockOpenTimer.restart();
        }
    }

    function closeCompactClock(toCenter) {
        if (compactClockPending) {
            compactClockPending = false;
            compactClockOpenTimer.stop();
        }
        if (!compactClockOpen || compactClockClosing) return;
        compactClockCloseToCenter = toCenter === true;
        compactClockClosing = true;
    }

    function finishCompactClockClose() {
        compactClockClosing = false;
        compactClockOpen = false;
        compactClockCloseToCenter = false;
    }

    function requestClockClose() {
        if (!clockOpen) return;
        if (clockShatterAnimationEnabled) {
            clockCloseRequested = true;
        } else if (clockSlideAnimationEnabled) {
            clockSlideCloseRequested = true;
        } else {
            clockCloseRequested = false;
            clockSlideCloseRequested = false;
            clockOpen = false;
        }
    }

    function openIdleConfig() {
        closeSwitcher();
        compactClockOpenTimer.stop();
        compactClockPending = false;
        closeCompactClock();
        clockOpenTimer.stop();
        if (clockOpen) requestClockClose();
        idleConfigOpen = true;
        idleApplyStatus = "";
    }

    function applyIdleSettings() {
        idleApplyStatus = "Saving settings…";
        idleApplyProcess.exec({
            command: [
                "python3",
                (Quickshell.env("HOME") || "") + "/.config/quickshell/apply-idle-settings.py",
                compactClockTimeout.toString(),
                idleClockTimeout.toString(),
                idleDimTimeout.toString(),
                idleDisplayOffTimeout.toString(),
                idleLockTimeout.toString(),
                compactClockEnabled.toString(),
                clockCardEnabled.toString(),
                dimDisplayEnabled.toString(),
                idleClockTextColor,
                idleClockTextSize.toString(),
                compactClockTextSize.toString(),
                iconTheme
            ]
        });
    }

    function toggleCalendar() {
        if (calendarOpen || calendarPending) {
            calendarTimer.stop();
            calendarPending = false;
            calendarOpen = false;
        } else {
            openCalendar();
        }
    }

    property var wallpaperToggleTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (service.wallpaperService) service.wallpaperService.toggleSelector();
        }
    }

    function toggleWallpaperSelector() {
        closeSwitcher();
        wallpaperToggleTimer.restart();
    }

    property var appMenuTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            service.appMenuPending = false;
            service.appMenuOpen = true;
        }
    }

    function openAppMenu() {
        cancelCompactClockForAppPanels();
        closeSwitcher();
        appMenuPending = true;
        appMenuTimer.restart();
    }

    function toggleAppMenu() {
        if (appMenuOpen || appMenuPending) {
            appMenuTimer.stop();
            appMenuPending = false;
            appMenuOpen = false;
        } else {
            openAppMenu();
        }
    }

    Component.onCompleted: {
        detectCompositor();
        refresh();
    }
}
