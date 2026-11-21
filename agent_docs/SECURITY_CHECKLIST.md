# Kollektiv: security checklist

The threat surface of this project and how each part is held. Pair with
`SECURITY.md` (how to report) and the scanners below (what runs automatically).

## Scanners

- CodeQL (`.github/workflows/codeql.yml`): every push and PR to main, weekly.
- OpenSSF Scorecard (`.github/workflows/scorecard.yml`): weekly.
- Dependabot alerts and updates (`.github/dependabot.yml`).
- GitHub secret scanning and push protection: enable in the repo settings.

## S1. Inputs

- [ ] Untrusted input: issue bodies read by `issue-priority.yml` (passed
      through `env`, never `${{ }}` in `run:`), and the product clones
      `bootstrap.sh` fetches, which the scripts read as data and never execute.

## S2. Credentials and secrets

- [ ] No secrets in the tree; `.claude/settings.json` denies reading `.env*`.
- [ ] Tokens used by CI are repo secrets with least privilege.

## S3. Paths and processes

- [ ] File paths built from input are resolved and checked against a root.
- [ ] No shell interpolation of untrusted strings.

## S4. CI and supply chain

- [ ] Every third-party action is pinned to a commit SHA.
- [ ] Workflows declare minimal `permissions:`; `pull_request_target` jobs never
      check out PR code.

## Open backlog
