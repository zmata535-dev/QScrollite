import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    required property var service

    screen: modelData

    anchors {
        top: true
        right: true
    }

    implicitWidth: service ? service.cornerSize : 12
    implicitHeight: service ? service.cornerSize : 12

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-hotcorner-tr"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    HotCornerIndicator {
        service: window.service
        corner: "top-right"
        screenName: window.modelData ? window.modelData.name : ""
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            if (window.service) {
                window.service.triggerCorner("top-right", window.modelData ? window.modelData.name : "");
            }
        }

        onClicked: {
            if (window.service) {
                window.service.triggerCorner("top-right", window.modelData ? window.modelData.name : "");
            }
        }
    }
}
