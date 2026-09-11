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
| `design/labels.json` | The suite's single source of truth for the GitHub/Linear label taxonomy |
| `design/labels.schema.json` | Its schema |
| `design/suite.schema.json` | Schema for the per-repo `.claude/suite.json` |
| `plugins/suite-kit/` | The shared Claude Code plugin |
| `plugins/suite-kit/suite-check.py` | Runs a repo's checks from its `.claude/suite.json`, with no plugin installed |
| `scripts/bootstrap.sh` | Clones the products as siblings |
| `scripts/lib/python.sh` | Resolves a Python 3 interpreter for the other scripts, and strips CRs from its output |
| `scripts/adopt.sh` | Scaffolds a repo's manifest, settings block and vendored files |
| `scripts/sync-tokens.sh` | Vendors `design/tokens.json` into each product (`--check` to detect drift) |
| `scripts/sync-runner.sh` | Vendors `suite-check.py` into each product (`--check` to detect drift) |
| `scripts/sync-notes.sh` | Vendors the release-notes generator, its tests and GitHub's fallback layout into each product; a product's `.github/changelog.json` is the adoption marker (`--check` to detect drift) |
| `scripts/sync-aislop.sh` | Vendors `.aislop/base.yml` into each product that has adopted aislop (`--check` to detect drift, and a config that does not extend it) |
| `scripts/sync-priority.sh` | Vendors `.github/workflows/issue-priority.yml` and renders the forms' priority question from `design/labels.json` (`--check` to detect drift) |
| `.aislop/base.yml` | The suite's aislop policy; each repo's `.aislop/config.yml` extends it with only that tree's size ratchet |
| `.github/workflows/aislop.yml` | The aislop gate as a reusable workflow, pinning aislop and ruff once; `ci.yml` here and each product's CI call it |
| `.github/workflows/pr-labelled.yml` | The pull-request label gate as a reusable workflow, called from each product's CI |
| `.github/workflows/drift.yml` | The cross-repo drift checks, on every push and nightly |
| `scripts/sync-labels.sh` | Applies `design/labels.json`'s GitHub side via `gh` (`--check` to detect drift) |
| `scripts/validate-schemas.sh` | Validates every manifest against its schema |
| `scripts/check-participation.sh` | Checks each repo's permissions floor, the paths its manifest names, its formatting settings, and that every vendored file is excluded from that repo's own formatter and scanner (`--require-products` to fail on an uncloned one) |
| `docs/adopting.md` | How a repo adopts suite-kit |
| `docs/conventions.md` | Cross-repo rules: tracking, PR magic words, permissions |
| `docs/linear.md` | The Linear structure `/suite-kit:suite-sync` mirrors GitHub Issues into |
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

**A vendored file is never touched by a product's own tools.** Every sync script
byte-compares its master against the product's copy, so a product formatter or
scanner that rewrites one creates drift nothing but the next sync can undo. That
happened once: Konnekt's aislop gate ran `ruff format` over its vendored
`release-notes.py`, and the nightly was red for a week. The masters here are held
to the same gate the products run, so they arrive clean, and
`check-participation.sh` checks that each product's `.aislopignore` and root
`.prettierignore` list what it vendors.

## Before calling a task done

Run `/suite-kit:health`. It reads `.claude/suite.json` and runs every check, including
schema validation.

Where the plugin is not installed — a cloud container, an unattended agent, a bare
clone — run the check runner directly. It reads the same manifest and runs the same
checks. **Declaring a plugin in `.claude/settings.json` does not install it**, so this
is the normal case in those environments, not a fallback for broken ones.

In **this** repo the runner is already on disk as the plugin source, so there is
nothing to vendor — run `./plugins/suite-kit/suite-check.py`. In a **product** it is
the vendored copy at `.claude/suite-check.py`, put there by `./scripts/sync-runner.sh`
and committed in that product's own repo.

On Windows the runner shells out through Git's bash rather than `cmd.exe`, which
it finds via `SHELL`, `PATH`, or alongside `git`. The scripts it calls resolve
their own interpreter through `scripts/lib/python.sh`, so a stock install with
`python` and the `py` launcher and no `python3` works without anything being
aliased by hand.

A check that could not run is **skipped**, never passing. Most of the value of the
health check is the gap between "I ran the checks" and "the checks passed". The runner
enforces that distinction mechanically: a grep over a path that does not exist, a
`pnpm` script with no `package.json`, a command whose dependencies were never
installed — each is a skip with a reason, and none of them is a pass.

**Token drift is deliberately not one of those checks.** `/suite-kit:health` reports on
one repo; drift detection needs every product cloned beside this one, which the `Suite drift`
workflow (`.github/workflows/drift.yml`) guarantees with `bootstrap.sh` and a bare
clone does not. Including it here would fail on a clean checkout. Run the `--check`
form of each `sync-*.sh` script yourself when you have a full workspace.

## Writing docs in this repo

This repo's whole purpose is being the place things are true, so a claim here costs
more than a claim elsewhere. It has been wrong about itself before — `docs/adopting.md`
carries a note about a revision that recorded both products as adopted when neither
was.

Describe what is on disk, in the present tense. Put intent in `docs/roadmap.md` as an
unchecked item. If you are unsure whether something landed, check before writing it
down.
