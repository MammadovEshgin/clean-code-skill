---
name: deslop
description: Rewrite existing code into the shape a senior engineer would have written, with behaviour locked and evidence for every pass. Removes slop, reshapes what is the wrong shape, audits the tests, then hunts and fixes bugs red-test-first. Scope is a path, a git range, or "repo" for the whole codebase, planned and committed slice by slice.
disable-model-invocation: true
argument-hint: [path | git-range | repo] [--plan] [--refactor-only] [--no-structure]
---

# Deslop

Take existing code to the standard in the `/clean-code` skill without losing what it does. First remove what earns no place: dead code, narration comments, trivial wrappers, duplicate helpers, defensive paranoia, debug leftovers, filler. Then reshape what is the wrong shape into a deeper, simpler one. Then make the tests able to fail. Then, and only then, hunt for bugs and fix them with a red test first. The output is a smaller, better codebase, plus a report that proves it.

Scope: `$ARGUMENTS`. Empty means the uncommitted diff. A path or a git range runs the procedure below directly. `repo` means the whole codebase and follows [REPO.md](REPO.md) instead: plan the work as slices, run this procedure on each slice in a fresh context, gate and commit each slice on its own, resume from the plan when interrupted. Flags: `--plan` writes the repo plan and stops; `--refactor-only` skips the audit step; `--no-structure` skips the repo structure phase. Workers spawned by REPO.md read `${CLAUDE_SKILL_DIR}/SKILL.md` and run one slice.

Vocabulary and the catalog of what counts as slop live in the `/clean-code` skill (`RED-FLAGS.md` beside it). Read that file before the first pass.

## Hard rules

1. **Lock behaviour before cleaning.** Run the existing tests for the scope. Where coverage is thin over code about to be touched, add characterization tests at the public interface first. No test signal, no cleanup of that code; report it as untestable instead.
2. **One category per pass.** Finish a pass, verify, then start the next. Mixed passes are undebuggable when something breaks.
3. **Verify after every pass.** Typecheck plus the focused tests. A failing pass is reverted, not patched forward.
4. **Passes preserve behaviour exactly.** A cleanup that changes observable behaviour is reverted even when the new behaviour looks better, and recorded for the audit step. Behaviour changes only in step 3, each with a test that failed first.
5. **Stay in scope.** Touch only files inside the scope. Neighbouring code that looks sloppy goes in the report.
6. **Deletion is complete.** When something is removed, its callers are updated and no shim, re-export, alias, or "deprecated" wrapper is left behind. On a published surface (package exports, an API, CLI flags) "no callers" inside the repo proves nothing about consumers outside it; that removal is reported as a decision, not made.
7. **Never weaken a check to get green.** A test rewritten to match, a skipped test, a lowered threshold, or a suppression is a red pass.

## Process

### 1. Establish the scope and the safety net

- Resolve the scope to a list of files.
- Identify the commands: typecheck, focused test, full suite, lint. Run typecheck and the full suite now; record the baseline (`N/N passed`).
- Run the inventory tools that exist in the repo, and record their output as the baseline:
  - TypeScript/JavaScript: `npx knip` (unused files, exports, dependencies), ESLint with `no-unused-vars`, `npx ts-prune` if present.
  - Python: `ruff check --select F401,F841,ERA,T20,ARG,BLE`, `vulture <scope>` if installed.
  - Go: `go vet ./...`, `staticcheck ./...` (U1000), `deadcode ./...` if installed.
  - Rust: `cargo clippy`, `cargo build` warnings for `dead_code` and `unused`, `cargo machete` if installed.
  - Any: `npx aislop@latest scan` if the repo uses it; `git log --oneline -- <path>` to see which files change often (they matter most).
- Where none exist, fall back to reading and grep over the tells in `RED-FLAGS.md`.
- Run `${CLAUDE_SKILL_DIR}/../clean-code/scripts/complexity.sh <scope>` and record the baseline: function count, maximum, functions over budget, erosion, hotspots.

### 2. Run the passes, in order

Skip a pass with zero findings; never reorder.

| Pass | Do | Detection |
|---|---|---|
| 1 Dead code | remove unused imports, variables, parameters, functions, exports, files; unreachable branches; commented-out code; stubs; compatibility shims; debug prints; scratch files | tooling from step 1, then grep |
| 2 Comments | remove narration, signature echoes, banners, step numbers, end markers, empty labels, vague TODOs, emoji, conversational voice; keep and sharpen the why | read every comment in scope against the diagnostic in `COMMENTS.md` |
| 3 Abstractions | inline single-use helpers that hide nothing (one that names a calculation stays); remove pass-through wrappers, one-implementation interfaces with no second adapter in sight, factories of one, config for constants, utility dumping grounds | call-site counts (`grep -rn` or the language's find-references) |
| 4 Defensive paranoia | remove null checks on guaranteed values, try/catch around code that cannot throw, internal-argument validation, masking fallbacks, redundant assertions | read each guard and ask what value could reach it |
| 5 Duplication | merge duplicate helpers, copy-pasted blocks with cosmetic variation, repeated switches; a copy of a helper that exists elsewhere uses the existing one | grep for the shape; compare bodies |
| 6 Naming | fix redundant qualifiers, generic names, synonyms for one concept, booleans that are not predicates | read the scope's public surface |
| 7 Filler | remove over-typed locals, decorative formatting, template scaffolding, generated boilerplate; one thing per line where a line does three | read |
| 8 Hotspots | split every function over the complexity budget along its responsibilities, worst first | `complexity.sh`; skip the pass when it reported n/a |
| 9 Design | reshape what is the wrong shape (see below) | Ousterhout's flags and Fowler's smells in `RED-FLAGS.md`; the deletion test |
| 10 Tests | read `${CLAUDE_SKILL_DIR}/../test-audit/SKILL.md` and apply it to the scope: delete tests that cannot fail, rewrite implementation-coupled ones at the seam, add the seam tests that are missing, prove the suite with mutation probes | that skill's classification table |
| 11 Docs | in `README`, `CLAUDE.md`, `AGENTS.md`, and docs inside the scope: delete implementation details the code already states, session-specific observations, and references to files, commands, or flags that no longer exist; keep the why | read each file against the code it describes |

**Pass 8** splits a hotspot along its responsibilities, never at line counts. One focused function per case of a dispatcher; a lookup table for a ladder of `if`/`else`; a special case defined out of existence; a guard clause for the early exit. Tests stay at the public seam and must pass unchanged. A dispatcher at 91 paths becoming a 12-path dispatcher plus focused handlers is the shape to aim for. Record complexity before and after each hotspot.

**Pass 9** is where the code becomes what a senior engineer would have written, not merely what is left after deleting. Rewrite when the result is clearly better on a measure a reviewer can see: a smaller interface, fewer concepts a caller must hold, a special case gone, one piece of knowledge in one place, and the seam tests passing unchanged. The moves: merge shallow modules into a deep one; move leaked knowledge (a format, a rule, a schema) behind one interface; define a special case out of existence; parse once at the boundary and delete the internal re-checks; make illegal states unrepresentable (a union for a boolean pair, a distinct id type); inject a dependency that is constructed inside; replace a boolean flag parameter with two functions or a union; replace a repeated switch with a table; collapse a pass-through layer (deletion test); reorganize a temporal decomposition around what each module knows; bound an unbounded call (timeout, retry cap) where the missing bound is a defect the tests can lock. When a function is beyond repair, rewrite it from its tests and its interface rather than patching it. A reshape that would ripple beyond the scope, or that needs a decision, goes in the report as a proposal with the before and after shape.

For each finding: apply the smallest edit that removes it, then continue. For each pass: run typecheck and the focused tests; on green, note the pass's stats (`git diff --shortstat`), on red, revert the pass and investigate before moving on.

Commit per pass only when the user asked for commits. Otherwise keep the passes sequential and report them separately so the reviewer can follow. In `repo` scope the orchestrator commits per slice; a worker never commits.

### 3. Audit

Unless `--refactor-only`: read `${CLAUDE_SKILL_DIR}/../audit/SKILL.md` and apply it to the scope. Its fixes change behaviour on purpose, each locked by a test that went red first, and they stay separate from the passes above: in `repo` scope they are a separate worker and a separate commit; in a single-scope run they are listed under their own heading in the report. Include the items recorded under rule 4 as candidates.

### 4. Finish

- Run lint and the full suite. Compare against the baseline: same tests, same pass count, or the difference is explained by tests deleted or added in pass 10 and by the audit's regression tests.
- Re-run the inventory tools; the numbers must not have gone up.
- Delete any temporary files created during the run, including `.probe` files.

## Report

End with this block. Numbers come from `scripts/diff-stats.sh <base>` in the `clean-code` skill folder (`${CLAUDE_SKILL_DIR}/../clean-code/scripts/diff-stats.sh`), the test runner, the inventory tools, and the reports of the test audit and the audit.

```
## Deslop Report
Scope       <path or range> · <N files inspected> · <M files changed>
Diff        +<added> / -<removed> lines · net <±n>
Passes      dead code <n> · comments <n> · abstractions <n> · defensive <n> · duplication <n> · naming <n> · filler <n> · hotspots <n> · design <n> · docs <n>
Tests       <before N> → <after M> · deleted <n> · rewritten <n> · added <n> · probes killed <k>/<m>
Audit       fixed <n> (bugs <n> · weaknesses <n> · security <n>) · reported <n>   (or skipped)
Gates       typecheck <pass|fail> · lint <pass|fail|n/a> · check <pass|fail|n/a>
Complexity  max <a> → <b> · over budget <a> → <b> · erosion <x%> → <y%>   (or n/a)
Tools       <knip / ruff / vulture / deadcode / clippy: before → after, or n/a>
Verdict     <behaviour preserved, audit fixes listed | reverted passes: ...>
```

**Fixed (behaviour changed)**: the audit's findings that were fixed, each with the test that went red.

**Found, not changed**: unproven findings, out-of-scope slop, untestable code, design proposals that need a decision, each with a file and one line of reasoning.

**Suggested follow-ups**: at most three, ordered by value.
