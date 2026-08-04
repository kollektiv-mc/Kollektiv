#!/usr/bin/env bash
#
# Apply the suite's GitHub label taxonomy (design/labels.json → .github array) to
# this repo and every product in suite.repos.json.
#
# Uses `gh label create` / `gh label edit`, not the GitHub MCP server: issue-write
# tools can attach a label name to an issue and will silently create a missing one,
# but with no color or description of its own choosing. Only `gh` (or the REST API
# it wraps) can set those, so getting the exact palette in design/labels.json onto
# GitHub requires `gh auth login` once, same as validate-schemas.sh requires
# check-jsonschema.
#
# Idempotent and non-destructive, like sync-tokens.sh: a label that already matches
# is left alone, and nothing here deletes a label — including ones outside this
# taxonomy, since a repo may carry its own labels this suite doesn't govern.
#
#   --check   Report drift and exit non-zero without writing anything.

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
labels_file="$root/design/labels.json"

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }
[ -f "$labels_file" ] || { echo "no design/labels.json at $root" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || {
  echo "gh (GitHub CLI) is required — https://cli.github.com, then gh auth login" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to read the manifest" >&2; exit 1
}

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$labels_file" || {
  echo "design/labels.json is not valid JSON — refusing to propagate it" >&2; exit 1
}

status=0
changed=0

sync_one_repo() {
  local slug="$1"

  while IFS=$'\t' read -r name color description; do
    [ -n "$name" ] || continue

    existing="$(gh label list --repo "$slug" --json name,color,description \
      --jq ".[] | select(.name == \"$name\")" 2>/dev/null || true)"

    if [ -z "$existing" ]; then
      if [ "$check_only" -eq 1 ]; then
        echo "! $slug missing label '$name'" >&2
        status=1
        changed=1
      else
        gh label create "$name" --repo "$slug" --color "$color" --description "$description" --force
        echo "+ $slug created '$name'"
        changed=1
      fi
      continue
    fi

    existing_color="$(echo "$existing" | python3 -c 'import json,sys; print(json.load(sys.stdin)["color"])')"
    existing_desc="$(echo "$existing" | python3 -c 'import json,sys; print(json.load(sys.stdin)["description"])')"

    if [ "$existing_color" = "$color" ] && [ "$existing_desc" = "$description" ]; then
      echo "= $slug '$name' already up to date"
      continue
    fi

    if [ "$check_only" -eq 1 ]; then
      echo "! $slug '$name' has drifted (color or description)" >&2
      status=1
      changed=1
    else
      gh label edit "$name" --repo "$slug" --color "$color" --description "$description"
      echo "+ $slug updated '$name'"
      changed=1
    fi
  done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for l in json.load(f)["github"]:
        print(l["name"], l["color"], l["description"], sep="\t")
' "$labels_file")
}

self_url="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
self_slug="$(echo "$self_url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"

if [ -n "$self_slug" ]; then
  sync_one_repo "$self_slug"
else
  echo "? could not determine this repo's GitHub slug from 'origin' — skipping it" >&2
  status=1
fi

while IFS=$'\t' read -r name url; do
  [ -n "$name" ] || continue
  slug="$(echo "$url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
  sync_one_repo "$slug"
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        print(r["name"], r["url"], sep="\t")
' "$manifest")

if [ "$check_only" -eq 1 ]; then
  if [ "$changed" -ne 0 ]; then
    echo "run scripts/sync-labels.sh to update" >&2
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
