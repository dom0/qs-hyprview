import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import '../layouts'
import '.'

PanelWindow {
    id: root
    property string layoutAlgorithm: "smartgrid"
    property bool liveCapture: false
    property bool moveCursorToActiveWindow: false

    property bool isActive: false
    property bool specialActive: false
    property bool animateWindows: false
    // mappa address -> { x, y } per l'animazione
    property var lastPositions: {}

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: isActive

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isActive ? 1 : 0
    WlrLayershell.namespace: "quickshell:expose"

    IpcHandler {
        target: "expose"
        function toggle() {
            root.toggleExpose()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!root.isActive && ev.name !== "activespecial")
                return

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                    Hyprland.refreshToplevels()
                    refreshThumbs()
                    return

                case "activespecial":
                    var dataStr = String(ev.data)
                    var namePart = dataStr.split(",")[0]
                    root.specialActive = (namePart.length > 0)
                    return

                default:
                    return
            }
        }
    }

    Timer {
        id: screencopyTimer
        interval: 125
        repeat: true
        running: !root.liveCapture && root.isActive
        onTriggered: root.refreshThumbs()
    }

    function toggleExpose() {
        root.isActive = !root.isActive
        if (root.isActive) {
            exposeArea.currentIndex = 0
            exposeArea.searchText = ""
            searchInput.text = ""
            Hyprland.refreshToplevels()
            searchInput.forceActiveFocus()
            refreshThumbs()
        } else {
            root.animateWindows = false
            root.lastPositions = {}
        }
    }

    function refreshThumbs() {
        if (!root.isActive) return

        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i)
            if (it && it.visible && it.refreshThumb) {
                it.refreshThumb()
            }
        }
    }

    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.isActive) return

            if (event.key === Qt.Key_Escape) {
                root.toggleExpose()
                event.accepted = true
                return
            }

            const total = exposeArea.totalWindows
            if (total <= 0) return

            function moveSelectionHorizontal(delta) {
                var count = winRepeater.count
                if (count <= 0) return
                var start = exposeArea.currentIndex
                for (var step = 1; step <= count; ++step) {
                    var candidate = (start + delta * step + count) % count
                    var it = winRepeater.itemAt(candidate)
                    if (it && it.visible) {
                        exposeArea.currentIndex = candidate
                        return
                    }
                }
            }

            function moveSelectionVertical(dir) {
                var count = winRepeater.count
                if (count <= 0) return

                var startIndex = exposeArea.currentIndex
                var currentItem = winRepeater.itemAt(startIndex)

                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? +1 : -1)
                    return
                }

                var curCx = currentItem.x + currentItem.width  / 2
                var curCy = currentItem.y + currentItem.height / 2

                var bestIndex = -1
                var bestDy = 99999999
                var bestDx = 99999999

                for (var i = 0; i < count; ++i) {
                    var it = winRepeater.itemAt(i)
                    if (!it || !it.visible)
                        continue

                    var cx = it.x + it.width  / 2
                    var cy = it.y + it.height / 2

                    var dy = cy - curCy

                    if (dir > 0 && dy <= 0) // DOWN
                        continue
                    if (dir < 0 && dy >= 0) // UP
                        continue

                    var absDy = Math.abs(dy)
                    var absDx = Math.abs(cx - curCx)

                    if (absDy < bestDy || (absDy === bestDy && absDx < bestDx)) {
                        bestDy = absDy
                        bestDx = absDx
                        bestIndex = i
                    }
                }

                if (bestIndex >= 0) {
                    exposeArea.currentIndex = bestIndex
                    return
                }

                // wrap: se non c'è nulla sopra/sotto, scegli il più in alto o il più in basso
                var chosenIndex = -1
                if (dir > 0) { // DOWN
                    var maxCy = -99999999
                    for (var j = 0; j < count; ++j) {
                        var it2 = winRepeater.itemAt(j)
                        if (!it2 || !it2.visible) continue
                        var cy2 = it2.y + it2.height / 2
                        if (cy2 > maxCy) {
                            maxCy = cy2
                            chosenIndex = j
                        }
                    }
                } else { // UP
                    var minCy = 99999999
                    for (var k = 0; k < count; ++k) {
                        var it3 = winRepeater.itemAt(k)
                        if (!it3 || !it3.visible) continue
                        var cy3 = it3.y + it3.height / 2
                        if (cy3 < minCy) {
                            minCy = cy3
                            chosenIndex = k
                        }
                    }
                }

                if (chosenIndex >= 0) {
                    exposeArea.currentIndex = chosenIndex
                }
            }

            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(+1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(+1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex)
                if (item && item.activateWindow) {
                    item.activateWindow()
                    event.accepted = true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.toggleExpose()
            }
        }

        Item {
            id: layout
            anchors.fill: parent
            anchors.margins: 32

            Column {
                id: layoutRoot
                anchors.fill: parent
                anchors.margins: 48
                spacing: 0

                Item {
                    id: exposeArea
                    width: layoutRoot.width
                    height: layoutRoot.height - searchBox.implicitHeight - layoutRoot.spacing

                    property int totalWindows: winRepeater.count

                    property int currentIndex: 0
                    property string searchText: ""

                    property real hGap: 64
                    property real vGap: 64

                    onSearchTextChanged: {
                        currentIndex = (winRepeater.count > 0) ? 0 : -1
                    }

                    Repeater {
                        id: winRepeater
                        model: ScriptModel {
                            values: {
                                var query = (exposeArea.searchText || "").toLowerCase()
                                var windowList = []
                                var idx = 0

                                for (var it of Hyprland.toplevels.values) {
                                    var w = it
                                    var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                                    var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                                    var workspaceId = workspace && workspace.id !== undefined ? workspace.id : undefined

                                    if (workspaceId === undefined || workspaceId === null)
                                        continue

                                    var size = clientInfo && clientInfo.size ? clientInfo.size : [0, 0]
                                    var at = clientInfo && clientInfo.at ? clientInfo.at : [-1000, -1000]

                                    if (at[1] + size[1] <= 0)
                                        continue

                                    var title = (w.title || clientInfo.title || "").toLowerCase()
                                    var clazz = (clientInfo["class"] || "").toLowerCase()
                                    var ic = (clientInfo.initialClass || "").toLowerCase()
                                    var app = (w.appId || clientInfo.initialClass || "").toLowerCase()

                                    if (query && query.length > 0) {
                                        var match =
                                            title.indexOf(query) !== -1 ||
                                            clazz.indexOf(query) !== -1 ||
                                            ic.indexOf(query) !== -1 ||
                                            app.indexOf(query) !== -1
                                        if (!match)
                                            continue
                                    }

                                    windowList.push({
                                        win: w,
                                        clientInfo: clientInfo,
                                        workspaceId: workspaceId,
                                        width: size[0],
                                        height: size[1],
                                        originalIndex: idx++,
                                        lastIpcObject: w.lastIpcObject
                                    })
                                }

                                windowList.sort(function(a, b) {
                                    if (a.workspaceId < b.workspaceId) return -1
                                    if (a.workspaceId > b.workspaceId) return 1
                                    if (a.originalIndex < b.originalIndex) return -1
                                    if (a.originalIndex > b.originalIndex) return 1
                                    return 0
                                })

                                if (["hero", "spiral"].includes(root.layoutAlgorithm)) {
                                    var activeIdx = windowList.findIndex(it => it.lastIpcObject.address ===Hyprland.activeToplevel.lastIpcObject.address)
                                    if (activeIdx !== -1) {
                                      windowList = [windowList[activeIdx], ...windowList.filter(it => it !== windowList[activeIdx])]
                                    }
                                }

                                var maxThumbHeight = exposeArea.height * 0.3
                                return LayoutsManager.doLayout(
                                    root.layoutAlgorithm,
                                    windowList,
                                    exposeArea.width,
                                    exposeArea.height,
                                    exposeArea.hGap,
                                    exposeArea.vGap,
                                    maxThumbHeight
                                )
                            }
                        }

                        delegate: WindowMiniature {
                            hWin: modelData.win
                            wHandle: hWin.wayland

                            winKey: String(hWin.address)

                            thumbW: modelData.width
                            thumbH: modelData.height

                            clientInfo: hWin.lastIpcObject
                            hovered: visible && (exposeArea.currentIndex === index)

                            targetX: modelData.x
                            targetY: modelData.y

                            moveCursorToActiveWindow: root.moveCursorToActiveWindow
                        }
                    }
                }

                Rectangle {
                    id: searchBox
                    width: Math.min(layoutRoot.width * 0.6, 480)
                    height: 36
                    radius: 18
                    color: "#55000000"
                    border.width: 1
                    border.color: "#50ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: "white"
                        font.pixelSize: 14
                        focus: false
                        text: exposeArea.searchText
                        activeFocusOnTab: false

                        onTextChanged: {
                            exposeArea.searchText = text
                            root.animateWindows = true
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Left   ||
                                event.key === Qt.Key_Right  ||
                                event.key === Qt.Key_Up     ||
                                event.key === Qt.Key_Down   ||
                                event.key === Qt.Key_Return ||
                                event.key === Qt.Key_Enter  ||
                                event.key === Qt.Key_Tab    ||
                                event.key === Qt.Key_Backtab) {
                                event.accepted = false
                            }
                            root.animateWindows = true
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: "#ffffffff"
                            font.pixelSize: 14
                            text: "Filtra finestre per titolo..."
                            visible: !searchInput.text || searchInput.text.length === 0
                        }
                    }
                }
            }
        }
    }
}
