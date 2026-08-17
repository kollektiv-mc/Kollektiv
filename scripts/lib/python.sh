#!/usr/bin/env bash
#
# Resolve a Python 3 interpreter into the PYTHON array.
#
# Every script here reaches for Python to read a manifest, and `python3` is not a
# universal spelling: a stock Windows install (python.org or the Store) puts
# `python` and the `py` launcher on PATH and no `python3` at all. Hard-coding
# `python3` made these scripts unrunnable there, which mattered more than it
# looks: sync-tokens.sh --check is the only thing that can detect token drift,
# because a product's generator reads its own vendored copy and so regenerates
# cleanly whether or not that copy is stale. A drift check that cannot run is
# not a drift check that passes.
#
# Callers use the array so a two-word interpreter (`py -3`) stays one argument
# vector rather than relying on word-splitting:
#
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
#   require_python
#   "${PYTHON[@]}" -c 'import json' ...
#
# CI is unaffected: ubuntu resolves `python3` on the first candidate.

# Set on success. Declared here so `set -u` cannot trip on it before resolution.
PYTHON=()

# Print nothing, return 0 and fill PYTHON, or return 1 if no Python 3 is found.
resolve_python() {
  local candidate

  # `python` is probed for its major version rather than trusted. On systems
  # where it is still Python 2 the scripts would otherwise fail somewhere in the
  # middle of a heredoc, which is a much worse error than failing here.
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 &&
      "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
      PYTHON=("$candidate")
      return 0
    fi
  done

  # The Windows launcher, which selects the interpreter itself. Last because it
  # exists only there, and `-3` is what makes the choice explicit.
  if command -v py >/dev/null 2>&1 && py -3 -c '' 2>/dev/null; then
    PYTHON=(py -3)
    return 0
  fi

  return 1
}

# Same, but exits with the message the scripts used to print inline.
require_python() {
  resolve_python || {
    echo "python3 is required to read the manifest (tried python3, python, py -3)" >&2
    exit 1
  }
}

# Run Python and strip CRs from its output. Use this for anything a shell
# variable will hold.
#
# Python opens stdout in text mode, so on Windows every `print` emits \r\n. That
# CR rides into the variable and is invisible in an echo: `dir="$root/$name"`
# became "…/Konnekt<CR>", which is not a directory that exists, so sync-runner.sh
# reported both products as "not cloned" on a workspace where both were present.
# The same CR landed on sync-tokens.sh's `role`, where `[ "$role" = "source" ]`
# could then never match — harmless while every repo is a consumer, and a silent
# self-vendoring if one ever is not.
python_lines() {
  "${PYTHON[@]}" "$@" | tr -d '\r'
}
