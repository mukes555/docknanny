# Changelog

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
- macdock stays off whichever display the system Dock is on, and follows if
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
