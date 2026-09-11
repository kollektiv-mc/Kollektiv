# Adopting suite-kit in a product repo

Six things go into each product repo: a settings block, a permissions block, a
`.claude/suite.json`, a vendored `tokens.source.json`, a vendored
`.claude/suite-check.py`, and two `.gitignore` lines. Two more are the shared
gates, adopted once the repo has a toolchain to gate: the aislop policy and the
priority question its issue forms ask (step 7). Nothing else about the repo
changes.

```sh
./scripts/adopt.sh ../NewRepo --kind vite-web
```

does the mechanical part of every step below — the manifest, the permissions floor,
the `.gitignore` line, and both vendored files. It stops where judgement starts:
`tokens`, `minecraft` and `health.invariants` describe a particular codebase, and it
prints which of them still need filling in rather than guessing. Read on for what
each field means and why.

---

## 1. Declare the marketplaces

In the repo's committed `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "kollektiv": { "source": { "source": "github", "repo": "kollektiv-mc/Kollektiv" } },
    "superpowers": { "source": { "source": "github", "repo": "obra/superpowers" } }
  },
  "enabledPlugins": {
    "suite-kit@kollektiv": true,
    "superpowers@superpowers": true
  }
}
```

`enabledPlugins` is an **object**, not an array — the schema rejects the array form
that some documentation examples show.

Declaring is not installing. On first run Claude Code reports the plugin as not
installed and prints a `claude plugin install` line; run it once per machine. This
applies on every path that loads plugins, including cloud sessions.

Both marketplaces run third-party code with your privileges. Enabling them is a
trust decision — make it deliberately, per repo.

## 2. Add the permissions block

Merge the block from [`conventions.md`](conventions.md) § Required permissions block
into the same `.claude/settings.json`, without disturbing anything already there. The
`deny` and `ask` entries are the suite-wide floor; `allow` is per-repo.

This matters most for unattended agents and scheduled routines, which have nobody
watching to decline a prompt.

## 3. Add `.claude/suite.json`

This is the file every suite-kit skill reads. Product-specific facts live here,
next to the code they constrain, rather than inside the plugin.

Its schema is [`design/suite.schema.json`](../design/suite.schema.json), and
`scripts/validate-schemas.sh` checks every manifest in the workspace against it. Point
`$schema` at it for editor completion. A malformed manifest otherwise fails late,
inside a skill, as confusing prose.

| Field | Meaning |
|---|---|
| `product` | Display name |
| `kind` | Stack shape, e.g. `wails-desktop`, `vite-web` |
| `linear.team` | Team key for a repo tracked in Linear directly, bypassing the GitHub-Issues mirror. Nothing in the suite uses this today |
| `tracking` | `github-issues` for every repo in the suite today. Exactly one of `linear` or `tracking` is required — see [`conventions.md`](conventions.md) |
| `roadmap` | Path to the repo's direction/sequencing doc. Not a work-item list — `/suite-kit:suite-sync` mirrors GitHub Issues into Linear, not this file |
| `tokens.role` | Always `consumer` for a product repo — the token set is defined in kollektiv's `design/tokens.json`, not in any product |
| `tokens.source` | The repo the token values come from — `kollektiv` |
| `tokens.sourceFile` | Path to the vendored copy of that source, `tokens.source.json` |
| `tokens.generate` | Command that regenerates this repo's token output from the vendored source |
| `tokens.enforce` | `strict`, or `migrating` where pre-existing literals are expected |
| `tokens.paths` | Paths the token rule covers |
| `minecraft.targetVersion` | Version the repo emits for |
| `minecraft.dataSource` | Where pinned registry data comes from |
| `minecraft.traitMatrix` | Path to the version-trait document |
| `distribution.current` | Builds a user can obtain today, e.g. `web`, `desktop-wails-v2`. For a product shipping more than one build from one codebase, which the single-valued `kind` cannot express. Omitted by a repo with one build |
| `distribution.planned` | Builds in the tree with no release producing installable artefacts yet |
| `distribution.doc` | The document describing the builds and the boundary between them. Must exist |
| `distribution.issue` | GitHub issue URL tracking the planned build, if one is open |
| `distribution.note` | A short pointer into `doc`, not a second copy of it |
| `docs` | camelCase names to repo-relative paths, the named entry points a skill or a person needs without guessing: `architecture`, `persistence`, `healthChecklist`. Every path must exist |
| `health.commands` | Ordered `{ name, run, cwd? }` list — `cwd` is relative to the repo root and defaults to it |
| `health.invariants` | `{ name, grep, paths, exclude, expect, diagnosis, reference }` |
| `health.generated` | List of `{ regenerate, cwd?, expectCleanDiff, requiresNetwork, diagnosis, reference }` — a repo can have more than one generator, and Kommands has two. `expectCleanDiff` is the list of repo-relative paths that must be unchanged after `regenerate` runs |

`Kommands/.claude/suite.json` is the worked example.

The `diagnosis` and `reference` fields are not decoration. An invariant without a
stated reason gets deleted the first time it is inconvenient.

## 4. Vendor the token source

```sh
./scripts/sync-tokens.sh          # from the kollektiv root
```

This copies `design/tokens.json` into the repo as `tokens.source.json`. Commit it,
along with whatever `tokens.generate` produces from it. Both files are inputs a
build reads, so both are committed — a product must build from a standalone clone,
without a `kollektiv` checkout beside it.

## 5. Vendor the check runner

```sh
./scripts/sync-runner.sh          # from the kollektiv root
```

This copies `plugins/suite-kit/suite-check.py` into the repo as
`.claude/suite-check.py`. Commit it.

**This is the step that makes the checks real.** Step 1 declares the plugin; it does
not install it, and nothing in a cloud container, a scheduled routine, or a fresh
clone will. Without the vendored runner, `.claude/suite.json` — every command, every
invariant, every `diagnosis` written to explain why a rule exists — is read by nothing
in exactly the environments that have no human watching.

Run it from the repo root:

```sh
.claude/suite-check.py              # all sections
.claude/suite-check.py --json       # for /suite-kit:health to judge against
```

It reports each check as `pass`, `fail`, or `skip` with a reason, and exits `0`, `1`,
or `2` (manifest unreadable). Skips do not affect the exit code — a repo that cannot
run a check yet is not a repo that failed it. `--require-runnable` inverts that, which
is what a product's CI turns on once its toolchain exists, so the checks cannot go
quietly vacuous.

Like `tokens.source.json`, the vendored copy is not the place to edit: the next
`sync-runner.sh` overwrites it. `scripts/sync-runner.sh --check` reports drift, and
the `Suite drift` workflow (`.github/workflows/drift.yml`) runs it on every push and
nightly, with `--require-vendored`: both products carry the runner, so a product
without it is one that lost the file, not one that has yet to adopt.

The same split, not adopted is a skip and stale is a failure, holds for every other
vendored file, and each `sync-*.sh --check` reports it the same way.

## 6. Ignore the runtime state

```gitignore
.claude/settings.local.json
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists are not shared.

## 7. Adopt the shared gates

Two more files are vendored once the repo has code to gate. Neither is scaffolded
by `adopt.sh`, because each needs a decision the script cannot make.

**The aislop policy.** Write `.aislop/config.yml` with `extends: ./base.yml` as its
first line (the `./` is load-bearing: aislop resolves the path relative to the config
and silently loads nothing without it), then run `./scripts/sync-aislop.sh` from the
kollektiv root, which copies `.aislop/base.yml` beside it. The base is the policy:
engines, the rules turned off and why, scoring, telemetry off, and `failBelow: 100`.
Your config carries only the size ratchet, `quality.maxFunctionLoc` and
`quality.maxFileLoc`, each held at the tree's largest function and file today and
lowered as they shrink, never raised; run `npx --yes aislop@0.16.0 scan` to find the
numbers. Add an `.aislopignore` listing what is generated or vendored, the vendored
Python above included. Then call the gate from CI:

```yaml
  aislop:
    uses: kollektiv-mc/Kollektiv/.github/workflows/aislop.yml@main
```

That workflow pins aislop and ruff in one place for every repo. ruff matters: aislop's
Python engines run only when a ruff binary is on PATH, and report nothing when it is
not.

**The priority question.** Every issue form asks it, and
`.github/workflows/issue-priority.yml` turns the answer into a `p*` label, because a
form's dropdown answer is otherwise body text that never becomes a label. Put the
markers into each form where the question should sit, as an empty block:

```yaml
  # >>> suite:priority. Vendored from kollektiv by scripts/sync-priority.sh. Edit it there.
  # <<< suite:priority
```

then run `./scripts/sync-priority.sh`, which renders the dropdown between them from
`design/labels.json`'s `priorityForm` and copies the workflow in. Nothing is inserted
into a form without the markers. Add the workflow to the repo's `.prettierignore` if
Prettier runs at its root: the sync byte-compares the copies, and a formatted copy is
drift.

`scripts/check-participation.sh` checks the last point for every vendored file, in
`.aislopignore` and a root `.prettierignore`, so a product gate cannot rewrite a
vendored file and hand the nightly a drift it cannot fix.

---

## Per-repo notes

An earlier revision of this page recorded both repos as adopted. They were not:
neither carried a `.claude/suite.json`, and the `docs/suite.md` it credited Kommands
with never existed. Every suite-kit skill that opens by reading that file was
therefore inoperable in both repos. The notes below describe what is actually on
disk.

### kollektiv (this repo)

kollektiv is itself an adopter, not just the source of the plugin. Its
`.claude/suite.json` declares `tracking: "github-issues"` and
`roadmap: "docs/roadmap.md"`, and its `.claude/settings.json` enables
`suite-kit@kollektiv` from the local marketplace plus `superpowers@superpowers` —
it omits `kollektiv` from `extraKnownMarketplaces` since this repo already is
that marketplace and declaring it as a remote `github` source would register it
twice. It has no `tokens`, `minecraft`, `health.invariants`, or
`health.generated` block: it authors [`design/tokens.json`](../design/tokens.json)
and [`design/labels.json`](../design/labels.json) as raw data rather than styled
application code, so the `tokens.role`/`enforce` machinery that guards literal hex
and px in product code doesn't apply to it; it emits no Minecraft commands and
generates nothing, so nothing was invented to fill those two slots either.

The Linear workspace was recreated from scratch on 2026-08-04 as `Kollektiv-MC`
(since renamed `Kollektiv`), replacing the old `KonnektMC` workspace, which is
abandoned rather than migrated. Old `KON-*` references in Konnekt's merged PRs
now point at nothing, since the new workspace renumbers from 1.

It holds two teams (`Kollektiv`, `Apps`) and one initiative (`Kollektiv Suite`)
today. See [`linear.md`](linear.md) for the full structure.

### Kommands

`.claude/settings.json`, `.claude/suite.json`, `tokens.source.json`, and the
`.gitignore` lines are all on `main`.

Its settings block declares `suite-kit@kollektiv` and `superpowers@superpowers`.
This was ahead of the rest of the suite rather than a deviation from it: OMC has
since been dropped everywhere, and step 1 above now names `superpowers` for
everyone.

**Kommands is tracked in GitHub Issues**, same as every other repo in the suite
now — its manifest declares `tracking: "github-issues"` and carries no `linear`
block. An earlier revision of this page described a switch to a Linear `KMD`
team; that switch was never made and is no longer planned — see
[`conventions.md`](conventions.md).

Its `.claude/commands/health-check.md` was **deleted** on adoption. It reimplemented
`/suite-kit:health` with the invariant greps hardcoded inline; those greps now live in
`health.invariants` where the plugin can read them. Two definitions of the same checks
is the drift this repo exists to prevent, and shipping the plugin while leaving the
copy in place would have been the clearest possible example of it.

`health.commands` declares the JS toolchain (`pnpm lint`, `typecheck`, `test`,
`format:check`, the build and bundle budget) and the Go shell's checks (`go vet` and
`go test` over `shell/`), three `invariants` and three `generated` entries, and its
CI runs the vendored runner with `--require-runnable` on every push, so a skip there
is a failure. Its `kind` is `vite-web+wails-desktop`, and its `distribution` block
records that only the web build is released today, with the desktop shell under
`planned` until a release workflow produces installable artefacts.

It carries the priority question in both forms and the vendored
`.github/workflows/issue-priority.yml`, and its `.prettierignore` excludes the
workflow and `tokens.source.json`. It has not adopted aislop, and has no
`.github/changelog.json`, so neither the release-notes generator nor the label gate
runs there yet; both are on `docs/roadmap.md`.

`.claude/rules/*.md` stay where they are. They are path-scoped and auto-inject when
a matching file is edited — a plugin skill does not do that, so the plugin does not
replace them. Only `styling.md` overlaps `/suite-kit:design-tokens`, and the
overlap is deliberate: the rule fires on edit, the skill on request.

### Konnekt

`.claude/suite.json` uses `kind: "wails-desktop"`, `roadmap: "agent_docs/ROADMAP.md"`,
and `tokens.enforce: "migrating"` — the repo is
mid-migration from an inline-styles-everywhere convention, per
`agent_docs/HEALTH_CHECKLIST.md` Milestone 2. As of that migration's start the
covered paths hold 176 hex literals across 33 files and 323 arbitrary-px values
across 76 `.tsx` files, which is what `migrating` exists to describe.

Its manifest declares `tracking: "github-issues"` on `main` since its PR #51
merged. An earlier revision of this page described the `linear: { team: "KON" }`
block that preceded it, which made `/suite-kit:suite-sync` skip the repo; that is
history now, and `scripts/check-participation.sh` is what notices if it returns.

`tokens.role` is `consumer`, not `source`. Konnekt authored the design language, but
the values now live in kollektiv's `design/tokens.json` and Konnekt generates
`frontend/src/styles/tokens.css` from the vendored copy. Leaving it as `source`
would mean a repo that both produced and consumed the same set, which is exactly the
round-trip that makes regeneration unsafe.

`health.generated` covers `pnpm gen:tokens` with `expectCleanDiff: true` and
`requiresNetwork: false` — the generator reads a committed local file, so unlike
Kommands' mcmeta derivation it works offline. Its clean-diff check runs in CI
(`.github/workflows/ci.yml`), not just `/suite-kit:health` — that landed in PR #22,
merged 2026-08-04.

It has one `health.invariants` entry, `no literal border widths`, from its own
token migration. The Minecraft-syntax greps Kommands carries do not apply to a
server dashboard, and nothing was invented to fill that slot.

It carries the release-notes generator (`.github/changelog.json` is its adoption
marker) and gates itself with aislop, with its own `.aislop/config.yml` predating the
suite's `base.yml`; adopting the base, listing the vendored generator in its
`.aislopignore`, and asking the priority question in its forms are all on
`docs/roadmap.md`.

`health.commands` uses `cwd` to mix toolchains in one list — `pnpm typecheck`,
`pnpm lint`, `pnpm test`, `pnpm check-bundle` with `cwd: "frontend"`, and
`go vet ./...` / `go test ./...` with no `cwd` (repo root).

The settings block is merged into `.claude/settings.json` without disturbing its
`hooks` section — Konnekt binds `graphify hook-guard` to `PreToolUse` on `Bash`,
`Read`, and `Glob`; suite-kit ships no hooks specifically so it cannot collide with
those. It declares `superpowers@superpowers`, not OMC, which this repo — and the
whole suite — no longer uses. All of this (the permissions block, the CI check, the
OMC → superpowers swap, and deleting `.claude/commands/linear-sync.md`) is on
`main` via PR #22.

`.claude/commands/linear-sync.md` duplicated the plugin skill and had already gone
stale, targeting the `KonnektMC` workspace deleted 2026-08-04 — running it did
nothing useful. `agent_docs/LINEAR.md` now points at kollektiv's
[`linear.md`](linear.md) for the suite-wide structure rather than describing its
own from scratch; Konnekt-specific facts (which team, which project, which
milestones) are the only thing that stays there.

Watch for friction between superpowers' agents and the graphify guards before
enabling it repo-wide beyond what `.claude/settings.json` already declares — the
guards nudge away from raw reads and greps, and an agent framework that reads and
greps constantly is worth a session of observation regardless of which one it is.
Tracked as [kollektiv-mc/konnekt#49](https://github.com/kollektiv-mc/Konnekt/issues/49).
