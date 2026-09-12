#!/usr/bin/env bash
#
# Vendor the issue-priority workflow and the priority dropdown it reads into
# each cloned product, and check that the two still agree with each other and
# with design/labels.json.
#
# Three things move together here, and that is the reason this is its own
# script rather than a third file in sync-workflows.sh:
#
#   plugins/suite-kit/workflows/issue-priority.yml
#       The workflow. On every issue opened, it reads the dropdown answer back
#       out of the body and applies the matching p* label, or says that none
#       was given. Copied whole to .github/workflows/issue-priority.yml.
#   plugins/suite-kit/issue-forms/priority.yml
#       The dropdown. Copied into every issue form in .github/ISSUE_TEMPLATE/
#       between a `# >>> suite:priority` line and a `# <<< suite:priority` line
#       the form carries. The markers are the product's; what sits between
#       them is this file.
#   design/labels.json
#       Where p0-p3 are defined. The workflow's map from a dropdown option to a
#       label is asserted against it, so the map is a copy that cannot drift
#       silently rather than a second source.
#
# A dropdown answer the workflow cannot read is the failure this exists to
# catch: it is silent everywhere else, and shows up as issues that mirror into
# Linear at priority None. So before anything is copied, the heading the
# workflow looks for is checked against the dropdown's label, every option's
# leading word against the map, and every mapped label against labels.json.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a product that has not adopted the block as a
#                       failure instead of a skip.
#
# Adoption is a human step, because only a person knows where in a form the
# question belongs: add the two marker lines to every form, then run this. A
# product with neither the workflow nor a marked form is reported and skipped.
# A product with one but not the other is a failure whatever the flags say,
# because a workflow with nothing to read flags every issue, and a form with
# nothing reading it asks a question that goes nowhere.

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
[ -f "$root/suite.repos.json" ] || { echo "no suite.repos.json at $root" >&2; exit 1; }

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

# The work is in Python because it is text surgery on YAML, which bash does
# badly, and because the consistency checks are the same code on every
# platform the suite's scripts run on.
"${PYTHON[@]}" - "$root" "$check_only" "$require_vendored" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
check_only = sys.argv[2] == "1"
require_vendored = sys.argv[3] == "1"

WORKFLOW_SRC = root / "plugins/suite-kit/workflows/issue-priority.yml"
BLOCK_SRC = root / "plugins/suite-kit/issue-forms/priority.yml"
LABELS_SRC = root / "design/labels.json"
WORKFLOW_DEST = ".github/workflows/issue-priority.yml"
FORMS_DIR = ".github/ISSUE_TEMPLATE"

# `suite:priority` followed by a dot, a space or the end of the line, so the
# workflow's own `suite:priority-map` markers never match.
START = re.compile(r"^\s*# >>> suite:priority(?:[.\s]|$)")
END = re.compile(r"^\s*# <<< suite:priority\s*$")


def read(path):
    # CRs stripped for the reason sync-tokens.sh spells out: the products
    # normalise line endings independently.
    return path.read_text(encoding="utf-8").replace("\r", "")


def fail(message):
    print(f"! {message}", file=sys.stderr)


for path in (WORKFLOW_SRC, BLOCK_SRC, LABELS_SRC):
    if not path.is_file():
        print(f"no {path.relative_to(root)} at {root}", file=sys.stderr)
        sys.exit(1)

# --- the three sources must agree before anything is copied ---------------

block_text = read(BLOCK_SRC)
block = block_text.splitlines()
workflow_text = read(WORKFLOW_SRC)

heading = re.search(r"^\s*label:\s*(.+?)\s*$", block_text, re.M)
options = re.findall(r"^\s*-\s*'([^':]+):", block_text, re.M)
wanted = re.search(r"^\s*HEADING:\s*'([^']*)'", workflow_text, re.M)
mapping = re.search(
    r"# >>> suite:priority-map\n(.*?)# <<< suite:priority-map", workflow_text, re.S
)

problems = []
if heading is None:
    problems.append("the dropdown block has no label:")
if not options:
    problems.append("the dropdown block has no options of the form 'Word: ...'")
if wanted is None:
    problems.append("the workflow has no HEADING: line")
if mapping is None:
    problems.append("the workflow has no suite:priority-map block")

if not problems:
    heading = heading.group(1).strip().strip("'\"")
    wanted = wanted.group(1)
    if heading != wanted:
        problems.append(
            f"the workflow looks for the heading {wanted!r} but the dropdown is labelled {heading!r}"
        )
    pairs = re.findall(r"^\s*([^:\s][^:]*):\s*(\S+)\s*$", mapping.group(1), re.M)
    pairs = [(k, v) for k, v in pairs if k != "PRIORITY_MAP"]
    mapped = {k: v for k, v in pairs}
    if set(mapped) != set(options):
        problems.append(
            f"the map covers {sorted(mapped)} but the dropdown offers {sorted(options)}"
        )
    labels = {entry["name"] for entry in json.loads(read(LABELS_SRC))["github"]}
    for option, label in mapped.items():
        if not re.fullmatch(r"p[0-3]", label) or label not in labels:
            problems.append(
                f"{option!r} maps to {label!r}, which design/labels.json does not define as a priority"
            )

if problems:
    for problem in problems:
        fail(problem)
    print("the priority sources disagree — fix them here before syncing", file=sys.stderr)
    sys.exit(1)


# --- then each product ------------------------------------------------------

def splice(text, block):
    """The form text with the block between its markers replaced, or None if
    the form does not carry both markers in order."""
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if START.match(line)), None)
    if start is None:
        return None
    end = next((i for i in range(start + 1, len(lines)) if END.match(lines[i])), None)
    if end is None:
        return None
    out = lines[: start + 1] + block + lines[end:]
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


with open(root / "suite.repos.json", encoding="utf-8") as f:
    names = [r["name"] for r in json.load(f)["repos"]]

status = 0
changed = 0
skipped = 0

for name in names:
    product = root / name
    if not product.is_dir():
        print(f"? {name} not cloned — run scripts/bootstrap.sh first", file=sys.stderr)
        status = 1
        continue

    workflow_dest = product / WORKFLOW_DEST
    forms_dir = product / FORMS_DIR
    forms = sorted(p for p in forms_dir.glob("*.yml") if p.name != "config.yml") if forms_dir.is_dir() else []
    marked = [p for p in forms if splice(read(p), block) is not None]
    unmarked = [p for p in forms if p not in marked]

    has_workflow = workflow_dest.is_file()

    if not has_workflow and not marked:
        if require_vendored:
            fail(f"{name} has not adopted the priority block")
            status = 1
            changed = 1
        else:
            print(f"? {name} has no {WORKFLOW_DEST} and no form carries the suite:priority markers — not adopted yet, skipped")
            skipped += 1
        continue

    if has_workflow and not marked:
        fail(f"{name} runs {WORKFLOW_DEST} but no form in {FORMS_DIR} carries the suite:priority markers, so every issue would be flagged")
        status = 1
        continue

    product_changed = False

    # Every form must carry the block once any does: the workflow comments on
    # each issue that arrives without an answer, and a form with no dropdown
    # produces exactly that issue.
    for form in unmarked:
        fail(f"{name}'s {form.relative_to(product)} has no suite:priority markers, so issues filed through it will be flagged")
        status = 1
        product_changed = True

    # The workflow, copied whole.
    if not has_workflow:
        if check_only:
            fail(f"{name} has no {WORKFLOW_DEST}")
            status = 1
            changed = 1
        else:
            workflow_dest.parent.mkdir(parents=True, exist_ok=True)
            workflow_dest.write_text(workflow_text, encoding="utf-8")
            print(f"+ {name} gained {WORKFLOW_DEST} — commit it")
            changed = 1
        product_changed = True
    elif read(workflow_dest) != workflow_text:
        if check_only:
            fail(f"{name} has drifted from plugins/suite-kit/workflows/issue-priority.yml")
            status = 1
        else:
            workflow_dest.write_text(workflow_text, encoding="utf-8")
            print(f"+ {name} updated {WORKFLOW_DEST} — commit it")
        changed = 1
        product_changed = True

    # The block, spliced into each marked form.
    for form in marked:
        current = read(form)
        wanted_text = splice(current, block)
        if wanted_text == current:
            continue
        rel = form.relative_to(product)
        if check_only:
            fail(f"{name}'s {rel} priority block has drifted from plugins/suite-kit/issue-forms/priority.yml")
            status = 1
        else:
            form.write_text(wanted_text, encoding="utf-8")
            print(f"+ {name} updated {rel} — commit it")
        changed = 1
        product_changed = True

    if not product_changed:
        print(f"= {name} already up to date")

if check_only:
    if changed:
        print("run scripts/sync-priority.sh to update, then commit in each product", file=sys.stderr)
    elif status:
        print("no drift among the products present, but the workspace is incomplete", file=sys.stderr)
    elif skipped:
        noun = "1 product has" if skipped == 1 else f"{skipped} products have"
        print(f"no drift among the products carrying the priority block; {noun} not adopted it")
    else:
        print("no drift")
elif not changed:
    print("nothing to do")

sys.exit(status)
PY
