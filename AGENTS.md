# Kollektiv

The umbrella repo for a small Minecraft tool suite: **Konnekt** (Wails · Go · React)
and **Kommands** (Vite · React). This repo owns **conventions, domain knowledge, and
agent tooling** for the suite.

It does **not** own builds, CI, or releases for the products: each keeps its own. A
change here that requires a product to rebuild is a change in the wrong place.

Rules shared with Sandro's other projects come from the
[AllesSandro template](https://github.com/sandrogekeler/AllesSandro) and are in
`.claude/rules/`. An agent that does not load that directory itself reads
`working.md`, `writing.md` and `simplicity.md` there before starting. The template
also supplies the check runner, the shared workflows and the release-notes
generator, in this repo and in each product.

## What lives here

| Path | What it is |
|---|---|
| `design/tokens.json` | The suite's single source of truth for design values |
| `design/labels.json` | The suite's single source of truth for the GitHub/Linear label taxonomy |
| `design/suite.schema.json` | Schema for the per-repo `.claude/suite.json` |
| `design/brand/` | The Kollektiv mark, lockup and app icon, with their construction and colours |
| `plugins/suite-kit/` | The shared Claude Code plugin: skills and the `mc-reviewer` agent |
| `scripts/bootstrap.sh` | Clones the products as siblings |
| `scripts/lib/python.sh` | Resolves a Python 3 interpreter for the other scripts, and strips CRs from its output |
| `scripts/sync-tokens.sh` | Vendors `design/tokens.json` into each product (`--check` to detect drift) |
| `scripts/sync-labels.sh` | Writes `design/labels.json`'s GitHub side into each repo's `.github/labels.json` (`--check` to detect drift) |
| `scripts/cloud-setup.sh` | The cloud environment's setup script, pasted into the environment dialog rather than run from a checkout |
| `scripts/validate-schemas.sh` | Validates every manifest against its schema |
| `scripts/check-participation.sh` | Checks each repo's permissions floor, the paths its manifest names, its formatting settings, and that received files are excluded from its own formatter and scanner |
| `scripts/check-copy.sh` | Checks every repo's published copy for em dashes |
| `.github/workflows/drift.yml` | The cross-repo checks, on every push and nightly |
| `website/` | The suite's home page, styled from `design/tokens.json` through `website/gen-tokens.py` |
| `docs/adopting.md` | How a product joins the suite |
| `docs/conventions.md` | Cross-repo rules: tracking, PR magic words, permissions |
| `docs/linear.md` | The Linear structure `/suite-kit:suite-sync` mirrors GitHub Issues into |
| `docs/roadmap.md` | Direction and sequencing for this repo |

This repo is the **workspace root**. The repos in `suite.repos.json` are cloned
beneath it by `bootstrap.sh` and are not tracked here. A repo without
`.claude/suite.json` has not adopted, and every check skips it by that marker
rather than failing.

## Rules that bite

**Tokens flow one way.** `design/tokens.json` is the only place a design value is
defined. Products vendor it as `tokens.source.json` and generate their own output
from it. Never add a value to a product, edit a vendored `tokens.source.json`, or
edit generated token output. Add it here, run `./scripts/sync-tokens.sh`, then
regenerate in each product.

**Name tokens by role, never by appearance.** `bg-elevated`, not `grey-800`.

**A missing value is a token to add, not a literal to inline.** Approximating with a
nearby token is worse than inlining, because it looks correct in review.

**Nothing both produces and consumes the token set.** Do not give a product
`tokens.role: "source"`.

**Labels come from `design/labels.json`.** `./scripts/sync-labels.sh` writes them
into each repo's `.github/labels.json`; that repo's `labels` workflow applies them.

**Template files are changed in AllesSandro.** `.claude/rules/template-files.md`
lists them. A local edit conflicts on the next update and turns `template-guard` red.

**suite-kit ships no hooks, deliberately.** Konnekt binds `graphify hook-guard`
to `PreToolUse`; stacking more matchers makes both feel broken.

**Nothing written for a reader carries an em dash.** `scripts/check-copy.sh` checks
the websites; the rest is review. See `docs/conventions.md` § Public copy.

**Version bumps come in pairs.** `plugins/suite-kit/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` must agree: a health check fails if they diverge.

## Before calling a task done

Run `python3 .claude/suite-check.py`, or `/suite-kit:health` where the plugin is
installed. Both read `.claude/suite.json`. **Declaring a plugin in
`.claude/settings.json` does not install it**, so in a cloud container or an
unattended session the runner is the normal path.

A check that could not run is **skipped**, never passing. How the runner decides is
in `.claude/rules/suite-runner.md`.

**Cross-repo drift is not one of those checks.** It needs every product cloned
beside this one, which `.github/workflows/drift.yml` guarantees with `bootstrap.sh`.
With a full workspace, run `./scripts/sync-tokens.sh --check` and
`./scripts/sync-labels.sh --check` yourself.

## Task tracking

Work is tracked in GitHub Issues, mirrored into Linear by `/suite-kit:suite-sync`.
Every issue carries a `type:`, an `area:` and exactly one priority (`p0`-`p3`)
label. An issue opened through the API (by an agent) sets the label in the same
call, `p2` when unclear. Close issues from the pull request with `Fixes #N`.

## Pull requests

Follow `CONTRIBUTING.md`: one pull request per piece of work, a `## Changelog`
line per change, an `area:` label.

## Docs

This repo's purpose is being the place things are true, so a claim here costs more
than a claim elsewhere. Describe what is on disk, in the present tense. Put intent
in `docs/roadmap.md` as an unchecked item. Unsure whether something landed? Check
before writing it down.

## Do not

- Commit secrets, `.env` files or credentials.
- Edit generated files or lockfiles by hand; regenerate them.
