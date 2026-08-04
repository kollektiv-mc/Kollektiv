#!/usr/bin/env bash
#
# Copy the shared design-token source into each cloned product.
#
# Products vendor the source rather than reading this path, so a product can build
# from a standalone clone. See design/README.md.
#
# Idempotent and non-destructive, like bootstrap.sh: a product that is not cloned
# is reported and skipped, and nothing here deletes. Re-running with no upstream
# change writes nothing and reports every product as unchanged.
#
#   --check   Report drift and exit non-zero without writing anything.
#
# --check exists because a product cannot detect its own staleness: its generator
# reads the vendored copy, so a stale copy still regenerates a clean diff. Only a
# checkout that has both sides can compare them. See design/README.md.

set -euo pipefail

check_only=0

for arg in "$@"; do
  case "$arg" in
    --check) check_only=1 ;;
    *) echo "usage: ${BASH_SOURCE[0]##*/} [--check]" >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/suite.repos.json"
source_file="$root/design/tokens.json"
vendored_name="tokens.source.json"

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }
[ -f "$source_file" ] || { echo "no design/tokens.json at $root" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to read the manifest" >&2; exit 1
}

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$source_file" || {
  echo "design/tokens.json is not valid JSON — refusing to propagate it" >&2; exit 1
}

status=0
changed=0

while IFS=$'\t' read -r name role; do
  [ -n "$name" ] || continue
  dir="$root/$name"

  if [ ! -d "$dir" ]; then
    echo "? $name not cloned — run scripts/bootstrap.sh first" >&2
    status=1
    continue
  fi

  if [ "$role" = "source" ]; then
    echo "= $name is the source, nothing to vendor"
    continue
  fi

  dest="$dir/$vendored_name"

  if [ -f "$dest" ] && cmp -s "$source_file" "$dest"; then
    echo "= $name already up to date"
    continue
  fi

  if [ "$check_only" -eq 1 ]; then
    if [ -f "$dest" ]; then
      echo "! $name has drifted from design/tokens.json" >&2
    else
      echo "! $name has no $vendored_name" >&2
    fi
    status=1
    changed=1
    continue
  fi

  cp "$source_file" "$dest"
  echo "+ $name updated $vendored_name — regenerate its tokens and commit both"
  changed=1
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        tokens = r.get("tokens")
        role = tokens.get("role") if isinstance(tokens, dict) else tokens
        print(r["name"], role or "", sep="\t")
' "$manifest")

if [ "$check_only" -eq 1 ]; then
  # Only a clean run over a complete workspace can claim no drift. A product that
  # was never compared is not a product that matches — saying so would be the same
  # collapse of "did not run" into "passed" that the health skill exists to prevent.
  if [ "$changed" -ne 0 ]; then
    echo "run scripts/sync-tokens.sh to update, then regenerate tokens in each product" >&2
  elif [ "$status" -ne 0 ]; then
    echo "no drift among the products present, but the workspace is incomplete" >&2
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
