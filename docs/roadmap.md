# Roadmap

Reconciled against Linear team `KOL`, project `Workspace & Tooling`, by
`/suite-kit:linear-sync`. Each item's Linear issue carries a
`Source: docs/roadmap.md § <section>` line — match on that, not on titles.

## Linear substrate

- [ ] Rename team `Kollektiv-MC` to `Kollektiv`, keep key `KOL`
- [ ] Create team `Konnekt`, key `KON`
- [ ] Create team `Kommands`, key `KMD` — **blocked on a real decision, not just
      provisioning**: Kommands' own `CLAUDE.md` and `docs/roadmap.md` state task
      tracking is GitHub Issues, contradicting `suite.repos.json`'s
      `linearTeam: "KMD"`. Resolve which is true before creating the team; see
      `docs/adopting.md` § Kommands
- [ ] Create initiative `Kollektiv Suite` and attach `Workspace & Tooling`

## Plugin stack

- [x] Remove OMC — declared but never installed, and its 60 agents/skills would
      have crowded suite-kit's 4 out of the skill listing budget
- [x] Adopt `superpowers@superpowers` (~14 skills, no hooks, no agents) as the
      lighter replacement
- [x] Decline `claude-mem` — its `hooks.json` binds `PreToolUse` on `Read`,
      colliding with Konnekt's `graphify hook-guard` on the same event and
      matcher; see `docs/adopting.md`
- [ ] Evaluate `context7@claude-plugins-official` for adoption (single MCP
      server, near-zero context cost) — needs a Custom network allowlist entry
      for its Upstash host in cloud environments before it's worth enabling
      repo-wide; not currently in `enabledPlugins`
- [x] Propagate the plugin swap to Konnekt — `.claude/settings.json` now
      declares `superpowers@superpowers` instead of `oh-my-claudecode@omc`
- [ ] Apply the settings block (`docs/adopting.md`) to Kommands, declaring
      `suite-kit` and `superpowers` at minimum — do this alongside resolving
      the `KMD` question above, not before it; a `.claude/suite.json` with
      `linear.team: "KMD"` would encode a decision that hasn't been made
- [ ] Run `claude plugin install` for `superpowers@superpowers` on each machine
      and cloud path that needs it, and record where it has been run

## Suite conventions

- [x] Hoist the reusable parts of Konnekt's `agent_docs/LINEAR.md` — the
      magic-word PR convention and the `Source: <roadmap> § <section>` mapping
      rule — into this repo, leaving Konnekt's own project and milestone
      structure where it is. Konnekt's copy now points at
      `plugins/suite-kit/skills/linear-sync/SKILL.md` instead of restating
      the rules
- [ ] Konnekt's `agent_docs/LINEAR.md` and `.claude/commands/linear-sync.md`
      still say workspace `KonnektMC` and cite `sandrogekeler/Konnekt` — both
      stale since the Linear workspace recreation and the GitHub org move.
      Not fixed this pass; flagged while doing the hoist above

## Workspace validation

- [x] Clone Konnekt and Kommands via `scripts/bootstrap.sh` — both cloned as
      siblings; a second run confirmed idempotence (`= already cloned`)
- [x] Confirm `sync-tokens.sh` vendors `design/tokens.json` into both —
      Konnekt already had a matching copy; Kommands didn't (see
      `docs/adopting.md` § Kommands), now vendored and committed there
