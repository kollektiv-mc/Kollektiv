#!/usr/bin/env bash
#
# Check this repo's own manifests: that each parses, that the two suite-kit
# version declarations agree, and that the check runner is valid Python.
#
# These were three inline `python3 -c ...` entries in .claude/suite.json and two
# more, with a different file list, in .github/workflows/ci.yml. That was the
# same drift this suite exists to prevent, and it had already happened: the
# manifest checked design/labels.json and CI checked design/tokens.json, so each
# file was validated in exactly one of the two places.
#
# Inlining them also made them unrunnable off Linux. A `run` string in a manifest
# cannot source lib/python.sh, so `python3` was hard-coded, and on a stock Windows
# install three of this repo's six checks reported as unavailable. A script can
# resolve an interpreter; a JSON string cannot.
#
# Reported per item rather than as one verdict, the way validate-schemas.sh does
# it, so a failure still names what failed.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

status=0

# Every manifest in the repo, not the two overlapping subsets this replaced.
manifests=(
  suite.repos.json
  .claude-plugin/marketplace.json
  plugins/suite-kit/.claude-plugin/plugin.json
  .claude/suite.json
  design/labels.json
  design/tokens.json
)

for f in "${manifests[@]}"; do
  if "${PYTHON[@]}" -m json.tool "$root/$f" > /dev/null 2>&1; then
    echo "= $f parses"
  else
    echo "! $f is not valid JSON" >&2
    "${PYTHON[@]}" -m json.tool "$root/$f" > /dev/null || true
    status=1
  fi
done

# The pair a version bump has to keep in step. A plugin whose marketplace entry
# advertises a different version is installed at one and reports the other.
if "${PYTHON[@]}" - "$root" <<'PY'
import json, sys
root = sys.argv[1]
a = json.load(open(root + "/.claude-plugin/marketplace.json"))["plugins"][0]["version"]
b = json.load(open(root + "/plugins/suite-kit/.claude-plugin/plugin.json"))["version"]
if a != b:
    sys.exit("marketplace %s != plugin %s" % (a, b))
PY
then
  echo "= suite-kit version matches across both manifests"
else
  echo "! suite-kit version differs between marketplace.json and plugin.json" >&2
  status=1
fi

# Checked here rather than only by sync-runner.sh, which validates it before
# propagating: a broken runner should redden this repo's own build too, not just
# the next vendoring run.
if "${PYTHON[@]}" -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' \
  "$root/plugins/suite-kit/suite-check.py" 2>/dev/null; then
  echo "= suite-check.py is valid Python"
else
  echo "! suite-check.py is not valid Python" >&2
  "${PYTHON[@]}" -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' \
    "$root/plugins/suite-kit/suite-check.py" || true
  status=1
fi

exit $status
