# Contributing to macdock

Thanks for looking. This document is the contract: branch names, commit
format, naming conventions, and the code-shape rules CI enforces.

## Prerequisites

```bash
brew install xcodegen swiftlint
```

Xcode 26.2 or later and Swift 6.2 or later. macdock targets macOS 26 (Tahoe)
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

[Conventional Commits](https://www.conventionalcommits.org/), because the
changelog is generated from them.

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
- One primary type per file, and the filename matches it exactly. The single
  exception is a small set of closely related option enums, which may share a
  file named for the group (`DockStyle.swift`); splitting four eight-line enums
  into four files would trade one rule for the deep-modules rule.
- Protocols are nouns (`SpaceFilter`) or capability adjectives
  (`PanelPositioning`). Never prefix with `I` or suffix with `Protocol`.
- Spell things out. `displayIdentifier`, not `dispId`. The only accepted
  acronyms are `ID`, `URL`, `AX`, `CG`, `CGS`, `SLS`, `UI`, `API`, and they
  keep their casing: `displayID`, `windowID`, `axElement`.
- Booleans read as assertions: `isVisible`, `hasResolvedID`, `canJoinAllSpaces`.
- Every symbol wrapping a private Apple API lives in `Sources/Private` and
  carries a comment naming the framework it came from and what breaks if
  Apple removes it.
- Tests use swift-testing. The behaviour under test goes in the `@Test`
  display string as a sentence a reviewer can read in the failure output
  ("A dock on a display at negative y stays on that display"), and the function
  name is a short camelCase restatement of it. An XCTest-style
  `test_subject_condition_expectation` function name adds nothing when the
  sentence is already right there.

## Code shape

macdock optimises for the reader, not the compiler. Human working memory
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

Generated files, fixtures and tests are exempt.

## Before opening a pull request

```bash
xcodegen generate
swiftlint --strict
xcodebuild test -project macdock.xcodeproj -scheme macdock -destination 'platform=macOS'
```

There is no root `Package.swift`, so `swift test` does not run this project's
suite. (`Spike/` is a separate package and builds with `swift build`.)

Fill in the pull request template. Describe the WHY, list what you verified
by hand (permissions flows and multi-monitor behaviour cannot be unit
tested), and attach a screenshot or recording for anything visual.

## Private Apple APIs

Some features (per-display Space filtering, window ordering) have no public
equivalent. Rules for touching them:

1. Every private symbol is declared in `Sources/Private`, nowhere else.
2. Resolve symbols at runtime via `dlopen`/`dlsym` so a missing symbol
   returns nil instead of crashing the app.
3. Every dependent feature sits behind a protocol with a working no-op
   implementation, so the app degrades in function rather than failing.
4. Anything private is gated through `Capability` and is visibly reported in
   Settings, so users can see what is and is not available on their macOS.

This is why macdock cannot ship on the Mac App Store. Distribution is a
notarized DMG and a Homebrew cask.
