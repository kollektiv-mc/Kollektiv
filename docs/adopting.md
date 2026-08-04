# Adopting suite-kit in a product repo

Five things go into each product repo: a settings block, a permissions block, a
`.claude/suite.json`, a vendored `tokens.source.json`, and two `.gitignore` lines.
Nothing else about the repo changes.

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
| `linear.team` | Team key for `/suite-kit:linear-sync` |
| `tracking` | `github-issues`, for a repo not tracked in Linear. Exactly one of `linear` or `tracking` is required — see [`conventions.md`](conventions.md) |
| `roadmap` | Path to the roadmap that skill reconciles against |
| `tokens.role` | Always `consumer` for a product repo — the token set is defined in kollektiv's `design/tokens.json`, not in any product |
| `tokens.source` | The repo the token values come from — `kollektiv` |
| `tokens.sourceFile` | Path to the vendored copy of that source, `tokens.source.json` |
| `tokens.generate` | Command that regenerates this repo's token output from the vendored source |
| `tokens.enforce` | `strict`, or `migrating` where pre-existing literals are expected |
| `tokens.paths` | Paths the token rule covers |
| `minecraft.targetVersion` | Version the repo emits for |
| `minecraft.dataSource` | Where pinned registry data comes from |
| `minecraft.traitMatrix` | Path to the version-trait document |
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

## 5. Ignore the runtime state

```gitignore
.claude/settings.local.json
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists are not shared.

---

## Per-repo notes

An earlier revision of this page recorded both repos as adopted. They were not:
neither carried a `.claude/suite.json`, and the `docs/suite.md` it credited Kommands
with never existed. Every suite-kit skill that opens by reading that file was
therefore inoperable in both repos. The notes below describe what is actually on
disk.

### kollektiv (this repo)

kollektiv is itself an adopter, not just the source of the plugin. Its
`.claude/suite.json` has `linear.team: "KOL"` and
`roadmap: "docs/roadmap.md"`, and its `.claude/settings.json` enables
`suite-kit@kollektiv` from the local marketplace plus `superpowers@superpowers` —
it omits `kollektiv` from `extraKnownMarketplaces` since this repo already is
that marketplace and declaring it as a remote `github` source would register it
twice. It has no `tokens`, `minecraft`, `health.invariants`, or
`health.generated` block: it authors [`design/tokens.json`](../design/tokens.json)
as raw data rather than styled application code, so the `tokens.role`/`enforce`
machinery that guards literal hex and px in product code doesn't apply to it; it
emits no Minecraft commands and generates nothing, so nothing was invented to
fill those two slots either.

The Linear workspace was recreated from scratch on 2026-08-04 as `Kollektiv-MC`
(team `KOL`), replacing the old `KonnektMC` workspace, which is abandoned rather
than migrated. Old `KON-*` references in Konnekt's merged PRs now point at nothing,
since the new workspace renumbers `KON` from 1.

It holds one team and one project today. The `KON` team is declared in Konnekt's
manifest but not yet provisioned; see `docs/roadmap.md`.

### Kommands

> **Not yet on `main`.** All of the below is on
> `kommands@claude/adopt-suite-kit` and is accurate for that branch only.
> `main` carries none of the five pieces. This page has twice described
> Kommands as adopted when it was not; the distinction between "written" and
> "merged" is the one it keeps losing.

`.claude/settings.json`, `.claude/suite.json`, `tokens.source.json`, and the
`.gitignore` lines land together on that branch.

Its settings block declares `suite-kit@kollektiv` and `superpowers@superpowers`.
This was ahead of the rest of the suite rather than a deviation from it: OMC has
since been dropped everywhere, and step 1 above now names `superpowers` for
everyone.

**Kommands is tracked in GitHub Issues, not Linear.** Its manifest declares
`tracking: "github-issues"` and carries no `linear` block. `/suite-kit:linear-sync`
reports that and stops. An earlier revision of this page described a switch to a
Linear `KMD` team; that switch was never made and is no longer planned — see
[`conventions.md`](conventions.md) § Tracking is a per-repo choice.

Its `.claude/commands/health-check.md` was **deleted** on adoption. It reimplemented
`/suite-kit:health` with the invariant greps hardcoded inline; those greps now live in
`health.invariants` where the plugin can read them. Two definitions of the same checks
is the drift this repo exists to prevent, and shipping the plugin while leaving the
copy in place would have been the clearest possible example of it.

`health.commands` is present but every entry is currently unrunnable — the repo is
pre-scaffold, with `docs/` and `.claude/` and no `package.json`. That is expected,
and `/suite-kit:health` reports an unrunnable check as `skipped` with a reason
rather than as passing. `tokens.generate` names `pnpm gen:tokens`, which likewise
does not exist yet; `docs/design-tokens.md` specifies its contract for whoever
scaffolds the app. The repo has no CI beyond the Claude workflows for the same
reason; adding it is a scaffold-time task.

`.claude/rules/*.md` stay where they are. They are path-scoped and auto-inject when
a matching file is edited — a plugin skill does not do that, so the plugin does not
replace them. Only `styling.md` overlaps `/suite-kit:design-tokens`, and the
overlap is deliberate: the rule fires on edit, the skill on request.

### Konnekt

`.claude/suite.json` uses `kind: "wails-desktop"`, `linear.team: "KON"`,
`roadmap: "agent_docs/ROADMAP.md"`, and `tokens.enforce: "migrating"` — the repo is
mid-migration from an inline-styles-everywhere convention, per
`agent_docs/HEALTH_CHECKLIST.md` Milestone 2. As of that migration's start the
covered paths hold 176 hex literals across 33 files and 323 arbitrary-px values
across 76 `.tsx` files, which is what `migrating` exists to describe.

`tokens.role` is `consumer`, not `source`. Konnekt authored the design language, but
the values now live in kollektiv's `design/tokens.json` and Konnekt generates
`frontend/src/styles/tokens.css` from the vendored copy. Leaving it as `source`
would mean a repo that both produces and consumes the same set, which is exactly the
round-trip that makes regeneration unsafe.

`health.generated` covers `pnpm gen:tokens` with `expectCleanDiff: true` and
`requiresNetwork: false` — the generator reads a committed local file, so unlike
Kommands' mcmeta derivation it works offline.

It has no `health.invariants`: Konnekt is a server dashboard, not a command
generator, so the Minecraft-syntax grep checks Kommands carries don't apply here —
nothing was invented to fill the slot.

`health.commands` uses `cwd` to mix toolchains in one list — `pnpm typecheck`,
`pnpm lint`, `pnpm test`, `pnpm check-bundle` with `cwd: "frontend"`, and
`go vet ./...` / `go test ./...` with no `cwd` (repo root).

The settings block was merged into the existing `.claude/settings.json` without
disturbing its `hooks` section — Konnekt binds `graphify hook-guard` to
`PreToolUse` on `Bash`, `Read`, and `Glob`; suite-kit ships no hooks specifically so
it cannot collide with those. It declares `superpowers@superpowers`, not OMC, which
this repo — and the whole suite — no longer uses.

> **Partly unmerged.** The command deletion, the CI check, the permissions
> block, and the OMC → superpowers swap below are on
> `konnekt@claude/suite-kit-enforcement`. The `.claude/suite.json` and vendored
> tokens are on `main`.

Its `.claude/commands/linear-sync.md` was **deleted** on adoption. It duplicated
`/suite-kit:linear-sync` and had already gone stale, targeting the `KonnektMC`
workspace that was deleted on 2026-08-04 — running it did nothing useful. The
reusable parts of `agent_docs/LINEAR.md` now live in
[`conventions.md`](conventions.md); Konnekt's own project, milestone, and label
structure stays in `agent_docs/LINEAR.md` where it belongs.

Its CI runs the `gen:tokens` clean-diff check that `health.generated` describes, so
that invariant no longer depends on an agent choosing to run a skill.

Watch for friction between superpowers' agents and the graphify guards before
enabling it repo-wide beyond what `.claude/settings.json` already declares — the
guards nudge away from raw reads and greps, and an agent framework that reads and
greps constantly is worth a session of observation regardless of which one it is.
