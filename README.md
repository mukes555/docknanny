<div align="center">

<img src="assets/branding/icon-1024.png" width="128" alt="macdock" />

# macdock

**A dock on every display. The one macOS won't give you.**

[![License: MIT](https://img.shields.io/badge/License-MIT-8BC53F.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-26%20Tahoe-8BC53F)
![Swift](https://img.shields.io/badge/Swift-6.2-8BC53F)

</div>

---

## The problem

macOS gives you exactly one Dock. On a multi-monitor setup it either hops
between screens on a hair trigger, or you turn on *Displays have separate
Spaces* and inherit a window-management model you did not ask for. The
long-standing workaround, shoving the cursor past the bottom edge of the
screen you want, is unreliable the moment your displays are not perfectly
bottom-aligned.

macdock puts a real dock on every display, stays off the display that
already has the system Dock, and leaves your Spaces settings alone.

<p align="center">
  <img src="assets/screenshots/dock-left-edge.png" height="430" alt="A macdock dock on the left edge of a second display: Finder, pinned apps, running apps, a divider, and the Trash" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/screenshots/tray.png" width="370" alt="The menu bar tray: one card per display with a live preview, edge switcher, tint and on/off switch, plus quick settings" />
</p>

## What it does

**It is your Dock, again.** By default macdock mirrors the system Dock: the
same apps in the same order, Finder first, folders and spacers where you put
them, running apps after the pins, the Trash at the end (full or empty, with
Empty Trash on right-click and files droppable onto it). Rearrange the real
Dock and every display follows within two seconds. Turn mirroring off and
each list is yours to edit.

**It behaves like the Dock.** Magnification spreads neighbours apart rather
than covering them, so a click can only ever mean one tile. Press feedback,
launch bounce, hover labels, Command-click to reveal, Option-click to hide the
others, drag to rearrange with a live gap, drag off the dock to remove it
with the poof, and drag a tile from one display's dock to another's.

**It knows about displays.** Edge (bottom, left, right), size, tint, hiding
and which apps are shown can all differ per display, and a display keeps its
settings across unplugging. The display that has the system Dock is skipped,
and if the Dock moves to another display macdock follows.

**It stays out of the way.** No focus stealing: clicking a dock icon does not
deactivate the app you are working in. Auto-hide retreats to a sliver at the
screen edge. Idle cost is zero: no timers wake the CPU while nothing changes.

**Keyboard.** Control-Option-1 to 9 open the first to ninth app on the dock
under the pointer; Control-Option-D toggles hiding, the way
Option-Command-D does for the system Dock. The modifiers are configurable.

**Settings worth opening.** A sidebar settings window in the spirit of
Raycast, a tray from the menu bar with a live preview of each display, four
presets (including one that copies the system Dock's edge, size,
magnification and hiding), and a settings file you can export, import or
reset.

<p align="center">
  <img src="assets/screenshots/settings-layout.png" width="720" alt="Settings, Layout pane" />
</p>

## Permissions

None to start. Every action goes through `NSRunningApplication`,
`NSWorkspace`, the Dock's own preferences and Carbon hot keys, none of which
needs a grant. Three things ask for something, only when you use them, and
work without it otherwise:

- **Window lists in tile menus** (right-click a running app to see and
  switch between its windows, as in the Dock) and **Keep windows clear of
  the dock** (Behavior) read other apps' windows, which is Accessibility
  access. Grant it from the setup window under the menu bar icon; the docks
  never need it.
- **Folder tiles** read the folder they show, so macOS may ask about that
  folder (Downloads, Desktop and the like).
- **Empty Trash** asks Finder to do the emptying, which is an Automation
  prompt for controlling Finder. Finder keeps its own "permanently erase?"
  confirmation.

One thing the system Dock's menu has that macdock's cannot: an app's own
menu section (a browser's profiles, an editor's recent windows). Apps hand
that to the Dock over a private channel on which the Dock is the server, so
no other process can ask for it.

## Install

Download the DMG from the latest release, drag macdock into Applications,
and launch it. It lives in the menu bar; the quokka with the glasses is the
mark.

Until releases are signed with a Developer ID, Gatekeeper will say the app
cannot be checked for malware. Clear that once with:

```bash
xattr -d com.apple.quarantine /Applications/macdock.app
```

A Homebrew cask template is in [packaging/homebrew](packaging/homebrew).

## Requirements

macOS 26 (Tahoe) or later, Apple Silicon.

## Building

```bash
brew install xcodegen swiftlint
```

```bash
git clone https://github.com/USERNAME/macdock.git && cd macdock && xcodegen generate && open macdock.xcodeproj
```

`tools/release.sh` builds a signed DMG (ad-hoc by default; set
`CODESIGN_IDENTITY` and `NOTARY_PROFILE` for a notarized one). Launch flags:
`--settings [--section=layout|appearance|behavior|displays|apps|presets]`,
`--setup`, `--tray`.

Settings live in `~/Library/Application Support/macdock/settings.json`, and
the app logs under the `app.macdock` subsystem:

```bash
/usr/bin/log stream --level info --predicate 'subsystem == "app.macdock"'
```

## What is next

See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). Window
previews on hover are the next piece.

A note on the gap beside the dock. The system Dock gets it from the window
server, which leaves the Dock's strip out of every display's visible frame
so a zoomed window stops beside it. The window server keeps exactly one such
strip and the Dock rewrites it whenever its contents change
(`tools/probe-dock-rect.swift` shows this), so macdock cannot reserve one of
its own without taking the Dock's away. "Keep windows clear of the dock" in
Behavior gets the same effect the other way round: a window opened or zoomed
into a dock's space is nudged to sit beside it.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. It covers branch naming, commit
format, Swift conventions, and the file-size limits CI enforces.

## Credits

macdock is an independent, clean-room implementation. Two existing projects
were read for background on macOS window-management behaviour and are
gratefully acknowledged, though no code was taken from either:
[MultiDock](https://github.com/DmitryChichikalyuk/MultiDock) and
[Docky](https://github.com/josejuanqm/docky).

## License

MIT. See [LICENSE](LICENSE).
