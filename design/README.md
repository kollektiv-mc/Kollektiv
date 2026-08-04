# Design tokens

`tokens.json` is the suite's single source of truth for design values. Every
product derives its own token output from it; no product hand-copies another's.

```
kollektiv/design/tokens.json          the source
        │
        │  scripts/sync-tokens.sh     copies it into each cloned product
        ▼
<product>/tokens.source.json          vendored, committed
        │
        │  the product's own generator
        ▼
<product>/src/styles/tokens.css       generated, committed
```

Both products are **consumers**. The source lives here, in the umbrella repo, so
that nothing both produces and consumes the token set — which is what makes
regenerating safe.

---

## Why the values carry no CSS

Konnekt and Kommands both happen to run Tailwind v4 over CSS custom properties
today, so a `.css` file in this repo would work. It would also quietly assume that
stays true. A third product on a different stack — or a native shell, or a
design-tool export — would then be reading a format built for someone else.

So values here are plain data:

| Instead of | This file holds |
|---|---|
| `rgba(255, 255, 255, 0.06)` | `{ "hex": "#ffffff", "alpha": 0.06 }` |
| `cubic-bezier(0.4, 0, 0.2, 1)` | `[0.4, 0, 0.2, 1]` |
| `'Excon', var(--font-sans)` | `["Excon", "@sans"]` |
| `10px` | `10`, with `"unit": "px"` on the group |

That is the whole extent of it. There is no colour-space modelling, no reference
resolution beyond font stacks, no theming DSL — those would be design for a
requirement nobody has.

## Conventions

- **`"light": null`** — the token inherits its dark value. The generator emits no
  light override for it.
- **`"@sans"`** in a font stack substitutes that family's stack. The only
  reference syntax in the file.
- **`"userConfigurable": true`** — the value is a *default* the user may override
  at runtime, via Konnekt's colour pickers. A generator must not bake it in as
  fixed.
- **`color.status`** members are expected to be exposed as separable colour
  components *and* a composed value, so alpha can be varied from a single token
  rather than a second one per opacity.

## Adding a token

1. Add it to `tokens.json`. Name it by **role**, never by appearance —
   `bg-elevated`, not `grey-800`. An appearance-named token becomes a lie the
   first time a theme changes it.
2. `./scripts/sync-tokens.sh` to push the new source into each cloned product.
3. In each product, run its token generator and commit the regenerated output
   alongside the vendored source.

A missing value is a token to add, not a literal to inline. That rule is enforced
per-repo by `/suite-kit:design-tokens`.

## Two things not held here

**Skins.** Konnekt's `BUILTIN_SKINS` (midnight, nord, solarized, mocha) override
shared token *names* with product-local values. They are a desktop-app feature,
not a shared design decision, and they stay in `Konnekt/frontend/src/lib/theme.ts`.

**Shadows.** There are no shadow tokens, deliberately. Elevation is communicated
by translucent surfaces plus hairline borders. The suite uses zero drop shadows;
the only permitted `box-shadow` is an accent-tinted glow inside a keyframe. If a
design seems to need a drop shadow, it needs a different surface or border.

## Why products vendor rather than read this path

`scripts/bootstrap.sh` clones the products as siblings, so a workspace checkout
*could* reference `../kollektiv/design/tokens.json` directly. Products vendor a
copy instead, because Konnekt has a tag-driven release that builds from a
standalone clone — requiring a `kollektiv` checkout to produce a binary would
break it.

The vendored copy is a pinned input, the same shape as Kommands pinning mcmeta
tags for its command data. Drift between a vendored copy and this file is caught
by each product's health check, which regenerates and expects a clean diff.
