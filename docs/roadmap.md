# Roadmap

This repo's own issues live in GitHub, like every other repo in the suite. Each
issue created from a line here carries a `Source: docs/roadmap.md § <section>` line —
match on that, not on titles.

## Linear substrate

Everything is tracked in GitHub Issues today. Linear is a destination for a future
sync, not a tracker anything writes to now. The workspace is on the free plan, which
caps it at two teams.

- [ ] Stand up the two-team model: `Kollektiv` for what spans the suite, `Apps` for
      building and maintaining the individual products. Per-repo teams (`KON`, `KMD`)
      are no longer planned
- [ ] Build the GitHub→Linear sync, so issues filed in each repo surface in Linear
      without anything writing to Linear directly
- [ ] Decide what becomes of `/suite-kit:linear-sync` — with every repo declaring
      `tracking`, it stops everywhere, correctly and uselessly. It is either the seed
      of the sync above or a deletion
- [ ] Drop the stale `linearTeam` keys from `suite.repos.json` (`KON`, `KMD`). That
      file has no schema and `validate-schemas.sh` does not check it, so nothing
      catches them
- [ ] Create initiative `Kollektiv Suite` and attach `Workspace & Tooling`

## Scheduled checks

- [x] Add `/suite-kit:health-sweep` — the suite-wide counterpart to
      `/suite-kit:health`, including the token-drift check the single-repo skill
      deliberately omits
- [x] Schedule it as a weekly cloud Routine, Mondays, filing findings as
      deduplicated GitHub issues in the repo each finding belongs to
- [ ] Shift the Routine's cron by an hour twice a year, or move it off UTC — Routine
      cron is evaluated in UTC and does not follow DST, so a schedule set for 09:00
      Berlin fires at 08:00 Berlin from late October to late March
- [ ] Confirm the sweep's second consecutive run opens zero new issues. Dedup is the
      whole design, and only a real second run proves it

## Enforcement

- [x] Add CI to this repo — script syntax, manifest validity, suite-kit version
      match, schema validation
- [x] Detect vendored-token drift (`scripts/sync-tokens.sh --check`, plus a
      scheduled CI job), replacing the incorrect claim that each product's own
      health check caught it
- [x] Add `design/suite.schema.json` and validate every manifest against it
- [~] Run Konnekt's `gen:tokens` clean-diff check in its CI rather than only in
      `/suite-kit:health` — on `konnekt@claude/suite-kit-enforcement`, not yet
      merged
- [ ] Add CI to Kommands once it is scaffolded — it has no `package.json` yet, so
      its `health.commands` are legitimately unrunnable
- [ ] Enforce the `docs/conventions.md` permissions block automatically rather
      than by review

**The `token-drift` CI job here is red until Kommands' adoption merges.** Its
`main` has no `tokens.source.json`, so the check correctly reports it as missing.
That is the job working, not a bug to suppress.

## Suite conventions

- [x] Hoist the reusable parts of Konnekt's `agent_docs/LINEAR.md` — the
      magic-word PR convention and the `Source: <roadmap> § <section>` mapping
      rule — into `docs/conventions.md`, leaving Konnekt's own project and
      milestone structure where it is
- [x] Add `CLAUDE.md` to this repo, so its conventions reach an agent session
      instead of sitting in files nothing auto-loads
- [~] Delete the two per-repo commands the plugin replaced
      (`Konnekt/.claude/commands/linear-sync.md`,
      `Kommands/.claude/commands/health-check.md`) — both deletions are on
      unmerged branches
- [ ] Write `scripts/adopt.sh` to scaffold a new repo's `.claude/suite.json`,
      settings block, and vendored tokens, so adopting a fourth repo is a
      command rather than a careful read of `docs/adopting.md`

## superpowers adoption

OMC (Oh-My-ClaudeCode) has been dropped suite-wide, along with its
`.omc-workspace` multi-repo session sharing — deleted from this repo along with
every reference to it. `superpowers` (`obra/superpowers`) is now the one
third-party plugin declared alongside `suite-kit`, everywhere.

- [x] Declare `superpowers` in this repo's `.claude/settings.json`, replacing `omc`
- [x] Declare `superpowers` in Konnekt's `.claude/settings.json`, replacing `omc`
      — on `konnekt@claude/suite-kit-enforcement`, not yet merged
- [x] Kommands already declared `superpowers` rather than `omc` — the rest of the
      suite has now matched it, not the other way around
- [ ] Run `claude plugin install` for `superpowers@superpowers` on each machine and
      cloud path that needs it, and record where it has been run — the weekly sweep
      attempts this install itself and reports its deeper review as skipped if it
      still cannot load the plugin
- [ ] Observe a session of superpowers' agents against Konnekt's
      `graphify hook-guard` before relying on it there beyond what
      `.claude/settings.json` already declares

## Workspace validation

- [ ] Clone Konnekt and Kommands via `scripts/bootstrap.sh` and confirm the
      sibling layout works standalone — no longer tied to OMC's workspace
      feature, which this repo no longer uses
