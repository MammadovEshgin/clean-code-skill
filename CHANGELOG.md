# Changelog

## 1.0.0 (2026-09-07)

Initial release.

- `clean-code`: model-invoked discipline for writing and changing code (loop, hard gates, writing rules, complexity budget, done gate, report) with reference files for red flags, comments, structure, errors, and tests.
- `deslop`: behaviour-preserving cleanup of existing code in ordered passes, with tool-backed inventory and a report.
- `interrogate`: first-principles challenge of a finished change (delete, simplify, stop).
- `clean-code-review`: fresh-context review on three axes (slop, design, scope).
- `clean-code-setup`: lint gates for TypeScript/JavaScript, Python, Go, Rust; one check command; `CODING_STANDARDS.md`; optional format-on-edit hook; proof that the gates bite.
- `scripts/diff-stats.sh`: deterministic numbers for every report.
- Installable as a Claude Code plugin, via skills.sh, or by script.
