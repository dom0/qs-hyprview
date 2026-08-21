import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import "../services"

Item {
    id: thumbContainer

    // Normalized window record, see services/WindowSource.qml
    property var win: null

    readonly property var wHandle: win ? win.handle : null
    readonly property string winKey: win ? win.key : ''

    property real thumbW: -1
    property real thumbH: -1

    property bool hovered: false

    property real targetX: -1000
    property real targetY: -1000
    property real targetZ: 0
    property real targetRotation: 0

    property bool moveCursorToActiveWindow: false

    width: thumbW
    height: thumbH

    x: 0
    y: 0
    z: targetZ
    rotation: 0

    visible: !!wHandle

    NumberAnimation {
        id: animX
        target: thumbContainer
        property: "x"
        duration: root.animateWindows ? 100 : 0
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: animY
        target: thumbContainer
        property: "y"
        duration: root.animateWindows ? 100 : 0
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: animRotation
        target: thumbContainer
        property: "rotation"
        duration: 400
        easing.type: Easing.OutBack // Effetto rimbalzo/inerzia
        easing.overshoot: 1.2
    }

    function updateLastPos() {
        var lp = root.lastPositions || ({})
        var prev = lp[winKey] || ({})
        prev.x = x
        prev.y = y
        lp[winKey] = prev
        root.lastPositions = lp
    }

    onTargetXChanged: {
        if (!root.animateWindows) {
            x = targetX
            updateLastPos()
            return
        }

        var lp = root.lastPositions || ({})
        var prev = lp[winKey]
        var startX = (prev && prev.x !== undefined) ? prev.x : targetX

        if (startX === targetX) {
            x = targetX
            updateLastPos()
            return
        }

        animX.stop()
        animX.from = startX
        animX.to = targetX
        animX.start()
    }

    onTargetYChanged: {
        if (!root.animateWindows) {
            y = targetY
            updateLastPos()
            return
        }

        var lp = root.lastPositions || ({})
        var prev = lp[winKey]
        var startY = (prev && prev.y !== undefined) ? prev.y : targetY

        if (startY === targetY) {
            y = targetY
            updateLastPos()
            return
        }

        animY.stop()
        animY.from = startY
        animY.to = targetY
        animY.start()
    }

    onTargetRotationChanged: {
        rotation = targetRotation
        animRotation.stop()
        animRotation.from = 0
        animRotation.to = targetRotation
        animRotation.start()
    }

    onXChanged: updateLastPos()
    onYChanged: updateLastPos()

    Component.onCompleted: {
        rotation = targetRotation
        if (!root.animateWindows) {
            x = targetX
            y = targetY
            updateLastPos()
        }
    }

    function activateWindow() {
        if (!win) return

        // The activation request has to go out before the overlay is hidden:
        // unmapping the layer surface can take the connection down with it, and
        // then the focus change never reaches the compositor.
        WindowSource.activateWindow(win)

        if (thumbContainer.moveCursorToActiveWindow) {
            WindowSource.moveCursorTo(win)
        }

        root.toggleExpose()
    }

    function closeWindow() {
        if (!win) return
        WindowSource.closeWindow(win)
    }

    function refreshThumb() {
        if (thumbLoader.item) {
            thumbLoader.item.captureFrame()
        }
    }

    Item {
        id: card
        anchors.fill: parent

        scale: thumbContainer.hovered ? 1.05 : 0.95
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
                exposeArea.currentIndex = index
            }
            onClicked: event => {
                exposeArea.currentIndex = index

                if (event.button === Qt.LeftButton) {
                    thumbContainer.activateWindow()
                }
                if (event.button === Qt.MiddleButton) {
                    thumbContainer.closeWindow()
                }
            }
            onExited: {
                if (exposeArea.currentIndex === index) {
                    exposeArea.currentIndex = -1
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
            active: root.isActive && !!thumbContainer.wHandle
            sourceComponent: ScreencopyView {
                id: thumb
                anchors.fill: parent
                captureSource: thumbContainer.wHandle
                live: root.liveCapture && root.isActive
                paintCursor: false
                visible: root.isActive && thumbContainer.wHandle && hasContent

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
                    color: thumbContainer.hovered ? "transparent": "#33000000"
                    border.width : thumbContainer.hovered ? 3 : 1
                    border.color : thumbContainer.hovered ? m3.m3Primary : m3.m3Secondary
                    radius: 16
                }
            }
        }

        Rectangle {
            id: badge
            z: 100
            width: Math.min(titleText.implicitWidth + 24, thumbContainer.thumbW * 0.75)
            height: titleText.implicitHeight + 12

            x: (card.width - width) / 2
            y: card.height - height - (card.height * 0.08)

            radius: 12
            color: thumbContainer.hovered ? "#FF000000" : "#CC000000"
            border.width : 1
            border.color : "#ff464646"

            Text {
                id: titleText
                anchors.centerIn: parent
                width: parent.width - 16
                text: win ? win.title : ""
                color: "white"
                font.pixelSize: thumbContainer.hovered ? 13 : 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
