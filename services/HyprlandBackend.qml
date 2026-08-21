import QtQuick
import Quickshell.Hyprland

// Hyprland backend for WindowSource.
//
// Window geometry, class and workspace all come from the Hyprland IPC client
// object (lastIpcObject), which is the only place that carries them.

QtObject {
    id: backend

    signal thumbsInvalidated()

    property bool active: false

    // Hyprland dims behind the overlay itself, through the dim_around
    // layerrule documented in the README.
    readonly property bool dimsOverlay: true

    // True while a special workspace is on screen. Focusing a window that is
    // not on it has to toggle it away first, or the window stays hidden.
    property bool specialActive: false

    readonly property var rawToplevels: Hyprland.toplevels.values

    readonly property string activeKey: {
        var address = Hyprland.activeToplevel?.lastIpcObject?.address
        return address ? String(address) : ""
    }

    readonly property var windows: {
        var out = []

        for (var toplevel of (rawToplevels || [])) {
            var client = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : {}
            var workspace = client.workspace ?? null
            var workspaceId = (workspace && workspace.id !== undefined) ? workspace.id : undefined

            // A window without a workspace is not mapped anywhere yet
            if (workspaceId === undefined || workspaceId === null) continue

            var size = client.size ?? [0, 0]
            var at = client.at ?? [-1000, -1000]

            out.push({
                key: String(toplevel.address),
                title: toplevel.title || client.title || "",
                appId: toplevel.appId || client.initialClass || "",
                className: client["class"] || "",
                x: at[0],
                y: at[1],
                width: size[0],
                height: size[1],
                workspaceId: workspaceId,
                workspaceOrder: workspaceId,
                workspaceName: (workspace && workspace.name) ? workspace.name : String(workspaceId),
                handle: toplevel.wayland,
                // Windows parked above the viewport (hidden special workspaces)
                onscreen: (at[1] + size[1]) > 0,
                toplevel: toplevel
            })
        }

        return out
    }

    function refresh() {
        Hyprland.refreshToplevels()
    }

    function activateWindow(win) {
        var targetIsSpecial = win.workspaceId < 0 || String(win.workspaceName).startsWith("special")
        if (backend.specialActive && !targetIsSpecial) {
            Hyprland.dispatch("togglespecialworkspace")
        }

        if (win.toplevel && win.toplevel.workspace) {
            win.toplevel.workspace.activate()
        }

        Hyprland.dispatch("focuswindow address:0x" + win.key)
        Hyprland.dispatch("alterzorder top")
    }

    function closeWindow(win) {
        Hyprland.dispatch("closewindow address:0x" + win.key)
    }

    function moveCursorTo(win) {
        var cx = win.x + (win.width / 2)
        var cy = win.y + (win.height / 2)
        Hyprland.dispatch("movecursor " + cx + " " + cy)
    }

    readonly property Connections events: Connections {
        target: Hyprland

        function onRawEvent(ev) {
            if (!backend.active && ev.name !== "activespecial") return

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                case "movewindow":
                Hyprland.refreshToplevels()
                backend.thumbsInvalidated()
                return

                case "activespecial":
                var namePart = String(ev.data).split(",")[0]
                backend.specialActive = (namePart.length > 0)
                return

                default:
                return
            }
        }
    }
}
