# London Motion

Subtle animated wallpapers for the [London Omarchy theme](https://github.com/clear-built-dev/omarchy-london-theme).

![London Motion preview](preview.png)

[Watch the animation demo](docs/demo.mp4).

- A red bus crosses Westminster Bridge in 110 seconds.
- The London Eye rotates once every 220 seconds; its supports remain fixed.
- Big Ben's hands show local system time, updating on each minute change.
- The Buckingham Palace and Windsor Castle flags ripple gently on a 4.4-second loop.

The backgrounds remain still PNGs. The plugin draws the moving parts locally
at 20 frames per second, with no video playback or network connection needed
for the animation. It animates only the London theme's three named backgrounds.

## Requirements

- **Omarchy Quattro**, tested on **4.0.6-1**, including its Quickshell background
  service and support for `omarchy.clonedFrom` plugin replacements.
- The [London theme](https://github.com/clear-built-dev/omarchy-london-theme),
  installed under the slug **`london`**, with the original background filenames
  and dimensions. Renamed themes and modified flag artwork are not supported.
- Qt Quick and Quickshell supplied by Omarchy. No extra runtime packages.

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

The status reports the selected theme, background, and advancing animation clock.
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
It does not download assets or execute repository-provided setup scripts.

## Development and license

`LondonMotion.qml` implements the animation. `Background.qml` is derived from
Omarchy's background renderer. The editable SVG motion assets are in `assets/`.
The development rendering/validation tools are kept outside this release package.

MIT license, retaining David Heinemeier Hansson's upstream copyright and the
copyright for London additions. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
