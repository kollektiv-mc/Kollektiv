# Roadmap

Reconciled against this repo's GitHub Issues by `/suite-kit:issue-sync`. Each
issue carries a `Source: docs/roadmap.md § <section>` line in its body — match on
that, not on titles. Section headings must stay unique within this file.

## Task tracking

- [x] Standardise on GitHub Issues in every repo — `tracking: "github-issues"`
      declared in all three `.claude/suite.json` files, replacing the per-repo
      `linear.team` / `linearTeam` keys
- [x] Repoint `linear-sync` → `issue-sync`: reconciles roadmap against GitHub
      Issues and never writes to Linear, so it cannot race the sync routine
- [x] Delete Konnekt's `agent_docs/LINEAR.md` and `.claude/commands/linear-sync.md`
      — the command hardcoded the dead `team=KonnektMC` and failed outright; the
      doc described initiatives and projects in that same abandoned workspace
- [x] Declare the convention in Konnekt's `agent_docs/CLAUDE.md`, which had never
      stated one — it had only accumulated Linear tooling
- [ ] Build the GitHub → Linear sync routine (owned separately; Linear is a
      downstream mirror and nothing in these repos writes to it directly)

## Plugin stack

- [x] Remove OMC — declared but never installed, and its 60 agents/skills would
      have crowded suite-kit's 4 out of the skill listing budget
- [x] Adopt `superpowers@superpowers` (~14 skills, no hooks, no agents) as the
      lighter replacement
- [x] Decline `claude-mem` — its `hooks.json` binds `PreToolUse` on `Read`,
      colliding with Konnekt's `graphify hook-guard` on the same event and
      matcher; see `docs/adopting.md`
- [x] Propagate the plugin swap to Konnekt — `.claude/settings.json` now
      declares `superpowers@superpowers` instead of `oh-my-claudecode@omc`
- [x] Apply the settings block to Kommands — `suite-kit@kollektiv` and
      `superpowers@superpowers`, merged alongside its existing `permissions`
- [ ] Evaluate `context7@claude-plugins-official` for adoption (single MCP
      server, near-zero context cost) — needs a Custom network allowlist entry
      for its Upstash host in cloud environments before it's worth enabling
      repo-wide; not currently in `enabledPlugins`
- [ ] Run `claude plugin install` for `superpowers@superpowers` on each machine
      and cloud path that needs it, and record where it has been run

## Suite conventions

- [x] Hoist the reusable parts of Konnekt's Linear doc — the PR-keyword
      convention and the `Source: <roadmap> § <section>` mapping rule — into
      `plugins/suite-kit/skills/issue-sync/SKILL.md`, so they are defined once
- [x] One health entry point: `/suite-kit:health` in all three repos. Kommands'
      local `.claude/commands/health-check.md` was deleted and its three grep
      invariants ported into `.claude/suite.json`; Konnekt's `agent_docs/CLAUDE.md`
      now names the skill in its Definition of done
- [x] Settle `§ <section>` matching: a referenced heading must be unique within
      its roadmap file, at any level. Konnekt's `### Tiles — beta` and Kommands'
      `## Now` both work without restructuring
- [x] Remove the duplicated token tables from Kommands' `docs/design-tokens.md` —
      values live only in `design/tokens.json`; the doc keeps the pipeline and the
      conventions the values cannot express
- [ ] Formalise Prettier settings in Kommands once it scaffolds. Konnekt's
      `frontend/.prettierrc.json` and Kommands' documented settings are currently
      identical (`semi: false`, `singleQuote`, `trailingComma: all`,
      `printWidth: 100`) — one is a file, the other prose, so they can drift
- [ ] Decide whether Konnekt gains a `.claude/rules/` layer. Kommands has four
      path-scoped rule files that auto-inject on edit; Konnekt has none, keeping
      the equivalent guidance as prose in `agent_docs/CLAUDE.md`

## Workspace validation

- [x] Clone Konnekt and Kommands via `scripts/bootstrap.sh` — both cloned as
      siblings; a second run confirmed idempotence (`= already cloned`)
- [x] Confirm `sync-tokens.sh` vendors `design/tokens.json` into both —
      Konnekt already had a matching copy; Kommands didn't, now vendored there
