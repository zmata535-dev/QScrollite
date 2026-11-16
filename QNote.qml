import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var service

    screen: Quickshell.screens[0]
    visible: service.qNoteOpen
    implicitWidth: Math.min(270, screen.width)
    implicitHeight: screen.height
    color: "transparent"
    anchors { top: true; bottom: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qscrollite-qnote"
    // Hold keyboard focus only while editing a note under the pointer.
    WlrLayershell.keyboardFocus: visible && focusedNoteField && notePanelHover.hovered
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { Region { item: noteCard } }

    property real slideOffset: 380
    property bool closing: false
    property int openPresetMenuIndex: -1
    property var focusedNoteField: null
    property var noteItems: []
    readonly property var pastelPalette: [
        { name: "Blue", color: "#3F536B" },
        { name: "Lavender", color: "#554B68" },
        { name: "Pink", color: "#6A4855" },
        { name: "Peach", color: "#70533F" },
        { name: "Yellow", color: "#696139" },
        { name: "Mint", color: "#3F6253" }
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
            if (colorIndex < 0) colorIndex = 0
            return {
                title: String(note.title || ("Note " + (index + 1))),
                text: String(note.text || ""),
                color: pastelPalette[colorIndex].color
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
        slideOut.start()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.service.qNoteOpen
        onActivated: root.close()
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "slideOffset"
        from: 380
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOut
        target: root
        property: "slideOffset"
        from: 0
        to: 380
        duration: 240
        easing.type: Easing.InCubic
        onFinished: root.service.closeQNote()
    }

    Component.onCompleted: {
        ensureNotes()
        slideIn.start()
    }

    Rectangle {
        id: noteCard
        width: root.width
        height: Math.min(680, root.height - 32)
        x: root.slideOffset
        y: Math.max(16, Math.round((root.height - height) / 2))
        radius: 14
        color: "#111722"
        border.color: "#3b4a63"
        border.width: 1

        HoverHandler {
            id: notePanelHover
            onHoveredChanged: {
                if (!hovered) {
                    root.releaseNoteKeyboardFocus()
                    root.openPresetMenuIndex = -1
                }
            }
        }

        GlowBorder { targetItem: noteCard; cornerRadius: noteCard.radius }

        Keys.onEscapePressed: root.close()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

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
                    onClicked: {
                        root.openPresetMenuIndex = -1
                        root.close()
                    }
                }
            }

            ListView {
                id: noteList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: root.noteItems
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: noteItemCard
                    required property int index
                    required property var modelData
                    function focusText() {
                        root.focusedNoteField = noteEditor
                        noteEditor.forceActiveFocus()
                    }
                    function choosePreset(colorIndex) {
                        root.updateNoteColor(noteItemCard.index, colorIndex)
                        root.openPresetMenuIndex = -1
                    }
                    readonly property bool presetMenuOpen: root.openPresetMenuIndex === index
                    width: noteList.width
                    height: 138
                    radius: 10
                    z: presetMenuOpen ? 10 : 0
                    color: root.noteBackground(modelData.color)
                    border.color: Qt.darker(modelData.color, 1.35)
                    border.width: 1
                    readonly property bool noteControlsVisible:
                        noteCardHover.hovered || presetMenuOpen

                    HoverHandler {
                        id: noteCardHover
                    }

                    Rectangle {
                        id: presetMenu
                        x: noteItemCard.width - width - 27
                        y: 26
                        width: 158
                        height: 78
                        radius: 7
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
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[0].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(0)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Lavender"
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[1].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(1)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Pink"
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[2].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(2)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Peach"
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[3].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(3)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Yellow"
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[4].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(4)
                            }
                            ShellButton {
                                width: (presetList.width - presetList.columnSpacing) / 2
                                height: 22
                                font.pixelSize: 9
                                text: "Mint"
                                background: Rectangle { radius: 4; color: root.noteBackground(root.pastelPalette[5].color); border.width: 0 }
                                onClicked: noteItemCard.choosePreset(5)
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            spacing: 3

                            ShellTextField {
                                id: noteTitle
                                Layout.fillWidth: true
                                implicitHeight: 23
                                leftPadding: 4
                                rightPadding: 3
                                font.pixelSize: 10
                                placeholderText: "Note title"
                                text: noteItemCard.modelData.title || ""
                                background: Rectangle {
                                    color: Qt.darker(noteItemCard.modelData.color, 1.35)
                                    radius: 4
                                    border.width: 0
                                }
                                onActiveFocusChanged: {
                                    root.setNoteFieldFocus(noteTitle, activeFocus)
                                    if (activeFocus) root.openPresetMenuIndex = -1
                                    else Qt.callLater(function() { root.service.flushQNoteSave() })
                                }
                                onTextChanged: root.updateNoteField(noteItemCard.index, "title", text)
                            }

                            ShellButton {
                                id: noteColorButton
                                Layout.preferredWidth: 82
                                implicitWidth: 82
                                implicitHeight: 23
                                font.pixelSize: 9
                                text: {
                                    for (var i = 0; i < root.pastelPalette.length; i++)
                                        if (root.pastelPalette[i].color === noteItemCard.modelData.color)
                                            return root.pastelPalette[i].name
                                    return root.pastelPalette[1].name
                                }
                                opacity: noteItemCard.noteControlsVisible ? 1 : 0
                                enabled: true
                                onClicked: {
                                    root.openPresetMenuIndex = noteItemCard.presetMenuOpen
                                        ? -1 : noteItemCard.index
                                }
                            }

                            ShellButton {
                                Layout.preferredWidth: 24
                                implicitWidth: 24
                                implicitHeight: 23
                                font.pixelSize: 12
                                danger: true
                                text: "×"
                                opacity: noteItemCard.noteControlsVisible ? 1 : 0
                                enabled: noteItemCard.noteControlsVisible
                                background: Rectangle {
                                    radius: 6
                                    color: root.noteBackground(noteItemCard.modelData.color)
                                    border.width: 1
                                    border.color: Qt.lighter(noteItemCard.modelData.color, 1.7)
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
                            text: noteItemCard.modelData.text || ""
                            placeholderText: "Write a note…"
                            color: "#e5ebf4"
                            selectionColor: "#809ac0"
                            selectedTextColor: "#ffffff"
                            wrapMode: TextEdit.Wrap
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 11
                            padding: 0
                            background: Rectangle {
                                color: Qt.darker(noteItemCard.modelData.color, 1.35)
                                radius: 7
                                border.width: 0
                            }
                            onActiveFocusChanged: {
                                root.setNoteFieldFocus(noteEditor, activeFocus)
                                if (activeFocus) {
                                    root.openPresetMenuIndex = -1
                                    root.service.qNoteCurrentIndex = noteItemCard.index
                                }
                                else Qt.callLater(function() { root.service.flushQNoteSave() })
                            }
                            onTextChanged: root.updateNoteField(noteItemCard.index, "text", text)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { }

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
