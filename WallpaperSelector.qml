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

    color: "#aa080a12"

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

    // Modal Dialog Box
    Rectangle {
        id: modalBox
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 1000)
        height: Math.min(parent.height - 60, 680)
        color: "#141622"
        radius: 18
        border.color: "#282c40"
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

                Text {
                    text: "󰸉"
                    font.family: "MesloLGS Nerd Font"
                    font.pixelSize: 22
                    color: "#abc7ff"
                }

                Text {
                    text: "Wallpaper Manager"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#f0f2fa"
                }

                Rectangle {
                    color: "#202436"
                    radius: 10
                    implicitWidth: countLabel.implicitWidth + 16
                    implicitHeight: 24

                    Text {
                        id: countLabel
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
                    radius: 8
                    color: closeMouse.containsMouse ? "#3b2630" : "#202436"
                    border.color: closeMouse.containsMouse ? "#ffb4ab" : "#2e344a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? "#ffb4ab" : "#8990b3"
                        font.pixelSize: 13
                        font.bold: true
                    }

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
                    color: "#1b1e2c"
                    radius: 10
                    border.color: searchInput.activeFocus ? "#abc7ff" : "#282d40"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "󰍉"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 14
                            color: "#6c7293"
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: "#f0f2fa"
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true
                            onTextChanged: {
                                selectorWindow.searchQuery = text;
                            }

                            Text {
                                text: "Filter wallpapers..."
                                color: "#545a78"
                                font.pixelSize: 13
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        // Clear search button
                        Text {
                            visible: searchInput.text.length > 0
                            text: "✕"
                            color: "#7e85a6"
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
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
                    radius: 10
                    color: prevMouse.containsMouse ? "#2a3048" : "#1f2334"
                    border.color: "#2e344a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "◀"; font.pixelSize: 10; color: "#abc7ff" }
                        Text { text: "Prev"; font.pixelSize: 12; font.bold: true; color: "#e2e6f3" }
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
                    radius: 10
                    color: nextMouse.containsMouse ? "#2a3048" : "#1f2334"
                    border.color: "#2e344a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "Next"; font.pixelSize: 12; font.bold: true; color: "#e2e6f3" }
                        Text { text: "▶"; font.pixelSize: 10; color: "#abc7ff" }
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
                    radius: 10
                    color: randMouse.containsMouse ? "#2a3048" : "#1f2334"
                    border.color: "#2e344a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰒝"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 14
                            color: "#abc7ff"
                        }
                        Text { text: "Random"; font.pixelSize: 12; font.bold: true; color: "#e2e6f3" }
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
                    radius: 10
                    color: timerMouse.containsMouse ? "#2a3048" : (service.slideshowInterval > 0 ? "#0d2b45" : "#1f2334")
                    border.color: service.slideshowInterval > 0 ? "#abc7ff" : "#2e344a"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰥔"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 13
                            color: service.slideshowInterval > 0 ? "#abc7ff" : "#8990b3"
                        }
                        Text {
                            text: "Timer: " + service.intervalLabel
                            font.pixelSize: 12
                            font.bold: true
                            color: service.slideshowInterval > 0 ? "#abc7ff" : "#c5cbe0"
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
                    radius: 10
                    color: scanMouse.containsMouse ? "#2a3048" : "#1f2334"
                    border.color: "#2e344a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "MesloLGS Nerd Font"
                        font.pixelSize: 14
                        color: "#abc7ff"
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
                            border.color: cardItem.isActive ? "#abc7ff" : (cardMouse.containsMouse ? "#4e577d" : "#262b3d")
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

                                    Text {
                                        anchors.bottom: parent.bottom
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

                                    Text {
                                        id: activeLabel
                                        anchors.centerIn: parent
                                        text: "✓ ACTIVE"
                                        font.pixelSize: 9
                                        font.bold: true
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

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰍉"
                                font.family: "MesloLGS Nerd Font"
                                font.pixelSize: 32
                                color: "#545a78"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
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

                Text {
                    text: "Active: " + (service.currentWallpaper ? service.currentWallpaper.split('/').pop() : "None")
                    color: "#abc7ff"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 350
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: "#434966"
                }

                Text {
                    text: service.slideshowInterval > 0
                        ? "Slideshow active (every " + service.intervalLabel + ")"
                        : "Slideshow paused"
                    color: "#8990b3"
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "[Esc] Close  •  [← / →] Prev/Next  •  [R] Random  •  [F5] Rescan"
                    color: "#5e668c"
                    font.pixelSize: 11
                }
            }
        }
    }
}
