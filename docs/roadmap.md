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

Still open: enforcing the `docs/conventions.md` permissions block
mechanically rather than by review. Kommands can't get CI yet — it has no
`package.json` until its own scaffolding work lands.

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

Still open: `scripts/adopt.sh`, to scaffold a new repo's `.claude/suite.json`,
settings block, and vendored tokens in one command instead of a careful read
of `docs/adopting.md`.

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
