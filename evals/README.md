# Evals

Real runs against real problems, checked mechanically, with the numbers recorded. This is how the repo answers "does it work" and "what does it cost" with something other than a screenshot. It is a smoke test with a baseline arm, not a benchmark; see [Honest limits](#honest-limits).

## Run

```bash
evals/run.sh                       # every fixture, skills installed
evals/run.sh ts-audit              # one fixture
evals/run.sh --baseline ts-audit   # the same fixture with no skills and a plain-English prompt
evals/run.sh --runs 3 ts-audit     # repeat, to see variability
evals/run.sh --keep ts-audit       # keep the workspace; agent-output.txt lands in <workspace>.meta/
```

Each run starts a fresh Claude Code session in a temporary git repo, installs the skills from this checkout (not in the baseline arm), runs the fixture's command (or its `baseline` prompt) with JSON output, then runs the fixture's `check.sh`. One line per run is printed and appended to `evals/results/log.tsv`:

```
date  claude  fixture  arm  run  verdict  seconds  input_tokens  output_tokens  cost_usd  turns
```

`input_tokens` includes cache reads and cache writes, which is what the API bills. The log is committed; a result quoted anywhere in this repo should be findable there with its date and Claude Code version.

## What a fixture checks

- **Behaviour is intact**: the fixture's own test suite passes after the run.
- **The problem is gone**: banned patterns no longer appear; the bug is fixed; the trash tests are deleted.
- **The workflow held**: `/finish` and `/audit` leave the change uncommitted; `/deslop repo` lands each slice in its own commits, leaves no `.deslop/`, leaves the tree clean.
- **Red first, mechanically** (`ts-audit`): the check puts the pre-fix production file back and requires the suite to fail. A fix without a test that fails on the old code fails the fixture.
- **The suite bites** (`ts-test-audit`): the check applies three mutants to the production code; each must make the suite fail.
- **Good code stays** (`ts-clean`): the production file must be byte-identical; no test may be removed.

Checks are strict and mechanical. A run that leaves one `console.log` behind fails.

## Fixtures

| Fixture | Command | Planted | Baseline prompt |
|---|---|---|---|
| `ts-pricing` | `/deslop src/pricing.ts` | banner and narration comments, one-call helper, null check the type forbids, swallowing `try/catch`, commented-out code, `console.log`, vague TODO | yes |
| `py-orders` | `/deslop orders.py` | the same in Python, plus `except Exception: pass` and an unjustified `# type: ignore` | no |
| `ts-finish` | `/finish HEAD~1` | the `ts-pricing` slop as the branch's last commit; nothing may be committed | no |
| `ts-repo` | `/deslop repo` | two modules with the same slop plus a `@ts-ignore`; one commit per module, no `.deslop/`, clean tree | no |
| `ts-audit` | `/audit src/users.ts` | SQL built from a user-supplied name; a pager that drops the last item of every page; existing tests cover neither | yes |
| `ts-test-audit` | `/test-audit src` | a tautological test, a mock-call test, a framework test, a `typeof` assertion, an untested seam | yes |
| `ts-clean` | `/deslop src` | nothing: correct code with tests that can fail; the run must leave the production file alone | yes |

## Recorded results

All rows are in `evals/results/log.tsv`; this table is a summary of it, Claude Code 2.1.258.

| Fixture | Arm | Result |
|---|---|---|
| `ts-pricing`, `py-orders` | skills, 2026-09-07 (1.1.0) | PASS, 274s and 297s, net -28 and -32 lines |
| `ts-finish` | skills, 2026-09-08 (2.0.0) | PASS, 525s; 39-line file to 7 lines; probes 6/6; one correctness finding reported; uncommitted |
| `ts-repo` | skills, 2026-09-07 (1.2.0) | PASS, 796s, net -54, one commit per slice |
| `ts-repo` | skills, 2026-09-08 (2.0.0) | interrupted: both slices landed as `refactor(deslop)` commits with the slop gone, then the account's session limit cut the run before the audit and finish phases; not a pass |
| `ts-audit` | skills, 2026-09-08 (2.0.0) | PASS, 102s; both fixed, red-first tests |
| `ts-test-audit` | skills, 2026-09-08 (2.0.0) | PASS, 214s; deleted 3, rewritten 1, added 4; probes 7/7 |
| `ts-clean` | skills, 2026-09-08 (2.1.0, first run) | FAIL for the right reason: the audit found a real bug in the fixture (`format` lost the sign under one whole unit) and fixed it red-first; 359s, 783k input and 21k output tokens, $2.88. The fixture was corrected and rerun; see the log |

Rows for the 2.1.0 reruns and the baseline arm are in the log as they complete. A table entry is written from a log row, never the other way round.

## Add a fixture

```
evals/fixtures/<name>/
  check.sh     exits 0 only when behaviour holds and the planted problem is gone
  entry        the scope passed to /deslop, e.g. src/pricing.ts
  command      optional: the full invocation instead, e.g. "/finish HEAD~1"; <entry> is substituted
  baseline     optional: the plain-English prompt for the no-skill arm
  base         optional: files for a first commit; everything else lands in a second commit
  ...          the project files, including a behaviour test the agent can run
```

Keep fixtures small enough to read in a minute and specific enough that a failure names the pattern that survived. For a bug fixture, make the check restore the pre-fix code and require the suite to fail. For a test-quality fixture, make the check apply mutants itself.

## Honest limits

- Seven small fixtures and single runs. They catch regressions in the skills and give repeatable, dated numbers; they do not establish that the skills beat the same model without them until the baseline arm has enough runs on the same fixtures. Run `--baseline` and `--runs 3` and compare rows in the log.
- Checks test what can be checked mechanically: patterns, behaviour tests, commits, mutants. They do not measure reviewer effort, bugs outside the planted ones, or quality of design.
- Coverage is TypeScript and Python on Windows 11 with Git Bash and Claude Code. Other hosts, operating systems, and the Go and Rust gates are untested here.
- One `ts-clean` run cost $2.88 and 783k input tokens (mostly cache reads); the audit and the test audit are not free. The log exists so the cost is known rather than guessed.
- For a real measurement of slop over long iterative work, see [SlopCodeBench](https://github.com/SprocketLab/slop-code-bench), whose erosion metric `scripts/complexity.sh` approximates.
