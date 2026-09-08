---
name: test-audit
description: Audit the tests in a scope. Delete tests that cannot fail, rewrite tests coupled to the implementation at the public seam, add the seam tests callers depend on, and prove the suite bites with mutation probes. Scope is a path or git range; empty means the tests the uncommitted diff touches or should have.
disable-model-invocation: true
argument-hint: [path | git-range]
---

# Test Audit

A suite is measured by one thing: it goes red when the code is wrong. A test that cannot go red is dead code with a runtime cost, and a test that goes red on a refactor cements the implementation. This skill removes both, writes the tests a caller would want, and then proves the result by breaking the code on purpose.

Scope: `$ARGUMENTS`. Empty means the tests that the uncommitted diff touches, plus the seams the diff changed that have no test. A path means every test in it and every public seam in it. A git range means the same for the changed files.

The rules and examples are in `${CLAUDE_SKILL_DIR}/../clean-code/TESTS.md`; read "Which tests to write", "Anti-patterns", and "Mutation probes". When a caller hands over a change record (target, check commands, baseline), use it and skip the matching parts of step 1.

## Hard rules

1. **Production behaviour stays.** This skill edits tests. The one production change allowed is the smallest seam change that lets a test reach the interface (a dependency accepted as a parameter instead of constructed inside), behaviour unchanged, named in the report.
2. **Every deletion names what remains.** The test that still covers the behaviour, or the reason no coverage is needed (trivial code, framework behaviour).
3. **Every added test went red once.** Before it is kept, the behaviour it protects was broken (a probe from step 4, or the line removed and restored) and the test failed.
4. **No mutant survives in the tree.** Every probe is reverted; `git status` after a probe equals `git status` before it.

## Process

### 1. Inventory

- List the test files in scope and, for each, the seam it crosses (the public interface a caller would use). List the public seams in scope with no test.
- Identify the runner and the focused command. Run the suite: baseline `N/N` and wall time.
- Coverage, if the runner has it (`--coverage`, `pytest --cov`, `go test -cover`, `cargo llvm-cov`), is a hint about where to look, never a target.

Done when every test file maps to a seam and every seam has its test files, or "none".

### 2. Classify every test

Read every test and give it a verdict: **keep**, **rewrite**, **merge**, or **delete**. Write a row only for rewrite, merge, and delete, with the tell; keeps are counted, not listed.

| Verdict | Tells |
|---|---|
| delete | tautological (the expected value is computed the way the code computes it, or the test reads an artifact and asserts it contains itself); asserts that an internal collaborator was called (a call to an external boundary that is the contract stays); tests the framework, the language, or a library; tests trivial code no caller depends on as a contract; duplicates another test with cosmetic input changes; has no assertion; skipped or commented out without a ticket; snapshots output nobody reads |
| rewrite | reaches past the interface (private state, spies on internals, verifies through a side channel); mocks an own module (`vi.mock`, `jest.mock`, `monkeypatch` on project code) instead of injecting through the seam; depends on real time, `sleep`, ordering, or state left by another test; named for the mechanism instead of the behaviour |
| merge | several tests whose inputs belong to the same class; one table-driven test with one row per distinct class |
| keep | one behaviour at a seam, an expected value from an independent source, one reason to fail |

Done when every test in scope has a verdict and every non-keep verdict has a row.

### 3. Act

- Apply the rows: delete, rewrite at the seam, merge. Where a rewrite needs a dependency injected, make that one change (rule 1).
- Add what is missing, per seam: the behaviour the seam exists for; the edge cases the spec names (empty, boundary, invalid input at a boundary); the error mode callers depend on; a regression test for every bug the history names (`git log --grep fix -- <scope>`) that has none. Choose the level where the behaviour is observable (unit, integration, end-to-end, contract, property). Name each test as a capability. Expected values come from a known literal or the spec.
- Run the suite.

Done when the suite is green and every row in step 2 has been applied.

### 4. Prove the suite bites

Use a mutation tool when the repo has one: StrykerJS (`npx stryker run --mutate "<scope>/**"`), mutmut (`mutmut run --paths-to-mutate <scope>`), cargo-mutants (`cargo mutants -f <file>`), gremlins (`gremlins unleash <package>`), pytest-gremlins (`pytest --gremlins`). Read the survivors.

Without a tool, probe by hand. For each production module in scope (in `/finish`, the functions the change touched; cap twelve probes), three mutants, one at a time:

1. Negate one condition.
2. Shift one boundary by one (`<` to `<=`, `n` to `n - 1`).
3. Return a constant, an empty collection, or `null` from the function.

Procedure per mutant: copy the file beside itself as `<file>.probe`, apply the mutant, run the focused tests, restore with `mv <file>.probe <file>`, confirm `git status` is unchanged. A mutant that no test kills is a **survivor**: untested behaviour (write the test named for that behaviour, apply the mutant again, watch the test fail, restore) or dead code (report it for `/deslop`).

Done when every mutant was killed, or its survival is listed with the behaviour it exposed.

### 5. Finish

Full suite; runtime before and after; `git status` shows no `.probe` files and no mutants.

## Report

```
## Test Audit Report
Scope       <path or range> · <T test files> · <S seams>
Tests       <before N> → <after M> · deleted <n> · rewritten <n> · merged <n> · added <n>
Probes      killed <k>/<m> via <stryker | mutmut | cargo-mutants | gremlins | manual> · survivors <n>
Runtime     <before>s → <after>s
Gates       typecheck <pass|fail|n/a> · suite <M/M>
Verdict     <suite bites | survivors: <behaviours> | needs decision: ...>
```

Below the block: each deletion with the coverage that remains; each survivor with the behaviour it exposed; each seam change made in production code. Nothing else.
