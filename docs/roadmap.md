# Roadmap

Reconciled against Linear team `KOL`, project `Workspace & Tooling`, by
`/suite-kit:linear-sync`. Each item's Linear issue carries a
`Source: docs/roadmap.md § <section>` line — match on that, not on titles.

## Linear substrate

- [ ] Rename team `Kollektiv-MC` to `Kollektiv`, keep key `KOL`
- [ ] Create team `Konnekt`, key `KON` — the key is already declared in
      `Konnekt/.claude/suite.json`, but the team does not exist, so
      `/suite-kit:linear-sync` cannot run there yet
- [ ] Create initiative `Kollektiv Suite` and attach `Workspace & Tooling`

No `KMD` team: Kommands is tracked in GitHub Issues, which is a per-repo choice
suite-kit supports rather than a gap. See `docs/conventions.md`.

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
      cloud path that needs it, and record where it has been run
- [ ] Observe a session of superpowers' agents against Konnekt's
      `graphify hook-guard` before relying on it there beyond what
      `.claude/settings.json` already declares

## Workspace validation

- [ ] Clone Konnekt and Kommands via `scripts/bootstrap.sh` and confirm the
      sibling layout works standalone — no longer tied to OMC's workspace
      feature, which this repo no longer uses
