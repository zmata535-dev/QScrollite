import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: polkitWindow

    required property var agent

    screen: Quickshell.screens[0]
    visible: agent.isActive && agent.flow !== null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-polkit"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    color: "#35080c16"

    readonly property var currentFlow: agent ? agent.flow : null
    property string authError: ""
    property bool isSubmitting: false
    property var connectedFlow: null
    property var supplementaryMessageHandler: null
    property var failedHandler: null
    property var responseRequiredHandler: null

    Connections {
        target: polkitWindow.agent

        function onAuthenticationRequestStarted() {
            polkitWindow.authError = "";
            polkitWindow.isSubmitting = false;
            passwordInput.text = "";
        }

        function onFlowChanged() {
            polkitWindow.connectCurrentFlow()
        }
    }

    function connectCurrentFlow() {
        var flow = currentFlow
        disconnectCurrentFlow()
        if (!flow) {
            authError = ""
            isSubmitting = false
            return
        }
        connectedFlow = flow

        supplementaryMessageHandler = function() {
            if (polkitWindow.currentFlow !== flow || !flow.supplementaryMessage || !flow.supplementaryMessage.trim()) return
            polkitWindow.authError = flow.supplementaryMessage
            if (flow.supplementaryIsError) polkitWindow.triggerShake()
        }
        flow.supplementaryMessageChanged.connect(supplementaryMessageHandler)

        failedHandler = function() {
            if (polkitWindow.currentFlow !== flow || !flow.failed) return
            polkitWindow.isSubmitting = false
            polkitWindow.triggerShake()
            if (!polkitWindow.authError)
                polkitWindow.authError = "Authentication failed. Please check your password."
            passwordInput.selectAll()
            passwordInput.forceActiveFocus()
        }
        flow.failedChanged.connect(failedHandler)

        responseRequiredHandler = function() {
            if (polkitWindow.currentFlow !== flow || !flow.isResponseRequired) return
            polkitWindow.isSubmitting = false
            passwordInput.forceActiveFocus()
        }
        flow.isResponseRequiredChanged.connect(responseRequiredHandler)
    }

    function disconnectCurrentFlow() {
        if (connectedFlow) {
            if (supplementaryMessageHandler)
                connectedFlow.supplementaryMessageChanged.disconnect(supplementaryMessageHandler)
            if (failedHandler)
                connectedFlow.failedChanged.disconnect(failedHandler)
            if (responseRequiredHandler)
                connectedFlow.isResponseRequiredChanged.disconnect(responseRequiredHandler)
        }
        connectedFlow = null
        supplementaryMessageHandler = null
        failedHandler = null
        responseRequiredHandler = null
    }

    Component.onCompleted: connectCurrentFlow()
    Component.onDestruction: disconnectCurrentFlow()

    function cancel() {
        if (currentFlow) {
            currentFlow.cancelAuthenticationRequest();
        }
    }

    function submit() {
        if (!currentFlow || isSubmitting) return;
        isSubmitting = true;
        authError = "";
        currentFlow.submit(passwordInput.text);
    }

    function triggerShake() {
        shakeAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            authError = "";
            isSubmitting = false;
            passwordInput.text = "";
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        repeat: false
        onTriggered: {
            passwordInput.forceActiveFocus();
        }
    }

    // Keyboard Shortcuts Trap
    Item {
        anchors.fill: parent
        focus: polkitWindow.visible

        Keys.onEscapePressed: {
            polkitWindow.cancel();
        }

        Keys.onReturnPressed: {
            polkitWindow.submit();
        }

        Keys.onEnterPressed: {
            polkitWindow.submit();
        }
    }

    // Backdrop Click Handling
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Dismissal by clicking backdrop cancels authentication
            polkitWindow.cancel();
        }
    }

    GlowBorder { targetItem: modalBox; cornerRadius: modalBox.radius; spread: 4 }

    Rectangle {
        id: modalBox
        property real shakeOffset: 0

        width: Math.min(parent.width - 40, 440)
        implicitHeight: contentColumn.implicitHeight + 40
        anchors.centerIn: parent
        transform: Translate { x: modalBox.shakeOffset }
        radius: 14
        color: "#111722"
        border.color: "#3b4a63"
        border.width: 1

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: -10; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 10; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: -6; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 6; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.InOutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            ShellComboBox {
                id: identitySelector
                Layout.fillWidth: true
                visible: Boolean(currentFlow && currentFlow.identities && currentFlow.identities.length > 1)
                model: currentFlow ? currentFlow.identities : []
                textRole: "displayName"
                currentIndex: currentFlow && currentFlow.identities
                    ? Math.max(0, currentFlow.identities.indexOf(currentFlow.selectedIdentity)) : 0
                onActivated: function(index) {
                    if (currentFlow && currentFlow.identities[index])
                        currentFlow.selectedIdentity = currentFlow.identities[index]
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !identitySelector.visible
                text: currentFlow && currentFlow.selectedIdentity
                    ? currentFlow.selectedIdentity.displayName
                    : (currentFlow && currentFlow.identities && currentFlow.identities.length
                        ? currentFlow.identities[0].displayName : "User")
                color: "#dce5f2"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.weight: Font.Light
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: authError || (currentFlow && currentFlow.message
                    ? currentFlow.message : "An application is requesting authorization.")
                color: authError ? "#ffb4ab" : "#94a3b8"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.weight: Font.Light
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 6
                    color: "#161d2a"
                    border.width: 1
                    border.color: passwordInput.activeFocus ? "#abc7ff" : (authError ? "#ff6b81" : "#2b364a")

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        color: "#dce5f2"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.weight: Font.Light
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        echoMode: (currentFlow && currentFlow.responseVisible) ? TextInput.Normal : TextInput.Password
                        enabled: !isSubmitting
                        onAccepted: polkitWindow.submit()

                        Text {
                            anchors.fill: parent
                            text: currentFlow && currentFlow.inputPrompt
                                ? currentFlow.inputPrompt.replace(/:$/, '') : "Password"
                            color: "#8092ab"
                            font: passwordInput.font
                            verticalAlignment: Text.AlignVCenter
                            visible: !passwordInput.text && !passwordInput.activeFocus
                        }
                    }
                }

                ShellButton {
                    Layout.preferredWidth: 72
                    text: "Cancel"
                    enabled: !isSubmitting
                    onClicked: polkitWindow.cancel()
                }

                ShellButton {
                    Layout.preferredWidth: 72
                    text: isSubmitting ? "Working…" : "OK"
                    accent: true
                    enabled: !isSubmitting
                    onClicked: polkitWindow.submit()
                }
            }
        }
    }

}
