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
├── .omc-workspace              marks the tree as one Oh-My-ClaudeCode workspace
├── suite.repos.json            the product manifest
├── CLAUDE.md                   what an agent landing here needs to know
├── scripts/bootstrap.sh        clones missing products
├── scripts/sync-tokens.sh      vendors design/tokens.json into each product
│                               (--check reports drift and writes nothing)
├── scripts/validate-schemas.sh validates every manifest against its schema
├── .github/workflows/ci.yml    hub checks + scheduled token-drift detection
├── .claude-plugin/             marketplace manifest
├── design/tokens.json          the shared design-token source
├── design/tokens.schema.json   its schema
├── design/suite.schema.json    schema for each repo's .claude/suite.json
├── plugins/suite-kit/          the shared plugin
├── .claude/                    this repo's own suite-kit + OMC adoption
├── docs/adopting.md            how a repo adopts suite-kit
├── docs/conventions.md         cross-repo rules: tracking, PRs, permissions
├── docs/roadmap.md             this repo's own roadmap, reconciled via linear-sync
├── Konnekt/                    cloned, untracked
└── Kommands/                   cloned, untracked
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

## Oh-My-ClaudeCode

[OMC](https://ohmyclaudecode.com/) is declared alongside suite-kit for multi-agent
orchestration. Two limits are worth knowing before depending on it:

- **`/team` is local-only.** It spawns workers through tmux, with optional external
  provider CLIs for cross-model work. Claude Code on the web has neither, so cloud
  sessions get OMC's skills and agents but not team mode. Named stage profiles
  additionally want Linux `flock`.
- **Context is not free.** OMC contributes a large number of agents and skills,
  paid on every turn in every session. Check the **Context cost** figure in the
  `/plugin` detail view before leaving it enabled repo-wide rather than reaching
  for it per-session.

Its `.omc-workspace` support is the part that fits this repo best: a token change
in Konnekt that must land in Kommands becomes one session instead of two.

---

## Tracking

Tracking is a **per-repo choice**, and suite-kit does not require a single tracker.
See [`docs/conventions.md`](docs/conventions.md).

| Repo | Tracked in |
|---|---|
| Kollektiv | Linear, team `KOL` |
| Konnekt | Linear, team `KON` — *key declared, team not yet provisioned* |
| Kommands | GitHub Issues |

**What exists in Linear today:** one workspace, `Kollektiv-MC`, holding one team
(`KOL`) and one project (`Workspace & Tooling`). There are no other teams and no
initiatives. Creating the `KON` team and a suite-wide initiative are open items in
[`docs/roadmap.md`](docs/roadmap.md) — declaring a team key in a manifest and
provisioning the team are different steps, and only the first is done.

This repo adopts its own plugin: `.claude/suite.json` points `linear.team` at `KOL`
and `roadmap` at `docs/roadmap.md`, so `/suite-kit:linear-sync` reconciles this repo
the same way it does Konnekt.

Linear's MCP exposes no `create_team` or `create_initiative`; both are hand-made in
the Linear UI. Projects are then attached to an initiative that already exists via
`save_project(addInitiatives: [...])`.

The workspace was recreated from scratch on 2026-08-04 (previously `KonnektMC`); old
`KON-*` issue references in Konnekt's merged PRs point at IDs that no longer exist,
since the new workspace renumbers from `KON-1`.
