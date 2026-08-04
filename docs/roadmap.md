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

## OMC adoption

- [ ] Decide whether Kommands should run OMC at all. It declares `suite-kit` plus
      **`superpowers@superpowers`**, not `omc` — so `docs/adopting.md` § 1, which
      names `omc`, does not describe it. Either add `omc` there or record
      third-party plugin choice as per-repo and stop implying a suite default
- [ ] Run `claude plugin install` for `oh-my-claudecode@omc` on each machine and
      cloud path that needs it, and record where it has been run
- [ ] Observe a session of OMC's agents against Konnekt's `graphify hook-guard`
      before enabling OMC repo-wide there

## Workspace validation

- [ ] Clone Konnekt and Kommands via `scripts/bootstrap.sh` and confirm
      `.omc-workspace` produces one shared session instead of one per product
