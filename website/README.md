# website

Kollektiv's home page: hand-written HTML and CSS with one small script, no
build step. Open `index.html` in a browser, or serve the directory:

```sh
python3 -m http.server -d website
```

## What is here

| Path | What it is |
|---|---|
| `index.html` | The one page |
| `styles.css` | Layout and the page vocabulary — every value the token set does not hold |
| `main.js` | Runs the hero carousel and fills each product's pill with the release GitHub reports; the page reads fine without it |
| `tokens.css` | **Generated.** Custom properties from `design/tokens.json`. Do not edit |
| `gen-tokens.py` | Writes `tokens.css` and `assets/img/favicon.svg` from the token source |
| `assets/img/favicon.svg` | **Generated.** The wordmark's initial, coloured from the tokens |
| `assets/img/konnekt.png` | Konnekt's dashboard, the same shot its own website uses |
| `assets/img/kommands.png` | Kommands' `//generate` editor with its 3D preview, captured from a dev build |
| `assets/fonts/` | Satoshi Black, Excon Medium, Ranade Regular as woff2 — the faces `type.family` names, self-hosted |

## How it is styled

The site is a consumer of `design/tokens.json` like every product is, with one
difference: it lives in the repo that holds the source, so it reads the file
directly instead of a vendored copy. `gen-tokens.py` turns it into `tokens.css`,
and `index.html` links that ahead of `styles.css`.

```
design/tokens.json ──gen-tokens.py──▶ website/tokens.css        (committed)
                                    ▶ website/assets/img/favicon.svg
```

The custom-property names match what Konnekt's generator emits for its own
website (`--bg-base`, `--accent-rgb`, `--font-display`, `--radius-panel`,
`--duration-fast`), so a rule reads the same on either site.

**What `styles.css` may declare itself.** The token set is the *app* scale — a
12px body and 24px as its largest space — and a marketing page has display
sizes and a section rhythm no app UI has. Those live in the `:root` block at the
top of `styles.css`, marked as page vocabulary, the same split Konnekt's website
makes. Two rules keep it honest:

- Nothing in that block is a colour. Colours come from the tokens, always.
- Nothing outside that block redeclares a token or inlines a value the tokens
  hold. A value the apps could share belongs in `design/tokens.json`.

Two literals sit outside CSS and cannot read a custom property: the
`theme-color` meta tag in `index.html`, which restates `bg-base`, and the
favicon, which is why the generator writes it.

## The hero

The whole first viewport. The products are a carousel of 16:9 windows,
Konnekt first, centred with the previous and next peeking in past the page's
side padding; it is the one element that crosses that padding. The window in
focus is drawn at full size and in colour, with its description and actions
unfolded beneath the name; its neighbours are smaller, black and white, text
included, with the name alone laid on whichever edge of them is visible. Only
the painted window scales, never its layout box, so the carousel still moves
by whole windows.

The window in focus is ringed by a soft glow in its product's colour while the
carousel is at rest and the pointer is on it — at rest, because a tile sliding
under a resting pointer would otherwise light up on the way past — on the window itself, not on the carousel, which is a band
the width of the viewport. The glow doubles as the reason the carousel has
stopped. It reaches further than the carousel's clip edge, so the carousel
clips with `overflow-clip-margin` rather than `hidden`; horizontally that
lets the tiles paint past the viewport, which is what `.hero`'s own
`overflow-x: clip` is for.

The foot of the window in focus is frosted — a backdrop blur under the
gradient, masked so it fades out rather than ending on a line across the
picture — which is what makes the copy readable while the upper half of the
app stays sharp. It fades in with the copy, on the same duration and easing.

A bar along the foot of the window in focus fills over eight seconds and the
carousel moves on when it is full. Hovering a window holds it and pauses the
bar; so does opening the card, and so does a hidden tab. Clicking a neighbour, or an app in the
nav, moves to it; clicking the window in focus opens its card. It never moves
by itself for a viewer who asked for reduced motion, and on narrow screens and
touch devices it is a plain column where every window is in focus.

### The wireframe

The app in focus turns slowly behind the carousel, large enough to reach past
the windows on every side: a geodesic sphere for Konnekt, a torus for
Kommands, a cube for Kube. The sphere is an icosahedron with every face cut
into four and every vertex pushed out onto the unit sphere, so every face is a
triangle and no vertex is special — a sphere of latitude rings and meridians
converges on a pole instead, and the pinch reads as a mistake. One canvas for the page rather
than one per tile — it is the page's background, and the windows are opaque,
so a shape drawn inside a tile would have been drawn on top of the app. When
the carousel moves on, the old shape fades out and the new one fades in, and
the swap happens at the point where neither is on screen. Each shape is built
once and kept: the "already showing this" test compares by name, and when it
compared freshly built objects instead it never matched, so every pass through
mark — and a wrap makes two in a row — restarted the morph and the shape
flashed.

`main.js` projects a few dozen edges onto a canvas; that needs no library, and
a library is a dependency this page has no other use for. Each shape is
normalised by its own reach, so a cube's corners and a sphere's surface come
out the same size, and each carries its own tilt — a torus at the angle that
suits a sphere is seen nearly edge-on and reads as an arc rather than a ring.

The stroke colour is read from the tile's `--tile-glow-rgb` at draw time —
the same move Kommands makes in `voxelColor` when it needs a token as a value
rather than as a class — so nothing in the drawing code restates a design
value. That is why `main.js` is covered by the no-literal-colours invariant
alongside `styles.css`.

Kommands' glow and shape are its own ember orange, `PRODUCT_ACCENT` in
that repo's `src/lib/theme.ts`, which is kept out of the suite tokens on
purpose (see `design/README.md` § Two things not held here). The value is
restated inline on its tile in `index.html`, with a comment saying where it
comes from; the other tiles take the suite accent. Kube's window is blank on
purpose: nothing is built yet, and a mock-up would say otherwise — and because
that window is the one translucent surface in the carousel, its cube shows
through it rather than only around it.

### The card

Clicking the window in focus, or its ⤢ button, grows it into a `<dialog>` over
a scrim: one card, sized to the window, that never scrolls. It starts laid
over the window it came from — same centre, same width, scaled evenly rather
than to that window's exact box, since a card squashed to another aspect ratio
distorts every word in it on the way out — and closing reverses it, which the
carousel being held for as long as the card is open is what makes possible. Its four
placeholders share out whatever height the text leaves rather than being
sized in the abstract, which is what keeps that true at any window size.

The card sits on its product's own ground rather than the suite's: Kommands'
warm canvas at its ember hue, a placeholder purple for Kube, and for Konnekt
the suite's own `bg-overlay`, which is what that product uses. Each is the
`overlay` of that product's skin, which `design/README.md` defines as
`bg-elevated` composited over `bg-base`; Kube's is built the same way at a
purple hue rather than picked by eye. They are set inline on the tiles in
`index.html`, the same exception as Kommands' accent and for the same reason.

Everything else in it is cloned from the tile it came from — the name and pill from
the window, the detail and placeholders from that tile's `<template>`, the
buttons from its actions — so a product is described in one place and the card
cannot drift from the window it opened out of.

A `<dialog>` rather than a div because the browser then owns the focus trap,
Escape, and inerting the page behind it. Two things it does not own: the grow
and the fade, which is why Escape is intercepted and the close is deferred;
and the text colour, since a dialog's UA rule sets `color: CanvasText` and
wins over anything inherited from `body`. The starting transform is flushed
with a forced reflow rather than waited for over a frame — the first frame
after `showModal` is an expensive one, and waiting for it left the card
sitting on the window before it grew.

## What the pills say

Each product's pill ships saying only `desktop` or `web`. `main.js` then asks
the GitHub API, per repo, for the latest release; failing that the newest
prerelease; failing that it says `in development` with the date of the last
commit, or without one for a repo that has no commits yet. A request that fails leaves the pill as shipped, so the page never
claims a version it did not fetch. The same element appears in the hero and in
the downloads table and is filled from one answer.

## Copy

**No em dashes.** Everything on this page is published, so it falls under
`docs/conventions.md` § Public copy: use a comma, a colon, or two sentences.
The comments in these files are not published and are unaffected.
`scripts/check-copy.sh` checks the page and reports the line.

Short, and about what a user gets. The sections about Kollektiv say what the
suite is and the fixed ideas behind it — local and private, made to work
together, a UI over a terminal, in the open — and do not name or describe
the apps; what an app does belongs in its own tile and its own site. How the
suite is built — the shared tokens, the checks, the conventions — is this
repo's README's to explain, not the page's.

## Checks

`.claude/suite.json` declares `gen-tokens.py` as a generator whose output is
committed, so `./plugins/suite-kit/suite-check.py` fails when `tokens.css` or
the favicon is stale or hand-edited, and an invariant greps `styles.css` for
literal hex colours. CI runs the same clean-diff check.

## What is not here

- **A deploy.** Nothing publishes this directory yet; there is no canonical URL
  in the page for that reason.
- **A light theme.** The tokens carry light values, but the page has no theme
  switcher and nothing sets `data-theme`, so the generator emits dark only —
  same as Konnekt's site.
- **Product copy that is not true on disk.** The Kommands tile says the web
  build is not deployed and the desktop app is in development, because its
  README says so. Update the page when the products change, not before.
