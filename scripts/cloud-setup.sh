#!/usr/bin/env bash
#
# Provision a Claude Code cloud session with the tools its checks reach for.
#
# This is the one script here that is NOT run from a checkout. It is the body of
# the "Setup script" field in the cloud environment dialog at claude.ai/code:
# paste it there, because that field is the only thing that runs before Claude
# Code launches. The copy in this repo is the reviewable master, so the script
# that provisions every cloud session is not config that exists nowhere.
#
# It installs two Python tools, for the same underlying reason in both cases: a
# tool a session is told to use, which is not there, fails quietly.
#
# graphify. Konnekt's root CLAUDE.md told agents to reach for it, and its
# .claude/settings.json binds `graphify hook-guard` to PreToolUse, but the
# install line read `pipx install graphify`. There is no `graphify` on PyPI; the
# distribution is `graphifyy` and the console script it installs is `graphify`.
# So the documented command failed everywhere, and session after session
# recorded "graphify is not installed in this container" (Konnekt
# agent_docs/HEALTH_LOG.md).
#
# ruff. aislop's Python formatting and lint engines run only when a ruff binary
# is on PATH, and with none they report `[ok] 0 issues` rather than saying they
# did not run. Every repo's .claude/suite.json runs `npx --yes aislop@0.16.0 ci`,
# so without ruff here the health check reports a gate that scored nothing as a
# pass, which is the one result this suite refuses to produce. CI pins ruff for
# exactly this reason (plugins/suite-kit/workflows/aislop.yml says so, and
# records Konnekt hitting it in the mirror image); a cloud session is the other
# place those checks run, so it gets the same pin.
#
# What it deliberately does not do: build the graph. `graphify update .` is an
# AST pass over a whole tree, and graphify earns its keep on navigation
# questions rather than on every session. Konnekt's CLAUDE.md now says to build
# the graph on demand, so this script provisions the tool and stops.
#
# Setup scripts run as root on Ubuntu, must finish inside about five minutes,
# and their result is snapshotted: later sessions start from the filesystem
# image and skip the script entirely. It re-runs when the script or the
# environment's allowed hosts change, and when the snapshot expires after about
# a week, so everything below is idempotent.
#
# It is also deliberately fatal on failure. A half-provisioned environment gets
# snapshotted and then every session inherits the gap silently, which is the
# exact failure this replaces. Better to redden the environment build.

set -euo pipefail

# Pinned because an unattended environment that silently moves to a new major is
# an environment nobody chose. `hook-guard`, which Konnekt binds to PreToolUse,
# is not in `graphify --help`, so it is not a surface upstream has promised to
# keep.
GRAPHIFY_VERSION="0.9.62"

# This has to be a literal, because a setup script runs before any checkout and
# so cannot read the pin out of a workflow. The workflow is still the source of
# truth: suite-probe.py reads `ruff==` from .github/workflows/ and skips the
# aislop check when what is installed does not match. So a divergence between
# this line and CI surfaces as a named skip rather than as a quiet disagreement,
# which is the whole reason the check exists.
RUFF_VERSION="0.16.7"

# graphify needs Python 3.10 or newer (its own requires-python).
readonly MIN_PYTHON_MINOR=10

# Progress goes to stderr, not stdout: the install helpers return the path they
# installed to by printing it, and a log line on the same stream lands inside
# the captured value.
log() { echo "[cloud-setup] $*" >&2; }

fail() {
  echo "[cloud-setup] $*" >&2
  exit 1
}

# uv installs a tool into its own environment and drops the console scripts in
# ~/.local/bin. Preferred when present because it resolves and unpacks a wheel
# set far faster than pip, which matters against the five minute budget.
install_with_uv() {
  local spec="$1" script="$2"
  log "installing $spec with uv"
  uv tool install "$spec"
  printf '%s/.local/bin/%s' "$HOME" "$script"
}

# Fallback for an environment without uv. A dedicated venv per tool rather than
# a --break-system-packages install into the system interpreter: graphify pulls
# in a large pinned dependency set, and standing that on top of whatever the
# image already ships is how an unrelated tool breaks later.
install_with_venv() {
  local spec="$1" script="$2" venv="/opt/$2"

  command -v python3 >/dev/null 2>&1 || fail "no python3 and no uv; cannot install $spec"

  python3 - <<PY || fail "$spec needs Python 3.$MIN_PYTHON_MINOR or newer"
import sys
sys.exit(0 if sys.version_info >= (3, $MIN_PYTHON_MINOR) else 1)
PY

  log "installing $spec into $venv"
  python3 -m venv "$venv"
  "$venv/bin/pip" install --quiet --upgrade pip
  "$venv/bin/pip" install --quiet "$spec"
  printf '%s/bin/%s' "$venv" "$script"
}

# Install one pinned tool and put its console script on the default PATH.
#
# The symlink is the part that matters. Konnekt's committed .claude/settings.json
# calls the bare name `graphify`, and aislop spawns the bare name `ruff`; neither
# ~/.local/bin nor /opt/<tool>/bin is on PATH for a non-login shell, which is
# what a PreToolUse hook and a subprocess both get. Upstream's own
# `graphify claude install` sidesteps this by writing an absolute path into the
# hook; a symlink on the default PATH fixes it once here instead, and leaves
# every repo's committed config identical to what it is on a laptop.
provision() {
  local spec="$1" script="$2" installed

  if command -v uv >/dev/null 2>&1; then
    installed="$(install_with_uv "$spec" "$script")"
  else
    installed="$(install_with_venv "$spec" "$script")"
  fi

  [ -x "$installed" ] || fail "install reported success but $installed is not executable"

  log "linking $installed into /usr/local/bin"
  mkdir -p /usr/local/bin
  ln -sf "$installed" "/usr/local/bin/$script"

  # Verified two ways on purpose. The absolute call proves the install runs at
  # all; the bare call proves the symlink is what a hook or a subprocess will
  # find. The second runs under an explicit standard PATH rather than this
  # script's own, because the environment dialog's shell is not the shell either
  # of those gets, and checking the wrong one is how this ends up passing here
  # and missing there.
  "/usr/local/bin/$script" --version >/dev/null 2>&1 ||
    fail "/usr/local/bin/$script is not runnable"

  env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$script" --version >/dev/null 2>&1 ||
    fail "$script does not resolve by bare name on a standard PATH"

  log "installed $("/usr/local/bin/$script" --version)"
}

main() {
  provision "graphifyy==$GRAPHIFY_VERSION" graphify
  provision "ruff==$RUFF_VERSION" ruff

  log "the graph is built on demand: run 'graphify update .' in a repo that wants one"
}

main "$@"
