#!/usr/bin/env bash
#
# Copy the suite-kit check runner into each cloned product.
#
# Same shape as sync-tokens.sh, for the same reason: a product must be able to
# run its own checks from a standalone clone. Declaring a plugin in
# .claude/settings.json does not install it, so a cloud container or an
# unattended agent has no /suite-kit:health at all — and .claude/suite.json,
# which declares every check that repo cares about, is then read by nothing.
#
# Vendoring is the mechanism already proven to survive that: tokens.source.json
# reaches every clone because it is copied, not referenced. The runner reaches
# them the same way.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product that has never vendored the runner as a
#                       failure instead of a skip.
#
# The split follows validate-schemas.sh. A product that has not adopted the runner
# yet is a different finding from one whose copy has gone stale: the first is work
# not started, the second is a check silently running the wrong rules. Only the
# second should redden a build that cannot fix it — adoption lands in the product's
# own repo, not here. Turn on --require-vendored once both products carry it.
#
# Kept separate from sync-tokens.sh rather than folded into it: bootstrap.sh,
# sync-tokens.sh, sync-labels.sh and validate-schemas.sh are each one job, and
# renaming sync-tokens.sh would break its references in CLAUDE.md, README.md,
# docs/adopting.md and both CI jobs.

set -euo pipefail

check_only=0
require_vendored=0

for arg in "$@"; do
  case "$arg" in
    --check) check_only=1 ;;
    --require-vendored) require_vendored=1 ;;
    *)
      echo "usage: ${BASH_SOURCE[0]##*/} [--check] [--require-vendored]" >&2
      exit 2
      ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/suite.repos.json"
source_file="$root/plugins/suite-kit/suite-check.py"
vendored_path=".claude/suite-check.py"

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }
[ -f "$source_file" ] || {
  echo "no plugins/suite-kit/suite-check.py at $root" >&2; exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to read the manifest" >&2; exit 1
}

# The runner is the thing that decides whether a product's checks passed. A
# syntactically broken copy would propagate to every product and fail there, one
# confusing traceback at a time, so it is checked once here instead.
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$source_file" || {
  echo "suite-check.py is not valid Python — refusing to propagate it" >&2; exit 1
}

status=0
changed=0
skipped=0

while IFS= read -r name; do
  [ -n "$name" ] || continue
  dir="$root/$name"

  if [ ! -d "$dir" ]; then
    echo "? $name not cloned — run scripts/bootstrap.sh first" >&2
    status=1
    continue
  fi

  if [ ! -f "$dir/.claude/suite.json" ]; then
    echo "? $name has no .claude/suite.json — not adopted, nothing to run" >&2
    status=1
    continue
  fi

  dest="$dir/$vendored_path"

  if [ -f "$dest" ] && cmp -s "$source_file" "$dest"; then
    echo "= $name already up to date"
    continue
  fi

  if [ "$check_only" -eq 1 ]; then
    if [ -f "$dest" ]; then
      echo "! $name has drifted from plugins/suite-kit/suite-check.py" >&2
      status=1
      changed=1
    elif [ "$require_vendored" -eq 1 ]; then
      echo "! $name has no $vendored_path" >&2
      status=1
      changed=1
    else
      # Said out loud rather than passed over in silence: this product's checks
      # are unreachable in any environment without the plugin installed. It is
      # not drift, and it is not a pass either.
      echo "? $name has no $vendored_path — not adopted yet, skipped"
      skipped=$((skipped + 1))
    fi
    continue
  fi

  mkdir -p "$dir/.claude"
  cp "$source_file" "$dest"
  chmod +x "$dest"
  echo "+ $name updated $vendored_path — commit it"
  changed=1
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        print(r["name"])
' "$manifest")

if [ "$check_only" -eq 1 ]; then
  # Only a clean run over a complete workspace can claim no drift — the same
  # reasoning sync-tokens.sh states: a product that was never compared is not a
  # product that matches.
  if [ "$changed" -ne 0 ]; then
    echo "run scripts/sync-runner.sh to update, then commit in each product" >&2
  elif [ "$status" -ne 0 ]; then
    echo "no drift among the products present, but the workspace is incomplete" >&2
  elif [ "$skipped" -ne 0 ]; then
    # "no drift" over a set where nothing was compared is the same lie the check
    # runner exists to stamp out. Say what was actually checked.
    if [ "$skipped" -eq 1 ]; then noun="1 product has"; else noun="$skipped products have"; fi
    echo "no drift among the products carrying the runner; $noun not adopted it"
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
