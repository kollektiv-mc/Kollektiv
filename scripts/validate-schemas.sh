#!/usr/bin/env bash
#
# Validate this repo's JSON against its schemas.
#
#   design/tokens.json        against  design/tokens.schema.json
#   .claude/suite.json        against  design/suite.schema.json
#   <product>/.claude/suite.json  ditto, for every product that is cloned
#
# A missing validator is a failure, not a skip. plugins/suite-kit/skills/health
# forbids reporting a skipped check as passing, and a validator that exits 0 when
# it is not installed is exactly that: a check that always passes and never runs.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/suite.repos.json"

command -v check-jsonschema >/dev/null 2>&1 || {
  echo "check-jsonschema is not installed — cannot validate." >&2
  echo "  pip install check-jsonschema" >&2
  exit 1
}

status=0

validate() {
  local instance="$1" schema="$2" label="$3"
  if check-jsonschema --schemafile "$schema" "$instance" >/dev/null 2>&1; then
    echo "= $label"
  else
    echo "! $label" >&2
    check-jsonschema --schemafile "$schema" "$instance" >&2 || true
    status=1
  fi
}

validate "$root/design/tokens.json" "$root/design/tokens.schema.json" "design/tokens.json"
validate "$root/.claude/suite.json" "$root/design/suite.schema.json" ".claude/suite.json"

# Products are cloned as siblings and are not tracked here, so validate whichever
# of them happen to be present rather than requiring a full workspace.
if [ -f "$manifest" ] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    suite="$root/$name/.claude/suite.json"
    if [ -f "$suite" ]; then
      validate "$suite" "$root/design/suite.schema.json" "$name/.claude/suite.json"
    else
      echo "? $name not cloned or not adopted — skipped"
    fi
  done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        print(r["name"])
' "$manifest")
fi

exit $status
