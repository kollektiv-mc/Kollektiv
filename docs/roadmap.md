# Roadmap

Reconciled against Linear team `KOL`, project `Workspace & Tooling`, by
`/suite-kit:linear-sync`. Each item's Linear issue carries a
`Source: docs/roadmap.md § <section>` line — match on that, not on titles.

## Linear substrate

- [ ] Rename team `Kollektiv-MC` to `Kollektiv`, keep key `KOL`
- [ ] Create team `Konnekt`, key `KON`
- [ ] Create team `Kommands`, key `KMD`
- [ ] Create initiative `Kollektiv Suite` and attach `Workspace & Tooling`

## OMC adoption

- [ ] Apply the settings block (`docs/adopting.md`) to Kommands, declaring the
      `omc` marketplace alongside `suite-kit`
- [ ] Run `claude plugin install` for `oh-my-claudecode@omc` on each machine and
      cloud path that needs it, and record where it has been run
- [ ] Observe a session of OMC's agents against Konnekt's `graphify hook-guard`
      before enabling OMC repo-wide there

## Suite conventions

- [ ] Hoist the reusable parts of Konnekt's `agent_docs/LINEAR.md` — the
      magic-word PR convention and the `Source: <roadmap> § <section>` mapping
      rule — into this repo, leaving Konnekt's own project and milestone
      structure where it is

## Workspace validation

- [ ] Clone Konnekt and Kommands via `scripts/bootstrap.sh` and confirm
      `.omc-workspace` produces one shared session instead of one per product
