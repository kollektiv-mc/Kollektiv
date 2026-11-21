# Adopting suite-kit in a product repo

A product repo first adopts the
[AllesSandro template](https://github.com/sandrogekeler/AllesSandro) (step 5),
before anything else. It brings the check runner, the shared workflows, the release-notes
generator, the aislop policy and the agent rules, and keeps them current
through Renovate. The steps below add what is specific to this suite: the
plugin, the manifest, the token source and the label taxonomy.

---

## 1. Declare the marketplaces

In the repo's committed `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "kollektiv": { "source": { "source": "github", "repo": "kollektiv-mc/Kollektiv" } },
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } }
  },
  "enabledPlugins": {
    "suite-kit@kollektiv": true,
    "superpowers@superpowers-dev": true
  }
}
```

`enabledPlugins` is an **object**, not an array: the schema rejects the array form
that some documentation examples show.

**`superpowers-dev` is not a typo.** The marketplace at `obra/superpowers` names
itself `superpowers-dev` in its own manifest, and the manifest's name wins over the
key written here: `claude plugin marketplace add obra/superpowers` reports
`Successfully added marketplace: superpowers-dev` and writes that spelling into
settings itself. All three repos declared it as `superpowers` until 2026-09-15, so
`claude plugin install superpowers@superpowers` failed on every machine and in every
scheduled run with `Plugin "superpowers" not found in marketplace "superpowers"`: a
message that reads like upstream removed the plugin rather than like a wrong id.

Declaring is not installing. On first run Claude Code reports the plugin as not
installed and prints a `claude plugin install` line; run it once per machine. This
applies on every path that loads plugins, including cloud sessions:

```sh
claude plugin marketplace add ./          # in kollektiv; a bare `.` is rejected
claude plugin install suite-kit@kollektiv
claude plugin marketplace add obra/superpowers
claude plugin install superpowers@superpowers-dev
```

In a scheduled or cloud session nothing is installed at startup, so this is the
normal opening move rather than a repair: `/suite-kit:health-sweep` does it as its
step 0.

Both marketplaces run third-party code with your privileges. Enabling them is a
trust decision: make it deliberately, per repo.

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
| `tracking` | `github-issues` for every repo in the suite today. Exactly one of `linear` or `tracking` is required: see [`conventions.md`](conventions.md) |
| `roadmap` | Path to the repo's direction/sequencing doc. Not a work-item list: `/suite-kit:suite-sync` mirrors GitHub Issues into Linear, not this file |
| `tokens.role` | Always `consumer` for a product repo: the token set is defined in kollektiv's `design/tokens.json`, not in any product |
| `tokens.source` | The repo the token values come from: `kollektiv` |
| `tokens.sourceFile` | Path to the vendored copy of that source, `tokens.source.json` |
| `tokens.generate` | Command that regenerates this repo's token output from the vendored source |
| `tokens.enforce` | `strict`, or `migrating` where pre-existing literals are expected |
| `tokens.paths` | Paths the token rule covers |
| `minecraft.targetVersion` | Version the repo emits for |
| `minecraft.dataSource` | Where pinned registry data comes from |
| `minecraft.traitMatrix` | Path to the version-trait document |
| `health.commands` | Ordered `{ name, run, cwd? }` list: `cwd` is relative to the repo root and defaults to it |
| `health.invariants` | `{ name, grep, paths, exclude, expect, diagnosis, reference }` |
| `health.generated` | List of `{ regenerate, cwd?, expectCleanDiff, requiresNetwork, diagnosis, reference }`: a repo can have more than one generator, and Kommands has two. `expectCleanDiff` is the list of repo-relative paths that must be unchanged after `regenerate` runs |
| `health.memory` | `{ maxLines, reason }`, and **only** if the repo is over the always-loaded memory budget. The `memory` section runs on every repo regardless of what the manifest says, because every repo pays that cost; this field is the ratchet a repo in excess holds while it comes down, and `maxLines` has a schema minimum of 201 so it cannot outlive the excess. See `docs/conventions.md` § The agent memory budget |

`Kommands/.claude/suite.json` is the worked example.

The `diagnosis` and `reference` fields are not decoration. An invariant without a
stated reason gets deleted the first time it is inconvenient.

## 4. Vendor the token source

```sh
./scripts/sync-tokens.sh          # from the kollektiv root
```

This copies `design/tokens.json` into the repo as `tokens.source.json`. Commit it,
along with whatever `tokens.generate` produces from it. Both files are inputs a
build reads, so both are committed: a product must build from a standalone clone,
without a `kollektiv` checkout beside it.

## 5. Adopt the AllesSandro template

Follow AllesSandro's `docs/adopting.md`, "An existing repo", in the product's
checkout:

```sh
copier copy --trust https://github.com/sandrogekeler/AllesSandro.git .
```

Answer `owner: kollektiv-mc`, the repo's own `kind` and `languages`, and
`release_notes: true` for a product that ships releases. Keep the repo's own
version of every seeded file Copier asks about. Then install Mend Renovate on
the repo (the kollektiv-mc org install, "Only selected repositories").

A repo's `.claude/suite.json` is seeded, so the one this page describes stays.
The files the template locks are not the place to edit: a local change conflicts
on the next template update and turns the repo's `template-guard` check red.
List them in `.aislopignore` and the root `.prettierignore`;
`scripts/check-participation.sh` checks that.

## 6. Write the label file

```sh
./scripts/sync-labels.sh          # from the kollektiv root
```

writes `design/labels.json`'s GitHub taxonomy into the repo's
`.github/labels.json`, replacing the template's default. The repo's `labels`
workflow applies it to GitHub when it reaches `main`. Add the repo to
`suite.repos.json` first; `--check` reports drift.

## 7. Ignore the runtime state

```gitignore
.claude/settings.local.json
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists are not shared.


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
`suite-kit@kollektiv` from the local marketplace plus `superpowers@superpowers-dev`:
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

Its settings block declares `suite-kit@kollektiv` and `superpowers@superpowers-dev`.
This was ahead of the rest of the suite rather than a deviation from it: OMC has
since been dropped everywhere, and step 1 above now names `superpowers` for
everyone.

**Kommands is tracked in GitHub Issues**, same as every other repo in the suite
now: its manifest declares `tracking: "github-issues"` and carries no `linear`
block. An earlier revision of this page described a switch to a Linear `KMD`
team; that switch was never made and is no longer planned: see
[`conventions.md`](conventions.md).

Its `.claude/commands/health-check.md` was **deleted** on adoption. It reimplemented
`/suite-kit:health` with the invariant greps hardcoded inline; those greps now live in
`health.invariants` where the plugin can read them. Two definitions of the same checks
is the drift this repo exists to prevent, and shipping the plugin while leaving the
copy in place would have been the clearest possible example of it.

`health.commands` declares the JS toolchain (`pnpm lint`, `typecheck`, `test`,
`format:check`, the build and bundle budget) and the Go shell's checks (`go vet` and
`go test` over `shell/`), three `invariants` and three `generated` entries, and its
CI runs `.claude/suite-check.py` with `--require-runnable` on every push, so a skip there
is a failure. Only its web build is released today; the desktop shell waits on a release
workflow that produces installable artefacts (Kommands #44).

It has adopted the AllesSandro template, with its own aislop ratchet and
`.github/changelog.json`. It has no release workflow yet, so the release-notes
generator is tested on every push and not yet called.

`.claude/rules/*.md` stay where they are. They are path-scoped and auto-inject when
a matching file is edited: a plugin skill does not do that, so the plugin does not
replace them. Only `styling.md` overlaps `/suite-kit:design-tokens`, and the
overlap is deliberate: the rule fires on edit, the skill on request.

### Konnekt

`.claude/suite.json` uses `kind: "wails-desktop"`, `roadmap: "agent_docs/ROADMAP.md"`,
and `tokens.enforce: "migrating"`: the repo is
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
`requiresNetwork: false`: the generator reads a committed local file, so unlike
Kommands' mcmeta derivation it works offline. Its clean-diff check runs in CI
(`.github/workflows/ci.yml`), not just `/suite-kit:health`: that landed in PR #22,
merged 2026-08-04.

It has one `health.invariants` entry, `no literal border widths`, from its own
token migration. The Minecraft-syntax greps Kommands carries do not apply to a
server dashboard, and nothing was invented to fill that slot.

It has adopted the AllesSandro template, with its own aislop ratchet and
`.github/changelog.json`.

`health.commands` uses `cwd` to mix toolchains in one list: `pnpm typecheck`,
`pnpm lint`, `pnpm test`, `pnpm check-bundle` with `cwd: "frontend"`, and
`go vet ./...` / `go test ./...` with no `cwd` (repo root).

The settings block is merged into `.claude/settings.json` without disturbing its
`hooks` section: Konnekt binds `graphify hook-guard` to `PreToolUse` on `Bash`,
`Read`, and `Glob`; suite-kit ships no hooks specifically so it cannot collide with
those. It declares `superpowers@superpowers-dev`, not OMC, which this repo (and the
whole suite) no longer uses. All of this (the permissions block, the CI check, the
OMC → superpowers swap, and deleting `.claude/commands/linear-sync.md`) is on
`main` via PR #22.

`.claude/commands/linear-sync.md` duplicated the plugin skill and had already gone
stale, targeting the `KonnektMC` workspace deleted 2026-08-04: running it did
nothing useful. `agent_docs/LINEAR.md` now points at kollektiv's
[`linear.md`](linear.md) for the suite-wide structure rather than describing its
own from scratch; Konnekt-specific facts (which team, which project, which
milestones) are the only thing that stays there.

Watch for friction between superpowers' agents and the graphify guards before
enabling it repo-wide beyond what `.claude/settings.json` already declares: the
guards nudge away from raw reads and greps, and an agent framework that reads and
greps constantly is worth a session of observation regardless of which one it is.
Tracked as [kollektiv-mc/konnekt#49](https://github.com/kollektiv-mc/Konnekt/issues/49).
