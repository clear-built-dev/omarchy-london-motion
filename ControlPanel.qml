import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    ipcTarget: moduleName + ".controls"
    manageIpc: false
    readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor(moduleName) : null
    readonly property var options: service ? service.options : ({motionEnabled: true, lightingEnabled: true, lightingMode: "automatic", weatherEnabled: false, weatherLocation: ""})
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onOpenedChanged: if (opened) city.text = options.weatherLocation

    IpcHandler {
        target: root.ipcTarget
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function status(): string {
            return JSON.stringify({open: root.opened, serviceAvailable: root.service !== null, options: root.options, panelVisible: popup.visible, width: popup.contentWidth, height: popup.contentHeight})
        }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰸉"
        tooltipText: "London wallpaper controls"
        active: root.opened
        onPressed: function(code) { if (root.service) root.toggle() }
    }

    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: focusScope
        contentWidth: popup.fittedContentWidth(Style.space(420))
        contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(760))

        FocusScope {
            id: focusScope
            anchors.fill: parent
            Keys.onEscapePressed: root.close()
            Flickable {
                anchors.fill: parent
                contentHeight: column.implicitHeight
                clip: true
                Column {
                    id: column
                    width: parent.width
                    spacing: Style.space(10)
                    Text {
                        text: "London Wallpaper"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: "Motion, light and weather · settings are saved"
                        color: Color.popups.text
                        opacity: 0.65
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    Dropdown {
                        width: parent.width
                        label: "Background"
                        value: root.service ? root.service.currentBackground.split("/").pop() : ""
                        options: [{value: "london.png", label: "London · Big Ben"}, {value: "buckingham-palace.png", label: "Buckingham Palace"}, {value: "windsor-castle-phone-box.png", label: "Windsor Castle"}]
                        onChanged: function(value) { if (root.service) root.service.selectBackground(value) }
                    }
                    Toggle {
                        width: parent.width
                        label: "Scene motion"
                        description: "Bus, London Eye, flags and weather particles"
                        checked: root.options.motionEnabled
                        onClicked: if (root.service) root.service.setOption("motionEnabled", !checked)
                    }
                    Toggle {
                        width: parent.width
                        label: "Time-of-day lighting"
                        description: "Follow your local clock or choose a fixed look"
                        checked: root.options.lightingEnabled
                        onClicked: if (root.service) root.service.setOption("lightingEnabled", !checked)
                    }
                    Dropdown {
                        width: parent.width
                        label: "Lighting"
                        value: root.options.lightingMode
                        enabled: root.options.lightingEnabled
                        opacity: enabled ? 1 : 0.45
                        options: [{value: "automatic", label: "Automatic · day and night"}, {value: "morning", label: "Morning"}, {value: "afternoon", label: "Afternoon"}, {value: "evening", label: "Evening"}, {value: "night", label: "Night"}]
                        onChanged: function(value) { if (root.service) root.service.setOption("lightingMode", value) }
                    }
                    PanelSeparator {}
                    Toggle {
                        width: parent.width
                        label: "Live weather"
                        description: "Use conditions reported for your configured city"
                        checked: root.options.weatherEnabled
                        onClicked: if (root.service) root.service.setOption("weatherEnabled", !checked)
                    }
                    RowLayout {
                        width: parent.width
                        spacing: Style.space(8)
                        TextField {
                            id: city
                            Layout.fillWidth: true
                            placeholderText: "City, e.g. London, UK"
                            maximumLength: 120
                            onAccepted: if (root.service) root.service.setOption("weatherLocation", text)
                        }
                        Button {
                            text: "Save city"
                            onClicked: if (root.service) root.service.setOption("weatherLocation", city.text)
                        }
                    }
                    Text {
                        width: parent.width
                        text: root.service ? root.service.weatherStatus : "Wallpaper service is loading"
                        color: Color.popups.text
                        opacity: 0.7
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "Weather queries wttr.in only when enabled with an explicit city. No location detection."
                        color: Color.popups.text
                        opacity: 0.55
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    Dropdown {
                        width: parent.width
                        label: "Weather preview"
                        value: root.service ? root.service.weatherOverride : "automatic"
                        options: [{value: "automatic", label: "Live conditions / off"}, {value: "clear", label: "Clear"}, {value: "cloudy", label: "Cloudy"}, {value: "rain", label: "Rain"}, {value: "fog", label: "Fog"}, {value: "snow", label: "Snow"}, {value: "storm", label: "Storm"}]
                        onChanged: function(value) { if (root.service) root.service.setWeatherPreview(value) }
                    }
                    Text {
                        visible: root.service && root.service.settingsError !== ""
                        width: parent.width
                        text: root.service ? root.service.settingsError : ""
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
