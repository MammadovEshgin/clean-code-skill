# Tests

Tests are the feedback loop that lets an agent work unattended and lets a human trust the result. Bad tests are worse than none: they cement implementation details, pass by construction, and cost runtime while proving nothing.

## Which tests to write

The question for every candidate test: **what plausible bug would make this fail, and would a caller care?** No answer, no test.

Worth writing:

- The behaviour the change exists for, at the public seam, on the happy path and on the edge cases the spec names (empty input, boundaries, invalid input at a boundary, concurrency where it applies).
- A regression test for every bug fixed, written red first.
- A contract test at each external boundary the project depends on (a request shape, a response shape, a schema).
- A property-based test for an algorithm with an invariant (round-trips, ordering, idempotence), in place of many hand-written examples.
- One integration or end-to-end test per user-facing flow, when the units cannot show the flow works together.

Not worth writing:

- Tests of trivial code: getters, setters, constructors, pass-through functions, constants, type definitions.
- Tests that a framework, library, or language feature works.
- Tests of private functions and internal helpers; test them through the public behaviour they support.
- Tests that assert a mock was called; they verify the collaboration, not the outcome.
- Duplicates of existing coverage with cosmetic changes to the input.
- Snapshot tests of large output that nobody reads when they change.
- Tests written to raise a coverage number.

Pick the level by the seam where the behaviour is observable: unit for pure logic behind a function, integration for a module with a real dependency, end-to-end for a flow across a boundary. A level chosen by habit ("every file gets a unit test") produces shallow tests of shallow modules.

Coverage is a symptom, not a goal. A module with three tests that can fail is better protected than one with thirty that cannot. The measure that matters is the mutation score: break the code on purpose and count the tests that notice (see [Mutation probes](#mutation-probes)).

## What a good test is

- It verifies behaviour through the public interface. The implementation can change entirely; the test should not.
- It asserts state and outcomes, never interactions. "The order is confirmed" survives a refactor; "`process` was called with the total" does not.
- It reads like a specification: `"user can check out with a valid cart"`, `"rejects an expired token"`.
- Its expected values come from an independent source: a known literal, a worked example, the spec.
- It exercises one behaviour and makes one logical assertion.
- It is deterministic: time, randomness, ordering, and network are controlled.
- It is self-contained: the reader sees the setup, the action, and the expectation without following helpers. Repetition across tests is cheaper than a helper that hides what is being tested.
- It was seen red once. A test that has never failed has never proven anything.

```ts
test("checkout confirms an order for a valid cart", async () => {
  const cart = createCart([{ sku: "A1", qty: 2 }]);
  const result = await checkout(cart, testPayment());
  expect(result.status).toBe("confirmed");
});
```

## Seams

A **seam** is the public boundary a test crosses. Tests live at seams, never against internals.

- Before writing tests for new work, name the seams under test. Prefer existing seams; prefer the highest seam that still gives a fast, deterministic signal.
- The ideal number of seams for a feature is small. A feature tested at one well-chosen seam beats one tested at ten shallow ones.
- If a test needs to reach past the seam to observe something, the module is the wrong shape. Fix the module, not the test.

## Anti-patterns

**Implementation-coupled**

```ts
test("checkout calls paymentService.process", async () => {
  const spy = jest.spyOn(paymentService, "process");
  await checkout(cart, payment);
  expect(spy).toHaveBeenCalledWith(cart.total);
});
```

The tell: the test breaks on a refactor that changes no behaviour. Fix: assert on the outcome (`result.status`, a retrievable record), not the collaboration.

**Verified through a side channel**

```ts
await createUser({ name: "Alice" });
const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
expect(row).toBeDefined();
```

Fix: verify through the interface: `getUser(user.id)`.

**Tautological**

```ts
const expected = items.reduce((sum, i) => sum + i.price, 0);
expect(calculateTotal(items)).toBe(expected);
```

The expected value is computed the way the code computes it, so the test cannot disagree with the code. Fix: `expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15)`.

The same tautology in another costume: a test that reads an artifact and asserts it contains itself.

```php
test('the layouts opt into dark mode', function () {
    expect(file_get_contents(resource_path('css/app.css')))
        ->toContain('@media (prefers-color-scheme: dark)');
});
```

It can only fail when someone edits the file it copies. Fix: render the page and assert the behaviour, or delete the test.

**Weakened check**

```diff
- expect(total).toBe(15);
+ expect(total).toBe(14.99);
```

```ts
test.skip("rejects a negative quantity", ...)
```

A test rewritten to match new behaviour, a skipped test, a lowered coverage threshold, or a new suppression is the cheapest path to green, and the signature failure of agent-written changes. Read test diffs before code diffs. Fix: restore the test; fix the code; if the behaviour really changed, the commit says why.

**Horizontal slicing**: writing all tests first, then all implementation. Bulk tests describe imagined behaviour and go insensitive to real changes. Fix: vertical slices, one test then one implementation, each test a tracer bullet informed by the last.

**Testing the framework or the language**: `expect(true).toBe(true)`, a getter returning what a setter set, a library's own validation. Fix: delete.

**Duplicate coverage**: five tests that differ only in a cosmetic input. Fix: keep one, or a table-driven test when the input classes genuinely differ.

**Skipped tests** without a ticket. Fix: fix or delete.

## Mocking policy

Mock only at system boundaries the project does not own:

- External APIs (payment, email, third-party services).
- Time and randomness.
- Sometimes the file system and the database; prefer a real local stand-in (temp dir, SQLite, PGlite, a container) when the suite can afford it.

Run for real:

- The project's own modules and classes.
- Internal collaborators.
- Anything the project controls.

Design boundaries so mocking is natural: accept dependencies as parameters instead of constructing them inside; expose one function per external operation (`api.getUser(id)`, `api.createOrder(data)`) rather than one generic `api.fetch(endpoint, options)` that forces conditional logic into every mock.

Module mocking (`vi.mock("./user-store")`, `jest.mock`, `monkeypatch.setattr` on an own module) is the tell that a seam is missing: the test rewires the import graph instead of passing a dependency. Add the parameter, pass an in-memory adapter, and the mock disappears along with the coupling to file paths.

## Bug fixes: red before green

1. Write the test that reproduces the bug at the seam where the bug is observable. Run it. It fails.
2. Fix the bug.
3. Run it. It passes.
4. Run the full suite.

A regression test that never went red proves nothing. If no seam can express the bug, that is a finding about the architecture; report it.

## Mutation probes

The direct test of a test: change the code so it is wrong, run the suite, and see whether anything notices. A mutant nothing kills is either untested behaviour or dead code.

- With a tool: StrykerJS (`npx stryker run`), mutmut (`mutmut run`), pytest-gremlins (`pytest --gremlins`), cargo-mutants (`cargo mutants`), gremlins (`gremlins unleash`). Read the survivors, not the score.
- By hand, three mutants per module, one at a time: negate one condition; shift one boundary by one; return a constant, an empty collection, or `null`. Copy the file beside itself as `<file>.probe` first, restore it with `mv` after, and confirm `git status` is unchanged.
- A survivor gets a test named for the behaviour it exposed, and that test is watched killing the mutant before the mutant is reverted.
- In a finishing pass, probe only the functions the change touched. In a cleanup, probe every module in scope.

`/test-audit` runs this procedure and reports `probes killed k/m`.

## What to run, and when

- Find the real commands first: `package.json` scripts, the `Makefile`, the CI workflow. Never assume `npm test`.
- Typecheck after each batch of edits.
- The focused test file while iterating.
- Lint and the full suite once at the end.
- Report the commands and the counts. "34/34 passed" is evidence; "should pass" is not.

## Tests are code

The clean-code rules apply to tests: no dead tests, no narration comments, precise names, helpers only when three tests share setup. A test file that needs a banner to be navigable is too long; split by behaviour.
