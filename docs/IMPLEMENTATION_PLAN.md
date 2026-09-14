# Implementation plan

## Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Language | Swift 6.2, AppKit shell with SwiftUI content | A dock is roughly 80% OS integration; a webview buys nothing and blocks the APIs that matter |
| Project file | XcodeGen (`project.yml`) | `.pbxproj` merge conflicts deter outside contributors |
| License | MIT | Permissive, so others can build on it |
| Distribution | Notarized DMG plus Homebrew cask | Private SkyLight symbols rule out the App Store |
| System Dock | Coexist by default; hiding is opt-in and later | Hiding it means `killall Dock`, backup files and signal handlers, all of which are fragile |
| Concurrency | Swift 6 strict, `@MainActor` by default | AppKit, AX and window-server calls are main-thread bound anyway |

## Why not Tauri

Evaluated and rejected. `tauri-nspanel` can produce a non-activating panel, so
it is possible, but every capability macdock depends on (Accessibility,
ScreenCaptureKit, the window server, Liquid Glass) would arrive through
hand-written objc2 bindings, and the native Tahoe material has no webview
equivalent at all. Cross-platform reach, Tauri's main benefit, is worth
nothing for a macOS Dock replacement.

## Module layout

```
Sources/
  App/        AppMain, AppDelegate, StatusItemController
  Private/    SkyLightBridge, Capability          <- every private symbol, nowhere else
  Core/       DisplayRegistry, RunningAppsMonitor, WindowIndex, SpaceFilter
  Config/     Settings, SettingsStore
  UI/         DockPanel, DockPanelController, DockContentView, DockItemView,
              WindowPreviewPopover, Settings/
```

Four core services, each deep: a simple interface over real work. No layer
exists purely to forward a call.

## Phases

### Phase 0: capability spike (complete)

Validate every risky API before depending on it. See
[PHASE-0-RESULTS.md](PHASE-0-RESULTS.md). Outcome: all clear.

### Phase 1: a dock on every display (complete)

`DisplayRegistry` with stable `CGDirectDisplayID` identity and debounced
rebuilds on hot-plug. `RunningAppsMonitor` over `NSWorkspace`. One `DockPanel`
per screen showing pinned plus running apps, click to launch or activate,
running indicators.

Bottom, left and right edge placement from the start. Every competing tool
assumes bottom; edge-agnostic layout is the gap worth owning.

### Phase 2: settings UI and per-display filtering (complete)

One `Settings` value type where every option is a property, plus
`[DisplayID: DisplayOverride]`. The UI is driven by that model so adding an
option never means touching plumbing twice. Raycast-grade interaction: dark
first, keyboard reachable throughout, spring animation, instant apply.

### Between phases 2 and 3 (complete, 0.2.0)

- The system Dock mirror finished: Finder, folders, spacers, recents, Trash.
- Folder tiles as list menus; Empty Trash through Finder; drops on the Trash.
- Carbon hot keys for opening apps by number and toggling hiding.
- A manual press gesture: press feedback, live-gap reordering, the poof, and
  drops between docks on different displays.
- Skipping whichever display the system Dock is on, located through the
  window list.
- Presets, and export, import and reset of the settings file.

### 0.3.0 (complete)

- Window lists in tile menus and Show All Windows, behind an optional
  Accessibility grant offered from the setup window.
- "Keep windows clear of the dock": the effect of the Dock's reserved strip,
  done by nudging, after the probe showed the window server keeps one strip
  for the whole system and the Dock rewrites it.
- A stable ad hoc signing requirement so the grant survives rebuilds.
- Activation through the call macOS still honours after a menu bar click.
- A housekeeping round: lifetimes, caches, Accessibility safety, privacy.

### Phase 3: live window previews

ScreenCaptureKit thumbnails cached by `CGWindowID`, strictly async. Without
Screen Recording permission the popover degrades to a titles-only list.

Window identity comes from `_AXUIElementGetWindow`, not from matching window
titles and frames.

### Phase 4: current-Space filtering

```swift
protocol SpaceFilter {
    func windowsOnActiveSpace(of displayID: CGDirectDisplayID) -> Set<CGWindowID>?
}
```

`SkyLightSpaceFilter` uses the private SPI; `NoOpSpaceFilter` returns nil,
meaning "show everything". `Capability` chooses between them at launch by
checking which symbols resolved. A future macOS withdrawing them costs the
feature, never the app.

## Known pitfalls

1. **Coordinate systems.** Accessibility uses a top-left origin, `NSScreen`
   uses bottom-left. One conversion helper, unit tested, never converted
   inline. The development machine has a display at negative Y, which makes
   this a live concern rather than a theoretical one.
2. **AXObserver is lossy.** It does not reliably deliver every window event.
   A low-frequency poll backs it up.
3. **Debounce display changes.** Hot-plug fires
   `didChangeScreenParametersNotification` repeatedly; rebuilding per event
   thrashes panels.
4. **Never block the main thread on capture.** Thumbnail work is async only.

## Non-goals

Replacing Launchpad or Mission Control, iOS or iPadOS support, theming engines,
and widgets. macdock puts a dock on every display and does it well.
