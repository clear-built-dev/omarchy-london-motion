// SPDX-License-Identifier: MIT
// Copyright (c) David Heinemeier Hansson
// London additions: Copyright (c) 2026 Shas Veeramani
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Settings.js" as Settings

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1
  property real motionSeconds: 0
  property string daylightOverride: ""
  property string daylightPhase: ""
  property string weatherOverride: "automatic"
  property var options: Settings.defaults()
  property string settingsError: ""
  property bool settingsSaving: false
  readonly property bool weatherConfigured: weatherService.query !== ""
  readonly property string effectiveWeather: weatherOverride !== "automatic" ? (weatherOverride === "off" ? "none" : weatherOverride) : options.weatherEnabled ? weatherService.condition : "none"
  readonly property string weatherStatus: !options.weatherEnabled ? "Live weather off" : !weatherConfigured ? "Enter a city to enable weather updates" : weatherService.fresh ? weatherService.locationName + " · " + weatherService.condition : "Waiting for weather · lighting continues offline"

  FileView {
    id: preferencesFile
    path: root.home + "/.config/omarchy/london-motion.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: if (!savePreferences.running && !root.settingsSaving) root.options = Settings.parse(text())
    onSaved: { root.settingsSaving = false; root.settingsError = "" }
    onSaveFailed: { root.settingsSaving = false; root.settingsError = "Could not save wallpaper preferences" }
  }
  Timer {
    id: savePreferences
    interval: 150
    onTriggered: {
      root.settingsSaving = true
      preferencesFile.setText(JSON.stringify(root.options, null, 2) + "\n")
    }
  }
  function setOption(key, value) {
    if (!Object.prototype.hasOwnProperty.call(Settings.defaults(), key)) return false
    var next = Object.assign({}, options)
    next[key] = value
    options = Settings.normalize(next)
    if (key === "lightingMode" || key === "lightingEnabled") daylightOverride = ""
    if (key === "weatherEnabled") weatherOverride = "automatic"
    savePreferences.restart()
    return true
  }
  function selectBackground(filename) {
    if (selectedTheme.text().trim() !== "london" || backgroundSetProc.running) return false
    if (["london.png", "buckingham-palace.png", "windsor-castle-phone-box.png"].indexOf(filename) < 0) return false
    backgroundSetProc.command = ["omarchy", "theme", "bg", "set", root.stateHome + "/omarchy/current/theme/backgrounds/" + filename]
    backgroundSetProc.running = true
    return true
  }
  Process {
    id: backgroundSetProc
    onExited: root.refreshBackground()
  }
  function setDaylightPreview(period) {
    if (["automatic", "morning", "afternoon", "evening", "night"].indexOf(period) < 0) return false
    daylightOverride = period === "automatic" ? "" : period
    return true
  }
  function setWeatherPreview(condition) {
    if (["automatic", "off", "clear", "cloudy", "rain", "fog", "snow", "storm"].indexOf(condition) < 0) return false
    weatherOverride = condition
    return true
  }

  WeatherService {
    id: weatherService
    enabled: selectedTheme.text().trim() === "london" && root.options.weatherEnabled && root.weatherOverride === "automatic"
    locationOverride: root.options.weatherLocation
  }

  FileView {
    id: selectedTheme
    path: root.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    // Background polling can advance backgroundVersion while a theme switch is
    // pending; the latest theme payload should still apply.
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Commons.Color.loadColors(pendingColorsRaw)
    // Commons.Color.loadShell also refreshes Style so the type scale flips with the
    // background reveal instead of waiting for a separate reload path.
    Commons.Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    function motionStatus(): string {
      return JSON.stringify({theme: selectedTheme.text().trim(), background: root.displayedBackground, seconds: root.motionSeconds, timeOfDay: root.daylightPhase, preview: root.daylightOverride || root.options.lightingMode, weather: root.effectiveWeather, weatherLocation: weatherService.locationName, weatherFresh: weatherService.fresh, options: root.options, settingsError: root.settingsError})
    }

    function setOption(key: string, value: string): string {
      var parsed = value
      if (["motionEnabled", "lightingEnabled", "weatherEnabled"].indexOf(key) >= 0) {
        if (value !== "true" && value !== "false") return "Use true or false"
        parsed = value === "true"
      }
      return root.setOption(key, parsed) ? "ok" : "Unknown option"
    }

    function previewTimeOfDay(period: string): string {
      return root.setDaylightPreview(period) ? "ok" : "Use automatic, morning, afternoon, evening or night"
    }

    function previewWeather(condition: string): string {
      return root.setWeatherPreview(condition) ? "ok" : "Use automatic, off, clear, cloudy, rain, fog, snow or storm"
    }

    function set(path: string): void {
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: refreshBackground()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      // Keep render updates enabled. The background layer has been observed to
      // lose its committed buffer while parked with updatesEnabled=false,
      // leaving a black desktop until omarchy-shell is restarted. The wallpaper
      // itself is static, so this favors correctness over a small render-loop
      // optimization.
      updatesEnabled: true

      property bool maskReady: false

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Image {
        id: base
        anchors.fill: parent
        source: root.imageUrl(root.displayedBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
          if (status === Image.Ready && root.finishingTransition) {
            root.incomingBackground = ""
            root.oldBackground = ""
            root.finishingTransition = false
          }
        }
      }

      LondonMotion {
        anchors.fill: parent
        backgroundPath: root.displayedBackground
        onSecondsChanged: root.motionSeconds = seconds
        sceneMotionEnabled: root.options.motionEnabled
        solarLocation: weatherService.report
        lightingEnabled: root.options.lightingEnabled
        daylightOverride: root.daylightOverride || (root.options.lightingMode === "automatic" ? "" : root.options.lightingMode)
        weatherCondition: root.effectiveWeather
        onDaylightPhaseChanged: root.daylightPhase = daylightPhase
        active: selectedTheme.text().trim() === "london"
                && root.incomingBackground === "" && root.revealProgress >= 1
      }

      Image {
        id: oldFrame
        anchors.fill: parent
        source: root.imageUrl(root.oldBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: root.oldBackground !== "" && root.revealProgress < 1
        onStatusChanged: panel.maybeStartReveal()
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          source: root.imageUrl(root.incomingBackground)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }
      }

      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: revealMask.centerTop - revealMask.spread; startY: 0
            PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
            PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}
