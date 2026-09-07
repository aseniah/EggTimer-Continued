# assets

Source art and screenshots. This whole directory is `.pkgmeta`-ignored, so
nothing here ships in the addon zip. `Icon.tga` at the repo root is the only
image that does.

## the_egg.png

Raw AI render, ChatGPT (GPT-4o image generation), 2026-09-07. This is the one the
icon is built from.

> A World of Warcraft ability icon: a single large speckled egg, tan and cream
> mottled shell, with a fine glowing hairline crack down one side leaking warm
> golden light, a faint arcane-blue shimmer around the shell. Painterly
> oil-painted style with thick visible brushstrokes, strong rim lighting from the
> upper left, rich saturated color, slight 3/4 view. The egg is centered and
> fills roughly 85% of the frame. Background is a dark desaturated blue-black
> radial vignette with no scenery. Square 1:1 composition. No border, no frame,
> no text, no UI chrome. High contrast so it stays readable at small sizes.

## the_egg_timer.png

Raw AI render, same session. Not used as the icon (an hourglass reads as a
generic timer/cooldown addon at 20px, and the egg — the distinguishing element —
disappears). Kept for the CurseForge page banner, where it is shown large.

> A World of Warcraft item icon: an ornate brass-and-dark-wood hourglass, but in
> place of sand the upper bulb cradles a softly glowing speckled egg, with golden
> motes streaming down through the neck into the lower bulb. Painterly oil-painted
> style, thick brushstrokes, warm rim lighting from the upper left, arcane-blue
> accents in the glass. Centered, filling about 85% of the frame. Dark blue-black
> radial vignette background, no scenery. Square 1:1. No border, no frame, no
> text. High contrast, readable when small.

## icon-source.png

1024px square master, a centre-crop of `the_egg.png` that pushes the egg closer
to the frame edges so it reads bigger when shrunk. `Icon.tga` (128x128) at the
repo root is exported from the same crop. No ImageMagick on the build machine, so
this is `sips`:

```
sips -c 1120 1120 assets/the_egg.png --out /tmp/c.png
sips -Z 1024 /tmp/c.png --out assets/icon-source.png
sips -Z 128  /tmp/c.png -s format tga --out Icon.tga
```

To swap the icon: drop a new square PNG in here, rerun those three lines, and
keep `## IconTexture` in the `.toc` and `local ICON` in the lua pointing at
`Interface\AddOns\EggTimerContinued\Icon`.

## 01-MinimapHover.png

In-game screenshot: the minimap-button tooltip listing two characters' egg
timers. For the README and the CurseForge page.
