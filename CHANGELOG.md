# Changelog

## 0.4.0

- Renamed from macdock to DockNanny. Apple does not allow "Mac" inside a
  third-party product name, and the new name joins PortNanny. Settings are
  carried over from the old folder on first launch; Accessibility has to be
  granted once more, since macOS keys it to the bundle identifier.
- Release readiness: the README is rebuilt with screenshots taken from a
  demo profile (nothing personal in them), a banner, and the tracon
  structure; `--settings-dir=<folder>` runs with a separate settings file;
  the pin-list edits live in a pure, tested module.
- A new app icon and menu bar mark: two displays, each with its own lime
  dock bar, on deep forest. Chosen from four directions on the design
  canvas; the generator draws the same geometry at every size.

## 0.3.2

- "Set Up DockNanny…" is in the tray as well as the right-click menu.
- Activation uses the current macOS form of the request instead of the
  deprecated one; no deprecated API remains in the app.
- The window keeper ignores notifications with no readable process and
  logs the set of watched apps only when it changes.

## 0.3.1

- "Keep windows clear of the dock" reads window frames from the window
  server instead of asking the app (iTerm2 reports the last frame it was
  asked for, not the one it has), verifies each nudge, and sweeps every
  watched window when it arms or a dock changes, so a window already under
  a dock is moved without waiting for an event. The gap left beside the
  dock now matches the system Dock's.
- `DockNanny --probe-windows=<app>` records what Accessibility and the window
  server each say about an app's windows, for support.

## 0.3.0

- Housekeeping round: polling loops are cancelled with their owners,
  observation loops hold their owners weakly, names and icons are cached
  instead of fetched on every change, every Accessibility call to a hung
  app is bounded at a quarter second, malformed Accessibility replies can
  no longer crash the process, window titles and bundle identifiers are
  private in the log, Control-click opens the menu bar menu, Command-H
  no longer hides every dock, a relaunch flushes settings first, and an
  unreadable settings file is kept beside the new one.
- Windows now reliably come to the front when opened from the menu bar:
  activation after the switch to a Dock-visible app waits for the switch
  to land and retries once. Clicking the Dock tile brings the open window
  forward instead of opening Settings beside it, and opening Settings
  twice no longer leaves the app in the Dock after closing it.
- The tray activates the app before it opens, so it takes key status and
  no longer draws faded; Escape closes it.
- "Keep windows clear of the dock" now accepts Electron windows (which
  report an unknown subrole), never nudges bubbles, menus or tooltips,
  watches apps launched after DockNanny, judges a drag by how it began, and
  reacts within 40 ms of a change settling.
- "Keep windows clear of the dock" (Behavior, off by default, needs
  Accessibility): a window opened or zoomed into a dock's space is nudged
  to sit beside it, which is the effect the system Dock gets from its
  reserved strip. The window server keeps one such strip for the whole
  system and the Dock rewrites it on every change, so reserving one for
  DockNanny was ruled out; the probe tool records the finding.
- Hot keys re-register only when their own settings change, not on every
  settings edit.
- Right-clicking a running app lists its windows, main one checked,
  minimized ones marked, and raises the one chosen; Show All Windows opens
  App Exposé. The window list needs Accessibility, which the setup window
  now offers with Grant and Relaunch buttons; without it the menu says so.
- `tools/probe-dock-rect.swift`, to find out whether reserving screen space
  beside a DockNanny dock is possible on a given machine.

## 0.2.0

- The system Dock mirror is complete: Finder first, folders and documents
  from the Dock's second section, spacers, Recent Applications when the Dock
  shows them, and the Trash (full or empty, openable, droppable, emptyable
  through Finder). Running apps share the apps section with no divider
  unless recents are on, as in the real Dock.
- Folder tiles open the Dock's list view: a menu of the folder's contents
  with submenus filled in as they are opened.
- Global shortcuts: Control-Option-1 to 9 open apps by position on the dock
  under the pointer; Control-Option-D toggles hiding. Modifiers are
  configurable in Behavior.
- Press feedback, drag-to-rearrange with a live gap, drag off the dock to
  remove with the poof, and drops from one display's dock onto another's.
- DockNanny stays off whichever display the system Dock is on, and follows if
  the Dock moves. This replaces "Show on the primary display".
- Presets (Match the Dock, Minimal, Playful, Tucked Away), and export,
  import and reset of the settings file.
- Custom lists gain spacers and a folders section; dropping a folder onto a
  dock pins it.
- A release script, a release workflow and a Homebrew cask template.

## 0.1.0

- A dock on every display, with per-display edge, size, tint, hiding and app
  filtering that survive reconnection.
- Dock-faithful magnification that spreads tiles rather than overlapping
  them, with slot-based click routing.
- Mirroring of the system Dock's pinned apps.
- Raycast-style settings window and menu bar tray.
