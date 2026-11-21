---
paths:
  - ".claude/suite-*.py"
  - "scripts/lib/python.sh"
---

# The check runner

On Windows the runner shells out through Git's bash rather than `cmd.exe`, which
it finds via `SHELL`, `PATH`, or alongside `git`. The scripts it calls resolve
their own interpreter through `scripts/lib/python.sh`, so a stock install with
`python` and the `py` launcher and no `python3` works without anything being
aliased by hand.

A `go` command whose package embeds a build nobody has built is a skip. The
runner reads the failure rather than pre-judging the command, and it
reinterprets only what it can prove: the embedded path has to be both absent and
gitignored, so a tracked file that is genuinely missing stays a failure, and an
embed miss stops excusing the run the moment anything else in the output failed
too.

An aislop run without the ruff its CI pins is the opposite shape, because it is
the only check here that is skipped *before* it runs. aislop's Python engines run
only when ruff is on PATH, and with none they report `[ok] 0 issues` and a score
of 100 rather than saying they did nothing; the JSON says `"skipped": false` with
no diagnostics, so there is nothing to read afterwards. A wrong version is the
same problem quieter, since 0.15.8 and 0.16.7 disagree about real findings in
this tree. So the runner establishes beforehand that the result would mean what
CI means, and reads the version it wants from the repo's own workflows rather
than from a second pin of its own. A repo that pins nothing is left alone.
