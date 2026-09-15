# Contributing to DockNanny

Thanks for looking. This document is the contract: branch names, commit
format, naming conventions, and the code-shape rules CI enforces.

## Prerequisites

```bash
brew install xcodegen swiftlint
```

Xcode 26.2 or later and Swift 6.2 or later. DockNanny targets macOS 26 (Tahoe)
and Apple Silicon.

## Branches

`main` is always releasable. Nothing is ever committed or pushed to it
directly; every change arrives through a pull request.

Branch names are `<type>/<scope>-<short-kebab-description>`:

| Type        | Use for                                        | Example                              |
| ----------- | ---------------------------------------------- | ------------------------------------ |
| `feat`      | New user-facing capability                      | `feat/core-display-registry`         |
| `fix`       | Bug fix                                         | `fix/ui-left-edge-panel-offset`      |
| `spike`     | Time-boxed investigation, may be thrown away    | `spike/skylight-space-probe`         |
| `refactor`  | Behaviour-preserving restructure                | `refactor/config-split-settings`     |
| `docs`      | Documentation only                              | `docs/permissions-onboarding`        |
| `chore`     | Tooling, deps, housekeeping                     | `chore/bump-swiftlint`               |
| `ci`        | Build and workflow changes                      | `ci/add-lint-job`                    |
| `brand`     | Icons, mascot art, marketing assets             | `brand/onboarding-illustrations`     |

Scopes match the module the change lands in: `core`, `ui`, `config`,
`private`, `app`, `spike`, `build`, `ci`, `docs`, `brand`.

Keep branches short-lived. If one outlives a week, it is too big.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), for a readable
history. `CHANGELOG.md` is written by hand and is where the release notes come
from (`tools/release-notes.sh`).

```
<type>(<scope>): <imperative summary, lowercase, no trailing period>

<optional body explaining WHY, wrapped at 72 columns>
```

Good:

```
feat(core): resolve window ids via _AXUIElementGetWindow

Title-plus-frame matching misidentified windows whenever two documents
shared a name. The private accessor returns the window server's own id,
so the ambiguity disappears.
```

Bad: `update stuff`, `fix bug`, `WIP`.

## Swift naming

Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
On top of those:

- Types are `UpperCamelCase`, members are `lowerCamelCase`.
- One primary type per file, named for it. A small type that exists only for
  that file (a value it builds, a private row view, a box that cleans up in
  its deinit) may share it, and closely related option enums may share a file
  named for the group (`DockStyle.swift`); splitting four eight-line enums into
  four files would trade one rule for the deep-modules rule.
- Protocols are nouns (`SpaceFilter`) or capability adjectives
  (`PanelPositioning`). Never prefix with `I` or suffix with `Protocol`.
- Spell things out. `displayIdentifier`, not `dispId`. The only accepted
  acronyms are `ID`, `URL`, `AX`, `CG`, `CGS`, `SLS`, `UI`, `API`, and they
  keep their casing: `displayID`, `windowID`, `axElement`.
- Booleans read as assertions: `isVisible`, `hasResolvedID`, `canJoinAllSpaces`.
- Every private Apple symbol is resolved in `Sources/Core/PrivateSymbols.swift`
  and carries a comment naming the framework it lives in and what the app
  falls back to if Apple removes it.
- Tests use swift-testing. The behaviour under test goes in the `@Test`
  display string as a sentence a reviewer can read in the failure output
  ("A dock on a display at negative y stays on that display"), and the function
  name is a short camelCase restatement of it. An XCTest-style
  `test_subject_condition_expectation` function name adds nothing when the
  sentence is already right there.

## Code shape

DockNanny optimises for the reader, not the compiler. Human working memory
holds about four things at once, so:

- Extract compound conditionals into named intermediate values rather than
  stacking `&&` and `||` inside an `if`.
- Prefer early returns over nested `if` blocks. Let the reader follow the
  happy path in a straight line.
- Prefer deep modules (simple interface, real work inside) over many shallow
  ones. A layer that only forwards a call should not exist.
- Comment the WHY and the bird's-eye WHAT. Never restate the line below.
- A little duplication beats a wrong abstraction.

File size is linted, not merely suggested:

| Lines  | Meaning                                                    |
| ------ | ---------------------------------------------------------- |
| ~300   | The aim. SwiftLint warns here.                             |
| ~500   | Split into focused sibling modules by responsibility.      |
| 1000   | Hard ceiling. SwiftLint fails the build.                   |

Generated files and fixtures are exempt; tests are linted at the same thresholds.

## Before opening a pull request

```bash
xcodegen generate
swiftlint --strict
xcodebuild test -project DockNanny.xcodeproj -scheme DockNanny -destination 'platform=macOS'
```

There is no root `Package.swift`, so `swift test` does not run this project's
suite. (`Spike/` is a separate package and builds with `swift build`.)

Fill in the pull request template. Describe the WHY, list what you verified
by hand (permissions flows and multi-monitor behaviour cannot be unit
tested), and attach a screenshot or recording for anything visual.

## Private Apple APIs

Two features have no public equivalent, and the rules for them are:

1. Every private symbol is resolved with `dlsym` in
   `Sources/Core/PrivateSymbols.swift`, nowhere else, with a comment naming
   where it lives and what happens without it. A missing symbol costs the
   feature, never the app.
2. Today there are two: `_AXUIElementGetWindow` gives the window keeper and
   the probe a window number (absent, frames come from the app's own report)
   and `CoreDockSendNotification` drives Show All Windows (absent, the app is
   only activated).

This, and the Accessibility use, is why DockNanny cannot ship on the Mac App
Store. Distribution is an ad hoc signed DMG (notarized once a Developer ID
exists) and a Homebrew cask that strips the quarantine.

## Signing for development

macOS keys an Accessibility grant to the app's designated requirement. A
plain ad hoc signature (`codesign --sign -`) has a requirement that is a
hash of the binary, so every rebuild is a new app as far as macOS is
concerned: the grant stops applying while System Settings keeps listing
DockNanny as allowed.

`tools/dev.sh` builds, signs and relaunches. Without a certificate it signs
ad hoc with the bundle identifier as the requirement
(`designated => identifier "app.docknanny"`), which every build satisfies, so
the grant survives rebuilds. With a code-signing certificate in the
keychain, or one named with `DOCKNANNY_SIGN_IDENTITY`, it uses that instead;
no certificate, Apple ID or trust setting is needed for the default.

After switching how a build is signed, remove any stale DockNanny entry from
System Settings > Privacy & Security > Accessibility and grant once more.

One caveat with the default: any ad hoc build claiming the identifier
`app.docknanny` satisfies that requirement, so another such build on the same
Mac inherits the grant. Release builds carry the same requirement (RELEASING.md,
Signing), so the caveat applies to them too until a Developer ID exists.
