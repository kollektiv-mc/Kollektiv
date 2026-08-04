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
| `tracking` | Where work items live. `github-issues` for every repo in this suite — `/suite-kit:issue-sync` stops rather than guessing if it is absent |
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
`.claude/suite.json` has `tracking: "github-issues"` and
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

### Task tracking, suite-wide

Every repo tracks work in **its own GitHub Issues**, declared as
`tracking: "github-issues"`. Roadmaps hold direction; issues hold work items;
`/suite-kit:issue-sync` reconciles the two on the `Source: <roadmap> § <section>`
line.

Linear (workspace `Kollektiv-MC`) is a **downstream mirror**, written only by the
GitHub → Linear sync routine. No repo and no skill writes to Linear directly —
two writers on the same records is the failure this arrangement avoids. That is
why `suite.repos.json` carries no per-repo Linear team keys.

This replaced an earlier Linear-primary arrangement. Old `KON-*` references in
Konnekt's merged PRs point at issues in a workspace (`KonnektMC`) that was
abandoned rather than migrated; treat them as dead links, not as issue numbers to
chase.

### Kommands

Adopted. `.claude/suite.json`, the settings block, and `tokens.source.json` are all
in place — verified against the repo, not inherited from a previous revision of
this page.

An earlier revision claimed all of that was already done while only the Linear
`KMD` switch was pending. **None of it was true.** There was no `.claude/suite.json`
at all, so every suite-kit skill stopped at its first step; `.claude/settings.json`
declared only `permissions`, so suite-kit was never actually enabled here; and
`tokens.source.json` did not exist until `scripts/sync-tokens.sh` was run against
the repo. The Linear question turned out to be the real blocker underneath: Kommands'
own `CLAUDE.md` had always said *"Task tracking is **GitHub Issues**"*, which the
suite-wide Linear assumption contradicted. That is now resolved suite-wide in
Kommands' favour — see **Task tracking, suite-wide** above.

`health.commands` is present but every entry is currently unrunnable — the repo is
pre-scaffold, with `docs/` and `.claude/` and no `package.json`. That is expected,
and `/suite-kit:health` reports an unrunnable check as `skipped` with a reason
rather than as passing. `tokens.generate` names `pnpm gen:tokens`, which likewise
does not exist yet; `docs/design-tokens.md` specifies its contract for whoever
scaffolds the app.

`health.invariants` carries the three greps that used to live in a local
`.claude/commands/health-check.md`: no hardcoded game values, no version-number
comparisons, no literal hex or px. That command was deleted — the checks now live
in `suite.json` where the plugin can read them, and every doc reference moved from
`/health-check` to `/suite-kit:health`.

`.claude/rules/*.md` stay where they are. They are path-scoped and auto-inject when
a matching file is edited — a plugin skill does not do that, so the plugin does not
replace them. Only `styling.md` overlaps `/suite-kit:design-tokens`, and the
overlap is deliberate: the rule fires on edit, the skill on request.

### Konnekt

`.claude/suite.json` uses `kind: "wails-desktop"`, `tracking: "github-issues"`,
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

`agent_docs/LINEAR.md` and `.claude/commands/linear-sync.md` were **deleted**. The
command hardcoded `list_issues team=KonnektMC` — a workspace that no longer exists,
so it failed outright rather than degrading — and the doc described two initiatives
and five projects in that same dead workspace. The reusable parts (the `Source:`
mapping rule, the PR-keyword convention) now live once in
`plugins/suite-kit/skills/issue-sync/SKILL.md`, and Konnekt's task-tracking
convention is declared in `agent_docs/CLAUDE.md` like Kommands'. Nothing referenced
either file, so removing them left no dangling links.

Neither `superpowers` nor `context7` ships hooks, so neither collides with
Konnekt's `graphify hook-guard`. That was the deciding factor against `claude-mem`
(see **Plugin selection** above) rather than something to observe after the fact.
