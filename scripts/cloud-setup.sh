#!/usr/bin/env bash
#
# Install graphify into a Claude Code cloud session.
#
# This is the one script here that is NOT run from a checkout. It is the body of
# the "Setup script" field in the cloud environment dialog at claude.ai/code:
# paste it there, because that field is the only thing that runs before Claude
# Code launches. The copy in this repo is the reviewable master, so the script
# that provisions every cloud session is not config that exists nowhere.
#
# Why it exists. Konnekt's root CLAUDE.md told agents to reach for `graphify`,
# and its .claude/settings.json binds `graphify hook-guard` to PreToolUse, but
# the install line read `pipx install graphify`. There is no `graphify` on PyPI;
# the distribution is `graphifyy` and the console script it installs is
# `graphify`. So the documented command failed everywhere, cloud and local
# alike, and session after session recorded "graphify is not installed in this
# container" (Konnekt agent_docs/HEALTH_LOG.md). The fix is a correct package
# name in an environment that actually runs it.
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

# Pinned for the same reason aislop is pinned in every product's CLAUDE.md: an
# unattended environment that silently moves to a new major is an environment
# nobody chose. `hook-guard`, which Konnekt binds to PreToolUse, is not in
# `graphify --help`, so it is not a surface upstream has promised to keep.
GRAPHIFY_VERSION="0.9.62"

# graphify needs Python 3.10 or newer (its own requires-python).
readonly MIN_PYTHON_MINOR=10

# Progress goes to stderr, not stdout: the install functions return the path
# they installed to by printing it, and a log line on the same stream lands
# inside the captured value.
log() { echo "[cloud-setup] $*" >&2; }

fail() {
  echo "[cloud-setup] $*" >&2
  exit 1
}

# uv installs a tool into its own environment and drops the console scripts in
# ~/.local/bin. Preferred when present because it resolves and unpacks the
# tree-sitter wheel set far faster than pip, which matters against the five
# minute budget.
install_with_uv() {
  log "installing graphifyy==$GRAPHIFY_VERSION with uv"
  uv tool install "graphifyy==$GRAPHIFY_VERSION"
  printf '%s/.local/bin/graphify' "$HOME"
}

# Fallback for an environment without uv. A dedicated venv rather than a
# --break-system-packages install into the system interpreter: graphify pulls in
# a large pinned dependency set, and standing that on top of whatever the image
# already ships is how an unrelated tool breaks later.
install_with_venv() {
  local venv=/opt/graphify

  command -v python3 >/dev/null 2>&1 || fail "no python3 and no uv; cannot install graphify"

  python3 - <<PY || fail "graphify needs Python 3.$MIN_PYTHON_MINOR or newer"
import sys
sys.exit(0 if sys.version_info >= (3, $MIN_PYTHON_MINOR) else 1)
PY

  log "installing graphifyy==$GRAPHIFY_VERSION into $venv"
  python3 -m venv "$venv"
  "$venv/bin/pip" install --quiet --upgrade pip
  "$venv/bin/pip" install --quiet "graphifyy==$GRAPHIFY_VERSION"
  printf '%s/bin/graphify' "$venv"
}

main() {
  local installed

  if command -v uv >/dev/null 2>&1; then
    installed="$(install_with_uv)"
  else
    installed="$(install_with_venv)"
  fi

  [ -x "$installed" ] || fail "install reported success but $installed is not executable"

  # Konnekt's committed .claude/settings.json calls the bare name `graphify`,
  # and so does its CLAUDE.md. Neither ~/.local/bin nor /opt/graphify/bin is on
  # PATH for a non-login shell, which is what a PreToolUse hook gets, so the
  # hooks would keep missing even with the tool installed. Upstream's own
  # `graphify claude install` sidesteps this by writing an absolute path into
  # the hook; a symlink on the default PATH fixes it once here instead, and
  # leaves the repo's config identical to what it is on a laptop.
  log "linking $installed into /usr/local/bin"
  mkdir -p /usr/local/bin
  ln -sf "$installed" /usr/local/bin/graphify

  # Verified two ways on purpose. The absolute call proves the install runs at
  # all; the bare call proves the symlink is what a hook will find. The second
  # runs under an explicit standard PATH rather than this script's own, because
  # the environment dialog's shell is not the shell a PreToolUse hook gets, and
  # checking the wrong one is how this ends up passing here and missing there.
  /usr/local/bin/graphify --version >/dev/null 2>&1 ||
    fail "/usr/local/bin/graphify is not runnable"

  env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    graphify --version >/dev/null 2>&1 ||
    fail "graphify does not resolve by bare name on a standard PATH"

  log "installed $(/usr/local/bin/graphify --version)"
  log "the graph is built on demand: run 'graphify update .' in a repo that wants one"
}

main "$@"
