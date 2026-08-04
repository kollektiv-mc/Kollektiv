# Adopting suite-kit in a product repo

Three things go into each product repo: a settings block, a `.claude/suite.json`,
and two `.gitignore` lines. Nothing else about the repo changes.

---

## 1. Declare the marketplaces

In the repo's committed `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "kollektiv": { "source": { "source": "github", "repo": "sandrogekeler/kollektiv" } },
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
| `tokens.role` | `source` if this repo defines the token set, `consumer` if it derives them |
| `tokens.enforce` | `strict`, or `migrating` where pre-existing literals are expected |
| `tokens.paths` | Paths the token rule covers |
| `minecraft.targetVersion` | Version the repo emits for |
| `minecraft.dataSource` | Where pinned registry data comes from |
| `minecraft.traitMatrix` | Path to the version-trait document |
| `health.commands` | Ordered `{ name, run, cwd? }` list — `cwd` is relative to the repo root and defaults to it |
| `health.invariants` | `{ name, grep, paths, exclude, expect, diagnosis, reference }` |
| `health.generated` | `{ regenerate, expectCleanDiff, requiresNetwork, diagnosis, reference }` |

`Kommands/.claude/suite.json` is the worked example.

The `diagnosis` and `reference` fields are not decoration. An invariant without a
stated reason gets deleted the first time it is inconvenient.

## 3. Ignore the runtime state

```gitignore
.claude/settings.local.json
.claude/.omc/
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists and OMC's session state are not shared.

---

## Per-repo notes

### kollektiv (this repo)

kollektiv is itself an adopter, not just the source of the plugin. Its
`.claude/suite.json` has `linear.team: "KOL"` and
`roadmap: "docs/roadmap.md"`, and its `.claude/settings.json` enables
`suite-kit@kollektiv` from the local marketplace plus `oh-my-claudecode@omc` —
it omits `kollektiv` from `extraKnownMarketplaces` since this repo already is
that marketplace and declaring it as a remote `github` source would register it
twice. It has no `tokens`, `minecraft`, `health.invariants`, or
`health.generated` block: this repo has no design tokens, emits no Minecraft
commands, and generates nothing, so nothing was invented to fill those slots.

The Linear workspace backing all three repos was recreated from scratch on
2026-08-04 as `Kollektiv-MC` (team `KOL`), replacing the old `KonnektMC`
workspace, which is abandoned rather than migrated. Old `KON-*` references in
Konnekt's merged PRs and `agent_docs/LINEAR.md` now point at nothing, since the
new workspace renumbers `KON` from 1.

### Kommands

`.claude/suite.json`, `docs/suite.md`, and the `.gitignore` lines are in place.
Two things are still pending, not done: the settings block above, and the
switch of task tracking from GitHub Issues to Linear `KMD` — the `KMD` team is
being created in the new `Kollektiv-MC` workspace, and did not exist in either
workspace before now.

`.claude/rules/*.md` stay where they are. They are path-scoped and auto-inject when
a matching file is edited — a plugin skill does not do that, so the plugin does not
replace them. Only `styling.md` overlaps `/suite-kit:design-tokens`, and the
overlap is deliberate: the rule fires on edit, the skill on request.

### Konnekt

Applied. `.claude/suite.json` uses `kind: "wails-desktop"`, `linear.team: "KON"`,
`roadmap: "agent_docs/ROADMAP.md"`, `tokens.role: "source"` and
`tokens.enforce: "migrating"` — the repo is mid-migration from an
inline-styles-everywhere convention, per `agent_docs/HEALTH_CHECKLIST.md`
Milestone 2. It has no `health.invariants`: Konnekt is a server dashboard, not a
command generator, so the Minecraft-syntax grep checks Kommands carries don't apply
here — nothing was invented to fill the slot.

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
