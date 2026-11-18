import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "GDictCalc.js" as Scientific
import "PanelPlacement.js" as PanelPlacement

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

    WlrLayershell.layer: service.raisedCardModule === "gdictcalc" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-gdictcalc"
    WlrLayershell.keyboardFocus: visible && focusedInput && cardHover.hovered
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: card }
    property real cardX: 12
    property real openTargetX: 12
    property string openEdge: "left"
    property string focusAtOpen: ""
    property var focusedInput: null

    function focusedWindowGeometry() {
        if (service.activeCompositor !== "hyprland") return null
        var targetId = String(service.activeWindowId || "")
        var workspaceList = service.workspaces || []
        for (var i = 0; i < workspaceList.length; i++) {
            var windows = workspaceList[i].windows || []
            for (var j = 0; j < windows.length; j++) {
                if (String(windows[j].id) === targetId) return windows[j]
            }
        }
        return null
    }

    function updateOpenTarget() {
        var geometry = focusedWindowGeometry()
        var screenLeft = Number(root.screen.x || 0)
        var appLeftX = geometry
            ? Number(geometry.x || 0)
            : screenLeft + root.width
        openEdge = appLeftX < screenLeft + root.width / 2 ? "right" : "left"
        openTargetX = openEdge === "right"
            ? root.width - card.width - 12 : 12
    }

    function placeOppositeFocusedWindow() {
        updateOpenTarget()
        cardX = openEdge === "right" ? root.width + 12 : -card.width - 12
    }

    function repositionForFocusedApp(force) {
        Qt.callLater(function() {
            if (!root.visible || PanelPlacement.switcherActive(root.service)) return
            var activeId = String(root.service.activeWindowId || "")
            if (!activeId || (!force && activeId === root.focusAtOpen)) return
            root.focusAtOpen = activeId
            root.updateOpenTarget()
            slideIn.stop()
            moveToOpenSide.restart()
        })
    }

    function openAtOppositeSide() {
        if (!visible || slideIn.running) return
        releaseKeyboardFocus()
        focusAtOpen = String(service.activeWindowId || "")
        placeOppositeFocusedWindow()
        slideIn.restart()
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "cardX"
        to: root.openTargetX
        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: moveToOpenSide
        target: root
        property: "cardX"
        to: root.openTargetX
        duration: 300
        easing.type: Easing.OutCubic
    }

    Connections {
        target: root.service
        function onActiveWindowIdChanged() {
            var activeId = String(root.service.activeWindowId || "")
            if (!activeId) return
            root.repositionForFocusedApp(false)
        }
        function onOpenChanged() { if (!root.service.open) root.repositionForFocusedApp(true) }
        function onAppSwitcherHoveredChanged() {
            if (!root.service.appSwitcherHovered) root.repositionForFocusedApp(true)
        }
    }

    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.searchGoogle("translate")
    }
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.searchWeather()
    }
    Shortcut {
        sequence: "Ctrl+P"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.searchGoogle("price")
    }
    Shortcut {
        sequence: "Ctrl+O"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.searchGoogle("convert")
    }

    property bool dictionaryMode: false
    property bool definitionRequested: false
    property bool translationRequested: false
    property string expression: String(service.gDictCalcInitialQuery || "")
    property string statusText: ""
    property string lastGoogleQuery: ""
    property string lastGoogleUrl: ""
    property string googleSearchSourceLanguage: ""
    property string googleSearchTargetLanguage: ""
    property string googleResultTitle: ""
    property string googleResultText: ""
    property string dictionaryPhonetic: ""
    property var dictionaryMeanings: []
    property bool weatherResult: false
    property bool dictionaryApiResult: false
    property bool searching: false
    property int googleSearchGeneration: 0
    readonly property string weatherUrl: "https://wttr.in/" +
        encodeURIComponent(weatherProcess.location).replace(/%20/g, "+")
    readonly property string weatherImageUrl: weatherUrl + ".png?Fnd"
    readonly property string calculationResult: {
        var result = Scientific.evaluate(expression)
        return result ? result.value : ""
    }
    readonly property var languages: [
        "Bahasa Indonesia", "English", "Spanish", "French", "German", "Italian",
        "Portuguese", "Japanese", "Korean", "Chinese (Simplified)", "Arabic",
        "Russian", "Hindi", "Dutch", "Turkish", "Vietnamese", "Thai",
        "Polish", "Swedish", "Greek", "Hebrew", "Ukrainian", "Bengali",
        "Malay", "Filipino"
    ]
    function dictionaryLanguageCode(language) {
        var codes = {
            "Bahasa Indonesia": "id", "English": "en", "Spanish": "es",
            "French": "fr", "German": "de", "Italian": "it", "Portuguese": "pt-BR",
            "Japanese": "ja", "Korean": "ko", "Chinese (Simplified)": "zh-CN",
            "Arabic": "ar", "Russian": "ru", "Hindi": "hi", "Dutch": "nl",
            "Turkish": "tr", "Vietnamese": "vi", "Thai": "th", "Polish": "pl",
            "Swedish": "sv", "Greek": "el", "Hebrew": "he", "Ukrainian": "uk",
            "Bengali": "bn", "Malay": "ms", "Filipino": "tl"
        }
        return codes[language] || "en"
    }
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

    Process {
        id: weatherProcess
        property string location: ""
        command: ["curl", "--fail", "--silent", "--show-error", "--max-time", "15",
            root.weatherUrl + "?format=j1"]
        running: false
        stdout: StdioCollector { id: weatherOutput }
        stderr: StdioCollector { id: weatherError }

        onExited: function(exitCode, exitStatus) {
            root.searching = false
            if (exitCode !== 0) {
                root.statusText = "Weather service request failed."
                root.googleResultText = weatherError.text.trim() || "Check your network connection and try again."
                return
            }
            var resolvedLocation = location
            try {
                var data = JSON.parse(String(weatherOutput.text || "").trim())
                var area = data.nearest_area && data.nearest_area.length ? data.nearest_area[0] : null
                if (area) {
                    var locationParts = [area.areaName, area.region, area.country].map(function(value) {
                        return value && value.length ? String(value[0].value || "").trim() : ""
                    }).filter(function(value, index, values) {
                        return value && values.indexOf(value) === index
                    })
                    if (locationParts.length) resolvedLocation = locationParts.join(", ")
                }
            } catch (e) {}
            root.statusText = ""
            root.googleResultTitle = "Weather report: " + location + " ~ " + resolvedLocation
            root.googleResultText = ""
        }
    }

    Process {
        id: dictionaryProcess
        property string word: ""
        property string languageCode: "en"
        command: ["curl", "--fail", "--silent", "--show-error", "--max-time", "12",
            "https://api.dictionaryapi.dev/api/v2/entries/" + languageCode + "/" + encodeURIComponent(word)]
        running: false
        stdout: StdioCollector { id: dictionaryOutput }
        stderr: StdioCollector { id: dictionaryError }

        onExited: function(exitCode, exitStatus) {
            root.searching = false
            if (exitCode !== 0) {
                root.searchGoogle("translate", true, true)
                return
            }
            try {
                var entries = JSON.parse(dictionaryOutput.text.trim())
                var entry = entries && entries.length ? entries[0] : null
                if (!entry || !entry.meanings || !entry.meanings.length) {
                    root.searchGoogle("translate", true, true)
                    return
                }
                var phonetic = String(entry.phonetic || "")
                if (!phonetic && entry.phonetics) {
                    for (var phoneticIndex = 0; phoneticIndex < entry.phonetics.length; phoneticIndex++) {
                        if (entry.phonetics[phoneticIndex].text) {
                            phonetic = String(entry.phonetics[phoneticIndex].text)
                            break
                        }
                    }
                }
                var meanings = []
                for (var meaningIndex = 0; meaningIndex < entry.meanings.length; meaningIndex++) {
                    var sourceMeaning = entry.meanings[meaningIndex]
                    var definitions = []
                    var sourceDefinitions = sourceMeaning.definitions || []
                    for (var definitionIndex = 0; definitionIndex < sourceDefinitions.length; definitionIndex++) {
                        var sourceDefinition = sourceDefinitions[definitionIndex]
                        if (!sourceDefinition.definition) continue
                        definitions.push({
                            definition: String(sourceDefinition.definition),
                            example: String(sourceDefinition.example || "")
                        })
                    }
                    if (definitions.length) meanings.push({
                        partOfSpeech: String(sourceMeaning.partOfSpeech || "Definition"),
                        definitions: definitions
                    })
                }
                if (!meanings.length) {
                    root.searchGoogle("translate", true, true)
                    return
                }
                root.dictionaryApiResult = true
                root.weatherResult = false
                root.definitionRequested = true
                root.translationRequested = false
                root.dictionaryPhonetic = phonetic
                root.dictionaryMeanings = meanings
                root.statusText = ""
                root.googleResultTitle = String(entry.word || dictionaryProcess.word)
                root.googleResultText = root.formatDefinitions(root.googleResultTitle, phonetic, meanings)
                root.dictionaryMode = true
                root.searching = false
            } catch (e) {
                root.searchGoogle("translate", true, true)
            }
        }
    }

    function close() {
        service.gDictCalcOpen = false
    }

    function setInputFocus(field, focused) {
        if (focused) {
            focusedInput = field
            return
        }
        Qt.callLater(function() {
            if (root.focusedInput === field && !field.activeFocus)
                root.focusedInput = null
        })
    }

    function releaseKeyboardFocus() {
        var field = focusedInput
        focusedInput = null
        if (field) field.focus = false
    }

    function handleShortcut(event) {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
            root.dictionaryMode = false
            root.statusText = ""
            Qt.callLater(function() { calcField.forceActiveFocus() })
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

    function copyResult() {
        if (!googleResultText) return
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "gdictcalc-copy-result", googleResultText])
    }

    function formatDefinitions(word, phonetic, meanings) {
        var lines = [String(word || "") + (phonetic ? "  " + phonetic : "")]
        for (var i = 0; i < meanings.length; i++) {
            var meaning = meanings[i]
            lines.push(String(meaning.partOfSpeech || "Definition").toUpperCase())
            for (var j = 0; j < meaning.definitions.length; j++) {
                var item = meaning.definitions[j]
                lines.push("• " + item.definition)
                if (item.example) lines.push("  Example: “" + item.example + "”")
            }
        }
        return lines.join("\n")
    }

    function calculate() {
        if (!calculationResult) return
        expression = calculationResult
        Qt.callLater(function() {
            calcField.forceActiveFocus()
            calcField.cursorPosition = calcField.text.length
        })
    }

    function searchGoogle(kind, skipDictionary, fallbackToEnglish) {
        if (googleSearchProcess.running) {
            statusText = "Wait for the current Google search to finish."
            return
        }
        var value = expression.trim()
        if (!value) {
            statusText = "Enter a word or value to search."
            return
        }

        var sourceLanguage = languageFrom.currentText
        var targetLanguage = fallbackToEnglish === true ? "English" : languageSelect.currentText
        var sameLanguage = sourceLanguage.toLowerCase() === targetLanguage.toLowerCase()
        googleSearchSourceLanguage = sourceLanguage
        googleSearchTargetLanguage = targetLanguage
        var text = value
        weatherResult = false
        dictionaryApiResult = false
        dictionaryMeanings = []
        dictionaryPhonetic = ""
        if (kind === "translate") {
            if (fallbackToEnglish === true || !sameLanguage)
                text = "translate " + value + " from " + sourceLanguage + " to " + targetLanguage
            else
                text = "define " + value + " in " + sourceLanguage
        }
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

        definitionRequested = kind === "translate" && sameLanguage && fallbackToEnglish !== true
        translationRequested = kind === "translate" && !definitionRequested

        if (kind === "translate" && sameLanguage && skipDictionary !== true) {
            lastGoogleQuery = text
            lastGoogleUrl = "https://www.google.com/search?q=" + encodeURIComponent(text).replace(/%20/g, "+")
            dictionaryProcess.word = value
            dictionaryProcess.languageCode = dictionaryLanguageCode(sourceLanguage)
            dictionaryMode = true
            googleResultTitle = ""
            googleResultText = ""
            statusText = "Looking up the definition…"
            searching = true
            dictionaryProcess.running = true
            return
        }

        lastGoogleQuery = text
        lastGoogleUrl = "https://www.google.com/search?q=" + encodeURIComponent(text).replace(/%20/g, "+")
        if (kind !== "translate") {
            definitionRequested = false
            translationRequested = false
        }
        dictionaryMode = true
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

    function searchWeather() {
        if (weatherProcess.running || googleSearchProcess.running) {
            statusText = "Wait for the current search to finish."
            return
        }
        var place = expression.trim()
        if (!place) {
            statusText = "Enter a city or location first."
            return
        }
        weatherResult = true
        dictionaryApiResult = false
        definitionRequested = false
        translationRequested = false
        weatherProcess.location = place
        dictionaryMode = true
        googleResultTitle = ""
        googleResultText = ""
        statusText = "Fetching today's weather…"
        lastGoogleUrl = weatherImageUrl
        searching = true
        weatherProcess.running = true
    }

    onVisibleChanged: {
        if (visible) {
            moveToOpenSide.stop()
            openAtOppositeSide()
        } else {
            slideIn.stop()
            moveToOpenSide.stop()
            releaseKeyboardFocus()
        }
    }

    Component.onCompleted: {
        if (visible) openAtOppositeSide()
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: card
            width: Math.min(480, root.width - 24)
            height: Math.min(content.implicitHeight + 24, root.height - 48)
            x: root.cardX
            y: (parent.height - height) / 2
            radius: 14
            color: "#111722"
            border.color: "#3b4a63"
            border.width: 1

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onPressedChanged: {
                    if (pressed) root.service.raiseCardModule("gdictcalc")
                }
            }

            HoverHandler {
                id: cardHover
                onHoveredChanged: {
                    if (!hovered) root.releaseKeyboardFocus()
                }
            }

            ColumnLayout {
                z: 1
                id: content
                anchors.fill: parent
                anchors.margins: 12
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.dictionaryMode
                            ? (root.definitionRequested ? "Definition"
                                : (root.translationRequested ? "Translation" : "Google result"))
                            : "Answer"
                        color: "#e2e8f0"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 17
                    }

                    Item { Layout.fillWidth: true }

                    ShellButton {
                        focusPolicy: Qt.NoFocus
                        visible: root.dictionaryMode
                        text: "<< Answer"
                        onClicked: {
                            root.dictionaryMode = false
                            root.definitionRequested = false
                            root.translationRequested = false
                            root.statusText = ""
                            root.lastGoogleUrl = ""
                            root.googleResultTitle = ""
                            root.googleResultText = ""
                            Qt.callLater(function() {
                                calcField.forceActiveFocus()
                            })
                        }
                    }

                    ShellButton {
                        focusPolicy: Qt.NoFocus
                        text: "×"
                        onClicked: root.close()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    ShellTextField {
                        id: calcField
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        placeholderText: "Expression, word, amount, currency, or product"
                        text: root.expression
                        rightPadding: 38
                        selectByMouse: true
                        onTextEdited: root.expression = text
                        onAccepted: root.calculate()
                        onActiveFocusChanged: root.setInputFocus(calcField, activeFocus)
                        Keys.onPressed: function(event) { root.handleShortcut(event) }

                        ShellButton {
                            focusPolicy: Qt.NoFocus
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 24
                            visible: calcField.text.length > 0
                            text: "󰃣"
                            onClicked: {
                                root.expression = ""
                                calcField.forceActiveFocus()
                            }
                        }
                    }

                    RowLayout {
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        spacing: 5
                        Text { text: "From"; color: "#94a3b8"; font.pixelSize: 11 }
                        ShellComboBox {
                            id: languageFrom
                            Layout.fillWidth: true
                            model: root.languages
                            currentIndex: 0
                            onActiveFocusChanged: root.setInputFocus(languageFrom, activeFocus)
                        }
                        Text { text: "To"; color: "#94a3b8"; font.pixelSize: 11 }
                        ShellComboBox {
                            id: languageSelect
                            Layout.fillWidth: true
                            model: root.languages
                            currentIndex: 1
                            onActiveFocusChanged: root.setInputFocus(languageSelect, activeFocus)
                        }
                    }

                    RowLayout {
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        spacing: 5
                        Text { text: "Convert"; color: "#94a3b8"; font.pixelSize: 11 }
                        ShellComboBox {
                            id: convertCategory
                            Layout.preferredWidth: 125
                            model: ["Currencies", "Length", "Weight", "Tech units", "Custom"]
                            onActivated: targetSelect.currentIndex = 0
                            onActiveFocusChanged: root.setInputFocus(convertCategory, activeFocus)
                        }
                        ShellComboBox {
                            id: targetSelect
                            Layout.fillWidth: true
                            visible: convertCategory.currentIndex !== 4
                            model: root.targetOptions
                            currentIndex: 0
                            onActiveFocusChanged: root.setInputFocus(targetSelect, activeFocus)
                        }
                        ShellTextField {
                            id: customTarget
                            Layout.fillWidth: true
                            visible: convertCategory.currentIndex === 4
                            placeholderText: "Enter target unit or currency"
                            onAccepted: root.searchGoogle("convert")
                            onActiveFocusChanged: root.setInputFocus(customTarget, activeFocus)
                        }
                    }

                    RowLayout {
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        spacing: 8
                        ShellButton {
                            focusPolicy: Qt.NoFocus
                            Layout.fillWidth: true
                            implicitHeight: 25
                            text: "T̲ranslate"
                            enabled: root.expression.trim().length > 0
                            accent: true
                            onClicked: root.searchGoogle("translate")
                        }
                        ShellButton {
                            focusPolicy: Qt.NoFocus
                            Layout.fillWidth: true
                            implicitHeight: 25
                            text: "Co̲nvert"
                            enabled: root.expression.trim().length > 0
                            accent: true
                            onClicked: root.searchGoogle("convert")
                        }
                        ShellButton {
                            focusPolicy: Qt.NoFocus
                            Layout.fillWidth: true
                            implicitHeight: 25
                            text: "P̲rice"
                            enabled: root.expression.trim().length > 0
                            accent: true
                            onClicked: root.searchGoogle("price")
                        }
                        ShellButton {
                            focusPolicy: Qt.NoFocus
                            Layout.fillWidth: true
                            implicitHeight: 25
                            text: "W̲eather"
                            enabled: root.expression.trim().length > 0
                            accent: true
                            onClicked: root.searchWeather()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.dictionaryMode
                            ? Math.min(220, resultColumn.implicitHeight + 16) : 42
                        radius: 7
                        color: "#161d2a"
                        border.color: "#2b364a"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: !root.dictionaryMode
                            Text {
                                Layout.fillWidth: true
                                text: root.calculationResult || (root.expression.length ? "Invalid expression" : "Enter an expression")
                                color: root.calculationResult ? "#abc7ff" : "#8092ab"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                            ShellButton {
                                focusPolicy: Qt.NoFocus
                                text: "Copy"
                                enabled: !!root.calculationResult
                                onClicked: root.copyCalculation()
                            }
                        }

                        ColumnLayout {
                            id: resultColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            visible: root.dictionaryMode

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
                                text: root.googleResultTitle +
                                    (root.dictionaryApiResult && root.dictionaryPhonetic
                                        ? "  " + root.dictionaryPhonetic : "")
                                visible: text.length > 0
                                color: "#abc7ff"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.Wrap
                            }
                            ShellButton {
                                focusPolicy: Qt.NoFocus
                                Layout.alignment: Qt.AlignRight
                                visible: root.googleResultText.length > 0
                                implicitHeight: 24
                                text: "Copy"
                                onClicked: root.copyResult()
                            }
                            ScrollView {
                                id: definitionScrollView
                                visible: root.dictionaryApiResult
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ColumnLayout {
                                    width: definitionScrollView.availableWidth
                                    spacing: 7

                                    Repeater {
                                        model: root.dictionaryMeanings

                                        delegate: ColumnLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.partOfSpeech
                                                color: "#abc7ff"
                                                font.family: "JetBrainsMono Nerd Font Mono"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            Repeater {
                                                model: modelData.definitions

                                                delegate: ColumnLayout {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: "• " + modelData.definition
                                                        color: "#e2e8f0"
                                                        font.family: "JetBrainsMono Nerd Font Mono"
                                                        font.pixelSize: 11
                                                        wrapMode: Text.Wrap
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: modelData.example.length > 0
                                                        text: "  Example: “" + modelData.example + "”"
                                                        color: "#94a3b8"
                                                        font.family: "JetBrainsMono Nerd Font Mono"
                                                        font.pixelSize: 10
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Flickable {
                                id: googleAnswerFlickable
                                visible: root.googleResultText.length > 0 && !root.weatherResult && !root.dictionaryApiResult
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                contentWidth: width
                                contentHeight: Math.max(height, googleAnswerText.implicitHeight)
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Text {
                                    id: googleAnswerText
                                    width: googleAnswerFlickable.width
                                    text: root.googleResultText
                                    color: "#e2e8f0"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 11
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                }

                                ScrollBar.vertical: ScrollBar { }
                            }
                            Flickable {
                                id: weatherImageFlickable
                                visible: root.weatherResult && root.googleResultTitle.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 190
                                contentWidth: Math.max(width, weatherImage.width)
                                contentHeight: Math.max(height, weatherImage.height)
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Image {
                                    id: weatherImage
                                    width: weatherImageFlickable.width * 1.2
                                    height: sourceSize.width > 0
                                        ? width * sourceSize.height / sourceSize.width : weatherImageFlickable.height
                                    source: weatherImageFlickable.visible ? root.weatherImageUrl : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }

                                ScrollBar.vertical: ScrollBar { }
                                ScrollBar.horizontal: ScrollBar { }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: root.lastGoogleUrl.length > 0
                                text: root.weatherResult ? "Open wttr.in ↗" :
                                    (root.translationRequested
                                        ? "Translate from " + root.googleSearchSourceLanguage + " to " + root.googleSearchTargetLanguage + " ↗"
                                        : (root.definitionRequested || root.dictionaryApiResult
                                            ? "Search definition ↗" : "Open Google search ↗"))
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

                    GridLayout {
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 4
                        columnSpacing: 4

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
                                readonly property bool numberKey:
                                    /^[0-9.]$/.test(modelData) || modelData === "pi" || modelData === "e"
                                readonly property bool functionKey:
                                    ["sin(", "cos(", "tan(", "sqrt(", "ln(", "log(", "asin(", "acos("]
                                        .indexOf(modelData) >= 0
                                focusPolicy: Qt.NoFocus
                                Layout.fillWidth: true
                                implicitHeight: 25
                                text: modelData
                                enabled: modelData !== "=" || root.expression.trim().length > 0
                                accent: modelData === "="
                                background: Rectangle {
                                    radius: 6
                                    color: !parent.enabled ? "#161d2a"
                                        : (parent.down ? (parent.danger ? "#3b1e28" : "#1d2a3e")
                                        : (parent.hovered ? (parent.danger ? "#3b1e28" : "#273650")
                                        : (parent.accent || parent.selected ? "#22334f" : "#161d2a")))
                                    border.width: 1
                                    border.color: parent.numberKey ? "#111722"
                                        : (parent.functionKey
                                            ? "#000000"
                                            : (!parent.enabled ? "#222936"
                                                : ((parent.hovered || parent.down)
                                                    ? (parent.danger ? "#ff6b81" : "#abc7ff")
                                                    : (parent.accent || parent.selected ? "#5476a4" : "#2b364a"))))
                                }
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
                        visible: !root.dictionaryMode
                        Layout.fillWidth: true
                        text: "Trig functions use degrees · ^ for powers · ! for factorial"
                        color: "#8290a7"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

            }
        }
    }
}
