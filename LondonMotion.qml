import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "Daylight.js" as Daylight
import "Weather.js" as Weather

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
    readonly property real imageWidth: 3840
    readonly property real imageHeight: 2160
    readonly property real fitScale: Math.max(width / imageWidth, height / imageHeight)
    readonly property real displayScale: Math.max(1, Screen.devicePixelRatio)
    property real seconds: 0
    property date clockTime: new Date()
    property string daylightOverride: ""
    property string weatherCondition: "none"
    readonly property var weatherLook: Weather.look(weatherCondition)
    readonly property var daylight: Daylight.atHour(clockTime.getHours() + clockTime.getMinutes() / 60, daylightOverride)
    readonly property string daylightPhase: daylight.label
    property bool daylightReady: false
    Component.onCompleted: daylightReady = true
    visible: active && supported && picture.status === Image.Ready
    clip: true

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: motion.visible && motion.animationEnabled
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
        layer.enabled: true
        layer.textureSize: Qt.size(Math.min(6144, Math.ceil(width * motion.fitScale * motion.displayScale)), Math.min(3456, Math.ceil(height * motion.fitScale * motion.displayScale)))
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            brightness: motion.daylight.brightness + motion.weatherLook.brightness
            contrast: motion.daylight.contrast + motion.weatherLook.contrast
            saturation: motion.daylight.saturation + motion.weatherLook.saturation
            colorization: motion.daylight.colorization
            colorizationColor: motion.daylight.color
            Behavior on brightness { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: 60000 } }
            Behavior on contrast { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: 60000 } }
            Behavior on saturation { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: 60000 } }
            Behavior on colorization { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: 60000 } }
            Behavior on colorizationColor { enabled: motion.daylightReady && motion.animationEnabled; ColorAnimation { duration: 60000 } }
        }

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
            x: motion.palace ? 2180 : 1450
            y: motion.palace ? 1100 : 1080
            width: 86
            height: 80
            readonly property real renderScale: Math.max(1, Math.min(1.6, motion.fitScale * motion.displayScale))
            readonly property real sourceScaleX: picture.sourceSize.width > 0 ? picture.sourceSize.width / motion.imageWidth : 1
            readonly property real sourceScaleY: picture.sourceSize.height > 0 ? picture.sourceSize.height / motion.imageHeight : 1
            canvasSize: Qt.size(Math.ceil(width * renderScale), Math.ceil(height * renderScale))
            onCanvasSizeChanged: requestPaint()
            property real phase: motion.seconds * 2 * Math.PI / 4.4
            property real pole: motion.palace ? 2186 : 1456
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
                const w = canvasSize.width, h = canvasSize.height
                ctx.clearRect(0, 0, w, h)
                // Small textured strips retain the hand-drawn flag artwork.
                for (let px = 0; px < w; px++) {
                    const along = Math.max(0, Math.min(1, (x + px / renderScale - pole) / (x + width - pole)))
                    const horizontal = ramp(0, 0.25, along) * (1 - ramp(0.82, 1, along))
                    for (let py = 0; py < h; py += 4) {
                        const hh = Math.min(4, h - py)
                        const t = (py + hh / 2) / h
                        const envelope = horizontal * ramp(0, 0.18, t) * (1 - ramp(0.8, 1, t))
                        const shift = 2.2 * envelope * Math.sin(along * 7 - phase)
                        ctx.drawImage(imagePath,
                            (x + px / renderScale) * sourceScaleX,
                            (y + py / renderScale + shift) * sourceScaleY,
                            sourceScaleX / renderScale, hh * sourceScaleY / renderScale,
                            px, py, 1, hh)
                    }
                }
            }
        }
    }

    // A faint horizon wash complements the tonal treatment without hiding grain.
    Rectangle {
        anchors.fill: parent
        opacity: motion.daylight.glowAmount
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.38; color: "transparent" }
            GradientStop {
                position: 0.72
                color: motion.daylight.glow
                Behavior on color { enabled: motion.daylightReady && motion.animationEnabled; ColorAnimation { duration: 60000 } }
            }
            GradientStop { position: 1; color: "transparent" }
        }
        Behavior on opacity { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: 60000 } }
    }
    WeatherOverlay {
        anchors.fill: parent
        seconds: motion.seconds
        appearance: motion.weatherLook
        animateTransitions: motion.daylightReady && motion.animationEnabled
    }
}
