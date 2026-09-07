# Errors

Exception handling is one of the largest sources of complexity in a codebase. The goal is fewer places where errors must be handled, and no place where one is hidden.

## The hierarchy

Use the tools in this order.

1. **Define the error out of existence.** Redesign the operation so the case is normal. `delete(path)` ensures the file is absent rather than failing when it already is. `substring(a, b)` clamps rather than throwing on out-of-range. "No selection" is an empty range, not a null. Every such redesign deletes a branch from every caller.
2. **Mask at a low level.** Handle it where the information to recover exists and callers gain nothing from knowing. A network layer retries a transient failure; callers see a byte stream.
3. **Aggregate.** Let errors propagate to one handler high in the call chain that can act on them (return a 500, abort the request, report and continue with the next item). Lower levels attach context and pass through.
4. **Crash.** For conditions that cannot be recovered from (corrupt state, violated invariant, out of memory), stop loudly with a message that names the invariant.

Do not define an error away when callers genuinely need the information. A storage module that swallows every transport failure makes a robust application impossible to build on top of it.

## Boundaries validate, internals trust

- Validate once, at the edge: HTTP handlers, CLI parsing, file readers, message consumers, external API responses. Produce a typed value.
- Inside, trust the type. A function receiving a `UserId` does not re-check that it is non-empty.
- Internal function arguments from trusted callers are not validated. If a bug produces a bad value, an assertion that crashes is better than a check that quietly returns.

## What is never acceptable

```ts
try {
  await save(order);
} catch (e) {
  // ignore
}
```

```py
try:
    total = compute(items)
except Exception:
    total = 0
```

```go
result, _ := parse(input)
```

```ts
const user = (await fetchUser(id)) ?? {};
```

- An empty `catch`, or one that only logs and continues, hides the failure and moves the crash somewhere harder to debug.
- A fallback value that masks a failure turns a loud bug into a silent wrong answer.
- Discarding an error return in Go with `_` outside of a documented reason.
- Catching a broad exception class at a low level.
- Retrying without a bound.

When a failure is genuinely acceptable to continue past, say so in code: catch the specific error, record it where it will be seen, and continue with explicit intent.

## Messages

An error message names what failed, what was expected, and the values involved:

```
config: DATABASE_URL is required but was not set
invoice 8213: cannot finalize with 0 line items
parse users.csv line 42: expected 5 columns, got 3
```

Add context at each level that has some (`%w` in Go, exception chaining in Python, `.context()` in Rust with `anyhow`), so the top-level handler sees the whole path without a stack trace.

## Logging

- Log at boundaries and at the aggregate handler, structured, with the identifiers needed to find the case again.
- Inside pure logic, no logging.
- Debug prints added during a task are removed before the task ends.
- Never log secrets, tokens, or full request bodies by default.

## Language idiom

Follow the codebase; where it has no convention, these apply.

**TypeScript / JavaScript**
- Throw `Error` subclasses with a `name` and the contextual fields; or return a discriminated `Result` union when the codebase already does.
- `catch (e: unknown)`, narrow before use.
- No `Promise` left unhandled; no `.catch(() => {})`.

**Python**
- Raise specific exception classes; define a small hierarchy per domain module when more than one kind exists.
- `raise ... from e` to chain.
- `except Exception` only at the process boundary (request handler, worker loop, CLI main).
- No bare `except:`.

**Go**
- Return errors; wrap with `fmt.Errorf("doing x: %w", err)`.
- Sentinel errors and `errors.Is` / `errors.As` for callers that need to branch.
- Handle each error once: either log it or return it, not both.
- `panic` only for programmer errors that cannot be reached by valid input.

**Rust**
- `Result<T, E>` with `?`; a crate-level error enum via `thiserror` for libraries, `anyhow` with `.context()` for binaries.
- `unwrap` and `expect` only in tests, or with a comment stating the invariant that makes it safe.
- `Option` for absence that is normal; `Result` for failure.
