# Red Flags

The catalog used by `/clean-code`, `/deslop`, and `/clean-code-review`. Name the flag when reporting a finding: naming it is half the diagnosis.

## Contents

- How to apply
- AI slop tells (comments, dead code, abstraction, defensive code, scope, naming, filler, tests, types)
- Ousterhout's design red flags
- Fowler's smell baseline
- Complexity signals

## How to apply

- A documented repo standard always wins. Where `CODING_STANDARDS.md` endorses something below, the flag is suppressed.
- Slop tells and complexity signals are near-mechanical: report them as violations.
- Design red flags and smells are judgement calls: report them as "possible X", with the hunk quoted and the fix named.
- Skip anything a linter already enforces in this repo; the linter is the source of truth for it.

## AI slop tells

Each entry: **Tell** (what it looks like) and **Fix**.

### Comments
- **Narration**: `// Initialize the counter` above `let counter = 0`; `# Return the result`. Fix: delete.
- **Signature echo**: a docstring whose `@param` and `@returns` restate the names and types. Fix: delete, or replace with the one contract fact the signature does not carry.
- **Workflow numbering**: `// Step 1: validate`, `// Step 2: process`, `// Finally...`. Fix: delete; if the flow is hard to follow, restructure the code.
- **Banners and dividers**: `// ===== HELPERS =====`, `# --- Section ---`, `/* ---------- */`. Fix: delete.
- **Empty labels**: `// Main logic`, `// Helper function`, `// Error handling`, `// Note: this is important`. Fix: delete unless replaced by a specific fact.
- **End markers**: `} // end if`, `# end of function`. Fix: delete.
- **Vague TODO**: `// TODO: improve this`, `// add more validation later`. Fix: delete, or make it a concrete task with an owner or ticket.
- **Decorative emoji and shouting**: `// ✅ Validation`, `// MAIN LOGIC`. Fix: plain sentence case, or delete.
- **Conversational voice**: `// Let's grab the user`, `// Now we need to...`, `// Great, this works!`. Fix: delete.
- **Line-by-line density** in a file that otherwise has few comments. Fix: one comment per non-obvious block, matching the file's density.

### Dead code
- Unused imports, variables, parameters, functions, exports, files. Fix: delete.
- Unreachable branches; conditions the types already rule out. Fix: delete the branch.
- Commented-out code, "kept for reference". Fix: delete; version control is the reference.
- Stubs: `throw new Error("not implemented")`, `pass`, `return null // TODO`, placeholder components. Fix: implement or delete.
- Compatibility shims left behind by a rename or removal: re-exports, `_legacy` aliases, deprecated wrappers, "backwards compatibility" branches nobody asked for. Fix: delete; update the callers.
- Debug leftovers: `console.log`, `print`, `dbg!`, `fmt.Println`, verbose logger calls added during iteration. Fix: delete; keep only logging that belongs to the design.
- Temporary scripts and scratch files created during the task. Fix: delete at the end of the task.

### Abstraction
- **Single-use helper**: a function with exactly one call site that does not create a meaningful interface. Fix: inline.
- **Pass-through wrapper**: a function or class that only forwards to another with the same shape. Fix: call the target directly.
- **One-implementation interface**: an interface, abstract class, or protocol with a single implementer and no second one in sight. Fix: use the concrete type; introduce the seam when the second adapter appears.
- **Factory of one**: a factory or builder that always produces the same thing. Fix: construct directly.
- **Config for constants**: options, flags, or settings that nothing sets. Fix: hardcode the value where it is used; name it if the meaning is unclear.
- **Premature generality**: parameters, generics, hooks, or plugin points for requirements that do not exist. Fix: delete; write for today's callers.
- **Utility dumping ground**: `utils/`, `helpers.ts`, `common/`, `misc.py` collecting unrelated functions. Fix: move each function next to its only user, or into the module that owns the concept.
- **Class for a function**: a class with one method and no state. Fix: a function.
- **Layer for a layer**: controller → service → repository where the middle only forwards. Fix: apply the deletion test; collapse the pass-through.

### Defensive code
- Null or undefined checks on values the type system guarantees. Fix: delete; trust the type.
- `try/catch` around code that cannot throw, or that catches and does nothing. Fix: delete; let errors propagate.
- Validation of internal function arguments called only by trusted code. Fix: validate at the boundary once.
- Silent fallbacks (`?? defaultValue`, `or {}`, `catch: return []`) that hide a failure instead of surfacing it. Fix: fail loudly or handle it explicitly where the caller can act.
- Redundant type assertions and re-checks after a narrowing already happened. Fix: delete.
- Retry, timeout, or cache logic added "to be safe" without a failure that motivated it. Fix: delete unless the requirement exists.

### Scope
- Changes to files, functions, or comments the request did not name and the change did not require. Fix: revert them; mention them in the report instead.
- Reformatting or restyling of untouched lines. Fix: revert.
- New features, options, or "while I'm here" refactors. Fix: revert; propose separately.
- Docstrings, comments, or type annotations added to code that was not changed. Fix: revert.

### Naming
- Redundant qualifiers: `getUserFromDatabase`, `userDataObject`, `handleButtonClickEvent`. Fix: `getUser`, `user`, `onClick`.
- Generic names: `data`, `result`, `item`, `temp`, `info`, `manager`, `processor`, `handler` without a domain word. Fix: name the thing.
- Synonyms for one concept: `fetch`/`get`/`load`/`retrieve` across sibling functions. Fix: one verb per concept.
- Type or scope in the name: `userList`, `strName`, `IUser`, `_privateThing` in languages with visibility. Fix: drop the prefix unless the codebase convention keeps it.
- Booleans that are not predicates: `flag`, `status`, `check`. Fix: `isActive`, `hasChanges`.

### Filler
- Excessive blank-line groups, decorative alignment, ASCII art in code. Fix: match the file's formatting.
- Over-typed locals where inference is obvious: `const count: number = 0`. Fix: drop the annotation, unless the codebase annotates everywhere.
- Template shape: every file follows the same scaffold (header comment, section banners, export block) regardless of content. Fix: shape each file to its content.
- Generated boilerplate left unedited (default README text, sample handlers, example tests). Fix: delete or replace with real content.

### Tests
- Tests that assert on call counts, private state, or internal collaborators. Fix: assert through the public interface.
- Tautological tests whose expected value is computed the same way as the code. Fix: use a known literal or a spec-derived value.
- Duplicate tests covering the same behaviour with cosmetic input changes. Fix: keep one; add a table-driven case only if the input class differs.
- Tests of the framework or the language (`expect(true).toBe(true)`, testing that a getter returns what the setter set). Fix: delete.
- Skipped or commented-out tests without a ticket. Fix: fix or delete.
- Mocks of the project's own modules. Fix: run them for real; mock only external boundaries.
- **Module mocking** (`vi.mock("./store")`, `jest.mock`, `monkeypatch` on an own module): the test replaces the seam instead of using it. Fix: inject the dependency through the interface and pass an in-memory adapter.

### Types and evidence
- `any`, `as any`, `object`, `dict[str, Any]` where a real shape exists. Fix: name the shape.
- **Widen then assert**: a known value stored as `unknown`, `any`, `object`, or `Record<string, unknown>` and cast back to a narrow type later. Fix: keep the inferred type; use `satisfies` where a constraint is wanted.
- **Chained assertions**: `input as object as User`, `x as unknown as T`. Fix: parse at the boundary into `User`; if the assertion is genuinely safe, one assertion with a `SAFETY:` comment naming the invariant.
- **Evidence discarded in signatures**: `unknown` parameters or returns, `Record<string, unknown>` dictionaries, `object` inputs on internal functions. Fix: a named type produced once by the boundary parser.
- **Runtime narrowing inside**: `typeof x === "string"` or `isinstance` checks on values that a boundary already validated. Fix: parse once at the boundary; trust the type inside.
- Suppressions (`# type: ignore`, `@ts-expect-error`, `#[allow]`) without a reason. Fix: fix the type, or leave a one-line reason.
- Boolean pairs that encode a state machine (`isLoading`, `isError`, `isSuccess`). Fix: a discriminated union with one status field.
- Stringly-typed identifiers and enums. Fix: enum, literal union, or distinct ID type.
- Reflection to dodge the type checker (`Reflect.get`, `getattr` with a computed name on a typed object). Fix: typed property access.

## Ousterhout's design red flags

From *A Philosophy of Software Design*. Use the names verbatim.

| Flag | What it looks like | Fix |
|---|---|---|
| **Shallow Module** | Interface as complex as the implementation: trivial wrappers, one-line classes, getters and setters that expose state. | Merge into a deeper module or inline. |
| **Information Leakage** | The same design decision (a format, a rule, a schema) encoded in two or more modules. | Merge the modules, or move the knowledge behind one simple interface. |
| **Temporal Decomposition** | Modules carved by execution order (`read`, `parse`, `write`) instead of by knowledge, so the same knowledge lives in several stages. | Reorganize around what each module knows. |
| **Overexposure** | The common case forces callers to learn rarely used features. | Make the common case simple; move rare options behind a separate path. |
| **Pass-Through Method** | A method that forwards its arguments to another method with the same signature. | Delete it; call the target. |
| **Repetition** | Non-trivial code repeated with small variations. | Extract the shared shape into one deep function. |
| **Special-General Mixture** | Special-purpose code embedded in a general mechanism. | Separate: general mechanism below, special case above. |
| **Conjoined Methods** | Two methods that cannot be understood without reading each other. | Merge them, or redraw the boundary so each stands alone. |
| **Comment Repeats Code** | A comment a reader could write from the code alone. | Delete, or raise the comment to intent or precision. |
| **Implementation Documentation Contaminates Interface** | Interface docs describe how, exposing internals. | Document what callers need; move the how next to the code. |
| **Vague Name** | `count`, `result`, `data`, `time`, `status`. | Name what it holds. |
| **Hard to Pick Name** | No clean name fits. | The concept is muddled, usually two things. Split. |
| **Hard to Describe** | A complete yet simple comment is hard to write. | The design is wrong. Redesign before documenting. |
| **Nonobvious Code** | A first-time reader cannot follow it on a quick read. | Reduce information needed, follow conventions, or add a precise comment. |

Also from the book: **Tactical Tornado** (a stream of quick fixes that each add complexity), **Pass-Through Variable** (a value threaded through methods that do not use it), **False Abstraction** (an interface that hides nothing).

## Fowler's smell baseline

From *Refactoring*, chapter 3. Always a judgement call.

- **Mysterious Name**: rename; if no honest name comes, the design is murky.
- **Duplicated Code**: extract the shared shape and call it from both.
- **Long Parameter List**: bundle the travelling parameters into one typed object.
- **Feature Envy**: a method reaching into another object's data more than its own; move it there.
- **Data Clumps**: the same fields travelling together; make them a type.
- **Primitive Obsession**: a string or number standing in for a domain concept; give it a type.
- **Repeated Switches**: the same conditional on the same type in several places; polymorphism or one shared map.
- **Shotgun Surgery**: one change forces edits across many files; gather what changes together.
- **Divergent Change**: one module edited for unrelated reasons; split so each changes for one reason.
- **Speculative Generality**: hooks and parameters for needs that do not exist; delete.
- **Message Chains**: `a.b().c().d()`; hide the walk behind one method.
- **Middle Man**: a class that mostly delegates; remove it.
- **Refused Bequest**: a subclass ignoring most of what it inherits; prefer composition.

## Complexity signals

Report these with the number. They are the gates `/clean-code-setup` installs.

| Signal | Threshold |
|---|---|
| Cyclomatic complexity of one function | above 10 |
| Nesting depth | above 3 |
| Parameters | above 4 |
| Function length | above 50 lines (examine; length alone is not a violation) |
| File length | above 400 lines |
| Exports from one module | more than its callers use |
