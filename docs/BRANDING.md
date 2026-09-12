# Branding

macdock's mascot is a quokka: an approachable expert, which is the right tone
for a utility that has to ask for intimidating permissions.

## Mark versus mascot

The **glasses are the logo**, not the quokka. At 16pt in the menu bar a quokka
renders as brown mush, while the black frames with lime lenses and robot eyes
stay legible. Use the quokka for README art, onboarding and empty states; use
the glasses alone for the menu bar, favicon and small chrome.

The menu bar icon must be a **template image**: pure black with alpha, no
colour. macOS recolours it for light, dark and tinted menu bars. A coloured
icon there looks wrong on half of all setups.

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| Brand lime | `#8BC53F` | Accent, lenses, highlights |
| Deep forest | `#1E3A1E` | Icon ground, robot eyes |
| Mug black | `#141414` | Mascot prop, dark chrome |

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

Prompt 22 becomes the menu bar template image.

## App icon

macOS 26 uses a layered icon system. Generate the quokka on a transparent
background **separately** from the green circle ground, so foreground and
background can be supplied as distinct layers later and pick up the native
Liquid Glass depth treatment. The flat composite still renders correctly in
the meantime.

The `.icns` ladder (16 through 1024, each at 1x and 2x) is produced from a
single 1024 master by script, never by generating each size separately.

## The placeholder mark

Until the mascot artwork is generated, `tools/make-icon.swift` draws the glasses
mark from the brand geometry and writes the whole icon ladder:

```bash
swift tools/make-icon.swift assets/branding
```

It emits `macdock.iconset/` (the ten rungs macOS expects), a 1024 composite, and
`mark-foreground-1024.png`: the glasses on transparency, kept separate so the
foreground can be layered over a new ground when the mascot arrives, which is
what macOS 26's layered icons want.

Replacing it is a matter of dropping new PNGs into
`Resources/Assets.xcassets/AppIcon.appiconset/`. Nothing in the code refers to
the artwork directly; the onboarding header reads the bundle's own icon.

## Where assets live

```
assets/branding/               masters, 1024x1024 transparent PNG
assets/branding/icon-512.png   README header
```
