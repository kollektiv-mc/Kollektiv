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

`scripts/sync-workflows.sh` vendors the workflows every product runs identically,
CodeQL and Scorecard, into `.github/workflows/`, and `scripts/sync-priority.sh`
vendors the priority dropdown into every issue form together with the workflow
that reads it, checking the two against each other and against
`design/labels.json` before it copies anything. Both run in CI's `token-drift`
job with `--check`. They exist because Kommands' copy of the priority workflow
said in its header that it was vendored from here by a script that did not
exist, and Konnekt had never received it.

Still open, in rough order:

- Turning on `--require-vendored` for `scripts/sync-workflows.sh` and
  `scripts/sync-priority.sh` in CI, once both products carry the files on their
  default branches.
- Turning on `scripts/sync-runner.sh --check --require-vendored` in CI. Both
  products carry the runner in a working tree here, but the flag can only go on
  once those commits are on their default branches — CI clones from there.
- A CI job in Kommands that runs its vendored runner. Every check it declares
  reports as skipped until `src/` and `package.json` exist, so the job would
  verify nothing yet; it lands with the scaffolding.
- Kommands turning on `--require-runnable` once `src/` exists. Until then its
  entire check set reports as skipped, which is honest but verifies nothing.
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

Still open on the sweep:

- Granting its Routine the GitHub connector from the claude.ai Routines UI. It
  was created over MCP, which cannot attach connectors for this organization, so
  its sessions have no issue-filing tools yet — the sweep will report filing as
  blocked and put its findings in the run report instead.
- Confirming it runs on Opus 5. A Routine's model cannot be set or read over MCP
  (`model_update_disabled`), so it inherits whatever the account default is.
- Confirming a second consecutive run opens zero new issues. Dedup via the
  `Health-Check-Key:` line is the whole design, and only a real second run
  proves it.

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
  It is missing `area:release`, `area:agents`, `p0` to `p3`, `health-check` and
  `changelog:skip`, and its `area:tokens` carries GitHub's default `ededed` and an
  empty description, which is what applying a label by hand creates. No Kommands
  issue has ever carried a priority, so the suite's own rule that a repo does not
  invent its own priority scale is currently unenforced there rather than followed.
- Deciding whether `suite.repos.json` and `design/suite.schema.json` should describe
  Kommands as something other than `"kind": "vite-web"` once it also ships a Wails
  binary. Konnekt is `wails-desktop` and Kommands would be genuinely both, which the
  single-`kind` field cannot express.

## superpowers adoption

OMC (Oh-My-ClaudeCode) is dropped suite-wide, along with its `.omc-workspace`
multi-repo session sharing. `superpowers` (`obra/superpowers`) is the one
third-party plugin declared alongside `suite-kit` in all three repos.

Still open: recording every machine and cloud path `superpowers@superpowers`
has actually been installed on, and observing a session of its agents against
Konnekt's `graphify hook-guard` before relying on it there beyond what
`.claude/settings.json` already declares.

## Workspace validation

Still open: cloning Konnekt and Kommands via `scripts/bootstrap.sh` and
confirming the sibling layout works standalone, with nothing depending on
OMC's workspace feature.
