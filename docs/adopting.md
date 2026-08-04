# Adopting suite-kit in a product repo

Four things go into each product repo: a settings block, a `.claude/suite.json`, a
vendored `tokens.source.json`, and two `.gitignore` lines. Nothing else about the
repo changes.

---

## 1. Declare the marketplaces

In the repo's committed `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "kollektiv": { "source": { "source": "github", "repo": "kollektiv-mc/Kollektiv" } },
    "omc": { "source": { "source": "github", "repo": "Yeachan-Heo/oh-my-claudecode" } }
  },
  "enabledPlugins": {
    "suite-kit@kollektiv": true,
    "oh-my-claudecode@omc": true
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

## 2. Add `.claude/suite.json`

This is the file every suite-kit skill reads. Product-specific facts live here,
next to the code they constrain, rather than inside the plugin.

| Field | Meaning |
|---|---|
| `product` | Display name |
| `kind` | Stack shape, e.g. `wails-desktop`, `vite-web` |
| `linear.team` | Team key for `/suite-kit:linear-sync` |
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

## 3. Vendor the token source

```sh
./scripts/sync-tokens.sh          # from the kollektiv root
```

This copies `design/tokens.json` into the repo as `tokens.source.json`. Commit it,
along with whatever `tokens.generate` produces from it. Both files are inputs a
build reads, so both are committed — a product must build from a standalone clone,
without a `kollektiv` checkout beside it.

## 4. Ignore the runtime state

```gitignore
.claude/settings.local.json
.claude/.omc/
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists and OMC's session state are not shared.

---

## Per-repo notes

An earlier revision of this page recorded both repos as adopted. They were not:
neither carried a `.claude/suite.json`, and the `docs/suite.md` it credited Kommands
with never existed. Every suite-kit skill that opens by reading that file was
therefore inoperable in both repos. The notes below describe what is actually on
disk.

### Kommands

`.claude/settings.json`, `.claude/suite.json`, `tokens.source.json`, the
`.gitignore` lines, and the switch of task tracking from GitHub Issues to Linear
`KMD` are in place.

`health.commands` is present but every entry is currently unrunnable — the repo is
pre-scaffold, with `docs/` and `.claude/` and no `package.json`. That is expected,
and `/health-check` already reports an unrunnable check as `skipped` with a reason
rather than as passing. `tokens.generate` names `pnpm gen:tokens`, which likewise
does not exist yet; `docs/design-tokens.md` specifies its contract for whoever
scaffolds the app.

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
it cannot collide with those.

**Still outstanding:** move the reusable parts of `agent_docs/LINEAR.md` — the
magic-word PR convention and the `Source: <roadmap> § <section>` mapping rule — up
into this repo, leaving Konnekt's own project and milestone structure where it is.

Expect friction between OMC's agents and the graphify guards: the guards nudge away
from raw reads and greps, and OMC's agents read and grep constantly. Worth a
session of observation before enabling OMC repo-wide there.
