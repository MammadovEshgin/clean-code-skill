---
name: clean-code
description: Senior-engineer discipline for writing and changing code without AI slop. Use when writing, editing, refactoring, or structuring code in any language, and when the user mentions clean code, slop, over-engineering, tech debt, dead code, simplifying, security, or project structure.
---

# Clean Code

Write code a senior engineer would merge without comment. The enemy is **slop**: code that works, passes a glance, and still degrades the codebase: narration comments, dead branches, one-call helpers, defensive paranoia, copy-pasted blocks, abstractions for futures that never arrive, tests that cannot fail. Slop is complexity added at machine speed.

Three ideas govern everything below. **Every line earns its place**: a line stays when deleting it would lose behaviour or information. **Match the codebase, then these defaults**: mirror the surrounding comment density, naming, idiom, and structure; a repo's `CODING_STANDARDS.md` (or `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`) overrides this skill. **Evidence over confidence**: the burden of proof is on the author; a change ships with the command that proves it, the test that went red before it, and a plain statement of what was not verified.

## The loop

Sized to the change: seconds for a one-line fix, deliberate for a feature.

1. **Understand.** Read the code and its callers; reuse the existing pattern for this kind of thing. Name the **seam** (the interface the change lives behind) and the check that proves it. For a library outside the standard library, read its current docs or types; recalled APIs go stale. When two readings of the request lead to different code, present both with a recommendation and ask. Done when one sentence says what changes, where, and how it is verified.
2. **Shape.** The smallest change that fully solves the request, behind the smallest interface that hides it. Sketch a second, radically different shape for any non-trivial interface. Write the naive, obviously correct version first; optimize only against a measurement.
3. **Write.** Apply the gates and rules below.
4. **Verify.** Typecheck, focused tests, lint, then the full suite once. Close the loop with real execution where it applies (run the program, the request, the browser). Read the output. "Tests pass" means they ran in this session with zero failures.
5. **Interrogate.** What is unnecessary, over-complicated, or resting on a weak assumption? What can be deleted entirely, and what simplifies once it is gone? Prefer **deleting over simplifying, simplifying over optimizing, optimizing over automating**. Make the cuts; if it is already right, leave it alone.
6. **Report.** End with the block in [Report](#report).

## Hard gates

A change that fails one of these is not done. These eight rows are the checklist; there is no second list.

| Gate | Standard |
|---|---|
| **Surgical** | Every changed line traces to the request. Adjacent code, comments, and formatting stay as they were; a comment that is not understood is left alone. Orphans the change created (imports, variables, functions, files) are removed. Pre-existing dead code is reported, not touched. |
| **Zero dead code** | No unused symbols, unreachable branches, commented-out code, stubs, placeholders, or scaffolding for later. Removal is complete: no shims, re-exports, or `_legacy` aliases unless asked. On a published surface (package exports, an API, a CLI flag), "unused" must include consumers outside the repo; that removal is a decision, not a cleanup. |
| **Comments carry information** | A comment stays only when it says what the code cannot: why, an invariant, a constraint, a consequence, a link to the decision. Narration, restatement, banners, step numbers, and end markers go. The why that does not fit a comment goes in the commit body. |
| **Structure follows need** | An abstraction earns its place by hiding a decision, naming a concept, or isolating what varies. A one-caller helper that hides nothing is inlined; one that names a calculation may stay. An interface with one implementation is a hypothetical seam unless a second adapter exists or is named in writing (a test fake, a vendor boundary). No forwarding wrapper, no option nobody sets, no config for what does not vary, no copy of a helper that exists elsewhere. |
| **Boundaries validate, internals trust** | Parse untrusted input once at the edge (user input, network, files, external APIs) into a named type; inside, trust the types and invariants. Errors surface: a `catch` that swallows, a fallback that hides a failure, or a null check on a guaranteed value is a bug. |
| **Safe by default** | Queries parameterized; shell, path, URL, and HTML sinks never receive raw strings. Authorization checked at every entry point for the object, not just the session. Secrets from configuration. Every external call has a timeout; retries only where the operation is idempotent, and then bounded. Multi-step writes atomic or idempotent. No secrets or personal data in logs. Failure closes, never opens. Catalog with evidence and fixes: [BUGS.md](BUGS.md). |
| **Tests can fail** | Every test protects a behaviour a caller depends on, at the public seam, and was seen red once. It asserts an outcome; an interaction only when the interaction is the contract at an external boundary (a charge captured once, an event published). No tests of framework behaviour, private internals, or duplicates; a test of trivial code stays only when that value is a contract callers depend on. Expected values come from an independent source, never recomputed the way the code computes them. Mock only boundaries the project does not own; inject a dependency instead of mocking an own module. |
| **Evidence before done** | The verification command ran in this session, its output was read, and it passed. Green was never reached by weakening the check: a test rewritten to match new behaviour, a skip, a lowered threshold, a suppression, or a stub is a finding, not a fix. A test changed on purpose carries the reason in the commit; a test deleted names the coverage that remains. |

## Writing rules

Only what the gates do not already say.

- **Simplicity.** If 200 lines could be 50, rewrite. One thing per line: an intermediate variable with a precise name beats a call chained into an index into a ternary. Three similar lines beat a premature abstraction; copy-pasted blocks with cosmetic variation are worse than both. Prefer a function to a class, a value to a flag, a lookup table to a recurring switch, a guard clause to nesting. Happy path unindented at the top; special cases handled early, or designed out of existence (an empty range instead of "no selection" checks). A refactor that moves code without reducing what a reader must hold in their head is not an improvement.
- **The better shape.** Inside the lines being touched, leave the design as it would be had the change been known from the start. When the code being changed is the wrong shape and a clearly better one exists (a smaller interface, a special case gone, one piece of knowledge in one place) and the seam tests pass unchanged, write the better shape. Outside the lines being touched, report and leave it.
- **Deep modules.** A lot of behaviour behind a small interface, at every scale. The interface is everything a caller must know: signature, invariants, ordering, errors, configuration, performance. Deletion test for any layer: complexity that vanishes when the layer is imagined away was a pass-through. Pull complexity downward; one piece of knowledge in one place; a module gets a folder with its public surface at the root. Length alone is no reason to split. Layout, dependency direction, structure problems and safe moves: [STRUCTURE.md](STRUCTURE.md).
- **The day it goes wrong.** Accept dependencies as parameters; return results instead of mutating inputs. Pure core, effects at the edge. Total operations where the domain allows, illegal states unrepresentable where it does not. One owner per resource with a close on the error path. A check followed by an act on shared state is a race until it is atomic. Bound the work to the input: paginate, stream, batch; a query inside a loop is a finding.
- **Naming.** Precise (the name alone says what it holds) and consistent (one term per concept). Length scales with scope. Booleans as predicates, functions as verbs, types as nouns. Drop redundant qualifiers. A hard-to-pick name means two concepts; split. Use the project's domain vocabulary.
- **Errors.** Define the error out of existence first (`delete` ensures absence, `substring` clamps). Handle each error once, at the level that can act on it. Fail loudly on the impossible and closed on the sensitive. Messages name what failed, what was expected, and the values. The language's idiom, as the codebase already uses it: [ERRORS.md](ERRORS.md).
- **Comments.** Default density is the file's. Precision (units, boundaries, ownership, null semantics) or intuition (the sentence that explains a block); never what a first-time reader could write from the code. Docstrings state the contract, not the implementation. `TODO` carries an owner or ticket and a concrete task. Keep and delete lists: [COMMENTS.md](COMMENTS.md).
- **Tests.** Level (unit, integration, end-to-end, contract, property) by the seam where the behaviour is observable, not by habit. One behaviour per test, named as a capability, self-contained over shared setup. Red before green. Find the repo's real test command in `package.json`, the `Makefile`, or CI. Good, bad, mocking, mutation probes: [TESTS.md](TESTS.md).
- **Types as evidence.** Parse once at the boundary; `typeof` narrowing inside, or `unknown`, `any`, `object`, `Record<string, unknown>` in internal signatures, means the evidence was thrown away. Never launder a type (widen then assert, chained casts, casts to satisfy the compiler); a necessary assertion carries a `SAFETY:` comment naming the invariant. Discriminated unions over boolean pairs, distinct ID types where mix-ups are plausible. Suppressions only with a one-line reason.
- **Instruction files.** `CLAUDE.md`, `AGENTS.md`, `README.md`, and memory files fill with implementation details, session observations, and stale docs. Write only what cannot be found by reading the code, delete what has gone stale in the same edit, and put a rule that must always hold into a test, a lint rule, or a hook instead of prose. When the user corrects a pattern, offer one dated line for `CODING_STANDARDS.md`; the review enforces it from then on.

## Complexity budget

Numbers a linter can enforce; crossing one means restructure along responsibilities, not extract a meaningless helper.

| Measure | Limit |
|---|---|
| Cyclomatic complexity per function | 10 |
| Nesting depth | 3 |
| Parameters | 4, the rest in a typed object |
| Function length | 50 lines is a smell to examine, not a limit |
| File length | 400 lines is a signal to split by responsibility |

`/clean-code-setup` wires these into the linter. `scripts/complexity.sh [path]` prints every function's complexity, the hotspots, and **erosion** (the share of complexity in functions over budget).

## Report

Close every piece of work with this block. Numbers from `scripts/diff-stats.sh [base]` and `scripts/complexity.sh [path]` (repo root; git and bash) and from the commands that actually ran. A gate that did not run says `n/a`, never `pass`.

```
## Clean Code Report
Scope       <request in one line> · <N files>
Diff        +<added> / -<removed> lines · net <±n>
Removed     dead code <n> · comments <n> · debug statements <n> · abstractions <n>
Gates       typecheck <pass|fail|n/a> · lint <pass|fail|n/a> · tests <passed>/<total>
Complexity  max <n> · over budget <n> · erosion <x%>   (or n/a)
Unverified  <what could not be run, and why, or "nothing">
Left        <things noticed outside scope, or "nothing">
Verdict     <ready | needs decision: ...>
```

## Reference

Load the section the task needs, not the file: `grep -n '^##' <file>` shows the map. Every link is one level deep.

- [RED-FLAGS.md](RED-FLAGS.md): slop tells by category, Ousterhout's red flags, Fowler's smells, complexity signals, each with its fix.
- [BUGS.md](BUGS.md): correctness, robustness, and security tells with the evidence each needs; severity, confidence, reproduction.
- [COMMENTS.md](COMMENTS.md), [STRUCTURE.md](STRUCTURE.md), [ERRORS.md](ERRORS.md), [TESTS.md](TESTS.md): as linked above.

Companion skills: `/finish` before a commit; `/deslop` and `/deslop repo` for existing code; `/audit`, `/test-audit`, `/interrogate`, `/clean-code-review` for the pieces; `/clean-code-setup` for the gates and hooks.
