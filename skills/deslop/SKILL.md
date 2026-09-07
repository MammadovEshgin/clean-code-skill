---
name: deslop
description: Audit existing code for AI slop and remove it in behaviour-preserving passes, with evidence. Scope is a path, a git range, or "repo".
disable-model-invocation: true
argument-hint: [path | git-range | repo]
---

# Deslop

Remove low-value code from an existing codebase without changing what it does: dead code, narration comments, trivial wrappers, duplicate helpers, defensive paranoia, debug leftovers, redundant tests, stale ceremony. The output is a smaller codebase that behaves identically, plus a report that proves it.

Scope: `$ARGUMENTS`. Empty means the uncommitted diff; `repo` means every source directory.

Vocabulary and the catalog of what counts as slop live in the `/clean-code` skill (`RED-FLAGS.md` beside it). Read that file before the first pass.

## Hard rules

1. **Lock behaviour before cleaning.** Run the existing tests for the scope. Where coverage is thin over code about to be touched, add characterization tests at the public interface first. No test signal, no cleanup of that code; report it as untestable instead.
2. **One category per pass.** Finish a pass, verify, then start the next. Mixed passes are undebuggable when something breaks.
3. **Verify after every pass.** Typecheck plus the focused tests. A failing pass is reverted, not patched forward.
4. **Preserve behaviour exactly.** A cleanup that changes observable behaviour is reverted even when the new behaviour looks better. Record it under "Found, not changed" for a separate task.
5. **Stay in scope.** Touch only files inside the scope. Neighbouring code that looks sloppy goes in the report.
6. **Deletion is complete.** When something is removed, its callers are updated and no shim, re-export, alias, or "deprecated" wrapper is left behind.

## Process

### 1. Establish the scope and the safety net

- Resolve the scope to a list of files. For `repo`, list every top-level source directory; each one is inspected before the work is called finished.
- Identify the commands: typecheck, focused test, full suite, lint. Run typecheck and the full suite now; record the baseline (`N/N passed`).
- Run the inventory tools that exist in the repo, and record their output as the baseline:
  - TypeScript/JavaScript: `npx knip` (unused files, exports, dependencies), ESLint with `no-unused-vars`, `npx ts-prune` if present.
  - Python: `ruff check --select F401,F841,ERA,T20,ARG,BLE`, `vulture <scope>` if installed.
  - Go: `go vet ./...`, `staticcheck ./...` (U1000), `deadcode ./...` if installed.
  - Rust: `cargo clippy`, `cargo build` warnings for `dead_code` and `unused`, `cargo machete` if installed.
  - Any: `npx aislop@latest scan` if the repo uses it; `git log --oneline -- <path>` to see which files change often (they matter most).
- Where none exist, fall back to reading and grep over the tells in `RED-FLAGS.md`.

### 2. Run the passes, in order

Skip a pass with zero findings; never reorder.

| Pass | Remove | Detection |
|---|---|---|
| 1 Dead code | unused imports, variables, parameters, functions, exports, files; unreachable branches; commented-out code; stubs; compatibility shims; debug prints; scratch files | tooling from step 1, then grep |
| 2 Comments | narration, signature echoes, banners, step numbers, end markers, empty labels, vague TODOs, emoji, conversational voice | read every comment in scope against the diagnostic in `COMMENTS.md` |
| 3 Abstractions | single-use helpers (inline), pass-through wrappers, one-implementation interfaces, factories of one, config for constants, utility dumping grounds | call-site counts (`grep -rn` or the language's find-references) |
| 4 Defensive paranoia | null checks on guaranteed values, try/catch around code that cannot throw, internal-argument validation, masking fallbacks, redundant assertions | read each guard and ask what value could reach it |
| 5 Duplication | duplicate helpers, copy-pasted blocks with cosmetic variation, repeated switches | grep for the shape; compare bodies |
| 6 Naming | redundant qualifiers, generic names, synonyms for one concept | read the scope's public surface |
| 7 Tests | tests that cannot fail on a plausible bug: tautological, duplicate, framework-testing, trivial-code, mock-call-asserting, implementation-coupled, skipped-without-ticket | read each test against "Which tests to write" in `TESTS.md`; for each deletion, name the remaining test that covers the behaviour, or the reason no coverage is needed |
| 8 Filler | over-typed locals, decorative formatting, template scaffolding, generated boilerplate | read |

For each finding: apply the smallest edit that removes it, then continue. For each pass: run typecheck and the focused tests; on green, note the pass's stats (`git diff --shortstat`), on red, revert the pass and investigate before moving on.

Commit per pass only when the user asked for commits. Otherwise keep the passes sequential and report them separately so the reviewer can follow.

### 3. Finish

- Run lint and the full suite. Compare against the baseline: same tests, same pass count, or the difference is explained by tests deleted in pass 7.
- Re-run the inventory tools; the numbers must not have gone up.
- For `repo` scope, confirm every directory listed in step 1 was inspected. Missing one means the work is not finished.
- Delete any temporary files created during the audit.

## Report

End with this block. Numbers come from `scripts/diff-stats.sh <base>` in the `clean-code` skill folder (`${CLAUDE_SKILL_DIR}/../clean-code/scripts/diff-stats.sh`), the test runner, and the inventory tools. Keep it to the block plus the two lists.

```
## Deslop Report
Scope     <path or range> · <N files inspected> · <M files changed>
Diff      +<added> / -<removed> lines · net <±n>
Passes    dead code <n> · comments <n> · abstractions <n> · defensive <n> · duplication <n> · naming <n> · tests <n> · filler <n>
Gates     typecheck <pass|fail> · lint <pass|fail|n/a> · tests <before N/N> → <after N/N>
Tools     <knip / ruff / vulture / deadcode / clippy: before → after, or n/a>
Verdict   <behaviour preserved | reverted passes: ...>
```

**Found, not changed**: behaviour bugs, out-of-scope slop, untestable code, each with a file and one line of reasoning.

**Suggested follow-ups**: at most three, ordered by value.
