import QtQuick
import Quickshell
import './modules'

ShellRoot {
  Hyprview {
    // scegli il layout: 'bands', 'smartgrid', 'spiral', 'hero', 'masonry', 'justified',
    layoutAlgorithm: "smartgrid"
    liveCapture: false
    moveCursorToActiveWindow: false
  }
}
