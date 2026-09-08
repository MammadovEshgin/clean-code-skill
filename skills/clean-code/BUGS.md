# Bugs, Weaknesses, and Security

The catalog used by `/clean-code` (to avoid them while writing), `/audit` (to find and fix them), and `/clean-code-review` (the correctness axis). Each entry is a **tell**, the **evidence** that makes it a finding, and the **fix**.

## Contents

- How to apply
- Correctness
- Robustness
- Security
- Excluded unless a concrete path exists
- Evidence and fix protocol

## How to apply

- **Trace data, not files.** Start at every entry point in scope (HTTP handler, CLI argument, queue consumer, file reader, webhook, cron job, environment variable) and follow each value to the sinks it reaches (database, shell, filesystem, network, template, `eval`, log, response). A bug is a path where a value can arrive in a state the sink does not expect. A security flaw is a path where an attacker controls that value.
- **Name the failure.** A finding is written as "given `<input>`, `<code>` does `<wrong outcome>`; expected `<right outcome>`". A finding that cannot be written that way is a hunch; keep looking or drop it.
- **Four facts before reporting.** Severity, confidence, reproduction, and action, as defined in [Evidence and fix protocol](#evidence-and-fix-protocol). Report `certain` and `likely`; fix only `reproduced`. A senior engineer who cannot name the input that breaks the code does not raise the finding.
- **Contrast with defensive paranoia.** Inside a boundary, the types are trusted and a check on a guaranteed value is slop. At the boundary, a missing check on an untrusted value is a bug. Which side of the boundary a value sits on decides which rule applies.
- **The repo's existing secure pattern wins.** When the codebase already has a parameterized query helper, an authorization middleware, a validated config loader, the fix uses it. A second way to do the same thing is a new place for the same bug.

## Correctness

### Boundaries and ranges
- **Tell**: `<` where `<=` is meant, `length - 1` arithmetic, inclusive and exclusive ends mixed, a last page that is never fetched, an empty or single-element input never considered. **Evidence**: a test at the boundary value and one past it. **Fix**: state the range convention once (half-open by default), test both edges.

### Absence
- **Tell**: `find` or a map lookup used without handling the missing case at a boundary; optional chaining that turns a missing value into a silently wrong result (`user?.plan?.limit ?? 0`); a default that stands in for missing data. **Evidence**: the input that makes the value absent, and the wrong result it produces. **Fix**: handle absence where it is possible, once, and fail loudly where it is not.

### Error paths
- **Tell**: `catch` that logs and continues with partial state; an exception thrown after a side effect with no rollback; `finally` overriding a return; `await` missing so the `try` does not cover the rejection; an error from a helper mapped to a generic message that loses the cause. **Evidence**: force the error (throw in the dependency, disconnect the fake) and observe the state afterwards. **Fix**: the hierarchy in [ERRORS.md](ERRORS.md); every side effect either completes or is undone.

### Async and concurrency
- **Tell**: a promise not awaited or not returned (errors vanish); `forEach(async ...)`; `Promise.all` where one failure must not abort the rest, or `allSettled` where it must; shared mutable module state across requests; a check followed by an act (`exists` then `create`, read balance then write) with no lock or constraint; a handler that is not idempotent though its caller retries; a goroutine or task with no way to stop; a blocking call inside an event loop. **Evidence**: two concurrent calls, or a rejection in the un-awaited branch, produce the wrong outcome. **Fix**: await and return every promise; make the act atomic (a unique constraint, an upsert, a transaction, a compare-and-set); key idempotency on a caller-supplied id; give every background task a cancellation path.

### Time
- **Tell**: local time where UTC is stored; month arithmetic by adding 30 days; DST-blind day boundaries; timestamps compared as strings; a `Date` mutated in place; expiry checked with the wrong inclusivity; token validity with no clock-skew allowance; `sleep` in tests. **Evidence**: a fixed clock at the boundary instant. **Fix**: UTC in storage and logic, a timezone only at presentation; an injected clock; calendar arithmetic through the library.

### Numbers
- **Tell**: money in floating point; integer overflow (`Number` above 2^53, 32-bit integers, unsigned wraparound); division by zero on an empty collection; `parseInt` without a radix; `NaN` flowing through arithmetic; negative modulo; rounding at the wrong step (each line versus the total). **Evidence**: the value that overflows, the empty collection, the amount that rounds differently. **Fix**: integer minor units or a decimal type for money; checked arithmetic where the range is not proven; round once, where the spec says.

### Text
- **Tell**: string length used for byte length or grapheme count; case-sensitive comparison of emails or identifiers that the system treats as case-insensitive; trimming that changes semantics; locale-dependent formatting in machine-facing output; a regular expression with nested quantifiers over untrusted input. **Evidence**: the input that differs only in case, width, or normalization. **Fix**: normalize once at the boundary; compare the normalized form; bound the regex or replace it with a parser.

### State and mutation
- **Tell**: an input mutated (`sort` in place, a shared default object or list, a spread that copies one level); a cache with no invalidation; a stale closure over a changing value; iteration order relied on where it is undefined; a singleton holding per-request data. **Evidence**: call twice, or with two callers, and observe the leak. **Fix**: copy at the boundary or treat inputs as read-only; key caches by every input they depend on; give per-request state a per-request owner.

### Resources
- **Tell**: a file, socket, connection, transaction, or lock opened without a guaranteed close on the error path; a listener or timer added and never removed; a stream consumed without backpressure. **Evidence**: the error path, walked by hand or by a fake that throws. **Fix**: `using`, `with`, `defer`, `try/finally`, or the pool's own scope helper; one owner per resource.

### Data integrity
- **Tell**: several writes with no transaction; a retry of a non-idempotent write; a uniqueness assumption in code with no unique constraint in the schema; a migration that drops or narrows a column with data; a read-after-write against a replica; a foreign key enforced only in code. **Evidence**: the partial failure, or the duplicate, that the schema allows. **Fix**: one transaction per invariant; constraints in the schema; idempotency keys; migrations that add, backfill, then remove.

### Control flow
- **Tell**: a `switch` without a `default` over a union that will grow (use an exhaustiveness check); fallthrough; an early return that skips cleanup; `a || b && c` without parentheses; a condition duplicated in two places that have drifted; exceptions as control flow for expected cases; a loop variable reused after the loop. **Evidence**: the case that takes the wrong branch. **Fix**: exhaustive matching with a compile-time check; guard clauses that release what they hold; one condition in one place.

### Contracts
- **Tell**: a function returning different shapes on different paths; an HTTP status that does not match the outcome; a pagination cursor that is not stable across inserts; a public type changed without its callers; an exported function whose documented error mode is not the real one. **Evidence**: the caller that breaks. **Fix**: one return shape; status codes from the outcome; cursors on a stable key; find every caller before changing a contract.

## Robustness

Weaknesses: the code is correct on the happy path and fragile everywhere else.

- **External calls without bounds.** No timeout on a network call, no cap or jitter on a retry, a retry of a non-idempotent request. Fix: timeout on every call, bounded exponential backoff with jitter, retries only where the operation is idempotent.
- **Unbounded work on unbounded input.** A whole file or table read into memory; `SELECT *` with no limit; a query inside a loop (N+1); an O(n²) pass over user-controlled n; recursion with no depth limit; a batch with no size cap. Fix: stream, paginate, batch, index, or bound the input at the boundary. Report only when the input is unbounded and reaches the work.
- **Silent degradation.** A fallback that hides an outage; an error logged and swallowed with a default result; a health check that always passes. Fix: fail loudly, or degrade explicitly with the degraded state visible to the caller and in the logs.
- **Configuration drift.** An environment variable read at call time; a default that differs between development and production; a flag whose absent value enables the risky path. Fix: one typed config read at startup, fail fast on missing values, safe defaults (see [STRUCTURE.md](STRUCTURE.md)).
- **Invisible failure.** An error with no identifier that would let someone find the case again; a retry path with no log line; a background job whose failure reaches no one. Fix: structured logs at boundaries with the ids that matter; a failure path that surfaces.
- **Hot spots.** A function far over the complexity budget in a file that changes weekly; that is where the next bug lands. Fix: `/deslop` pass 8 before the next feature.

## Security

Organized by the OWASP Top 10:2025. Every entry needs the attacker's input and the sink it reaches.

- **Broken access control (A01).** An object id from the request used without checking that the caller may act on that object (IDOR); authorization checked on the client only; a request body bound straight to a model so a caller can set `role` or `price` (mass assignment); an endpoint copied from another without its checks; CORS `*` with credentials. Evidence: a request as one user reaching another user's object. Fix: authorization at every entry point, for the object, through the codebase's existing check; allowlists for bound fields.
- **Security misconfiguration (A02).** Debug mode reachable in production; stack traces or internal ids in responses; default credentials; world-writable files; directory listing; missing security headers on a new surface. Fix: the secure setting as the default, the risky one as an explicit opt-in.
- **Software supply chain (A03).** An unpinned dependency; a lockfile missing or ignored; an install script pulling from an unverified source; a package name that looks like a known one; a version with a published vulnerability (`npm audit`, `pip-audit`, `cargo audit`, `govulncheck`). Fix: pin, lock, verify; the report names the advisory.
- **Cryptographic failures (A04).** MD5 or SHA-1 for passwords; `Math.random` or `random` for a token or id that must be unguessable; ECB; a hardcoded key or IV; a JWT accepted with `alg: none` or verified with the wrong key type; a secret compared with `==`; TLS verification disabled; home-made crypto. Fix: argon2id, bcrypt, or scrypt for passwords; the platform's CSPRNG; authenticated encryption from the standard library; constant-time comparison; verification on.
- **Injection (A05).** SQL built from strings (parameterize); a shell command built from strings (`shell=True`, `exec` with a string; use an argument array); a path built from user input (resolve it, then require the resolved path to stay inside the allowed root); template or expression injection; NoSQL operator injection (`{"$gt": ""}`; validate types); header injection through CRLF; log injection; a user-controlled URL fetched by the server (SSRF; allowlist hosts, block private ranges); HTML injected into the DOM or a template without encoding (XSS; `innerHTML`, `dangerouslySetInnerHTML`, unescaped template output); deserialization of untrusted data (`pickle`, `yaml.load`, `eval`, `new Function`, Java serialization); prototype pollution through a deep merge of user JSON. Evidence: the payload and the sink. Fix: the parameterized or typed API for that sink; encoding at the output boundary; a parser that produces a typed value.
- **Insecure design (A06).** A price, total, discount, role, or quantity trusted from the client; a business rule enforced only in the UI; a negative quantity or a reused coupon accepted; a balance check racing with a debit. Fix: recompute server-side from the source of truth; enforce invariants in the module that owns them; make the check-and-act atomic.
- **Authentication failures (A07).** Passwords stored reversibly or unsalted; no throttling or lockout on login and reset; session ids reused across login (fixation); tokens in URLs; reset tokens that are predictable or never expire; cookies without `HttpOnly`, `Secure`, `SameSite`; a long-lived token with no rotation or revocation. Fix: the framework's session and password primitives; rotate the session on login; short-lived tokens with revocation.
- **Software and data integrity (A08).** A webhook accepted without verifying its signature; an update or artifact applied without verification; deserialization of data the process did not produce; a cache that can be poisoned through request headers. Fix: verify signatures with the provider's library; treat every inbound payload as untrusted.
- **Logging and alerting (A09).** Secrets, tokens, passwords, full request bodies, or personal data in logs; authentication and authorization failures not logged; errors swallowed so an incident leaves no trace. Fix: redact at the logging boundary; log security events with the identifiers needed to investigate.
- **Mishandling of exceptional conditions (A10).** Fail-open: an authorization check that throws and the request proceeds; a catch-all that returns success; a partial write left behind by an exception; an unhandled rejection that crashes the process or is silently dropped. Fix: fail closed; every error path either completes the operation or leaves the state as it was.
- **Secrets.** A key, password, or token in source, in a default value, in a client bundle (`NEXT_PUBLIC_`, `VITE_`), in a URL, in an error message, or in git history. Fix: configuration at startup, from the environment or a secret store; rotate anything that was ever committed.

## Excluded unless a concrete path exists

These produce noise when raised in general. Raise one only with the specific input and the specific sink.

- Denial of service, resource exhaustion, and rate limiting in general. Raise only when an unbounded untrusted input reaches an allocation, a loop, or a regex, and name the input.
- Memory safety in memory-safe languages.
- "Missing validation" on a field that reaches no sensitive sink.
- Open redirects with no phishing or token-leak path.
- Timing attacks outside secret comparison.
- Anything a linter, typechecker, or compiler in the repo already reports.
- Pre-existing issues outside the scope. They go in the report, not in the diff.

## Evidence and fix protocol

Four separate facts per finding. Keep them separate; a strong concern that cannot be run here is still a concern.

- **Severity**: `high` when it is exploitable or wrong now (code execution, data breach, authorization bypass, data loss or corruption, wrong money); `medium` when it needs conditions but the impact is significant; `low` for defence in depth.
- **Confidence**: `certain` (the input was run and the wrong outcome observed); `likely` (verified by reading: the concrete input and its path to the sink are named, and nothing in the code prevents it); `possible` (a pattern that matches, no concrete input yet).
- **Reproduction**: `reproduced` (a loop exists and went red); `not reproducible here` (the environment cannot run it: no database, no network, no fixture); `not attempted`.
- **Action**: `fixed`, `reported`, or `dropped`.

Rules: `certain` and `likely` are reported. `possible` is dropped once a second reading fails to make it `likely`; a deep audit may keep it as one line. A fix requires `reproduced`: the loop went red before the change and green after. A `likely` finding whose loop cannot run here is reported as `not reproducible here` with the input and the command that would prove it; it is never patched blind and never silently dropped. On the 0 to 100 scale Claude Code's review plugin uses, `certain` is 100, `likely` is 75, `possible` is 50 and below.

**Fix rule**: red before green. Build the loop that shows the failure (a test at the seam where the bug is observable, a `curl`, a script with the payload), run it, watch it fail, fix, watch it pass, run the full suite, keep the test. The loop is the evidence; a fix without one is a guess. When no seam can express the failure, that is a finding about the architecture: report it with what was tried and do not patch blind.

**Where the fix goes**: the smallest change inside the scope, using the codebase's existing secure pattern first, the standard library second, a new dependency last. A fix that needs a design decision (a new constraint, a changed contract, a rotated secret) is reported with the reproduction and left to the owner.
