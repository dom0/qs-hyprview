import QtQuick
import Quickshell
import "./modules"
import "./common"

ShellRoot {
    id: root

    Appearance { id: m3 }

    Hyprview {
        liveCapture: true
        moveCursorToActiveWindow: false
    }
}
