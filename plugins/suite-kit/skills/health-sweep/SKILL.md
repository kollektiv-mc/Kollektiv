---
description: Sweep every repo in suite.repos.json — run each product's health checks, review the week's changes, file findings as deduplicated GitHub issues in the repo they belong to, and record the run itself in a standing log issue. Use for the weekly scheduled health check, or whenever asked for a suite-wide rather than single-repo report.
disable-model-invocation: true
---

# Suite-wide health sweep

`/suite-kit:health` reports on **one** repo, on demand. This sweeps **all** of them,
unattended, and writes what it finds down where the work happens.

Run this from the workspace root (`kollektiv`). It is the scheduled counterpart to
`/suite-kit:health`, not a replacement for it — step 3 below runs that skill in each
repo rather than reimplementing its logic.

**This sweep never changes code.** Its entire output is issues, a comment on the
standing run log, and a report.

It does not fix, refactor, implement, scaffold, or build anything — not the trivial
one-line fix, not the thing it is certain about, not "while I was in there". It does
not commit, push, open pull requests, or leave a branch behind. A finding that looks
easy is still a finding, not an invitation.

Three steps below do write outside the conversation, and all three are local,
session-scoped and expected: installing the two plugins (step 0, user scope, in a
container that is discarded), cloning the products, and running a product's
`regenerate` command to check its generated files are in sync. **Leave the last two
uncommitted.** A dirty working tree in a cloned product is the check having run, not
work in progress.

The reason for the rule is what the sweep is: an unattended weekly run with nobody
reviewing its diff. Anything it changed would land unreviewed, and the value of a
check nobody trusts is zero. The issue is the deliverable.

---

## 0. Load the tooling

**Declaring a plugin is not installing it.** Every repo's `.claude/settings.json`
enables `suite-kit` and `superpowers`, and a scheduled run still starts in a fresh
container with neither on disk — `claude plugin list` reports none. That is the
normal state of this sweep's session, not a broken one. Install both, from this
repo's root, before anything else:

```sh
claude plugin marketplace add ./
claude plugin install suite-kit@kollektiv
claude plugin marketplace add obra/superpowers
claude plugin install superpowers@superpowers-dev
```

Three things about those four lines, each of which has cost a run:

- **`./`, not `.`** — a bare `.` is rejected as an invalid source format.
- **`superpowers@superpowers-dev`, not `superpowers@superpowers`.** The marketplace
  at `obra/superpowers` names *itself* `superpowers-dev` in its manifest, and the
  manifest's name wins over the alias in `extraKnownMarketplaces`. The id that reads
  correctly fails with `Plugin "superpowers" not found in marketplace "superpowers"`,
  which is exactly the message you get for a plugin that does not exist, so it reads
  as upstream's problem rather than a typo here.
- Both installs are **user scope and session-local.** They change no repo, and the
  container is discarded afterwards.

Then run `/reload-plugins` if the install summary asks for it. Report an install that
fails as **skipped, with the reason**, and carry on — step 3 falls back to each
product's vendored `.claude/suite-check.py`, which is the path that works with no
plugin at all.

**This skill is `disable-model-invocation: true`, and that is deliberate.** A
suite-wide sweep should not fire because a description matched. The consequence is
that installing `suite-kit` does *not* make `/suite-kit:health-sweep` reachable from
a scheduled prompt: only a human typing the command can invoke it, and Claude Code
blocks the model from calling it either way. **Reading this file directly is the only
entry point a scheduled run has.** It is not a fallback for a broken session, and the
line in the Routine prompt that says to read it is load-bearing — do not tidy it away
as redundant. `/suite-kit:health` in step 3 carries no such restriction and is
invokable normally.

## 1. Assemble the workspace

Read `suite.repos.json` for the repo list. **Do not hardcode product names** — a
fourth repo added to that manifest must be swept without editing this skill.

Run `./scripts/bootstrap.sh`. It clones each repo in the manifest beside this one as
`<root>/<name>`, is idempotent, and never touches a directory it did not create. The
products are public, so this needs no credentials. If `add_repo` is available in the
session, attach each product with it as well (`access: "push"` — filing issues needs
credentials, cloning alone does not) and call `register_repo_root` afterwards so the
product's own `CLAUDE.md`, skills, and settings load.

A repo that cannot be cloned is reported as **skipped, with the reason**, and the
sweep continues to the next one. One unreachable product does not cancel the other
checks.

## 2. Drift

With every product cloned, run each drift check from the root, in the order
`.github/workflows/drift.yml` runs them, and run all of them even after one fails:

```sh
./scripts/sync-tokens.sh --check
./scripts/sync-runner.sh --check --require-vendored
./scripts/sync-aislop.sh --check
./scripts/sync-workflows.sh --check
./scripts/sync-priority.sh --check
./scripts/sync-notes.sh --check --require-vendored
./scripts/validate-schemas.sh --require-products
./scripts/check-participation.sh --require-products
./scripts/check-copy.sh --require-products
```

**That list is a copy, and a copy drifts.** It fell two checks behind `drift.yml`
once already, between `sync-workflows.sh` landing and this line being written, and
`sync-notes.sh` sat here for three weeks without the `--require-vendored` the
workflow passes it — which is the difference between a product that lost the
release-notes generator being a finding and it being a silent skip. Read the `run:`
lines out of `.github/workflows/drift.yml` and run those, with their flags. If what
the workflow runs and what is written above disagree, the workflow is right and the
disagreement is itself a finding to file against this repo.

These are the checks `/suite-kit:health` deliberately leaves out: they need the full
workspace, and would fail on a bare checkout. **Here they belong**, because assembling
that workspace is step 1. Read each script's outcomes carefully — every one
distinguishes "no drift", "no drift among the products present, but the workspace is
incomplete", "not adopted" and actual drift, specifically so the middle two are not
read as a pass. Report them the way the scripts report them. With every product
present, an unadopted product is a finding for `validate-schemas.sh` and
`check-participation.sh`, and a skip for the sync scripts run without
`--require-vendored`.

## 3. Per-repo health

In each cloned repo, run `/suite-kit:health`. It reads that repo's
`.claude/suite.json` and knows what that product's health means.

A repo with no `.claude/suite.json` has not adopted suite-kit. Report it as
**not adopted** and move on — do not invent a plausible set of commands for it.
`docs/adopting.md` is the fix, and it is a human's call.

Run every repo even after one fails. The point of a sweep is the whole picture.

## 4. The deeper review

The declared checks catch regressions in things someone already thought to encode.
The sweep also exists to catch what no check encodes yet.

Use the **`superpowers`** skills for this — systematic code review, not a skim. Cover:

- every commit merged to the repo's default branch since the previous sweep
  (`git log --since` the last run's date, or the last 7 days on a first run), and
- one rotating deep-dive area per repo per week, so the whole codebase is covered
  over time rather than only its most recent edits.

`superpowers` is installed in step 0. If that install failed, try it once more
there — the id is `superpowers@superpowers-dev`, for the reason given in that step.

If it is still unavailable after that, run everything else and report the deeper
review as **skipped, with the reason**. Do not substitute an unstructured read and
report it as though the review ran. A shallow pass recorded as a pass is worse than
an honest gap, because it is the one outcome nobody goes back to check.

## 5. File the findings

Findings go to **GitHub Issues in the repo the finding is about** — Konnekt's findings
to Konnekt, Kommands' to Kommands, the hub's to this repo. Nothing goes to Linear;
see `docs/conventions.md`.

Every issue this sweep opens carries, on its own line in the body:

```
Health-Check-Key: <repo>/<check-id>
```

`<check-id>` must be **stable across runs** — derived from what the finding *is*, never
from the week it was found or the wording of the title. `konnekt/invariant/no-raw-hex`,
`kommands/command/typecheck`, `kollektiv/tokens/drift`.

Before opening anything, search that repo's open issues for the key. Then:

| Key found | Finding present | Do |
|---|---|---|
| no | yes | Open an issue |
| yes | yes | Comment on the existing issue with the new run's date and what changed |
| yes | no | Comment that it no longer reproduces — **do not close it** |

**Match on the key line, never on titles.** This is the same rule
`docs/conventions.md` states for roadmap-sourced issues, for the same reason: titles get
edited on both sides and drift apart, and matching on them produces duplicates that then
need untangling by hand.

Closing is a human's call. An issue that stops reproducing may have been fixed, or the
check may have stopped running — and this sweep cannot tell those apart.

Label everything it files `health-check`. Create the label if the repo lacks it.

### What an issue says

**One problem per issue, described thoroughly and briefly.** Those pull against each
other, and the resolution is to cut explanation, never evidence. A reader must be able
to confirm the problem themselves without opening a session.

Title: the problem, specifically. `gen:tokens output is stale in Konnekt`, not
`Health check findings`.

Body, in this order and nothing else:

```
Health-Check-Key: <repo>/<check-id>

<One or two sentences: what is wrong.>

**Where** — <file:line>, <file:line>  (all of them; a truncated list is a bug report
that cannot be reproduced)

**Why it matters** — <the failure this causes, in one or two sentences.>

**Found by** — <the check name> · <reference doc>
```

For an invariant, use the `diagnosis` and `reference` from that entry in
`.claude/suite.json` **verbatim** for those last two fields. They were written to name
the specific silent failure behind the rule, and paraphrasing loses exactly the part
that made the rule worth having.

**Do not propose the fix.** No patch, no diff, no "just change X to Y", no
implementation sketch. Diagnosis is this sweep's job and the whole of it; deciding what
to do about it is the reader's, and an unreviewed suggestion from an unattended run is
worth less than the space it takes up. State the problem and stop.

Paste an error only when it is the evidence — the failing assertion, the drift the
script printed — and only the relevant lines of it. Never a full log.

**If no GitHub issue tooling is available in the session**, do not drop the findings
and do not treat the sweep as complete. Put every finding, in full and with its key
line, into the report of step 7, and state plainly at the top that issue filing was
**blocked** and why. A scheduled run reaches a human through its completion
notification; a finding that only ever existed in a session nobody opened is a finding
that was never made.

## 6. The run log

Findings become issues. **Every run also leaves a record of itself, including the
runs that find nothing** — those are the ones with no other trace, and a sweep whose
clean weeks are indistinguishable from the weeks it did not fire is not evidence of
anything.

The log is a single permanent issue in **this repo**, labelled `health-check`, with
this on its own line in the body:

```
Health-Sweep-Log: kollektiv
```

Search that line first. Find it and comment; find nothing and open it once, titled
`Health sweep run log`. **Never close it, and never open a second one** — it is a
ledger, not a finding, and the one thing that makes it readable is that a year of
runs sits in one place in order.

Post exactly one comment per run, whatever the outcome:

```
## <YYYY-MM-DD> — <clean | N finding(s)>

| Repo | Checks | Result |
|---|---|---|
| kollektiv | 12/12 | pass |
| Konnekt | 20/21 | 1 skipped |
| Kommands | 14/14 | pass |

**Drift** — 9/9 pass
**Deep review** — <the rotating area covered, or: skipped, with the reason>
**Could not run** — <N, and which; or: none>

**Opened** — <links, or: none>
**Commented** — <links, or: none>
**No longer reproducing** — <links, or: none>
```

Counts, not prose. The detail belongs in the issues; this is the row that says the
sweep ran, what it covered, and what it could not reach. `Could not run` is the
column worth reading a year later, and the whole reason a clean run still posts: a
run reporting `14/14 pass` and a run reporting `0/14, workspace never assembled` are
both silent otherwise, and only one of them is good news.

If issue tooling is unavailable, the log comment cannot be posted either. Say so at
the top of the report alongside the blocked findings, per step 5.

## 7. Report

One table per repo, in the shape `/suite-kit:health` already uses:

| Check | Result |
|---|---|

Then, for the run as a whole: issues opened, issues commented on, and issues whose
finding no longer reproduces — each as a link. Add a link to the run-log comment
step 6 posted.

Close with the count of checks that **could not run**, and why. If that count is not
zero, it is the first thing the report should say after the tables, not a footnote.

The report reaches a human through the Routine's completion notification and then
exists only in a session transcript. The run log is what survives, so anything worth
knowing in six months belongs in step 6's comment, not only here.
