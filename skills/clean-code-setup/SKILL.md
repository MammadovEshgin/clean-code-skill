---
name: clean-code-setup
description: Install the clean-code gates in a repo. Complexity and dead-code lint rules, one check command, CODING_STANDARDS.md, and an optional format-on-edit hook. Run once per repo.
disable-model-invocation: true
argument-hint: [--no-hook]
---

# Clean Code Setup

Make the rules in `/clean-code` enforceable by tooling. Prose asks; a linter insists. Run once per repo, and again after adding a language.

Templates live in `${CLAUDE_SKILL_DIR}/templates/`. Arguments: `$ARGUMENTS` (`--no-hook` skips step 5).

## 1. Detect

- Stacks present: `package.json` (with or without `tsconfig.json`), `pyproject.toml` or `requirements*.txt`, `go.mod`, `Cargo.toml`. Several may apply; handle each.
- JavaScript package manager from the lockfile (`pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`, else npm).
- Existing formatter, linter, typecheck, and test configuration for each stack, and any umbrella command (`check`, `ci`, `validate`, `lint:all`, a Makefile target).
- Existing `CODING_STANDARDS.md`, `CLAUDE.md`, `AGENTS.md`.

Existing configuration is merged into, never overwritten. Show the diff of every config change.

Done when the stacks, their current tooling, and the umbrella command (or its absence) are listed.

## 2. Install the gates

| Stack | Template | Enforces | Also add |
|---|---|---|---|
| TypeScript / JavaScript | `eslint.clean-code.mjs` | complexity 10, depth 3, params 4, unused vars, empty catch, debug statements, vague TODOs | `knip` (unused files, exports, dependencies); with typescript-eslint: `no-explicit-any`, `ban-ts-comment`, `no-unnecessary-type-assertion`, and the type-aware `no-unsafe-*` rules. Type-evidence rules (widen-then-assert, chained assertions, `unknown` in signatures, module mocking): offer to vendor [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) with `npx skills add dmmulroy/anti-slop --skill install-anti-slop` when the repo uses Oxlint or is willing to |
| Python | `ruff.clean-code.toml` | mccabe 10, branches 10, args 4, statements 50, unused imports and variables, commented-out code, `print`, blind `except` | `vulture` for dead code (optional) |
| Go | `golangci.clean-code.yml` | gocyclo 10, gocognit 15, funlen 60, nestif 4, unused, unparam, errcheck, errorlint | `deadcode` from `golang.org/x/tools` (optional) |
| Rust | `rust-lints.toml` | `dead_code`, `unused_*` denied; clippy cognitive complexity, too many arguments and lines, `dbg!`, `todo!`, `unwrap` | `cargo-machete` for unused dependencies (optional) |

- Merge the template's rules into the existing config for that stack. Flat ESLint config: import the template and spread it; legacy `.eslintrc`: translate the rules. Ruff: under `[tool.ruff]` in `pyproject.toml`. golangci-lint: the v2 schema; translate if the repo is on v1. Rust: `[lints]` in `Cargo.toml` (or `[workspace.lints]` plus `lints.workspace = true` in members) and thresholds in `clippy.toml`.
- Thresholds match the complexity budget in `/clean-code`. When the current code exceeds a threshold in many places, run `${CLAUDE_SKILL_DIR}/../clean-code/scripts/complexity.sh` to find the current maximum, set the initial ceiling just above it so nothing is grandfathered or suppressed, record it as a **ratchet** in `CODING_STANDARDS.md` with the hotspots listed, and lower it as `/deslop` pass 9 lands. A regression ceiling today beats a target nobody passes.
- Install a formatter where none exists (Prettier or Biome, Ruff, gofmt, rustfmt).

Done when each stack's lint runs and reports either zero findings or a listed set of pre-existing ones.

## 3. One check command

Create or extend the umbrella command so one invocation runs: format check, lint, typecheck, tests. Use the repo's existing convention (npm script, Makefile, `justfile`, `nox`, `cargo` alias). Name it `check` unless a convention already exists.

Done when the command exists and its exit code reflects all four.

## 4. Standards file

- If `CODING_STANDARDS.md` is missing, copy `templates/CODING_STANDARDS.md` to the repo root and fill in the stack, the formatter, the check command, and the ratchets. Keep it short; every line is loaded into every review.
- Add a pointer to it from `CLAUDE.md` or `AGENTS.md` (create `AGENTS.md` when neither exists) using `templates/CLAUDE.md.snippet`. Do not copy rules into `CLAUDE.md`; the standards file is the single source.

Done when the file exists and one instruction file links to it.

## 5. Format-on-edit hook (Claude Code, optional)

Skip when `--no-hook` was passed. Otherwise offer the hook and install it only after the user agrees, since hooks run commands automatically:

- Copy `templates/format-on-edit.sh` to `.claude/hooks/format-on-edit.sh` and merge `templates/hooks.settings.json` into `.claude/settings.json` (project scope, committed). Existing hooks are preserved.
- The script formats the file that was just edited and always exits 0, so a missing formatter never blocks an edit.

## 6. Prove the gates bite

The completion criterion for the whole setup. For each stack:

1. Run the check command. It passes, or its failures are the pre-existing ones listed in step 2.
2. Add a scratch file inside the source tree containing an unused import and a function with nesting five deep.
3. Run the check command. It fails and names the rule.
4. Delete the scratch file. Run the check command. It passes.

Observed pass, fail with the rule named, pass again. Anything else means the gate is not wired; fix it before finishing.

## Report

```
## Setup Report
Stacks    <ts, python, go, rust>
Gates     complexity <n> · depth <n> · params <n> · dead code via <knip | ruff | deadcode | rustc>
Check     <command>
Standards CODING_STANDARDS.md <created | existing> · pointer in <CLAUDE.md | AGENTS.md>
Hook      <installed | skipped | declined>
Proof     pass → fail (<rule>) → pass, per stack
Ratchet   <threshold raised to current max, or none>
```
