# Linear structure

What the Linear workspace looks like, and how `/suite-kit:suite-sync` keeps it
that way. GitHub Issues is the source of truth for work items across the
suite (see `docs/conventions.md`) — everything below is what those issues get
mirrored into, not something edited by hand as the primary path.

---

## Teams

Two teams, because that's the workspace's limit:

| Team | Key | Covers |
|---|---|---|
| Kollektiv | `KOL` | The umbrella repo: conventions, tokens, suite-kit, CI |
| Apps | `APP` | Konnekt and Kommands product work |

Per-app separation within `Apps` is handled by **projects**, not a third team —
each app is one project, and every mirrored issue also carries a `repo:*`
label so a cross-team view still filters to one repo cleanly.

## Initiative

One initiative, **`Kollektiv Suite`**, with every project attached. Initiatives
are the only Linear object that spans teams, so this is what gives a single
roll-up view across both.

## Projects and milestones

| Team | Project | Milestones |
|---|---|---|
| Kollektiv | `Workspace & Tooling` | — |
| Kollektiv | `Design System` | — |
| Kollektiv | `Suite Automation` | — |
| Apps | `Konnekt` | `Alpha` (complete), `Beta`, `Remote Access` |
| Apps | `Kommands` | `Now`, `Next`, `Later` |

Milestones mirror each repo's own roadmap phase headings
(`agent_docs/ROADMAP.md` in Konnekt, `docs/roadmap.md` in Kommands), so the
roadmap file and Linear read as the same shape without a translation table.

GitHub has no milestone-creation tool available in a Claude Code cloud
session (see `docs/conventions.md` § Known GitHub MCP gaps), so milestone
membership on the GitHub side is carried as a label instead —
`milestone:beta`, `milestone:remote-access` in Konnekt today. `/suite-kit:suite-sync`
maps a `milestone:<x>` label to the Linear milestone of the same name on that
issue's project.

Routing an issue by repo:

- `kollektiv-mc/kollektiv` → team **Kollektiv**, project `Design System` if
  labelled `area:tokens`, otherwise `Suite Automation`.
- `kollektiv-mc/konnekt` → team **Apps**, project `Konnekt`.
- `kollektiv-mc/kommands` → team **Apps**, project `Kommands`.

## Label taxonomy

Full definitions, colors, and descriptions live in `design/labels.json` — this
is the summary.

**GitHub side**, applied identically to all three repos by
`scripts/sync-labels.sh`:

- type: `type:feature`, `type:bug`, `type:chore`, `type:docs`
- area: `area:tokens`, `area:ci`, `area:agents`, `area:ui`, `area:schema`, `area:release`
- priority: `p0`, `p1`, `p2`, `p3`
- `blocked`
- `health-check`, carried by everything `/suite-kit:health-sweep` files

**Linear side** — `repo:kollektiv` / `repo:konnekt` / `repo:kommands`; `Feature` /
`Bug` / `Chore` / `Docs` (the type set, mirroring GitHub's `type:*`) plus
`Improvement`, kept as the pre-existing alias for GitHub's default
`enhancement` label rather than deleted; the same `area:*` set; `blocked`;
`health-check`, mirroring the GitHub label of the same name; and
`source:github`, marking an issue `/suite-kit:suite-sync` created or last
updated from GitHub — its absence means an issue predates the routine or was
created by hand in Linear.

## Field mapping

| GitHub | Linear |
|---|---|
| `p0` / `p1` / `p2` / `p3` / none | Urgent(1) / High(2) / Medium(3) / Low(4) / None(0) |
| `type:*`, `area:*` | matching Linear label |
| `milestone:*` label | project milestone of the same name |
| repo | `repo:*` label + team/project routing above |
| open | Backlog, or Todo if pulled into the active cycle |
| open + linked open PR | In Review |
| closed, `state_reason: completed` | Done |
| closed, `state_reason: not_planned` | Canceled |
| assignee | Linear assignee if that GitHub user is a Linear workspace member; otherwise unassigned |

## The match key

Every mirrored Linear issue carries, in its description:

```
Source: kollektiv-mc/<repo>#<number>
```

Match on that line and nothing else — a stable numeric reference, unlike the
`Source: <roadmap> § <section>` convention it replaced, which broke whenever
a roadmap section got retitled. The connection is also attached as a native
GitHub link on the Linear issue, so it's visible without opening the
description.

## Cycles

Not enabled yet on either team. Cycle creation is a Team Settings toggle, not
exposed via the Linear MCP — enable it once in **Team Settings → Cycles** per
team if wanted.

## Corrections to earlier documentation

Two claims that circulated in this repo's docs turned out to be wrong when
actually checked against the connected Linear MCP's tool list:

- **`save_initiative` and `save_project` both exist.** An initiative does not
  need to be created by hand in the Linear UI — `Kollektiv Suite` above was
  created with `save_initiative`, and every project was attached to it with
  `save_project`'s `addInitiatives`. `create_team` is still genuinely absent;
  teams are still made by hand.
- **PR #22's merge state.** `list_pull_requests` reported PR #22 in Konnekt
  as closed-unmerged; `pull_request_read` (the `get` method) shows it merged
  at `2026-08-04T20:40:15Z`, and the CI check it added is live on `main`. If
  a PR's status matters for a decision, verify with `pull_request_read`
  rather than trusting the list view.
