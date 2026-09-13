#!/usr/bin/env bash
#
# Copy the suite's aislop policy into each cloned product.
#
# Same shape as sync-runner.sh, for the reason .aislop/base.yml states at its
# top: the rules a finding is judged by should be the same in every repo, and a
# policy written down three times is a policy waiting to fork. A product's own
# .aislop/config.yml extends the vendored copy and carries only what is true of
# that one tree, its size ratchet.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product that has never adopted aislop as a
#                       failure instead of a skip.
#
# The adoption marker is the product's own .aislop/config.yml: a product without
# one has not adopted aislop at all, which is work not started and a skip. A
# product that has one and no base.yml, or a stale one, or a config that does
# not extend it, is a gate running rules other than the suite's, and that is a
# failure whether or not --require-vendored is set. The third case is the one
# worth spelling out: a vendored file nothing reads is exactly the "check that
# never runs" this suite exists to stamp out.

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
source_file="$root/.aislop/base.yml"
vendored_path=".aislop/base.yml"
config_path=".aislop/config.yml"

[ -f "$manifest" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }
[ -f "$source_file" ] || { echo "no $vendored_path at $root" >&2; exit 1; }

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

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

  if [ ! -f "$dir/$config_path" ]; then
    if [ "$require_vendored" -eq 1 ]; then
      echo "! $name has no $config_path — aislop not adopted" >&2
      status=1
      changed=1
    else
      echo "? $name has no $config_path — aislop not adopted yet, skipped"
      skipped=$((skipped + 1))
    fi
    continue
  fi

  dest="$dir/$vendored_path"

  # The config has to read the base or the base is decoration. Checked in both
  # modes, because writing the file cannot fix a config that ignores it.
  if ! grep -qE '^extends:[[:space:]]*\./base\.yml[[:space:]]*$' "$dir/$config_path"; then
    echo "! $name $config_path does not extend ./base.yml — the suite policy is not applied" >&2
    status=1
    changed=1
  fi

  # CRs stripped before comparing, for the reason sync-tokens.sh spells out.
  if [ -f "$dest" ] && cmp -s <(tr -d '\r' < "$source_file") <(tr -d '\r' < "$dest"); then
    echo "= $name already up to date"
    continue
  fi

  if [ "$check_only" -eq 1 ]; then
    if [ -f "$dest" ]; then
      echo "! $name has drifted from $vendored_path" >&2
    else
      echo "! $name has $config_path but no $vendored_path" >&2
    fi
    status=1
    changed=1
    continue
  fi

  mkdir -p "$dir/.aislop"
  cp "$source_file" "$dest"
  echo "+ $name updated $vendored_path — commit it"
  changed=1
done < <(python_lines -c '
import json, sys
with open(sys.argv[1]) as f:
    for r in json.load(f)["repos"]:
        print(r["name"])
' "$manifest")

if [ "$check_only" -eq 1 ]; then
  if [ "$changed" -ne 0 ]; then
    echo "run scripts/sync-aislop.sh to update, then commit in each product" >&2
  elif [ "$status" -ne 0 ]; then
    echo "no drift among the products present, but the workspace is incomplete" >&2
  elif [ "$skipped" -ne 0 ]; then
    if [ "$skipped" -eq 1 ]; then noun="1 product has"; else noun="$skipped products have"; fi
    echo "no drift among the products carrying the policy; $noun not adopted aislop"
  else
    echo "no drift"
  fi
elif [ "$changed" -eq 0 ]; then
  echo "nothing to do"
fi

exit $status
