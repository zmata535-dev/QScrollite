import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "AppSearch.js" as AppSearch
import "Calculator.js" as Calculator

PanelWindow {
    id: root

    required property var service
    screen: Quickshell.screens[0]
    visible: service.appMenuOpen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-app-menu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string filterText: ""
    property bool showAllApps: false
    property int appRevision: 0
    property int selectedIndex: 0
    property var calculation: Calculator.evaluate(filterText)
    property real cardEntranceOffset: -36
    property real cardEntranceOpacity: 0

    ParallelAnimation {
        id: entranceAnimation
        running: true

        NumberAnimation {
            target: root
            property: "cardEntranceOffset"
            from: -36
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "cardEntranceOpacity"
            from: 0
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    FileView {
        id: recentAppsFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/recent-apps.json"
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: recentAppsStore
            property list<string> recentApps: []
        }
    }

    property var matches: {
        appRevision
        service.pinnedApps
        showAllApps
        var values = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values)
            ? DesktopEntries.applications.values : []
        return AppSearch.sortedEntries(values, filterText, function(entry) { return entry.noDisplay === true }, recentAppsStore.recentApps, service.pinnedApps, showAllApps)
    }
    property var menuRows: {
        var rows = []
        if (calculation) rows.push({ isCalculation: true, calculation: calculation })
        for (var i = 0; i < matches.length; i++) rows.push({ isCalculation: false, app: matches[i] })
        return rows
    }

    function iconSource(icon) {
        var value = String(icon || "")
        if (!value) return Quickshell.iconPath("application-x-executable", true)
        // Some desktop-entry sources report the window class instead of the
        // installed icon name for Sakura.
        if (value.toLowerCase() === "sakura") value = "terminal-tango"
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
        if (value.charAt(0) === "/") return "file://" + value
        return Quickshell.iconPath(value, true) || Quickshell.iconPath("application-x-executable", true)
    }

    function closeMenu() {
        searchField.focus = false
        filterText = ""
        selectedIndex = 0
        service.appMenuOpen = false
    }

    onVisibleChanged: {
        if (visible) {
            entranceAnimation.restart()
            Qt.callLater(function() {
                if (root.visible) searchField.forceActiveFocus()
            })
        } else {
            searchField.focus = false
        }
    }

    function runCommand() {
        var command = filterText.trim()
        if (!command) return
        Quickshell.execDetached(["sakura", "--hold", "-e", "bash", "-lc", command])
        closeMenu()
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function markRecentlyOpened(entry) {
        var id = AppSearch.entryId(entry)
        if (!id) return
        var previous = recentAppsStore.recentApps.slice(0)
        var updated = [id]
        for (var i = 0; i < previous.length && updated.length < 12; i++) {
            if (previous[i] !== id) updated.push(previous[i])
        }
        recentAppsStore.recentApps = updated
        appRevision++
    }

    function activate(row) {
        if (!row) return
        if (row.isCalculation && row.calculation) {
            Quickshell.execDetached(["bash", "-c", "printf '%s' " + shellQuote(row.calculation.copyText) + " | wl-copy"])
            closeMenu()
            return
        }
        var entry = row.app && row.app.entry
        if (!entry) return
        var id = AppSearch.entryId(entry)
        if (!id) return
        markRecentlyOpened(entry)
        Quickshell.execDetached(["gtk-launch", id])
        closeMenu()
    }

    function moveSelection(amount) {
        if (menuRows.length === 0) return
        selectedIndex = (selectedIndex + amount + menuRows.length) % menuRows.length
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    onFilterTextChanged: {
        selectedIndex = 0
        if (searchField.text !== filterText) searchField.text = filterText
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() { root.appRevision++ }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#35080c16"

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeMenu()
            }
        }

        GlowBorder {
            targetItem: card
            cornerRadius: card.radius
            offsetY: root.cardEntranceOffset
        }

        Rectangle {
            id: card
            width: Math.min(520, root.width - 32)
            height: Math.min(content.implicitHeight + 32, root.height - 64)
            anchors.centerIn: parent
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
            opacity: root.cardEntranceOpacity
            transform: Translate { y: root.cardEntranceOffset }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Apps"
                        color: "#e2e8f0"
                        font.pixelSize: 18}
                    Item { Layout.fillWidth: true }
                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "Esc to close"
                        color: "#8290a7"
                        font.pixelSize: 11
                    }
                }

                ShellTextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search, calculate (2 + 2), or convert (10 km to mi)…"
                    text: root.filterText
                    selectByMouse: true
                    onTextEdited: root.filterText = text
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            if (root.filterText.length) root.filterText = ""
                            else root.closeMenu()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageDown) {
                            root.moveSelection(8)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp) {
                            root.moveSelection(-8)
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                                   (event.modifiers & Qt.AltModifier)) {
                            root.runCommand()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.matches.length === 0) {
                                root.runCommand()
                            } else if (root.menuRows.length) {
                                root.activate(root.menuRows[root.selectedIndex])
                            }
                            event.accepted = true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ShellButton {
                        Layout.fillWidth: true
                        text: root.showAllApps ? "Show pinned/recent" : "Show all"
                        onClicked: root.showAllApps = !root.showAllApps
                    }

                    ShellButton {
                        text: "Run"
                        accent: true
                        enabled: root.filterText.trim().length > 0
                        onClicked: root.runCommand()
                    }
                }

                ListView {
                    id: resultList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, Math.max(120, root.height * 0.62))
                    clip: true
                    spacing: 4
                    model: root.menuRows
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 54
                        radius: 9
                        color: index === root.selectedIndex ? "#273650" : "transparent"
                        border.color: index === root.selectedIndex ? "#5476a4" : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 12

                            Image {
                                visible: !modelData.isCalculation
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                source: modelData.isCalculation ? "" : root.iconSource(modelData.app.entry.icon)
                                sourceSize.width: 68
                                sourceSize.height: 68
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                                    text: modelData.isCalculation ? "Copy result" : AppSearch.entryName(modelData.app.entry)
                                    color: index === root.selectedIndex ? "#abc7ff" : "#e2e8f0"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                                    text: modelData.isCalculation ? modelData.calculation.value : AppSearch.entrySubtext(modelData.app.entry)
                                    visible: text.length > 0
                                    color: "#8998af"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;text: "↵"
                                color: "#8290a7"
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = index
                            onClicked: root.activate(modelData)
                        }
                    }

                    ScrollBar.vertical: ScrollBar { }
                }

                Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                    visible: root.menuRows.length === 0
                    text: root.filterText.trim().length
                        ? "No applications found"
                        : "No pinned or recent apps. Search to find an application."
                    color: "#8998af"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                }
            }
        }
    }

    Component.onCompleted: {
        if (visible) Qt.callLater(function() { searchField.forceActiveFocus() })
    }
}
