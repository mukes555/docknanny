# Changelog

## 0.6.0

- Apps open on the screen you clicked. Clicking an app that is not running,
  or one running with no window, used to put its new window wherever macOS
  chose, usually the screen with focus. The window now appears on the screen
  whose dock was clicked, at its own size and centred, shrunk only if it does
  not fit. Apps already showing a window are left alone, so a window you open
  by hand is never moved. On by default; Behavior, Clicking to turn it off.
- Hide on This Screen is the default for clicking the app you are already in.
  A settings file that already chose something else keeps its choice.
- `--probe-open=<bundle id>` clicks an app's tile from the dock under the
  pointer through the same path a real click takes, and reports which screen
  each of its windows ended up on.

## 0.5.2

- The setting for clicking the app you are already in is a menu now, so its
  three choices read in full. As a row of three buttons they were cut to
  "Do Nothi...", "Hide the..." and "Hide on...". Its explanation is shorter
  and says plainly how the two ways of hiding differ.
- Hide on This Screen has been tried by hand on two screens: a window folds
  away on the screen whose dock was clicked and comes back on the next click,
  including clicks a second apart.

## 0.5.1

- Bringing a window back to the screen it came from works however quickly
  you click. While a window folds away the window server describes its
  thumbnail in the Dock, which sits on whichever screen the Dock is on, so
  a second click within about a second looked for the window on the wrong
  screen and only brought the app forward. The app's own answer is trusted
  for a window that is folded away, the window server's for one on screen.
- `--probe-hide=<app>`, with `--apply`, reports what "Hide on This Screen"
  would do to an app on the screen under the pointer, and does it while
  watching, which is how the above was found.

## 0.5.0

- A third choice for clicking the app you are already in: "Hide on This
  Screen" folds away only its windows on the screen whose dock you clicked,
  and clicking there again brings them back. The other screens are left as
  they were. macOS hides whole applications and has no per-display hide, so
  this is a dock on every display doing what the system Dock cannot.

## 0.4.2

- An app that starts after the keeper is armed has its own windows judged
  once, rather than every window on the machine; a sweep of everything
  is kept for the docks changing. The release workflow's actions moved to
  their current major versions.

## 0.4.1

- Release notes come from the changelog section of the version being
  released, and a release refuses a tag whose version disagrees with
  project.yml or the newest changelog section.
- An audit round. The hovered tile's name on a bottom dock was drawn above
  the window and never showed. Auto-hide could leave a dock revealed with
  the pointer gone, stuck hidden after the shortcut, or collapsing under its
  own menu; a hidden dock took file drops on its invisible sliver; a launch
  that never came up bounced for ever; tile menus had clickable headers and
  a live "Empty Trash..." with an empty Trash, and the Trash counted
  Finder's own housekeeping files as contents. Clicking a running app with
  no windows now opens one, as the system Dock does; the settings window
  opens on the pane asked for even when already open; the hiding shortcut
  works on a display with its own auto-hide setting; held shortcuts no
  longer repeat; a tray closed by a click elsewhere no longer takes focus
  back half a second later.
- The window keeper judges windows only when the docks change or an app
  joins, reads the window list once per pass and each window in one round
  trip, retries an app that is still starting up with backoff and then
  gives up rather than piling up retries, and cancels a second look when
  the person takes hold of the window.
- A second review pass. On a mirrored dock, a drag that ended where it
  began silently switched mirroring off; edits now fork from the system
  Dock only when they change something. A file dropped on a dock showing
  only chosen apps is now allowed on that dock rather than appearing on
  every other one. Reopening DockNanny while its docks are up opens
  Settings instead of taking focus with nothing to show. A login item
  parked for approval says so and opens Login Items. "Hide automatically"
  in the tray and the Behavior pane flips every dock, like the shortcut.
  The display poll goes through the hot-plug settle, so a tick mid
  reconfiguration no longer closes and reopens every panel. An app
  LaunchServices still lists after its process is gone is no longer shown
  or watched. Clicking the front app opens a window when it has none, as
  the Dock does. The docs match the code again.
- Failures are told, not only logged. A Finder that declines to empty the
  Trash (the Automation prompt, answered no) opens the Trash instead; a
  settings file that cannot be written is announced on every pane of the
  settings window; an export that fails says so beside the button. The hot
  key and window observer registrations are taken down with their owners.
- Settings files: an absurd number no longer crashes the settings window; a
  list with one bad entry keeps the rest, and a per-display override keeps
  its readable fields; a symlinked settings.json is written through; a file
  that cannot be opened is set aside instead of overwritten; imports are
  refused above a megabyte.

## 0.4.0

- The brand colour is lime #C0DD71, chosen in the app from a family of
  ten candidates: the icon draws its two displays in lime on a near-black
  ground, the banner and every accent follow it, and the accent of
  DockNanny's own windows can be swapped for one of the others in
  Appearance.
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
