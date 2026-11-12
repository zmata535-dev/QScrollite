import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool pairedWithNotifications: service.notificationService
        ? service.notificationService.notificationCenterOpen : false
    readonly property real pairedCalendarWidth: Math.min(388, (root.width - 48) * 0.38)
    readonly property real pairedNotificationWidth: Math.min(560, (root.width - 48) * 0.56)
    property var pairedInputRegion: Region { item: card }
    mask: pairedWithNotifications ? pairedInputRegion : null

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
        var closePairedCenter = pairedWithNotifications
        service.calendarOpen = false
        if (closePairedCenter && service.notificationService)
            service.notificationService.closeCenter()
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
            color: root.pairedWithNotifications ? "transparent" : "#35080c16"

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeCalendar()
            }
        }

        GlowBorder { targetItem: card; cornerRadius: card.radius }

        Rectangle {
            id: card
            width: root.pairedWithNotifications
                ? root.pairedCalendarWidth : Math.min(388, root.width - 32)
            height: calendarColumn.implicitHeight + 36
            x: root.pairedWithNotifications
                ? (root.width - root.pairedCalendarWidth - 14 - root.pairedNotificationWidth) / 2
                : (root.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: calendarColumn
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 6
                        color: previousMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: previousMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "‹"
                            color: previousMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 22
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
                        font.pixelSize: 18
horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 6
                        color: nextMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: nextMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "›"
                            color: nextMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
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
                            Layout.preferredHeight: 38
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
                                font.pixelSize: 12}

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
                    spacing: 8

                    Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;Layout.fillWidth: true
                        text: root.selectedDateLabel
                        color: "#94a3b8"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: 54
                        implicitHeight: 28
                        radius: 6
                        color: todayMouse.containsMouse ? "#273650" : "#161d2a"
                        border.color: todayMouse.containsMouse ? "#abc7ff" : "#2b364a"

                        Text { font.family: "JetBrainsMono Nerd Font Mono"; font.weight: Font.Light;anchors.centerIn: parent
                            text: "Today"
                            color: todayMouse.containsMouse ? "#abc7ff" : "#8092ab"
                            font.pixelSize: 11}

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
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
}
