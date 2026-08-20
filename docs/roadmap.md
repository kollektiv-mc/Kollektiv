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
match, suite participation, and vendored-token drift (`scripts/sync-tokens.sh
--check`, run on a schedule since drift detection needs every product cloned
beside this one).

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

Both products now carry `.claude/suite-check.py`, and Konnekt's CI runs it as an
`invariants` job over the `invariants` and `generated` sections. Not `commands`:
Konnekt's backend legs run on windows-latest and in a webkit2gtk container, and
`suite.json`'s flat command list cannot express that matrix, so CI keeps those as
literal steps. The two sections CI had no equivalent of are the ones the runner
now covers — before this, Konnekt's `no literal border widths` invariant was
checked only when someone invoked `/suite-kit:health` by hand.

`scripts/check-participation.sh` checks what the other scripts do not: the
`docs/conventions.md` permissions floor in each repo's committed
`.claude/settings.json`, and that the paths each manifest names — `roadmap`,
`tokens.sourceFile`, every `health.commands[].cwd` — still exist. It runs in this
repo's `.claude/suite.json` and in CI with `--require-products`.

Still open, in rough order:

- Turning on `scripts/sync-priority.sh --check --require-vendored` in CI, once
  every repo carries the priority field and `.github/workflows/issue-priority.yml`
  on its default branch. Same reason as the runner below: CI clones from there.
- Turning on `scripts/sync-runner.sh --check --require-vendored` in CI. Both
  products carry the runner in a working tree here, but the flag can only go on
  once those commits are on their default branches — CI clones from there.
- A CI job in Kommands that runs its vendored runner. Every check it declares
  reports as skipped until `src/` and `package.json` exist, so the job would
  verify nothing yet; it lands with the scaffolding.
- Kommands turning on `--require-runnable` once `src/` exists. Until then its
  entire check set reports as skipped, which is honest but verifies nothing.
- Widening Konnekt's literals invariant past borders. It declares
  `tokens.enforce: "migrating"` and names the covered paths, and the
  `no literal border widths` entry closed the border sweep — 0 literals against
  181 token call sites. Hex and arbitrary px are still open: 118 hex literals and
  183 px values across 48 files under the paths its manifest names. A single
  broad pattern would be red on arrival, so this wants either per-sweep entries
  or `migrating` finally meaning something to the runner, which does not yet
  distinguish it from `strict`.
- Wiring the runner into `/suite-kit:health-sweep`. That skill clones every
  product and checks token drift; it should check runner drift the same way, and
  read each product's `.claude/suite-check.py --json` rather than its prose
  report.

Closed since this section was last written: Konnekt PR #51 merged (`ef49aa7`), so
its manifest declares `tracking: "github-issues"` on `main` and
`/suite-kit:suite-sync` no longer skips the repo. Konnekt gained a
`health.invariants` entry. The permissions block is enforced by
`check-participation.sh` rather than by review.

## Scheduled runs

Two cloud Routines exist and are enabled, both created over MCP against this
repo: the daily `/suite-kit:suite-sync` mirror (`30 6 * * *` UTC) and the weekly
`/suite-kit:health-sweep` (`0 7 * * 1` UTC). `README.md` describes what each does.

Still open on the sweep:

- Granting its Routine the GitHub connector from the claude.ai Routines UI. It
  was created over MCP, which cannot attach connectors for this organization, so
  its sessions have no issue-filing tools yet — the sweep will report filing as
  blocked and put its findings in the run report instead.
- Confirming it runs on Opus 5. A Routine's model cannot be set or read over MCP
  (`model_update_disabled`), so it inherits whatever the account default is.
- Confirming a second consecutive run opens zero new issues. Dedup via the
  `Health-Check-Key:` line is the whole design, and only a real second run
  proves it.

Routine cron is evaluated in UTC and does not follow DST, so both schedules need
shifting by an hour twice a year, or moving off UTC — a schedule set for 09:00
Berlin fires at 08:00 Berlin from late October to late March.

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
