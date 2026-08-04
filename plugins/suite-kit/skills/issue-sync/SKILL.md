---
description: Reconcile this repo's roadmap against its GitHub Issues — open issues for newly scoped items, close issues for shipped ones, and report what changed. Use when asked to sync, reconcile, or update issues, or on a scheduled roadmap reconcile.
disable-model-invocation: true
---

# Issue sync

Read `.claude/suite.json` → `tracking` and `roadmap`. This skill runs only when
`tracking` is `github-issues`; if that field is missing, say so and stop rather
than assuming — a repo that never declared its convention is a repo where
reconciling could file issues in the wrong place.

Issues live in the same repository as the roadmap. This is one prompt shared by
manual runs and any scheduled reconcile, so the reconcile logic has exactly one
definition.

**Linear is downstream, and is written only by the GitHub → Linear sync routine.
This skill never writes to Linear.** Anything filed here reaches Linear through
that routine; writing to both would put two writers on the same records.

---

## 1. Gather

- Read the roadmap at the configured path.
- Read recent git history for what shipped since the last reconcile.
- List the repo's open and recently-closed issues.

## 2. Match

Every issue created from a roadmap line carries a line in its body:

```
Source: <roadmap path> § <section>
```

Match on that, not on titles. Titles get edited on both sides and drift apart;
matching on them produces duplicates that then need untangling by hand.

Search bodies rather than scanning titles — `search_issues` with
`repo:<owner>/<name>` plus the `Source:` string.

A heading referenced by `§` must be **unique within its roadmap file**, and `§`
names it verbatim at whatever level it sits. Konnekt's `### Tiles — beta` and
Kommands' `## Now` are both valid; what matters is that the text is unambiguous
within that one file.

## 3. Reconcile

- A roadmap item marked `[ ]` with no matching issue → open it, with the `Source:`
  line in the body.
- An item now `[x]`, or closed by a merged PR → close its issue.
- An issue with no matching roadmap section → **report it, do not close it.** It is
  as likely that the roadmap is stale as that the issue is.

Do not invent labels or milestones to make something fit. If an item has no obvious
home, say so and leave it.

---

## Constraints worth knowing

- Use the `mcp__github__*` tools. GitHub's `gh` CLI is **not** pre-installed in
  cloud sessions, so a prompt that shells out to it works locally and fails in the
  cloud.
- PR closing keywords (`Fixes #12`, `Closes #9`) close issues automatically on
  merge. That layer needs no maintenance — this reconcile exists for what it cannot
  see.
- Issue numbers are per-repo: `#12` in Konnekt and `#12` in Kommands are unrelated.
  Always qualify with the repo when reporting across the suite.

## Report

Summarise what changed: opened, closed, flagged for review. If nothing changed, say
that rather than manufacturing activity.
