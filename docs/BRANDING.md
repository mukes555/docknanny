# Branding

DockNanny's mascot is a quokka: an approachable expert, which is the right tone
for a utility that has to ask for intimidating permissions.

## App icon, menu bar mark, mascot

The **app icon** is two displays, each with its own lime dock bar, on deep
forest: the proposition drawn literally, a dock on every display. The **menu
bar mark** is the same two displays reduced to outlines, 20 by 14 points.
Both are drawn by `tools/make-icon.swift` from one geometry, chosen from four
directions on the design canvas (the glasses, the dock as a symbol, a
monogram of tiles, and this one).

The quokka is the mascot, not the mark: at 16pt an animal is mush. Use the
quokka for README art, onboarding and empty states; the glasses remain its
signature and appear on nothing else.

The menu bar mark must be a **template image**: pure black with alpha, no
colour. macOS recolours it for light, dark and tinted menu bars. A coloured
icon there looks wrong on half of all setups.

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| Brand lime | `#C0DD71` | The accent everywhere: lenses, dock bars on screens, switches, highlights, the icon's glyph |
| Deep olive | `#1F2A16` | The icon ground's near corner, and backgrounds behind the mascot |
| Near black | `#0C100A` | The icon ground's far corner |
| Screen black | `#0E1408` | The screens inside the icon's displays |
| Mug black | `#141414` | Mascot prop, dark chrome |

Black and green: the icon is the lime glyph on a near-black ground, which
is what makes it read at 16 points and what keeps the lime from going
fluorescent. In the app the accent can be swapped for one of the sunny
family (Appearance, Accent) as a personal choice; the icon stays lime.

## Generation

Every mascot prompt is the scene plus this suffix, which keeps the character
on-model across tools and sessions:

```
3D rendered cute quokka, tan-brown fur, black chunky wayfarer glasses
with lime-green lenses showing a dark-green robot face icon, black matte
coffee mug, soft studio lighting, Pixar style, transparent background,
soft contact shadow, 1:1 square
```

Request 1024x1024 transparent PNG for all mascot art. Downscaling works,
upscaling does not.

### How prompts are built

Image tools follow a reference picture loosely and a precise description
consistently, so the logo and the character are each one fixed block that
goes into every prompt verbatim, and only a scene line changes. Attach
`assets/branding/icon-1024.png` to every generation; reuse the seed of the
first image that lands, and attach that image too once it exists, so the
character stays on-model across the set.

Logo block:

```
The DockNanny logo, reproduced exactly as in the attached reference image and used as the ONLY logo anywhere in the picture: a dark green-black rounded square; inside it two overlapping monitor outlines drawn in thick lime #C0DD71 lines, the near monitor at lower-left with a small stand beneath it, the far monitor at upper-right behind it; each monitor has one short lime bar along the bottom of its screen; the screens are near-black. Do not redesign it, do not add text, icons, apps or any other logo.
```

Character block:

```
3D rendered cute quokka, tan-brown fur, black chunky wayfarer glasses, both lenses matte lime #C0DD71 with the DockNanny logo small and centred on each lens, black matte coffee mug, soft studio lighting, Pixar style, muted natural colour grading, no glow, no neon, transparent background. Same character, same logo, same style in every image; only the scene changes.
```

### Scenes

The README hero is the quokka with an arc of displays behind its head, the
way a chakra or an aureole sits behind a deity: the logo on every one of
them, the quokka in front of all of them.

```
Wave: Quokka standing front and centre, waving with one paw, mug in the other, 1:1 square.
Halo A: Quokka front and centre, waving, an arc of five monitors fanned behind its head like a halo; every monitor shows the DockNanny logo large and centred on a near-black screen; 1:1 square.
Halo B: Quokka seated cross-legged, serene, a ring of seven thin displays behind its head, every display showing the DockNanny logo centred on a near-black screen; deep olive #1F2A16 background, matte finish; 1:1 square.
Banner: Wide 2400 by 900 crop, quokka at the left third, a halo of monitors behind its head trailing off to the right, every monitor showing the DockNanny logo, empty space on the right for a wordmark, deep olive #1F2A16 background, flat soft light.
```

Ask for 2048 by 2048 for the squares, 2400 by 900 for the banner,
transparent background where the tool allows it. The README shows the results
as `docs/media/quokka-wave.png` and `docs/media/quokka-halo.jpg`; the banner
render is `docs/media/banner-quokka.jpg`, which
`swift tools/make-banner.swift docs/media` composites with the wordmark into
`docs/media/banner.png`, the file the README shows at the top.

### Hero and README

```
1. Quokka standing between three floating glowing monitors, arms spread wide, proud
2. Quokka on a laptop screen edge, looking out at two big external displays
3. Quokka dragging a glowing app icon from one monitor to another, mid-motion
4. Wide banner: quokka centered, three monitors behind in a shallow arc, lime background
```

### Onboarding and permissions

```
5. Quokka pointing at a floating System Settings window, encouraging, one paw raised
6. Quokka holding a large key, offering it forward, friendly
7. Quokka holding a small camera, slightly shy, apologetic shrug
8. Quokka giving a double thumbs up, confetti, celebrating
```

### Empty and error states

```
9.  Quokka shrugging at an empty floating dock bar, puzzled
10. Quokka asleep in a hammock, mug on the ground, peaceful
11. Quokka holding a bent unplugged cable, worried, sweat drop
12. Quokka peeking out from behind a monitor, curious, only head visible
13. Quokka with a tiny fire extinguisher, small puff of smoke, sheepish
```

### Settings and features

```
14. Quokka adjusting a large slider control, focused, tongue out
15. Quokka holding a paint palette and brush, creative
16. Quokka sorting glowing app icons into two neat stacks
17. Quokka wearing a tiny hard hat, holding a wrench
```

### Distribution and social

```
18. Quokka carrying a cardboard box with a lime bow, delivering a gift
19. Quokka waving goodbye from a doorway, warm
20. Quokka relaxing in a deck chair between two monitors, mug raised in toast
```

### The mark, glasses only

Do not append the mascot style suffix to these.

```
21. Flat vector icon, black wayfarer glasses frame, lime-green lenses,
    dark-green robot eyes, centered, transparent background, minimal
22. Same glasses, pure solid black silhouette, no color, flat, 16x16 optimized
23. Same glasses, single continuous line-art style, 2px stroke, monochrome
```

## App icon

macOS 26 uses a layered icon system. `tools/make-icon.swift` draws the ground
and the glyph as separate passes so they can be supplied as distinct layers
later and pick up the native Liquid Glass depth treatment. The flat composite
renders correctly in the meantime.

The iconset ladder (16 to 512 points, each at 1x and 2x) is drawn rung by rung
from one geometry at each rung's own pixel size, never downscaled from a
master.

## Generating the icon

`tools/make-icon.swift` draws the icon ladder and the menu bar mark; copy the
results into the asset catalogue afterwards:

```
swift tools/make-icon.swift assets/branding
cp assets/branding/DockNanny.iconset/*.png Resources/Assets.xcassets/AppIcon.appiconset/
cp assets/branding/menubar*.png Resources/Assets.xcassets/MenuBarIcon.imageset/
```

It emits `DockNanny.iconset/` (the ten rungs macOS expects), `icon-1024.png`
(the composite) and `menubar.png`, `menubar@2x.png`, `menubar@3x.png` (the
template mark for the menu bar).

Replacing it is a matter of dropping new PNGs into
`Resources/Assets.xcassets/AppIcon.appiconset/`. The code refers to the
catalogue entries by name only (`AppIcon`, `MenuBarIcon`), so new PNGs are
enough.

## Where assets live

```
assets/branding/DockNanny.iconset/   the ten rungs
assets/branding/icon-1024.png        the composite
assets/branding/menubar*.png         the menu bar template mark
assets/branding/DockNanny-icon.svg   the icon as vector
assets/branding/DockNanny-glyph.svg  the bare glyph
docs/media/banner.png                README header
```
