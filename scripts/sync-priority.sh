#!/usr/bin/env bash
#
# Vendor the issue-priority workflow and the priority question into each product.
#
# A GitHub issue form applies only the static `labels:` in its front matter; a
# dropdown answer lands as text in the body. .github/workflows/issue-priority.yml
# reads that answer back out and applies the p* label it means, and it runs in
# every repo in suite.repos.json plus this one. Kommands has carried a copy of
# it since 2026-08-20 with a header saying this script vendors it. This is that
# script, written after the fact; until now nothing compared the copies.
#
# Two things are vendored, and both are rendered from design/labels.json's
# priorityForm so they cannot disagree:
#
#   .github/workflows/issue-priority.yml   copied whole. The master is this repo's
#                                          own copy, since it runs here too. Its
#                                          PRIORITY_MAP block between the
#                                          `suite:priority-map` markers, and its
#                                          HEADING, are checked against labels.json.
#   .github/ISSUE_TEMPLATE/*.yml           only the block between the
#                                          `>>> suite:priority` and `<<< suite:priority`
#                                          markers is touched. A form without the
#                                          markers is a form that has not adopted
#                                          the question, and nothing is inserted
#                                          into a file a human wrote.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product that has never adopted this as a failure
#                       instead of a skip.
#
# The split follows sync-runner.sh: not adopted is work not started and a skip;
# adopted and stale is a workflow applying last month's rubric, and a failure.

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

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

ROOT="$root" CHECK_ONLY="$check_only" REQUIRE_VENDORED="$require_vendored" "${PYTHON[@]}" <<'PY'
import glob, json, os, sys

root = os.environ["ROOT"]
check_only = os.environ["CHECK_ONLY"] == "1"
require_vendored = os.environ["REQUIRE_VENDORED"] == "1"

WORKFLOW = ".github/workflows/issue-priority.yml"
FORMS = ".github/ISSUE_TEMPLATE"
FORM_OPEN = "# >>> suite:priority. Vendored from kollektiv by scripts/sync-priority.sh. Edit it there."
FORM_CLOSE = "# <<< suite:priority"
MAP_OPEN = "# >>> suite:priority-map"
MAP_CLOSE = "# <<< suite:priority-map"


def load(path):
    with open(path, encoding="utf-8") as f:
        return f.read().replace("\r", "")


def fail(msg):
    global status
    print("! " + msg, file=sys.stderr)
    status = 1


with open(os.path.join(root, "design", "labels.json"), encoding="utf-8") as f:
    form = json.load(f)["priorityForm"]
with open(os.path.join(root, "suite.repos.json"), encoding="utf-8") as f:
    repos = [r["name"] for r in json.load(f)["repos"]]


def render_form_block(indent):
    """The dropdown, rendered at the indentation the form's body list uses."""
    pad = " " * indent
    lines = [
        pad + FORM_OPEN,
        pad + "- type: dropdown",
        pad + "  id: priority",
        pad + "  attributes:",
        pad + "    label: " + form["heading"],
        pad + "    description: " + form["description"],
        pad + "    options:",
    ]
    for o in form["options"]:
        lines.append(pad + "      - '" + o["text"] + "'")
    lines += [
        pad + "  validations:",
        pad + "    required: true",
        pad + FORM_CLOSE,
    ]
    return "\n".join(lines)


def render_map_block(indent):
    pad = " " * indent
    lines = [pad + MAP_OPEN, pad + "PRIORITY_MAP: |"]
    for o in form["options"]:
        lines.append(pad + "  " + o["text"].split(":")[0] + ": " + o["label"])
    lines.append(pad + MAP_CLOSE)
    return "\n".join(lines)


def find_block(text, opener, closer):
    """(start, end, indent) of the marked block, or None. end is exclusive and
    includes the closing marker's line."""
    lines = text.split("\n")
    start = None
    for i, line in enumerate(lines):
        if line.strip() == opener:
            start = i
        elif start is not None and line.strip() == closer:
            return start, i + 1, len(lines[start]) - len(lines[start].lstrip())
    return None


def replace_block(text, opener, closer, rendered):
    found = find_block(text, opener, closer)
    lines = text.split("\n")
    s, e, _ = found
    return "\n".join(lines[:s] + rendered.split("\n") + lines[e:])


status = 0
changed = 0
skipped = 0

# The master first: it runs here, and it is what the products get. Its map and
# heading are rendered from labels.json, so a labels.json edit shows up here as
# drift until the workflow is regenerated.
master_path = os.path.join(root, WORKFLOW)
master = load(master_path)
found = find_block(master, MAP_OPEN, MAP_CLOSE)
if found is None:
    fail("%s has no %s block" % (WORKFLOW, MAP_OPEN))
    sys.exit(1)
rendered_map = render_map_block(found[2])
heading_line = "HEADING: '" + form["heading"] + "'"
if "\n".join(master.split("\n")[found[0]:found[1]]) != rendered_map or heading_line not in master:
    if check_only:
        fail("%s does not match design/labels.json priorityForm" % WORKFLOW)
    else:
        master = replace_block(master, MAP_OPEN, MAP_CLOSE, rendered_map)
        import re
        master = re.sub(r"HEADING: '[^']*'", heading_line, master, count=1)
        with open(master_path, "w", encoding="utf-8") as f:
            f.write(master)
        print("+ kollektiv regenerated %s from labels.json — commit it" % WORKFLOW)
        changed = 1
else:
    print("= kollektiv %s matches labels.json" % WORKFLOW)

for name in repos:
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        print("? %s not cloned — run scripts/bootstrap.sh first" % name, file=sys.stderr)
        status = 1
        continue

    forms = sorted(glob.glob(os.path.join(d, FORMS, "*.yml")))
    forms = [p for p in forms if os.path.basename(p) != "config.yml"]
    adopted_forms = [p for p in forms if find_block(load(p), FORM_OPEN, FORM_CLOSE)]
    dest = os.path.join(d, WORKFLOW)

    if not adopted_forms and not os.path.isfile(dest):
        if require_vendored:
            fail("%s has no %s and no form carries the priority question" % (name, WORKFLOW))
            changed = 1
        else:
            print("? %s has not adopted the priority question — skipped" % name)
            skipped += 1
        continue

    product_changed = 0

    if os.path.isfile(dest) and load(dest) == master:
        pass
    elif check_only:
        if os.path.isfile(dest):
            fail("%s has drifted from %s" % (name, WORKFLOW))
        else:
            fail("%s forms ask the question but %s is missing" % (name, WORKFLOW))
        changed = 1
        product_changed = 1
    else:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(master)
        print("+ %s updated %s — commit it" % (name, WORKFLOW))
        changed = 1
        product_changed = 1

    # Every form, not just the adopted ones: a form without the question is
    # reported, because a repo with the workflow and one form that never asks
    # is a repo where that form's issues always arrive unprioritised.
    for path in forms:
        rel = os.path.relpath(path, d).replace(os.sep, "/")
        text = load(path)
        found = find_block(text, FORM_OPEN, FORM_CLOSE)
        if found is None:
            print("? %s %s does not carry the priority question" % (name, rel))
            continue
        rendered = render_form_block(found[2])
        if "\n".join(text.split("\n")[found[0]:found[1]]) == rendered:
            continue
        if check_only:
            fail("%s %s priority block has drifted" % (name, rel))
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(replace_block(text, FORM_OPEN, FORM_CLOSE, rendered))
            print("+ %s updated %s — commit it" % (name, rel))
        changed = 1
        product_changed = 1

    if not product_changed:
        print("= %s already up to date" % name)

if check_only:
    if changed:
        print("run scripts/sync-priority.sh to update, then commit in each product", file=sys.stderr)
    elif status:
        print("no drift among the products present, but the workspace is incomplete", file=sys.stderr)
    elif skipped:
        noun = "1 product has" if skipped == 1 else "%d products have" % skipped
        print("no drift among the products asking the question; %s not adopted it" % noun)
    else:
        print("no drift")
elif not changed:
    print("nothing to do")

sys.exit(status)
PY
