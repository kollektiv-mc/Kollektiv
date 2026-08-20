---
description: Mirror GitHub Issues across the suite into Linear — create missing Linear issues, update status/priority/labels/project/milestone/assignee on existing ones, place completed work on the version timeline, and post a project status update. Never deletes. Use when asked to sync, reconcile, or update Linear, or on a scheduled mirror run.
disable-model-invocation: true
---

# Suite sync

GitHub Issues is the one source of truth for work items across the suite. Linear is
a downstream mirror. This skill is one prompt shared by manual runs and the scheduled
routine, so the reconcile logic has exactly one definition.

Read `suite.repos.json` at the workspace root for the repo list, plus this repo
(`kollektiv`) itself — it is the workspace root and is not listed in its own manifest.

For each repo, read its `.claude/suite.json`:

- `tracking: "github-issues"` → in scope for this sync.
- `linear: { team: ... }` present instead → that repo is tracked in Linear directly.
  Report it and skip; do not mirror a repo that already lives in Linear.
- Neither present, or the file is missing → report it as misconfigured and skip. Do
  not guess.

Today every repo in the suite declares `tracking: "github-issues"`, so this should
rarely trigger — but a repo that later opts back into direct Linear tracking is a
real, supported case, not an error.

---

## 1. Gather

For each in-scope repo, list open issues and issues closed since the last run (or
all closed issues on a first run — cheap, and the match key makes re-runs safe).
List existing Linear issues carrying the `repo:<name>` label so the comparison set
is bounded per repo rather than scanning the whole workspace every time.

## 2. Match

Every mirrored Linear issue carries this line in its description:

```
Source: kollektiv-mc/<repo>#<number>
```

**Match on that line, and nowhere else.** Not on titles — they get edited on both
sides and drift apart, and matching on them produces duplicates that then need
untangling by hand.

An existing Linear issue with a `Source:` line pointing at a repo/number that no
longer exists on GitHub (deleted, or the repo was renamed) is reported, not touched.

## 3. Reconcile

**A GitHub issue with no matching Linear issue → create one.**

- Team and project: route by repo.
  - `kollektiv` → team **Kollektiv**, project by area — `Design System` for
    `area:tokens`, `Suite Automation` for everything else in this repo.
  - `konnekt` → team **Apps**, project **Konnekt**.
  - `kommands` → team **Apps**, project **Kommands**.
- Milestone: GitHub has no milestone-creation tool available in this session, so
  milestone membership is carried as a label instead — `milestone:beta`,
  `milestone:remote-access` in Konnekt; nothing yet in Kommands (its roadmap phases
  Now/Next/Later aren't filed as issues per-phase the way Konnekt's are — see its
  `docs/roadmap.md`). Map a `milestone:<x>` label to the Linear project milestone of
  the same name if one exists on that project; otherwise leave the issue
  milestone-less rather than inventing one.
- Labels: see the mapping table below.
- Priority: `p0`–`p3` labels map to Urgent/High/Medium/Low. No priority label →
  derive one from the type label rather than leaving it at None. See § Priority
  below.
- Assignee: carry the GitHub assignee across if that person is a Linear workspace
  member; otherwise leave unassigned. Do not default to yourself — that was a
  decision the old per-repo model made and it produced a false sense of ownership.
- Description: the GitHub issue body, followed by a blank line and the `Source:`
  line, followed by a GitHub link attachment (`links: [{url, title}]` on
  `save_issue`) so the connection is also visible as a native attachment.
- Add the `source:github` label, plus `repo:<name>`.

**An existing mirrored Linear issue whose GitHub counterpart changed → update it.**
Status, priority, labels, assignee, and title/description all follow the GitHub
side. Never move a mirrored issue's status backwards from Done/Canceled to
something open unless the GitHub issue itself reopened — a manual status edit made
directly in Linear should not be silently reverted by drift in the other direction,
but the *next* GitHub-side change always wins, because GitHub is the source of
truth here, not Linear.

**Status mapping:**

| GitHub | Linear |
|---|---|
| open | Backlog, or Todo if already in the current cycle |
| open + linked open PR | In Review |
| closed, `state_reason: completed` | Done |
| closed, `state_reason: not_planned` | Canceled |

**Label mapping** (full taxonomy in `design/labels.json`):

| GitHub | Linear |
|---|---|
| `type:feature` | `Feature` |
| `type:bug` | `Bug` |
| `type:chore` | `Chore` |
| `type:docs` | `Docs` |
| `area:*` | same-named `area:*` label |
| `blocked` | `blocked` |
| GitHub's default `enhancement` (predates this taxonomy, still used in Konnekt's older issues) | `Improvement` |
| any other foreign label (`question`, `documentation`, …) | carried across as-is if a same-named Linear label exists; otherwise dropped, not invented |

### Priority

A `p0`–`p3` label always wins. Where an issue carries none, derive:

| Signal | Priority |
|---|---|
| `type:bug` | High (2) |
| `type:feature` | Medium (3) |
| `type:chore`, `type:docs` | Low (4) |
| `health-check` | Low (4) |
| no type label at all | Medium (3) |

Two rules bound the derived value:

- **Never write a `p*` label back to GitHub.** This sync is one-directional. The
  derived priority lives in Linear only, and labelling the GitHub issue by hand
  is what retires the guess.
- **Never overwrite a priority already set in Linear with a derived one.** Only
  an explicit `p*` label may do that. A derived value fills an empty field; it
  does not overrule a person.

Rationale and the audit that prompted this is in `docs/linear.md` § Priority when
no label says so — the short version is that the old "no label → None" rule left
88 of ~90 mirrored issues at no priority.

**A Linear issue with no matching GitHub issue → report it, do not delete it.** It
is as likely that it predates this sync (hand-created, or from the old
roadmap-driven model) as that it is genuinely orphaned. `source:github`'s absence is
itself the signal: an issue without that label was never GitHub-sourced, and is not
this skill's business to touch beyond reporting.

Do not invent projects or milestones to make something fit. If an issue has no
obvious home under the routing above, say so and leave it.

## 4. Version timeline

Completed work goes on a timeline by the version it shipped in — one Linear
project milestone per tag, dated to the tag. Full structure and the reasoning
behind it is `docs/linear.md` § Version timeline; this is the procedure.

**Read the tags from the repo on disk, not from the GitHub API.** `list_tags` and
`list_releases` exist but only cover repos attached to the session, which the
products are not in every session this skill runs in; the checkout is always
there. A shallow clone has no tags until you ask for them:

```
git fetch --tags --depth=1 origin
git for-each-ref --sort=creatordate \
  --format='%(refname:short)|%(creatordate:short)' refs/tags
```

`creatordate` reads the tag date for an annotated tag and the commit date for a
lightweight one, so both kinds land on the timeline correctly. A repo with no
tags has no version timeline — report that and move on, do not invent a version.
Today only Konnekt is tagged; kollektiv and Kommands have no tags at all.

**Per tag, ensure a milestone** on that repo's Linear project, named
`<Channel> · <tag>`, with `targetDate` set to the tag date:

| Tag shape | Channel |
|---|---|
| `-snapshot`, or the bare rolling `snapshot` tag | Snapshot |
| `-alpha` | Alpha |
| `-beta` | Beta |
| bare `vX.Y` / `vX.Y.Z` | Release |
| anything else | report it, do not guess a channel |

The bare `snapshot` tag is a **rolling pointer**, not a version — Konnekt's
`.github/workflows/snapshot.yml` moves it nightly. It gets exactly one
milestone, `Snapshot · current`, whose date is updated to wherever the tag now
points. Never file one per night.

**Attach each completed issue** to the first version tagged at or after its
GitHub `closed_at`. Use `closed_at` from the GitHub issue — **not** the Linear
issue's `completedAt`, which records when a sync run noticed the closure and so
reflects this routine's own schedule rather than when anything was fixed.

An issue fixed after the newest version tag attaches to `Snapshot · current`:
it is on `main` and in the nightly build, but no versioned release holds it yet.
When a later version is cut past it, move it onto that version's milestone. This
is the one case where this sync moves an issue off a milestone it set earlier.

**Do not touch roadmap milestones.** `Beta` and `Remote Access` on Konnekt, and
Kommands' `Now`/`Next`/`Later`, are forward-looking phases driven by the
`milestone:<x>` label mapping in step 3. A channel with no tags keeps its roadmap
milestone; a channel with tags is owned by the version milestones. Konnekt's
`Alpha` is superseded today and is left in place regardless — the Linear MCP has
no milestone-deletion tool, and retiring one is a manual step in the UI.

## 5. Status update

Post a project status update on each active project touched this run: shipped, in
progress, blocked, next. Skip projects with no changes this run rather than
manufacturing one.

---

## Constraints worth knowing

- `save_initiative` exists in the connected Linear MCP — despite
  `docs/conventions.md` historically saying otherwise, initiatives do not need to be
  created by hand. `create_team` still does not exist; a repo needing a new team is
  still a manual step.
- Cycle creation is a team-settings toggle, not exposed via the MCP.
- **Linear's Releases feature is unavailable.** Pipelines, stages and per-release
  issue sets are the obvious home for step 4 and need a Business or Enterprise
  plan; this workspace is on the free plan, the same constraint that caps it at
  two teams. Releases has no timeline view either — it produces a changelog.
  Project milestones are the only dated object that renders on a Linear timeline.
- There is no milestone-deletion tool. Milestones can be created and updated with
  `save_milestone` and nothing more, so a superseded milestone is reported and
  left alone.
- GitHub label and milestone *creation* likewise has no MCP tool in a Claude Code
  cloud session — only `gh label create/edit` (see `scripts/sync-labels.sh`) can set
  a label's color and description precisely. `issue_write` will silently create a
  missing label with a default gray color when you attach it to an issue, which is
  enough for this skill's matching and filtering to work even before someone runs
  `scripts/sync-labels.sh` to fix the color.
- PR magic words (`Fixes #12`, `Closes #9`, `Part of #28`) drive GitHub's own
  issue-closing automation. That layer needs no maintenance — this sync exists for
  what it cannot see: issues Linear-side that need status changes propagated in,
  and new issues that need mirroring in the first place.

## Report

Summarise what changed: created, updated, flagged for review, per repo. If nothing
changed, say that rather than manufacturing activity.

Report the timeline separately from the issue reconcile, since the two fail
independently: version milestones created or re-dated, issues attached to a
version, issues sitting on `Snapshot · current` because no release contains them
yet, and any tag whose channel could not be derived. A repo with no tags is
reported as having no version timeline — that is a fact about the repo, not a
skipped step.

Priorities are worth a line too: how many issues took an explicit `p*` label and
how many were derived. If that second number is not falling over time, nobody is
labelling on the GitHub side and the derivation is carrying the whole taxonomy.
