import QtQuick

// Local time, with the hour hand positioned between hour marks.
Item {
    id: clock
    property date time: new Date()
    readonly property real hourAngle: (time.getHours() % 12) * 30 + time.getMinutes() * 0.5
    readonly property real minuteAngle: time.getMinutes() * 6

    Item {
        x: clock.width / 2
        y: clock.height / 2
        rotation: clock.hourAngle
        Rectangle { x: -1.8; y: -16; width: 3.6; height: 18; radius: 1.8; color: "#333c3d"; antialiasing: true }
    }
    Item {
        x: clock.width / 2
        y: clock.height / 2
        rotation: clock.minuteAngle
        Rectangle { x: -1.5; y: -22; width: 3; height: 24; radius: 1.5; color: "#333c3d"; antialiasing: true }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 4; height: 4; radius: 2; color: "#333c3d"; antialiasing: true
    }
}
