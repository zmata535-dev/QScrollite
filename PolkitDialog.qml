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

    color: "#aa080a12"

    property alias agent: polkitAgent
    readonly property var currentFlow: polkitAgent.flow
    property string authError: ""
    property bool isSubmitting: false
    property bool showPassword: false

    PolkitAgent {
        id: polkitAgent

        onIsRegisteredChanged: {
            console.log("[PolkitAgent] Registered:", isRegistered);
        }

        onAuthenticationRequestStarted: {
            console.log("[PolkitAgent] Request started. Action:", flow ? flow.actionId : "");
            polkitWindow.authError = "";
            polkitWindow.isSubmitting = false;
            polkitWindow.showPassword = false;
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
                polkitWindow.showPassword = false;
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
            showPassword = false;
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

    // Modal Card
    Rectangle {
        id: modalBox

        property real shakeOffset: 0

        width: Math.min(parent.width - 40, 500)
        implicitHeight: contentColumn.implicitHeight + 48
        radius: 18
        color: "#141622"
        border.color: "#282c40"
        border.width: 1

        x: (parent.width - width) / 2 + shakeOffset
        y: (parent.height - height) / 2

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: -12; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 12; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: -8; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 8; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: -4; duration: 40; easing.type: Easing.InOutQuad }
            NumberAnimation { target: modalBox; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.InOutQuad }
        }

        // Prevent click from propagating to backdrop
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Shield Icon Container
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 12
                    color: "#20263c"
                    border.color: "#2f3a5a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: "MesloLGS Nerd Font"
                        font.pixelSize: 20
                        color: "#abc7ff"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Authentication Required"
                        font.pixelSize: 17
                        font.bold: true
                        color: "#f0f2fa"
                    }

                    Text {
                        text: "Privileged action requested"
                        font.pixelSize: 12
                        color: "#8990b3"
                    }
                }

                // Close / Cancel Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: closeMouse.containsMouse ? "#3b2630" : "#1f2334"
                    border.color: closeMouse.containsMouse ? "#ffb4ab" : "#2e344a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? "#ffb4ab" : "#8990b3"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: polkitWindow.cancel()
                    }
                }
            }

            // Message Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: messageColumn.implicitHeight + 20
                radius: 12
                color: "#1b1e2c"
                border.color: "#262b3e"
                border.width: 1

                ColumnLayout {
                    id: messageColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: currentFlow && currentFlow.message ? currentFlow.message : "An application is requesting administrative rights."
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: "#e2e6f3"
                        font.pixelSize: 13
                        lineHeight: 1.2
                    }

                    // Action ID badge
                    RowLayout {
                        visible: Boolean(currentFlow && currentFlow.actionId)
                        spacing: 6

                        Text {
                            text: "󰅩"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 12
                            color: "#6c7293"
                        }

                        Text {
                            text: currentFlow && currentFlow.actionId ? currentFlow.actionId : ""
                            color: "#8990b3"
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                    }
                }
            }

            // Identity / User Selection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: Boolean(currentFlow && currentFlow.identities && currentFlow.identities.length > 0)

                Text {
                    text: "User Identity"
                    color: "#8990b3"
                    font.pixelSize: 11
                    font.bold: true
                }

                // If multiple identities, show selectable rows
                Repeater {
                    model: currentFlow ? currentFlow.identities : []

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 8
                        color: (currentFlow && currentFlow.selectedIdentity === modelData) ? "#27304d" : "#1a1d2b"
                        border.color: (currentFlow && currentFlow.selectedIdentity === modelData) ? "#abc7ff" : "#262b3e"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰋑"
                                font.family: "MesloLGS Nerd Font"
                                font.pixelSize: 14
                                color: (currentFlow && currentFlow.selectedIdentity === modelData) ? "#abc7ff" : "#7e85a6"
                            }

                            Text {
                                text: modelData.displayName || "Administrator"
                                font.pixelSize: 12
                                font.bold: currentFlow && currentFlow.selectedIdentity === modelData
                                color: (currentFlow && currentFlow.selectedIdentity === modelData) ? "#f0f2fa" : "#8990b3"
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: currentFlow && currentFlow.selectedIdentity === modelData
                                text: "✓"
                                color: "#abc7ff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (currentFlow) {
                                    currentFlow.selectedIdentity = modelData;
                                }
                            }
                        }
                    }
                }
            }

            // Error Notice Banner
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorRow.implicitHeight + 14
                radius: 8
                color: "#2d1419"
                border.color: "#681d24"
                border.width: 1
                visible: authError !== ""

                RowLayout {
                    id: errorRow
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰀦"
                        font.family: "MesloLGS Nerd Font"
                        font.pixelSize: 14
                        color: "#ffb4ab"
                    }

                    Text {
                        text: authError
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: "#ffb4ab"
                        font.pixelSize: 12
                    }
                }
            }

            // Password Input Row
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: currentFlow && currentFlow.inputPrompt ? currentFlow.inputPrompt.replace(/:$/, '') : "Password"
                    color: "#abc7ff"
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: "#1b1e2c"
                    border.color: passwordInput.activeFocus ? "#abc7ff" : (authError ? "#ff5449" : "#282d40")
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "󰌵"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 14
                            color: passwordInput.activeFocus ? "#abc7ff" : "#6c7293"
                        }

                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            color: "#f0f2fa"
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true
                            echoMode: (currentFlow && currentFlow.responseVisible) || showPassword ? TextInput.Normal : TextInput.Password
                            enabled: !isSubmitting

                            onAccepted: {
                                polkitWindow.submit();
                            }

                            Text {
                                text: "Enter password..."
                                color: "#545a78"
                                font.pixelSize: 13
                                visible: !passwordInput.text && !passwordInput.activeFocus
                            }
                        }

                        // Toggle visibility button
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 6
                            color: eyeMouse.containsMouse ? "#262b3e" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: showPassword ? "󰈈" : "󰈉"
                                font.family: "MesloLGS Nerd Font"
                                font.pixelSize: 14
                                color: showPassword ? "#abc7ff" : (eyeMouse.containsMouse ? "#c0d6ff" : "#7e85a6")
                            }

                            MouseArea {
                                id: eyeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    showPassword = !showPassword;
                                }
                            }
                        }
                    }
                }
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                // Cancel Button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 10
                    color: cancelMouse.containsMouse ? "#252b3e" : "#1a1e2d"
                    border.color: cancelMouse.containsMouse ? "#3f4766" : "#2a3048"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: cancelMouse.containsMouse ? "#f0f2fa" : "#8990b3"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: polkitWindow.cancel()
                    }
                }

                // Authenticate Button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 10
                    color: isSubmitting ? "#6b8ab8" : (authMouse.containsMouse ? "#c5dcff" : "#abc7ff")

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            visible: isSubmitting
                            text: "󰑮"
                            font.family: "MesloLGS Nerd Font"
                            font.pixelSize: 14
                            color: "#002d6c"

                            RotationAnimation on rotation {
                                running: isSubmitting
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }

                        Text {
                            text: isSubmitting ? "Authenticating..." : "Authenticate"
                            color: "#002d6c"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: authMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !isSubmitting
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: polkitWindow.submit()
                    }
                }
            }
        }
    }
}
