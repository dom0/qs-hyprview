pragma Singleton

import QtQuick
import Quickshell

// Compositor-independent window source.
//
// Every consumer in this project (the overview, the thumbnails, the layouts)
// talks to this singleton only, and never to a compositor module directly.
// The compositor is detected at startup and the matching backend is created
// from its own file, so a backend whose Quickshell module is missing degrades
// to "no windows" instead of breaking the whole config.
//
// A backend exposes:
//   windows        - list of normalized window records, see below
//   activeKey      - key of the currently focused window, "" when unknown
//   active         - set by the overview; backends use it to skip work
//   refresh()      - pull a fresh window list, for backends that poll
//   activateWindow(win) / closeWindow(win)
//   moveCursorTo(win)   - optional
//   dimsOverlay    - true when the compositor already dims behind the
//                    overlay's layer, so the shell must not dim twice
//   thumbsInvalidated() - signal, the window set changed on screen
//
// A window record is a plain object:
//   key            string   stable per-window id, also the thumbnail identity
//   title          string   window title, shown on the badge and searched
//   appId          string   application id, searched
//   className      string   secondary search field, "" when the compositor
//                           has no separate class
//   x, y           real     window position, Hyprland global / COSMIC per-output
//   width, height  real     real window size: every layout derives its
//                           aspect ratios from these two
//   workspaceId    var      grouping key, used by BandsLayout
//   workspaceOrder real     sort key, so bands appear in workspace order
//   workspaceName  string
//   handle         QtObject value for ScreencopyView.captureSource
//   onscreen       bool     false for windows the overview must skip
//   toplevel       QtObject the backend's native object, backend use only

Singleton {
    id: root

    readonly property string compositor: {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "hyprland"
        var desktop = String(Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
        if (desktop.indexOf("cosmic") !== -1) return "cosmic"
        return ""
    }

    readonly property var backendFiles: ({
        "hyprland": "HyprlandBackend.qml",
        "cosmic": "CosmicBackend.qml"
    })

    property QtObject backend: null

    readonly property var windows: backend ? backend.windows : []
    readonly property string activeKey: backend ? backend.activeKey : ""

    // Assume we have to dim ourselves until a backend says otherwise
    readonly property bool dimsOverlay: backend ? backend.dimsOverlay : false

    // Set by the overview while it is visible. Backends use it to avoid
    // reacting to window events nobody is looking at.
    property bool active: false
    onActiveChanged: if (backend) backend.active = active

    signal thumbsInvalidated()

    function refresh() {
        if (backend && backend.refresh) backend.refresh()
    }

    function activateWindow(win) {
        if (backend && win) backend.activateWindow(win)
    }

    function closeWindow(win) {
        if (backend && win) backend.closeWindow(win)
    }

    function moveCursorTo(win) {
        if (backend && win && backend.moveCursorTo) backend.moveCursorTo(win)
    }

    readonly property Connections backendEvents: Connections {
        target: root.backend
        ignoreUnknownSignals: true
        function onThumbsInvalidated() { root.thumbsInvalidated() }
    }

    Component.onCompleted: {
        var file = root.backendFiles[root.compositor]
        if (!file) {
            console.warn("WindowSource: unsupported compositor, no windows will be listed")
            return
        }

        var component = Qt.createComponent(file)
        if (component.status !== Component.Ready) {
            console.warn("WindowSource: " + root.compositor + " backend unavailable: "
                         + component.errorString().trim())
            return
        }

        root.backend = component.createObject(root)
        root.backend.active = root.active
    }
}
