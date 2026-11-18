import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "PanelPlacement.js" as PanelPlacement

PanelWindow {
    id: selectorWindow

    required property var service
    required property var switcherService

    screen: Quickshell.screens[0]
    visible: service.selectorOpen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: switcherService.raisedCardModule === "wallpaper" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-wallpaper-picker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    property real cardX: -1000
    property real openTargetX: 12

    function positionOppositeFocusedWindow() {
        openTargetX = PanelPlacement.oppositeTargetX(switcherService, selectorWindow.screen.x,
            selectorWindow.width, modalBox.width, 12)
    }

    function openFromOppositeSide() {
        positionOppositeFocusedWindow()
        cardX = PanelPlacement.entryX(openTargetX, selectorWindow.width, modalBox.width,
            selectorWindow.screen.x, 12)
        slideIn.to = openTargetX
        slideIn.restart()
    }

    function repositionAfterSwitcher() {
        Qt.callLater(function() {
            if (!selectorWindow.visible || PanelPlacement.switcherActive(switcherService)) return
            selectorWindow.positionOppositeFocusedWindow()
            slideIn.stop()
            slideIn.to = selectorWindow.openTargetX
            slideIn.restart()
        })
    }

    NumberAnimation {
        id: slideIn
        target: selectorWindow
        property: "cardX"
        to: selectorWindow.openTargetX
        duration: 300
        easing.type: Easing.OutCubic
    }

    Connections {
        target: switcherService
        function onActiveWindowIdChanged() {
            selectorWindow.repositionAfterSwitcher()
        }
        function onOpenChanged() { if (!switcherService.open) selectorWindow.repositionAfterSwitcher() }
        function onAppSwitcherHoveredChanged() {
            if (!switcherService.appSwitcherHovered) selectorWindow.repositionAfterSwitcher()
        }
    }

    color: "#35080c16"

    property string searchQuery: ""

    property var filteredWallpapers: {
        if (!searchQuery || searchQuery.trim() === "") {
            return service.wallpapers;
        }
        var q = searchQuery.toLowerCase().trim();
        return service.wallpapers.filter(function(path) {
            var name = path.split('/').pop().toLowerCase();
            return name.indexOf(q) !== -1 || path.toLowerCase().indexOf(q) !== -1;
        });
    }

    // Keyboard shortcuts
    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            service.closeSelector();
        }

        Keys.onReturnPressed: {
            service.closeSelector();
        }

        Keys.onEnterPressed: {
            service.closeSelector();
        }

        Keys.onLeftPressed: {
            service.prev();
        }

        Keys.onRightPressed: {
            service.next();
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_R && !searchInput.activeFocus) {
                service.random();
                event.accepted = true;
            } else if (event.key === Qt.Key_F5) {
                service.scan();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: {
        switcherService.raiseCardModule("wallpaper")
        searchQuery = "";
        searchInput.text = "";
        openFromOppositeSide()
        searchInput.forceActiveFocus();
    }

    // Backdrop click dismisses modal
    MouseArea {
        anchors.fill: parent
        onClicked: {
            service.closeSelector();
        }
    }

    GlowBorder { targetItem: modalBox; cornerRadius: modalBox.radius; spread: 5 }

    // Modal Dialog Box
    Rectangle {
        id: modalBox
        x: selectorWindow.cardX
        y: (parent.height - height) / 2
        width: Math.min(parent.width - 40, 860)
        height: Math.min(parent.height - 40, 440)
        color: "#111722"
        radius: 14
        border.color: "#3b4a63"
        border.width: 1

        // Consume clicks inside modal
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            z: 1
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰸉"
font.pixelSize: 18
                    color: "#abc7ff"
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Wallpaper Manager"
                    font.pixelSize: 15
color: "#f0f2fa"
                }

                Rectangle {
                    color: "#202436"
                    radius: 10
                    implicitWidth: countLabel.implicitWidth + 12
                    implicitHeight: 20

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: countLabel
                        anchors.centerIn: parent
                        text: service.wallpapers.length + " wallpapers"
                        color: "#8990b3"
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 6
                    color: closeMouse.containsMouse ? "#3b1e28" : "#161d2a"
                    border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                        font.pixelSize: 11}

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.closeSelector()
                    }
                }
            }

            // Toolbar Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Search input
                Rectangle {
                    Layout.preferredWidth: Math.max(150, Math.round((modalBox.width - 28) * 0.3))
                    Layout.minimumWidth: 150
                    implicitHeight: 32
                    color: "#161d2a"
                    radius: 6
                    border.color: searchInput.activeFocus ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 8
                        spacing: 6

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰍉"
font.pixelSize: 12
                            color: "#8092ab"
                        }

                        TextInput { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: searchInput
                            Layout.fillWidth: true
                            color: "#dce5f2"
                            font.pixelSize: 11
                            clip: true
                            selectByMouse: true
                            Keys.onEscapePressed: function(event) {
                                service.closeSelector();
                                event.accepted = true;
                            }
                            onTextChanged: {
                                selectorWindow.searchQuery = text;
                            }

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Filter wallpapers..."
                                color: "#8092ab"
                                font.pixelSize: 11
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        // Clear search button
                        Rectangle {
                            visible: searchInput.text.length > 0
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 6
                            color: clearSearchMouse.containsMouse ? "#273650" : "#161d2a"
                            border.color: clearSearchMouse.containsMouse ? "#abc7ff" : "#2b364a"
                            border.width: 1

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                text: "✕"
                                color: clearSearchMouse.containsMouse ? "#abc7ff" : "#8092ab"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: clearSearchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }

                // Prev Button
                Rectangle {
                    implicitWidth: 62
                    implicitHeight: 32
                    radius: 6
                    color: prevMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: prevMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "◀"; font.pixelSize: 10; color: prevMouse.containsMouse ? "#abc7ff" : "#8092ab" }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Prev"; font.pixelSize: 12; color: prevMouse.containsMouse ? "#abc7ff" : "#dce5f2" }
                    }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.prev()
                    }
                }

                // Next Button
                Rectangle {
                    implicitWidth: 62
                    implicitHeight: 32
                    radius: 6
                    color: nextMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: nextMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Next"; font.pixelSize: 12; color: nextMouse.containsMouse ? "#abc7ff" : "#dce5f2" }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "▶"; font.pixelSize: 10; color: nextMouse.containsMouse ? "#abc7ff" : "#8092ab" }
                    }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.next()
                    }
                }

                // Random Shuffle Button
                Rectangle {
                    implicitWidth: 82
                    implicitHeight: 32
                    radius: 6
                    color: randMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: randMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰒝"
font.pixelSize: 12
                            color: randMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Random"; font.pixelSize: 11; color: randMouse.containsMouse ? "#abc7ff" : "#dce5f2" }
                    }
                    MouseArea {
                        id: randMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.random()
                    }
                }

                // Slideshow Cycle Button
                Rectangle {
                    implicitWidth: 106
                    implicitHeight: 32
                    radius: 6
                    color: timerMouse.containsMouse ? "#273650" : (service.slideshowInterval > 0 ? "#22334f" : "#161d2a")
                    border.color: timerMouse.containsMouse ? "#abc7ff" : (service.slideshowInterval > 0 ? "#5476a4" : "#2b364a")
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰥔"
font.pixelSize: 11
                            color: service.slideshowInterval > 0 || timerMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Timer: " + service.intervalLabel
                            font.pixelSize: 11
color: service.slideshowInterval > 0 || timerMouse.containsMouse ? "#abc7ff" : "#dce5f2"
                        }
                    }
                    MouseArea {
                        id: timerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.cycleInterval()
                    }
                }

                // Rescan Button
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 32
                    radius: 6
                    color: scanMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: scanMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "󰑐"
font.pixelSize: 12
                        color: scanMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        rotation: service.isScanning ? 360 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: 500 }
                        }
                    }
                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: service.scan()
                    }
                }
            }

            // Gallery Grid
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 284
                Layout.minimumHeight: 284
                Layout.maximumHeight: 284

                GridView {
                    id: galleryGrid
                    anchors.fill: parent
                    clip: true
                    flow: GridView.TopToBottom
                    flickableDirection: Flickable.HorizontalFlick
                    cellWidth: 194
                    cellHeight: 142
                    model: selectorWindow.filteredWallpapers
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        id: cardItem
                        required property var modelData
                        required property int index
                        width: 184
                        height: 132

                        property bool isActive: modelData === service.currentWallpaper

                        Rectangle {
                            id: cardBox
                            anchors.fill: parent
                            radius: 9
                            color: "#181b29"
                            border.color: cardItem.isActive || cardMouse.containsMouse ? "#abc7ff" : "#2b364a"
                            border.width: cardItem.isActive ? 2 : 1

                            scale: cardMouse.containsMouse ? 1.02 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: cardBox.border.width
                                radius: 8

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }

                                // Bottom dark gradient overlay for filename
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 30
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#00000000" }
                                        GradientStop { position: 1.0; color: "#ee0c0f18" }
                                    }

                                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        text: modelData.split('/').pop()
                                        color: "#e2e6f3"
                                        font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                }

                                // Active Badge
                                Rectangle {
                                    visible: cardItem.isActive
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    color: "#062646"
                                    radius: 6
                                    border.color: "#abc7ff"
                                    border.width: 1
                                    implicitWidth: activeLabel.implicitWidth + 12
                                    implicitHeight: 18

                                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: activeLabel
                                        anchors.centerIn: parent
                                        text: "✓ ACTIVE"
                                        font.pixelSize: 8
color: "#abc7ff"
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    service.setWallpaper(modelData);
                                }
                                onDoubleClicked: {
                                    service.setWallpaper(modelData);
                                    service.closeSelector();
                                }
                            }
                        }
                    }

                    // Empty state when filter matches nothing
                    Item {
                        anchors.fill: parent
                        visible: selectorWindow.filteredWallpapers.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.alignment: Qt.AlignHCenter
                                text: "󰍉"
font.pixelSize: 26
                                color: "#545a78"
                            }

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.alignment: Qt.AlignHCenter
                                text: "No wallpapers found matching \"" + selectorWindow.searchQuery + "\""
                                color: "#8990b3"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // Footer / Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: service.slideshowInterval > 0
                        ? "Slideshow active (every " + service.intervalLabel + ")"
                        : "Slideshow paused"
                    color: "#8990b3"
                    font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "[Esc] Close  •  [← / →] Prev/Next  •  [R] Random  •  [F5] Rescan"
                    color: "#5e668c"
                    font.pixelSize: 9
                }
            }
        }
    }
}
