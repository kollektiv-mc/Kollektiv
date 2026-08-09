---
description: Run this repo's lint, typecheck, tests, and architectural invariant checks, then report a table. Use before calling any task done, and whenever asked for a health check, to verify a change did not break an invariant, or to confirm generated files are still in sync.
---

# Health check

Read `.claude/suite.json` at the repo root. It declares what this product's health
means: `health.commands`, `health.invariants`, and `health.generated`. If the file
is missing, say so and stop — do not guess a set of checks.

**Run every check. Do not stop at the first failure.** A partial run hides
compounding problems: a lint failure and a broken invariant are different bugs, and
finding one is not a reason to leave the other undiscovered.

---

## 1. Run the checks

`suite-check.py` runs all three sections from the manifest. Use it rather than
reconstructing the commands and greps by hand — two implementations of the same
checks is the drift this suite exists to prevent, and the hand-run version is the
one that quietly diverges.

Take the first of these that exists:

1. `.claude/suite-check.py` — the vendored copy. The normal path, and the only one
   that works when the plugin is not installed.
2. `${CLAUDE_PLUGIN_ROOT}/suite-check.py` — the copy inside this plugin.
3. Neither — run the manifest's entries by hand as described below, and say in your
   report that you did. Then mention that
   `kollektiv/scripts/sync-runner.sh` vendors the runner, since a repo missing it
   will keep hitting this.

```sh
.claude/suite-check.py --json
```

`--json` gives one record per check with `status`, `reason`, and the matching lines.
Useful flags: `--section` to run one section, `--offline` where a network-dependent
generator should be skipped without probing, `--require-runnable` to make a skip a
failure.

Exit codes are `0` no failures, `1` at least one failure, `2` the manifest could not
be read.

## 2. Judge the invariant matches

The runner reports every match. It does not decide whether a match is a violation,
because it cannot: `health.invariants` entries carry a `diagnosis` naming the
specific silent failure behind the rule, and some name a legitimate exception — a
namespace prefix under construction, as opposed to a fully named identifier.

Read the entry's `diagnosis` and `reference` before deciding a match is acceptable.
Judge a match against the diagnosis, not against the regex.

**When you judge a match legitimate, say so in the report and encode it.** Add the
path to that invariant's `exclude`, or sharpen its `grep`. A decision made once in a
session is invisible to CI and to the next session; a commit is not. This is the
whole difference between the runner and the skill — the runner is binary because it
has no one to ask, so the exception has to become part of the rule.

## 3. Interpret the skips

The runner skips a check it could not run: no `package.json`, no `node_modules`, a
path the invariant covers that does not exist yet, a network-dependent generator
while offline. Each skip carries its reason.

**A skip is never a pass.** Report it as a skip, with the reason. If the whole run is
skips — which is what a pre-scaffold repo looks like — that is the finding, and the
report should say plainly that nothing was verified.

---

## Reporting

One table, every check, in the order above:

| Check | Result |
|---|---|

For each failure give the file, the line, and a one-line diagnosis. Do not fix
anything unless asked — report first.

A check that could not run is `skipped`, with its reason. **Never report a skipped
check as passing.** Most of what this skill is for is the gap between "I ran the
checks" and "the checks passed", and collapsing the two is the one outcome that
makes the whole exercise worthless.
