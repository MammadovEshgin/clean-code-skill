# Changelog

## 2.1.0 (2026-09-08)

A reliability and cost release, driven by an outside review of 2.0.0 (findings verified against the files before anything changed).

- Hooks: `commit-gate.sh` now catches every spelling of `git commit` (leading whitespace, `--no-pager`, `-c` and `--git-dir` values, chained and multi-line commands, `sh -c '...'`) and runs the check inside `git -C <dir>`; `check-on-stop.sh` blocks a red stop at most three times per session and then lets the agent stop with a message, instead of exiting silently on `stop_hook_active`. `scripts/test-hooks.sh` (33 cases) runs from `scripts/check.sh`. Hooks are documented as development feedback; CI is the merge gate.
- Rules: absolute bans replaced by the contract they protect. A one-caller helper that names a calculation may stay; a test fake or a named vendor boundary counts as a second adapter; an interaction is asserted when it is the contract at an external boundary; a trivial value that is a contract keeps one test; retries only where idempotent; removing a shim on a published surface is a decision with outside consumers in view.
- `/audit` and `/clean-code-review`: severity, confidence (`certain`, `likely`, `possible`), reproduction (`reproduced`, `not reproducible here`, `not attempted`), and action are four separate facts. `likely` findings are reported even when their loop cannot run here; a fix still requires a loop that went red.
- `/deslop repo`: `skills/deslop/scripts/slice.sh` (`snapshot`, `confine`, `red-check`) owns the stateful steps: changes that existed before a worker started are never reverted, `.deslop/` is never reverted, and a fix is proven by restoring the pre-fix production files while the new tests stay in place. Resume is detected before the clean-tree check. `scripts/test-slice.sh` (14 cases).
- Installers: an edited skill directory is moved to `<name>.bak-<timestamp>` instead of deleted; `--replace` / `-Replace` overwrites. `scripts/check.sh` picks a JSON parser proven to work (node first) so a Windows Store `python` alias no longer produces false "invalid JSON" failures.
- Evals: `evals/run.sh` records input and output tokens, cost, turns, elapsed time, and the Claude Code version per run in `evals/results/log.tsv`; `--baseline` runs the same fixture with no skills and a plain-English prompt; `--runs N` repeats. `ts-audit` proves red-first mechanically (the suite must fail on the pre-fix production file); new `ts-clean` fixture where good code must stay byte-identical.
- Token cost: the core skill went from 4,736 to 2,854 estimated tokens (characters divided by four, a 40% cut) by making the eight gates the only checklist and moving examples to the references; the other skills grew slightly with the rule nuance, the change record, and the section maps, so the total across all skills and references is flat (33,964 to 33,767) and the saving comes from loading less per run, not from smaller files; `/finish` writes one change record and hands it to every step and to the reviewer, reuses check results until a covered file changes, and runs at `fast`, `standard`, or `deep` chosen from the change's size and risk markers (auth, persistence, concurrency, external side effects, public contracts, migrations, many files); the catalogs open with a section map so passes and reviews load only the sections they need; the test audit lists only non-keep verdicts; repo-mode worker briefs carry the discovery.
- Docs: positioning as a configurable toolkit for improving and verifying agent-written code; a status table of implemented, tested, and intended behaviour; `CONTRIBUTING.md`; `SECURITY.md`; a token budget table; claims narrowed to what the evidence shows.

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
