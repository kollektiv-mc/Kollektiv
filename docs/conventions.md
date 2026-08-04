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
choice to make anymore — Kommands set this precedent, Konnekt and kollektiv
now match it.

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

**Merging, not replacing.** Konnekt's `.claude/settings.json` also carries a `hooks`
section binding `graphify hook-guard` to `PreToolUse`. Add the permissions block
alongside it. suite-kit ships no hooks specifically so it cannot collide with those.

## What's shared vs. what stays per-repo

**Shared**, in `design/labels.json`: the `type:*`/`area:*`/`p0`–`p3`/`blocked`
label taxonomy, applied identically to every repo by `scripts/sync-labels.sh`.
A repo does not invent its own type or priority labels.

**Per-repo:**

- Linear project and milestone structure — documented once, for every repo,
  in kollektiv's `docs/linear.md`, since Linear projects are workspace-wide
  objects rather than something each repo declares on its own.
- Cycle cadence. Cycle creation is a team-settings toggle not exposed via the
  Linear MCP; enable it once in **Team Settings → Cycles**.
- Anything about the product's own build, CI, or release.

## Known Linear MCP gaps

- **No `create_team`.** Teams are made by hand in the Linear UI.
- **No cycle creation.** Team-settings toggle only.

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
