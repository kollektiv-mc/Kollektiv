---
description: Apply the suite's design-token rule when writing or editing UI — no literal hex colours, no literal pixel values, every value comes from a named token. Use when styling a component, adding a colour or spacing value, or reviewing UI code for inlined literals.
---

# Design tokens

Read `.claude/suite.json` → `tokens` for this repo's `role` (`source` or
`consumer`), `enforce` level, and the `paths` the rule covers.

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

## Roles

- **`source`** — this repo defines the token set. A new token starts here.
- **`consumer`** — this repo derives its tokens. Add the token upstream first, then
  regenerate. Hand-editing generated token output is silently reverted on the next
  regeneration, and the underlying gap survives.

## Enforce levels

- **`strict`** — a match is a failure. Fix it.
- **`migrating`** — the codebase is mid-migration and pre-existing matches are
  expected. Report them, do not mass-rewrite, and hold new code to `strict`. A
  drive-by migration mixed into an unrelated change is how a mid-migration
  codebase stops being reviewable.
