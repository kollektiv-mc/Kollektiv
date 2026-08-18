#!/usr/bin/env bash
#
# Scaffold suite-kit adoption in a repo.
#
# docs/adopting.md is six steps of careful reading, and a step skipped there fails
# late and quietly: a skill opens by reading .claude/suite.json, and a repo without
# one leaves every suite-kit skill inoperable. That has already happened to both
# products once — see the note at the top of that page's per-repo section.
#
#   scripts/adopt.sh <path> [--kind <kind>] [--product <name>] [--roadmap <path>]
#
# Writes .claude/suite.json, merges the permissions block into .claude/settings.json,
# adds the .gitignore lines, then delegates the two vendoring steps to the scripts
# that already own them.
#
# Non-destructive, like every script here. A repo that already carries a manifest is
# reported and left exactly as it is. Nothing here deletes, and nothing overwrites a
# file a human wrote.
#
# What it writes is deliberately incomplete. `tokens`, `minecraft` and
# `health.invariants` are judgement calls about a specific codebase — a generated
# guess at them would be worse than their absence, because it would look reviewed.
# The manifest it produces is valid; it is not finished, and the script says so.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

target=""
kind=""
product=""
roadmap="docs/roadmap.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --kind) kind="${2:-}"; shift 2 ;;
    --product) product="${2:-}"; shift 2 ;;
    --roadmap) roadmap="${2:-}"; shift 2 ;;
    -h|--help)
      echo "usage: ${BASH_SOURCE[0]##*/} <path> [--kind K] [--product N] [--roadmap P]"
      exit 0
      ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)
      [ -z "$target" ] || { echo "only one path may be given" >&2; exit 2; }
      target="$1"; shift
      ;;
  esac
done

[ -n "$target" ] || {
  echo "usage: ${BASH_SOURCE[0]##*/} <path> [--kind K] [--product N] [--roadmap P]" >&2
  exit 2
}
[ -d "$target" ] || { echo "no directory at $target" >&2; exit 1; }

target="$(cd "$target" && pwd)"
[ -n "$product" ] || product="$(basename "$target")"
[ -n "$kind" ] || kind="unknown"

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

status=0

# --- .claude/suite.json ---------------------------------------------------

mkdir -p "$target/.claude"
manifest="$target/.claude/suite.json"

if [ -f "$manifest" ]; then
  echo "= $product already has .claude/suite.json — left alone"
else
  # health.commands is required and must be non-empty, deliberately: a manifest
  # that declares no checks would let a repo sit indefinitely reporting health
  # while verifying nothing, which is the "skip reported as a pass" failure this
  # suite is built to prevent, in its worst form.
  #
  # So the scaffolded entry has to be a real check. This one is:
  #
  #   - It can fail. The previous entry could not. It ran `json.tool` over the
  #     manifest, but suite-check.py exits 2 with a line and column when that file
  #     will not parse, before any check runs -- so the manifest had to be valid
  #     for the check that validates it to be reached at all.
  #   - It needs no toolchain. A repo may be scaffolded before its language is
  #     installed, and a scaffolded repo has no scripts/lib/python.sh of this
  #     repo's to call, which is also why it cannot spell `python3`.
  #   - It is true of any repo, in any language.
  #   - Nothing else in the suite covers it. docs/conventions.md's permissions
  #     floor denies *reading* .env and secrets/; nothing catches them being
  #     committed. This is the other half of that rule.
  #
  # Tracked files only. A gitignored .env in the working tree is normal and is
  # not a finding.
  cat > "$manifest" <<EOF
{
  "\$schema": "https://github.com/kollektiv-mc/Kollektiv/design/suite.schema.json",
  "product": "$product",
  "kind": "$kind",
  "tracking": "github-issues",
  "roadmap": "$roadmap",
  "health": {
    "commands": [
      { "name": "no committed secrets", "run": "! git ls-files | grep -qE '(^|/)([.]env(\$|[.])|secrets/)'" }
    ]
  }
}
EOF
  echo "+ $product wrote .claude/suite.json"
fi

# --- .claude/settings.json ------------------------------------------------

settings="$target/.claude/settings.json"

# Merged rather than written, because docs/conventions.md is explicit that the block
# goes in alongside whatever is already there — Konnekt's settings carry a hooks
# section binding graphify hook-guard, and clobbering it would break that repo's
# guards to install ours.
"${PYTHON[@]}" - "$settings" <<'PY'
import json, os, sys

path = sys.argv[1]
floor = {
    "deny": ["Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"],
    "ask": ["Bash(git push:*)"],
}

data = {}
if os.path.isfile(path):
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError:
        print(f"! {path} is not valid JSON — not touching it", file=sys.stderr)
        raise SystemExit(1)

permissions = data.setdefault("permissions", {})
added = []
for key, values in floor.items():
    existing = permissions.setdefault(key, [])
    for value in values:
        if value not in existing:
            existing.append(value)
            added.append(f"{key}:{value}")
permissions.setdefault("allow", [])

marketplaces = data.setdefault("extraKnownMarketplaces", {})
marketplaces.setdefault(
    "kollektiv", {"source": {"source": "github", "repo": "kollektiv-mc/Kollektiv"}}
)
plugins = data.setdefault("enabledPlugins", {})
plugins.setdefault("suite-kit@kollektiv", True)

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")

print(f"+ settings.json updated ({len(added)} permission entries added)" if added
      else "= settings.json already carries the permissions floor")
PY
[ $? -eq 0 ] || status=1

# --- .gitignore -----------------------------------------------------------

ignore="$target/.gitignore"
line=".claude/settings.local.json"
if [ -f "$ignore" ] && grep -qxF "$line" "$ignore"; then
  echo "= .gitignore already ignores $line"
else
  printf '\n# Agent tooling: shared config is committed so every clone and cloud agent\n# inherits the same setup. Personal state is not.\n%s\n' "$line" >> "$ignore"
  echo "+ .gitignore now ignores $line"
fi

# --- vendored files -------------------------------------------------------

# Delegated rather than reimplemented. These two scripts already know how to vendor,
# how to report, and how to detect drift afterwards; a second copy of that logic here
# is the duplication this repo exists to prevent. They read suite.repos.json, so they
# only act on a repo listed there — a target outside the manifest is told to add
# itself, not silently skipped.
if "${PYTHON[@]}" -c '
import json, sys
repos = json.load(open(sys.argv[1]))["repos"]
sys.exit(0 if any(r["name"] == sys.argv[2] for r in repos) else 1)
' "$root/suite.repos.json" "$(basename "$target")" 2>/dev/null; then
  "$root/scripts/sync-tokens.sh" || status=1
  "$root/scripts/sync-runner.sh" || status=1
else
  echo "? $product is not in suite.repos.json — add it there, then run:" >&2
  echo "    ./scripts/sync-tokens.sh && ./scripts/sync-runner.sh" >&2
  status=1
fi

# --- what is still a human's job -----------------------------------------

cat <<EOF

$product now has a valid manifest. It is not a finished one.

Fill in by hand, in .claude/suite.json — see docs/adopting.md for each field:

  health.commands     the repo's real lint/typecheck/test entries
  tokens              if the repo has UI: role, source, sourceFile, generate,
                      enforce, paths
  minecraft           if the repo emits commands: targetVersion, dataSource,
                      traitMatrix
  health.invariants   the checks a linter cannot express, each with a diagnosis
                      saying what a match means
  health.generated    any generator whose output is committed

Nothing was invented for these. An invariant with no stated reason gets deleted the
first time it is inconvenient, and a guessed enforce level reports clean over the
wrong paths.

Also not written: the superpowers marketplace, which docs/adopting.md step 1 lists
alongside kollektiv. Enabling a marketplace runs third-party code with your
privileges, and that is a decision to make per repo rather than one a scaffold
script makes on your behalf. Add it by hand if you want it.

Then: ./scripts/validate-schemas.sh
EOF

exit $status
