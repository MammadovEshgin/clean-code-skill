# Changelog

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
