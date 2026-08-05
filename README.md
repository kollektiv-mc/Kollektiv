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
and each of those was written down twice. Kommands' `docs/design-tokens.md`
restated Konnekt's entire palette by hand. That palette now lives in
[`design/tokens.json`](design/tokens.json); Kommands stops restating it and
generates from the vendored copy when its adoption lands, on
`kommands@claude/adopt-suite-kit`. Both repos carry their own health-check prose.
Both are exposed to the same failure mode:
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
├── design/labels.json          the shared GitHub/Linear label taxonomy
├── design/labels.schema.json   its schema
├── design/suite.schema.json    schema for each repo's .claude/suite.json
├── scripts/sync-labels.sh      applies design/labels.json's GitHub side via gh
│                               (--check reports drift and writes nothing)
├── plugins/suite-kit/          the shared plugin
├── .claude/                    this repo's own suite-kit + superpowers adoption
├── docs/adopting.md            how a repo adopts suite-kit
├── docs/conventions.md         cross-repo rules: tracking, PRs, permissions
├── docs/linear.md              the Linear structure /suite-kit:suite-sync mirrors into
├── docs/roadmap.md             this repo's own roadmap — direction, not work items
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
| `/suite-kit:health-sweep` | Run those checks across every repo and file findings as issues |
| `/suite-kit:mc-syntax` | Verify Minecraft syntax against pinned data before writing it |
| `/suite-kit:design-tokens` | The no-literal-hex, no-literal-px rule |
| `/suite-kit:suite-sync` | Mirror each repo's GitHub Issues into Linear |
| `@mc-reviewer` | Review a diff for version-trait and hardcoded-value violations |

The skills are generic. Everything product-specific — the actual commands, the
actual grep invariants, where the repo is tracked — lives in that product's
`.claude/suite.json`, next to the code it constrains. See
[`docs/adopting.md`](docs/adopting.md).

Deliberately **no hooks**. Konnekt already binds `graphify hook-guard` to
`PreToolUse` on `Bash`, `Read`, and `Glob`; stacking more matchers on top is the
fastest way to make both feel broken.

## superpowers

[`obra/superpowers`](https://github.com/obra/superpowers) is declared alongside
suite-kit in every repo in the suite. It replaces Oh-My-ClaudeCode, which this repo
no longer uses or documents — OMC's workspace-sharing feature (`.omc-workspace`) is
gone along with it; the sibling-clone layout `bootstrap.sh` produces stands on its
own and never depended on it.

Declaring a marketplace runs third-party code with your privileges — that is a trust
decision made per repo, same as any `extraKnownMarketplaces` entry.

---

## Tracking

**GitHub Issues is the one source of truth for work items across the suite** —
every repo declares `tracking: "github-issues"`. Linear is a downstream
mirror, kept current by `/suite-kit:suite-sync` on a schedule. See
[`docs/conventions.md`](docs/conventions.md) and
[`docs/linear.md`](docs/linear.md) for the full model: teams, projects,
milestones, and the label taxonomy shared by both sides.

The Linear workspace (`Kollektiv-MC`, since renamed `Kollektiv`) holds two
teams — `Kollektiv` and `Apps` — under one `Kollektiv Suite` initiative.
Linear's MCP exposes no `create_team`; teams are hand-made in the Linear UI.

The workspace was recreated from scratch on 2026-08-04 (previously
`KonnektMC`); old `KON-*` issue references in Konnekt's merged PRs point at
IDs that no longer exist in the replacement workspace.

## Scheduled runs

Two cloud Routines drive the suite on a schedule, both created over MCP against
this repo:

| Routine | Cron (UTC) | What it does |
|---|---|---|
| Suite sync — GitHub → Linear | `30 6 * * *` | Runs `/suite-kit:suite-sync` |
| Weekly suite health check | `0 7 * * 1` | Runs `/suite-kit:health-sweep` |

The sweep clones every repo in `suite.repos.json`, runs each one's
`/suite-kit:health`, checks vendored-token drift, reviews the week's commits, and
files findings as GitHub issues labelled `health-check` in the repo they belong
to. It never commits, pushes, or opens pull requests. Its issues carry a
`Health-Check-Key:` line so the next week's run comments on an open issue rather
than filing a duplicate.

Routine cron is evaluated in UTC and does not follow DST, so these drift by an
hour in local terms twice a year — see [`docs/roadmap.md`](docs/roadmap.md).
