import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "GDictCalc.js" as Scientific

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: service.gDictCalcOpen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-gdictcalc"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool dictionaryMode: false
    property string expression: String(service.gDictCalcInitialQuery || "")
    property string query: String(service.gDictCalcInitialQuery || "")
    property string statusText: ""
    property string lastGoogleQuery: ""
    property string lastGoogleUrl: ""
    property string googleResultTitle: ""
    property string googleResultText: ""
    property bool searching: false
    property int googleSearchGeneration: 0
    readonly property string calculationResult: {
        var result = Scientific.evaluate(expression)
        return result ? result.value : ""
    }
    readonly property var languages: [
        "English", "Indonesian", "Spanish", "French", "German", "Italian",
        "Portuguese", "Japanese", "Korean", "Chinese (Simplified)", "Arabic",
        "Russian", "Hindi", "Dutch", "Turkish", "Vietnamese", "Thai",
        "Polish", "Swedish", "Greek", "Hebrew", "Ukrainian", "Bengali",
        "Malay", "Filipino"
    ]
    readonly property var targetOptions: {
        switch (convertCategory.currentIndex) {
        case 1: return ["meters", "kilometers", "miles", "feet", "inches"]
        case 2: return ["kilograms", "grams", "pounds", "ounces", "tons"]
        case 3: return ["bytes", "kilobytes", "megabytes", "gigabytes", "terabytes", "bits", "kilobits", "megabits", "gigabits", "terabits"]
        case 4: return []
        default: return ["USD", "EUR", "JPY", "GBP", "CNY", "AUD", "CAD", "CHF", "INR", "IDR"]
        }
    }

    Process {
        id: googleSearchProcess
        property int requestGeneration: 0
        command: {
            var configHome = Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")
            return ["python3", configHome + "/quickshell/GoogleSearch.py", root.lastGoogleQuery]
        }
        running: false

        stdout: StdioCollector { id: googleSearchOutput }
        stderr: StdioCollector { id: googleSearchError }

        onExited: function(exitCode, exitStatus) {
            root.searching = false
            if (requestGeneration !== root.googleSearchGeneration) return
            if (exitCode !== 0) {
                root.statusText = "Google search couldn't be fetched."
                root.googleResultTitle = ""
                root.googleResultText = googleSearchError.text.trim() || "Check that curl and network access are available."
                return
            }
            try {
                var response = JSON.parse(googleSearchOutput.text.trim())
                if (response.ok) {
                    root.statusText = ""
                    root.googleResultTitle = response.title || "Google answer"
                    root.googleResultText = response.text || "Google returned an empty answer."
                } else {
                    root.statusText = response.message || "Google did not return a readable answer to curl."
                    root.googleResultTitle = ""
                    root.googleResultText = response.text || ""
                }
            } catch (e) {
                root.statusText = "Google returned a response that couldn't be read."
                root.googleResultTitle = ""
                root.googleResultText = "Open the Google search to view its response."
            }
        }
    }

    function close() {
        service.gDictCalcOpen = false
    }

    function handleShortcut(event) {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
            root.dictionaryMode = true
            root.statusText = ""
            Qt.callLater(function() { queryField.forceActiveFocus() })
            event.accepted = true
        }
    }

    function insertToken(token) {
        var start = calcField.selectionStart
        var end = calcField.selectionEnd
        if (start < 0 || end < 0) start = end = calcField.cursorPosition
        expression = expression.slice(0, start) + token + expression.slice(end)
        Qt.callLater(function() {
            calcField.forceActiveFocus()
            calcField.cursorPosition = start + token.length
        })
    }

    function copyCalculation() {
        if (!calculationResult) return
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "gdictcalc-copy", calculationResult])
    }

    function calculate() {
        if (!calculationResult) return
        expression = calculationResult
        Qt.callLater(function() {
            calcField.forceActiveFocus()
            calcField.cursorPosition = calcField.text.length
        })
    }

    function searchGoogle(kind) {
        if (googleSearchProcess.running) {
            statusText = "Wait for the current Google search to finish."
            return
        }
        var value = query.trim()
        if (!value) {
            statusText = "Enter a word or value to search."
            return
        }

        var text = value
        if (kind === "translate") text = value + " in " + languageSelect.currentText
        else if (kind === "convert") {
            var target = convertCategory.currentIndex === 4
                ? customTarget.text.trim() : targetSelect.currentText
            if (!target) {
                statusText = "Enter a custom unit, currency, or target."
                return
            }
            text = "convert " + value + " to " + target
        }
        else if (kind === "price") text = value + " current price"

        lastGoogleQuery = text
        lastGoogleUrl = "https://www.google.com/search?q=" + encodeURIComponent(text).replace(/%20/g, "+")
        googleSearchGeneration++
        googleSearchProcess.requestGeneration = googleSearchGeneration
        googleResultTitle = ""
        googleResultText = ""
        statusText = "Fetching Google's answer…"
        searching = true
        googleSearchProcess.running = false
        Qt.callLater(function() {
            if (root.visible && googleSearchGeneration === googleSearchProcess.requestGeneration)
                googleSearchProcess.running = true
        })
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (root.visible) {
                if (root.dictionaryMode) queryField.forceActiveFocus()
                else calcField.forceActiveFocus()
            }
        })
    }

    onVisibleChanged: {
        if (visible) Qt.callLater(function() {
            if (root.dictionaryMode) queryField.forceActiveFocus()
            else calcField.forceActiveFocus()
        })
    }

    Item {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
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

                    Text {
                        text: root.dictionaryMode ? "Google Dictionary" : "GDictCalc · Scientific"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }

                    Item { Layout.fillWidth: true }

                    ShellButton {
                        text: root.dictionaryMode ? "← Calculator" : "Dictionary →"
                        onClicked: {
                            root.dictionaryMode = !root.dictionaryMode
                            root.statusText = ""
                            Qt.callLater(function() {
                                if (root.dictionaryMode) queryField.forceActiveFocus()
                                else calcField.forceActiveFocus()
                            })
                        }
                    }

                    ShellButton {
                        text: "×"
                        onClicked: root.close()
                    }
                }

                ColumnLayout {
                    visible: !root.dictionaryMode
                    Layout.fillWidth: true
                    spacing: 8

                    ShellTextField {
                        id: calcField
                        Layout.fillWidth: true
                        placeholderText: "Scientific expression · sin(30), sqrt(2), pi^2"
                        text: root.expression
                        selectByMouse: true
                        onTextEdited: root.expression = text
                        onAccepted: root.calculate()
                        Keys.onPressed: function(event) { root.handleShortcut(event) }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 7
                        color: "#161d2a"
                        border.color: "#2b364a"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.calculationResult || (root.expression.length ? "Invalid expression" : "Enter an expression")
                                color: root.calculationResult ? "#abc7ff" : "#8092ab"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }

                            ShellButton {
                                text: "Copy"
                                enabled: !!root.calculationResult
                                onClicked: root.copyCalculation()
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 5
                        columnSpacing: 5

                        Repeater {
                            model: [
                                "sin(", "cos(", "tan(", "sqrt(",
                                "ln(", "log(", "asin(", "acos(",
                                "7", "8", "9", "/",
                                "4", "5", "6", "*",
                                "1", "2", "3", "-",
                                "0", ".", "pi", "+",
                                "(", ")", "!", "^",
                                "C", "⌫", "e", "="
                            ]

                            delegate: ShellButton {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                accent: modelData === "="
                                onClicked: {
                                    if (modelData === "C") root.expression = ""
                                    else if (modelData === "⌫") root.expression = root.expression.slice(0, -1)
                                    else if (modelData === "=") root.calculate()
                                    else root.insertToken(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Trig functions use degrees · ^ for powers · ! for factorial"
                        color: "#8290a7"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ColumnLayout {
                    visible: root.dictionaryMode
                    Layout.fillWidth: true
                    spacing: 10

                    ShellTextField {
                        id: queryField
                        Layout.fillWidth: true
                        placeholderText: "Word, amount, currency, or product"
                        text: root.query
                        selectByMouse: true
                        onTextEdited: root.query = text
                        onAccepted: root.searchGoogle("translate")
                        Keys.onPressed: function(event) { root.handleShortcut(event) }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Translate to"; color: "#94a3b8"; font.pixelSize: 11 }
                        ShellComboBox {
                            id: languageSelect
                            Layout.fillWidth: true
                            model: root.languages
                            currentIndex: 0
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: true
                        Text { text: "Convert"; color: "#94a3b8"; font.pixelSize: 11 }
                        ShellComboBox {
                            id: convertCategory
                            Layout.preferredWidth: 125
                            model: ["Currencies", "Length", "Weight", "Tech units", "Custom"]
                            onActivated: targetSelect.currentIndex = 0
                        }
                        ShellComboBox {
                            id: targetSelect
                            Layout.fillWidth: true
                            visible: convertCategory.currentIndex !== 4
                            model: root.targetOptions
                            currentIndex: 0
                        }
                        ShellTextField {
                            id: customTarget
                            Layout.fillWidth: true
                            visible: convertCategory.currentIndex === 4
                            placeholderText: "Enter target unit or currency"
                            onAccepted: root.searchGoogle("convert")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ShellButton {
                            Layout.fillWidth: true
                            text: "Translate"
                            accent: true
                            onClicked: root.searchGoogle("translate")
                        }
                        ShellButton {
                            Layout.fillWidth: true
                            text: "Convert"
                            accent: true
                            onClicked: root.searchGoogle("convert")
                        }
                        ShellButton {
                            Layout.fillWidth: true
                            text: "Price"
                            accent: true
                            onClicked: root.searchGoogle("price")
                        }
                    }

                    Rectangle {
                        visible: root.statusText.length > 0 || root.googleResultText.length > 0
                        Layout.fillWidth: true
                        implicitHeight: resultColumn.implicitHeight + 20
                        radius: 8
                        color: "#161d2a"
                        border.color: "#2b364a"

                        ColumnLayout {
                            id: resultColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: root.statusText
                                visible: text.length > 0
                                color: "#c4ccda"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.googleResultTitle
                                visible: text.length > 0
                                color: "#abc7ff"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Flickable {
                                id: googleAnswerFlickable
                                visible: root.googleResultText.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(240, googleAnswerText.implicitHeight)
                                contentWidth: width
                                contentHeight: googleAnswerText.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Text {
                                    id: googleAnswerText
                                    width: googleAnswerFlickable.width
                                    text: root.googleResultText
                                    color: "#e2e8f0"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }

                                ScrollBar.vertical: ScrollBar { }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: root.lastGoogleUrl.length > 0
                                text: "Open Google search ↗"
                                color: "#abc7ff"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 11
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(root.lastGoogleUrl)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
