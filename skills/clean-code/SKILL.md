---
name: clean-code
description: Senior-engineer discipline for writing and changing code without AI slop. Use when writing, editing, refactoring, or structuring code in any language, and when the user mentions clean code, slop, over-engineering, tech debt, dead code, simplifying, or project structure.
---

# Clean Code

Write code a senior engineer would merge without comment. The enemy is **slop**: code that works, passes a glance, and still degrades the codebase because it carries narration comments, dead branches, one-call helpers, defensive paranoia, and abstractions for futures that never arrive. Slop is complexity added at machine speed.

Two ideas govern everything below.

- **Every line earns its place.** A line stays when deleting it would lose behaviour or information. Otherwise it goes.
- **Match the codebase, then these defaults.** Read the surrounding code and mirror its comment density, naming, idiom, and structure. A repo's `CODING_STANDARDS.md` (or `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`) overrides this skill. Where the repo has no convention, the rules here apply.

## The loop

Run this for every change, sized to the change. A one-line fix runs it in seconds; a feature runs it deliberately.

1. **Understand.** Read the code to be changed and its callers. Find the existing pattern for this kind of thing and reuse it. Name the **seam** (the interface the change lives behind) and the check that will prove it works. State assumptions. When two readings of the request lead to materially different code, ask before writing.
   Done when one sentence says what changes, where it lives, and how it is verified.
2. **Shape.** Choose the smallest change that fully solves the request. Put new behaviour behind the smallest interface that hides it. For a non-trivial interface, sketch a second, radically different shape before committing to the first.
3. **Write.** Apply the rules below.
4. **Verify.** Run the check: typecheck, focused tests, lint, then the full suite once at the end. Read the output. "Tests pass" means they ran in this session with zero failures.
5. **Interrogate.** Before calling it done, challenge what was built from first principles: what is unnecessary, over-complicated, or resting on a weak assumption? What can be deleted entirely? What simplifies once the deleted pieces are gone? Prefer **deleting over simplifying, simplifying over optimizing, optimizing over automating**. Make the cuts. If it is already right, leave it alone.
6. **Report.** End with the block in [Report](#report).

## Hard gates

A change that fails one of these is not done.

| Gate | Standard |
|---|---|
| **Surgical** | Every changed line traces to the request. Adjacent code, comments, and formatting stay as they were. Orphans created by the change (imports, variables, functions, files) are removed. Pre-existing dead code is reported, not touched. |
| **Zero dead code** | No unused imports, variables, parameters, functions, exports, or files. No unreachable branches. No commented-out code. No stubs, placeholders, or scaffolding for later. Removal is complete: no compatibility shims, re-exports, or `_legacy` aliases unless asked. |
| **Comments carry information** | A comment stays only when it says something the code cannot: why, an invariant, a constraint, a non-obvious consequence, a link to the decision. Narration, restatement, banners, step numbers, and end-of-block markers go. |
| **Structure follows need** | Nothing exists for a caller that does not yet exist: no helper with one call site, no wrapper that only forwards, no interface with one implementation, no option nobody sets, no configuration for what does not vary. |
| **Boundaries validate, internals trust** | Validate at the system edge (user input, network, files, external APIs). Inside, trust the types and invariants. Errors surface; a `catch` that swallows, a fallback that hides a failure, or a null check on a guaranteed value is a bug. |
| **Tests earn their place** | Every test protects a behaviour a caller depends on, at the public seam, and would fail on a plausible bug. Tests of trivial code, framework behaviour, private internals, and duplicates of existing coverage are not written, and are deleted when found. Fewer tests that can fail beat many that cannot. |
| **Evidence before done** | The verification command ran in this session, its output was read, and it passed. A claim without a fresh run is a guess. |

## Writing rules

### Simplicity
- Write the minimum code that solves the problem. If 200 lines could be 50, rewrite.
- Inline the abstraction that has one user. Extract on the third caller, or when the extraction creates a real interface (see Structure).
- Prefer a plain function to a class, a value to a flag, a lookup table to a recurring switch, a guard clause to nesting.
- Keep the happy path at the top level and unindented; handle the special case early and return.
- Design special cases out of existence: model "no selection" as an empty range rather than an `if (hasSelection)` at every use.
- Inside the lines being touched, leave the design as it would be if the change had been known from the start. Outside them, report what was seen and leave it.

### Structure: deep modules
- A **module** (function, class, package, service) is deep when a lot of behaviour sits behind a small interface. Aim for that shape at every scale.
- The **interface** is everything a caller must know: signature, invariants, ordering, error modes, configuration, performance. Keep all of it small.
- Apply the **deletion test** to any layer: if deleting it makes complexity vanish, it was a pass-through. If complexity would reappear across callers, it earns its keep.
- Pull complexity downward. A harder implementation that gives callers a simpler contract is the right trade.
- One implementation of an interface means a hypothetical seam; two means a real one. Introduce the seam at two.
- Keep each piece of knowledge in one place. When a format, rule, or mapping shows up in two modules, merge them or move the knowledge behind one simple interface.
- Files mirror the module map: a module gets a folder, its public surface at the root, implementation and tests in subfolders. Outsiders import entry points only.
- Length is not a reason to split. A 150-line function with one job and a simple signature is deep; six 25-line functions that only make sense together are shallow.
- Layout, dependency direction, and language shape: [STRUCTURE.md](STRUCTURE.md).

### Naming
- Names are precise (the name alone says what it holds) and consistent (one term per concept, never reused for another).
- Length scales with scope: `i` in a five-line loop, `retryBudgetMs` across a module.
- Booleans read as predicates (`isExpired`, `hasBalance`); functions as verbs; types as nouns.
- Drop redundant qualifiers: `getUserFromDatabase` is `getUser` unless another source exists; `userAccountStatus` inside `User` is `status`.
- A name that is hard to pick means the concept is muddled, usually two things. Split it.
- Use the project's domain vocabulary (`CONTEXT.md`, glossary, existing names) rather than inventing synonyms.

### Errors
- First, define the error out of existence by making the operation total: `delete` ensures absence, `substring` clamps.
- Handle each error once, at the level that can act on it. Let it propagate through levels that cannot.
- Fail loudly on the impossible. Messages name what failed, what was expected, and the values involved.
- Use the language's idiom for propagation (typed results, `%w` wrapping, `?`, specific exception classes) as the codebase already does.
- Hierarchy and per-language idiom: [ERRORS.md](ERRORS.md).

### Comments
- Default density is the file's density. In a file with no comments, add one only for something genuinely non-obvious.
- A good comment sits at a different level than the code: precision (units, boundaries, ownership, null semantics) or intuition (the sentence that explains the block).
- Diagnostic: could a reader who has never seen this code write this comment from the code alone? If yes, delete it.
- Docstrings state the contract for callers (what, preconditions, errors), never the implementation. Skip docstrings that restate the signature.
- `TODO` carries an owner or ticket and a concrete task.
- Keep and delete lists with examples: [COMMENTS.md](COMMENTS.md).

### Tests
- Write a test when a plausible bug would make it fail and a caller would care. Trivial code, getters, framework behaviour, and private helpers get none. Pick the level (unit, integration, end-to-end, contract, property) by the seam where the behaviour is observable, not by habit.
- Test behaviour through the public interface. A test that must reach past the interface means the module is the wrong shape.
- Expected values come from an independent source (a known literal, the spec), never recomputed the way the code computes them.
- Mock only at system boundaries the project does not own. Own modules run for real.
- One behaviour per test, named as the capability ("rejects expired token"), not the mechanism.
- Red before green when fixing a bug: the test fails first, then the fix makes it pass.
- Tests that duplicate coverage or exercise the framework are dead code with a runtime cost. Delete them.
- Good, bad, and mocking policy: [TESTS.md](TESTS.md).

### Types
- Make illegal states unrepresentable: discriminated unions over boolean pairs, enums over strings, distinct ID types where mix-ups are plausible.
- Casts, `any`, and suppression comments (`@ts-ignore`, `# type: ignore`) appear only with a one-line reason. A type that is hard to name signals an unclear design.
- Annotate public signatures and exported values; let inference carry the rest.

## Complexity budget

Numbers a linter can enforce. Crossing one is a signal to restructure, not a rule to satisfy by extracting a meaningless helper.

| Measure | Limit |
|---|---|
| Cyclomatic complexity per function | 10 |
| Nesting depth | 3 |
| Parameters | 4, bundling the rest into a typed object |
| Function length | 50 lines is a smell to examine, not a limit |
| File length | 400 lines is a signal to split by responsibility |

`/clean-code-setup` wires these into the repo's linter. When a gate exists, passing it is part of done.

## Done gate

Copy and check every box before reporting completion.

```
- [ ] Every changed line traces to the request; nothing adjacent was "improved"
- [ ] No dead code, stubs, commented-out code, or compatibility shims
- [ ] Every remaining comment says something the code cannot
- [ ] No abstraction with a single user; no option nobody sets
- [ ] Validation at boundaries only; errors surface; no masking fallbacks
- [ ] Names precise and consistent with the codebase
- [ ] Complexity gates pass (or none exist yet)
- [ ] Every new test can fail on a plausible bug; no test of trivial code, framework, or internals
- [ ] Typecheck, lint, focused tests, full suite: run this session, output read, passing
- [ ] Interrogated: nothing left to delete or simplify
```

## Report

Close every piece of work with this block. Fill the numbers from `scripts/diff-stats.sh [base]` (run from the repo root; needs git and bash) and from the commands that actually ran. Ten lines or fewer.

```
## Clean Code Report
Scope     <request in one line> · <N files>
Diff      +<added> / -<removed> lines · net <±n>
Removed   dead code <n> · comments <n> · debug statements <n> · abstractions <n>
Gates     typecheck <pass|fail|n/a> · lint <pass|fail|n/a> · tests <passed>/<total> · complexity <max or n/a>
Left      <things noticed outside scope, or "nothing">
Verdict   <ready | needs decision: ...>
```

Report only what happened. A gate that did not run says `n/a`, never `pass`.

## Reference

Load only what the task needs; every link is one level deep.

- [RED-FLAGS.md](RED-FLAGS.md): the catalog. AI slop tells, Ousterhout's design red flags, Fowler's smells, each with its fix. Name the flag when reviewing.
- [COMMENTS.md](COMMENTS.md): comments to keep and delete, with examples.
- [STRUCTURE.md](STRUCTURE.md): project layout, module shape, dependency direction, language notes.
- [ERRORS.md](ERRORS.md): the four-tool hierarchy and per-language idiom.
- [TESTS.md](TESTS.md): good tests, bad tests, mocking policy.

Companion skills: `/interrogate` challenges a finished change; `/deslop` cleans existing code in behaviour-preserving passes; `/clean-code-review` reviews a diff in a fresh context; `/clean-code-setup` installs the lint gates and `CODING_STANDARDS.md`.
