---
description: Mirror GitHub Issues across the suite into Linear — create missing Linear issues, update status/priority/labels/project/milestone/assignee on existing ones, and post a project status update. Never deletes. Use when asked to sync, reconcile, or update Linear, or on a scheduled mirror run.
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
- Priority: `p0`–`p3` labels map to Urgent/High/Medium/Low; no priority label →
  Linear priority None.
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

**A Linear issue with no matching GitHub issue → report it, do not delete it.** It
is as likely that it predates this sync (hand-created, or from the old
roadmap-driven model) as that it is genuinely orphaned. `source:github`'s absence is
itself the signal: an issue without that label was never GitHub-sourced, and is not
this skill's business to touch beyond reporting.

Do not invent projects or milestones to make something fit. If an issue has no
obvious home under the routing above, say so and leave it.

## 4. Status update

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
