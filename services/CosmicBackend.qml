import QtQuick
import Quickshell
import Quickshell.WindowManager
import Quickshell.Cosmic

// COSMIC backend for WindowSource.
//
// Requires a `Quickshell.Cosmic` module, which upstream Quickshell does not
// ship: cosmic-comp implements none of zwlr-foreign-toplevel-management, so
// Quickshell.Wayland.ToplevelManager lists nothing there. Until the patched
// Quickshell is installed this file fails to load and the overview simply
// shows no windows.
//
// The module has to expose exactly this much, all of it available from
// protocols cosmic-comp already advertises:
//
//   Cosmic.toplevels        ObjectModel<CosmicToplevel>  ext-foreign-toplevel-list-v1
//   Cosmic.activeToplevel   CosmicToplevel or null       zcosmic-toplevel-info state
//
//   CosmicToplevel.identifier   string  ext-foreign-toplevel-list identifier
//   CosmicToplevel.title        string
//   CosmicToplevel.appId        string
//   CosmicToplevel.geometry     rect    zcosmic-toplevel-info-v1 geometry event
//   CosmicToplevel.workspaceId  string  ext_workspace_enter, matches Windowset.id
//   CosmicToplevel.minimized    bool    zcosmic-toplevel-info-v1 state
//   CosmicToplevel.activate()           zcosmic-toplevel-manager-v1 activate
//   CosmicToplevel.close()              zcosmic-toplevel-manager-v1 close
//
// plus ScreencopyView.captureSource accepting a CosmicToplevel, via
// ext-foreign-toplevel-image-capture-source-v1 feeding the existing
// ext-image-copy-capture path.
//
// Workspaces need no patch: Quickshell.WindowManager already implements
// ext-workspace-v1, which cosmic-comp advertises.

QtObject {
    id: backend

    signal thumbsInvalidated()

    property bool active: false

    // cosmic-comp has no dim_around equivalent and no layer rules, so the
    // shell has to draw its own dim.
    readonly property bool dimsOverlay: false

    readonly property var rawToplevels: Cosmic.toplevels.values

    readonly property string activeKey: {
        var toplevel = Cosmic.activeToplevel
        return toplevel ? String(toplevel.identifier) : ""
    }

    // A window on an inactive workspace can report no geometry. Falling back to
    // the screen size keeps its aspect ratio plausible instead of collapsing
    // the thumbnail to nothing.
    readonly property size fallbackSize: {
        var screen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        return screen ? Qt.size(screen.width, screen.height) : Qt.size(1920, 1080)
    }

    readonly property var windows: {
        var out = []

        for (var toplevel of (rawToplevels || [])) {
            var geometry = toplevel.geometry
            var sized = geometry && geometry.width > 0 && geometry.height > 0
            var workspace = backend.workspaceById(toplevel.workspaceId)

            out.push({
                key: String(toplevel.identifier),
                title: toplevel.title || "",
                appId: toplevel.appId || "",
                // cosmic-comp reports no class distinct from the app id
                className: "",
                x: sized ? geometry.x : 0,
                y: sized ? geometry.y : 0,
                width: sized ? geometry.width : backend.fallbackSize.width,
                height: sized ? geometry.height : backend.fallbackSize.height,
                workspaceId: toplevel.workspaceId,
                workspaceOrder: (workspace && workspace.coordinates.length > 0)
                                ? workspace.coordinates[0] : 0,
                workspaceName: workspace ? workspace.name : String(toplevel.workspaceId),
                handle: toplevel,
                // A minimized window has no live buffer left to capture
                onscreen: !toplevel.minimized,
                toplevel: toplevel,
                workspace: workspace
            })
        }

        return out
    }

    function workspaceById(id) {
        var sets = WindowManager.windowsets
        for (var i = 0; i < sets.length; ++i) {
            if (sets[i].id === id) return sets[i]
        }
        return null
    }

    // The toplevel list is event driven, there is nothing to pull
    function refresh() {}

    function activateWindow(win) {
        if (win.workspace && win.workspace.canActivate) {
            win.workspace.activate()
        }
        if (win.toplevel) win.toplevel.activate()
    }

    function closeWindow(win) {
        if (win.toplevel) win.toplevel.close()
    }

    // moveCursorTo is deliberately absent: no COSMIC protocol can warp the
    // pointer onto another client's surface, so the option is a no-op here.

    readonly property Connections events: Connections {
        target: Cosmic.toplevels
        ignoreUnknownSignals: true

        function onValuesChanged() {
            if (backend.active) backend.thumbsInvalidated()
        }
    }
}
