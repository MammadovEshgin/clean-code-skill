# Evals

Real runs against real slop, checked mechanically. This is how the repo answers "does it work" with something other than a screenshot.

## Run

```bash
evals/run.sh                 # every fixture
evals/run.sh ts-pricing      # one fixture
evals/run.sh --keep          # keep the workspaces to read agent-output.txt
```

Each fixture run starts a fresh Claude Code session (`claude -p "/deslop <entry>"`) in a temporary git repo with the skills from this checkout installed, then runs the fixture's `check.sh`. A run costs tokens and takes a few minutes. The output is one line per fixture:

```
PASS  py-orders      297s  lines +2 / -34 · net -32 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
PASS  ts-pricing     274s  lines +2 / -30 · net -28 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
evals: 2/2 passed
```

Those are the numbers from the run on 2026-09-07 with Claude Code 2.1.258. Both fixtures came back as the two intended functions, with the behaviour tests at 4/4 before and after.

## What a fixture checks

- **Behaviour is intact**: the fixture's own test suite passes after the run.
- **The slop is gone**: banned patterns (narration comments, banners, debug output, vague TODOs, commented-out code, swallowing `catch`) no longer appear in the entry file.
- **The file got smaller**: a line-count ceiling that a faithful cleanup lands under.

A check is deliberately strict and mechanical. A run that leaves one `console.log` behind fails.

## Fixtures

| Fixture | Language | Slop planted |
|---|---|---|
| `ts-pricing` | TypeScript | banner and narration comments, one-call helper, null check the type forbids, swallowing `try/catch`, commented-out code, `console.log`, vague TODO |
| `py-orders` | Python | banner and narration comments, one-call helper, defensive `None` check, `except Exception: pass`, `print`, commented-out code, vague TODO, unjustified `# type: ignore` |

## Add a fixture

```
evals/fixtures/<name>/
  entry        the scope passed to /deslop, e.g. src/pricing.ts
  check.sh     exits 0 only when behaviour holds and the slop is gone
  ...          the project files, including a behaviour test the agent can run
```

Keep fixtures small enough to read in a minute and specific enough that a failure names the pattern that survived.

## Honest limits

Two fixtures is a smoke test, not a benchmark. It catches regressions in the skill (a rewrite that stops removing debug output would fail immediately) and gives a repeatable number to quote. For a real measurement of slop over long iterative work, see [SlopCodeBench](https://github.com/SprocketLab/slop-code-bench), whose erosion metric `scripts/complexity.sh` approximates.
