---
name: audit
description: Find and fix bugs, weaknesses, and security flaws in a scope, with evidence. Every fix ships with a test that failed before it; a finding that cannot be reproduced is reported with the input that would prove it, never patched blind. Scope is a path, a git range, or empty for the uncommitted diff.
disable-model-invocation: true
argument-hint: [path | git-range] [--report-only]
---

# Audit

Read the code the way an attacker and the on-call engineer read it: where does each value come from, where does it go, and what happens on the day it is wrong. The output is a set of fixes, each locked by a test that went red first, plus a report of what was found and could not be proven.

Scope: `$ARGUMENTS`. Empty means the uncommitted diff and the functions it calls. A git range means the changed hunks and their callees. A path means every entry point inside it. `--report-only` finds and proves but changes nothing.

The catalog is `${CLAUDE_SKILL_DIR}/../clean-code/BUGS.md`: the tells, the evidence each one needs, the fix, the confidence rubric, and the exclusions. Read it before the first file.

## Hard rules

1. **A finding is a sentence.** "Given `<input>`, `<code>` does `<wrong outcome>`; expected `<right outcome>`." No sentence, no finding.
2. **Red before green.** A fix lands only after a loop showed the failure: a test at the seam, a request with the payload, a script with the input. The loop ran, went red, and stays as the regression test.
3. **Report likely, fix reproduced.** Every finding carries severity, confidence, reproduction, and action as `BUGS.md` defines them. `certain` and `likely` are reported; `possible` is dropped. A fix requires a loop that went red; a `likely` finding whose loop cannot run here is reported as `not reproducible here` with the command that would prove it, never patched blind.
4. **Fix, do not refactor.** The fix is the smallest change that makes the loop green. Cleanup belongs to `/deslop`; a fix commit that also tidies cannot be reviewed as a fix.
5. **Stay in scope.** Pre-existing problems outside the scope go in the report with the input that reproduces them.
6. **The repo's secure pattern first.** The existing query helper, authorization check, validator, or config loader is the fix; the standard library second; a new dependency last.

## Process

### 1. Map

- List the entry points in scope (handlers, commands, consumers, readers, jobs, exported functions callers reach) and the sinks each one reaches (database, shell, filesystem, network, template, `eval`, log, response). Mark where trust changes hands.
- List the codebase's existing security patterns: how it parameterizes queries, checks authorization, validates input, loads configuration, verifies webhooks. New code is measured against them.
- Run what exists: typecheck, the linter's security rules (`eslint-plugin-security`, Ruff `S`, `gosec`, `clippy`), and the dependency audit when the scope touches dependencies (`npm audit`, `pip-audit`, `cargo audit`, `govulncheck`). Record the baseline: tests `N/N`.

Done when every entry point has its sinks listed and the repo's own patterns are named.

### 2. Hunt

- Walk `BUGS.md` in order over the map: correctness, robustness, security. For each candidate write the finding sentence, the severity, and the confidence.
- Read the nearby code, not only the hunks. Callers and callees one level out; the bug is often in how the code is called, in the retry around it, or in the state it shares.
- Hot spots first: the functions over the complexity budget and the files with the most recent churn (`git log --since='6 months ago' --name-only --format= -- <scope> | sort | uniq -c | sort -rn`).

Done when every category in the catalog has been walked and every kept candidate has a sentence, a severity, and a confidence of `likely` or better.

### 3. Prove

For each finding, build the loop, in this order of preference: a failing test at the seam where the outcome is observable; a request or command with the payload against a running instance; a throwaway harness that calls the code path with the input. Run it and confirm it fails on the exact outcome in the sentence, not on something nearby. Tighten it: deterministic, seconds, no human in the loop. When the environment cannot run the loop, write down the command that would, and mark the finding `not reproducible here`.

Done when every finding to be fixed has a command that was run and went red, pasted into the notes, and every other finding says why it was not run.

### 4. Fix

- The smallest change, using the pattern found in step 1. Run the loop: green. Run the focused tests, then the full suite at the end.
- Turn the loop into a test where it is not one yet, at the seam, named for the behaviour (`rejects a path outside the upload root`, `keeps the balance when the debit races`). The test stays.
- A fix that needs a decision (a new constraint, a changed contract, a rotated secret, a dependency upgrade with breaking changes) is reported with the loop, not made.

Done when the suite is green and every new test can fail.

### 5. Finish

Remove instrumentation and throwaway harnesses (grep for the tag used). Run the check command. `git status` shows only the fixes and their tests.

## Report

```
## Audit Report
Scope       <path or range> · <N files> · <E entry points>
Fixed       <n> · bugs <n> · weaknesses <n> · security <n>   (each with a red-first test)
Reported    <n> · not reproducible here <n> · needs decision <n> · out of scope <n>
Severity    high <n> · medium <n> · low <n>
Gates       check <pass|fail|n/a> · tests <before N/N> → <after M/M>
Verdict     <clean | fixed <n>, review the list | needs decision: ...>
```

Below the block, one line per finding: `file:line · category · severity · <certain|likely> · <reproduced|not reproducible here> · "given X, Y; expected Z" · fixed by <test name>` or `reported: <what would prove it>`. Nothing else.
