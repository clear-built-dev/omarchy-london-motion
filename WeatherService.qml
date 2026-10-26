import QtQuick
import Quickshell
import Quickshell.Io
import "Weather.js" as Weather

Item {
    id: weather
    property bool enabled: false
    property var report: null
    property double fetchedAt: 0
    property double now: Date.now()
    readonly property bool fresh: report !== null && Weather.isFresh(fetchedAt, now)
    readonly property string condition: fresh ? report.condition : "none"
    readonly property string query: Weather.locationQuery(preferences.text()) || Weather.locationQuery(location.text())
    property string requestedQuery: ""
    property string pendingRaw: ""
    readonly property string locationName: fresh && report.location ? report.location : query ? "Configured weather city" : "Weather location not configured"

    FileView {
        id: preferences
        path: Quickshell.env("HOME") + "/.config/omarchy/london-motion-weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    FileView {
        id: location
        path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    function refresh() {
        if (!enabled || !query || request.running) return
        requestedQuery = query
        pendingRaw = ""
        request.command = ["curl", "-fsS", "--connect-timeout", "5", "--max-time", "10", "--max-filesize", "524288", "https://wttr.in/" + query + "?format=j1"]
        request.running = true
    }
    onEnabledChanged: {
        now = Date.now()
        if (enabled) refresh()
    }
    onQueryChanged: {
        report = null
        fetchedAt = 0
        if (enabled) refresh()
    }
    Process {
        id: request
        stdout: StdioCollector { onStreamFinished: weather.pendingRaw = text }
        onExited: function(code, status) {
            if (weather.requestedQuery !== weather.query) { weather.refresh(); return }
            if (code !== 0) return
            const parsed = Weather.parse(weather.pendingRaw)
            if (!parsed) return
            weather.report = parsed
            weather.now = Date.now()
            weather.fetchedAt = weather.now
        }
    }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: weather.enabled; onTriggered: weather.refresh() }
    Timer { interval: 60 * 1000; repeat: true; running: weather.enabled; onTriggered: weather.now = Date.now() }
}
