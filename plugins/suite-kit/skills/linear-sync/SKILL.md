---
description: Reconcile this repo's roadmap against Linear — create issues for newly scoped items, close issues for shipped ones, and post a project status update. Use when asked to sync, reconcile, or update Linear, or on a scheduled roadmap reconcile.
disable-model-invocation: true
---

# Linear sync

Read `.claude/suite.json` → `linear.team` and `roadmap` for this repo's Linear team
key and roadmap path. If that file is missing, say so and stop.

**Tracking is a per-repo choice.** A manifest declares exactly one of `linear` or
`tracking`. If it declares `tracking` instead of `linear` — Kommands uses
`github-issues` — report that this repo is tracked elsewhere and stop. That is a
correct outcome, not an error, and it is not a reason to guess a team key from the
repo name.

A `linear.team` key that names a team which does not exist in the workspace is a
different case: report the team as unprovisioned and stop, rather than creating
issues somewhere else. Declaring a key and provisioning the team are separate steps.

This is one prompt shared by manual runs and any scheduled reconcile, so that the
reconcile logic has exactly one definition.

---

## 1. Gather

- Read the roadmap at the configured path.
- Read recent git history for what shipped since the last reconcile.
- List the team's existing issues and projects.

## 2. Match

Every issue created from a roadmap line carries a line in its description:

```
Source: <roadmap path> § <section>
```

Match on that, not on titles. Titles get edited on both sides and drift apart;
matching on them produces duplicates that then need untangling by hand.

## 3. Reconcile

- A roadmap item marked `[ ]` with no matching issue → create it in the right
  project, with the `Source:` line.
- An item now `[x]`, or closed by a merged PR → move its issue to Done.
- An issue with no matching roadmap section → **report it, do not delete it.** It is
  as likely that the roadmap is stale as that the issue is.

Do not invent projects or milestones to make something fit. If an item has no
obvious home, say so and leave it.

## 4. Status update

Post a project status update on each active project: shipped, in progress,
blocked, next.

---

## Constraints worth knowing

- The Linear MCP exposes no `create_initiative`. Initiatives must be created by
  hand in the Linear UI; projects can then be attached with
  `save_project(addInitiatives: [...])`.
- Cycle creation is a team-settings toggle, not exposed via the MCP.
- PR magic words (`Fixes KON-12`, `Closes KMD-9`, `Part of KON-28`) drive the
  native GitHub integration and move issues automatically on open and merge. That
  layer needs no maintenance — this reconcile exists for what it cannot see.

## Report

Summarise what changed: created, closed, flagged for review. If nothing changed,
say that rather than manufacturing activity.
