<div align="center">

<img src="docs/media/banner.png" width="760" alt="DockNanny: the quokka in lime glasses, waving, with a halo of displays behind its head each showing the DockNanny logo, beside the wordmark and the tagline A dock on every display" />

<br />

**A dock on every display. The one macOS won't give you.**<br />
Your Dock, mirrored to every screen you plug in, with the parts macOS keeps to itself: magnification that spreads, a Trash that fills, folders that open as lists, and windows that stay clear of it.

[![CI](https://github.com/mukes555/docknanny/actions/workflows/ci.yml/badge.svg)](https://github.com/mukes555/docknanny/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/mukes555/docknanny?include_prereleases)](https://github.com/mukes555/docknanny/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-8BC53F.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-26%20Tahoe-8BC53F)
![Swift](https://img.shields.io/badge/Swift-6.2-8BC53F)

<br />

<img src="docs/media/dock.png" width="860" alt="A DockNanny dock: Finder, Safari, Mail, Notes, Terminal and System Settings on a glass slab, a divider, and the Trash" />

</div>

## Why

macOS gives you exactly one Dock. On a multi-monitor setup it either hops
between screens on a hair trigger, or you turn on *Displays have separate
Spaces* and inherit a window-management model you did not ask for. The
long-standing workaround, shoving the cursor past the bottom edge of the
screen you want, is unreliable the moment your displays are not perfectly
bottom-aligned.

DockNanny puts a real dock on every display, stays off the one that already has
the system Dock, and leaves your Spaces settings alone.

<div align="center"><img src="docs/media/quokka-halo.jpg" width="480" alt="The DockNanny quokka seated with a coffee mug, a ring of displays behind its head, every one showing the DockNanny logo" /></div>

## What you get

**Your Dock, again.** By default DockNanny mirrors the system Dock: the same apps
in the same order, Finder first, folders and spacers where you put them,
running apps after the pins, the Trash at the end. Rearrange the real Dock and
every display follows within two seconds. Turn mirroring off and each list is
yours.

**Dock behaviour, not a lookalike.** Magnification spreads neighbours apart
rather than covering them, so a click can only ever mean one tile. Press
feedback, launch bounce, hover labels, Command-click to reveal, Option-click to
hide the others, drag to rearrange with a live gap, drag a tile off to remove
it with the poof, and drag one from one display's dock to another's. Right-click
a running app for its windows, like the Dock. Folder tiles open as a list.

**One app, one screen at a time.** Clicking the app you are already in can
fold away just its windows on that screen and leave your other screens alone,
with another click to bring them back. macOS hides whole applications; a dock
on every display can be narrower than that.

**Windows stay clear of it.** Turn on "Keep windows clear of the dock" in
Behavior and grant Accessibility once, and a window opened or zoomed into a
dock's space is nudged to sit beside it, the effect the system Dock gets from
its reserved strip.

**Every display its own.** Edge, size, tint, hiding and which apps are shown
can all differ per display, and a display keeps its settings across unplugging.

**Keyboard.** Control-Option-1 to 9 open the first to ninth app on the dock
under the pointer; Control-Option-D toggles hiding. Modifiers are configurable.

**Never in the way.** Clicking a dock icon does not deactivate the app you are
working in. Idle cost is a rounding error: 0.0 to 0.1 percent CPU and 17 MB.

## The screens

**The tray** drops from the menu bar mark: one card per display with a live
preview of its dock, an edge switcher, a tint and an on/off switch, plus the
quick settings.

<div align="center"><img src="docs/media/tray.png" width="370" alt="The tray: a display card with a live dock preview, edge buttons, tint dot and switch, quick settings, and the actions" /></div>

**Layout** is where the dock goes and how big it is, with the preview updating
as you drag.

<img src="docs/media/settings-layout.png" width="860" alt="Settings, Layout: edge cards, alignment, icon size, spacing and margin sliders, and the live preview" />

**Appearance** covers the glass, the indicators, magnification and tint.

<img src="docs/media/settings-appearance.png" width="860" alt="Settings, Appearance: chrome style, indicator style, magnification and the tint swatches" />

**Behavior** holds hiding, clicking, the keyboard shortcuts, and keeping
windows clear of the dock.

<img src="docs/media/settings-behavior.png" width="860" alt="Settings, Behavior: contents, hiding, clicking, keyboard shortcuts and windows" />

**Apps** is the pin list: mirrored from the system Dock, or your own with
drag-to-reorder, spacers and a folders section.

<img src="docs/media/settings-apps.png" width="860" alt="Settings, Apps: the source switch, the pinned list with icons, and the footer actions" />

**Presets** are starting points, one of which copies the system Dock's edge,
size, magnification and hiding, and the settings file can be exported,
imported or reset.

<img src="docs/media/settings-presets.png" width="860" alt="Settings, Presets: four starting points with Apply buttons, and export, import and reset" />

### Keyboard

| Keys | Action |
| --- | --- |
| `Ctrl+Opt+1` to `9` | Open the first to ninth app on the dock under the pointer |
| `Ctrl+Opt+D` | Toggle "Hide automatically" |
| `Cmd+,` | Settings, from the tray or any window |
| `Cmd+1` to `6` | Switch Settings sections |
| `Esc` | Close the tray |

## Install

```bash
brew tap mukes555/tap
brew install --cask docknanny        # later: brew upgrade --cask docknanny
```

The cask clears the Gatekeeper quarantine for you. There is a DMG in
[Releases](https://github.com/mukes555/docknanny/releases/latest) too; the app
is ad hoc signed rather than notarized, so if you install from the DMG, clear
the quarantine once:

```bash
xattr -dr com.apple.quarantine /Applications/DockNanny.app
```

DockNanny lives in the menu bar as two small displays.

**Requirements.** macOS 26 (Tahoe) or later, Apple Silicon.

## Permissions

None to start. Every action goes through `NSRunningApplication`,
`NSWorkspace`, the Dock's own preferences and Carbon hot keys, none of which
needs a grant. Three things ask for something, only when you use them, and
work without it otherwise:

- **Window lists in tile menus** and **Keep windows clear of the dock** read
  other apps' windows, which is Accessibility access. Grant it from the setup
  window under the menu bar icon; the docks never need it.
- **Folder tiles** read the folder they show, so macOS may ask about that
  folder (Downloads, Desktop and the like).
- **Empty Trash** asks Finder to do the emptying, which is an Automation
  prompt for controlling Finder. Finder keeps its own "permanently erase?"
  confirmation. Decline the prompt and the Trash opens instead, so you can
  empty it there.

<div align="center"><img src="docs/media/setup.png" width="480" alt="The setup window: nothing to grant for the docks, and the optional Accessibility row with Grant and Relaunch buttons" /></div>

One thing the system Dock's menu has that DockNanny's cannot: an app's own menu
section (a browser's profiles, an editor's recent windows). Apps hand that to
the Dock over a private channel on which the Dock is the server, so no other
process can ask for it.

## Privacy

DockNanny has no network access and no analytics. Settings live in one JSON file
at `~/Library/Application Support/DockNanny/settings.json`, which you can export,
import or reset from Settings. The unified log carries no window titles or
bundle identifiers in the clear.

## Building

```bash
brew install xcodegen swiftlint
```

```bash
git clone https://github.com/mukes555/docknanny.git && cd docknanny && xcodegen generate && open DockNanny.xcodeproj
```

`tools/dev.sh` builds, signs and relaunches a development build so its
Accessibility grant survives rebuilds. `tools/release.sh` builds a DMG (ad hoc
by default; set `CODESIGN_IDENTITY` and `NOTARY_PROFILE` for a notarized
one). Launch flags: `--settings [--section=layout|appearance|behavior|displays|apps|presets]`,
`--setup`, `--tray`, `--settings-dir=<folder>` for a separate profile, and
`--probe-windows=<app name or bundle id>` (optionally with `--resize-test` or
`--set-width=<points>`) to record what Accessibility and the window server say
about an app's windows when one will not stay clear of a dock. The probe
reports in the log under the `probe` category and exits; start it with
`open -n -a DockNanny --args --probe-windows=<app>` so it runs with the app's
own Accessibility grant.

The app logs under the `app.docknanny` subsystem:

```bash
/usr/bin/log stream --level info --predicate 'subsystem == "app.docknanny"'
```

## What is next

See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). Window
previews on hover are the next piece.

## Built by AI agents

<img src="docs/media/quokka-wave.png" width="240" align="right" alt="The DockNanny quokka waving, coffee mug in the other paw" />

DockNanny was designed and written with Claude Code, one decision at a time,
with every behaviour measured against the real system Dock before it
shipped: window frames read from the window server, pixel measurements of
the Dock's own reserved gap, and a probe for every private API it leans on.
The quokka is the mascot of that way of working: an approachable expert with
a coffee, unbothered by how many displays you plug in.

<br clear="right" />

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. It covers branch naming, commit
format, Swift conventions, and the file-size limits CI enforces.

## Credits

DockNanny is an independent, clean-room implementation. Two existing projects
were read for background on macOS window-management behaviour and are
gratefully acknowledged, though no code was taken from either:
[MultiDock](https://github.com/DmitryChichikalyuk/MultiDock) and
[Docky](https://github.com/josejuanqm/docky).

## License

MIT. See [LICENSE](LICENSE).
