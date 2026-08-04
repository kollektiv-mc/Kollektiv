---
description: Apply the suite's design-token rule when writing or editing UI — no literal hex colours, no literal pixel values, every value comes from a named token. Use when styling a component, adding a colour or spacing value, or reviewing UI code for inlined literals.
---

# Design tokens

Read `.claude/suite.json` → `tokens` for this repo's `role`, `enforce` level, and
the `paths` the rule covers.

If that file is missing, say so and stop. Do not guess an enforce level or invent
the covered paths — a rule applied to the wrong paths is worse than no rule,
because it reports clean. The fix is to add `.claude/suite.json`; see
`kollektiv/docs/adopting.md`.

---

## The rule

Inside the covered paths: `var(--token)` or a semantic utility. Never a raw `#hex`,
never an arbitrary pixel value.

```tsx
<div className="text-2xs border-hairline border-border-subtle" />   // right
<div className="text-[10px] border-[0.5px] border-white/6" />       // wrong
<div style={{ color: '#4ade80' }} />                                // wrong
```

## Why it is absolute

Theming works by overriding custom properties on the root element at runtime. An
inlined value silently opts that element out of theming — and the breakage does not
appear in the default theme, which is the one being looked at while the code is
written. It surfaces later, in a theme nobody was testing.

That is why the rule has no "small enough to inline" exemption. The cost of the
mistake is not proportional to the size of the value.

## A missing token is a token to add

The scale deliberately names the awkward steps — the 9px, the 0.5px, the 10px
radius — precisely because those are the ones that get inlined.

**If a value seems to be missing, add a token.** Do not inline it, and do not
approximate with a nearby token; approximating is worse than inlining, because it
looks correct in review. Adding a token is a normal, expected change.

## Where a new token goes

The source is `kollektiv/design/tokens.json`. Every product repo is a
**`consumer`** — it vendors that file as `tokens.source.json` and generates its own
token output from it. No product repo defines the set, so none of them is the place
to add a value.

Adding a token is three steps, in order:

1. Add it to `kollektiv/design/tokens.json`, named by role, not appearance.
2. `./scripts/sync-tokens.sh` from the kollektiv root — refreshes the vendored copy
   in each cloned product.
3. In this repo, run the generator named by `tokens.generate` and commit the
   regenerated output alongside the updated `tokens.source.json`.

Editing generated token output directly is silently reverted on the next
regeneration, and the gap that prompted the edit survives. Editing
`tokens.source.json` directly is the same mistake one step earlier: the next
`sync-tokens.sh` overwrites it, and the other product never sees the value.

## Enforce levels

- **`strict`** — a match is a failure. Fix it.
- **`migrating`** — the codebase is mid-migration and pre-existing matches are
  expected. Report them, do not mass-rewrite, and hold new code to `strict`. A
  drive-by migration mixed into an unrelated change is how a mid-migration
  codebase stops being reviewable.
