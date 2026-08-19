#!/usr/bin/env bash
#
# Copy the release-notes generator and its tests into each cloned product.
#
# Same shape as sync-runner.sh, for a related reason. A product cuts its own
# releases, in its own workflow, in a container that has this repo nowhere on
# disk and no plugin installed — so the generator has to be *in* the product,
# the way tokens.source.json and suite-check.py are. Fetching it from here at
# release time would put a network call and an unpinned dependency on another
# repo's main branch in the middle of the one job that must not fail quietly.
#
# What is shared and what is not, because this split is the whole point:
#
#   shared    The rules. Which label means which section, that a title is never
#             read as a promotion into Features, that maintenance is counted
#             rather than listed. A user reading Konnekt's notes and Kommands'
#             notes should be reading the same document in two voices.
#   per-repo  Which of that product's paths never reach what it ships. Konnekt
#             has website/ and agent_docs/; Kommands has neither. That list
#             lives in each product's .github/changelog.json and is not
#             touched here.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product that has never vendored the generator as
#                       a failure instead of a skip.
#
# The split follows sync-runner.sh. A product that has not adopted the generator
# is a different finding from one whose copy has gone stale: the first is work
# not started, the second is a release describing itself by last month's rules.
# Only the second should redden a build that cannot fix it — adoption lands in
# the product's own repo, not here. Turn on --require-vendored once both
# products carry it.

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

# Script and tests move together. A generator whose tests were left behind is
# worse than one with none: the stale file passes, and says so.
sources=(
  "plugins/suite-kit/release-notes.py:.github/scripts/release-notes.py"
  "plugins/suite-kit/release-notes_test.py:.github/scripts/release-notes_test.py"
)

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

for pair in "${sources[@]}"; do
  src="$root/${pair%%:*}"
  [ -f "$src" ] || { echo "no ${pair%%:*} at $root" >&2; exit 1; }
  # Checked once here rather than discovered in a product's release job, which
  # is the worst place to find out: the notes fall back to a commit link and
  # the release is already published by the time anyone reads it.
  "${PYTHON[@]}" -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$src" || {
    echo "${pair%%:*} is not valid Python — refusing to propagate it" >&2; exit 1
  }
done

# The generator's own tests, run here before anything is copied. They are pure
# and offline, so there is no reason to let a broken classifier reach a product
# at all.
"${PYTHON[@]}" "$root/plugins/suite-kit/release-notes_test.py" >/dev/null || {
  echo "plugins/suite-kit/release-notes_test.py fails — refusing to propagate it" >&2
  exit 1
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

  # .github/changelog.json is the adoption marker, not .claude/suite.json: the
  # generator cannot run without a product's own non-app path list, and a
  # product that has not written one has not adopted this.
  if [ ! -f "$dir/.github/changelog.json" ]; then
    if [ "$require_vendored" -eq 1 ]; then
      echo "! $name has no .github/changelog.json" >&2
      status=1
      changed=1
    else
      echo "? $name has no .github/changelog.json — not adopted yet, skipped"
      skipped=$((skipped + 1))
    fi
    continue
  fi

  product_changed=0
  for pair in "${sources[@]}"; do
    src="$root/${pair%%:*}"
    dest="$dir/${pair##*:}"

    # CRs stripped before comparing, for the reason sync-tokens.sh spells out:
    # the products normalise line endings independently, so identical content
    # can sit as CRLF on one side and LF on the other.
    if [ -f "$dest" ] && cmp -s <(tr -d '\r' < "$src") <(tr -d '\r' < "$dest"); then
      continue
    fi

    if [ "$check_only" -eq 1 ]; then
      if [ -f "$dest" ]; then
        echo "! $name has drifted from ${pair%%:*}" >&2
      else
        echo "! $name has no ${pair##*:}" >&2
      fi
      status=1
      changed=1
      product_changed=1
      continue
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    [ "${pair##*:}" = ".github/scripts/release-notes.py" ] && chmod +x "$dest"
    echo "+ $name updated ${pair##*:} — commit it"
    changed=1
    product_changed=1
  done

  [ "$product_changed" -eq 0 ] && echo "= $name already up to date"
done < <(python_lines -c '
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
    echo "run scripts/sync-notes.sh to update, then commit in each product" >&2
  elif [ "$status" -ne 0 ]; then
    echo "no drift among the products present, but the workspace is incomplete" >&2
  elif [ "$skipped" -ne 0 ]; then
    if [ "$skipped" -eq 1 ]; then noun="1 product has"; else noun="$skipped products have"; fi
    echo "no drift among the products carrying the generator; $noun not adopted it"
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
