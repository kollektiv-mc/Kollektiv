# Roadmap

Direction and sequencing. Individual tasks live in
[GitHub Issues](https://github.com/kollektiv-mc/Kollektiv/issues) — this file
does not track work items, and there is no `TODO.md`.

`/suite-kit:suite-sync` mirrors GitHub Issues across this repo, Konnekt, and
Kommands into Linear. The Linear structure itself — teams, projects,
milestones, labels — is documented in `docs/linear.md`, not here.

---

## Linear substrate

The workspace is live: team `Kollektiv` (renamed from `Kollektiv-MC`) and team
`Apps`, both provisioned by hand in the Linear UI (teams have no create API).
The `Kollektiv Suite` initiative groups every project across both teams.

There is no `KON` or `KMD` team — the suite settled on two teams total, with
per-app separation handled by Linear projects (one per app, under team `Apps`)
and a `repo:*` label rather than a third team. See `docs/linear.md`.

## Enforcement

CI here checks script syntax, manifest and schema validity, suite-kit version
match, and vendored-token drift (`scripts/sync-tokens.sh --check`, run on a
schedule since drift detection needs every product cloned beside this one).

Konnekt's `gen:tokens` clean-diff check now runs in its own CI
(`.github/workflows/ci.yml`), not just `/suite-kit:health`.

`plugins/suite-kit/suite-check.py` runs everything a repo's `.claude/suite.json`
declares, without the plugin installed, and `scripts/sync-runner.sh` vendors it
into each product the way `sync-tokens.sh` vendors the token source. This exists
because declaring a plugin does not install one: in a cloud container
`installed_plugins.json` is empty, so before this the manifest was read by
nothing there. The runner also distinguishes a skip from a pass, which the
invariant greps previously could not — a grep over a path that does not exist
reported clean.

Still open, in rough order:

- Vendoring the runner into Konnekt and Kommands, and adding a CI job in each
  that runs it. Nothing is committed in either product yet — `sync-runner.sh`
  writes the copy, but only a checkout with both sides can do that. Konnekt PR
  #51 and Kommands PR #20, the companion PRs referenced from PR #9, are both
  unmerged and neither carries `.claude/suite-check.py`, so this is new work
  rather than something already in flight.
- Merging Konnekt PR #51, which already fixes that repo's tracking declaration
  (below). It has been open since 2026-08-05 with the correction written; the
  mirror has skipped Konnekt for as long as it has sat.
- Kommands turning on `--require-runnable` once `src/` exists. Until then its
  entire check set reports as skipped, which is honest but verifies nothing.
- Konnekt's `.claude/suite.json` declaring `linear: { team: "KON" }` instead of
  `tracking: "github-issues"` on `main`, which makes `/suite-kit:suite-sync` skip
  the repo silently. Fixed in unmerged PR #51 — see `docs/adopting.md` § Konnekt.
- Giving Konnekt a `health.invariants` entry for hex and px. It declares
  `tokens.enforce: "migrating"` and names the covered paths, but declares no
  invariant at all, so nothing mechanical checks them. Measured against those
  paths on `main`: 123 hex literals and 324 arbitrary px values across 57 files.
  The repo carrying the whole literals problem has no literal check, while
  Kommands — which has no `src/` yet — has one. The entry belongs in Konnekt's
  manifest, and `migrating` wants the runner to report a count rather than fail,
  which `suite-check.py` does not yet distinguish from `strict`.
- Wiring the runner into `/suite-kit:health-sweep`, which PR #9 adds. That skill
  clones every product and checks token drift; it should check runner drift the
  same way, and read each product's `.claude/suite-check.py --json` rather than
  its prose report. The two changes belong in that PR's file, not this one.
- Enforcing the `docs/conventions.md` permissions block mechanically rather than
  by review. Kommands can't get CI for its `pnpm` commands yet — it has no
  `package.json` until its own scaffolding work lands — but the invariant greps
  need no toolchain and can be wired up before that.

## Suite conventions

The reusable parts of Konnekt's old `agent_docs/LINEAR.md` — the PR
magic-word convention and, historically, the roadmap-section mapping rule —
were hoisted into `docs/conventions.md`, and `CLAUDE.md` was added here so
these conventions reach an agent session automatically. The per-repo
`linear-sync` and `health-check` commands the plugin replaced have been
deleted from both products.

`scripts/adopt.sh` scaffolds a new repo's `.claude/suite.json`, permissions block,
`.gitignore` lines and both vendored files in one command, instead of a careful
read of `docs/adopting.md`. It writes a manifest that is valid but deliberately
unfinished — `tokens`, `minecraft` and `health.invariants` describe a specific
codebase, and a generated guess at them would look reviewed without being.

## superpowers adoption

OMC (Oh-My-ClaudeCode) is dropped suite-wide, along with its `.omc-workspace`
multi-repo session sharing. `superpowers` (`obra/superpowers`) is the one
third-party plugin declared alongside `suite-kit` in all three repos.

Still open: recording every machine and cloud path `superpowers@superpowers`
has actually been installed on, and observing a session of its agents against
Konnekt's `graphify hook-guard` before relying on it there beyond what
`.claude/settings.json` already declares.

## Workspace validation

Still open: cloning Konnekt and Kommands via `scripts/bootstrap.sh` and
confirming the sibling layout works standalone, with nothing depending on
OMC's workspace feature.
