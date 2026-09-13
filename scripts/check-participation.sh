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
#   vendored      every file this repo vendors into a product is excluded from
#                 that product's own formatter and scanner. A vendored file is
#                 byte-compared against its master, so a product gate that
#                 rewrites one creates drift that nothing here can fix. That
#                 happened: Konnekt's aislop gate ran ruff format over its copy
#                 of release-notes.py, and the nightly was red for a week.
#                 Each product had already learned this once for one file
#                 (.claude/suite-check.py in Konnekt's .aislopignore, the
#                 priority workflow in Kommands' .prettierignore); this is the
#                 rule those two lines were instances of.
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

# Hard: every check below is written in the Python that follows, so without an
# interpreter this script has nothing to report. lib/python.sh is what knows that
# `python3` is not a universal spelling.
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
require_python

ROOT="$root" REQUIRE_PRODUCTS="$require_products" "${PYTHON[@]}" <<'PY'
import json, os, sys

root = os.environ["ROOT"]
require_products = os.environ["REQUIRE_PRODUCTS"] == "1"

# docs/conventions.md § Required permissions block. Not negotiable per repo,
# which is the whole reason it can be checked mechanically at all.
FLOOR = {
    "deny": ["Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"],
    "ask": ["Bash(git push:*)"],
}

# docs/conventions.md § Required formatting settings, and Prettier 3's own defaults
# beside them. Compared as *effective* values: an absent key means Prettier will
# apply its default, so absent-and-wrong is a real disagreement while
# absent-and-right is not. semi is the one that bites -- leaving it out means
# semicolons, which is the opposite of the convention.
STYLE = {"semi": False, "singleQuote": True, "trailingComma": "all",
         "printWidth": 100, "tabWidth": 2}
PRETTIER_DEFAULTS = {"semi": True, "singleQuote": False, "trailingComma": "all",
                     "printWidth": 80, "tabWidth": 2}

# Only the JSON-parseable forms. A prettier.config.js would have to be executed to
# be read, and this script will not run a repo's code to check it.
STYLE_FILES = (".prettierrc", ".prettierrc.json", ".prettierrc.json5")
STYLE_FILES_UNREADABLE = (".prettierrc.js", ".prettierrc.mjs", ".prettierrc.cjs",
                          ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
                          "prettier.config.js", "prettier.config.mjs",
                          "prettier.config.cjs")

# What this repo vendors into a product, and which script owns each. A product
# gate must never rewrite one of these; the sync script that owns it byte-compares
# the two copies. Kept here rather than read out of the scripts because each of
# them knows only its own file, and this is the one place that needs the list.
VENDORED = {
    "tokens.source.json": "sync-tokens.sh",
    ".claude/suite-check.py": "sync-runner.sh",
    ".github/scripts/release-notes.py": "sync-notes.sh",
    ".github/scripts/release-notes_test.py": "sync-notes.sh",
    ".github/release.yml": "sync-notes.sh",
    ".github/workflows/issue-priority.yml": "sync-priority.sh",
    ".aislop/base.yml": "sync-aislop.sh",
    ".github/workflows/aislop.yml": "sync-workflows.sh",
    ".github/workflows/codeql.yml": "sync-workflows.sh",
    ".github/workflows/pr-labelled.yml": "sync-workflows.sh",
    ".github/workflows/scorecard.yml": "sync-workflows.sh",
}
# What each product-side tool would rewrite. aislop formats and lints Python;
# Prettier formats JSON, YAML and Markdown. A vendored file with any other
# extension is not something either tool touches.
AISLOP_EXTS = (".py",)
PRETTIER_EXTS = (".json", ".yml", ".yaml", ".md")

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


def rel(path, repo_dir):
    """Repo-relative path with forward slashes, so a report reads the same on
    Windows as it does in CI."""
    return os.path.relpath(path, repo_dir).replace(os.sep, "/")


def own_subdirs(repo_dir):
    """Immediate subdirectories that belong to this repo.

    A nested git repo does not: the workspace root has the products cloned inside
    it, so without this the root's search walked into Konnekt/ and reported its
    package.json as the root's own.
    """
    out = []
    try:
        names = sorted(os.listdir(repo_dir))
    except OSError:
        return out
    for d in names:
        full = os.path.join(repo_dir, d)
        if not os.path.isdir(full) or d.startswith(".") or d == "node_modules":
            continue
        if os.path.exists(os.path.join(full, ".git")):
            continue
        out.append(full)
    return out


def find_style_config(repo_dir):
    """(kind, path, settings) for a repo's Prettier config.

    kind is "json" with settings, "unreadable" with a path and no settings, or
    "none". Searched at the repo root and one level down, because Konnekt keeps its
    JS toolchain in frontend/ while Kommands will keep its at the root -- the same
    reason health.commands carries a cwd.
    """
    roots = [repo_dir] + own_subdirs(repo_dir)

    for d in roots:
        for name in STYLE_FILES:
            f = os.path.join(d, name)
            if os.path.isfile(f):
                try:
                    return "json", f, load(f)
                except (OSError, ValueError) as e:
                    return "broken", f, str(e)
        pkg = os.path.join(d, "package.json")
        if os.path.isfile(pkg):
            try:
                cfg = load(pkg).get("prettier")
            except (OSError, ValueError):
                cfg = None
            if isinstance(cfg, dict):
                return "json", pkg + " (prettier key)", cfg
        for name in STYLE_FILES_UNREADABLE:
            f = os.path.join(d, name)
            if os.path.isfile(f):
                return "unreadable", f, None
    return "none", None, None


def has_js_toolchain(repo_dir):
    if os.path.isfile(os.path.join(repo_dir, "package.json")):
        return True
    return any(os.path.isfile(os.path.join(d, "package.json"))
               for d in own_subdirs(repo_dir))


def check_style(label, repo_dir):
    """The shared formatting settings, compared as effective values."""
    kind, path, cfg = find_style_config(repo_dir)

    if kind == "none":
        if has_js_toolchain(repo_dir):
            fail("%s has a package.json but no Prettier config — the shared "
                 "formatting settings are unset" % label)
        else:
            # kollektiv has no JS at all; Kommands has none yet. Neither is
            # non-conforming, and calling it a failure would train people to
            # ignore this check.
            print("? %s no JS toolchain — formatting settings not applicable" % label)
        return

    if kind == "broken":
        fail("%s Prettier config at %s is not readable: %s"
             % (label, rel(path, repo_dir), cfg))
        return

    if kind == "unreadable":
        print("? %s Prettier config is %s — not compared, it would have to be executed"
              % (label, rel(path, repo_dir)))
        return

    where = rel(path, repo_dir)
    wrong = []
    for key, want in STYLE.items():
        effective = cfg.get(key, PRETTIER_DEFAULTS[key])
        if effective != want:
            wrong.append("%s is %r, want %r" % (key, effective, want))
    if wrong:
        fail("%s %s: %s" % (label, where, "; ".join(wrong)))
    else:
        print("= %s formatting settings (%s)" % (label, where))


def ignore_lines(path):
    """The non-comment entries of an ignore file, trailing slashes dropped."""
    out = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    out.append(line.rstrip("/"))
    except OSError:
        pass
    return out


def covered(rel_path, lines):
    """Whether an ignore file's entries cover rel_path: exactly, as a parent
    directory, or as a glob."""
    import fnmatch
    for entry in lines:
        if rel_path == entry or rel_path.startswith(entry + "/"):
            return True
        if fnmatch.fnmatch(rel_path, entry):
            return True
    return False


def check_vendored_ignores(label, repo_dir):
    """Every vendored file present is excluded from the product's own tools."""
    present = sorted(p for p in VENDORED if os.path.isfile(os.path.join(repo_dir, p)))

    if os.path.isfile(os.path.join(repo_dir, ".aislop", "config.yml")):
        lines = ignore_lines(os.path.join(repo_dir, ".aislopignore"))
        for p in present:
            if not p.endswith(AISLOP_EXTS):
                continue
            if covered(p, lines):
                print("= %s .aislopignore covers %s" % (label, p))
            else:
                fail("%s .aislopignore does not cover %s, which %s vendors; aislop "
                     "would reformat it and the next sync would report drift"
                     % (label, p, VENDORED[p]))

    # Only a root-level Prettier config reaches the vendored files, which all
    # sit at the root or under .github/ and .claude/. Konnekt runs Prettier from
    # frontend/ and website/, and neither pass can see them.
    kind, path, _ = find_style_config(repo_dir)
    if kind in ("json", "unreadable") and os.path.dirname(path.split(" ")[0]) == repo_dir:
        lines = ignore_lines(os.path.join(repo_dir, ".prettierignore"))
        for p in present:
            if not p.endswith(PRETTIER_EXTS):
                continue
            if covered(p, lines):
                print("= %s .prettierignore covers %s" % (label, p))
            else:
                fail("%s .prettierignore does not cover %s, which %s vendors; Prettier "
                     "would reformat it and the next sync would report drift"
                     % (label, p, VENDORED[p]))


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

    check_style(label, repo_dir)
    check_vendored_ignores(label, repo_dir)

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
