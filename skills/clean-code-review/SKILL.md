---
name: clean-code-review
description: Review a diff in a fresh context for slop, design red flags, bugs and security flaws, and scope drift. Every finding is verified before it is reported and carries the fix; nothing is edited. Base ref is the argument; default is the default branch's merge-base, or the working tree when uncommitted changes exist.
disable-model-invocation: true
argument-hint: [base-ref] [spec-path]
context: fork
agent: general-purpose
background: false
---

# Clean Code Review

Review the change as a senior engineer who did not write it. This runs in a fresh context on purpose: the reviewer sees the diff, the code around it, and the standards, not the reasoning that produced the code. The bar is the one a reviewer at a strong company holds: a finding names a real consequence, is checked before it is raised, and comes with the fix.

Arguments: `$ARGUMENTS`. The first is the base ref; the second, if present, is a spec, issue, or plan file describing what the change was supposed to do. When the caller hands over a change record (purpose, target, checks, standards, risk markers), take the purpose and the standards list from it and skip the matching discovery in steps 1 and 2; still read the diff yourself.

## 1. Pin the diff

- With uncommitted changes and no base given: `git diff HEAD`, plus `git status --short` for untracked files.
- With a base given and a clean tree: `git diff <base>...HEAD` (three-dot, against the merge-base). With a base given and uncommitted changes: the working tree against the merge-base, `git diff $(git merge-base <base> HEAD)`, plus `git status --short`. With no base and a clean tree: the merge-base with `main` or `master`.
- Confirm the ref resolves and the diff is non-empty before reading further. List the commits (`git log <base>..HEAD --oneline`).

## 2. Gather the standards

In priority order; a higher source overrides a lower one.

1. The repo's documented standards: `CODING_STANDARDS.md`, `CONTRIBUTING.md`, the code-style sections of `CLAUDE.md` or `AGENTS.md`.
2. The catalogs beside the `clean-code` skill: `${CLAUDE_SKILL_DIR}/../clean-code/RED-FLAGS.md` (slop tells, Ousterhout's red flags, Fowler's smells, complexity signals) and `${CLAUDE_SKILL_DIR}/../clean-code/BUGS.md` (correctness, robustness, security, the four facts per finding). Load the sections the diff calls for (`grep -n '^##'` shows the map): the security section only when untrusted input or a sink is in the diff, the async section only when there is concurrency, and so on.
3. The surrounding code's own conventions, read from the files the diff touches.

Skip anything the repo's linter already enforces.

## 3. Read

Read the test changes first: a test rewritten to match new behaviour, a skipped test, a lowered threshold, or a new suppression is the signature failure of agent-written changes, and it decides how much the rest of the diff can be trusted. Then read every changed hunk, and the code around it: the callers of what changed, the callees, the retry or the transaction it sits inside. The bug is often in how the code is called, not in the hunk.

## 4. Review on four axes

For each finding record file and line, the named flag, the quoted lines, and the fix.

- **Slop**: tells from `RED-FLAGS.md`. Near-mechanical; report as violations.
- **Design**: shallow modules, information leakage, pass-throughs, special cases that could be defined away, errors that are swallowed or masked, tests that reach past the interface, a copy of a helper that exists elsewhere, a refactor that moved code without reducing what a reader must hold. Judgement calls; report as "possible X" with reasoning.
- **Correctness**: bugs, weaknesses, and security flaws from `BUGS.md`, written as "given X, Y happens; expected Z", with severity and confidence. Trace untrusted input to the sinks it reaches. Includes weakened checks from step 3.
- **Scope**: changed lines that the request (commit messages, spec, branch name) does not explain; requirements from the spec that are missing or partial; behaviour that was not asked for. Without a spec, limit this axis to changes that look unrelated to each other.

## 5. Verify, then filter

Re-check every finding against the code before it is written down. For a correctness finding, run the reproduction when it is cheap (a focused test, a one-line script) and record severity, confidence, and reproduction as `BUGS.md` defines them; report `certain` and `likely`, drop `possible`. Drop, on every axis:

- Pre-existing issues on lines the change did not touch (mention the worst one in a single closing line, nothing more).
- Anything a linter, typechecker, or compiler in the repo reports.
- Style preferences the repo does not document.
- Nitpicks a senior engineer would not raise in a review.
- Behaviour changes the purpose explains.
- A finding that a second reading does not support.

Report only what affects correctness, maintainability, security, or a stated standard. A reviewer asked to find gaps will find some; chasing every one produces over-engineering, so the bar is real impact.

## 6. Report

Under 600 words. Findings first, ordered by severity within each axis. No fixes are applied; the implementing session applies them.

```
## Review: <base>..HEAD · <N files> · <M findings>

### Slop
- path/file.ts:42 · Narration · `// increment the counter` → delete

### Design
- path/service.ts:10-48 · possible Pass-Through Method · `OrderService.create` forwards to `repo.create` unchanged → call the repository directly, or give the service a real contract

### Correctness
- path/upload.ts:31 · path traversal · high · likely · not attempted · given `name = "../../etc/passwd"`, `join(root, name)` escapes the root; expected a rejection → resolve, then require the result to start with the root
- test/orders.test.ts:88 · weakened check · high · certain · reproduced · the expected total was changed from 15 to 14.99 to match the new rounding → restore the test, fix the rounding

### Scope
- path/other.ts · reformatted 30 untouched lines → revert

### Verdict
<merge | fix then merge | rethink> · worst issue: <one line>
```

An axis with nothing to report says "none". Do not rank across axes; a change can pass one and fail another, and both facts matter. A correctness finding at high severity makes the verdict at least `fix then merge`.
