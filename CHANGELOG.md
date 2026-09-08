# Changelog

## 2.0.0 (2026-09-08)

The senior-level release: the skills no longer stop at removing slop. They rewrite code into the shape a senior engineer would have written, hunt bugs and security flaws with evidence, make tests able to fail, fix folder structure, and run automatically through hooks.

- `/audit` (new): find and fix bugs, weaknesses, and security flaws in a path, a range, or the diff. Every finding is a sentence ("given X, Y happens; expected Z") with a confidence score; only findings at 80 and above are raised; every fix ships with a test that failed first; unproven findings are reported with what would prove them. Catalog in `skills/clean-code/BUGS.md`: correctness, robustness, the OWASP Top 10:2025 mapped to tells and fixes, exclusions, the confidence rubric.
- `/test-audit` (new): classify every test as keep, rewrite, merge, or delete, with the tell; rewrite implementation-coupled tests at the seam; add the seam tests callers depend on; prove the suite bites with mutation probes (StrykerJS, mutmut, cargo-mutants, gremlins, or three hand probes per module); report `probes killed k/m`.
- `/deslop`: eleven passes. New pass 9 "Design" reshapes what is the wrong shape (merge shallow modules, move leaked knowledge behind one interface, define special cases away, parse once at the boundary, make illegal states unrepresentable, inject constructed dependencies, collapse pass-throughs, rewrite beyond-repair functions from their tests); pass 10 runs `/test-audit`; pass 11 prunes docs and instruction files of implementation details, session observations, and stale references. Then an audit step, behaviour-changing on purpose and separate. Flags `--refactor-only` and `--no-structure`.
- `/deslop repo`: two fresh-context workers per slice, a cleanup commit (`refactor(deslop)`) and a fix commit (`fix(audit)`) so a reviewer reads "same behaviour" and "new behaviour, proven" separately; a fix whose test does not go red on the pre-fix code is reverted; a structure phase at the end fixes layout problems with tool-verified moves and publishes the moved-path map; docs and instruction files form their own slice.
- `/finish`: now interrogate, deslop, test audit of the change's tests, audit of the change, gate, four-axis review, apply, gate, second review, land. Correctness findings are reproduced before they are fixed; weakened checks are restored. Report gains `Tests`, `Audit`, and `Unverified` lines.
- `/clean-code-review`: four axes (slop, design, correctness, scope); reads test diffs first and the code around each hunk; every finding is re-checked against the code before it is reported, correctness findings carry severity and confidence, and Claude Code's own false-positive list filters the rest.
- `clean-code`: a third governing idea (evidence over confidence), an eighth hard gate (safe by default), "one thing per line", "three similar lines beat a premature abstraction", the rewrite-when-clearly-better rule, a "design for the day it goes wrong" section, an "instruction files" section (write only what the code cannot say; rules that must hold go into hooks, lint, or tests; offer a `CODING_STANDARDS.md` line after every correction), `Unverified` in the report.
- `/clean-code-setup`: three hooks installed by default (`format-and-lint.sh` on every edit, `check-on-stop.sh` before the agent stops, `commit-gate.sh` before any `git commit`), `--no-hooks` to skip; security lint rules (Ruff `S`, `gosec`, `eslint-plugin-security`), a fast check subset, a mutation-tool offer, and a proof step that also blocks a fake commit.
- Reference files: `BUGS.md` (new); `TESTS.md` gains state-not-interactions, self-contained tests, the artifact-asserts-itself tautology, weakened checks, mutation probes; `STRUCTURE.md` gains "Structure problems and safe moves"; `RED-FLAGS.md` gains copy-of-existing-helper, copy-pasted block, multitasking line, weakened check, and instruction-file sediment.
- `evals/`: `ts-audit` (a SQL injection and an off-by-one, fixed with red-first tests, nothing committed) and `ts-test-audit` (four trash tests deleted, a seam covered, three mutants killed). `scripts/check.sh` also parses every shell script and JSON file and checks that `plugin.json` lists every skill.
- Docs: README, USAGE, SOURCES (fourth pass: Addy Osmani, Andrej Karpathy, Matt Pocock's 2026 posts, Vinh Nguyen, Anthropic's security reviewer and code-review plugin, OWASP 2025, mutation tools), COMPARISON.

## 1.2.0 (2026-09-07)

- `/finish`: one command before a commit. Interrogate, deslop, gates, fresh-context review, findings applied, a second review when anything changed. Leaves the tree ready, or commits with `--commit`. Finish Report with a suggested commit message.
- `/deslop repo`: whole-codebase cleanup as an automated loop. Inventory and measurement, slices ordered by risk and value, the plan in `.deslop/plan.md`, one fresh-context worker per slice, the check command as the gate, one commit per slice on a `deslop/<date>` branch, revert on red, resumable. `--plan` writes the plan only. Design notes in `skills/deslop/REPO.md`.
- `/clean-code-review`: with a base ref and uncommitted changes, reviews the working tree against the merge-base.
- `clean-code`, `CLAUDE.md.snippet`, installers, README, USAGE: point at `/finish` and `/deslop repo`.
- `evals/`: fixtures can name their own `command` and a two-commit `base`; new `ts-finish` (`/finish HEAD~1`) and `ts-repo` (`/deslop repo` over two modules, one commit per slice) fixtures; the runner allows the Agent tool.

## 1.1.0 (2026-09-07)

- `scripts/complexity.sh`: per-function cyclomatic complexity through ESLint, Ruff, or gocyclo; hotspots; erosion (CC-weighted share in functions over the budget, after SlopCodeBench).
- `clean-code`: Types rules reframed as evidence (parse once at the boundary, never launder a type, `SAFETY:` comments on necessary assertions); module mocking named as a missing seam; `Complexity` line in the report.
- `RED-FLAGS.md`: widen-then-assert, chained assertions, evidence discarded in signatures, runtime narrowing inside, reflection, module mocking.
- `/deslop`: complexity baseline in step 1; pass 9 splits hotspots along responsibilities; `Complexity` before/after in the report.
- `/clean-code-setup`: ceiling-at-current-maximum ratchet with hotspots recorded; typescript-eslint type-aware rules; offer to vendor dmmulroy/anti-slop for TypeScript type evidence.
- `evals/`: fixtures with planted slop (TypeScript, Python) and a runner that checks a real `/deslop` run mechanically.
- `docs/COMPARISON.md`: layer-by-layer comparison with the alternatives, including where this repo is weaker.

## 1.0.0 (2026-09-07)

Initial release.

- `clean-code`: model-invoked discipline for writing and changing code (loop, hard gates, writing rules, complexity budget, done gate, report) with reference files for red flags, comments, structure, errors, and tests.
- `deslop`: behaviour-preserving cleanup of existing code in ordered passes, with tool-backed inventory and a report.
- `interrogate`: first-principles challenge of a finished change (delete, simplify, stop).
- `clean-code-review`: fresh-context review on three axes (slop, design, scope).
- `clean-code-setup`: lint gates for TypeScript/JavaScript, Python, Go, Rust; one check command; `CODING_STANDARDS.md`; optional format-on-edit hook; proof that the gates bite.
- `scripts/diff-stats.sh`: deterministic numbers for every report.
- Installable as a Claude Code plugin, via skills.sh, or by script.
