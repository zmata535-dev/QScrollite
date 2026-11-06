import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    property var wallpapers: []
    property string currentWallpaper: ""
    property int currentIndex: 0
    property int slideshowInterval: 0
    property bool selectorOpen: false
    property bool isScanning: false
    property bool stateLoaded: false

    readonly property string intervalLabel: {
        if (slideshowInterval <= 0) return "Off";
        if (slideshowInterval >= 3600) return (slideshowInterval / 3600) + "h";
        return (slideshowInterval / 60) + "m";
    }

    function normalizePath(p) {
        if (!p) return "";
        var s = p.toString().trim();
        if (s.startsWith("file://")) s = s.substring(7);
        return s;
    }

    function saveState() {
        var state = {
            current: currentWallpaper,
            interval: slideshowInterval
        };
        try {
            stateFile.setText(JSON.stringify(state, null, 2));
        } catch (e) {
            console.log("[WallpaperService] Failed to save state:", e);
        }
    }

    function setWallpaper(path) {
        var clean = normalizePath(path);
        if (!clean) return;

        // If not in current list, add it
        var foundIndex = -1;
        for (var i = 0; i < wallpapers.length; i++) {
            if (wallpapers[i] === clean) {
                foundIndex = i;
                break;
            }
        }
        if (foundIndex === -1) {
            var updated = wallpapers.slice();
            updated.unshift(clean);
            wallpapers = updated;
            currentIndex = 0;
        } else {
            currentIndex = foundIndex;
        }

        currentWallpaper = clean;
        saveState();
    }

    function next() {
        if (wallpapers.length === 0) return;
        var nextIdx = (currentIndex + 1) % wallpapers.length;
        currentIndex = nextIdx;
        currentWallpaper = wallpapers[nextIdx];
        saveState();
    }

    function prev() {
        if (wallpapers.length === 0) return;
        var prevIdx = (currentIndex - 1 + wallpapers.length) % wallpapers.length;
        currentIndex = prevIdx;
        currentWallpaper = wallpapers[prevIdx];
        saveState();
    }

    function random() {
        if (wallpapers.length <= 1) return;
        var randIdx = Math.floor(Math.random() * wallpapers.length);
        if (randIdx === currentIndex && wallpapers.length > 1) {
            randIdx = (randIdx + 1) % wallpapers.length;
        }
        currentIndex = randIdx;
        currentWallpaper = wallpapers[randIdx];
        saveState();
    }

    function setInterval(sec) {
        var val = parseInt(sec);
        if (isNaN(val) || val < 0) val = 0;
        slideshowInterval = val;
        saveState();
    }

    function cycleInterval() {
        var steps = [0, 300, 900, 1800, 3600];
        var curr = slideshowInterval;
        var nextVal = steps[0];
        for (var i = 0; i < steps.length; i++) {
            if (steps[i] === curr) {
                nextVal = steps[(i + 1) % steps.length];
                break;
            }
        }
        setInterval(nextVal);
    }

    function toggleSelector() {
        selectorOpen = !selectorOpen;
    }

    function openSelector() {
        selectorOpen = true;
    }

    function closeSelector() {
        selectorOpen = false;
    }

    function scan() {
        if (isScanning) return;
        isScanning = true;
        scanner.running = true;
    }

    // State Persistence
    property var stateFile: FileView {
        id: stateFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/wallpaper-state.json"
        printErrors: false
        watchChanges: true

        onLoaded: {
            try {
                var content = text();
                if (content && content.trim().length > 0) {
                    var data = JSON.parse(content);
                    if (data.interval !== undefined) {
                        service.slideshowInterval = parseInt(data.interval) || 0;
                    }
                    if (data.current && data.current.length > 0) {
                        service.currentWallpaper = service.normalizePath(data.current);
                    }
                }
            } catch (e) {
                console.log("[WallpaperService] Error parsing state file:", e);
            }
            service.stateLoaded = true;
        }

        onLoadFailed: {
            service.stateLoaded = true;
            // Write initial state once scanner runs
        }
    }

    // Directory Scanner Process
    property var scanner: Process {
        id: scanner
        command: [
            "bash",
            "-c",
            "find -L ~/Pictures ~/Wallpapers ~/wallpapers ~/.local/share/wallpapers -maxdepth 4 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort -u"
        ]
        running: true

        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var lines = text.trim().split("\n").filter(function(l) { return l.length > 0; });
                    service.wallpapers = lines;

                    // Update currentIndex
                    var found = -1;
                    if (service.currentWallpaper) {
                        for (var i = 0; i < lines.length; i++) {
                            if (lines[i] === service.currentWallpaper) {
                                found = i;
                                break;
                            }
                        }
                    }

                    if (found !== -1) {
                        service.currentIndex = found;
                    } else if (lines.length > 0) {
                        // If no current wallpaper or existing not found, pick first
                        if (!service.currentWallpaper) {
                            service.currentIndex = 0;
                            service.currentWallpaper = lines[0];
                            service.saveState();
                        }
                    }
                }
                service.isScanning = false;
            }
        }
    }

    // Slideshow Auto-Cycle Timer
    property var timer: Timer {
        id: slideshowTimer
        interval: Math.max(1000, service.slideshowInterval * 1000)
        repeat: true
        running: service.slideshowInterval > 0
        onTriggered: {
            service.next();
        }
    }

    Component.onCompleted: {
        scan();
    }
}
