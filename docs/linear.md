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

| Team | Project | Roadmap milestones | Version milestones |
|---|---|---|---|
| Kollektiv | `Workspace & Tooling` | — | — (repo is untagged) |
| Kollektiv | `Design System` | — | — (repo is untagged) |
| Kollektiv | `Suite Automation` | — | — (repo is untagged) |
| Apps | `Konnekt` | `Alpha` (superseded), `Beta`, `Remote Access` | one per tag, see below |
| Apps | `Kommands` | `Now`, `Next`, `Later` | — (repo is untagged) |

Roadmap milestones mirror each repo's own roadmap phase headings
(`agent_docs/ROADMAP.md` in Konnekt, `docs/roadmap.md` in Kommands), so the
roadmap file and Linear read as the same shape without a translation table.
They are forward-looking: they say what is planned.

Version milestones are the opposite — they are backward-looking, one per tag
that a repo has actually cut, and they are what puts shipped work on a
timeline. Both kinds live in the same Linear field, so § Version timeline
below states which one wins where they overlap.

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

## Version timeline

Completed work is placed on a timeline by the version it shipped in, not one bar
per issue. `/suite-kit:suite-sync` creates one **project milestone per tag** in
the repo's Linear project, dated to the tag, so the project and initiative
timelines show the version history with each version's completion percentage.

**Why milestones rather than Linear's Releases feature.** Releases — pipelines,
stages, per-release issue sets — is the obvious fit and is not available: it
requires a Business or Enterprise plan, and this workspace is on the free plan
(see `docs/conventions.md` § Known Linear MCP gaps, which records the same
constraint as the two-team cap). Releases also has no timeline view; it produces
a chronological changelog. Project milestones are the only Linear object that
both carries a date and renders on a timeline.

**Channels** come from the tag's suffix, and nothing else:

| Tag shape | Channel | Example |
|---|---|---|
| `-snapshot` suffix, or the bare rolling `snapshot` tag | Snapshot | `snapshot` |
| `-alpha` suffix | Alpha | `v0.1-alpha`, `v0.1.0-alpha.1` |
| `-beta` suffix | Beta | `v1.0-beta` |
| bare `vX.Y` / `vX.Y.Z`, no suffix | Release | `v1.0.0` |
| anything else | reported, not guessed at | `-rc`, `-pre`, a non-`v` tag |

A milestone is named `<Channel> · <tag>` — `Alpha · v0.1-alpha` — and its
`targetDate` is the tag's creation date (`git for-each-ref --format
'%(creatordate:short)'`, which reads the tag date for an annotated tag and the
commit date for a lightweight one).

**The rolling `snapshot` tag is one milestone, not one per night.** Konnekt's
`.github/workflows/snapshot.yml` rebuilds `main` nightly and reuses a single
`snapshot` tag for it; the tag moves, it does not accumulate. It gets exactly one
milestone, `Snapshot · current`, whose date is updated to wherever the tag now
points. Treating it like a version would file a new milestone every morning, and
Konnekt already treats it as not-a-version elsewhere — its website changelog
filters the tag out by name.

**Sort by date, never by version string.** Konnekt's tags are not chronological:
`v2.0-alpha` is dated 2026-06-21 and `v0.1.0-alpha.1` 2026-07-16. The timeline is
the tag dates in order; a version-number sort would draw a false history.

### Which milestone an issue lands on

An issue attaches to the **first version tagged at or after the moment it was
fixed**, using the GitHub issue's `closed_at`.

**Not Linear's `completedAt`.** That records when a sync run first noticed the
issue was closed, which is the routine's schedule, not the fix — every Kommands
issue mirrored on 2026-08-19 carries a `completedAt` within the same two minutes.
Reading it as a fix date would stack unrelated work onto whichever version
followed a sync run.

An issue fixed after the newest version tag attaches to `Snapshot · current`: it
is on `main` and ships in the nightly build, but no versioned release contains it
yet. It moves to a version milestone when one is cut past it. This is the only
case where the sync moves an issue off a milestone it previously set.

### Where version and roadmap milestones collide

Linear has one milestone field per issue, so an issue cannot sit on both `Beta`
and `Beta · v1.0-beta`. The rule:

- A repo with **no tags in a channel** keeps its roadmap milestone there. Konnekt's
  `Beta` and `Remote Access`, and all three of Kommands', are untouched — nothing
  has been tagged against them, and the `milestone:<x>` label mapping below still
  drives them.
- Once a channel **has tags**, the version milestones own it and the roadmap
  milestone for that channel is superseded. Konnekt's `Alpha` is the one case
  today: its four versioned tags are all alphas — the fifth tag is the rolling
  snapshot — so the four `Alpha · *` milestones carry that history and `Alpha`
  itself holds nothing.

A superseded milestone is left in place, not deleted: the Linear MCP has no
milestone-deletion tool (`docs/conventions.md` § Known Linear MCP gaps).
Retiring one is a manual step in the Linear UI.

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
| `p0` / `p1` / `p2` / `p3` | Urgent(1) / High(2) / Medium(3) / Low(4) |
| no `p*` label | derived from `type:*` — see § Priority when no label says so |
| `type:*`, `area:*` | matching Linear label |
| `milestone:*` label | project milestone of the same name |
| tag containing the fix | version milestone — see § Version timeline |
| repo | `repo:*` label + team/project routing above |
| open | Backlog, or Todo if pulled into the active cycle |
| open + linked open PR | In Review |
| closed, `state_reason: completed` | Done |
| closed, `state_reason: not_planned` | Canceled |
| assignee | Linear assignee if that GitHub user is a Linear workspace member; otherwise unassigned |

## Priority when no label says so

A `p0`–`p3` label on the GitHub issue is authoritative and always wins. Most
issues do not carry one: at the time this was written, 2 of roughly 90 mirrored
Linear issues had any priority at all — `APP-20` Urgent and `KOL-19` Low — and
every other one sat at None. The mapping table was not wrong; there was simply
no rule for the unlabelled case, so "none → None(0)" did what it said and the
whole backlog landed flat.

Where no `p*` label exists, priority is derived from the type label:

| Signal on the GitHub issue | Linear priority |
|---|---|
| any `p0`–`p3` label | that label's priority, always |
| `type:bug` | High (2) |
| `type:feature` | Medium (3) |
| `type:chore`, `type:docs` | Low (4) |
| `health-check` | Low (4) |
| no type label at all | Medium (3) |

Two limits on the derived value, both deliberate:

- **It is never written back to GitHub.** The sync stays one-directional; a
  derived priority exists in Linear only. Labelling issues on the GitHub side is
  a manual step, and doing it is what retires the derivation for that issue.
- **It never overwrites a priority already set in Linear.** Only an explicit
  `p*` label does that. A derived value is a guess filling an empty field, and a
  guess should not silently replace a decision someone made by hand.

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
