import QtQuick

// Native scene animation: a static background plus a small moving item/patch.
Item {
    id: motion
    required property string backgroundPath
    property bool active: false
    property bool animationEnabled: true
    readonly property string name: backgroundPath.split("/").pop()
    readonly property bool busScene: name === "london.png"
    readonly property bool palace: name === "buckingham-palace.png"
    readonly property bool supported: busScene || palace || name === "windsor-castle-phone-box.png"
    readonly property real imageWidth: busScene ? 3840 : 1672
    readonly property real imageHeight: busScene ? 2160 : 941
    readonly property real fitScale: Math.max(width / imageWidth, height / imageHeight)
    property real seconds: 0
    property date clockTime: new Date()
    visible: active && supported && picture.status === Image.Ready
    clip: true

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: motion.visible && motion.busScene && motion.animationEnabled
        onTriggered: {
            const now = new Date()
            if (now.getHours() !== motion.clockTime.getHours() || now.getMinutes() !== motion.clockTime.getMinutes())
                motion.clockTime = now
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: motion.visible && motion.animationEnabled
        onTriggered: motion.seconds = (motion.seconds + 0.05) % 660
    }

    Item {
        id: scene
        width: motion.imageWidth
        height: motion.imageHeight
        x: (motion.width - width) / 2
        y: (motion.height - height) / 2
        scale: motion.fitScale

        Image {
            id: picture
            anchors.fill: parent
            source: !motion.backgroundPath ? "" : motion.busScene ? Qt.resolvedUrl("assets/london-base.png") : "file://" + motion.backgroundPath
            asynchronous: true
            smooth: true
            mipmap: true
        }

        ClockHands {
            visible: motion.busScene
            x: 1550
            y: 1150
            width: 56
            height: 56
            time: motion.clockTime
        }

        Image {
            visible: motion.busScene
            source: "assets/wheel.png"
            x: 2334
            y: 1016
            width: 532
            height: 532
            rotation: motion.seconds * 360 / 220
            transformOrigin: Item.Center
            smooth: true
        }

        Image {
            visible: motion.busScene
            source: "assets/bus.png"
            width: 164
            height: 86
            // 110-second crossing; wrap only while fully outside the frame.
            readonly property real bridgeX: ((1195 + motion.seconds * 2110 / 110) % 2110) - 100
            x: bridgeX * 2
            // Follow the same quadratic curve as the bridge's top edge.
            readonly property real bridgeT: Math.max(0, Math.min(1, (bridgeX + 41) / 1920))
            y: 2 * (821 - 88 * bridgeT + 74 * bridgeT * bridgeT - 48)
            smooth: true
        }

        Canvas {
            id: flag
            visible: !motion.busScene
            x: motion.palace ? 906 : 594
            y: motion.palace ? 498 : 442
            width: 42
            height: 43
            property real phase: motion.seconds * 2 * Math.PI / 4.4
            property real pole: motion.palace ? 910 : 598
            property string imagePath: !motion.supported || motion.busScene ? "" : "file://" + motion.backgroundPath
            property string loadedPath: ""
            Component.onCompleted: if (imagePath) loadImage(imagePath)
            onAvailableChanged: if (available && imagePath) loadImage(imagePath)
            onImagePathChanged: {
                if (loadedPath) unloadImage(loadedPath)
                loadedPath = imagePath
                if (imagePath) loadImage(imagePath)
            }
            onImageLoaded: requestPaint()
            onPhaseChanged: if (imagePath && isImageLoaded(imagePath)) requestPaint()
            function ramp(a, b, v) {
                const t = Math.max(0, Math.min(1, (v - a) / (b - a)))
                return t * t * (3 - 2 * t)
            }
            onPaint: {
                if (!imagePath || !isImageLoaded(imagePath)) return
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const w = width, h = height
                // Small textured strips retain the hand-drawn flag artwork.
                for (let px = 0; px < w; px++) {
                    const along = Math.max(0, Math.min(1, (x + px - pole) / (x + w - pole)))
                    const horizontal = ramp(0, 0.25, along) * (1 - ramp(0.82, 1, along))
                    for (let py = 0; py < h; py += 4) {
                        const hh = Math.min(4, h - py)
                        const t = (py + hh / 2) / h
                        const envelope = horizontal * ramp(0, 0.18, t) * (1 - ramp(0.8, 1, t))
                        const shift = 2.2 * envelope * Math.sin(along * 7 - phase)
                        ctx.drawImage(imagePath, x + px, y + py + shift, 1, hh, px, py, 1, hh)
                    }
                }
            }
        }
    }
}
