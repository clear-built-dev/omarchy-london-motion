import QtQuick

Item {
    id: weather
    property real seconds: 0
    property bool drawnScene: false
    property real daylightAmount: 1
    property var appearance: ({cloud: 0, fog: 0, rain: 0, snow: 0})
    property bool animateTransitions: true
    Rectangle {
        anchors.fill: parent
        opacity: weather.appearance.cloud
        gradient: Gradient {
            GradientStop { position: 0; color: "#26323d" }
            GradientStop { position: 0.48; color: "#35404a" }
            GradientStop { position: 0.8; color: "transparent" }
        }
        Behavior on opacity { enabled: weather.animateTransitions; NumberAnimation { duration: 15000 } }
    }
    Rectangle {
        anchors.fill: parent
        opacity: weather.appearance.fog
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: "#a7b5bb" }
            GradientStop { position: 0.77; color: "#bec7c7" }
            GradientStop { position: 1; color: "#6a818e" }
        }
        Behavior on opacity { enabled: weather.animateTransitions; NumberAnimation { duration: 15000 } }
    }
    Repeater {
        model: weather.appearance.rain > 0 ? 34 : weather.appearance.snow > 0 ? 24 : 0
        Rectangle {
            required property int index
            readonly property bool rain: weather.appearance.rain > 0
            readonly property real speed: rain ? 0.19 + (index % 4) * 0.025 : 0.025 + (index % 4) * 0.004
            x: ((index * 0.381966 + weather.seconds * (rain ? 0.011 : 0.002)) % 1) * weather.width
            y: ((index * 0.6180339 + weather.seconds * speed) % 1) * weather.height
            width: rain ? Math.max(0.7, weather.width / 2200) : Math.max(1.8, weather.width / 900)
            height: rain ? weather.height * 0.014 : width
            radius: rain ? 0.4 : width / 2
            rotation: rain ? -8 : 0
            color: rain ? (weather.drawnScene && weather.daylightAmount > 0.5 ? "#46535e" : "#b4c6d0") : "#d8e0df"
            opacity: rain ? weather.appearance.rain : weather.appearance.snow
            antialiasing: true
        }
    }
}
