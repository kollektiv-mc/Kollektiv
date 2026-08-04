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

## 1. Commands

Run each entry in `health.commands` in order. Record pass or fail per entry.

## 2. Invariants

Each entry in `health.invariants` is a grep that must find nothing. Run it against
the entry's `paths`, honouring `exclude`, and treat any match as a failure.

These are the checks a linter cannot express. They exist because each one has a
specific, silent failure mode behind it — the entry's `diagnosis` says which, and
its `reference` points at the document that explains why. Read the reference before
deciding a match is acceptable.

Some invariants carry a legitimate exception in their `diagnosis` — a namespace
prefix under construction, for example, as opposed to a fully named identifier.
Judge a match against the diagnosis, not against the regex.

## 3. Generated files

If `health.generated` is present, run its `regenerate` command and confirm each
path in `expectCleanDiff` is unchanged.

A non-empty diff means one of two things, and both are bugs: a generated file was
hand-edited, or a generator change was committed without its regenerated output.

When `requiresNetwork` is true and the machine is offline, report this check as
**skipped**, with the reason.

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
