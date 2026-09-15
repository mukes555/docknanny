# Phase 0: capability probe results

Run on macOS 26.5.1 (build 25F80), Apple Silicon, Swift 6.2.3, Xcode 26.2,
against a two-display setup.

Phase 0 exists to answer one question before any architecture depends on the
answer: **do the APIs DockNanny needs actually work on the macOS we target?**

## Verdict

**All clear.** Every probe passed except the one that requires a permission a
terminal-launched binary cannot self-grant.

## Report

```
[PASS] Display identity
       q: Can every screen be identified by a stable CGDirectDisplayID?
       > 2 screen(s), all identified.
         - id 1: 1800x1169 at (0,0), scale 2.0x [main]
         - id 3: 2560x1440 at (1800,-92), scale 1.0x

[PASS] Liquid Glass material
       q: Is the native Tahoe glass material available to us?
       > Found NSGlassEffectView, NSGlassContainerView.

[SKIP] AX to CGWindowID resolution
       q: Can a CGWindowID be read straight off an AX window element?
       > This binary is not trusted for Accessibility.

[PASS] Per-display Spaces (private SkyLight SPI)
       q: Can we tell which Space is active on each display?
       > 2 managed display(s) reported.
         - active space id: 1
         - display 37D8832A-...: 1 space(s) [1]
         - display BE730944-...: 1 space(s) [547]

[PASS] Non-activating panel
       q: Does a non-activating panel show without taking focus?
       > 2 panel(s) shown, focus untouched.
```

## What each result decides

**Display identity.** Every `NSScreen` yields a `CGDirectDisplayID`, so
`DisplayRegistry` can key panels and per-display settings by it. Phase 1
proceeds as designed.

**Liquid Glass.** Both `NSGlassEffectView` and `NSGlassContainerView` exist on
26.5.1. The dock chrome uses the native material, with `NSVisualEffectView`
kept only as a defensive fallback rather than the primary path.

**Non-activating panel.** `[.borderless, .nonactivatingPanel]` at `.floating`
level with `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` shows on
every screen without activating the app. This is the single mechanism the
whole product rests on, and it works.

**Per-display Spaces.** The private SkyLight symbols resolve and return live
data, including per-display UUIDs and ordered space lists. **Phase 4 is
viable**, which was the biggest open risk in the plan. It stays behind
`SpaceFilter` with a no-op implementation regardless, because resolving today
says nothing about macOS 27.

**AX to CGWindowID.** Unverified. A binary launched from a terminal is not
trusted for Accessibility, so the probe correctly skipped rather than
reporting a false negative. Re-run after granting the built binary
Accessibility permission:

```bash
open -R Spike/.build/debug/Spike
```

Add it under System Settings > Privacy & Security > Accessibility, then
`swift run Spike` again.

## Incidental finding

The two displays are vertically misaligned: the external panel sits at origin
`(1800, -92)`, putting its bottom edge 92pt below the built-in display's.

This is almost certainly why the native "shove the cursor past the bottom
edge" gesture for relocating the system Dock is unreliable on this machine.
It also means panel placement must be computed from each screen's own
`visibleFrame` and never from a shared baseline, and that the AX-to-NS
coordinate conversion has to be correct for negative origins from day one.
A regression test covers exactly this geometry.

## Reproducing

```bash
cd Spike && swift run Spike
```

The spike is deliberately throwaway. It is kept in the repository because
re-running it on each new macOS release is the cheapest possible early warning
that a private symbol has been withdrawn.
