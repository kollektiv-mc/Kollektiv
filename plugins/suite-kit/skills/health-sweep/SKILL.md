---
description: Sweep every repo in suite.repos.json — run each product's health checks, review the week's changes, and file findings as deduplicated GitHub issues in the repo they belong to. Use for the weekly scheduled health check, or whenever asked for a suite-wide rather than single-repo report.
disable-model-invocation: true
---

# Suite-wide health sweep

`/suite-kit:health` reports on **one** repo, on demand. This sweeps **all** of them,
unattended, and writes what it finds down where the work happens.

Run this from the workspace root (`kollektiv`). It is the scheduled counterpart to
`/suite-kit:health`, not a replacement for it — step 3 below runs that skill in each
repo rather than reimplementing its logic.

**This sweep never changes code.** It files issues and reports. It does not commit,
push, open pull requests, or fix what it finds. A finding that looks trivial is still
a finding, not an invitation.

---

## 1. Assemble the workspace

Read `suite.repos.json` for the repo list. **Do not hardcode product names** — a
fourth repo added to that manifest must be swept without editing this skill.

For each repo, attach it to the session with `add_repo` (`access: "push"` — filing
issues needs credentials, cloning alone does not), clone it beside this repo as
`<root>/<name>` exactly as `scripts/bootstrap.sh` does, then call
`register_repo_root` so the product's own `CLAUDE.md`, skills, and settings load.

A repo that cannot be attached or cloned is reported as **skipped, with the tool's
own reason**, and the sweep continues to the next one. One unreachable product does
not cancel the other checks.

## 2. Token drift

With every product cloned, run `./scripts/sync-tokens.sh --check` from the root.

This is the check `/suite-kit:health` deliberately leaves out: it needs the full
workspace, and would fail on a bare checkout. **Here it belongs**, because assembling
that workspace is step 1. Read the script's three outcomes carefully — it distinguishes
"no drift", "no drift among the products present, but the workspace is incomplete", and
actual drift, specifically so the middle one is not read as a pass. Report it the way
the script reports it.

Then run `./scripts/validate-schemas.sh --require-products`. With every product
present, an unadopted product is a finding rather than a skip.

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

**If `superpowers` is not installed on this machine, try installing it once:**
`claude plugin install superpowers@superpowers`. It is declared in every repo's
`.claude/settings.json`, but declaring is not installing, and a cloud session starts
from a fresh container.

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

A new issue's body carries: the key line, the affected files with line numbers, the
diagnosis, and the `reference` document. For an invariant, use the `diagnosis` and
`reference` from that entry in `.claude/suite.json` verbatim — they were written to
explain the specific silent failure behind the rule, and paraphrasing loses that.

## 6. Report

One table per repo, in the shape `/suite-kit:health` already uses:

| Check | Result |
|---|---|

Then, for the run as a whole: issues opened, issues commented on, and issues whose
finding no longer reproduces — each as a link.

Close with the count of checks that **could not run**, and why. If that count is not
zero, it is the first thing the report should say after the tables, not a footnote.
