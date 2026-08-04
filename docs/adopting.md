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
    "superpowers": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } }
  },
  "enabledPlugins": {
    "suite-kit@kollektiv": true,
    "superpowers@superpowers": true,
    "context7@claude-plugins-official": true
  }
}
```

`enabledPlugins` is an **object**, not an array — the schema rejects the array form
that some documentation examples show.

Declaring is not installing. On first run Claude Code reports the plugin as not
installed and prints a `claude plugin install` line; run it once per machine. This
applies on every path that loads plugins, including cloud sessions.

Every marketplace here runs third-party code with your privileges. Enabling one is
a trust decision — make it deliberately, per repo. See **Plugin selection** below
for why these and not others. `context7` needs a Custom network allowlist entry for
cloud sessions (its host isn't in the Trusted default list); include it once that's
set up, or drop it and keep just `superpowers` if not.

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
```

Shared config is committed so every clone and cloud agent inherits the same setup.
Personal permission allowlists are not shared.

---

## Plugin selection

Third-party plugins here are chosen against a specific failure mode: the skill
listing Claude Code shows the model is budgeted at roughly 1% of the context
window, and when it overflows, descriptions are dropped starting with the skills
invoked least. A plugin with a large component count can silently crowd
suite-kit's own skills out of that listing. Only `superpowers` is currently
enabled suite-wide; `context7` and `claude-mem` were evaluated against the same
table but neither is enabled here yet.

| Plugin | Components | Hooks | Decision |
|---|---|---|---|
| **Oh-My-ClaudeCode** | 28 agents + 32 skills = 60 | none | Removed — declared for weeks, never installed, and would have outweighed suite-kit's 4 skills roughly 15 to 1 |
| **superpowers** | ~14 skills, 0 agents | none | Adopted — a quarter of OMC's footprint, covers TDD/debugging/planning workflows without agents |
| **context7** | 0 skills, 1 MCP server | none | Evaluated, not enabled repo-wide — near-zero listing cost, a good candidate, but its Upstash calls need a Custom network allowlist entry in cloud environments since the host isn't on the Trusted default list. Add it per-repo (or per-session) once that's in place, rather than declaring it unused. |
| **claude-mem** | memory system | `Setup`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PreToolUse` (matcher `Read`), `Stop` | **Declined** — its `PreToolUse`/`Read` binding collides with Konnekt's `graphify hook-guard` on the identical event and matcher, exactly the stacking suite-kit avoids by shipping no hooks at all (`README.md` § suite-kit). It also starts a persistent background worker at session start. |

Before adding another plugin here, check its component count and hook footprint
against this table, not just what it claims to do.

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
`suite-kit@kollektiv` from the local marketplace plus `superpowers@superpowers`
— see **Plugin selection** above — while omitting `kollektiv` from
`extraKnownMarketplaces` since this repo already is that marketplace and
declaring it as a remote `github` source would register it twice. `context7` is
evaluated favorably in that table but not enabled here yet, pending the cloud
network allowlist entry its MCP server needs. It has no `tokens`, `minecraft`,
`health.invariants`, or
`health.generated` block: it authors [`design/tokens.json`](../design/tokens.json)
as raw data rather than styled application code, so the `tokens.role`/`enforce`
machinery that guards literal hex and px in product code doesn't apply to it; it
emits no Minecraft commands and generates nothing, so nothing was invented to
fill those two slots either.

The Linear workspace backing all three repos was recreated from scratch on
2026-08-04 as `Kollektiv-MC` (team `KOL`), replacing the old `KonnektMC`
workspace, which is abandoned rather than migrated. Old `KON-*` references in
Konnekt's merged PRs and `agent_docs/LINEAR.md` now point at nothing, since the
new workspace renumbers `KON` from 1.

### Kommands — not adopted, and blocked on a real decision

The previous revision of this note (inherited from an earlier PR, never verified
against the actual repo) claimed `.claude/settings.json`, `.claude/suite.json`,
`tokens.source.json`, and the `.gitignore` lines were all in place, with only the
Linear `KMD` switch pending. **None of that was true except the last part.**
Checked directly against the repo: no `.claude/suite.json` exists at all;
`.claude/settings.json` exists but declares only `permissions`, no
`extraKnownMarketplaces`/`enabledPlugins` — suite-kit was never actually declared
here. `tokens.source.json` didn't exist until this session ran
`scripts/sync-tokens.sh` against it directly.

More than a missing file, this is a real conflict, not just an outstanding step.
Kommands' own `CLAUDE.md` states plainly: *"Task tracking is **GitHub Issues**. Do
not add a `TODO.md`."* — and its `docs/roadmap.md` says the same:
*"Individual tasks live in GitHub Issues — this file does not track work items."*
That directly contradicts `suite.repos.json`'s `linearTeam: "KMD"` and every prior
claim on this page about a Kommands→Linear migration. `CLAUDE.md` also says:
*"If reality diverges from the documented design mid-task, stop and surface it
rather than improvising a workaround"* — so no `.claude/suite.json` with
`linear.team: "KMD"` was added here. Adding one would silently pick a side in a
decision that's actually still open: either Kommands migrates task tracking to
Linear for real (and its own `CLAUDE.md`/`docs/roadmap.md` get updated to say so),
or kollektiv's suite-wide Linear assumption gets corrected to exclude it, keeping
Kommands on GitHub Issues. `suite.repos.json`'s `linearTeam: "KMD"` reflects an
assumption, not a decision — resolve that first, then adopt for real.

What this session actually did: vendored `tokens.source.json` (a safe, additive
step — the pipeline it feeds is documented in `docs/design-tokens.md` regardless
of the Linear question, and the repo is pre-scaffold so there's no generator yet
to run against it). Nothing else was touched.

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

Neither `superpowers` nor `context7` ships hooks, so neither collides with
Konnekt's `graphify hook-guard`. That was the deciding factor against `claude-mem`
(see **Plugin selection** above) rather than something to observe after the fact.
