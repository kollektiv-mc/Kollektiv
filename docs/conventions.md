# Cross-repo conventions

Rules that apply across the suite. Anything specific to one repo — its projects, its
milestones, its label taxonomy — stays in that repo.

These were hoisted out of `Konnekt/agent_docs/LINEAR.md`, which held them as though
they were Konnekt's own. They are not; they describe how every repo here is tracked
and reviewed.

---

## Issues live in GitHub

Every repo in the suite tracks its work in **GitHub Issues, in the repo the work is
about**. Each declares it the same way:

```json
"tracking": "github-issues"
```

`.claude/suite.json` must declare exactly one of `linear` or `tracking` —
`design/suite.schema.json` enforces it. No repo declares `linear` today. The branch
remains in the schema for the planned GitHub→Linear sync, which is an open item in
`docs/roadmap.md` and does not exist yet.

`/suite-kit:linear-sync` in a repo with `tracking` set reports that the repo is tracked
elsewhere and stops. That is a correct outcome, not an error — and it is currently the
outcome everywhere.

**What exists in Linear today:** one workspace, `Kollektiv-MC`, holding one team and one
project (`Workspace & Tooling`). The free plan caps the workspace at two teams, so the
planned shape is `Kollektiv` for what spans the suite and `Apps` for building and
maintaining the individual products — not one team per repo. No `KON` or `KMD` team is
planned. Nothing writes to Linear until the sync lands.

## Issue ↔ roadmap mapping

Every issue created from a roadmap line carries this in its description:

```
Source: <roadmap path> § <section>
```

**Match on that line, never on titles.** Titles get edited on both sides and drift
apart; matching on them produces duplicates that then need untangling by hand.

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

```
Fixes #12      Closes #9      Part of #28
```

GitHub's own closing keywords, resolving against issues in the same repo. Nothing here
is Linear-tracked, so Linear's `KON-12`-style magic words do not apply — an issue
reference of that shape in a PR is a leftover, not an instruction to the integration.

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

## What stays per-repo

- Project and milestone structure, and label taxonomy.
- Cycle cadence. Cycle creation is a team-settings toggle not exposed via the Linear
  MCP; enable it once in **Team Settings → Cycles**.
- Anything about the product's own build, CI, or release.

## Known Linear MCP gaps

- **No `create_team`.** Teams are made by hand in the Linear UI.
- **No `create_initiative` / `save_initiative`.** Initiatives must be created by hand
  (Workspace → Initiatives → New). Projects can then be attached to one that already
  exists via `save_project(addInitiatives: [...])`.
- **No cycle creation.** Team-settings toggle only.
- **Two teams, total.** The workspace is on the free plan. A skill that would need a
  third team needs a different design, not a new team.

Do not write a skill step that assumes any of these exist.
