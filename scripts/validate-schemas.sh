#!/usr/bin/env bash
#
# Validate this repo's JSON against its schemas.
#
#   design/tokens.json        against  design/tokens.schema.json
#   .claude/suite.json        against  design/suite.schema.json
#   <product>/.claude/suite.json  ditto, for every product that is cloned
#
#   --require-products   Treat an absent or unadopted product as a failure
#                        instead of a skip.
#
# A missing validator is a failure, not a skip. plugins/suite-kit/skills/health
# forbids reporting a skipped check as passing, and a validator that exits 0 when
# it is not installed is exactly that: a check that always passes and never runs.
#
# The same reasoning drives --require-products. Skipping an uncloned product is
# right in a bare checkout, where the products are not expected. It is wrong
# straight after scripts/bootstrap.sh, where a product that is still missing means
# the bootstrap failed — and "validated every product" would then be a pass over
# a set that was never checked. CI uses the flag; a bare run does not.

set -euo pipefail

require_products=0

for arg in "$@"; do
  case "$arg" in
    --require-products) require_products=1 ;;
    *) echo "usage: ${BASH_SOURCE[0]##*/} [--require-products]" >&2; exit 2 ;;
  esac
done

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
    elif [ "$require_products" -eq 1 ]; then
      echo "! $name has no .claude/suite.json — not cloned, or not adopted" >&2
      status=1
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
