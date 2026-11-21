#!/usr/bin/env bash
#
# Write the suite's GitHub label taxonomy (design/labels.json → github array)
# into .github/labels.json in this repo and in every adopted product.
#
# Each repo's .github/workflows/labels.yml, from the AllesSandro template,
# applies that file to GitHub on every push to main that changes it. So this
# script only writes files: no `gh`, no token. Nothing deletes a label: the
# workflow creates and updates, and a repo may carry labels this suite does not
# govern.
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

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

ROOT="$root" CHECK_ONLY="$check_only" "${PYTHON[@]}" <<'PY'
import json, os, sys

root = os.environ["ROOT"]
check_only = os.environ["CHECK_ONLY"] == "1"
DEST = os.path.join(".github", "labels.json")

with open(os.path.join(root, "design", "labels.json"), encoding="utf-8") as f:
    labels = json.load(f)["github"]
with open(os.path.join(root, "suite.repos.json"), encoding="utf-8") as f:
    repos = [r["name"] for r in json.load(f)["repos"]]

rendered = json.dumps({
    "$comment": [
        "Written by kollektiv's scripts/sync-labels.sh from design/labels.json.",
        "Edit it there. .github/workflows/labels.yml applies this file on push to main.",
    ],
    "labels": [
        {"name": l["name"], "color": l["color"], "description": l["description"]}
        for l in labels
    ],
}, indent=2, ensure_ascii=False) + "\n"

status = 0
changed = 0
skipped = 0


def sync(name, repo_dir):
    global status, changed
    path = os.path.join(repo_dir, DEST)
    try:
        with open(path, encoding="utf-8") as f:
            current = f.read().replace("\r", "")
    except FileNotFoundError:
        current = None
    if current == rendered:
        print("= %s %s up to date" % (name, DEST))
        return
    changed = 1
    if check_only:
        print("! %s %s differs from design/labels.json" % (name, DEST), file=sys.stderr)
        status = 1
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(rendered)
    print("+ %s wrote %s, commit it" % (name, DEST))


sync("kollektiv", root)
for name in repos:
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        print("? %s not cloned, run scripts/bootstrap.sh first" % name, file=sys.stderr)
        status = 1
    elif not os.path.isfile(os.path.join(d, ".copier-answers.yml")):
        print("? %s has not adopted the AllesSandro template, skipped" % name)
        skipped += 1
    else:
        sync(name, d)

if check_only and changed:
    print("run scripts/sync-labels.sh, then commit in each repo", file=sys.stderr)
elif not changed and not status:
    print("no drift" if check_only else "nothing to do")
sys.exit(status)
PY
