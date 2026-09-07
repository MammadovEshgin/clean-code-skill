---
name: clean-code-review
description: Review a diff in a fresh context for slop, design red flags, and scope drift. Reports findings that matter, with the fix; does not edit. Base ref is the argument; default is the default branch's merge-base, or the working tree when uncommitted changes exist.
disable-model-invocation: true
argument-hint: [base-ref] [spec-path]
context: fork
agent: general-purpose
background: false
---

# Clean Code Review

Review the change as a senior engineer who did not write it. This runs in a fresh context on purpose: the reviewer sees the diff and the standards, not the reasoning that produced the code.

Arguments: `$ARGUMENTS`. The first is the base ref; the second, if present, is a spec, issue, or plan file describing what the change was supposed to do.

## 1. Pin the diff

- With uncommitted changes and no base given: `git diff HEAD`, plus `git status --short` for untracked files.
- With a base given: `git diff <base>...HEAD` (three-dot, against the merge-base). With no base and a clean tree: the merge-base with `main` or `master`.
- Confirm the ref resolves and the diff is non-empty before reading further. List the commits (`git log <base>..HEAD --oneline`).

## 2. Gather the standards

In priority order; a higher source overrides a lower one.

1. The repo's documented standards: `CODING_STANDARDS.md`, `CONTRIBUTING.md`, the code-style sections of `CLAUDE.md` or `AGENTS.md`.
2. The catalog at `${CLAUDE_SKILL_DIR}/../clean-code/RED-FLAGS.md` (slop tells, Ousterhout's red flags, Fowler's smells, complexity signals).
3. The surrounding code's own conventions, read from the files the diff touches.

Skip anything the repo's linter already enforces.

## 3. Review on three axes

Read every changed hunk. For each finding record file and line, the named flag, the quoted lines, and the fix.

- **Slop**: tells from the catalog. Near-mechanical; report as violations.
- **Design**: shallow modules, information leakage, pass-throughs, special cases that could be defined away, errors that are swallowed or masked, tests that reach past the interface. Judgement calls; report as "possible X" with reasoning.
- **Scope**: changed lines that the request (commit messages, spec, branch name) does not explain; requirements from the spec that are missing or partial; behaviour that was not asked for. Without a spec, limit this axis to changes that look unrelated to each other.

## 4. Filter

Report a finding only when it affects correctness, maintainability, or a stated standard. Style preferences the repo does not document are left out. A reviewer asked to find gaps will find some; chasing every one produces over-engineering, so the bar is real impact.

## 5. Report

Under 500 words. Findings first, ordered by severity within each axis. No fixes are applied; the implementing session applies them.

```
## Review: <base>..HEAD · <N files> · <M findings>

### Slop
- path/file.ts:42 · Narration · `// increment the counter` → delete

### Design
- path/service.ts:10-48 · possible Pass-Through Method · `OrderService.create` forwards to `repo.create` unchanged → call the repository directly, or give the service a real contract

### Scope
- path/other.ts · reformatted 30 untouched lines → revert

### Verdict
<merge | fix then merge | rethink> · worst issue: <one line>
```

An axis with nothing to report says "none". Do not rank across axes; a change can pass one and fail another, and both facts matter.
