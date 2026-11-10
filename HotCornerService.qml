import QtQuick
import Quickshell

QtObject {
    id: service

    property string explicitCompositor: ""
    property string detectedCompositor: "hyprland"
    readonly property string activeCompositor: explicitCompositor !== "" ? explicitCompositor : detectedCompositor

    property bool enabled: true
    property int cornerSize: 12
    property int cooldownMs: 350
    property bool visualFeedback: true

    property real lastTriggerBR: 0
    property real lastTriggerBL: 0
    property real lastTriggerTR: 0
    property real lastTriggerTL: 0

    property var switcherService: null

    signal cornerTriggered(string corner, string screenName)

    function detectCompositor() {
        var envComp = (Quickshell.env("QS_COMPOSITOR") || "").toString().trim().toLowerCase();
        if (envComp === "niri" || envComp === "hyprland") {
            explicitCompositor = envComp;
            console.log("[HotCorner] Compositor set via QS_COMPOSITOR:", explicitCompositor);
            return;
        }

        var niriSock = Quickshell.env("NIRI_SOCKET");
        var desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toString().toLowerCase();
        var hyprSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");

        if ((niriSock && niriSock !== "") || desktop.indexOf("niri") !== -1) {
            detectedCompositor = "niri";
        } else if ((hyprSig && hyprSig !== "") || desktop.indexOf("hyprland") !== -1) {
            detectedCompositor = "hyprland";
        } else {
            detectedCompositor = "hyprland";
        }
        console.log("[HotCorner] Compositor auto-detected:", detectedCompositor);
    }

    function switchFocusRight() {
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-column-right"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"focus r\")"]);
        }
    }

    function switchFocusLeft() {
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "focus-column-left"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout(\"focus l\")"]);
        }
    }

    function centerFocused() {
        if (activeCompositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "center-column"]);
        } else {
            //Quickshell.execDetached(["hyprctl", "dispatch", "function() pcall(function() hl.dispatch(hl.dsp.layout(\"fit active\")) end); pcall(function() hl.dispatch(hl.dsp.window.center()) end) end"]);            		
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.layout('center')"]);
        }
    }

    function toggleAppSwitcher() {
        if (!switcherService) return;
        if (switcherService.open) {
            switcherService.closeSwitcher();
        } else {
            switcherService.openSwitcher();
        }
    }

    function triggerCorner(corner, screenName) {
        if (!enabled) return false;

        var now = Date.now();
        var cd = cooldownMs;

        if (corner === "bottom-right") {
            if (now - lastTriggerBR < cd) return false;
            lastTriggerBR = now;
            switchFocusRight();
            cornerTriggered("bottom-right", screenName || "");
            return true;
        } else if (corner === "bottom-left") {
            if (now - lastTriggerBL < cd) return false;
            lastTriggerBL = now;
            switchFocusLeft();
            cornerTriggered("bottom-left", screenName || "");
            return true;
        } else if (corner === "top-right") {
            if (now - lastTriggerTR < cd) return false;
            lastTriggerTR = now;
            centerFocused();
            cornerTriggered("top-right", screenName || "");
            return true;
        } else if (corner === "top-left") {
            if (now - lastTriggerTL < cd) return false;
            lastTriggerTL = now;
            toggleAppSwitcher();
            cornerTriggered("top-left", screenName || "");
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        detectCompositor();
    }
}
