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

## Priority

Every issue in every repo carries **exactly one** `p*` label. No label is not a
neutral middle: `/suite-kit:suite-sync` mirrors an unlabelled issue into Linear
as priority None, which sorts below `p3` and drops it out of every ordered view.
An issue nobody has prioritised looks, from Linear, exactly like one nobody
thinks is worth doing.

The four levels are defined once, in `design/labels.json`'s `priority` array.
They are quoted verbatim below, because this is the page a person reads and that
is the file the tooling reads — `scripts/sync-priority.sh` fails if the two
disagree.

| Label | Linear | Means |
|---|---|---|
| `p0` | Urgent | Drop everything. Data loss, a shipped build that will not start, a security fix, or the default branch red. Other work stops until it clears. |
| `p1` | High | Next up. A user-visible capability is broken with no workaround, or a release is blocked on it. |
| `p2` | Medium | Normal queue. Real work with a workaround, or with no deadline. The honest answer for most issues, and the one an unsure assessment resolves to. |
| `p3` | Low | Nice to have. Polish, cleanup, or an idea worth keeping. No commitment that it gets done. |

Priority is a claim about sequencing, not a measure of how annoyed the reporter
was. Triage may change it, and changing it is normal rather than a correction.

**`p0` is maintainer-only**, and not by a rule anyone has to remember. It is
declared `reporterSelectable: false`, so the field `sync-priority.sh` generates
into the public forms does not contain it. There is no cap to enforce anywhere
and nothing to spoof, because the option was never offered.

### How the label actually gets there

A GitHub issue form applies only the static `labels:` list in its front matter. A
dropdown answer lands as text in the issue body and never becomes a label on its
own, so the priority field the forms ask for would be decorative without
something reading it back. `.github/workflows/issue-priority.yml`, vendored into
every repo by `sync-priority.sh`, is that something: it maps the answer to a
label on `issues: opened`, and leaves an issue that already carries one alone.

### Agents assess priority before filing

An agent opening an issue — `/suite-kit:health-sweep`, or a session working in a
repo — applies a `p*` label **in the same call** that creates it, chosen against
the table above. "Unsure" resolves to `p2`, never to nothing.

This is the case the forms cannot reach. An issue opened through the API has no
form answer in its body, so the workflow has nothing to map and comments saying
so instead. GitHub has no way to refuse an issue, so a comment is the strongest
gate available; it is also the one an agent reading its own issue back will
actually see. It deliberately applies no triage label on that path, because
attaching a label a repo does not declare makes GitHub invent it in default grey
with no description (see § Known GitHub MCP gaps), and quietly inventing
vocabulary is what `design/labels.json` exists to prevent.

An issue that reaches Linear with no priority is reported by
`/suite-kit:suite-sync` as a finding rather than mirrored silently at None.

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

Each product builds its notes with `.github/scripts/release-notes.py`, vendored
from `plugins/suite-kit/release-notes.py` by `scripts/sync-notes.sh` for the
reason `sync-runner.sh` states about the check runner: a release job runs in the
product's own container, with this repo nowhere on disk and no plugin installed,
so the generator has to be *in* the product.

**Every pull request carries exactly one `type:` label.** The label alone decides
where it lands, and each product's CI fails a pull request without one. Before
that gate existed, 24 of the 41 pull requests in Konnekt's first release window
were unlabelled, the generator fell back to reading the title's leading verb, and
"Add a Full release roadmap section and a nightly snapshot build channel" — a
website and CI change — was published to users under **Features**.

| Label | Where it lands |
|---|---|
| `type:feature` | **Features** |
| `type:bug` | **Fixes** |
| `type:chore`, `type:docs` | counted in a footer line, not listed |
| `changelog:skip` | left out entirely, not counted |
| none | **Other changes**, and CI is red |

Two rules follow from that table and are worth stating outright:

- **Nothing reaches Features by guesswork.** An unlabelled title is read only
  well enough to separate a fix from everything else. A wrong entry in the
  section people read first costs more than a vague one further down, so the
  guess is confined to where being wrong is cheap.
- **Maintenance is counted, not listed.** `type:chore` and `type:docs` are real
  work that changed nothing a user can observe. Listing them is how 17 entries
  of CI and tooling ended up in a changelog for people downloading a binary. The
  footer says how many there were, and the full-changelog link has them all.

**One pull request, one concern.** The notes list a merged pull request once,
under one heading, by its title, so a pull request carrying a feature *and* a
website pass *and* a CI tweak cannot be described honestly by any single line.
Split it, or accept that it will be filed as a chore.

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
A repo does not invent its own type or priority labels. What the priority levels
*mean*, and the form field and workflow that put them on an issue, are shared
from the same file — see § Priority.

**Shared**, in `plugins/suite-kit/release-notes.py`: how a merged pull request
becomes a line in the release notes, vendored by `scripts/sync-notes.sh`. See
§ Release notes and pull request labelling above for the split between those
rules and each product's own `.github/changelog.json`.

**Per-repo:**

- Linear project and milestone structure — documented once, for every repo,
  in kollektiv's `docs/linear.md`, since Linear projects are workspace-wide
  objects rather than something each repo declares on its own.
- Cycle cadence. Cycle creation is a team-settings toggle not exposed via the
  Linear MCP; enable it once in **Team Settings → Cycles**.
- Anything about the product's own build, CI, or release — including which of
  its paths never reach what it ships, in `.github/changelog.json`.

## Known Linear MCP gaps

- **No `create_team`.** Teams are made by hand in the Linear UI.
- **No cycle creation.** Team-settings toggle only.
- **Two teams, total.** The workspace is on the free plan. A skill that would need a
  third team needs a different design, not a new team.

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
