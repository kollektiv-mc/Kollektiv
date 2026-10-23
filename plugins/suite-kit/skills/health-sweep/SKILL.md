---
description: Run the suite-wide health sweep across every repo in suite.repos.json — each product's health checks, the cross-repo drift checks, a review of the week's commits and one health pillar per repo — filing findings as deduplicated GitHub issues and recording the run in a standing log issue. Use ONLY when explicitly asked for a suite-wide sweep across all repos, or when fired by the weekly Routine. For one repo, use health instead; this one clones every product, installs plugins, and writes to GitHub.
---

# Suite-wide health sweep

`/suite-kit:health` reports on **one** repo, on demand. This sweeps **all** of them,
unattended, and files what it finds where the work happens. Run it from the
workspace root (`kollektiv`).

**Check you were actually asked for this one.** It clones every product, installs
plugins, and opens and comments on issues in other repos. If you reached it from
"run a health check" or "check this repo", that is `/suite-kit:health`: stop, say
so, and run that instead. Continue only when the request was explicitly
suite-wide, or this is the weekly Routine firing.

**This sweep never changes code.** Its whole output is issues, one comment on the
run log, and a report. It does not fix, refactor, scaffold or build anything, not
the trivial one-line fix and not the thing it is certain about. It does not commit,
push, open pull requests, or leave a branch behind. It is an unattended run with
nobody reviewing its diff, so anything it changed would land unreviewed.

Three things it does write are local and expected: installing `suite-kit`,
cloning the products, and running a product's `regenerate` command to check its
generated files. **Leave the last two uncommitted.** A dirty tree in a cloned
product is the check having run.

---

## 0. Load the tooling

A scheduled run starts in a fresh container with no plugins on disk, whatever
`.claude/settings.json` declares. From this repo's root:

```sh
claude plugin marketplace add ./
claude plugin install suite-kit@kollektiv
```

The source is `./`; a bare `.` is rejected. The install is user scope and
session-local, and its skills are invokable in the same session. Run
`/reload-plugins` if the install summary asks for it. Do not install
`superpowers`; nothing here needs it.

If the install fails, report it as **skipped, with the reason**, read this file
from disk and follow it. Step 3 then runs each product's vendored
`.claude/suite-check.py`, which needs no plugin.

## 0b. Subagents fetch; you judge

Up to **two** Sonnet subagents may run at a time, and only for retrieval:
locating files, collecting command output, quoting a doc or a diff back. What they
return is evidence, never a verdict.

- Never let a subagent decide whether a match is a violation, a skip is
  acceptable, or a finding reproduces.
- Never let a subagent open an issue, comment, or write the run log.
- **Re-verify anything that becomes a finding against the primary source** before
  filing it: run the command or read the file:line yourself.

A review delegated wholesale and filed from subagent summaries has not been done.

## 1. Assemble the workspace

Read `suite.repos.json` for the repo list; never hardcode product names. Run
`./scripts/bootstrap.sh`, which clones each repo beside this one and is
idempotent. If `add_repo` is available, attach each product with
`access: "push"` (filing issues needs it) and call `register_repo_root` so its
`CLAUDE.md`, rules and settings load.

A repo that cannot be cloned is **skipped, with the reason**; the sweep continues.

## 2. Drift

Run every `run:` line of `.github/workflows/drift.yml`, in order and with its
flags, from the root. Run all of them even after one fails.

Report each the way the script does. They distinguish "no drift", "no drift
among the products present, but the workspace is incomplete", "not adopted" and
real drift, so the middle two are never read as a pass. With every product
present, an unadopted product is a finding for `validate-schemas.sh` and
`check-participation.sh`, and a skip for the sync scripts run without
`--require-vendored`.

## 3. Per-repo health

In each cloned repo, run `/suite-kit:health`. A repo with no `.claude/suite.json`
is **not adopted**: report it and move on, without inventing commands for it.
Run every repo even after one fails.

## 4. Review

The declared checks catch what someone already encoded. This step reads the code
against what is written down but not encoded. It has three parts per adopted repo.

**Range.** Every commit on the default branch since the previous run (its date is
in the run log, step 6; the last 7 days on a first run). Take as the base
`git rev-list -1 --before=<last run> origin/<default>`. The range always starts at
the last run: nothing a run leaves unreviewed is added to the next one.

**The written rules.** Read them before reviewing:

- the product's health checklist, the file its `CLAUDE.md` (or a file it
  imports) names for its four pillars;
- `docs/conventions.md` § Simplicity and § Wording;
- the product's own `CLAUDE.md` and `.claude/rules/`.

A product whose `CLAUDE.md` names no checklist is reported as **no checklist**,
and 4a is skipped for it.

Run the parts in this order. The first two are bounded and are what only this
sweep does; `/code-review` comes last so it cannot use up the run before them.

### 4a. One pillar, over the whole tree

Each run covers one pillar per repo: the one after the pillar the previous run
logged for that repo, in the checklist's order, starting with the first. With
four pillars and a weekly run, the whole checklist is covered about monthly.

Judge every **ticked** item in that pillar against the code as it is now. Skip an
item a declared check in `.claude/suite.json` already enforces (a command, an
invariant, a generated entry); step 3 settled it. What remains is what no machine
checks: docs that match the tree, dead code, layering, a pattern held across
files. A ticked item that no longer holds is a finding, citing the item. An
unticked item is a known gap the checklist already tracks: do not file it.

### 4b. Rules: yours, over the range's diff

Read the diff yourself for any change that breaks a Simplicity or Wording limit,
a ticked item in the checklist, or the product's own rules. A finding cites its
file:line and the rule it breaks. Taste with no written rule behind it is not a
finding; when the same thing keeps appearing with none to cite, file the gap in
the conventions against this repo.

### 4c. Correctness: `/code-review`

```
/code-review high --max-findings all <base>...origin/<default>
```

Never pass `--fix`, `--comment` or `ultra`. On a CLI older than v2.1.288, drop
`--max-findings all` and say in the log that the review's own limit applied. Each
finding it returns is a candidate, re-verified per 0b. Re-verify first the
candidates 4b would also cite: dead code, a second way, an abstraction or option
with one user, and work done more often than needed.

### What could not be covered

Anything in the range or the pillar not read this run (commits, candidates not
re-verified, checklist items not judged) is counted under **Could not run** in
the log with the reason. It is this run's gap, recorded once, and is not carried
forward. If `/code-review` is unavailable, still do 4a and 4b and record 4c as
**skipped, with the reason**; never substitute an unstructured read and call it
the review.

## 5. File the findings

Findings go to **GitHub Issues in the repo the finding is about**. Nothing goes
to Linear.

Every issue carries, on its own line in the body, a key **stable across runs**,
derived from what the finding is, never the week or the title:

```
Health-Check-Key: <repo>/<check-id>
```

For example `konnekt/invariant/no-raw-hex`, `kommands/command/typecheck`,
`kollektiv/tokens/drift`, `konnekt/pillar/performant/ring-buffers`.

Search that repo's open issues for the key line, **never for titles**, then:

| Key found | Finding present | Do |
|---|---|---|
| no | yes | Open an issue |
| yes | yes | Comment with the run's date and what changed |
| yes | no | Comment that it no longer reproduces; **do not close it** |

An open issue a review part filed (4a to 4c) is re-checked only when the range
touched a file its **Where** names. Nothing it points at has changed otherwise, so
it needs no comment. Count the ones left alone in the log, not one by one. An
issue a declared check filed is settled by that check's result in steps 2 and 3.

Closing is a human's call: "fixed" and "the check stopped running" look the same
from here. Label everything `health-check`, creating the label if the repo lacks
it.

**One problem per issue.** Cut explanation, never evidence: a reader must be able
to confirm it without opening a session. Title: the problem, specifically
(`gen:tokens output is stale in Konnekt`). Body, in this order and nothing else:

```
Health-Check-Key: <repo>/<check-id>

<One or two sentences: what is wrong.>

**Where**: <file:line>, <file:line>  (all of them)

**Why it matters**: <the failure this causes, in one or two sentences.>

**Found by**: <the check, rule or checklist item> · <reference doc>
```

For an invariant, copy the entry's `diagnosis` and `reference` from
`.claude/suite.json` verbatim into the last two fields. For a checklist item,
quote the item.

**Do not propose the fix**: no patch, no "just change X to Y". Paste an error only
when it is the evidence, and only its relevant lines. Issue and log text is
published, so it carries no em dash.

If no GitHub issue tooling is available, put every finding, in full with its key
line, into the report (step 7), and say at the top that filing was **blocked** and
why.

## 6. The run log

Every run, clean ones included, posts exactly one comment on the standing issue
in **this repo** whose body carries:

```
Health-Sweep-Log: kollektiv
```

Search for that line; open the issue once, titled `Health sweep run log` and
labelled `health-check`, only if none exists. Never close it or open a second.

```
## <YYYY-MM-DD>: <clean | N finding(s)>

| Repo | Checks | Result |
|---|---|---|
| kollektiv | 12/12 | pass |
| Konnekt | 20/21 | 1 skipped |
| Kommands | 14/14 | pass |

**Drift**: 9/9 pass
**Review**: <per repo: the range, the pillar covered, findings from 4a, 4b and 4c>
**Could not run**: <N, and what; or: none>

**Opened**: <links, or: none>
**Commented**: <links, or: none>; <N> untouched since filed, not re-checked
**No longer reproducing**: <links, or: none>
```

Counts, not prose; the detail is in the issues. The pillar name is what the next
run reads to pick its own. If the log cannot be posted, say so at the top of the
report.

## 7. Report

One `| Check | Result |` table per repo, as `/suite-kit:health` prints it. Then
the issues opened, commented on, and no longer reproducing, each as a link, and a
link to the log comment. If anything could not run, say how much and why right
after the tables.
