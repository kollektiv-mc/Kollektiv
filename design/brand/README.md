# Kollektiv mark

The Kollektiv mark is a cube built from eight smaller ones, pulled apart so
each block stands on its own: a collective of individuals that still make one
shape. The bottom layer carries the products, Konnekt green in the centre,
Kommands ember on the left and Kube violet on the right, under a neutral top
layer. Each block is drawn the way Konnekt's is, so the suite's mark and the
products' share one construction, and the suite carries every product's colour
while each product mark keeps only its own.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="lockup-on-dark.svg">
  <img src="lockup-on-light.svg" alt="The Kollektiv mark beside the Kollektiv wordmark" width="420">
</picture>

It replaced the first Kollektiv mark, three blocks stacked as a triangle, on
2026-11-11. Both studies are private to the project: the cube directions at
https://claude.ai/artifact/Vn4AFGM5FssNRRAastwxpx and the earlier ones at
https://claude.ai/artifact/GccCUv5yydu2buzQYMZSEE.

## Files

Every file is an SVG on a transparent background, except the app icons. Where
the ground shows between blocks it is left undrawn, and in the one-colour files
the gaps between faces, and between a block and the blocks behind it, are
masks, so all of them are real transparency on any ground.

| File | Use |
| --- | --- |
| [`mark-on-dark.svg`](mark-on-dark.svg), [`mark-on-light.svg`](mark-on-light.svg) | The mark, at 17 px and above |
| [`mark-16-on-dark.svg`](mark-16-on-dark.svg), [`mark-16-on-light.svg`](mark-16-on-light.svg) | 16 px and below, drawn on a 16 grid |
| [`mark-mono-white.svg`](mark-mono-white.svg), [`mark-mono-black.svg`](mark-mono-black.svg) | One colour: the faces are separated by gaps instead of shade |
| [`lockup-on-dark.svg`](lockup-on-dark.svg), [`lockup-on-light.svg`](lockup-on-light.svg) | Mark and wordmark, the wordmark outlined |
| [`app-icon.svg`](app-icon.svg) | The mark at 80 % on a full-bleed `#05060a` square |
| [`app-icon-16.svg`](app-icon-16.svg) | The 16 cut on the same square, for 16 px favicons |
| [`construction.svg`](construction.svg) | The construction below |

## Construction

<img src="construction.svg" alt="The mark at ten times, with its live area, its outline and each visible block's centre" width="360">

Drawn on a 24-unit grid, like Konnekt's. The mark fills a 21-unit live area,
1.5 units in from every edge, and is centred on its own bounds.

| Part | Rule | Value in `mark-on-*.svg` |
| --- | --- | --- |
| View | Isometric: an orthographic projection that foreshortens all three axes equally, the same view as Konnekt's block | |
| Cube | 2 × 2 × 2 cells, seen from above the front corner | |
| Block | An isometric cube centred in its cell, its edge 0.7 of the cell's | cell *r* = 6.176, block *r* = 4.324 |
| Order | Drawn back to front, so a nearer block covers the ones behind it, and the faces of the blocks behind show in the gaps | |
| Base | Each block's faces sit on a hexagon filled with its left face's shade, so the seams between faces anti-alias against the block's own colour, not the ground, and draw no dark line | |
| Bounds | Set by the live area's height: a hexagon of radius *r* × 1.7 | 18.19 × 21 |

Seven blocks show. The eighth, at the back of the bottom layer, sits exactly
behind the front top one and is hidden by it.

## Sizes

The full mark holds down to 17 px: the gaps between blocks are 1.6 units wide,
so at 24 px each is still more than a pixel.

At 16 px and below it is redrawn on its own 16 grid, with each block at 0.75
of its cell rather than 0.7, so that every vertical edge sits on a whole pixel
(x = 1, 3, 5, 7, 9, 11, 13, 15) and the mark stays sharp in a tab. Its top and
bottom points reach 0.08 past the 16 grid and are cut there, which no pixel
shows.

Sizes are device pixels, as in Konnekt's README: a mark laid out at 16 px on a
2× screen takes the full drawing.

<img src="mark-16-on-dark.svg" width="16" alt="16 px"> <img src="mark-on-dark.svg" width="24" alt="24 px"> <img src="mark-on-dark.svg" width="32" alt="32 px"> <img src="mark-on-dark.svg" width="64" alt="64 px"> <img src="mark-on-dark.svg" width="128" alt="128 px">

## Colour

Each block takes three shades: the lightest on top, the darkest on the right.
The three product blocks take their product's colour and the other five a
neutral grey. On light grounds the products step one shade darker, as
Konnekt's do, and the neutral turns to a dark slate so the top layer keeps
its weight against a pale ground.

| Block | On dark: top, left, right | On light: top, left, right | Where the colour comes from |
| --- | --- | --- | --- |
| Konnekt | `#4ade80` `#22c55e` `#16a34a` | `#22c55e` `#16a34a` `#15803d` | Tailwind's green 400 to 700, Konnekt's `accent` |
| Kommands | `#fb923c` `#f97316` `#ea580c` | `#f97316` `#ea580c` `#c2410c` | Tailwind's orange 400 to 700, Kommands' `PRODUCT_ACCENT` |
| Kube | `#a57ffe` `#9362f4` `#7d49da` | `#9362f4` `#7d49da` `#6429bc` | Chosen here, see below |
| Neutral | `#eef0f6` `#b4b9c7` `#7c8293` | `#5c6272` `#3a3f4c` `#1d2029` | Chosen here: a cool grey at the hue of the suite's `bg-base` |

Each product's top face is its token in `tokens.json`'s `color.brand`:
`brand-konnekt`, `brand-kommands` and `brand-kube`, the top on dark as the
token's dark value and the top on light as its light one. The other faces are
the mark's construction, not identities anyone else paints with, so they stay
in these files, and so does the neutral, which is no product's colour. A brand token is a product's identity colour, for a mark, a
tile or a glow, and not a text colour: text in a product's colour uses its
`accent`, which a product darkens on light grounds for contrast.

**Kube's violet.** In OKLCH it is hue 295, with each face 0.09 darker than the
green and ember ladder (0.69, 0.62, 0.545; 0.455 on light) so that its top face
reaches the green's chroma of 0.18. A lighter violet at the green's lightness
could not: in sRGB, violet that light tops out near chroma 0.12 and reads as
washed out beside the other two. Hue 295 was chosen because it is the furthest
from green, ember and the status colours, and because green and ember are
close for deuteranopes (an OKLab distance of 7, against 26 for typical colour
vision, simulated with Machado, Oliveira and Fernandes 2009), so the third
colour has to be the one that stays apart. It does, in all three simulations.

| Part | On dark | On light |
| --- | --- | --- |
| Wordmark | `#ffffff` | `#0b0d12` |

## Lockup

The same rules as Konnekt's, so the two lockups sit together:

- The mark's box is 1.2 times the wordmark's font size, and its centre sits on
  the middle of the cap height.
- The gap between the box and the wordmark is 0.4 times the font size.
- The wordmark is Geist SemiBold at -0.03 em tracking, outlined from Geist 1.200
  (the npm `geist` package). Geist is © Vercel under the SIL Open Font License 1.1.
- Clear space: at least half the mark's height on every side.
- Minimum sizes: the mark at 16 px with the 16 cut; the lockup at 96 px wide.
  Below that, use the mark alone.

The lockup file is 1.05 times as tall as its font size, because the mark is
taller than the wordmark's caps. To set the wordmark at a given font size, size
the image at 1.05em; the website does.

## Do not

- Move the product colours to other blocks, or give a product a block in
  another's colour.
- Colour a top-layer block. The neutral layer is what lets the three products
  read as one row; a fourth product means redrawing the colouring.
- Close the gaps or change the block size. At 0.7 of a cell the blocks read as
  separate; nearer 1 it is one cube with seams.
- Scale the 16 cut up, or the full mark down past 17 px.
- Add outlines, shadows, gradients or glows, or recolour outside the table above.
- Put the coloured mark on a mid-tone ground. Use the app icon tile, or a mono file.

## Where it is used

- **Website.** The favicons are `app-icon-16.svg` rendered at 16 px and
  `app-icon.svg` at 32 and 256 px, in `website/assets/img/`. The bar and the
  footer show `lockup-on-dark.svg`, copied there as `lockup.svg`. Re-copy and
  re-render them when this folder changes.
- **The products.** Nothing yet. Konnekt keeps its own mark in its
  `docs/brand/`.
