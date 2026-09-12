#!/usr/bin/env bash
#
# Copy the shared workflows into each cloned product's .github/workflows/.
#
# Same shape as sync-notes.sh, for a related reason: a workflow has to be *in*
# the product for GitHub to run it. The alternative, a `uses:` reference to a
# file on this repo's main branch, would put an unpinned dependency on another
# repository into every product's CI, and a change here would land in every
# product with no pull request there to review it. A vendored copy is reviewed
# where it runs, and this script plus CI's drift step are what keep the copies
# from diverging without anyone noticing.
#
# What is shared: the workflows that are the same job on every product and
# name nothing only one product has. CodeQL over the four languages both carry,
# and Scorecard. Not shared: each product's ci.yml, its release workflows and
# anything that names a path or a toolchain only it has. Those stay per-repo,
# as docs/conventions.md says. The priority workflow is not here either: it
# moves together with a form block and a label map, and sync-priority.sh owns
# all three so they cannot be updated apart.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product missing a shared workflow as a failure
#                       instead of a skip.
#
# Adoption is per file. Without --check, a missing file is copied in, which is
# how a product adopts a workflow; with --check, a missing file is reported and
# skipped and a differing one is drift. The split follows sync-runner.sh and
# sync-notes.sh, for the same reason: adoption lands in the product's repo, so
# a red build here cannot fix it. Turn on --require-vendored once every product
# carries every file.

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
source_dir="plugins/suite-kit/workflows"

# Listed rather than globbed, so a file dropped into the directory by mistake
# does not land in every product's CI on the next sync.
sources=(
  "codeql.yml"
  "scorecard.yml"
)

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

for file in "${sources[@]}"; do
  src="$root/$source_dir/$file"
  [ -f "$src" ] || { echo "no $source_dir/$file at $root" >&2; exit 1; }
  # A workflow without a name is not one GitHub will list, and this is the
  # cheap place to notice before it is copied into every product.
  grep -q '^name:' "$src" || {
    echo "$source_dir/$file has no name: — refusing to propagate it" >&2
    exit 1
  }
done

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

  product_changed=0
  for file in "${sources[@]}"; do
    src="$root/$source_dir/$file"
    dest="$dir/.github/workflows/$file"

    if [ ! -f "$dest" ]; then
      if [ "$require_vendored" -eq 1 ]; then
        echo "! $name has no .github/workflows/$file" >&2
        status=1
        changed=1
      elif [ "$check_only" -eq 1 ]; then
        echo "? $name has no .github/workflows/$file — not adopted yet, skipped"
        skipped=$((skipped + 1))
      else
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        echo "+ $name gained .github/workflows/$file — commit it"
        changed=1
      fi
      product_changed=1
      continue
    fi

    # CRs stripped before comparing, for the reason sync-tokens.sh spells out:
    # the products normalise line endings independently, so identical content
    # can sit as CRLF on one side and LF on the other.
    if cmp -s <(tr -d '\r' < "$src") <(tr -d '\r' < "$dest"); then
      continue
    fi

    if [ "$check_only" -eq 1 ]; then
      echo "! $name has drifted from $source_dir/$file" >&2
      status=1
      changed=1
      product_changed=1
      continue
    fi

    cp "$src" "$dest"
    echo "+ $name updated .github/workflows/$file — commit it"
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
    echo "run scripts/sync-workflows.sh to update, then commit in each product" >&2
  elif [ "$status" -ne 0 ]; then
    echo "no drift among the products present, but the workspace is incomplete" >&2
  elif [ "$skipped" -ne 0 ]; then
    if [ "$skipped" -eq 1 ]; then noun="1 copy is"; else noun="$skipped copies are"; fi
    echo "no drift among the workflows carried; $noun not adopted yet"
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
