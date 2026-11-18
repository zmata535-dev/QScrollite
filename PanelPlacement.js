.pragma library

function switcherActive(service) {
    return !!service && (!!service.open || !!service.appSwitcherHovered)
}

function focusedWindowIsLeft(service, screenX, screenWidth) {
    if (!service || service.activeCompositor !== "hyprland") return false
    var activeId = String(service.activeWindowId || "")
    var workspaces = service.workspaces || []
    for (var i = 0; i < workspaces.length; i++) {
        var windows = workspaces[i].windows || []
        for (var j = 0; j < windows.length; j++) {
            var window = windows[j]
            if (String(window.id) !== activeId) continue
            return Number(window.x || 0) < Number(screenX || 0) + Number(screenWidth || 0) / 2
        }
    }
    return false
}

function oppositeTargetX(service, screenX, screenWidth, panelWidth, margin) {
    var gap = Number(margin || 12)
    return focusedWindowIsLeft(service, screenX, screenWidth)
        ? Number(screenWidth) - Number(panelWidth) - gap
        : gap
}

function entryX(targetX, screenWidth, panelWidth, screenX, margin) {
    var gap = Number(margin || 12)
    return Number(targetX) + Number(panelWidth) / 2 > Number(screenWidth) / 2
        ? Number(screenWidth) + gap
        : -Number(panelWidth) - gap
}
