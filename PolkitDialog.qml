import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

PanelWindow {
    id: polkitWindow

    screen: Quickshell.screens[0]
    visible: polkitAgent.isActive && polkitAgent.flow !== null

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

    property alias agent: polkitAgent
    readonly property var currentFlow: polkitAgent.flow
    property string authError: ""
    property bool isSubmitting: false

    PolkitAgent {
        id: polkitAgent

        onIsRegisteredChanged: {
            console.log("[PolkitAgent] Registered:", isRegistered);
        }

        onAuthenticationRequestStarted: {
            console.log("[PolkitAgent] Request started. Action:", flow ? flow.actionId : "");
            polkitWindow.authError = "";
            polkitWindow.isSubmitting = false;
            passwordInput.text = "";
        }

        onFlowChanged: {
            if (flow) {
                flow.supplementaryMessageChanged.connect(function() {
                    if (flow && flow.supplementaryMessage && flow.supplementaryMessage.trim() !== "") {
                        polkitWindow.authError = flow.supplementaryMessage;
                        if (flow.supplementaryIsError) {
                            polkitWindow.triggerShake();
                        }
                    }
                });

                flow.failedChanged.connect(function() {
                    if (flow && flow.failed) {
                        polkitWindow.isSubmitting = false;
                        polkitWindow.triggerShake();
                        if (!polkitWindow.authError) {
                            polkitWindow.authError = "Authentication failed. Please check your password.";
                        }
                        passwordInput.selectAll();
                        passwordInput.forceActiveFocus();
                    }
                });

                flow.isResponseRequiredChanged.connect(function() {
                    if (flow && flow.isResponseRequired) {
                        polkitWindow.isSubmitting = false;
                        passwordInput.forceActiveFocus();
                    }
                });
            } else {
                polkitWindow.authError = "";
                polkitWindow.isSubmitting = false;
                passwordInput.text = "";
            }
        }
    }

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
