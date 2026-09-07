# Evals

Real runs against real slop, checked mechanically. This is how the repo answers "does it work" with something other than a screenshot.

## Run

```bash
evals/run.sh                 # every fixture
evals/run.sh ts-pricing      # one fixture
evals/run.sh --keep          # keep the workspaces; agent-output.txt lands in <workspace>.meta/
```

Each fixture run starts a fresh Claude Code session in a temporary git repo with the skills from this checkout installed, runs the fixture's command (`claude -p "/deslop <entry>"` by default), then runs the fixture's `check.sh`. A run costs tokens and takes a few minutes. The output is one line per fixture:

```
PASS  py-orders      297s  lines +2 / -34 · net -32 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
PASS  ts-pricing     274s  lines +2 / -30 · net -28 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
evals: 2/2 passed
```

Those are the numbers from the run on 2026-09-07 with Claude Code 2.1.258. Both fixtures came back as the two intended functions, with the behaviour tests at 4/4 before and after. The workflow fixtures, same day and version:

```
PASS  ts-finish      395s  lines +7 / -0 · net +7    (the branch's 39-line file became 7 lines, uncommitted, verdict "ready to commit")
PASS  ts-repo        796s  lines +8 / -62 · net -54 comments removed 33 · added 0 dead-ish removed 4 · added 0 debug removed 2 · added 0
evals: 2/2 passed
```

`ts-repo` ended on branch `deslop/2026-09-07` with four commits: the baseline, `refactor(deslop): src/orders`, `refactor(deslop): src/pricing`, and `refactor(deslop): finish repo cleanup (2 slices, net -54 lines)`, which deleted `.deslop/plan.md`. Tests 8/8 before and after; the orders slice also gained one characterization test. `ts-finish` spent its time on a fresh-context review that returned zero findings, and its report flagged, without touching it, that the fixture's `npm test` script did not work on Node 24 (fixed since).

## What a fixture checks

- **Behaviour is intact**: the fixture's own test suite passes after the run.
- **The slop is gone**: banned patterns (narration comments, banners, debug output, vague TODOs, commented-out code, swallowing `catch`) no longer appear in the entry file.
- **The file got smaller**: a line-count ceiling that a faithful cleanup lands under.
- **The workflow held** (where it applies): `/finish` without `--commit` leaves the change uncommitted; `/deslop repo` lands each slice in its own commit, leaves no `.deslop/`, and leaves the tree clean.

A check is deliberately strict and mechanical. A run that leaves one `console.log` behind fails.

## Fixtures

| Fixture | Command | Language | Slop planted |
|---|---|---|---|
| `ts-pricing` | `/deslop src/pricing.ts` | TypeScript | banner and narration comments, one-call helper, null check the type forbids, swallowing `try/catch`, commented-out code, `console.log`, vague TODO |
| `py-orders` | `/deslop orders.py` | Python | banner and narration comments, one-call helper, defensive `None` check, `except Exception: pass`, `print`, commented-out code, vague TODO, unjustified `# type: ignore` |
| `ts-finish` | `/finish HEAD~1` | TypeScript | the `ts-pricing` slop, added as the branch's last commit; the check also requires that nothing was committed |
| `ts-repo` | `/deslop repo` | TypeScript | two modules (`src/pricing`, `src/orders`) with the same kinds of slop plus a `@ts-ignore`; the check also requires one commit per module, no `.deslop/`, and a clean tree |

## Add a fixture

```
evals/fixtures/<name>/
  check.sh     exits 0 only when behaviour holds and the slop is gone
  entry        the scope passed to /deslop, e.g. src/pricing.ts
  command      optional: the full invocation instead, e.g. "/finish HEAD~1"; <entry> is substituted
  base         optional: files for a first commit; everything else lands in a second commit
  ...          the project files, including a behaviour test the agent can run
```

Keep fixtures small enough to read in a minute and specific enough that a failure names the pattern that survived.

## Honest limits

Four fixtures is a smoke test, not a benchmark. It catches regressions in the skills (a rewrite that stops removing debug output, or a repo loop that stops committing per slice, would fail immediately) and gives a repeatable number to quote. For a real measurement of slop over long iterative work, see [SlopCodeBench](https://github.com/SprocketLab/slop-code-bench), whose erosion metric `scripts/complexity.sh` approximates.
