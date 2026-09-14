#!/usr/bin/env bash
#
# Check the suite's public copy for em dashes.
#
# The rule is docs/conventions.md § Public copy: anything a reader outside the
# project sees carries no em dash. That is the websites' words, and the titles
# and bodies of issues, pull requests and commits.
#
# Only the first of those is in a file, so only the first can be checked here.
# The rest rest on review, and the convention says so rather than implying a
# gate that does not exist — the same distinction the health runner draws
# between a check that passed and one that never ran.
#
# Every repo in suite.repos.json is scanned, not just this one. The rule is
# suite-wide and the products are where most of the published copy actually
# lives; checking only this repo's website meant Konnekt shipped seventeen em
# dashes in its page titles with nothing to catch them. Products are cloned as
# siblings and are not tracked here, so an uncloned one is reported and skipped
# rather than failing a bare checkout. --require-products is the CI form, where
# bootstrap.sh has run and a missing product means that failed.
#
# A repo with no pages is a skip too, not a pass: Kommands publishes a web app
# whose copy is in its React components, and this script does not read those.
# Saying so is the point. Adding a repo to the manifest is all it takes to have
# it scanned from then on.
#
# What counts as a page: website/*.html, which is how both websites are laid
# out, plus any *.html at the repo root, which is where a Vite app keeps the
# shell it serves. Nothing is scanned recursively, so a fixture or a build
# output deeper in the tree is not mistaken for published copy.
#
# Deliberately NOT the whole file. An HTML comment, a stylesheet comment and a
# line of Python are notes between people working on these repos, and the rule
# does not reach them: it is about what is published, not about how the thing
# that publishes it is written. So comments, <script> and <style> are blanked
# before the search, in place, so the line numbers reported are the real ones.
#
# What is left after that blanking is everything a reader can reach: the text
# between the tags, and the attributes that are themselves copy — a title, a
# meta description, the alt text on a screenshot.

set -euo pipefail

require_products=0

for arg in "$@"; do
  case "$arg" in
    --require-products) require_products=1 ;;
    *) echo "usage: ${BASH_SOURCE[0]##*/} [--require-products]" >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/suite.repos.json"

. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

# set -e propagates the scanner's exit code, and it has already said why.
exec "${PYTHON[@]}" - "$root" "$manifest" "$require_products" <<'PY'
import glob
import json
import os
import re
import sys

root, manifest, require_products = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
EM_DASH = "—"


def blank(match):
    """Replace a span with spaces, keeping every newline, so lines still count."""
    return re.sub(r"[^\n]", " ", match.group(0))


def pages_under(repo_dir):
    """Published pages: a website/ directory, plus a root-level app shell."""
    found = glob.glob(os.path.join(repo_dir, "website", "*.html"))
    found += glob.glob(os.path.join(repo_dir, "*.html"))
    return sorted(set(found))


def scan(page):
    with open(page, encoding="utf-8") as handle:
        source = handle.read()
    masked = re.sub(r"<!--.*?-->", blank, source, flags=re.S)
    masked = re.sub(r"<(script|style)\b.*?</\1>", blank, masked, flags=re.S | re.I)

    lines = source.split("\n")
    hits = []
    for number, line in enumerate(masked.split("\n"), 1):
        if EM_DASH in line:
            hits.append((number, lines[number - 1].strip()))
    return hits


# This repo is the one that is always here; the products sit beside it.
targets = [("kollektiv", root)]
if os.path.exists(manifest):
    with open(manifest, encoding="utf-8") as handle:
        for repo in json.load(handle)["repos"]:
            targets.append((repo["name"], os.path.join(root, repo["name"])))

findings = []
scanned = 0
skipped = 0
status = 0

for name, repo_dir in targets:
    if not os.path.isdir(repo_dir):
        if require_products:
            print("! %s not cloned; run scripts/bootstrap.sh" % name, file=sys.stderr)
            status = 1
        else:
            print("? %s not cloned, skipped" % name)
            skipped += 1
        continue

    pages = pages_under(repo_dir)
    if not pages:
        # Never a pass. A repo with published copy this cannot reach is exactly
        # what the reader of this output needs to know about.
        print("? %s has no website/*.html or root page, skipped" % name)
        skipped += 1
        continue

    for page in pages:
        scanned += 1
        for number, text in scan(page):
            findings.append("%s/%s:%d: %s" % (name, os.path.relpath(page, repo_dir), number, text))

for finding in findings:
    print(finding, file=sys.stderr)

# The reason a run failed is known here and nowhere else. Naming it in the shell
# wrapper instead reported an uncloned product as an em dash.
if findings:
    print(
        "! the published copy carries an em dash;"
        " see docs/conventions.md § Public copy",
        file=sys.stderr,
    )
    status = 1

if status:
    sys.exit(status)

summary = "= no em dashes in %d page(s) across the suite" % scanned
if skipped:
    summary += "; %d repo(s) skipped, skipped is not checked" % skipped
print(summary)
PY
