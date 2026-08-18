#!/usr/bin/env bash
#
# Check that every repo in the suite still participates in the shared machinery.
#
# The other scripts each check one artifact: sync-tokens.sh the token source,
# sync-runner.sh the check runner, validate-schemas.sh the manifests. This one
# checks the things a repo has to get right for those to mean anything, and that
# nothing else looks at:
#
#   permissions   .claude/settings.json carries the deny/ask floor from
#                 docs/conventions.md. Enforced by review until now, which is
#                 the weakest place to enforce something that exists for
#                 unattended agents — the sessions with nobody there to decline
#                 a prompt are exactly the ones no reviewer sees.
#   tokens        the path .claude/suite.json names as tokens.sourceFile exists.
#   roadmap       the path it names as roadmap exists.
#   cwd           every health.commands[].cwd directory exists. A command whose
#                 cwd is gone is reported by the runner as a skip, and a skip
#                 nobody reads is how a check stops running without anyone
#                 noticing.
#
# Deliberately not re-checked here, because each already has an owner: manifest
# presence and schema validity (validate-schemas.sh), runner presence and drift
# (sync-runner.sh), token drift (sync-tokens.sh). Two scripts reporting the same
# finding is how they drift apart.
#
#   --require-products   Treat an absent or unadopted product as a failure
#                        instead of a skip.
#
# Same split as validate-schemas.sh and for the same reason: skipping an uncloned
# product is right in a bare checkout, and wrong straight after bootstrap.sh,
# where a missing product means the bootstrap failed and "checked every repo"
# would be a pass over a set that was never checked.

set -euo pipefail

require_products=0

for arg in "$@"; do
  case "$arg" in
    --require-products) require_products=1 ;;
    *) echo "usage: ${BASH_SOURCE[0]##*/} [--require-products]" >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to read the manifests" >&2; exit 1
}

ROOT="$root" REQUIRE_PRODUCTS="$require_products" python3 <<'PY'
import json, os, sys

root = os.environ["ROOT"]
require_products = os.environ["REQUIRE_PRODUCTS"] == "1"

# docs/conventions.md § Required permissions block. Not negotiable per repo,
# which is the whole reason it can be checked mechanically at all.
FLOOR = {
    "deny": ["Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"],
    "ask": ["Bash(git push:*)"],
}

status = 0
skipped = 0
checked = 0


def fail(msg):
    global status
    print("! " + msg, file=sys.stderr)
    status = 1


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def check_repo(label, repo_dir):
    """Every check runs. One failure does not cancel the rest — health/SKILL.md's
    rule, for the same reason: they are independent findings."""
    global checked
    checked += 1

    suite_path = os.path.join(repo_dir, ".claude", "suite.json")
    settings_path = os.path.join(repo_dir, ".claude", "settings.json")

    if os.path.isfile(settings_path):
        try:
            perms = load(settings_path).get("permissions", {})
        except json.JSONDecodeError as e:
            fail("%s .claude/settings.json is not valid JSON: %s" % (label, e))
            perms = None
        if perms is not None:
            for section, required in FLOOR.items():
                have = perms.get(section) or []
                missing = [e for e in required if e not in have]
                if missing:
                    fail("%s permissions.%s is missing %s" % (label, section, ", ".join(missing)))
                else:
                    print("= %s permissions.%s" % (label, section))
    else:
        fail("%s has no .claude/settings.json — no permissions floor at all" % label)

    try:
        suite = load(suite_path)
    except (OSError, json.JSONDecodeError) as e:
        fail("%s .claude/suite.json unreadable: %s" % (label, e))
        return

    def path_check(rel, what):
        if rel is None:
            return
        if os.path.exists(os.path.join(repo_dir, rel)):
            print("= %s %s (%s)" % (label, what, rel))
        else:
            fail("%s %s points at %s, which does not exist" % (label, what, rel))

    path_check(suite.get("roadmap"), "roadmap")
    path_check((suite.get("tokens") or {}).get("sourceFile"), "tokens.sourceFile")

    for cmd in suite.get("health", {}).get("commands", []):
        cwd = cmd.get("cwd")
        if cwd is None:
            continue
        if os.path.isdir(os.path.join(repo_dir, cwd)):
            print("= %s health command %r cwd (%s)" % (label, cmd.get("name"), cwd))
        else:
            fail("%s health command %r has cwd %s, which is not a directory"
                 % (label, cmd.get("name"), cwd))


check_repo("kollektiv", root)

manifest = os.path.join(root, "suite.repos.json")
if os.path.isfile(manifest):
    for repo in load(manifest)["repos"]:
        name = repo["name"]
        d = os.path.join(root, name)
        if os.path.isfile(os.path.join(d, ".claude", "suite.json")):
            check_repo(name, d)
        elif require_products:
            fail("%s not cloned, or not adopted" % name)
        else:
            print("? %s not cloned or not adopted — skipped" % name)
            skipped += 1
else:
    fail("no suite.repos.json at %s" % root)

# A clean run over a set where nothing was compared is the lie this suite exists
# to stamp out. Say what was actually checked.
if status == 0:
    if skipped:
        print("participation ok for %d repo(s); %d not checked" % (checked, skipped))
    else:
        print("participation ok for %d repo(s)" % checked)

sys.exit(status)
PY
