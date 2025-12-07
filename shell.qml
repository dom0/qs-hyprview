import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root
    property bool isActive: false
    property bool specialActive: false

    property var hyprClients: ({})

    function updateHyprClients(jsonText) {
        try {
            var arr = JSON.parse(jsonText);
            var map = {};
            for (var i = 0; i < arr.length; ++i) {
                var c = arr[i];
                map[c.address] = c;
            }
            hyprClients = map;
        } catch (e) {
            console.log("hyprClients: parse error", e);
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "#dd000000"
    visible: isActive

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isActive ? 1 : 0
    WlrLayershell.namespace: "qs-expose"

    IpcHandler {
        target: "expose"
        function toggle() { root.toggleExpose(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activespecial") return;

            var dataStr = String(ev.data);
            var namePart = dataStr.split(",")[0];
            root.specialActive = (namePart.length > 0);
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.updateHyprClients(clientsCollector.text);
            }
        }
    }

    function toggleExpose() {
        root.isActive = !root.isActive;
        if (root.isActive) {
            exposeArea.mouseActive = false;
            exposeArea.searchText = "";
            searchInput.text = "";
            exposeArea.resetCurrentIndexToActive();
            searchInput.forceActiveFocus();
            getClients.running = true;
        }
    }

    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        scale: root.isActive ? 1 : 0.1
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Keys.onPressed: (event) => {
            if (!root.isActive) return;

            // ESC chiude sempre
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

            const isTabForward  = (event.key === Qt.Key_Tab);
            const isTabBackward = (event.key === Qt.Key_Backtab);

            // Right / Tab => avanti (lineare)
            if (event.key === Qt.Key_Right || isTabForward) {
                moveSelectionHorizontal(+1);
                event.accepted = true;
            }
            // Left / Backtab => indietro (lineare)
            else if (event.key === Qt.Key_Left || isTabBackward) {
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
            onPositionChanged: {
                exposeArea.mouseActive = true;
            }
        }

        Rectangle {
            id: layout
            anchors.fill: parent
            anchors.margins: 32
            radius: 32
            color: "transparent"
            border.width: 0
            clip: true

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
                    property bool mouseActive: false

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

                    function resetCurrentIndexToActive() {
                        var count = winRepeater.count;
                        if (count <= 0) {
                            currentIndex = 0;
                            return;
                        }

                        var active = Hyprland.activeToplevel;
                        var activeAddr = active ? active.address : "";

                        if (activeAddr && !activeAddr.startsWith("0x"))
                            activeAddr = "0x" + activeAddr;

                        if (activeAddr) {
                            for (var i = 0; i < count; ++i) {
                                var it = winRepeater.itemAt(i);
                                if (!it || !it.hWin || !it.visible)
                                    continue;
                                var addr = it.hWin.address;
                                if (!addr)
                                    continue;
                                if (!addr.startsWith("0x"))
                                    addr = "0x" + addr;
                                if (addr === activeAddr) {
                                    currentIndex = i;
                                    return;
                                }
                            }
                        }

                        for (var j = 0; j < count; ++j) {
                            var it2 = winRepeater.itemAt(j);
                            if (it2 && it2.visible) {
                                currentIndex = j;
                                return;
                            }
                        }
                        currentIndex = 0;
                    }

                    // --- GRIGLIA DI MINIATURE CON REPACK ANIMATO ---
                    Repeater {
                        id: winRepeater
                        model: Hyprland.toplevels

                        delegate: Item {
                            id: delegateItem
                            property var hWin: modelData
                            property var wHandle: hWin.wayland

                            property var clientInfo: root.hyprClients["0x" + hWin.address]

                            property bool matches: {
                                var q = exposeArea.searchText.toLowerCase();
                                if (!q || q.length === 0) return true;

                                var t  = (hWin.title || (clientInfo ? clientInfo.title : "") || "").toLowerCase();
                                var c  = ((clientInfo ? clientInfo["class"] : "") || "").toLowerCase();
                                var ic = ((clientInfo && clientInfo.initialClass) ? clientInfo.initialClass : "").toLowerCase();
                                var app = (hWin.appId || (clientInfo ? clientInfo.initialClass : "") || "").toLowerCase();

                                return t.indexOf(q)  !== -1 || c.indexOf(q)  !== -1 || ic.indexOf(q) !== -1 || app.indexOf(q) !== -1;
                            }

                            property int clientWidth: clientInfo ? clientInfo.size[0] : 0
                            property int clientHeight: clientInfo ? clientInfo.size[1] : 0

                            property bool hovered: visible && (exposeArea.currentIndex === index)

                            property int compactIndex: {
                                if (!visible)
                                    return -1;
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

                            property real srcW: clientWidth
                            property real srcH: clientHeight

                            property real maxThumbW: exposeArea.cellW * 0.9
                            property real maxThumbH: exposeArea.cellH * 0.9

                            property real baseScale: Math.min(maxThumbW / srcW, maxThumbH / srcH, 1.0)

                            property real thumbW: srcW * baseScale
                            property real thumbH: srcH * baseScale

                            property real maxBadgeWidth: thumbW * 0.75

                            width:  exposeArea.cellW
                            height: exposeArea.cellH

                            x: colIndex * exposeArea.cellW
                            y: rowIndex * exposeArea.cellH

                            Behavior on x {
                                NumberAnimation { duration: mainScope.scale===1 ? 100 : 0; easing.type: Easing.OutQuad }
                            }
                            Behavior on y {
                                NumberAnimation { duration: mainScope.scale===1 ? 100 : 0; easing.type: Easing.OutQuad }
                            }

                            visible: !!wHandle && matches

                            function isSpecialWindow() {
                                if (!hWin.workspace)
                                    return false;
                                if (hWin.workspace.id < 0)
                                    return true;
                                if (hWin.workspace.name && hWin.workspace.name.startsWith("special"))
                                    return true;
                                return false;
                            }

                            function activateWindow() {
                                if (!hWin)
                                    return;

                                var addr = hWin.address;
                                if (!addr || addr === "")
                                    return;
                                if (!addr.startsWith("0x"))
                                    addr = "0x" + addr;

                                var targetIsSpecial = isSpecialWindow();

                                if (root.specialActive && !targetIsSpecial) {
                                    Hyprland.dispatch("togglespecialworkspace");
                                }

                                if (hWin.workspace) {
                                    hWin.workspace.activate();
                                }

                                Hyprland.dispatch("focuswindow address:" + addr);
                                root.toggleExpose();
                            }

                            // --- card ---
                            Rectangle {
                                id: card
                                width: delegateItem.thumbW
                                height: delegateItem.thumbH

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter:   parent.verticalCenter

                                color: "#00000000"
                                border.color : "#ff0088cc"
                                border.width : delegateItem.hovered ? 3 : 0
                                radius: 12
                                scale: delegateItem.hovered ? 1.05 : 0.95
                                transformOrigin: Item.Center

                                Behavior on scale {
                                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                                }

                                opacity: delegateItem.hovered ? 1.0 : 0.85
                                Behavior on opacity {
                                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        if (exposeArea.mouseActive) {
                                            exposeArea.currentIndex = index;
                                        }
                                    }
                                    onClicked: {
                                        exposeArea.currentIndex = index;
                                        delegateItem.activateWindow();
                                    }
                                }


                                ScreencopyView {
                                    id: thumb
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    captureSource: wHandle
                                    live: mainScope.scale===1 && root.isActive // && delegateItem.hovered
                                    paintCursor: false
                                    constraintSize: Qt.size(width, height)
                                    visible: root.isActive && wHandle && hasContent

                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: delegateItem.thumbW
                                            height: delegateItem.thumbH
                                            radius: 12
                                        }
                                    }
                                }


                                Rectangle {
                                    id: badge
                                    z: 100
                                    width: Math.min(titleText.implicitWidth + 24, delegateItem.maxBadgeWidth)
                                    height: titleText.implicitHeight + 12

                                    x: (card.width - width) / 2
                                    y: card.height - height - (card.height * 0.08)

                                    radius: 12
                                    color: "#DD000000"
                                    border.width: 0

                                    Text {
                                        id: titleText
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        text: hWin.title
                                        color: "white"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                            }
                        }
                    }
                }

                // BARRA DI RICERCA (sempre sotto le miniature)
                Rectangle {
                    id: searchBox
                    width: Math.min(layoutRoot.width * 0.6, 480)
                    height: 36
                    radius: 18
                    color: "#33000000"
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
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: "#80ffffff"
                            font.pixelSize: 14
                            text: "Filtra finestre per titolo..."
                            visible: !searchInput.text || searchInput.text.length === 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchInput.forceActiveFocus();
                            exposeArea.mouseActive = false;
                        }
                    }
                }
            }
        }
    }
}


