import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    property var wallpaperService: null
    property bool open: false
    property bool appMenuOpen: false
    property bool appMenuPending: false
    property bool calendarOpen: false
    property bool calendarPending: false
    property bool clockOpen: false
    property bool idleConfigOpen: false
    property bool ignoreClockActivity: false
    property string idleApplyStatus: ""
    property alias idleClockTimeout: idleSettings.clockTimeout
    property alias idleDimTimeout: idleSettings.dimTimeout
    property alias idleDisplayOffTimeout: idleSettings.displayOffTimeout
    property alias idleLockTimeout: idleSettings.lockTimeout
    property alias idleClockTextColor: idleSettings.clockTextColor
    property alias idleClockTextSize: idleSettings.clockTextSize
    property bool previewOnHover: false
    property var workspaces: []
    property var hoveredWindow: null
    property string activeCompositor: "hyprland"
    property string activeWindowId: ""
    property bool isRefreshing: false

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
            property int dimTimeout: 15
            property int displayOffTimeout: 21
            property int lockTimeout: 26
            property string clockTextColor: "#e2e8f0"
            property int clockTextSize: 96
        }
    }

    property var idleApplyProcess: Process {
        id: idleApplyProcess
        running: false
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                service.idleApplyStatus = "Applied; hypridle restarted"
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
                return ["bash", "-c", "hyprctl -j clients 2>/dev/null; echo '---SPLIT---'; hyprctl -j activewindow 2>/dev/null"];
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
                        parseHyprland(rawClients, rawExtra);
                    }
                } catch(e) {
                    console.log("[WindowSwitcher] Error parsing windows:", e);
                }
                service.isRefreshing = false;
            }
        }
    }

    function parseHyprland(clientsJson, activeJson) {
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

    // Auto-refresh timer while switcher is open
    property var liveTimer: Timer {
        interval: 500
        repeat: true
        running: service.open
        onTriggered: {
            service.refresh();
        }
    }

    function openSwitcher() {
        detectCompositor();
        workspaces = [];
        activeWindowId = "";
        refresh();
        open = true;
    }

    function closeSwitcher() {
        open = false;
        hoveredWindow = null;
    }

    function toggle() {
        if (open) {
            closeSwitcher();
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
        closeSwitcher();
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
        closeSwitcher();
    }

    function nextWorkspace() {
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"+1\" })"]);
        }
        closeSwitcher();
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

        closeSwitcher();
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
            if (service.open || service.appMenuOpen || service.appMenuPending ||
                    service.calendarOpen || service.calendarPending || service.idleConfigOpen ||
                    service.wallpaperToggleTimer.running || wallpaperOpen) {
                restart();
                return;
            }
            service.ignoreClockActivity = true;
            service.clockOpen = true;
            service.clockActivityGuardTimer.restart();
        }
    }

    property var clockActivityGuardTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: service.ignoreClockActivity = false
    }

    function openCalendar() {
        closeSwitcher();
        calendarPending = true;
        calendarTimer.restart();
    }

    function openClock() {
        clockOpen = false;
        ignoreClockActivity = true;
        clockActivityGuardTimer.stop();
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
        // Opening the overlay can itself produce an immediate idle-resume event.
        if (clockOpenTimer.running || ignoreClockActivity) return "ignored";
        clockOpen = false;
        return "closed";
    }

    function openIdleConfig() {
        closeSwitcher();
        idleConfigOpen = true;
        idleApplyStatus = "";
    }

    function applyIdleSettings() {
        idleApplyStatus = "Saving settings…";
        idleApplyProcess.exec({
            command: [
                "python3",
                (Quickshell.env("HOME") || "") + "/.config/quickshell/apply-idle-settings.py",
                idleClockTimeout.toString(),
                idleDimTimeout.toString(),
                idleDisplayOffTimeout.toString(),
                idleLockTimeout.toString(),
                idleClockTextColor,
                idleClockTextSize.toString()
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
    }
}
