# Comments

Comments are a design tool, not a documentation tax. Writing one is the cheapest moment to discover a design is wrong: if a complete yet simple comment is hard to write, fix the code.

## The rule

A comment describes something not obvious from the code, judged from a first-time reader's point of view. It sits at a different level than the code:

- **Precision** (lower level): units, boundary inclusivity, null semantics, ownership, invariants. Best on declarations.
- **Intuition** (higher level): the one sentence that explains what a block is for. Best at the top of a method or a tricky block.

A comment at the same level as the code repeats it and adds nothing.

**Diagnostic**: could someone who has never seen this code write this comment by looking only at the code next to it? If yes, delete it.

**Density**: match the file. In a file with no comments, add one only for something genuinely non-obvious. In a heavily documented codebase, follow its docstring conventions.

## Delete

```ts
// Initialize the counter
let counter = 0;

// Loop over the items
for (const item of items) {
  // Add the item to the total
  total += item.price;
}

// Return the total
return total;
```

becomes

```ts
let counter = 0;
for (const item of items) {
  total += item.price;
}
return total;
```

```py
# ==========================================
# HELPER FUNCTIONS
# ==========================================

def parse_date(value: str) -> date:
    """Parse a date.

    Args:
        value: The date string.

    Returns:
        The parsed date.
    """
```

becomes

```py
def parse_date(value: str) -> date:
    """Accepts ISO 8601 only; naive values are treated as UTC."""
```

Delete on sight:

- Narration of the next line.
- Section banners, dividers, ASCII boxes.
- `// Step 1 / Step 2 / Finally`.
- `} // end if`, `# end of loop`.
- `// Main logic`, `// Helper`, `// Error handling`, `// Note: important`.
- `// TODO: improve`, `// add more later`.
- Emoji, ALL CAPS, conversational voice (`Let's`, `Now we`, `Great!`).
- Commented-out code.
- File headers that restate the filename or list the file's functions.
- Docstrings that only echo the signature.

## Keep

Keep comments that explain what the code cannot:

```ts
// Stripe retries webhook delivery for up to three days.
// Deduplicate on event id, not on timestamp.
if (seenEvents.has(event.id)) return;
```

```go
// offsets are byte positions into the original buffer, inclusive start,
// exclusive end. Callers must not hold them across a compaction.
type Span struct{ Start, End int }
```

```py
# The vendor API returns 200 with an empty body on rate limit.
# Treat an empty body as retryable rather than as success.
```

```rs
/// Returns the balance in minor units (cents). Never negative:
/// overdrafts are modelled as a separate `Debt` entry.
pub fn balance(&self) -> u64
```

Categories that earn their place:

- Why this way and not the obvious way.
- Invariants and preconditions callers must respect.
- Units, ranges, encodings, time zones, inclusivity.
- Ownership and lifetime (who frees, who closes, who may mutate).
- Concurrency assumptions.
- Workarounds for external bugs, with a link.
- Security and performance consequences that are not visible locally.
- Protocol and API contract details.
- Legal notices.

## Docstrings and interface comments

- Describe the contract as callers see it: what it does, preconditions, error modes, side effects. Never the implementation.
- Skip parameters whose name and type already say everything. Document the one that has a constraint.
- A public function in a library gets a docstring if the codebase documents public API. An internal function gets one only when its contract is not obvious.
- Write the interface comment before the body when designing a new module; if it is hard to write, the interface is wrong.

## TODO

A `TODO` is a task, not a feeling. It carries a concrete action and an owner or ticket:

```ts
// TODO(#482): remove once the v1 export endpoint is retired.
```

Anything else is deleted or turned into a ticket.

## Language notes

- **TypeScript / JavaScript**: TSDoc on exported API when the repo uses it; no JSDoc types on typed code; no `@param` echoes.
- **Python**: one-line docstrings for the common case; the repo's docstring style (Google, NumPy, reST) for public API; no docstring on private helpers whose name says it all.
- **Go**: doc comments on exported identifiers start with the name (`// Balance returns ...`); this is the convention, not narration. Keep them to the contract.
- **Rust**: `///` on public items with the contract and panics/errors sections when they apply; `//!` only for module-level intent.
- **Any language**: a comment that would be wrong after a routine refactor of the same lines is at the wrong level; raise it or delete it.
