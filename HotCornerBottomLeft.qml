import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    required property var service

    screen: modelData

    anchors {
        bottom: true
        left: true
    }

    implicitWidth: service ? service.cornerSize : 12
    implicitHeight: service ? service.cornerSize : 12

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-hotcorner-bl"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    HotCornerIndicator {
        service: window.service
        corner: "bottom-left"
        screenName: window.modelData ? window.modelData.name : ""
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            if (window.service) {
                window.service.triggerCorner("bottom-left", window.modelData ? window.modelData.name : "");
            }
        }

        onClicked: {
            if (window.service) {
                window.service.triggerCorner("bottom-left", window.modelData ? window.modelData.name : "");
            }
        }
    }
}
