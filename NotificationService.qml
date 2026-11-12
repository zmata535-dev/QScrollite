import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var switcherService: null
    property var unread: []
    property var toasts: []
    property bool doNotDisturb: dndSettings.enabled
    property int timeoutSeconds: dndSettings.timeoutSeconds
    property bool notificationCenterOpen: false
    readonly property int unreadCount: unread.length

    property var dndFile: FileView {
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/notification-settings.json"
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: dndSettings
            property bool enabled: false
            property int timeoutSeconds: 3
        }
    }

    function accept(notification) {
        var item = {
            id: notification.id,
            appName: notification.appName || "Notification",
            desktopEntry: notification.desktopEntry || "",
            appIcon: notification.appIcon || "",
            summary: notification.summary || "",
            body: notification.body || "",
            notification: notification
        };

        var nextUnread = unread.slice(0);
        var exists = false;
        for (var i = 0; i < nextUnread.length; i++) {
            if (nextUnread[i].id === item.id) { exists = true; break; }
        }
        if (!exists) {
            nextUnread.push(item);
            unread = nextUnread;
        }

        if (!doNotDisturb) {
            var nextToasts = toasts.slice(0);
            nextToasts.push(item);
            toasts = nextToasts;
        }
    }

    function removeFrom(array, id) {
        var result = [];
        for (var i = 0; i < array.length; i++) {
            if (array[i].id !== id) result.push(array[i]);
        }
        return result;
    }

    function removeToast(id) {
        toasts = removeFrom(toasts, id);
    }

    function openCenter() {
        notificationCenterOpen = true;
    }

    function closeCenter() {
        notificationCenterOpen = false;
    }

    function dismissAllUnread() {
        var pending = unread.slice(0);
        for (var i = 0; i < pending.length; i++) dismiss(pending[i]);
    }

    function markRead(id) {
        unread = removeFrom(unread, id);
        removeToast(id);
    }

    function activate(item) {
        if (!item) return;
        var notification = item.notification;
        if (switcherService) {
            switcherService.calendarTimer.stop();
            switcherService.calendarPending = false;
            switcherService.calendarOpen = false;
        }
        markRead(item.id);
        notificationCenterOpen = false;
        var actions = notification ? notification.actions : [];
        for (var i = 0; actions && i < actions.length; i++) {
            var action = actions[i];
            if (action && action.identifier === "default") {
                action.invoke();
                break;
            }
        }
        Qt.callLater(function() {
            if (root.switcherService)
                root.switcherService.focusNotificationSender(item);
        });
    }

    function dismiss(item) {
        if (!item) return;
        markRead(item.id);
        if (item.notification) item.notification.dismiss();
    }

    function toggleDnd() {
        dndSettings.enabled = !dndSettings.enabled;
        dndFile.writeAdapter();
        if (!dndSettings.enabled && unread.length > 0) {
            toasts = unread.slice(0);
        }
    }

    function setTimeoutSeconds(value) {
        dndSettings.timeoutSeconds = Math.max(1, Math.min(3600, Math.round(Number(value))));
        dndFile.writeAdapter();
    }

    property var notificationServer: NotificationServer {
        id: server
        actionsSupported: true
        persistenceSupported: true
        keepOnReload: true
        onNotification: function(notification) {
            notification.tracked = true;
            var notificationId = notification.id;
            notification.closed.connect(function(reason) {
                root.markRead(notificationId);
            });
            root.accept(notification);
        }
    }
}
