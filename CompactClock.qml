import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: true
    // Keep this full-screen surface non-reserving so the card can travel to
    // screen center before the full clock opens.
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Keep the compact row above the edge trigger so row controls receive input.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-compact-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        Region { item: compactCard }
        Region { item: clockButton }
        Region { item: mediaControls }
        Region { item: notificationBadge }
    }

    property var now: service.clockNow
    property bool colonVisible: service.clockColonVisible
    property real slideY: -18
    property string selectedPlayerName: ""
    readonly property var mediaPlayers: Mpris.players.values
    readonly property var availableMediaPlayers: {
        var result = [];
        var players = mediaPlayers || [];
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState !== MprisPlaybackState.Stopped)
                result.push(players[i]);
        }
        return result;
    }
    readonly property var activeMediaPlayer: {
        var players = availableMediaPlayers;
        if (players.length === 0) return null;
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === selectedPlayerName) return players[i];
        }
        for (var j = 0; j < players.length; j++) {
            if (players[j].isPlaying) return players[j];
        }
        return players[0];
    }
    readonly property int mediaControlsWidth: activeMediaPlayer
        ? 54 + (availableMediaPlayers.length > 1 ? 18 : 0)
        : 0
    readonly property string activePlayerInitial: {
        var name = activeMediaPlayer ? playerDisplayName(activeMediaPlayer) : "";
        return name ? name.charAt(0).toUpperCase() : "?";
    }

    Component.onDestruction: {
        root.service.compactClockClockHovered = false
        root.service.compactClockControlsHovered = false
    }

    Timer {
        id: closeAfterPointerExit
        interval: 240
        repeat: false
        onTriggered: {
            if (!root.service.compactClockCardHovered)
                root.service.closeCompactClock()
        }
    }

    function cycleMediaPlayer() {
        var players = availableMediaPlayers;
        if (players.length < 2) return;
        var currentIndex = -1;
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === (activeMediaPlayer ? activeMediaPlayer.dbusName : "")) {
                currentIndex = i;
                break;
            }
        }
        selectedPlayerName = players[(currentIndex + 1) % players.length].dbusName;
    }

    function openActivePlayer() {
        var player = activeMediaPlayer;
        if (!player) return;

        var webApp = playerWebAppName(player);
        if (focusPlayerWindow(player, webApp)) return;

        if (webApp) {
            // Launching the installed web-app entry targets its app id, while
            // MPRIS raise() targets the browser that owns the media session.
            var webAppEntry = webApp === "YouTube" ? youtubeDesktopEntryId() : "";
            if (webAppEntry) {
                Quickshell.execDetached(["gtk-launch", webAppEntry]);
                return;
            }
            root.service.focusNotificationSender({ desktopEntry: "", appName: webApp });
            return;
        }

        root.service.focusNotificationSender({
            desktopEntry: String(player.desktopEntry || ""),
            appName: String(player.identity || "")
        });
        if (player.canRaise)
            player.raise();
    }

    function playerWebAppName(player) {
        var url = "";
        try { url = String(player.metadata["xesam:url"] || "").toLowerCase(); } catch (e) {}
        var artUrl = String(player.trackArtUrl || "").toLowerCase();
        var identity = String(player.identity || "").toLowerCase();
        var desktopEntry = String(player.desktopEntry || "").toLowerCase();
        var heliumSession = identity.indexOf("helium") >= 0 || desktopEntry.indexOf("helium") >= 0;
        if (url.indexOf("youtube.com") >= 0 || url.indexOf("youtu.be") >= 0 ||
                artUrl.indexOf("ytimg.com") >= 0 || identity.indexOf("youtube") >= 0 ||
                (heliumSession && youtubeDesktopEntryId()))
            return "YouTube";
        return "";
    }

    function playerDisplayName(player) {
        var webApp = playerWebAppName(player);
        if (webApp) return webApp;
        var identity = String(player.identity || "").trim();
        if (identity) return identity;
        return String(player.desktopEntry || "").replace(/\.desktop$/i, "");
    }

    function youtubeDesktopEntryId() {
        try {
            var entry = DesktopEntries.heuristicLookup("YouTube");
            if (entry) return root.service.normalizedDesktopEntryId(entry.id);
        } catch (e) {
        }
        return "chrome-agimnkijcaahngcdmfeangaknmldooml-Default.desktop";
    }

    function youtubeWindowAppId() {
        var entryId = youtubeDesktopEntryId().toLowerCase().replace(/\.desktop$/, "");
        var match = entryId.match(/^chrome-(.+)-default$/i);
        return match ? ("crx_" + match[1]).toLowerCase() : "";
    }

    function focusPlayerWindow(player, webApp) {
        var workspaces = root.service.workspaces || [];
        var desktopEntry = root.service.normalizedDesktopEntryId(player.desktopEntry).toLowerCase();
        var desktopApp = desktopEntry.replace(/\.desktop$/, "");
        var siteName = String(webApp || "").toLowerCase();
        var trackTitle = String(player.trackTitle || "").trim().toLowerCase();
        var youtubeEntry = siteName === "youtube" ? youtubeDesktopEntryId().toLowerCase() : "";
        var youtubeAppStem = youtubeEntry.replace(/\.desktop$/, "");
        var youtubeAppId = siteName === "youtube" ? youtubeWindowAppId() : "";
        var siteMatch = null;
        var siteMatchRank = 99;

        for (var i = 0; i < workspaces.length; i++) {
            var windows = workspaces[i].windows || [];
            for (var j = 0; j < windows.length; j++) {
                var win = windows[j];
                var appId = String(win.appId || "").toLowerCase();
                var title = String(win.title || "").toLowerCase();
                var windowEntry = "";
                try {
                    var entry = root.service.appEntryForWindow(win);
                    if (entry) windowEntry = root.service.normalizedDesktopEntryId(entry.id).toLowerCase();
                } catch (e) {}

                if (siteName) {
                    var rank = 99;
                    if ((youtubeEntry && windowEntry === youtubeEntry) ||
                            (youtubeAppStem && appId === youtubeAppStem) ||
                            (youtubeAppId && appId.indexOf(youtubeAppId) >= 0)) rank = 0;
                    else if (siteName !== "youtube") {
                        if (appId.indexOf(siteName) >= 0 || windowEntry.indexOf(siteName) >= 0) rank = 1;
                        else if (title.indexOf(siteName) >= 0) rank = 2;
                        else if (trackTitle && title.indexOf(trackTitle) >= 0) rank = 3;
                    }
                    if (rank < siteMatchRank) {
                        siteMatch = win;
                        siteMatchRank = rank;
                    }
                    continue;
                }

                var normalizedAppId = root.service.normalizedDesktopEntryId(appId).toLowerCase();
                if ((desktopEntry && (windowEntry === desktopEntry || normalizedAppId === desktopEntry)) ||
                        (desktopApp && appId === desktopApp)) {
                    root.service.focusWindow(win);
                    return true;
                }
            }
        }
        if (siteMatch) {
            root.service.focusWindow(siteMatch);
            return true;
        }
        return false;
    }

    function updateClockHover(hovered) {
        root.service.compactClockClockHovered = hovered;
        if (hovered) closeAfterPointerExit.stop();
        else closeAfterPointerExit.restart();
    }

    function updateControlsHover(hovered) {
        root.service.compactClockControlsHovered = hovered;
        if (hovered) closeAfterPointerExit.stop();
        else closeAfterPointerExit.restart();
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "slideY"
        from: -18
        to: 0
        duration: 320
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "slideY"
        from: root.slideY
        to: root.service.compactClockCloseToCenter
            ? Math.max(8, (root.height - compactCard.height) / 2)
            : -18
        duration: root.service.compactClockCloseToCenter ? 400 : 240
        easing.type: Easing.InCubic
        onStopped: {
            if (root.service.compactClockClosing)
                root.service.finishCompactClockClose()
        }
    }

    Connections {
        target: root.service
        function onCompactClockOpenChanged() {
            if (root.service.compactClockOpen) {
                slideOut.stop()
                root.slideY = -18
                slideIn.start()
            }
        }
        function onCompactClockClosingChanged() {
            if (root.service.compactClockClosing) {
                slideIn.stop()
                slideOut.start()
            } else if (root.service.compactClockOpen) {
                slideOut.stop()
                root.slideY = -18
                slideIn.start()
            }
        }
    }

    Component.onCompleted: slideIn.start()

    Item {
        anchors.fill: parent

        GlowBorder {
            targetItem: compactCard
            cornerRadius: compactCard.radius
        }

        Rectangle {
            id: compactCard
            x: (root.width - width) / 2
            y: root.slideY
            width: 69 + root.mediaControlsWidth
            height: 18
            radius: 12
            color: Qt.rgba(17 / 255, 23 / 255, 34 / 255, root.service.clockCardBackgroundOpacity / 100)
            border.color: "#3b4a63"
            border.width: 1

        }

        Rectangle {
            id: notificationBadge
            visible: root.service.unreadNotificationCount > 0
            x: compactCard.x + compactCard.width - 3
            y: compactCard.y - 3
            z: 14
            width: root.service.unreadNotificationCount > 9 ? 17 : 10
            height: 10
            radius: 5
            color: "#ef6478"
            border.color: "#111622"
            border.width: 1
            Text {
                anchors.centerIn: parent
                visible: root.service.unreadNotificationCount > 9
                text: root.service.unreadNotificationCount > 99 ? "99+" : String(root.service.unreadNotificationCount)
                color: "#111622"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 7
                font.bold: true
            }
            ShellToolTip {
                parent: notificationBadgeMouse
                visible: notificationBadgeMouse.containsMouse
                text: root.service.unreadNotificationCount + " unread notification" + (root.service.unreadNotificationCount === 1 ? "" : "s")
            }
            MouseArea {
                id: notificationBadgeMouse
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        Button {
            id: clockButton
            x: compactCard.x
            y: compactCard.y
            width: 69
            height: compactCard.height
            z: 11
            padding: 0
            hoverEnabled: true
            text: Qt.formatDateTime(root.now, "HH") + (root.colonVisible ? ":" : " ") + Qt.formatDateTime(root.now, "mm")
            background: Item {}
            onHoveredChanged: root.updateClockHover(hovered)
            onClicked: root.service.openCalendarFromCompactClock()
            contentItem: Text {
                id: clockButtonText
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: compactCard.y + compactCard.height / 2 - height / 2 - clockButton.y
                text: clockButton.text
                color: "#ffffff"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.weight: Font.Light
                font.pixelSize: root.service.compactClockTextSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            id: mediaControls
            x: compactCard.x + 69
            y: compactCard.y
            width: root.mediaControlsWidth
            height: compactCard.height
            z: 13
            visible: root.activeMediaPlayer !== null

            HoverHandler {
                onHoveredChanged: root.updateControlsHover(hovered)
            }

            Repeater {
                model: root.availableMediaPlayers.length > 1 ? 4 : 3

                delegate: Rectangle {
                    required property int index
                    readonly property var player: root.activeMediaPlayer
                    readonly property bool actionEnabled: {
                        if (root.availableMediaPlayers.length > 1 && index === 0)
                            return true;
                        var controlIndex = index - (root.availableMediaPlayers.length > 1 ? 1 : 0);
                        if (controlIndex === 0) return player && player.canTogglePlaying;
                        if (controlIndex === 1) return player && player.canGoNext;
                        return !!player;
                    }
                    x: index * 18
                    width: 18
                    height: 18
                    radius: 8
                    color: mediaControlMouse.containsMouse ? "#35445c" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.availableMediaPlayers.length > 1 && index === 0) return "⇄";
                            var controlIndex = index - (root.availableMediaPlayers.length > 1 ? 1 : 0);
                            if (controlIndex === 0) return player && player.isPlaying ? "Ⅱ" : "▶";
                            if (controlIndex === 1) return "⏭";
                            return root.activePlayerInitial;
                        }
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: mediaControlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: true
                        cursorShape: parent.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!parent.actionEnabled) return;
                            if (root.availableMediaPlayers.length > 1 && index === 0) {
                                root.cycleMediaPlayer();
                                return;
                            }
                            var controlIndex = index - (root.availableMediaPlayers.length > 1 ? 1 : 0);
                            if (!player) return;
                            if (controlIndex === 0) player.togglePlaying();
                            else if (controlIndex === 1) player.next();
                            else root.openActivePlayer();
                        }
                        ShellToolTip {
                            parent: mediaControlMouse
                            visible: mediaControlMouse.containsMouse
                            text: {
                                if (root.availableMediaPlayers.length > 1 && index === 0)
                                    return "Switch player: " + (player ? root.playerDisplayName(player) : "");
                                var controlIndex = index - (root.availableMediaPlayers.length > 1 ? 1 : 0);
                                if (controlIndex === 0) return player && player.isPlaying ? "Pause" : "Play";
                                if (controlIndex === 1) return "Next track";
                                return "Open or focus " + (player ? root.playerDisplayName(player) : "player");
                            }
                        }
                    }
                }
            }
        }

    }
}
