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

## The health sweep's run log

Findings are only half of what a scheduled run knows. The other half is that it ran at
all, what it covered, and what it could not reach — and on a clean week that half has
no issue to live in.

So the sweep also keeps one standing issue in **kollektiv**, labelled `health-check`,
identified by this line in its body:

```
Health-Sweep-Log: kollektiv
```

One issue, never closed, one comment per run, clean runs included. The comment carries
counts rather than prose: per-repo checks passed, drift, the deep-dive area covered,
what could not run, and links to whatever was opened or commented on. The detail lives
in the issues; this is the ledger.

**Why an issue and not a file in the repo.** The sweep's whole claim to being
trustworthy is that it never commits, pushes, or leaves a branch behind — an unattended
weekly run with nobody reviewing its diff. A log file it appends and pushes each week
would trade that away for a format nobody reads more often. An issue comment costs the
sweep nothing it was not already spending.

Note that `ask: Bash(git push:*)` in the permissions floor is **not** what stops it. A
Routine's session runs with no permission prompts at all
([routines docs](https://code.claude.com/docs/en/routines)), so nothing is there to
answer an `ask` and the rule cannot block anything. What keeps the sweep from pushing
is the instruction in its skill and nothing else, which is the reason that instruction
is stated four times and the reason not to hand it a job that needs a commit.

**Why kollektiv and not a product.** The run is suite-wide. A suite-wide record filed
under one product's directory is the same category error as a shared design token
defined in one product: whoever reads it there will reasonably assume it is about that
product.

The report the run prints reaches a human once, through the Routine's completion
notification, and then exists only in a session transcript. The log is the part that is
still there in six months.

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

## The cloud environment's setup script

`scripts/cloud-setup.sh` is the body of the **Setup script** field in the cloud
environment dialog at claude.ai/code. It is the only script here that is not run
from a checkout, because that field is the only thing that runs before Claude Code
launches. The copy in this repo is the reviewable master: paste it into the dialog
when it changes, or the thing provisioning every cloud session is config that
exists nowhere and nobody can review.

Today it installs one tool, graphify, for Konnekt's `PreToolUse` hooks. That it had
to be written at all is the lesson worth keeping. Konnekt's `CLAUDE.md` told agents
to run `pipx install graphify`, and there is no `graphify` on PyPI: the
distribution is `graphifyy` and `graphify` is only the console script it installs.
So the documented command failed on every machine, and because nothing checks that
an optional tool is present, the only trace was sessions reporting "graphify is not
installed in this container" into `agent_docs/HEALTH_LOG.md` for months.

Two rules follow from that:

- **A setup script installs, it does not build.** graphify's graph is an AST pass
  over a whole tree, and the clone is fresh every session anyway. Konnekt's
  `CLAUDE.md` says to build it on demand, and this repo's job is to make the tool
  available, not to decide a session needs it.
- **Fail loudly.** The script exits non-zero when anything it installed is not
  runnable afterwards. A half-provisioned environment gets snapshotted and then
  every later session inherits the gap in silence, which is the failure above. It
  verifies the bare command name resolves on a standard `PATH`, not just on the
  dialog's own, because a `PreToolUse` hook gets the former.

The cost of the second rule is that a PyPI outage during a rebuild reddens the
environment rather than quietly producing one without the tool. That is the trade
this suite already makes everywhere else: a check that could not run is skipped,
never passed.

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

## The agent memory budget

**A repo's always-loaded agent memory stays under 200 lines.** That is Claude
Code's own target, and it is stated as a consequence rather than a preference:
"Longer files consume more context and reduce adherence"
([memory docs](https://code.claude.com/docs/en/memory)). A convention nobody
reads is not a convention, and past a few hundred lines that stops being a
figure of speech.

**What counts is everything loaded at launch, not the file called `CLAUDE.md`.**
Three things land in context every session and all three are in the budget:

- the root `CLAUDE.md`, or `.claude/CLAUDE.md`
- every `@import` from it, resolved recursively to a depth of four
- every `.claude/rules/*.md` with no `paths:` frontmatter

**Splitting into `@imports` is organisation, not relief.** Imported files are
expanded into context at launch, so a twelve-line root file importing six
hundred lines costs six hundred and twelve. Konnekt was in exactly that
position when this rule was written, reading as a tidy twelve-line file and
loading 639 lines, and a per-file check would have called it the smallest
memory file in the suite.

**The escape hatch is `.claude/rules/` with `paths:` frontmatter.** A scoped
rule loads only when Claude reads a file it matches, so it costs nothing at
launch and can be as long as the subject deserves. Kommands holds 288 lines
that way across four files. What belongs there is anything that only matters in
one part of the tree; what has to stay in `CLAUDE.md` is what must be true
before any file is opened, because a path-scoped rule triggers on reading a
matching file and a new file written from nothing may not have triggered one.

Two filters decide what survives a trim, in this order:

1. **Cut what Claude can derive from the codebase** — directory layouts,
   dependency inventories, architecture overviews. Keep pitfalls, rationale,
   and conventions that differ from a tool's defaults. This is the split
   `/doctor`'s own trim check makes.
2. **Demote what a gate already enforces.** A rule backed by a failing check
   fails loudly whether or not it was in context; a rule backed only by prose
   rots silently. Between two rules of equal length, the one ESLint already
   catches is the one to move.

And the rule Kommands wrote for itself, which holds for every repo: **each fact
lives in exactly one file.** `CLAUDE.md` links, it does not restate.

### Where it is enforced

`suite-check.py`'s `memory` section, so `/suite-kit:health` reports it in every
repo and the weekly sweep reports it across all of them. It is the one section
driven by no manifest list, deliberately: every repo pays this cost whether or
not it declares anything, so a check a repo opts into is a check a new repo
silently lacks. An absent declaration means the suite default, never a skip.

### A repo that is already over

Coming down takes more than one pull request, so a repo over the budget
declares `health.memory` in `.claude/suite.json`, seeded at what it measures
today:

```json
"memory": {
  "maxLines": 639,
  "reason": "Being trimmed under kollektiv-mc/Konnekt#NNN. Lower this with each pass."
}
```

A ratchet, on the same terms as the aislop size limits and the coverage floors:
**lower it as the tree shrinks, never raise it to make a build pass.** A repo
inside the budget declares nothing and keeps its headroom to 200, rather than
being pinned at whatever it happens to measure. Being unusually short today is
not a reason to be held to it tomorrow.

The field is built to expire. `maxLines` has a schema minimum of 201, so a repo
that reaches the budget can no longer express the key and has to delete it, and
the runner fails a manifest that still carries one once the real total is inside
200. A schema only binds a repo that validates its manifest, which is why the
check refuses the stale field again at runtime.

## Public copy

**Anything published carries no em dash.** Use a comma, a colon, or two
sentences.

Published means what a reader outside the project sees:

- the websites' words, including the title, the meta description and alt text
- issue titles and bodies
- pull request titles and bodies
- commit messages

Everything else is unaffected, and deliberately so. Code, code comments, and
the documentation in these repos are notes between people working on them, not
copy. This file uses em dashes freely and is not in breach: the rule is about
what is published, not about how the thing that publishes it is written.

**Why the rule exists where it does.** A merged pull request title is a
release-notes line, which the section below is entirely about. An issue title
is an index entry. The website is the first thing a user reads. Those are the
surfaces where punctuation someone has to decode costs something, and they are
also the ones nobody revises after the fact.

**What is checked.** `scripts/check-copy.sh` reads every repo in
`suite.repos.json`, plus this one, and fails on an em dash in the copy. Per repo
it takes `website/*.html` and any `*.html` at the root, which is where a Vite
app keeps the shell it serves; nothing deeper, so a fixture or a build output is
never mistaken for published copy. It blanks comments, `<script>` and `<style>`
first, so a note to the next person working on the page is left alone, and it
keeps the line numbers so a failure names the line.

A repo that is not cloned, or that has no page the scan can reach, is reported
and skipped rather than counted as clean. The bare form does that so a checkout
without the products still runs; `--require-products` turns an uncloned repo
into a failure, and is what `.github/workflows/drift.yml` uses after
`bootstrap.sh`. `ci.yml` runs the bare form on every push, which covers this
repo's own website and says out loud which products it could not see.

Adding a repo to `suite.repos.json` is the whole of what it takes to have its
copy checked from then on.

**Copy that is not in HTML is checked where the parser is.** Kommands renders
its words from `.tsx`, so the scan above reads its `index.html` and finds one
word of copy in it, the title. A regex over a component cannot tell a rendered
string from a comment about one, and these trees comment heavily: 160 files
there carry an em dash and all but a handful are prose between people working
on it. So that half is an ESLint `no-restricted-syntax` rule in the repo, on
`JSXText`, `Literal` and `TemplateElement`, which sees the three node types
that carry copy and never sees a comment at all. It runs in `pnpm lint`, which
CI already gates on, and it follows the same precedent as Konnekt's rule
against inline `style={{}}`.

The rule does not separate a string a user reads from one only a developer
hits. It does not need to: neither wants an em dash, and a colon reads the same
in both, so fixing the handful of loader and parser messages was cheaper than
the machinery to exempt them.

**What is not checked, and will not be.** Issue titles, pull request titles and
bodies, and commit messages are not in a file this repo can read, so nothing
gates them. They rest on review. Saying so is the point: the suite treats a
check that could not run as a skip rather than a pass, and a convention that
implies a gate it does not have is the same mistake in prose.

**Where this came from.** Konnekt has stated the rule locally for some time, in
`agent_docs/CLAUDE.md` and `CONTRIBUTING.md`, covering issue titles and pull
request titles, bodies and commit messages. It never covered website copy, and
Konnekt's own pages carried seventeen em dashes as a result: every page title
and its `og:`/`twitter:` twin, plus one line of prose. They are gone, and the
check now reads the products rather than only this repo, which is what would
have caught them. This is that rule hoisted to the suite, with the websites
added, for the same reason every other rule here was hoisted: it was true of one
repo and should be true of all of them.

Its record in Konnekt is worth repeating, because it says what to expect.
Across the last two hundred commits there, no subject line carried an em dash
and thirteen bodies did. The half that is read on every release lands; the half
buried in a body drifts. Only the website half of this rule has a check behind
it, so the rest will drift the same way unless review catches it.

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
`plugins/suite-kit/workflows/pr-labelled.yml` here, vendored into each product's
`.github/workflows/` by `scripts/sync-workflows.sh`.
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

## Verifiable release artefacts

A product that publishes a binary somebody downloads carries three things. They
look like one thing and are not:

- **`checksums.txt`, published beside the binaries.** It answers "did this
  download arrive intact". It cannot answer "did this come from the project",
  because whoever can write the release writes both halves of it.
- **A build provenance attestation**, produced by `actions/attest` in the job
  that uploads the exact bytes, which needs `id-token: write` and
  `attestations: write` on that job. Each artifact's digest is bound to the
  workflow, the repository and the commit, signed against the job's OIDC token
  and recorded in a public transparency log. Nothing holds a signing key, so
  there is no key to leak and none to rotate. Attest where the upload happens
  rather than in the build jobs: what is signed has to be what a person
  downloads, with no artifact round trip in between.
- **Somewhere a reader is told.** An attestation nobody knows about buys
  nothing, and release notes are read after the download if at all. The
  product's download page carries the `gh attestation verify` invocation and
  the checksum fallback, and says which question each one answers.

Konnekt does all three, in `.github/workflows/release.yml`'s `publish` job and
`website/download.html`. Kommands publishes no binary yet; when its desktop
shell does, it carries the same three.

Signing is a **separate** problem and is not covered here. Provenance proves
where a binary came from once a reader asks; OS code signing and notarisation
are what stop Windows and macOS warning about it before they get the chance.
A product can hold all three above and still trip SmartScreen.

This is a convention rather than a shared workflow, and deliberately so. Release
workflows stay per-repo, per § What's shared vs. what stays per-repo below,
because each names a toolchain and an artifact set only that product has.
`sync-workflows.sh` carries job bodies that are identical everywhere; a release
job never is. What travels between the products here is the requirement.

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

Every workflow in the suite, shared or per-repo, pins each action to the full
commit SHA of a release, with that release as a trailing comment:
`actions/checkout@<40 hex> # v7.0.1`. A tag can be moved to other code by
whoever controls the action's repository, and a moved tag in a release workflow
runs with that job's write token. Resolve the SHA from the action's own
repository (`git ls-remote --tags https://github.com/<owner>/<repo>`, taking the
peeled `^{}` commit of an annotated tag), never from a fork or a search result.
Every workflow also declares a top-level `permissions:` block, `contents: read`
unless it needs less, and a job that needs more says so in its own block.
Dependabot's `github-actions` updates keep the pins current in the products;
see the Dependabot paragraph in `CLAUDE.md` for why the masters here trail
them.

**Shared**, in `.aislop/base.yml`: the aislop policy, vendored by
`scripts/sync-aislop.sh`. Per-repo: the size ratchet in each `.aislop/config.yml`,
held at that tree's largest function and file, and the `.aislopignore` naming
what that tree generates or vendors.

**Shared**, in `design/labels.json`'s `priorityForm`: the question every issue
form asks and the `p*` label each answer becomes, rendered into the forms and
into the vendored `.github/workflows/issue-priority.yml` by
`scripts/sync-priority.sh`. Per-repo: everything else in the forms. See
§ Priority above.

**A repo in the manifest has not necessarily adopted.** `suite.repos.json` is
the list of repos the suite manages, and a repo joins it before
`scripts/adopt.sh` has ever run against it. `.claude/suite.json` is the marker
that says it has: `adopt.sh` writes it, and every suite-kit skill opens by
reading it. So each `--require-products` and `--require-vendored` flag asserts
something about **adopted** repos, and a cloned repo without that file is
reported and skipped rather than failed. Two things around it stay failures:
a repo that is in the manifest and not on disk, which under those flags means
`bootstrap.sh` did not do its job, and a repo that has adopted and is missing a
vendored file, which means it lost one.

Before this, five checks read "not cloned, or not adopted" as one state and
failed on both, so adding a repo to the manifest turned the nightly red until
that repo had adopted everything. Kube is in the manifest on exactly that
footing today.

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
  commits. What a release that publishes a binary has to carry regardless of
  how it is built is § Verifiable release artefacts above.

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
