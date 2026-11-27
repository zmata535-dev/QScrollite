import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "PanelPlacement.js" as PanelPlacement

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: service.raisedCardModule === "calendar" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: root.otherComponentOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    readonly property bool otherComponentOpen: service.open || service.appMenuOpen || service.appMenuPending
        || service.gDictCalcOpen || service.qSysMonOpen || service.qNoteOpen || service.clipboardOpen
        || service.bluetoothOpen || service.idleConfigOpen || service.clockOpen || service.compactClockOpen
        || (service.wallpaperService && service.wallpaperService.selectorOpen)
    readonly property bool otherSidePanelOpen: service.appMenuOpen || service.appMenuPending
        || service.gDictCalcOpen || service.qSysMonOpen || service.qNoteOpen
        || service.clipboardOpen || service.bluetoothOpen || service.idleConfigOpen
        || (service.wallpaperService && service.wallpaperService.selectorOpen)
    readonly property real dayCellHeight: Math.max(10, Math.min(30, (root.height - 240) / 6))
    mask: Region { item: card }
    property real cardX: -500
    property real openTargetX: 12

    function positionOppositeFocusedWindow() {
        var totalWidth = card.width
        var preferredX = PanelPlacement.oppositeTargetX(service, root.screen.x,
            root.width, totalWidth, 12)
        if (otherSidePanelOpen) {
            openTargetX = preferredX < root.width / 2
                ? root.width - totalWidth - 12 : 12
        } else {
            openTargetX = preferredX
        }
    }

    function openFromOppositeSide() {
        positionOppositeFocusedWindow()
        cardX = PanelPlacement.leftEntryX(root.screen.x,
            card.width, 12)
        slideIn.to = openTargetX
        slideIn.restart()
    }

    function repositionAfterSwitcher() {
        Qt.callLater(function() {
            if (!root.visible || PanelPlacement.switcherActive(root.service)) return
            root.positionOppositeFocusedWindow()
            slideIn.stop()
            slideIn.to = root.openTargetX
            slideIn.restart()
        })
    }

    onOtherSidePanelOpenChanged: repositionAfterSwitcher()
    Connections {
        target: root.service
        function onActiveWindowIdChanged() {
            root.repositionAfterSwitcher()
        }
        function onOpenChanged() { if (!root.service.open) root.repositionAfterSwitcher() }
        function onAppSwitcherHoveredChanged() {
            if (!root.service.appSwitcherHovered) root.repositionAfterSwitcher()
        }
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "cardX"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }

    property var monthDate: {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), 1)
    }
    property var selectedDate: new Date()
    property var days: []
    readonly property string monthTitle: Qt.formatDate(monthDate, "MMMM yyyy")
    readonly property string selectedDateLabel: Qt.formatDate(selectedDate, "dddd, d MMMM yyyy")

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    function rebuildDays() {
        var first = new Date(monthDate.getFullYear(), monthDate.getMonth(), 1)
        var mondayOffset = (first.getDay() + 6) % 7
        var gridStart = new Date(first.getFullYear(), first.getMonth(), 1 - mondayOffset)
        var today = new Date()
        var values = []

        for (var i = 0; i < 42; i++) {
            var date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i)
            values.push({
                date: date,
                day: date.getDate(),
                inMonth: date.getMonth() === monthDate.getMonth(),
                isToday: sameDay(date, today),
                isSelected: sameDay(date, selectedDate)
            })
        }
        days = values
    }

    function shiftMonth(amount) {
        monthDate = new Date(monthDate.getFullYear(), monthDate.getMonth() + amount, 1)
    }

    function selectDate(day) {
        selectedDate = day.date
        if (!day.inMonth) monthDate = new Date(day.date.getFullYear(), day.date.getMonth(), 1)
        else rebuildDays()
    }

    function closeCalendar() {
        service.closeCalendar()
    }

    onMonthDateChanged: rebuildDays()

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeCalendar()
        Keys.onLeftPressed: root.shiftMonth(-1)
        Keys.onRightPressed: root.shiftMonth(1)

        Rectangle {
            anchors.fill: parent
            color: root.otherComponentOpen ? "transparent" : "#35080c16"
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: Math.min(340, root.width - 32)
            height: Math.min(calendarColumn.implicitHeight + 24, root.height - 32)
            x: root.cardX
            y: (root.height - height) / 2
            clip: true
            radius: 12
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onPressedChanged: {
                    if (pressed) root.service.raiseCardModule("calendar")
                }
            }

            ColumnLayout {
                id: calendarColumn
                z: 1
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 6
                        color: previousMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: previousMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "‹"
                            color: previousMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: root.monthTitle
                        color: "#e2e8f0"
                        font.pixelSize: 15
horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 6
                        color: nextMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: nextMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "›"
                            color: nextMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }

                    ShellButton {
                        focusPolicy: Qt.NoFocus
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        implicitWidth: 26
                        implicitHeight: 26
                        font.pixelSize: 15
                        text: "×"
                        onClicked: root.closeCalendar()
                    }

                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            text: modelData
                            color: "#8290a7"
                            font.pixelSize: 10
horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Repeater {
                        model: root.days

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.dayCellHeight
                            radius: 6
                            color: modelData.isSelected ? "#22334f"
                                : (modelData.isToday ? "#1d2a3e"
                                : (dayMouse.containsMouse ? "#273650" : "transparent"))
                            border.color: modelData.isSelected ? "#abc7ff"
                                : (modelData.isToday ? "#5476a4" : "transparent")
                            border.width: modelData.isToday || modelData.isSelected ? 1 : 0

                            Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                                text: modelData.day
                                color: !modelData.inMonth ? "#526078"
                                    : (modelData.isSelected ? "#ffffff" : "#dce5f2")
                                font.pixelSize: 11}

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectDate(modelData)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light
                        Layout.maximumWidth: 190
                        text: root.selectedDateLabel
                        color: "#94a3b8"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 0

                        Text {
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.weight: Font.Light
                            text: Qt.formatDateTime(root.service.clockNow, "HH")
                            color: "#94a3b8"
                            font.pixelSize: 10
                        }

                        Text {
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.weight: Font.Light
                            text: ":"
                            color: root.service.clockColonVisible ? "#94a3b8" : "#414957"
                            font.pixelSize: 10
                        }

                        Text {
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.weight: Font.Light
                            text: Qt.formatDateTime(root.service.clockNow, "mm")
                            color: "#94a3b8"
                            font.pixelSize: 10
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 48
                        implicitHeight: 24
                        radius: 6
                        color: todayMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: todayMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "Today"
                            color: todayMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 10}

                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var now = new Date()
                                root.selectedDate = now
                                root.monthDate = new Date(now.getFullYear(), now.getMonth(), 1)
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        rebuildDays()
        if (visible) {
            Qt.callLater(function() {
                if (!root.visible) return
                openFromOppositeSide()
            })
        }
    }
}
