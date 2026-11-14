import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property var wallpaperService: service

    function ensureHypridleForQuickShellIdleCallbacks() {
        var signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        var desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toString().toLowerCase();
        if ((!signature || signature === "") && desktop.indexOf("hyprland") === -1) return;
        Quickshell.execDetached(["bash", "-c", "pgrep -x hypridle >/dev/null || exec hypridle"]);
    }

    Component.onCompleted: ensureHypridleForQuickShellIdleCallbacks()

    WallpaperService {
        id: service
    }

    Variants {
        model: Quickshell.screens
        BackgroundLayer {
            service: root.wallpaperService
        }
    }

    LazyLoader {
        active: root.wallpaperService.selectorOpen

        WallpaperSelector {
            service: root.wallpaperService
        }
    }

    PolkitDialog {
        id: polkitDialog
    }

    WindowSwitcherService {
        id: switcherService
        wallpaperService: root.wallpaperService
        notificationService: notifications
    }

    NotificationService {
        id: notifications
        switcherService: switcherService
    }

    LazyLoader {
        active: notifications.toasts.length > 0

        NotificationPopups {
            service: notifications
        }
    }

    LazyLoader {
        active: notifications.notificationCenterOpen

        NotificationCenter {
            service: notifications
        }
    }

    LazyLoader {
        active: switcherService.open

        AppSwitcher {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.volumeOsdVisible

        VolumeOSD {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.brightnessOsdVisible

        BrightnessOSD {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.bluetoothOpen

        BluetoothManager {
            service: switcherService
        }
    }

    AppMenu {
        service: switcherService
    }

    LazyLoader {
        active: switcherService.calendarOpen

        Calendar {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.clockOpen

        ClockCard {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.compactClockOpen

        CompactClock {
            service: switcherService
        }
    }

    LazyLoader {
        active: switcherService.idleConfigOpen

        IdleSettings {
            service: switcherService
        }
    }

    HotCornerService {
        id: hotCornerService
        switcherService: switcherService
    }

    Variants {
        model: Quickshell.screens
        CompactClockEdge {
            service: switcherService
        }
    }

    Variants {
        model: Quickshell.screens
        AppSwitcherEdge {
            service: switcherService
        }
    }

    Variants {
        model: Quickshell.screens
        HotCornerBottomRight {
            service: hotCornerService
        }
    }

    Variants {
        model: Quickshell.screens
        HotCornerBottomLeft {
            service: hotCornerService
        }
    }

    Variants {
        model: Quickshell.screens
        HotCornerTopRight {
            service: hotCornerService
        }
    }

    Variants {
        model: Quickshell.screens
        HotCornerTopLeft {
            service: hotCornerService
        }
    }

    IpcHandler {
        target: "notifications"

        function status(): string {
            return JSON.stringify({
                unread: notifications.unreadCount,
                visible: notifications.toasts.length,
                doNotDisturb: notifications.doNotDisturb,
                timeoutSeconds: notifications.timeoutSeconds
            }, null, 2);
        }

        function toggleDnd(): string {
            notifications.toggleDnd();
            return notifications.doNotDisturb ? "Do Not Disturb on" : "Do Not Disturb off";
        }
    }

    IpcHandler {
        target: "hotcorner"

        function status(): string {
            return JSON.stringify({
                enabled: hotCornerService.enabled,
                activeCompositor: hotCornerService.activeCompositor,
                explicitCompositor: hotCornerService.explicitCompositor,
                detectedCompositor: hotCornerService.detectedCompositor,
                cornerSize: hotCornerService.cornerSize,
                cooldownMs: hotCornerService.cooldownMs,
                visualFeedback: hotCornerService.visualFeedback,
                corners: {
                    bottom_right: "switch focus right",
                    bottom_left: "switch focus left",
                    top_right: "center focused",
                    top_left: "app switcher"
                }
            }, null, 2);
        }

        function toggle(): string {
            hotCornerService.enabled = !hotCornerService.enabled;
            return hotCornerService.enabled ? "enabled" : "disabled";
        }

        function enable(): void {
            hotCornerService.enabled = true;
        }

        function disable(): void {
            hotCornerService.enabled = false;
        }

        function setCompositor(comp: string): string {
            if (comp === "niri" || comp === "hyprland") {
                hotCornerService.explicitCompositor = comp;
            } else if (comp === "auto" || comp === "reset") {
                hotCornerService.explicitCompositor = "";
                hotCornerService.detectCompositor();
            }
            return hotCornerService.activeCompositor;
        }

        function testIcon(name: string): string {
            var p = Quickshell.iconPath(name);
            var entry = DesktopEntries.heuristicLookup(name);
            var entryIcon = entry ? entry.icon : "";
            var entryPath = entryIcon ? Quickshell.iconPath(entryIcon) : "";
            return JSON.stringify({ name: name, path: p, entryName: entry ? entry.name : "", entryIcon: entryIcon, entryPath: entryPath });
        }

        function trigger(corner: string): string {
            var ok = hotCornerService.triggerCorner(corner, "");
            return ok ? "triggered " + corner : "ignored (cooldown or disabled)";
        }

        function setSize(px: string): void {
            var s = parseInt(px);
            if (s > 0) hotCornerService.cornerSize = s;
        }

        function setCooldown(ms: string): void {
            var c = parseInt(ms);
            if (c >= 0) hotCornerService.cooldownMs = c;
        }
    }

    IpcHandler {
        target: "switcher"

        function status(): string {
            return JSON.stringify({
                open: switcherService.open,
                previewOnHover: switcherService.previewOnHover,
                activeCompositor: switcherService.activeCompositor,
                activeWindowId: switcherService.activeWindowId,
                workspacesCount: switcherService.workspaces.length,
                workspaces: switcherService.workspaces
            }, null, 2);
        }

        function toggle(): string {
            switcherService.toggle();
            return switcherService.open ? "open" : "closed";
        }

        function open(): void {
            switcherService.openSwitcher();
        }

        function close(): void {
            switcherService.closeSwitcher();
        }

        function togglePreview(): string {
            switcherService.previewOnHover = !switcherService.previewOnHover;
            return switcherService.previewOnHover ? "on" : "off";
        }

        function refresh(): void {
            switcherService.refresh();
        }

    }

    IpcHandler {
        target: "appmenu"

        function toggle(): string {
            switcherService.toggleAppMenu();
            return switcherService.appMenuPending ? "opening" : (switcherService.appMenuOpen ? "open" : "closed");
        }

        function open(): void {
            switcherService.openAppMenu();
        }

        function close(): void {
            switcherService.appMenuTimer.stop();
            switcherService.appMenuPending = false;
            switcherService.appMenuOpen = false;
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): string {
            switcherService.toggleCalendar();
            return switcherService.calendarPending ? "opening" : (switcherService.calendarOpen ? "open" : "closed");
        }

        function open(): void {
            switcherService.openCalendar();
        }

        function close(): void {
            switcherService.calendarTimer.stop();
            switcherService.calendarPending = false;
            switcherService.calendarOpen = false;
        }
    }

    IpcHandler {
        target: "clock"

        function open(): void {
            switcherService.openClock();
        }

        function isOpen(): bool {
            return switcherService.clockOpen;
        }

        function compact(): void {
            switcherService.showCompactClock();
        }

        function compactIsOpen(): bool {
            return switcherService.compactClockOpen;
        }

        function mediaPlaying(): bool {
            return switcherService.compactClockOnMediaPlaying && switcherService.hasPlayingMedia();
        }

        function activity(): string {
            return switcherService.closeClockOnActivity();
        }

        function close(): void {
            switcherService.requestClockClose();
        }
    }

    IpcHandler {
        target: "idle-settings"

        function isOpen(): bool {
            return switcherService.idleConfigOpen;
        }
    }

    IpcHandler {
        target: "polkit"

        function status(): string {
            return JSON.stringify({
                registered: polkitDialog.agent.isRegistered,
                active: polkitDialog.agent.isActive
            }, null, 2);
        }

        function cancel(): void {
            polkitDialog.cancel();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            service.toggleSelector();
        }

        function open(): void {
            service.openSelector();
        }

        function close(): void {
            service.closeSelector();
        }

        function next(): void {
            service.next();
        }

        function prev(): void {
            service.prev();
        }

        function random(): void {
            service.random();
        }

        function set(path: string): void {
            service.setWallpaper(path);
        }

        function current(): string {
            return service.currentWallpaper;
        }

        function list(): string {
            return service.wallpapers.join("\n");
        }

        function interval(sec: string): void {
            service.setInterval(parseInt(sec) || 0);
        }

        function rescan(): void {
            service.scan();
        }

        function status(): string {
            return JSON.stringify({
                current: service.currentWallpaper,
                total: service.wallpapers.length,
                interval: service.slideshowInterval,
                open: service.selectorOpen
            }, null, 2);
        }
    }
}
