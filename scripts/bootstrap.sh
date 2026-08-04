#!/usr/bin/env bash
#
# Clone the suite's products as siblings inside the workspace root.
#
# Idempotent, and deliberately non-destructive: a directory that already holds a
# working clone is left exactly as it is, and a directory that holds anything
# else is reported rather than touched. Nothing here deletes.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/suite.repos.json"

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to read the manifest" >&2; exit 1
}

status=0

while IFS=$'\t' read -r name url; do
  [ -n "$name" ] || continue
  dir="$root/$name"

  if [ -d "$dir" ]; then
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
      echo "= $name already cloned"
    else
      echo "! $name exists but is not a git clone — leaving it alone" >&2
      status=1
    fi
    continue
  fi

  echo "+ cloning $name"
  git clone "$url" "$dir"
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        print(r["name"], r["url"], sep="\t")
' "$manifest")

exit $status
