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
    property bool sceneMotionEnabled: true
    property bool lightingEnabled: true
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
    property var solarLocation: null
    readonly property var weatherLook: Weather.look(weatherCondition)
    readonly property var daylight: lightingEnabled ? Daylight.atTime(clockTime, solarLocation, daylightOverride) : Daylight.original()
    readonly property string daylightPhase: daylight.label
    readonly property int lightTransitionDuration: daylightOverride !== "" ? 1200 : 60000
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
        running: motion.visible && motion.animationEnabled && motion.sceneMotionEnabled
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
        layer.effect: ShaderEffect {
            property var source
            property real brightness: motion.daylight.brightness + motion.weatherLook.brightness
            property real contrast: motion.daylight.contrast + motion.weatherLook.contrast
            property real saturation: motion.daylight.saturation + motion.weatherLook.saturation
            property real colorization: motion.daylight.colorization
            property color colorizationColor: motion.daylight.color
            property real daylightAmount: motion.daylight.dayAmount
            property real sceneKind: motion.busScene ? 0 : motion.palace ? 1 : 2
            property real lightingStrength: motion.lightingEnabled ? 1 : 0
            property real flagPhase: motion.seconds * 2 * Math.PI / 4.4
            fragmentShader: "SceneLighting.frag.qsb"
            Behavior on brightness { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
            Behavior on contrast { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
            Behavior on saturation { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
            Behavior on colorization { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
            Behavior on colorizationColor { enabled: motion.daylightReady && motion.animationEnabled; ColorAnimation { duration: motion.lightTransitionDuration } }
            Behavior on daylightAmount { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
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
                Behavior on color { enabled: motion.daylightReady && motion.animationEnabled; ColorAnimation { duration: motion.lightTransitionDuration } }
            }
            GradientStop { position: 1; color: "transparent" }
        }
        Behavior on opacity { enabled: motion.daylightReady && motion.animationEnabled; NumberAnimation { duration: motion.lightTransitionDuration } }
    }
    WeatherOverlay {
        anchors.fill: parent
        seconds: motion.seconds
        drawnScene: !motion.busScene
        daylightAmount: motion.lightingEnabled ? motion.daylight.dayAmount : 1
        appearance: motion.weatherLook
        animateTransitions: motion.daylightReady && motion.animationEnabled
    }
}
