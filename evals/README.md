# Evals

Real runs against real slop, checked mechanically. This is how the repo answers "does it work" with something other than a screenshot.

## Run

```bash
evals/run.sh                 # every fixture
evals/run.sh ts-pricing      # one fixture
evals/run.sh --keep          # keep the workspaces; agent-output.txt lands in <workspace>.meta/
```

Each fixture run starts a fresh Claude Code session in a temporary git repo with the skills from this checkout installed, runs the fixture's command (`claude -p "/deslop <entry>"` by default), then runs the fixture's `check.sh`. A run costs tokens and takes minutes. The output is one line per fixture:

```
PASS  py-orders      297s  lines +2 / -34 · net -32 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
PASS  ts-pricing     274s  lines +2 / -30 · net -28 comments removed 16 · added 0 dead-ish removed 2 · added 0 debug removed 1 · added 0
evals: 2/2 passed
```

Recorded results are in the table below, from real runs on the day of each release. A run that was interrupted is recorded as interrupted, not as a pass.

## What a fixture checks

- **Behaviour is intact**: the fixture's own test suite passes after the run.
- **The slop is gone**: banned patterns (narration comments, banners, debug output, vague TODOs, commented-out code, swallowing `catch`) no longer appear in the entry file.
- **The file got smaller**: a line-count ceiling that a faithful cleanup lands under.
- **The workflow held** (where it applies): `/finish` without `--commit` leaves the change uncommitted; `/deslop repo` lands each slice in its own commit, leaves no `.deslop/`, and leaves the tree clean.
- **The bugs are fixed and proven** (`ts-audit`): the injection is parameterized, the boundary is right, each fix has a test the agent added, nothing outside `src/` changed, nothing was committed.
- **The suite bites** (`ts-test-audit`): the trash tests are gone, the uncovered seam is covered, and the check itself applies three mutants to the production code, each of which must make the suite fail.

A check is deliberately strict and mechanical. A run that leaves one `console.log` behind fails. A run that writes a test which cannot kill a mutant fails.

## Fixtures

| Fixture | Command | Language | Planted | Result (2026-09-07/08, Claude Code 2.1.258) |
|---|---|---|---|---|
| `ts-pricing` | `/deslop src/pricing.ts` | TypeScript | banner and narration comments, one-call helper, null check the type forbids, swallowing `try/catch`, commented-out code, `console.log`, vague TODO | PASS 274s, net -28 |
| `py-orders` | `/deslop orders.py` | Python | the same in Python, plus `except Exception: pass` and an unjustified `# type: ignore` | PASS 297s, net -32 |
| `ts-finish` | `/finish HEAD~1` | TypeScript | the `ts-pricing` slop as the branch's last commit; the check requires that nothing was committed | PASS 525s, 39-line file to 7 lines, probes 6/6, one correctness finding reported, uncommitted |
| `ts-repo` | `/deslop repo` | TypeScript | two modules with the same slop plus a `@ts-ignore`; the check requires one commit per module, no `.deslop/`, a clean tree | 2026-09-07 (1.2.0): PASS 796s, net -54. 2026-09-08 (2.0.0): both slices landed as `refactor(deslop)` commits with the slop gone (11 lines each), then the account's session limit cut the run before the audit and finish phases, so `.deslop/` remained and the check failed; re-run pending |
| `ts-audit` | `/audit src/users.ts` | TypeScript | SQL built from a user-supplied name; a pager that drops the last item of every page; two existing tests that do not cover either | PASS 102s, both fixed at confidence 100, tests 2 to 5, uncommitted |
| `ts-test-audit` | `/test-audit src` | TypeScript | a tautological test, a mock-call test, a framework test, a `typeof` assertion, and an untested seam | PASS 214s, deleted 3, rewritten 1, added 4, probes 7/7, production code untouched |

## Add a fixture

```
evals/fixtures/<name>/
  check.sh     exits 0 only when behaviour holds and the planted problem is gone
  entry        the scope passed to /deslop, e.g. src/pricing.ts
  command      optional: the full invocation instead, e.g. "/finish HEAD~1"; <entry> is substituted
  base         optional: files for a first commit; everything else lands in a second commit
  ...          the project files, including a behaviour test the agent can run
```

Keep fixtures small enough to read in a minute and specific enough that a failure names the pattern that survived. For a test-quality fixture, make the check apply mutants itself: a suite that cannot kill a mutant is the failure you want to catch.

## Honest limits

Six fixtures is a smoke test, not a benchmark. It catches regressions in the skills (a rewrite that stops removing debug output, an audit that patches without a red test, a test audit that keeps a tautology) and gives a repeatable number to quote. For a real measurement of slop over long iterative work, see [SlopCodeBench](https://github.com/SprocketLab/slop-code-bench), whose erosion metric `scripts/complexity.sh` approximates.
