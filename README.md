# kollektiv

The umbrella for a small suite of Minecraft tools:

| Product | What it is | Stack |
|---|---|---|
| [Konnekt](https://github.com/kollektiv-mc/Konnekt) | Desktop dashboard for Minecraft servers | Wails v2 · Go · React 19 |
| [Kommands](https://github.com/kollektiv-mc/Kommands) | Command generator for Java Edition | Vite · React 19 |

This repo owns **conventions, domain knowledge, and agent tooling**. It does not
own builds, CI, or releases — each product keeps its own.

---

## Why this exists

The two products share a design language, a domain, and a set of working rules,
and until now each of those was written down twice. Kommands' `docs/design-tokens.md`
restated Konnekt's entire palette by hand — that palette now lives in
[`design/tokens.json`](design/tokens.json) and each product generates from it. Both
repos carry their own health-check prose. Both are exposed to the same failure mode:
Minecraft syntax changes between versions in ways that produce commands which look
correct and silently do nothing, and model training data on that syntax is
frequently stale.

Written twice, those rules drift. Held here as a plugin, they do not.

A monorepo would be the wrong shape. Konnekt is a Go module with generated Wails
bindings, a gzip bundle budget, and a `v*` tag-driven release that publishes
binaries and an `.rpm`; Kommands derives its data from pinned mcmeta tags. Merging
them buys nothing and breaks a working release pipeline.

---

## Layout

This repo is the **workspace root**. The products are cloned as siblings beneath
it and are not tracked here.

```
kollektiv/
├── suite.repos.json        the product manifest
├── scripts/bootstrap.sh    clones missing products
├── scripts/sync-tokens.sh  vendors design/tokens.json into each product
├── .claude-plugin/         marketplace manifest
├── design/                 the shared design-token source
├── plugins/suite-kit/      the shared plugin
├── .claude/                this repo's own plugin adoption
├── docs/roadmap.md         this repo's own roadmap, reconciled via linear-sync
├── Konnekt/                cloned, untracked
└── Kommands/               cloned, untracked
```

## Getting started

```sh
git clone https://github.com/kollektiv-mc/Kollektiv
cd Kollektiv
./scripts/bootstrap.sh
./scripts/sync-tokens.sh
```

Both scripts are idempotent and never delete: a product directory that already
contains a working clone is left alone, and a vendored token file that already
matches the source is not rewritten.

---

## Design tokens

`design/tokens.json` is the suite's single source of truth for design values —
tech-neutral JSON, semantic name to value, no CSS syntax baked in. Both products
are **consumers**: `sync-tokens.sh` vendors the file into each clone as
`tokens.source.json`, and each product's own generator transforms it into whatever
its stack needs.

Nothing both produces and consumes the token set, which is what makes regenerating
safe. See [`design/README.md`](design/README.md).

---

## suite-kit

A Claude Code plugin, published from this repo's own marketplace, carrying the
rules both products share.

| Skill | Purpose |
|---|---|
| `/suite-kit:health` | Run a product's checks and invariants, report a table |
| `/suite-kit:mc-syntax` | Verify Minecraft syntax against pinned data before writing it |
| `/suite-kit:design-tokens` | The no-literal-hex, no-literal-px rule |
| `/suite-kit:linear-sync` | Reconcile a roadmap against Linear |
| `@mc-reviewer` | Review a diff for version-trait and hardcoded-value violations |

The skills are generic. Everything product-specific — the actual commands, the
actual grep invariants, the Linear team key — lives in that product's
`.claude/suite.json`, next to the code it constrains. See
[`docs/adopting.md`](docs/adopting.md).

Deliberately **no hooks**. Konnekt already binds `graphify hook-guard` to
`PreToolUse` on `Bash`, `Read`, and `Glob`; stacking more matchers on top is the
fastest way to make both feel broken.

## Other plugins

Declared alongside suite-kit in `.claude/settings.json`:

| Plugin | What it adds | Cost |
|---|---|---|
| [`superpowers`](https://github.com/obra/superpowers) | ~14 skills: TDD, systematic debugging, planning and review workflows | No hooks, no agents |

Replaces **Oh-My-ClaudeCode**, removed after it turned out to be declared but
never installed: 28 agents and 32 skills — 60 components competing for a skill
listing budgeted at roughly 1% of the context window, against suite-kit's 4. Before
adding another plugin here, check its component count and hook footprint against
that budget, not just what it does.

Two others were evaluated and are **not** currently enabled repo-wide:

- [`context7`](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/context7)
  — version-specific library docs, one MCP server, negligible listing cost. A good
  candidate; its Upstash calls aren't on Claude Code cloud's Trusted network
  allowlist by default, so it needs a Custom policy entry for cloud sessions that
  want it. Left off `enabledPlugins` for now rather than declared-but-unused.
- `claude-mem` (persistent cross-session memory) was considered and **declined**:
  its `hooks.json` binds `PreToolUse` on `Read`, colliding with Konnekt's
  `graphify hook-guard` on the same event and matcher — precisely the stacking
  this repo's suite-kit avoids by shipping no hooks of its own (see below).

See [`docs/adopting.md`](docs/adopting.md) for the full comparison.

---

## Tracking

Linear, workspace `Kollektiv-MC`. Three teams: `KOL` for this repo — suite
conventions, suite-kit, plugin adoption — and one per product, `KON` and `KMD`, so
cycles and boards stay per-product. A suite-wide initiative, `Kollektiv Suite`,
spans all three.

This repo adopts its own plugin: `.claude/suite.json` points `linear.team` at
`KOL` and `roadmap` at [`docs/roadmap.md`](docs/roadmap.md), so
`/suite-kit:linear-sync` reconciles this repo the same way it does Konnekt and
Kommands.

Linear's MCP exposes no `create_team` or `create_initiative`; both are hand-made
in the Linear UI. Projects are then attached to an initiative that already
exists via `save_project(addInitiatives: [...])`.

The workspace was recreated from scratch on 2026-08-04 (previously
`KonnektMC`); old `KON-*` issue references in Konnekt's merged PRs and
`agent_docs/LINEAR.md` point at IDs that no longer exist, since the new
workspace renumbers from `KON-1`.
