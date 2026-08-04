# Cross-repo conventions

Rules that apply across the suite. Anything specific to one repo — its projects, its
milestones, its label taxonomy — stays in that repo.

These were hoisted out of `Konnekt/agent_docs/LINEAR.md`, which held them as though
they were Konnekt's own. They are not; they describe how every repo here is tracked
and reviewed.

---

## Tracking is a per-repo choice

There is no suite-wide tracker, and suite-kit does not require one.

| Repo | Tracked in | Declared as |
|---|---|---|
| Kollektiv | Linear, team `KOL` | `linear.team: "KOL"` |
| Konnekt | Linear, team `KON` | `linear.team: "KON"` |
| Kommands | GitHub Issues | `tracking: "github-issues"` |

`.claude/suite.json` must declare exactly one of `linear` or `tracking` —
`design/suite.schema.json` enforces it. Declaring neither would leave
`/suite-kit:linear-sync` guessing a team key, which is the failure mode every skill in
this plugin is written to avoid.

`/suite-kit:linear-sync` in a repo with `tracking` set reports that the repo is tracked
elsewhere and stops. That is a correct outcome, not an error.

**A declared team key is not a provisioned team.** `KON` is declared in Konnekt's
manifest and does not yet exist in the `Kollektiv-MC` workspace. Declaring and
provisioning are separate steps; see `docs/roadmap.md`.

## Issue ↔ roadmap mapping

Every issue created from a roadmap line carries this in its description:

```
Source: <roadmap path> § <section>
```

**Match on that line, never on titles.** Titles get edited on both sides and drift
apart; matching on them produces duplicates that then need untangling by hand.

## PR magic words

For Linear-tracked repos, magic words in the PR title or description drive the native
GitHub integration and move issues automatically on open and merge:

```
Fixes KON-12      Closes KOL-9      Part of KON-28
```

That layer needs no maintenance. `/suite-kit:linear-sync` exists for what it cannot
see — items scoped on the roadmap but never branched, and issues whose roadmap section
has since been rewritten.

## Required permissions block

Every repo's committed `.claude/settings.json` carries this, merged into whatever else
it already has:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "ask": [
      "Bash(git push:*)"
    ],
    "allow": []
  }
}
```

`deny` and `ask` are the suite-wide floor and are not negotiable per repo. `allow` is
per-repo: put the read-only and routinely-safe commands of that stack in it — the
point is to cut permission prompts for things like `pnpm typecheck` and `git status`
without also waving through a push.

This matters most for unattended agents and scheduled routines, which have no one
watching to decline a prompt. A repo with no permissions block has no floor at all.

**Merging, not replacing.** Konnekt's `.claude/settings.json` also carries a `hooks`
section binding `graphify hook-guard` to `PreToolUse`. Add the permissions block
alongside it. suite-kit ships no hooks specifically so it cannot collide with those.

## What stays per-repo

- Project and milestone structure, and label taxonomy.
- Cycle cadence. Cycle creation is a team-settings toggle not exposed via the Linear
  MCP; enable it once in **Team Settings → Cycles**.
- Anything about the product's own build, CI, or release.

## Known Linear MCP gaps

- **No `create_team`.** Teams are made by hand in the Linear UI.
- **No `create_initiative` / `save_initiative`.** Initiatives must be created by hand
  (Workspace → Initiatives → New). Projects can then be attached to one that already
  exists via `save_project(addInitiatives: [...])`.
- **No cycle creation.** Team-settings toggle only.

Do not write a skill step that assumes any of these exist.
