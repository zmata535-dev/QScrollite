import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: selectorWindow

    required property var service

    screen: Quickshell.screens[0]
    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper-picker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
        searchQuery = "";
        searchInput.text = "";
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
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 1000)
        height: Math.min(parent.height - 60, 680)
        color: "#111722"
        radius: 14
        border.color: "#3b4a63"
        border.width: 1

        // Consume clicks inside modal
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰸉"
font.pixelSize: 22
                    color: "#abc7ff"
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Wallpaper Manager"
                    font.pixelSize: 18
color: "#f0f2fa"
                }

                Rectangle {
                    color: "#202436"
                    radius: 10
                    implicitWidth: countLabel.implicitWidth + 16
                    implicitHeight: 24

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: countLabel
                        anchors.centerIn: parent
                        text: service.wallpapers.length + " wallpapers"
                        color: "#8990b3"
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 6
                    color: closeMouse.containsMouse ? "#3b1e28" : "#161d2a"
                    border.color: closeMouse.containsMouse ? "#ff6b81" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? "#ffb3ba" : "#8092ab"
                        font.pixelSize: 13}

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
                spacing: 10

                // Search input
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    color: "#161d2a"
                    radius: 6
                    border.color: searchInput.activeFocus ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰍉"
font.pixelSize: 14
                            color: "#8092ab"
                        }

                        TextInput { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: searchInput
                            Layout.fillWidth: true
                            color: "#dce5f2"
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true
                            onTextChanged: {
                                selectorWindow.searchQuery = text;
                            }

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Filter wallpapers..."
                                color: "#8092ab"
                                font.pixelSize: 13
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        // Clear search button
                        Rectangle {
                            visible: searchInput.text.length > 0
                            implicitWidth: 22
                            implicitHeight: 22
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
                    implicitWidth: 74
                    implicitHeight: 38
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
                    implicitWidth: 74
                    implicitHeight: 38
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
                    implicitWidth: 96
                    implicitHeight: 38
                    radius: 6
                    color: randMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: randMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰒝"
font.pixelSize: 14
                            color: randMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light; text: "Random"; font.pixelSize: 12; color: randMouse.containsMouse ? "#abc7ff" : "#dce5f2" }
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
                    implicitWidth: 125
                    implicitHeight: 38
                    radius: 6
                    color: timerMouse.containsMouse ? "#273650" : (service.slideshowInterval > 0 ? "#22334f" : "#161d2a")
                    border.color: timerMouse.containsMouse ? "#abc7ff" : (service.slideshowInterval > 0 ? "#5476a4" : "#2b364a")
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "󰥔"
font.pixelSize: 13
                            color: service.slideshowInterval > 0 || timerMouse.containsMouse ? "#abc7ff" : "#8092ab"
                        }
                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Timer: " + service.intervalLabel
                            font.pixelSize: 12
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
                    implicitWidth: 40
                    implicitHeight: 38
                    radius: 6
                    color: scanMouse.containsMouse ? "#273650" : "#161d2a"
                    border.color: scanMouse.containsMouse ? "#abc7ff" : "#2b364a"
                    border.width: 1

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                        text: "󰑐"
font.pixelSize: 14
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
                Layout.fillHeight: true

                GridView {
                    id: galleryGrid
                    anchors.fill: parent
                    clip: true
                    cellWidth: 230
                    cellHeight: 165
                    model: selectorWindow.filteredWallpapers

                    delegate: Item {
                        id: cardItem
                        required property var modelData
                        required property int index
                        width: 220
                        height: 155

                        property bool isActive: modelData === service.currentWallpaper

                        Rectangle {
                            id: cardBox
                            anchors.fill: parent
                            radius: 12
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
                                radius: 11

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
                                    height: 38
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#00000000" }
                                        GradientStop { position: 1.0; color: "#ee0c0f18" }
                                    }

                                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: modelData.split('/').pop()
                                        color: "#e2e6f3"
                                        font.pixelSize: 11
                                        elide: Text.ElideMiddle
                                    }
                                }

                                // Active Badge
                                Rectangle {
                                    visible: cardItem.isActive
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    color: "#062646"
                                    radius: 6
                                    border.color: "#abc7ff"
                                    border.width: 1
                                    implicitWidth: activeLabel.implicitWidth + 12
                                    implicitHeight: 20

                                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;id: activeLabel
                                        anchors.centerIn: parent
                                        text: "✓ ACTIVE"
                                        font.pixelSize: 9
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
                            spacing: 10

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.alignment: Qt.AlignHCenter
                                text: "󰍉"
font.pixelSize: 32
                                color: "#545a78"
                            }

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.alignment: Qt.AlignHCenter
                                text: "No wallpapers found matching \"" + selectorWindow.searchQuery + "\""
                                color: "#8990b3"
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            // Footer / Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Active: " + (service.currentWallpaper ? service.currentWallpaper.split('/').pop() : "None")
                    color: "#abc7ff"
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 350
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: "#434966"
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: service.slideshowInterval > 0
                        ? "Slideshow active (every " + service.intervalLabel + ")"
                        : "Slideshow paused"
                    color: "#8990b3"
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "[Esc] Close  •  [← / →] Prev/Next  •  [R] Random  •  [F5] Rescan"
                    color: "#5e668c"
                    font.pixelSize: 11
                }
            }
        }
    }
}
