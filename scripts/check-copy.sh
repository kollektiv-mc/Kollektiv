#!/usr/bin/env bash
#
# Check the public copy for em dashes.
#
# The rule is docs/conventions.md § Public copy: anything a reader outside the
# project sees carries no em dash. That is the website's words, and the titles
# and bodies of issues, pull requests and commits.
#
# Only the first of those is in a file, so only the first can be checked here.
# The rest rest on review, and the convention says so rather than implying a
# gate that does not exist — the same distinction the health runner draws
# between a check that passed and one that never ran.
#
# Deliberately NOT the whole file. An HTML comment, a stylesheet comment and a
# line of Python are notes between people working on this repo, and the rule
# does not reach them: it is about what is published, not about how the thing
# that publishes it is written. So comments, <script> and <style> are blanked
# before the search, in place, so the line numbers reported are the real ones.
#
# What is left after that blanking is everything a reader can reach: the text
# between the tags, and the attributes that are themselves copy — a title, a
# meta description, the alt text on a screenshot.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

if "${PYTHON[@]}" - "$root" <<'PY'
import glob
import os
import re
import sys

root = sys.argv[1]
EM_DASH = "—"


def blank(match):
    """Replace a span with spaces, keeping every newline, so lines still count."""
    return re.sub(r"[^\n]", " ", match.group(0))


findings = []
pages = sorted(glob.glob(os.path.join(root, "website", "*.html")))
if not pages:
    sys.exit("no pages found under website/")

for page in pages:
    with open(page, encoding="utf-8") as handle:
        source = handle.read()
    masked = re.sub(r"<!--.*?-->", blank, source, flags=re.S)
    masked = re.sub(r"<(script|style)\b.*?</\1>", blank, masked, flags=re.S | re.I)

    lines = source.split("\n")
    for number, line in enumerate(masked.split("\n"), 1):
        if EM_DASH in line:
            where = os.path.relpath(page, root)
            findings.append("%s:%d: %s" % (where, number, lines[number - 1].strip()))

for finding in findings:
    print(finding, file=sys.stderr)
if findings:
    sys.exit(1)
PY
then
  echo "= no em dashes in the published copy"
else
  echo "! the published copy carries an em dash; see docs/conventions.md § Public copy" >&2
  exit 1
fi
