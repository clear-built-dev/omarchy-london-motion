# London Motion

Animated 6K wallpapers with local-time lighting and optional live weather for the [London Omarchy theme](https://github.com/clear-built-dev/omarchy-london-theme).

![London Motion preview](preview.png)

[Watch the animation demo](docs/demo.mp4).

![Morning, afternoon, evening and night on all three backgrounds](docs/time-of-day.png)

- A red bus crosses Westminster Bridge in 110 seconds.
- The London Eye rotates once every 220 seconds; its supports remain fixed.
- Big Ben's hands show local system time, updating on each minute change.
- The Buckingham Palace and Windsor Castle flags ripple gently on a 4.4-second loop.
- Morning, afternoon, evening and night lighting blends gradually through the day.
- Optional real weather adds clear/cloudy lighting, rain, fog, snow or subdued storm conditions.

The demo accelerates the four lighting presets for comparison; actual lighting
blends over hours. Big Ben's clock always shows actual local time.

The backgrounds remain still PNGs. The plugin draws the moving parts locally
at 20 frames per second, with no video playback. Motion and time-of-day lighting
work offline; optional live weather uses a bounded request to wttr.in every 15 minutes. It animates only the London theme's three named backgrounds.

## Requirements

- **Omarchy Quattro**, tested on **4.0.6-1**, including its Quickshell background
  service and support for `omarchy.clonedFrom` plugin replacements.
- The [London theme](https://github.com/clear-built-dev/omarchy-london-theme),
  the **6K vector edition**, installed under the slug **`london`**, with its
  original background filenames and flag positions. This plugin edition is not
  compatible with the first edition's pencil backgrounds. Renamed themes and
  modified flag artwork are not supported.
- Qt Quick, Qt Quick Effects and Quickshell supplied by Omarchy. `curl`, already
  shipped with Omarchy, is used only when weather is configured.

Other Omarchy versions have not been verified. This service contains a modified
copy of the 4.0.6 background renderer; changes in future Omarchy versions may
require an update. It replaces the built-in background service while enabled,
including when another theme is selected. Other themes retain still wallpapers.

## Install

First install the theme:

```sh
omarchy theme install https://github.com/clear-built-dev/omarchy-london-theme
```

Then add the plugin. Review it before enabling:

```sh
omarchy plugin add https://github.com/clear-built-dev/omarchy-london-motion
omarchy plugin enable io.github.clear-built-dev.london-motion
omarchy restart shell
```

Enabling explicitly replaces `omarchy.background`; restarting ensures cached
QML components are refreshed. The plugin does not install packages or modify
terminal settings, Hyprland configuration, theme files, or global font settings.
Omarchy records the enabled plugin in its normal user shell configuration.

If another wallpaper-renderer clone is enabled, switch back to
`omarchy.background` before enabling London Motion. Your old clone stays on disk.

Cycle through the three backgrounds with `omarchy theme bg next`.

## Time of day

Lighting follows **local system time**, with no location lookup:

| Local time | Appearance |
| --- | --- |
| 22:00–05:00 | Night |
| 05:00–07:00 | Night gradually becomes morning |
| 07:00–11:00 | Morning |
| 11:00–13:00 | Morning gradually becomes afternoon |
| 13:00–16:00 | Afternoon |
| 16:00–18:00 | Afternoon gradually becomes evening |
| 18:00–20:00 | Evening |
| 20:00–22:00 | Evening gradually becomes night |

These are fixed time periods, not sunrise/sunset calculations. The appearance is
recalculated from the system clock each minute, including after sleep or clock
changes. Only the wallpaper changes; terminal and application colours stay the
same. All moving parts receive the same lighting treatment.

Preview a look without changing the clock, then restore automatic lighting:

```sh
omarchy-shell background previewTimeOfDay afternoon
omarchy-shell background previewTimeOfDay automatic
```

Preview changes ease over one minute. They reset to automatic after shell restart.

## Optional live weather

![Weather appearance examples](docs/weather.png)

Weather is **disabled until an explicit city or coordinates are configured**.
It never infers your location from your IP address. It first reads
`~/.config/omarchy/london-motion-weather.json`; if absent, it uses an explicitly
saved Omarchy weather location in `~/.local/state/omarchy/settings/weather.json`.
It does not change Omarchy's global weather settings.

For example, configure the wallpaper to use London by creating
`~/.config/omarchy/london-motion-weather.json` containing:

```json
{"name": "London, UK"}
```

A location with explicit `latitude` and `longitude` is also supported. An empty
or malformed configuration does not trigger a request. When configured, the
plugin sends that location to **wttr.in**, the same service used by Omarchy's
weather tools. Requests time out after 10 seconds and run at most once every
15 minutes per shell instance, shared across monitors. It does not write weather
responses to disk. The provider may supply delayed observations.

Clear, cloudy, rain, fog, snow and storm codes change the lighting. Rain and snow
add sparse native moving particles; storms darken the scene without flashing.
Failed fetches keep the last successful response for at most an hour, then fall
back to time-of-day lighting. Unknown or malformed conditions also fall back.
Weather changes fade gently. No network is needed for the rest of the plugin.

Preview weather without a network request, or suppress live weather:

```sh
omarchy-shell background previewWeather rain
omarchy-shell background previewWeather off
omarchy-shell background previewWeather automatic
```

Preview/off settings reset on shell restart. Remove the wallpaper weather config
and any explicit global Omarchy weather location to disable fetching persistently.
Provider reference: https://github.com/chubin/wttr.in#json-output

## Disable or remove

Return to Omarchy's built-in still wallpaper renderer:

```sh
omarchy plugin enable omarchy.background
omarchy restart shell
```

Then, optionally remove the plugin:

```sh
omarchy plugin remove io.github.clear-built-dev.london-motion
```

The London theme and its wallpapers remain installed. To return to a different
previous wallpaper clone, explicitly enable that clone instead.

## Troubleshooting and behavior

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.clear-built-dev.london-motion
omarchy-shell background motionStatus
```

The status reports the selected theme, background, advancing animation clock, lighting period and weather freshness.
Allow a moment after shell startup for the background to load. If a background
does not move, confirm the theme slug is `london` and restart the shell.

Motion pauses while its component is hidden during a transition or another theme
is active. There is no dedicated battery, lock-state, or reduced-motion policy;
disable the plugin with the command above when you want still wallpapers.
Resource use depends on monitor count, resolution, and graphics driver; no
battery-life or performance benchmark is claimed.

The existing background picker, click handling, transitions, and monitor crop
behavior are retained from Omarchy. The plugin uses the same installed Omarchy
theme/background selector commands and reads the current theme/background state.
It does not download assets or execute repository-provided setup scripts. Configured
weather performs the documented HTTPS request, without running provider content.

## Development and license

`LondonMotion.qml` implements the animation. `Background.qml` is derived from
Omarchy's background renderer. The editable SVG motion assets are in `assets/`.
The development rendering/validation tools are kept outside this release package.

MIT license, retaining David Heinemeier Hansson's upstream copyright and the
copyright for London additions. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
