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
    visible: service.qNoteOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: service.raisedCardModule === "qnote" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qscrollite-qnote"
    // Hold keyboard focus only while editing a note under the pointer.
    WlrLayershell.keyboardFocus: visible && focusedNoteField && notePanelHover.hovered
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { Region { item: noteCard } }

    property real cardX: -300
    property real openTargetX: 12
    property real exitX: -300
    property bool closing: false
    property int openPresetMenuIndex: -1
    property var focusedNoteField: null
    property var noteItems: []
    readonly property int cornerRadius: 8
    readonly property string clipboardNoteColor: "#CEC8A3"
    readonly property real clipboardNoteOpacity: 0.69
    readonly property var pastelPalette: [
        { name: "Blue", color: "#3F536B" },
        { name: "Lavender", color: "#554B68" },
        { name: "Pink", color: "#6A4855" },
        { name: "Peach", color: "#70533F" },
        { name: "Yellow", color: "#696139" },
        { name: "Mint", color: "#3F6253" },
        { name: "Gray", color: "#555B63" },
        { name: "Black", color: "#24272D" }
    ]
    readonly property string activeNoteColor: noteItems.length
        ? String(noteItems[Math.max(0, Math.min(service.qNoteCurrentIndex, noteItems.length - 1))].color)
        : pastelPalette[1].color

    function noteBackground(color) {
        var value = String(color || pastelPalette[1].color).replace("#", "")
        return Qt.rgba(parseInt(value.slice(0, 2), 16) / 255,
                       parseInt(value.slice(2, 4), 16) / 255,
                       parseInt(value.slice(4, 6), 16) / 255,
                       0.92)
    }

    function noteCardBackground(color) {
        if (color === clipboardNoteColor) {
            var pastel = Qt.darker(color, 1.0)
            return Qt.rgba(pastel.r, pastel.g, pastel.b, clipboardNoteOpacity)
        }
        return Qt.darker(color, 1.35)
    }

    function noteFieldBackground(color) {
        return color === clipboardNoteColor ? "transparent" : Qt.darker(color, 1.35)
    }

    function noteControlBackground(color, controlsVisible, hovered, idle) {
        if (!controlsVisible && color === clipboardNoteColor) return "transparent"
        return Qt.darker(color, idle || !controlsVisible ? 1.35 : (hovered ? 1.9 : 1.6))
    }

    function setNoteFieldFocus(field, focused) {
        if (focused) {
            focusedNoteField = field
            return
        }
        // Let focus move between the title and body without briefly dropping
        // keyboard focus from the layer surface.
        Qt.callLater(function() {
            if (root.focusedNoteField === field && !field.activeFocus)
                root.focusedNoteField = null
        })
    }

    function releaseNoteKeyboardFocus() {
        var field = focusedNoteField
        focusedNoteField = null
        if (field) field.focus = false
    }

    function ensureNotes() {
        // Only write during startup when migrating older storage. A normal
        // reload should read the saved list without rewriting it.
        var needsMigration = !service.qNoteInitialized
        var storedNotes = service.qNoteNotes
        var saved = []
        if (storedNotes && typeof storedNotes.length === "number") {
            for (var savedIndex = 0; savedIndex < storedNotes.length; savedIndex++)
                saved.push(storedNotes[savedIndex])
        }
        if (needsMigration && saved.length === 0)
            saved = [{ text: service.qNoteLegacyText || "", color: pastelPalette[1].color }]
        var previousPalette = ["#293d59", "#403552", "#543742", "#594333", "#514a2b", "#2d493f"]
        var legacyLightPalette = ["#dceafa", "#e8e0f5", "#f5dfe6", "#f5e2d2", "#f4edc9", "#d9eee5"]
        noteItems = saved.map(function(note, index) {
            var color = String(note.color || pastelPalette[1].color)
            var colorIndex = -1
            for (var i = 0; i < pastelPalette.length; i++)
                if (pastelPalette[i].color === color) colorIndex = i
            if (colorIndex < 0) colorIndex = previousPalette.indexOf(color)
            if (colorIndex < 0) colorIndex = legacyLightPalette.indexOf(color)
            if (colorIndex >= 0) color = pastelPalette[colorIndex].color
            else if (!/^#[0-9a-fA-F]{6}$/.test(color)) color = pastelPalette[0].color
            return {
                title: String(note.title || ("Note " + (index + 1))),
                text: String(note.text || ""),
                color: color
            }
        })
        service.qNoteCurrentIndex = noteItems.length
            ? Math.max(0, Math.min(service.qNoteCurrentIndex, noteItems.length - 1)) : 0
        service.qNoteInitialized = true
        if (needsMigration) saveNotes()
        console.log("[QNote] Restored", noteItems.length, "notes")
    }

    function saveNotes() {
        service.qNoteNotes = noteItems.map(function(note) {
            return {
                title: String(note.title || ""),
                text: String(note.text || ""),
                color: String(note.color || pastelPalette[1].color)
            }
        })
    }

    function updateNoteField(index, field, value) {
        if (index < 0 || index >= noteItems.length) return
        noteItems[index][field] = String(value)
        service.qNoteCurrentIndex = index
        saveNotes()
    }

    function updateNoteColor(index, colorIndex) {
        if (index < 0 || index >= noteItems.length || colorIndex < 0 || colorIndex >= pastelPalette.length) return
        var updated = noteItems.slice(0)
        updated[index] = {
            title: updated[index].title,
            text: updated[index].text,
            color: pastelPalette[colorIndex].color
        }
        noteItems = updated
        service.qNoteCurrentIndex = index
        saveNotes()
        service.flushQNoteSave()
    }

    function addNote() {
        var updated = noteItems.slice(0)
        updated.push({ title: "Note " + (updated.length + 1), text: "", color: pastelPalette[1].color })
        noteItems = updated
        service.qNoteCurrentIndex = updated.length - 1
        saveNotes()
        service.flushQNoteSave()
        var newIndex = updated.length - 1
        Qt.callLater(function() {
            noteList.positionViewAtEnd()
            Qt.callLater(function() {
                var newCard = noteList.itemAtIndex(newIndex)
                if (newCard) newCard.focusText()
            })
        })
    }

    function addClipboardNote(text) {
        var updated = noteItems.slice(0)
        updated.push({
            title: "Clipboard note",
            text: String(text || ""),
            color: clipboardNoteColor
        })
        noteItems = updated
        service.qNoteCurrentIndex = updated.length - 1
        openPresetMenuIndex = -1
        saveNotes()
        service.flushQNoteSave()
        var newIndex = updated.length - 1
        Qt.callLater(function() {
            noteList.positionViewAtEnd()
            Qt.callLater(function() {
                var newCard = noteList.itemAtIndex(newIndex)
                if (newCard) newCard.focusText()
            })
        })
    }

    function consumePendingClipboardNote() {
        if (!service.qNoteInitialized || !service.pendingClipboardNoteText.length) return
        var text = service.pendingClipboardNoteText
        service.pendingClipboardNoteText = ""
        addClipboardNote(text)
    }

    function deleteNote(index) {
        if (index < 0 || index >= noteItems.length) return
        var updated = noteItems.slice(0)
        updated.splice(index, 1)
        noteItems = updated
        service.qNoteCurrentIndex = updated.length ? Math.min(index, updated.length - 1) : 0
        saveNotes()
        service.flushQNoteSave()
    }

    function close() {
        if (closing) return
        closing = true
        exitX = PanelPlacement.entryX(cardX, root.width, noteCard.width, root.screen.x, 12)
        slideOut.to = exitX
        slideOut.start()
    }

    function positionOppositeFocusedWindow() {
        var requestedX = PanelPlacement.oppositeTargetX(
            service, root.screen.x, root.width, noteCard.width, 12)
        var margin = Math.min(12, Math.max(0, (root.width - noteCard.width) / 2))
        var maxX = Math.max(margin, root.width - noteCard.width - margin)
        openTargetX = Math.max(margin, Math.min(requestedX, maxX))
    }

    function openFromOppositeSide() {
        Qt.callLater(function() {
            if (!root.visible || root.closing || root.width <= 0 || noteCard.width <= 0) return
            root.positionOppositeFocusedWindow()
            root.cardX = PanelPlacement.entryX(root.openTargetX,
                root.width, noteCard.width, root.screen.x, 12)
            slideIn.to = root.openTargetX
            slideIn.restart()
        })
    }

    function repositionAfterSwitcher() {
        Qt.callLater(function() {
            if (!root.visible || root.closing || PanelPlacement.switcherActive(root.service)) return
            root.positionOppositeFocusedWindow()
            slideIn.stop()
            slideIn.to = root.openTargetX
            slideIn.restart()
        })
    }

    Connections {
        target: root.service
        function onPendingClipboardNoteTextChanged() {
            Qt.callLater(function() { root.consumePendingClipboardNote() })
        }
        function onActiveWindowIdChanged() {
            root.repositionAfterSwitcher()
        }
        function onOpenChanged() { if (!root.service.open) root.repositionAfterSwitcher() }
        function onAppSwitcherHoveredChanged() {
            if (!root.service.appSwitcherHovered) root.repositionAfterSwitcher()
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.service.qNoteOpen
        onActivated: root.close()
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
        id: slideOut
        target: root
        property: "cardX"
        from: root.cardX
        to: root.exitX
        duration: 240
        easing.type: Easing.InCubic
        onFinished: root.service.closeQNote()
    }

    Component.onCompleted: {
        ensureNotes()
        consumePendingClipboardNote()
        openFromOppositeSide()
    }

    onWidthChanged: {
        if (visible && !closing && !slideIn.running && cardX !== openTargetX)
            openFromOppositeSide()
    }

    GlowBorder { targetItem: noteCard; cornerRadius: noteCard.radius }

    Rectangle {
        id: noteCard
        width: Math.min(270, root.width)
        height: Math.min(680, root.height - 32)
        // Negative offsets move the card beyond the panel's left edge.
        x: root.cardX
        y: Math.max(16, Math.round((root.height - height) / 2))
        radius: root.cornerRadius
        opacity: root.focusedNoteField ? 1 : 0.92
        color: "#111722"
        border.color: "#3b4a63"
        border.width: 1

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onPressedChanged: {
                if (pressed) root.service.raiseCardModule("qnote")
            }
        }

        HoverHandler {
            id: notePanelHover
            onHoveredChanged: {
                if (!hovered) {
                    root.releaseNoteKeyboardFocus()
                    root.openPresetMenuIndex = -1
                }
            }
        }

        Keys.onEscapePressed: root.close()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.service.raiseCardModule("qnote")
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "QNote"
                    color: "#abc7ff"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                ShellButton {
                    Layout.preferredWidth: 24
                    implicitWidth: 24
                    implicitHeight: 23
                    font.pixelSize: 15
                    text: "+"
                    background: Rectangle {
                        radius: root.cornerRadius
                        color: parent.hovered ? "#273650" : "#161d2a"
                        border.width: 1
                        border.color: parent.hovered ? "#abc7ff" : "#2b364a"
                    }
                    onClicked: {
                        root.openPresetMenuIndex = -1
                        root.addNote()
                    }
                }

                ShellButton {
                    Layout.preferredWidth: 24
                    implicitWidth: 24
                    implicitHeight: 23
                    font.pixelSize: 12
                    text: "×"
                    background: Rectangle {
                        radius: root.cornerRadius
                        color: parent.hovered ? "#273650" : "#161d2a"
                        border.width: 1
                        border.color: parent.hovered ? "#abc7ff" : "#2b364a"
                    }
                    onClicked: {
                        root.openPresetMenuIndex = -1
                        root.close()
                    }
                }
            }

            Item {
                id: noteListContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                id: noteList
                anchors.fill: parent
                clip: true
                spacing: 8
                leftMargin: 12
                model: root.noteItems
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: noteItemCard
                    required property int index
                    required property var modelData
                    property string initialText: ""
                    function focusText() {
                        root.focusedNoteField = noteEditor
                        noteEditor.forceActiveFocus()
                    }
                    function choosePreset(colorIndex) {
                        root.updateNoteColor(noteItemCard.index, colorIndex)
                        root.openPresetMenuIndex = -1
                    }
                    function insertSymbol(symbol) {
                        var start = noteEditor.activeFocus ? noteEditor.cursorPosition : noteEditor.text.length
                        var end = start
                        if (noteEditor.activeFocus && noteEditor.selectedText.length > 0) {
                            start = noteEditor.selectionStart
                            end = noteEditor.selectionEnd
                        }
                        noteEditor.forceActiveFocus()
                        if (end > start) noteEditor.remove(start, end)
                        noteEditor.insert(start, symbol)
                        noteEditor.cursorPosition = start + symbol.length
                    }
                    readonly property bool presetMenuOpen: root.openPresetMenuIndex === index
                    readonly property real minimumBodyHeight: noteEditor.font.pixelSize * 1.4 * 3
                    width: noteList.width - noteList.leftMargin
                    height: 26 + Math.max(minimumBodyHeight, noteEditor.contentHeight)
                    radius: root.cornerRadius
                    z: presetMenuOpen ? 10 : 0
                    color: root.noteCardBackground(modelData.color)
                    border.color: root.noteCardBackground(modelData.color)
                    border.width: 1
                    readonly property bool noteControlsVisible:
                        noteCardHover.hovered || presetMenuOpen

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onPressedChanged: {
                            if (pressed) root.service.raiseCardModule("qnote")
                        }
                    }

                    HoverHandler {
                        id: noteCardHover
                    }

                    Component.onCompleted: initialText = noteEditor.text

                    Rectangle {
                        id: presetMenu
                        x: noteItemCard.width - width - 27
                        y: {
                            var cardTop = noteItemCard.y - noteList.contentY
                            var belowY = 26
                            var aboveY = -height - 4
                            if (cardTop + belowY + height + 4 <= noteList.height)
                                return belowY
                            if (cardTop + aboveY >= 4)
                                return aboveY
                            return Math.max(4 - cardTop,
                                Math.min(belowY, noteList.height - cardTop - height - 4))
                        }
                        width: 158
                        height: 102
                        radius: root.cornerRadius
                        visible: noteItemCard.presetMenuOpen
                        z: 20
                        color: "#111722"
                        border.color: "#3b4a63"
                        border.width: 1

                        Grid {
                            id: presetList
                            anchors.fill: parent
                            anchors.margins: 4
                            columns: 2
                            columnSpacing: 2
                            rowSpacing: 2

                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Blue"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[0].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(0)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Lavender"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[1].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(1)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Pink"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[2].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(2)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Peach"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[3].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(3)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Yellow"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[4].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(4)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Mint"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[5].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(5)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Gray"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[6].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(6)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Black"
                                background: Rectangle { radius: root.cornerRadius; color: root.noteBackground(root.pastelPalette[7].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(7)
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            spacing: 0

                            ShellTextField {
                                id: noteTitle
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onPressedChanged: {
                                        if (pressed) root.service.raiseCardModule("qnote")
                                    }
                                }
                                Layout.fillWidth: true
                                implicitHeight: 23
                                leftPadding: 4
                                rightPadding: 3
                                font.pixelSize: 10
                                placeholderText: "Note title"
                                text: noteItemCard.modelData.title || ""
                                color: noteItemCard.modelData.color === root.clipboardNoteColor
                                    ? "#36352d" : "#e5ebf4"
                                background: Rectangle {
                                    color: root.noteFieldBackground(noteItemCard.modelData.color)
                                    radius: root.cornerRadius
                                    bottomLeftRadius: 0
                                    bottomRightRadius: 0
                                    border.width: 0
                                }
                                onActiveFocusChanged: {
                                    root.setNoteFieldFocus(noteTitle, activeFocus)
                                    if (activeFocus) {
                                        root.service.raiseCardModule("qnote")
                                        root.openPresetMenuIndex = -1
                                    }
                                    else Qt.callLater(function() { root.service.flushQNoteSave() })
                                }
                                onTextChanged: root.updateNoteField(noteItemCard.index, "title", text)
                            }

                            ShellButton {
                                id: noteColorButton
                                Layout.preferredWidth: 76
                                implicitWidth: 76
                                implicitHeight: 23
                                font.pixelSize: 9
                                text: {
                                    for (var i = 0; i < root.pastelPalette.length; i++)
                                        if (root.pastelPalette[i].color === noteItemCard.modelData.color)
                                            return root.pastelPalette[i].name
                                    return noteItemCard.modelData.color === root.clipboardNoteColor
                                        ? "Clipboard" : "Custom"
                                }
                                opacity: 1
                                enabled: true
                                background: Rectangle {
                                    radius: root.cornerRadius
                                    color: root.noteControlBackground(noteItemCard.modelData.color,
                                        noteItemCard.noteControlsVisible, noteColorButton.hovered, false)
                                    border.width: 0
                                }
                                contentItem: Text {
                                    text: noteColorButton.text
                                    color: noteItemCard.noteControlsVisible
                                        ? Qt.lighter(noteItemCard.modelData.color, 1.7) : "transparent"
                                    font: noteColorButton.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                onClicked: {
                                    root.openPresetMenuIndex = noteItemCard.presetMenuOpen
                                        ? -1 : noteItemCard.index
                                }
                            }

                            Repeater {
                                model: ["✓", "✕", "○"]
                                delegate: ShellButton {
                                    required property var modelData
                                    Layout.preferredWidth: 22
                                    implicitWidth: 22
                                    implicitHeight: 23
                                    font.pixelSize: 12
                                    focusPolicy: Qt.NoFocus
                                    text: modelData
                                    opacity: 1
                                    enabled: noteItemCard.noteControlsVisible && noteEditor.activeFocus
                                    background: Rectangle {
                                        radius: root.cornerRadius
                                        color: root.noteControlBackground(noteItemCard.modelData.color,
                                            noteItemCard.noteControlsVisible, parent.hovered, false)
                                        border.width: 0
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled
                                            ? Qt.lighter(noteItemCard.modelData.color, 1.7)
                                            : (noteItemCard.noteControlsVisible ? "#657188" : "transparent")
                                        font: parent.font
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: noteItemCard.insertSymbol(modelData)
                                }
                            }

                            ShellButton {
                                id: noteUndoButton
                                Layout.preferredWidth: 22
                                implicitWidth: 22
                                implicitHeight: 23
                                font.pixelSize: 14
                                focusPolicy: Qt.NoFocus
                                text: "↶"
                                opacity: 1
                                enabled: noteItemCard.noteControlsVisible && noteEditor.activeFocus &&
                                    noteEditor.text !== noteItemCard.initialText
                                background: Rectangle {
                                    radius: root.cornerRadius
                                    color: root.noteControlBackground(noteItemCard.modelData.color,
                                        noteItemCard.noteControlsVisible, noteUndoButton.hovered,
                                        noteEditor.text === noteItemCard.initialText)
                                    border.width: 0
                                }
                                contentItem: Text {
                                    text: noteUndoButton.text
                                    color: !noteItemCard.noteControlsVisible ||
                                        noteEditor.text === noteItemCard.initialText ? "transparent" :
                                        (noteUndoButton.enabled
                                            ? Qt.lighter(noteItemCard.modelData.color, 1.7) : "#657188")
                                    font: noteUndoButton.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    noteEditor.forceActiveFocus()
                                    if (noteEditor.canUndo) noteEditor.undo()
                                    else noteEditor.text = noteItemCard.initialText
                                }
                            }

                            ShellButton {
                                id: noteDeleteButton
                                Layout.preferredWidth: 22
                                implicitWidth: 22
                                implicitHeight: 23
                                font.pixelSize: 12
                                text: "󰆴"
                                opacity: 1
                                enabled: noteItemCard.noteControlsVisible
                                background: Rectangle {
                                    radius: root.cornerRadius
                                    color: root.noteControlBackground(noteItemCard.modelData.color,
                                        noteItemCard.noteControlsVisible, noteDeleteButton.hovered, false)
                                    border.width: 0
                                }
                                contentItem: Text {
                                    text: noteDeleteButton.text
                                    color: noteItemCard.noteControlsVisible
                                        ? Qt.lighter(noteItemCard.modelData.color, 1.7) : "transparent"
                                    font: noteDeleteButton.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    root.openPresetMenuIndex = -1
                                    root.deleteNote(noteItemCard.index)
                                }
                            }
                        }

                        TextArea {
                            id: noteEditor
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onPressedChanged: {
                                    if (pressed) root.service.raiseCardModule("qnote")
                                }
                            }
                            text: noteItemCard.modelData.text || ""
                            placeholderText: "Write a note…"
                            color: noteItemCard.modelData.color === root.clipboardNoteColor
                                ? "#36352d" : "#e5ebf4"
                            selectionColor: "#809ac0"
                            selectedTextColor: "#ffffff"
                            wrapMode: TextEdit.Wrap
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                            padding: 0
                            background: Rectangle {
                                color: root.noteFieldBackground(noteItemCard.modelData.color)
                                radius: root.cornerRadius
                                border.width: 0
                            }
                            onActiveFocusChanged: {
                                root.setNoteFieldFocus(noteEditor, activeFocus)
                                if (activeFocus) {
                                    root.service.raiseCardModule("qnote")
                                    root.openPresetMenuIndex = -1
                                    root.service.qNoteCurrentIndex = noteItemCard.index
                                }
                                else Qt.callLater(function() { root.service.flushQNoteSave() })
                            }
                            onTextChanged: root.updateNoteField(noteItemCard.index, "text", text)
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 14
                    z: 2
                    visible: noteList.contentY > 1
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ee111722" }
                        GradientStop { position: 1; color: "#00111722" }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 14
                    z: 2
                    visible: noteList.contentY + noteList.height < noteList.contentHeight - 1
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00111722" }
                        GradientStop { position: 1; color: "#ee111722" }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    parent: noteListContainer
                    anchors.top: noteList.top
                    anchors.left: noteList.left
                    anchors.bottom: noteList.bottom
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.noteItems.length === 0
                    text: "No notes yet · press + to create one"
                    color: "#8092ab"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                }
            }
            }
        }
    }
}
