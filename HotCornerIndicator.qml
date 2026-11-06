import QtQuick

Rectangle {
    id: indicator

    required property var service
    required property string corner
    property string screenName: ""

    anchors.fill: parent
    color: "#abc7ff"
    opacity: 0
    radius: 3

    NumberAnimation on opacity {
        id: fadeAnim
        from: 0.8
        to: 0.0
        duration: 350
        easing.type: Easing.OutQuad
        running: false
    }

    Connections {
        target: indicator.service
        function onCornerTriggered(triggeredCorner, triggeredScreen) {
            if (triggeredCorner === indicator.corner && (!triggeredScreen || triggeredScreen === indicator.screenName)) {
                if (indicator.service && indicator.service.visualFeedback) {
                    fadeAnim.restart();
                }
            }
        }
    }
}
