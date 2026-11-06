import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    property var service

    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "#0a0c14"

    Item {
        id: crossfadeContainer
        anchors.fill: parent

        property bool showingFirst: true
        property string targetUrl: ""

        property string activeWallpaper: window.service ? window.service.currentWallpaper : ""
        onActiveWallpaperChanged: {
            applyWallpaper(activeWallpaper);
        }

        Image {
            id: img1
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: 1

            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.InOutCubic }
            }

            onStatusChanged: {
                if (status === Image.Ready && !crossfadeContainer.showingFirst && source == crossfadeContainer.targetUrl) {
                    img1.opacity = 1;
                    img2.opacity = 0;
                    crossfadeContainer.showingFirst = true;
                }
            }
        }

        Image {
            id: img2
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: 0

            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.InOutCubic }
            }

            onStatusChanged: {
                if (status === Image.Ready && crossfadeContainer.showingFirst && source == crossfadeContainer.targetUrl) {
                    img2.opacity = 1;
                    img1.opacity = 0;
                    crossfadeContainer.showingFirst = false;
                }
            }
        }

        function applyWallpaper(path) {
            if (!path) return;
            var url = path.startsWith("file://") ? path : "file://" + path;
            if (url === targetUrl) return;
            targetUrl = url;

            if (showingFirst) {
                img2.source = url;
                if (img2.status === Image.Ready) {
                    img2.opacity = 1;
                    img1.opacity = 0;
                    showingFirst = false;
                }
            } else {
                img1.source = url;
                if (img1.status === Image.Ready) {
                    img1.opacity = 1;
                    img2.opacity = 0;
                    showingFirst = true;
                }
            }
        }

        Component.onCompleted: {
            if (activeWallpaper) {
                applyWallpaper(activeWallpaper);
            }
        }
    }
}
