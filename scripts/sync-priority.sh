#!/usr/bin/env bash
#
# Put the suite's issue-priority machinery into each repo: the priority field in
# every issue form that files work, and the workflow that turns the answer into a
# label.
#
# Same shape as sync-notes.sh and sync-runner.sh, for the same reason. A workflow
# runs in its own repo's container, with this one nowhere on disk and no plugin
# installed, so the thing that reads the form has to be *in* the repo.
#
# What is shared and what is not:
#
#   shared    That every issue carries exactly one p* label, what the four levels
#             mean, the wording a reporter chooses between, and the job that maps
#             an answer to a label. A person filing in Konnekt and a person filing
#             in Kommands answer the same question.
#   per-repo  The forms themselves. Konnekt's ask for a Minecraft loader and a tile
#             area; a conventions repo's have no business doing either. This script
#             splices one field into a hand-authored form and leaves the rest of it
#             alone.
#
# The field is generated from design/labels.json's priority[] rather than kept as a
# file of its own, so the option a reporter picks and the level it means cannot
# disagree. The workflow *is* a file of its own, and carries a copy of the mapping
# in its env block, which is checked against design/labels.json before anything is
# written: a copy that cannot drift silently is fine, a second source is not.
#
#   --check             Report drift and exit non-zero without writing anything.
#   --require-vendored  Treat a repo that has never adopted the workflow as a
#                       failure instead of a skip.
#
# The split follows sync-notes.sh. A repo that has not adopted this is work not
# started, and adoption lands in that repo; a copy that has gone *stale* is a form
# asking a question nothing reads back. Only the second should redden a build here
# that cannot fix the first. Turn on --require-vendored once every repo carries it.

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
[ -f "$root/design/labels.json" ] || { echo "no design/labels.json at $root" >&2; exit 1; }

# Hard: every check below is written in the Python that follows, so without an
# interpreter this script has nothing to report.
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

ROOT="$root" CHECK_ONLY="$check_only" REQUIRE_VENDORED="$require_vendored" "${PYTHON[@]}" <<'PY'
import json, os, re, sys

root = os.environ["ROOT"]
check_only = os.environ["CHECK_ONLY"] == "1"
require_vendored = os.environ["REQUIRE_VENDORED"] == "1"

WORKFLOW_SRC = os.path.join(root, "plugins", "suite-kit", "issue-priority.workflow.yml")
WORKFLOW_DST = os.path.join(".github", "workflows", "issue-priority.yml")

# The form copy. Not in design/labels.json, which holds what the levels mean rather
# than how they are asked about -- but HEADING is load-bearing in two places, so the
# workflow's copy of it is asserted against this one below.
HEADING = "How urgent is this for you?"
DESCRIPTION = "Your honest read. Triage may change it, and that is normal."

OPEN = "  # >>> suite:priority. Vendored from kollektiv by scripts/sync-priority.sh. Edit it there."
CLOSE = "  # <<< suite:priority"

status = 0
changed = 0


def fail(msg):
    global status
    print("! " + msg, file=sys.stderr)
    status = 1


def yaml_single_quote(value):
    return "'" + value.replace("'", "''") + "'"


def build_block(levels):
    """The issue-form field, generated from the levels a reporter may select.

    p0 is absent from it because design/labels.json says it is not reporter
    selectable. That absence is the whole of the cap: there is no rule to enforce
    later and nothing to spoof, because the option was never offered.
    """
    lines = [
        OPEN,
        "  - type: dropdown",
        "    id: priority",
        "    attributes:",
        "      label: %s" % HEADING,
        "      description: %s" % DESCRIPTION,
        "      options:",
    ]
    for level in levels:
        lines.append("        - %s" % yaml_single_quote(level["formOption"]))
    lines += [
        "    validations:",
        "      required: true",
        CLOSE,
    ]
    return "\n".join(lines) + "\n"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# --- the source, and the one copy of it that lives outside itself ---------

labels = json.loads(read(os.path.join(root, "design", "labels.json")))
selectable = [level for level in labels["priority"] if level.get("reporterSelectable")]

if not selectable:
    fail("design/labels.json declares no reporter-selectable priority level")
    sys.exit(1)

block = build_block(selectable)

# Leading tokens have to stay distinct: the workflow matches an answer by the first
# whitespace-delimited token of the option, so two options starting the same way
# would make one of them unreachable. Verbatim, punctuation included -- a rule with
# no trimming in it is a rule the workflow can implement as a prefix match.
keys = [level["formOption"].split()[0] for level in selectable]
if len(set(keys)) != len(keys):
    fail("design/labels.json priority[] has two form options with the same leading "
         "token, which the workflow's match cannot tell apart")

workflow = read(WORKFLOW_SRC)

expected_map = "".join("            %s %s\n" % (key, level["label"])
                       for key, level in zip(keys, selectable))
found_map = re.search(
    r"# >>> suite:priority-map\n[ \t]*PRIORITY_MAP: \|\n((?:.*\n)*?)[ \t]*# <<< suite:priority-map",
    workflow)
if not found_map:
    fail("plugins/suite-kit/issue-priority.workflow.yml has no suite:priority-map region")
elif found_map.group(1) != expected_map:
    fail("plugins/suite-kit/issue-priority.workflow.yml's PRIORITY_MAP disagrees with "
         "design/labels.json. Expected:\n" + expected_map.rstrip())

if ("HEADING: %s" % yaml_single_quote(HEADING)) not in workflow:
    fail("plugins/suite-kit/issue-priority.workflow.yml's HEADING is not %r, so it would "
         "read a heading the vendored form never writes" % HEADING)

if status:
    print("the source disagrees with itself; nothing was propagated", file=sys.stderr)
    sys.exit(status)


# --- per-repo ------------------------------------------------------------

def forms_that_file_work(template_dir):
    """Every issue form in the directory that applies a `type:` label.

    That is the whole selection rule, and it is mechanical on purpose: a form with
    no `type:` label is not filing a work item. It is what keeps Konnekt's
    question.yml out without this script needing to know what a question is.
    """
    out = []
    try:
        names = sorted(os.listdir(template_dir))
    except OSError:
        return out
    for name in names:
        if not name.endswith((".yml", ".yaml")) or name == "config.yml":
            continue
        text = read(os.path.join(template_dir, name))
        # Read the top-level `labels:` line rather than parsing the file: this runs
        # with no YAML library available, and the front matter is a fixed shape.
        match = re.search(r"^labels:\s*\[(.*)\]\s*$", text, re.M)
        if match and "type:" in match.group(1):
            out.append(name)
    return out


def splice(text, block):
    """Put the block in, replacing an existing one if the markers are already there.

    A form with no markers gets it before the trailing `extra` field, so the last
    thing on the page stays the open-ended one. A form with no `extra` field gets it
    appended.
    """
    existing = re.search(re.escape(OPEN) + r"\n.*?" + re.escape(CLOSE) + r"\n", text, re.S)
    if existing:
        return text[:existing.start()] + block + text[existing.end():]

    elements = list(re.finditer(r"^  - type: ", text, re.M))
    for i, element in enumerate(elements):
        end = elements[i + 1].start() if i + 1 < len(elements) else len(text)
        if re.search(r"^    id: extra\s*$", text[element.start():end], re.M):
            return text[:element.start()] + block + "\n" + text[element.start():]

    if not text.endswith("\n"):
        text += "\n"
    return text + "\n" + block


def sync_one_repo(name, repo_dir):
    global changed
    template_dir = os.path.join(repo_dir, ".github", "ISSUE_TEMPLATE")
    forms = forms_that_file_work(template_dir)

    if not forms:
        if require_vendored:
            fail("%s has no issue form applying a type: label -- see docs/adopting.md" % name)
        else:
            print("? %s has no issue form applying a type: label -- skipped" % name)
        return

    for form in forms:
        path = os.path.join(template_dir, form)
        before = read(path)
        after = splice(before, block)
        where = "%s .github/ISSUE_TEMPLATE/%s" % (name, form)
        if before == after:
            print("= %s already up to date" % where)
            continue
        changed += 1
        if check_only:
            fail("%s is missing the priority field, or its copy has drifted" % where)
        else:
            write(path, after)
            print("+ %s updated" % where)

    dst = os.path.join(repo_dir, WORKFLOW_DST)
    wanted = workflow
    current = read(dst) if os.path.exists(dst) else None
    where = "%s %s" % (name, WORKFLOW_DST.replace(os.sep, "/"))
    if current == wanted:
        print("= %s already up to date" % where)
        return
    changed += 1
    if check_only:
        if current is None:
            fail("%s has not been vendored" % where)
        else:
            fail("%s has drifted from the copy in this repo" % where)
    else:
        write(dst, wanted)
        print("+ %s %s" % (where, "created" if current is None else "updated"))


sync_one_repo("kollektiv", root)

manifest = json.loads(read(os.path.join(root, "suite.repos.json")))
for repo in manifest["repos"]:
    name = repo["name"]
    repo_dir = os.path.join(root, name)
    if not os.path.isdir(repo_dir):
        if require_vendored:
            fail("%s is not cloned beside this repo -- run scripts/bootstrap.sh" % name)
        else:
            print("? %s not cloned -- skipped" % name)
        continue
    sync_one_repo(name, repo_dir)

if check_only:
    if changed:
        print("run scripts/sync-priority.sh to update", file=sys.stderr)
    else:
        print("no drift")
elif not changed:
    print("nothing to do")

sys.exit(status)
PY
