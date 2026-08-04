# kollektiv

The umbrella repo for a small Minecraft tool suite: **Konnekt** (Wails · Go · React)
and **Kommands** (Vite · React). This repo owns **conventions, domain knowledge, and
agent tooling**.

It does **not** own builds, CI, or releases for the products — each keeps its own. A
change here that requires a product to rebuild is a change in the wrong place.

## What lives here

| Path | What it is |
|---|---|
| `design/tokens.json` | The suite's single source of truth for design values |
| `design/tokens.schema.json` | Its schema |
| `design/suite.schema.json` | Schema for the per-repo `.claude/suite.json` |
| `plugins/suite-kit/` | The shared Claude Code plugin |
| `scripts/bootstrap.sh` | Clones the products as siblings |
| `scripts/sync-tokens.sh` | Vendors `design/tokens.json` into each product (`--check` to detect drift) |
| `scripts/validate-schemas.sh` | Validates every manifest against its schema |
| `docs/adopting.md` | How a repo adopts suite-kit |
| `docs/conventions.md` | Cross-repo rules: tracking, PR magic words, permissions |
| `design/README.md` | Why the token set is shaped the way it is |

This repo is the **workspace root**. `Konnekt/` and `Kommands/` are cloned beneath it
by `bootstrap.sh` and are not tracked here.

## Rules that bite

**Tokens flow one way.** `design/tokens.json` is the only place a design value is
defined. Products are consumers: they vendor it as `tokens.source.json` and generate
their own output from it. Never add a value to a product; never edit a vendored
`tokens.source.json` (the next sync overwrites it); never edit generated token output
(the next regeneration reverts it). Add it here, run `./scripts/sync-tokens.sh`, then
regenerate in each product.

**Name tokens by role, never by appearance.** `bg-elevated`, not `grey-800`. An
appearance-named token becomes a lie the first time a theme changes it.

**A missing value is a token to add, not a literal to inline.** Approximating with a
nearby token is worse than inlining, because it looks correct in review.

**Nothing both produces and consumes the token set.** That asymmetry is what makes
regenerating safe — do not give a product `tokens.role: "source"`.

**Products vendor rather than reference.** Konnekt has a tag-driven release that builds
from a standalone clone; requiring a `kollektiv` checkout beside it would break that.

**suite-kit ships no hooks, deliberately.** Konnekt already binds `graphify hook-guard`
to `PreToolUse`; stacking more matchers is the fastest way to make both feel broken.

**Version bumps come in pairs.** `plugins/suite-kit/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` must agree — a health check fails if they diverge.

## Before calling a task done

Run `/suite-kit:health`. It reads `.claude/suite.json` and runs every check, including
schema validation.

A check that could not run is **skipped**, never passing. Most of the value of the
health check is the gap between "I ran the checks" and "the checks passed".

**Token drift is deliberately not one of those checks.** `/suite-kit:health` reports on
one repo; drift detection needs every product cloned beside this one, which CI's
`token-drift` job guarantees with `bootstrap.sh` and a bare clone does not. Including it
here would fail on a clean checkout. Run `./scripts/sync-tokens.sh --check` yourself when
you have a full workspace.

## Writing docs in this repo

This repo's whole purpose is being the place things are true, so a claim here costs
more than a claim elsewhere. It has been wrong about itself before — `docs/adopting.md`
carries a note about a revision that recorded both products as adopted when neither
was.

Describe what is on disk, in the present tense. Put intent in `docs/roadmap.md` as an
unchecked item. If you are unsure whether something landed, check before writing it
down.
