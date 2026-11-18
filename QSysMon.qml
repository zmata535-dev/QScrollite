import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "PanelPlacement.js" as PanelPlacement

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: service.qSysMonOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: service.raisedCardModule === "sysmon" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-qsysmon"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: card }
    property real cardX: 0
    property real openTargetX: 0

    function positionOppositeFocusedWindow() {
        openTargetX = PanelPlacement.oppositeTargetX(service, root.screen.x, root.width, card.width, 16)
    }

    function openFromOppositeSide() {
        positionOppositeFocusedWindow()
        cardX = PanelPlacement.entryX(openTargetX, root.width, card.width, root.screen.x, 16)
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
        to: root.openTargetX
        duration: 300
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: openFromOppositeSide()

    property real cpuPercent: 0
    property real memoryPercent: 0
    property real diskPercent: 0
    property string memorySummary: "Reading memory…"
    property string diskSummary: "Reading storage…"
    property string wifiSummary: "Searching for wireless interface…"
    property string previousWifiIface: ""
    property string wifiInterface: ""
    property var temperatures: []
    property var cpuHistory: []
    property var memoryHistory: []
    property var diskHistory: []
    property var wifiRxHistory: []
    property var wifiTxHistory: []
    property real previousCpuTotal: 0
    property real previousCpuIdle: 0
    property real previousWifiRx: -1
    property real previousWifiTx: -1

    function close() {
        service.qSysMonOpen = false
    }

    function appendSample(history, value) {
        var next = history.slice(-59)
        next.push(Math.max(0, Math.min(100, value)))
        return next
    }

    function appendRateSample(history, value) {
        var next = history.slice(-59)
        next.push(Math.max(0, value))
        return next
    }

    function formatGiB(kib) {
        return (Number(kib) / 1048576).toFixed(1) + " GiB"
    }

    function friendlyTemperatureName(sensor, label) {
        var source = sensor.toLowerCase()
        if (source === "coretemp") {
            if (label.indexOf("Package") === 0) return "CPU Package"
            var core = label.match(/Core\s+(\d+)/)
            if (core) return "CPU Core " + core[1]
            return "CPU " + label
        }
        if (source === "acpitz") {
            var zone = label.match(/(\d+)/)
            return "ACPI Zone " + (zone ? zone[1] : "")
        }
        if (source.indexOf("pch") >= 0) return "PCH Chipset"
        if (source === "asus") return "Motherboard"
        var friendlySource = sensor.replace(/_/g, " ").replace(/\b\w/g, function(ch) { return ch.toUpperCase() })
        var friendlyLabel = label.replace(/^temp/i, "Sensor ")
        return friendlySource + " · " + friendlyLabel
    }

    function drawGraph(canvas, samples, color) {
        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        if (samples.length < 2) return
        ctx.beginPath()
        ctx.lineWidth = 0.5
        ctx.strokeStyle = color
        for (var i = 0; i < samples.length; i++) {
            var x = i * canvas.width / (samples.length - 1)
            var y = canvas.height - (samples[i] / 100) * (canvas.height - 4) - 2
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }

    function drawWifiGraph(canvas) {
        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        var maxRate = 1
        for (var i = 0; i < root.wifiRxHistory.length; i++)
            maxRate = Math.max(maxRate, root.wifiRxHistory[i], root.wifiTxHistory[i] || 0)
        function drawSeries(samples, color) {
            if (samples.length < 2) return
            ctx.beginPath()
            ctx.lineWidth = 0.5
            ctx.strokeStyle = color
            for (var j = 0; j < samples.length; j++) {
                var x = j * canvas.width / (samples.length - 1)
                var y = canvas.height - (samples[j] / maxRate) * (canvas.height - 4) - 2
                if (j === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
        drawSeries(root.wifiRxHistory, "#8db8ff")
        drawSeries(root.wifiTxHistory, "#70d4c4")
    }

    function formatRate(kibPerSecond) {
        if (kibPerSecond >= 1024) return (kibPerSecond / 1024).toFixed(1) + " MiB/s"
        return kibPerSecond.toFixed(0) + " KiB/s"
    }

    Process {
        id: sampleProcess
        command: ["bash", "-c", "head -n 1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -Pk /; for d in /sys/class/hwmon/hwmon*/temp*_input; do [ -r \"$d\" ] || continue; h=\"${d%/temp*_input}\"; b=\"${d%_input}\"; n=$(cat \"$h/name\" 2>/dev/null); l=$(cat \"${b}_label\" 2>/dev/null); [ -n \"$l\" ] || l=$(basename \"$b\"); v=$(cat \"$d\"); printf 'TEMP|%s|%s|%s\\n' \"$n\" \"$l\" \"$v\"; done; for d in /sys/class/net/*/wireless; do [ -d \"$d\" ] || continue; i=\"${d%/wireless}\"; i=\"${i##*/}\"; rx=$(cat \"/sys/class/net/$i/statistics/rx_bytes\" 2>/dev/null); tx=$(cat \"/sys/class/net/$i/statistics/tx_bytes\" 2>/dev/null); q=$(awk -v dev=\"$i:\" '$1 == dev {printf \"%d\", $3 / 70 * 100}' /proc/net/wireless); state=$(cat \"/sys/class/net/$i/operstate\" 2>/dev/null); printf 'WIFI|%s|%s|%s|%s|%s\\n' \"$i\" \"$rx\" \"$tx\" \"$q\" \"$state\"; done"]
        running: false
        stdout: StdioCollector { id: sampleOutput }
        onExited: function(exitCode) {
            if (exitCode !== 0) return
            var lines = sampleOutput.text.trim().split("\n")
            if (lines.length < 5) return

            var cpu = lines[0].trim().split(/\s+/).slice(1).map(Number)
            var total = cpu.reduce(function(sum, part) { return sum + part }, 0)
            var idle = (cpu[3] || 0) + (cpu[4] || 0)
            if (root.previousCpuTotal > 0 && total > root.previousCpuTotal) {
                var totalDelta = total - root.previousCpuTotal
                var idleDelta = idle - root.previousCpuIdle
                root.cpuPercent = Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100))
                root.cpuHistory = root.appendSample(root.cpuHistory, root.cpuPercent)
            }
            root.previousCpuTotal = total
            root.previousCpuIdle = idle

            var memTotal = Number(lines[1].match(/\d+/)[0])
            var memAvailable = Number(lines[2].match(/\d+/)[0])
            if (memTotal > 0) {
                var memUsed = memTotal - memAvailable
                root.memoryPercent = memUsed * 100 / memTotal
                root.memorySummary = root.formatGiB(memUsed) + " / " + root.formatGiB(memTotal)
                root.memoryHistory = root.appendSample(root.memoryHistory, root.memoryPercent)
            }

            var disk = lines[4].trim().split(/\s+/)
            if (disk.length >= 5) {
                root.diskPercent = Number(disk[4].replace("%", "")) || 0
                root.diskSummary = root.formatGiB(disk[2]) + " / " + root.formatGiB(disk[1])
                root.diskHistory = root.appendSample(root.diskHistory, root.diskPercent)
            }

            var tempList = []
            var foundWifi = false
            for (var lineIndex = 5; lineIndex < lines.length; lineIndex++) {
                var fields = lines[lineIndex].split("|")
                if (fields[0] === "TEMP" && fields.length >= 4) {
                    var temperature = Number(fields[3]) / 1000
                    if (isFinite(temperature) && temperature > -40 && temperature < 150)
                        tempList.push({ name: root.friendlyTemperatureName(fields[1], fields[2]), value: temperature.toFixed(1) + " °C" })
                } else if (fields[0] === "WIFI" && fields.length >= 6) {
                    foundWifi = true
                    var iface = fields[1]
                    var rxBytes = Number(fields[2])
                    var txBytes = Number(fields[3])
                    var quality = Number(fields[4])
                    var state = fields[5] || "unknown"
                    root.wifiInterface = iface
                    if (root.previousWifiIface === iface && root.previousWifiRx >= 0 && rxBytes >= root.previousWifiRx) {
                        root.wifiRxHistory = root.appendRateSample(root.wifiRxHistory, (rxBytes - root.previousWifiRx) / 1024)
                        root.wifiTxHistory = root.appendRateSample(root.wifiTxHistory, (txBytes - root.previousWifiTx) / 1024)
                    } else {
                        root.wifiRxHistory = []
                        root.wifiTxHistory = []
                    }
                    root.previousWifiIface = iface
                    root.previousWifiRx = rxBytes
                    root.previousWifiTx = txBytes
                    root.wifiSummary = iface + " · " + state + " · signal " + (isFinite(quality) ? quality : 0) + "%"
                }
            }
            root.temperatures = tempList
            if (!foundWifi) {
                root.wifiInterface = ""
                root.wifiSummary = "No wireless interface detected"
                root.previousWifiIface = ""
                root.previousWifiRx = -1
                root.previousWifiTx = -1
                root.wifiRxHistory = []
                root.wifiTxHistory = []
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && !sampleProcess.running
        onTriggered: sampleProcess.running = true
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: card
            width: Math.min(372, root.width - 32)
            height: Math.min(content.implicitHeight + 32, root.height - 64)
            x: root.cardX
            y: (parent.height - height) / 2
            opacity: 0.69
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1
            MouseArea {
                anchors.fill: parent
                onPressed: root.service.raiseCardModule("sysmon")
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onPressedChanged: {
                    if (pressed) root.service.raiseCardModule("sysmon")
                }
            }

            ColumnLayout {
                z: 1
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "QSysMon"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }
                    Item { Layout.fillWidth: true }
                    ShellButton { text: "×"; onClicked: root.close() }
                }

                Repeater {
                    model: [
                        { name: "CPU", value: root.cpuPercent.toFixed(1) + "%", samples: root.cpuHistory, tint: "#8db8ff" },
                        { name: "Memory", value: root.memorySummary + "  ·  " + root.memoryPercent.toFixed(1) + "%", samples: root.memoryHistory, tint: "#a8d5a2" },
                        { name: "Disk / Storage", value: root.diskSummary + "  ·  " + root.diskPercent.toFixed(1) + "%", samples: root.diskHistory, tint: "#e2c17b" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 8
                        color: "#161d2a"
                        border.color: "#2b364a"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            ColumnLayout {
                                Layout.preferredWidth: 145
                                spacing: 5
                                Text {
                                    text: modelData.name
                                    color: modelData.tint
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: modelData.value
                                    color: "#dce5f2"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Canvas {
                                id: graph
                                property var samples: modelData.samples
                                property color lineColor: modelData.tint
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 42
                                Layout.alignment: Qt.AlignVCenter
                                onSamplesChanged: requestPaint()
                                onLineColorChanged: requestPaint()
                                onPaint: root.drawGraph(graph, samples, lineColor)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    radius: 8
                    color: "#161d2a"
                    border.color: "#2b364a"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14
                        ColumnLayout {
                            Layout.preferredWidth: 145
                            spacing: 5
                            Text { text: "Wireless Network"; color: "#70d4c4"; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13 }
                            Text {
                                text: root.wifiInterface.length > 0
                                    ? root.wifiSummary + "\n↓ " + root.formatRate(root.wifiRxHistory.length ? root.wifiRxHistory[root.wifiRxHistory.length - 1] : 0)
                                        + "   ↑ " + root.formatRate(root.wifiTxHistory.length ? root.wifiTxHistory[root.wifiTxHistory.length - 1] : 0)
                                    : root.wifiSummary
                                color: "#dce5f2"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Canvas {
                            id: wifiGraph
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            onPaint: root.drawWifiGraph(wifiGraph)
                            Connections {
                                target: root
                                function onWifiRxHistoryChanged() { wifiGraph.requestPaint() }
                                function onWifiTxHistoryChanged() { wifiGraph.requestPaint() }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: root.temperatures.length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: "Temperature sensors"
                        color: "#c4ccda"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 12
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: root.temperatures
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: 6
                                color: "#161d2a"
                                border.color: "#2b364a"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: "#94a3b8"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.value
                                        color: "#f0dd89"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
