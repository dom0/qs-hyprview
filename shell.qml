import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root
    property bool liveCapture: false

    property bool isActive: false
    property bool specialActive: false
    property bool animateWindows: false

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
            root.toggleExpose(); 
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!root.isActive && ev.name !== "activespecial")
                return;

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                    Hyprland.refreshToplevels();
                    refreshThumbs();
                    return

                case "activespecial":
                    var dataStr = String(ev.data);
                    var namePart = dataStr.split(",")[0];
                    root.specialActive = (namePart.length > 0);
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
        root.isActive = !root.isActive;
        if (root.isActive) {
            exposeArea.currentIndex = 0;
            exposeArea.searchText = "";
            searchInput.text = "";
            Hyprland.refreshToplevels();
            searchInput.forceActiveFocus();
            refreshThumbs();
          } else {
            root.animateWindows = false
          }
    }

    function refreshThumbs() {
        if (!root.isActive) return;

        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i);
            if (it && it.visible) {
                it.refreshThumb();
            }
        }
    }

    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.isActive) return;

            if (event.key === Qt.Key_Escape) {
                root.toggleExpose();
                event.accepted = true;
                return;
            }

            const total = exposeArea.totalWindows;
            if (total <= 0) return;

            function moveSelectionHorizontal(delta) {
                var count = winRepeater.count;
                if (count <= 0) return;
                var start = exposeArea.currentIndex;
                for (var step = 1; step <= count; ++step) {
                    var candidate = (start + delta * step + count) % count;
                    var it = winRepeater.itemAt(candidate);
                    if (it && it.visible) {
                        exposeArea.currentIndex = candidate;
                        return;
                    }
                }
            }

            function moveSelectionVertical(dir) {
                var count = winRepeater.count;
                if (count <= 0) return;

                var startIndex = exposeArea.currentIndex;
                var currentItem = winRepeater.itemAt(startIndex);

                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? +1 : -1);
                    return;
                }

                var targetRow = currentItem.rowIndex + dir;

                var bestIndex = -1;
                var bestDist = 999999;

                for (var i = 0; i < count; ++i) {
                    var it = winRepeater.itemAt(i);
                    if (!it || !it.visible)
                        continue;
                    if (it.rowIndex !== targetRow)
                        continue;

                    var d = Math.abs(it.colIndex - currentItem.colIndex);
                    if (d < bestDist) {
                        bestDist = d;
                        bestIndex = i;
                    }
                }

                if (bestIndex >= 0) {
                    exposeArea.currentIndex = bestIndex;
                    return;
                }

                // wrap se non c'è una riga sopra/sotto
                if (dir > 0) {
                    // Down: ultima visibile
                    for (var j = count - 1; j >= 0; --j) {
                        var it2 = winRepeater.itemAt(j);
                        if (it2 && it2.visible) {
                            exposeArea.currentIndex = j;
                            return;
                        }
                    }
                } else {
                    // Up: prima visibile
                    for (var k = 0; k < count; ++k) {
                        var it3 = winRepeater.itemAt(k);
                        if (it3 && it3.visible) {
                            exposeArea.currentIndex = k;
                            return;
                        }
                    }
                }
            }

            // Right / Tab => avanti (lineare)
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(+1);
                event.accepted = true;
            }
            // Left / Backtab => indietro (lineare)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1);
                event.accepted = true;
            }
            // Down => riga sotto
            else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(+1);
                event.accepted = true;
            }
            // Up => riga sopra
            else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1);
                event.accepted = true;
            }
            // Enter attiva la finestra corrente
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex);
                if (item && item.activateWindow) {
                    item.activateWindow();
                    event.accepted = true;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.toggleExpose();
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

                    property int visibleWindows: {
                        var count = winRepeater.count;
                        var vis = 0;
                        for (var i = 0; i < count; ++i) {
                            var it = winRepeater.itemAt(i);
                            if (it && it.visible)
                                vis++;
                        }
                        return vis;
                    }

                    property int totalWindows: visibleWindows > 0 ? visibleWindows : 0

                    property int columns: Math.max(1, Math.ceil(Math.sqrt(totalWindows > 0 ? totalWindows : 1)))
                    property int rows: Math.max(1, Math.ceil((totalWindows > 0 ? totalWindows : 1) / columns))

                    property real cellW: width  / columns
                    property real cellH: height / rows

                    property int currentIndex: 0
                    property string searchText: ""


                    onSearchTextChanged: {
                        var count = winRepeater.count;
                        for (var i = 0; i < count; ++i) {
                            var it = winRepeater.itemAt(i);
                            if (it && it.visible) {
                                currentIndex = i;
                                return;
                            }
                        }
                        currentIndex = 0;
                    }

                    // --- GRIGLIA DI MINIATURE ---
                    Repeater {
                        id: winRepeater
                        // model: Hyprland.toplevels
                        model: ScriptModel {
                            values: {
                                let windowsList = []
                                for (let w of Hyprland.toplevels.values)  {
                                  windowsList.push(w)
                                }
                                windowsList = windowsList.filter(w => {
                                  let clientInfo = w?.lastIpcObject ?? {}
                                  let workspaceId = clientInfo?.workspace?.id ?? false
                                  let size = clientInfo?.size ?? [0, 0]
                                  let at = clientInfo?.at ?? [-1000, -1000]
                                  return workspaceId !== false && at[1] + size[1] > 0
                                })

                                windowsList.sort((a, b) => a.lastIpcObject.workspace.id < b.lastIpcObject.workspace.id ? -1 :1)
                                return windowsList
                            }
                        }

                        delegate: Item {
                            id: delegateItem
                            property var hWin: modelData
                            property var wHandle: hWin.wayland

                            property var clientInfo: hWin.lastIpcObject
                            property int clientWidth: clientInfo && clientInfo.size ? clientInfo.size[0] : 0
                            property int clientHeight: clientInfo && clientInfo.size ? clientInfo.size[1] : 0
                            property int clientX: clientInfo && clientInfo.at ? clientInfo.at[0] : 0
                            property int clientY: clientInfo && clientInfo.at ? clientInfo.at[1] : 0

                            property bool matches: {
                                var q = exposeArea.searchText.toLowerCase();
                                if (!q || q.length === 0) return true;

                                var t  = (hWin.title || (clientInfo ? clientInfo.title : "") || "").toLowerCase();
                                var c  = ((clientInfo ? clientInfo["class"] : "") || "").toLowerCase();
                                var ic = ((clientInfo && clientInfo.initialClass) ? clientInfo.initialClass : "").toLowerCase();
                                var app = (hWin.appId || (clientInfo ? clientInfo.initialClass : "") || "").toLowerCase();
                                return t.indexOf(q)  !== -1 || c.indexOf(q)  !== -1 || ic.indexOf(q) !== -1 || app.indexOf(q) !== -1;
                            }

                            property bool hovered: visible && (exposeArea.currentIndex === index)

                            property int compactIndex: {
                                if (!visible) return -1;
                                var c = 0;
                                for (var i = 0; i < winRepeater.count; ++i) {
                                    var it = winRepeater.itemAt(i);
                                    if (!it || !it.visible)
                                        continue;
                                    if (i === index)
                                        return c;
                                    c++;
                                }
                                return -1;
                            }

                            property int rowIndex: compactIndex >= 0 ? Math.floor(compactIndex / exposeArea.columns) : 0
                            property int colIndex: compactIndex >= 0 ? (compactIndex % exposeArea.columns) : 0

                            // --- CALCOLO CENTRATURA RIGA ---
                            property int itemsInThisRow: {
                                // Se non è l'ultima riga, è piena
                                if (rowIndex < exposeArea.rows - 1) return exposeArea.columns;
                                
                                // Calcolo elementi nell'ultima riga
                                var remainder = exposeArea.totalWindows % exposeArea.columns;
                                return (remainder === 0) ? exposeArea.columns : remainder;
                            }

                            // Offset per centrare: (SpazioTotale - SpazioOccupatoDalleCelle) / 2
                            property real rowOffset: (exposeArea.width - (itemsInThisRow * exposeArea.cellW)) / 2

                            property real maxThumbW: exposeArea.cellW * 0.9
                            property real maxThumbH: exposeArea.cellH * 0.9

                            property real baseScale: Math.min(
                                maxThumbW / (clientWidth > 0 ? clientWidth : 1),
                                maxThumbH / (clientHeight > 0 ? clientHeight : 1),
                                1.0
                            )

                            property real thumbW: (clientWidth > 0 ? clientWidth : 0) * baseScale
                            property real thumbH: (clientHeight > 0 ? clientHeight : 0)  * baseScale

                            width:  exposeArea.cellW
                            height: exposeArea.cellH
                            
                            x: rowOffset + (colIndex * exposeArea.cellW)
                            y: rowIndex * exposeArea.cellH
                            
                            Behavior on x {
                                NumberAnimation { duration: root.animateWindows ? 100 : 0; easing.type: Easing.OutQuad }
                            }
                            Behavior on y {
                                NumberAnimation { duration: root.animateWindows ? 100 : 0; easing.type: Easing.OutQuad }
                            }

                            visible: !!wHandle && matches


                            function activateWindow() {
                                if (!hWin) return;

                                var targetIsSpecial = (hWin?.workspace ?? 0) < 0 || (hWin?.workspace?.name??"").startsWith("special")

                                if (root.specialActive && !targetIsSpecial) {
                                    Hyprland.dispatch("togglespecialworkspace");
                                }

                                if (hWin.workspace) {
                                    hWin.workspace.activate();
                                }

                                Hyprland.dispatch("focuswindow address:0x" + hWin.address);
                                root.toggleExpose();
                            }

                            function closeWindow() {
                                if (!hWin) return;
                                Hyprland.dispatch("closewindow address:0x" + hWin.address);
                            }

                            function refreshThumb() {
                                thumbLoader.item.captureFrame();
                            }

                            // --- card ---
                            Item {
                                id: card
                                width: delegateItem.thumbW
                                height: delegateItem.thumbH

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter:   parent.verticalCenter

                                scale: delegateItem.hovered ? 1.05 : 0.95
                                transformOrigin: Item.Center

                                Behavior on scale {
                                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                    onEntered: {
                                        exposeArea.currentIndex = index;
                                    }
                                    onClicked: event => {
                                        exposeArea.currentIndex = index;

                                        if (event.button === Qt.LeftButton) {
                                            delegateItem.activateWindow();
                                        }
                                        if (event.button === Qt.MiddleButton) {
                                            delegateItem.closeWindow();
                                        }
                                    }
                                }

                                RectangularShadow {
                                    anchors.fill: parent
                                    radius: 16
                                    blur: 24
                                    spread: 10
                                    color: "#55000000"
                                    cached: true
                                }

                                Loader {
                                    id: thumbLoader
                                    anchors.fill: parent
                                    active: root.isActive && !!delegateItem.wHandle
                                    sourceComponent: ScreencopyView {
                                        id: thumb
                                        anchors.fill: parent
                                        captureSource: delegateItem.wHandle
                                        live: root.liveCapture && root.isActive
                                        paintCursor: false
                                        visible: root.isActive && delegateItem.wHandle && hasContent

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: thumb.width
                                                height: thumb.height
                                                radius: 16
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: delegateItem.hovered ? "transparent": "#33000000"
                                            border.width : delegateItem.hovered ? 3 : 1
                                            border.color : delegateItem.hovered ? "#ff0088cc" : "#cc444444"
                                            radius: 16
                                        }
                                    }
                                }

                                Rectangle {
                                    id: badge
                                    z: 100
                                    width: Math.min(titleText.implicitWidth + 24, delegateItem.thumbW * 0.75)
                                    height: titleText.implicitHeight + 12

                                    x: (card.width - width) / 2
                                    y: card.height - height - (card.height * 0.08)

                                    radius: 12
                                    color: delegateItem.hovered ? "#FF000000" : "#CC000000"
                                            border.width : 1
                                            border.color : "#ff464646"

                                    Text {
                                        id: titleText
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        text: hWin.title
                                        color: "white"
                                        font.pixelSize: delegateItem.hovered ? 13 : 12
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // BARRA DI RICERCA
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
                            exposeArea.searchText = text;
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
                                event.accepted = false;
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
