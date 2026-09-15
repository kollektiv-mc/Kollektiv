# Roadmap

Direction and sequencing. Individual tasks live in
[GitHub Issues](https://github.com/kollektiv-mc/Kollektiv/issues) — this file
does not track work items, and there is no `TODO.md`.

`/suite-kit:suite-sync` mirrors GitHub Issues across this repo, Konnekt, and
Kommands into Linear. The Linear structure itself — teams, projects,
milestones, labels — is documented in `docs/linear.md`, not here.

---

## Linear substrate

The workspace is live: team `Kollektiv` (renamed from `Kollektiv-MC`) and team
`Apps`, both provisioned by hand in the Linear UI (teams have no create API).
The `Kollektiv Suite` initiative groups every project across both teams.

There is no `KON` or `KMD` team — the suite settled on two teams total, with
per-app separation handled by Linear projects (one per app, under team `Apps`)
and a `repo:*` label rather than a third team. See `docs/linear.md`.

## Enforcement

CI here checks script syntax, manifest and schema validity, suite-kit version
match, suite participation, and vendored-token drift (`scripts/sync-tokens.sh
--check`, run on a schedule since drift detection needs every product cloned
beside this one).

Konnekt's `gen:tokens` clean-diff check now runs in its own CI
(`.github/workflows/ci.yml`), not just `/suite-kit:health`.

`plugins/suite-kit/suite-check.py` runs everything a repo's `.claude/suite.json`
declares, without the plugin installed, and `scripts/sync-runner.sh` vendors it
into each product the way `sync-tokens.sh` vendors the token source. This exists
because declaring a plugin does not install one: in a cloud container
`installed_plugins.json` is empty, so before this the manifest was read by
nothing there. The runner also distinguishes a skip from a pass, which the
invariant greps previously could not — a grep over a path that does not exist
reported clean.

Both products now carry `.claude/suite-check.py`, and Konnekt's CI runs it as an
`invariants` job over the `invariants` and `generated` sections. Not `commands`:
Konnekt's backend legs run on windows-latest and in a webkit2gtk container, and
`suite.json`'s flat command list cannot express that matrix, so CI keeps those as
literal steps. The two sections CI had no equivalent of are the ones the runner
now covers — before this, Konnekt's `no literal border widths` invariant was
checked only when someone invoked `/suite-kit:health` by hand.

`scripts/check-participation.sh` checks what the other scripts do not: the
`docs/conventions.md` permissions floor in each repo's committed
`.claude/settings.json`, and that the paths each manifest names — `roadmap`,
`tokens.sourceFile`, every `health.commands[].cwd` — still exist. It runs in this
repo's `.claude/suite.json` and in CI with `--require-products`.

The cross-repo checks are one workflow, `.github/workflows/drift.yml`, on every
push and nightly: token, runner, aislop-policy, shared-workflow, priority and
release-notes drift, product manifest validation and participation. The runner
and release-notes checks run with `--require-vendored`; the aislop, workflow and
priority checks do not, until both products carry every file on their default
branches.

Everything shared is a file a product vendors and this repo's gate holds clean:
the workflows that are the same job everywhere, the aislop gate, CodeQL, the
pull-request label gate and Scorecard, in `plugins/suite-kit/workflows/`
(`scripts/sync-workflows.sh`); `.aislop/base.yml` (`scripts/sync-aislop.sh`); the
issue-priority workflow and the question its forms ask, rendered from
`design/labels.json` (`scripts/sync-priority.sh`); and the release-notes
generator with its tests and GitHub's fallback layout (`scripts/sync-notes.sh`).
Nothing is shared by reference: a `uses:` line pointing at this repo's `main`
would be an unpinned dependency in every product's CI, which the products'
Scorecard runs would themselves flag. `check-participation.sh` checks that every
vendored file is excluded from the product's own formatter and scanner, which is
the rule the Sep 2026 drift (Konnekt's gate reformatting its vendored generator)
was an instance of.

Still open, in rough order:

- Turning on `--require-vendored` for `scripts/sync-workflows.sh`,
  `scripts/sync-aislop.sh` and `scripts/sync-priority.sh` in `drift.yml`, once
  both products carry the files on their default branches.
- A release workflow for Kommands. It carries the generator, its
  `.github/changelog.json` and the fallback layout, and tests the generator on
  every push, but nothing there cuts a tag or calls it yet.
- Returning this repo's `quality.maxNesting` to the base's 5. It is held at 7 by
  `run_invariants` in `suite-check.py`, which #23 already needs to touch.
- Widening Konnekt's literals invariant past borders. It declares
  `tokens.enforce: "migrating"` and names the covered paths, and the
  `no literal border widths` entry closed the border sweep — 0 literals against
  181 token call sites. Hex and arbitrary px are still open: 118 hex literals and
  183 px values across 48 files under the paths its manifest names. A single
  broad pattern would be red on arrival, so this wants either per-sweep entries
  or `migrating` finally meaning something to the runner, which does not yet
  distinguish it from `strict`.
- Wiring the runner into `/suite-kit:health-sweep`. That skill clones every
  product and checks token drift; it should check runner drift the same way, and
  read each product's `.claude/suite-check.py --json` rather than its prose
  report.

Closed since this section was last written: Konnekt PR #51 merged (`ef49aa7`), so
its manifest declares `tracking: "github-issues"` on `main` and
`/suite-kit:suite-sync` no longer skips the repo. Konnekt gained a
`health.invariants` entry. The permissions block is enforced by
`check-participation.sh` rather than by review.

## Scheduled runs

Two cloud Routines exist and are enabled, both created over MCP against this
repo: the daily `/suite-kit:suite-sync` mirror (`30 6 * * *` UTC) and the weekly
`/suite-kit:health-sweep` (`0 7 * * 1` UTC). `README.md` describes what each does.

Settled since, by reading the runs rather than predicting them:

- **The sweep files issues.** An earlier revision of this section said its
  sessions had no issue-filing tools and that filing would report as blocked.
  That was wrong: #11, #23 and #24 were all opened by the sweep, each carrying
  its `Health-Check-Key:` line and the `health-check` label.
- **Dedup works.** The 2026-09-14 run opened nothing and commented on #23, as
  did 2026-09-07 before it. Two consecutive runs matching on the key line
  instead of filing twins is the proof this section was waiting for.
- **The `health-check` label exists in all three repos**, created by the sweep
  itself rather than by `sync-labels.sh`, which has still never been applied to
  Kommands (see below).
- **The Routine's model is settable over MCP**, contrary to an earlier note here
  that recorded `model_update_disabled` and had the sweep inheriting the account
  default. `update_trigger` takes a `model`; the sweep is pinned to
  `claude-opus-5` as of 2026-09-15. Opus is the assessor, and the skill's step 0b
  holds the rule that its Sonnet subagents fetch rather than judge.
- **The sweep is model-invocable again.** It carried
  `disable-model-invocation: true`, which removes a skill from the model's
  listing outright, so a scheduled run could never invoke it and read the file as
  prose instead. Verified with a two-skill probe plugin under `claude -p`: the
  gated skill is not listed at all, the ungated one invokes headlessly. The gate
  is gone and an explicit scope guard at the top of the skill replaces it.

Still open on the sweep:

- Watching the first run after 2026-09-15 actually install both plugins and
  complete the deep review. Until that run, `superpowers` had never once loaded
  (see below), so step 4 was skipped every week and every finding to date came
  from a declared check rather than from review.
- Seeding the run log. `Health-Sweep-Log: kollektiv` is a standing issue the
  sweep opens on its first run under the new skill; until then, nothing records
  a clean week.

Routine cron is evaluated in UTC and does not follow DST, so both schedules need
shifting by an hour twice a year, or moving off UTC — a schedule set for 09:00
Berlin fires at 08:00 Berlin from late October to late March.

## Version timeline

`/suite-kit:suite-sync` step 4 places completed work on a timeline by the version
it shipped in — one Linear project milestone per git tag, dated to the tag, sorted
into Snapshot / Alpha / Beta / Release by the tag's suffix. `docs/linear.md`
§ Version timeline is the structure; the milestones for Konnekt's five tags exist
in Linear, and Konnekt's roadmap `Alpha` milestone is marked superseded.

Linear's own Releases feature would have been the obvious home and is not
available on the free plan — see `docs/conventions.md` § Known Linear MCP gaps.

Still open:

- Attaching completed issues to their version milestone. The milestones are dated
  and empty; nothing is on the timeline until a sync run with GitHub access to
  Konnekt and Kommands reads each issue's `closed_at` and files it. The first
  scheduled run does this.
- The daily Routine's inline prompt still summarises the old behaviour. It
  delegates to this skill and the skill is the specification, so runs pick up
  step 4 regardless, but the summary is stale. It cannot be edited over MCP —
  the Routine fires into a persistent session, and `update_trigger` refuses a
  prompt edit for one. Fix it in the claude.ai Routines UI, or recreate it.
- Retiring Konnekt's `Alpha` milestone in the Linear UI. It holds nothing and is
  marked superseded; there is no deletion tool.
- A timeline for kollektiv and Kommands. Neither repo has a single tag, so both
  correctly report no version timeline. This is a fact about the repos, not a gap
  in the skill, and it resolves when they start tagging.

## Suite conventions

The reusable parts of Konnekt's old `agent_docs/LINEAR.md` — the PR
magic-word convention and, historically, the roadmap-section mapping rule —
were hoisted into `docs/conventions.md`, and `CLAUDE.md` was added here so
these conventions reach an agent session automatically. The per-repo
`linear-sync` and `health-check` commands the plugin replaced have been
deleted from both products.

`scripts/adopt.sh` scaffolds a new repo's `.claude/suite.json`, permissions block,
`.gitignore` lines and both vendored files in one command, instead of a careful
read of `docs/adopting.md`. It writes a manifest that is valid but deliberately
unfinished — `tokens`, `minecraft` and `health.invariants` describe a specific
codebase, and a generated guess at them would look reviewed without being.

## Cross-product handoff

Konnekt and Kommands have a link between them: a command saved in Kommands can be
linked, one at a time, into Konnekt's Commands tile, and stays bound to its Kommands
original so an edit there propagates. Tracked in
[`konnekt#213`](https://github.com/kollektiv-mc/Konnekt/issues/213), with the
blocking work filed and landed in Kommands. On disk today: Kommands' standalone
shell writes `saved-commands.json` from the commands the user linked (its
`shell/store`), and Konnekt's `backend/services/kommands.go` reads it and keeps a
button per entry the user adds. Saved and linked are two acts on purpose: a saved
command is organized in Kommands and never leaves it until it is linked; linking
makes it visible to Konnekt, and adding it as a button there is a third act, taken
in Konnekt. The one-shot `konnekt://` handoff (Phases 1 and 2 of that issue) is not
built.

Most of it is product work and belongs in the products. Two decisions taken while
scoping it are this repo's, because they are cross-repo by construction and neither
product can hold them alone.

**The shared path.** Kommands writes its saved commands to
`os.UserConfigDir()/kommands/saved-commands.json` and Konnekt only ever reads them.
That read-only posture on Konnekt's side is what makes divergence structurally
impossible rather than merely unlikely, and it is why the canonical copy sits with
the writer instead of in a neutral suite directory. Both apps resolve the path from
the same Go stdlib call, so neither discovers the other: Konnekt's own data directory
is already `os.UserConfigDir()/konnekt` (`backend/services/datadir.go`). The file
format and its version field become a cross-repo compatibility surface the first time
Konnekt reads one.

**The shell choice that makes the above free.** Kommands gains a standalone desktop
build on Wails v2, matching Konnekt's major rather than starting on v3. Tauri and
Electron were both assessed and declined, Tauri for adding Rust as a third language
in a two-language suite and Electron for a bundled-Chromium argument Konnekt's worlds
tile already disproves. v3 was declined for this app because the scheme handler and
`SingleInstanceLock` are a different API there, so two majors would mean writing the
suite's one genuinely shareable piece of Go twice, and because v3's GTK4 default
drops the Ubuntu 22.04 and Debian 12 that Konnekt's README promises. The full
reasoning is on `konnekt#213`.

Still open here:

- Writing the path and file format into `docs/conventions.md`, once they exist. They
  are a cross-repo contract, which is this repo's to hold, but nothing is on disk to
  describe yet and a conventions entry written ahead of the code would be this repo
  being wrong about itself again.
- Running `scripts/sync-labels.sh` against Kommands, which has never had it applied.
  It is missing `area:release`, `area:agents`, `p0` to `p3` and `changelog:skip`,
  and its `area:tokens` carries GitHub's default `ededed` and an empty
  description, which is what applying a label by hand creates. (`health-check`
  was on this list until 2026-09-15; it exists in all three repos, created by
  the sweep itself as its skill instructs.) No Kommands
  issue has ever carried a priority, so the suite's own rule that a repo does not
  invent its own priority scale is currently unenforced there rather than followed.

## superpowers adoption

OMC (Oh-My-ClaudeCode) is dropped suite-wide, along with its `.omc-workspace`
multi-repo session sharing. `superpowers` (`obra/superpowers`) is the one
third-party plugin declared alongside `suite-kit` in all three repos.

The install id is **`superpowers@superpowers-dev`**. The marketplace at
`obra/superpowers` names itself `superpowers-dev`, and the manifest's name beats
the key in `extraKnownMarketplaces`. All three repos declared it as
`superpowers` from adoption until 2026-09-15, and `/suite-kit:health-sweep`
told its sessions to install `superpowers@superpowers`, so the plugin had never
loaded anywhere: the failure reads `Plugin "superpowers" not found in
marketplace "superpowers"`, which looks like upstream dropped it. Verified by
installing both spellings in a cloud session on 2026-09-15; only the
`-dev` one resolves.

Still open: observing a session of its agents against Konnekt's
`graphify hook-guard` before relying on it there beyond what
`.claude/settings.json` already declares.

## Workspace validation

Still open: cloning Konnekt and Kommands via `scripts/bootstrap.sh` and
confirming the sibling layout works standalone, with nothing depending on
OMC's workspace feature.
