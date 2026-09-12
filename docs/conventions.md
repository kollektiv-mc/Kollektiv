# Cross-repo conventions

Rules that apply across the suite. Anything specific to one repo — its GitHub
labels beyond the shared taxonomy, its Linear project's internal shape — stays
in that repo.

These were hoisted out of `Konnekt/agent_docs/LINEAR.md`, which held them as
though they were Konnekt's own. They are not; they describe how every repo
here is tracked and reviewed.

---

## GitHub Issues is the one source of truth

Every repo in the suite tracks its work items in GitHub Issues, declared as
`tracking: "github-issues"` in `.claude/suite.json`. There is no per-repo
choice to make anymore — Kommands set this precedent and kollektiv matches it.

Konnekt's manifest now says this too, since PR #51 merged (`ef49aa7`). It
previously declared `linear: { team: "KON" }` on `main`, naming a team key from
the workspace deleted 2026-08-04, and `/suite-kit:suite-sync` skipped the repo
for as long as that sat there. An earlier revision of this paragraph claimed
Konnekt already matched while it did not; it does now, and
`scripts/check-participation.sh` is what will notice if that stops being true.

`design/suite.schema.json` still allows a repo to declare `linear: { team:
... }` instead, for a hypothetical repo that should be tracked in Linear
directly rather than mirrored. Nothing in the suite uses it today. A repo
declaring neither is misconfigured — `/suite-kit:suite-sync` reports it and
stops rather than guessing.

Linear is a **downstream mirror**, kept current by `/suite-kit:suite-sync` on
a schedule. The full Linear structure — teams, projects, milestones, the
label taxonomy — is documented in `docs/linear.md`.

## Issue ↔ Linear mapping

Every Linear issue mirrored from GitHub carries this in its description:

```
Source: kollektiv-mc/<repo>#<number>
```

**Match on that line, never on titles.** Titles get edited on both sides and
drift apart; matching on them produces duplicates that then need untangling
by hand.

This replaced an earlier convention — `Source: <roadmap path> § <section>` —
from when roadmap files were the thing being reconciled against. Roadmap
files (`docs/roadmap.md`, `agent_docs/ROADMAP.md`) are direction and
sequencing now, not a checklist of trackable items; GitHub issue numbers are
a stable key in a way a roadmap section heading never was, since headings get
rewritten and sections get merged.

## Issues filed by the health sweep

`/suite-kit:health-sweep` runs weekly across every repo and files what it finds. Its
issues carry a stable fingerprint line in the body:

```
Health-Check-Key: <repo>/<check-id>
```

Same rule as above — **match on that line, never on titles.** The sweep re-runs every
week and re-finds the same problems; the key is what makes a second run comment on an
open issue instead of opening its twin.

`<check-id>` is derived from what the finding is, never from the week it was found.
Everything the sweep files is labelled `health-check`.

The sweep never closes an issue. A finding that stops reproducing gets a comment saying
so, because "it was fixed" and "the check stopped running" look identical from the
outside, and only one of them is good news.

## Priority

Every issue carries exactly one of `p0`-`p3`, defined in `design/labels.json` and
applied to every repo by `scripts/sync-labels.sh`:

| Label | Means |
| --- | --- |
| `p0` | Drop everything. |
| `p1` | High priority, next up. |
| `p2` | Medium priority, normal queue. |
| `p3` | Low priority, nice to have. |

An issue form asks the reporter for their honest read and offers three answers,
which the vendored `issue-priority.yml` workflow turns into a label when the
issue opens: *Blocking* is `p1`, *Significant* is `p2`, *Minor* is `p3`. `p0` is
never offered; it is a triage judgement, and triage may move any of the other
three. An issue opened through the API carries no form answer, so whoever files
it, usually an agent, applies the label in the same call; when none does, the
workflow says so in a comment rather than guessing. If the priority is genuinely
unclear, the answer is `p2`, never nothing: an issue without a priority mirrors
into Linear at priority None and drops out of every ordered view, which is not
the same as being low priority.

## PR magic words

GitHub's own closing keywords in a PR title or description close the issue
they reference on merge:

```
Fixes #12      Closes #9      Resolves #28
```

That's the primary mechanism now: it closes the GitHub issue, and the next
`/suite-kit:suite-sync` run carries that to Done in Linear. Linear's native
GitHub integration and its own magic words (`Fixes KOL-9`) still work if a PR
references a Linear ID directly, but that's a secondary path — the mirrored
issue's ID is not meant to be the one branch names and PRs are built around.

## Required permissions block

Every repo's committed `.claude/settings.json` carries this, merged into whatever else
it already has:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "ask": [
      "Bash(git push:*)"
    ],
    "allow": []
  }
}
```

`deny` and `ask` are the suite-wide floor and are not negotiable per repo. `allow` is
per-repo: put the read-only and routinely-safe commands of that stack in it — the
point is to cut permission prompts for things like `pnpm typecheck` and `git status`
without also waving through a push.

This matters most for unattended agents and scheduled routines, which have no one
watching to decline a prompt. A repo with no permissions block has no floor at all.

`scripts/check-participation.sh` checks this mechanically across every cloned repo,
and CI runs it with `--require-products`. It was enforced by review until then,
which is the weakest place to enforce a rule whose whole purpose is the sessions
nobody is watching.

**Merging, not replacing.** Konnekt's `.claude/settings.json` also carries a `hooks`
section binding `graphify hook-guard` to `PreToolUse`. Add the permissions block
alongside it. suite-kit ships no hooks specifically so it cannot collide with those.

## Required formatting settings

Every repo with a JavaScript or TypeScript toolchain sets these in its Prettier
config, wherever that config lives:

```json
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2
}
```

`trailingComma` and `tabWidth` match Prettier 3's own defaults and may be omitted;
the other three do not, and an omitted `semi` means semicolons. Anything else a
repo needs — plugins, overrides, ignore files — is per-repo and untouched.
Konnekt adds `prettier-plugin-tailwindcss`; nothing here objects.

These are checked by `scripts/check-participation.sh`, which compares **effective**
values: a key left out is read as Prettier's default for it, because that is what
Prettier will do. A repo with no Prettier config and no `package.json` is reported
as a skip rather than a failure — that is a pre-scaffold repo, not a
non-conforming one.

Why mechanical rather than documented: before this, the settings were stated in
Konnekt's `.prettierrc.json` and again, by hand, in Kommands' `CLAUDE.md` prose.
They agreed, and nothing would have said so if they stopped. One convention
written down twice is one convention waiting to fork.

## Release notes and pull request labelling

A merged pull request's title is public copy. It is what a person reading the
release notes sees, and it is the only thing they see about that change, so it
describes what changed in the product, not which files moved or which branch it
came off.

A product that has adopted this builds its notes with
`.github/scripts/release-notes.py`, vendored from
`plugins/suite-kit/release-notes.py` by `scripts/sync-notes.sh` for the reason
`sync-runner.sh` states about the check runner: a release job runs in the
product's own container, with this repo nowhere on disk and no plugin installed,
so the generator has to be *in* the product.

**Both products carry it.** The marker is a product's own
`.github/changelog.json`, holding the non-app path list the generator cannot run
without; `sync-notes.sh` vendors the generator, its tests and GitHub's fallback
layout (`.github/release.yml`) beside it, and the drift check runs with
`--require-vendored`. Konnekt's release workflow calls the generator when it cuts
a release; Kommands has no release workflow yet, so there the generator is
tested on every push and waits for its first tag.

**Every pull request carries exactly one `type:` label.** The label alone decides
where it lands, and CI fails a pull request without one: the check is
`.github/workflows/pr-labelled.yml` here, a reusable workflow each product calls.
Before that gate existed, 24 of the 41 pull requests in Konnekt's first release
window were unlabelled, the generator fell back to reading the title's leading
verb, and "Add a Full release roadmap section and a nightly snapshot build
channel" — a website and CI change — was published to users under **Features**.

| Label | Where it lands |
|---|---|
| `type:feature` | **Features** |
| `type:bug` | **Fixes** |
| `type:chore`, `type:docs` | counted in a footer line, not listed |
| `changelog:skip` | left out entirely, not counted |
| none | **Other changes**, and CI is red |

Two rules follow from that table and are worth stating outright:

- **The title is never read.** Not by its leading verb, not by a `feat:`
  prefix, not at all. The guess that used to run was first confined to where
  being wrong was cheap, and has now been removed outright: a verb says how
  someone phrased a sentence, not what the change was. An unlabelled pull
  request lands in "Other changes", which is where a failed gate stays visible
  instead of being dressed up as a category.
- **Maintenance is counted, not listed.** `type:chore` and `type:docs` are real
  work that changed nothing a user can observe. Listing them is how 17 entries
  of CI and tooling ended up in a changelog for people downloading a binary. The
  footer says how many there were, and the full-changelog link has them all.

**One pull request, one concern.** The notes list a merged pull request once,
under one heading, by its title, so a pull request carrying a feature *and* a
website pass *and* a CI tweak cannot be described honestly by any single line.
Split it, or accept that it will be filed as a chore.

### Which `type:` label

Since the label is the only input, it has to be decidable by whoever applies
one, at the moment they apply it. Ask these in order and stop at the first yes:

1. **Can a user of the product tell the difference?** If nothing they can see,
   run or click changed, it is `type:chore`, or `type:docs` when the change is
   documentation and nothing else. Refactors, tests, CI, tooling and dependency
   bumps stop here, however large the diff.
2. **Was the product already meant to do this, and not doing it?** Then it is
   `type:bug`. That covers anything the UI offers, the docs describe or the
   product plainly implies, including things that fail silently.
3. **Otherwise it is `type:feature`:** the product can now do something it
   never offered.

**The size of the diff is not the test**, and that is where this goes wrong in
both directions. A repair that needed a new file, a new bound method and a new
row of UI is still `type:bug`; a new surface built in service of a repair
belongs to the repair. Konnekt's #97 "Write a log file a bug reporter can
attach" was published under **Features** on exactly that reasoning, by a person
rather than by the generator: the app was already writing diagnostics, a
packaged build with no terminal was throwing them away, and the change is the
repair.

When the ladder feels ambiguous, revert the change in your head and ask what
the user loses. Something goes back to being broken is `type:bug`. They lose
something they never had is `type:feature`. They cannot tell is `type:chore`.
A change that is honestly half repair and half new capability is two pull
requests, which is the one-concern rule doing its job.

These four sentences are also the label descriptions in `design/labels.json`,
so the ladder is in the label picker and not only in this document.

### What's shared and what is not

**Shared**, in `plugins/suite-kit/release-notes.py`: the rules above. A person
reading Konnekt's notes and Kommands' notes should be reading the same document
in two voices.

**Per-repo**, in each product's `.github/changelog.json`: which of that
product's paths never reach what it ships. A pull request touching only those is
dropped and counted. Konnekt excludes `website/`, `agent_docs/`, `docs/`,
`.github/`, `.claude/`, `scripts/` and the root repo furniture; Kommands has a
different tree and will need a different list, which is exactly why this half is
not shared.

Two lessons from Konnekt's list are worth copying rather than rediscovering.
`README.md` belongs on it: a one-line banner edit beside an all-website diff was
enough to pull that pull request into the notes twice. `.github/` belongs on it
too, or the release tooling describes itself to users as an app change — the four
pull requests that built this very generator did exactly that. And `build/` does
*not* belong on it, because the app icon, `.desktop` file and RPM spec do ship.

Deliberately not in `.claude/suite.json`: `design/suite.schema.json` sets
`additionalProperties: false` and this repo's CI validates every product's
manifest nightly, so a key there is a change that has to land here first. A
separate file next to its one consumer needs no such coordination.

## What's shared vs. what stays per-repo

**Shared**, in `design/labels.json`: the `type:*`/`area:*`/`p0`–`p3`/`blocked`
label taxonomy, applied identically to every repo by `scripts/sync-labels.sh`.
A repo does not invent its own type or priority labels.

**Shared**, in `plugins/suite-kit/release-notes.py`: how a merged pull request
becomes a line in the release notes, vendored by `scripts/sync-notes.sh`. See
§ Release notes and pull request labelling above for the split between those
rules and each product's own `.github/changelog.json`.

**Shared**, in `plugins/suite-kit/workflows/`: the workflows that are the same
job on every product, the aislop gate, CodeQL, the pull-request label gate and
Scorecard, vendored by `scripts/sync-workflows.sh`. A job body lives here once,
so the aislop and ruff versions it pins change everywhere on the next sync;
nothing calls a workflow in this repo by reference.

**Shared**, in `.aislop/base.yml`: the aislop policy, vendored by
`scripts/sync-aislop.sh`. Per-repo: the size ratchet in each `.aislop/config.yml`,
held at that tree's largest function and file, and the `.aislopignore` naming
what that tree generates or vendors.

**Shared**, in `design/labels.json`'s `priorityForm`: the question every issue
form asks and the `p*` label each answer becomes, rendered into the forms and
into the vendored `.github/workflows/issue-priority.yml` by
`scripts/sync-priority.sh`. Per-repo: everything else in the forms. See
§ Priority above.

**A vendored file is never touched by a product's own tools.** Every sync script
byte-compares its master against the product's copy, so a product formatter or
scanner that rewrites one hands the nightly a drift only the next sync can undo.
The masters here are held to the same aislop gate the products run, so they
arrive clean, and `scripts/check-participation.sh` checks that each product's
`.aislopignore`, and its root `.prettierignore` where Prettier runs at the root,
list what it vendors.

**Per-repo:**

- Linear project and milestone structure — documented once, for every repo,
  in kollektiv's `docs/linear.md`, since Linear projects are workspace-wide
  objects rather than something each repo declares on its own.
- Cycle cadence. Cycle creation is a team-settings toggle not exposed via the
  Linear MCP; enable it once in **Team Settings → Cycles**.
- Anything about the product's own build, CI, or release — including which of
  its paths never reach what it ships, in `.github/changelog.json`. The shared
  workflows above are the exception, and the product still owns the copy it
  commits.

## Known Linear MCP gaps

- **No `create_team`.** Teams are made by hand in the Linear UI.
- **No cycle creation.** Team-settings toggle only.
- **Two teams, total.** The workspace is on the free plan. A skill that would need a
  third team needs a different design, not a new team.
- **No Releases.** Release pipelines, stages and per-release issue sets need a
  Business or Enterprise plan — the same free-plan constraint as the two-team cap.
  The tools (`save_release`, `list_release_pipelines`, …) are present in the MCP
  and the workspace has no pipelines, so this reads as "nothing set up yet" rather
  than "not entitled"; it is the latter. Releases has no timeline view in any case.
  `docs/linear.md` § Version timeline uses project milestones instead, which are
  the only dated Linear object that renders on a timeline.
- **No milestone deletion.** `save_milestone` creates and updates; nothing removes.
  A milestone that outlives its purpose is left in place and marked, and retiring
  it is a manual step in the Linear UI.

`save_initiative` and `save_project` both exist and work — an earlier version of
this document said initiatives had to be created by hand. That was wrong by
the time it was written down; verify a claim like this against the actual
tool list before repeating it.

## Known GitHub MCP gaps

- **No label or milestone creation/color/description management.** `issue_write`
  will silently create a missing label when you attach it to an issue, but
  with a default gray color and no description — good enough for matching
  and filtering, not for the palette in `design/labels.json`. Only `gh label
  create/edit` (via `scripts/sync-labels.sh`, run where `gh` is authenticated
  — not available in a Claude Code cloud session) sets those precisely.
  Milestones have no creation tool at all in this session; the suite uses
  `milestone:<name>` labels instead where a repo needs the grouping. See
  `docs/linear.md`.

Do not write a skill step that assumes any of these exist.
