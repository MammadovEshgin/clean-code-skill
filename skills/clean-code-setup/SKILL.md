---
name: clean-code-setup
description: Install the clean-code gates in a repo. Complexity, dead-code, and security lint rules, one check command, CODING_STANDARDS.md, and three hooks that lint on edit, gate the agent's stop, and block red commits. Run once per repo.
disable-model-invocation: true
argument-hint: [--no-hooks]
---

# Clean Code Setup

Make the rules in `/clean-code` enforceable by tooling. Prose asks; a linter insists; a hook makes it automatic. Run once per repo, and again after adding a language.

Templates live in `${CLAUDE_SKILL_DIR}/templates/`. Arguments: `$ARGUMENTS` (`--no-hooks` skips step 5).

## 1. Detect

- Stacks present: `package.json` (with or without `tsconfig.json`), `pyproject.toml` or `requirements*.txt`, `go.mod`, `Cargo.toml`. Several may apply; handle each.
- JavaScript package manager from the lockfile (`pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`, else npm).
- Existing formatter, linter, typecheck, and test configuration for each stack, and any umbrella command (`check`, `ci`, `validate`, `lint:all`, a Makefile target).
- Existing `CODING_STANDARDS.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `.claude/hooks/`.

Existing configuration is merged into, never overwritten. Show the diff of every config change.

Done when the stacks, their current tooling, and the umbrella command (or its absence) are listed.

## 2. Install the gates

| Stack | Template | Enforces | Also add |
|---|---|---|---|
| TypeScript / JavaScript | `eslint.clean-code.mjs` | complexity 10, depth 3, params 4, unused vars, empty catch, debug statements, vague TODOs | `knip` (unused files, exports, dependencies); with typescript-eslint: `no-explicit-any`, `ban-ts-comment`, `no-unnecessary-type-assertion`, and the type-aware `no-unsafe-*` rules; `strict: true` in `tsconfig.json` when it is not already set. Security: `eslint-plugin-security` when the project serves untrusted input. Type-evidence rules (widen-then-assert, chained assertions, `unknown` in signatures, module mocking): offer to vendor [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) with `npx skills add dmmulroy/anti-slop --skill install-anti-slop` when the repo uses Oxlint or is willing to |
| Python | `ruff.clean-code.toml` | mccabe 10, branches 10, args 4, statements 50, unused imports and variables, commented-out code, `print`, blind `except`, security (`S`: `shell=True`, `eval`, weak hashes, hardcoded secrets, unsafe `yaml.load`) | `vulture` for dead code (optional); `mypy --strict` or `pyright` when the project is typed |
| Go | `golangci.clean-code.yml` | gocyclo 10, gocognit 15, funlen 60, nestif 4, unused, unparam, errcheck, errorlint, gosec | `deadcode` from `golang.org/x/tools` (optional); `govulncheck ./...` in the check command |
| Rust | `rust-lints.toml` | `dead_code`, `unused_*` denied; clippy cognitive complexity, too many arguments and lines, `dbg!`, `todo!`, `unwrap` | `cargo-machete` for unused dependencies (optional); `cargo audit` in the check command when a lockfile exists |

- Merge the template's rules into the existing config for that stack. Flat ESLint config: import the template and spread it; legacy `.eslintrc`: translate the rules. Ruff: under `[tool.ruff]` in `pyproject.toml`. golangci-lint: the v2 schema; translate if the repo is on v1. Rust: `[lints]` in `Cargo.toml` (or `[workspace.lints]` plus `lints.workspace = true` in members) and thresholds in `clippy.toml`.
- Thresholds match the complexity budget in `/clean-code`. When the current code exceeds a threshold in many places, run `${CLAUDE_SKILL_DIR}/../clean-code/scripts/complexity.sh` to find the current maximum, set the initial ceiling just above it so nothing is grandfathered or suppressed, record it as a **ratchet** in `CODING_STANDARDS.md` with the hotspots listed, and lower it as `/deslop` pass 8 lands. A regression ceiling today beats a target nobody passes.
- Install a formatter where none exists (Prettier or Biome, Ruff, gofmt, rustfmt).
- Security rules that fire on existing code are listed as pre-existing findings for `/audit`, never suppressed.

Done when each stack's lint runs and reports either zero findings or a listed set of pre-existing ones.

## 3. One check command

Create or extend the umbrella command so one invocation runs: format check, lint, typecheck, tests, and the dependency audit where the stack has one. Use the repo's existing convention (npm script, Makefile, `justfile`, `nox`, `cargo` alias). Name it `check` unless a convention already exists. Also define the **fast** subset, lint plus typecheck, as `check:fast` (or the convention's equivalent) for the stop hook.

Done when the command exists and its exit code reflects every part.

## 4. Standards file

- If `CODING_STANDARDS.md` is missing, copy `templates/CODING_STANDARDS.md` to the repo root and fill in the stack, the formatter, the check command, and the ratchets. Keep it short; every line is loaded into every review.
- Add a pointer to it from `CLAUDE.md` or `AGENTS.md` (create `AGENTS.md` when neither exists) using `templates/CLAUDE.md.snippet`. Do not copy rules into `CLAUDE.md`; the standards file is the single source.

Done when the file exists and one instruction file links to it.

## 5. Hooks (Claude Code)

Skip when `--no-hooks` was passed. Otherwise install the three hooks; they are what makes the discipline automatic rather than remembered. Say what each one does in one line each before installing, then install.

| Hook | Event | Does |
|---|---|---|
| `format-and-lint.sh` | PostToolUse on Edit and Write | formats the edited file and lints it; findings come straight back to the agent, so slop is fixed the moment it is written |
| `check-on-stop.sh` | Stop | when the session edited files, runs the fast gates before the agent stops; red keeps the agent working |
| `commit-gate.sh` | PreToolUse on Bash | runs the check command before any `git commit` the agent runs; red blocks the commit |

- Copy the three scripts from `templates/` to `.claude/hooks/`. Fill `__FAST_CHECK__` in `check-on-stop.sh` and `__CHECK_COMMAND__` in `commit-gate.sh` with the commands from step 3; the scripts detect the stack on their own when a placeholder is left in place.
- Merge `templates/hooks.settings.json` into `.claude/settings.json` (project scope, committed). Existing hooks are preserved.
- Every script exits 0 when its tool is missing, so a hook never blocks work in a stack it does not know.

Done when the three scripts exist and `.claude/settings.json` references them.

## 6. Mutation testing (offer)

`/test-audit` proves a suite bites with mutation probes. A tool does it faster and wider than hand probes: StrykerJS for TypeScript and JavaScript, `mutmut` or `pytest-gremlins` for Python, `cargo-mutants` for Rust, `gremlins` for Go. Name the install command for the repo's stack and add it only when the user says yes; the audit works without it.

## 7. Prove the gates bite

The completion criterion for the whole setup. For each stack:

1. Run the check command. It passes, or its failures are the pre-existing ones listed in step 2.
2. Add a scratch file inside the source tree containing an unused import, a function with nesting five deep, and a string concatenated into a shell or SQL call.
3. Run the check command. It fails and names the rules.
4. With the hooks installed, feed the commit gate a fake payload: `printf '{"tool_input":{"command":"git commit -m x"}}' | bash .claude/hooks/commit-gate.sh`. It exits 2 and prints the failure.
5. Delete the scratch file. Run the check command. It passes. The commit gate exits 0.

Observed pass, fail with the rules named, blocked commit, pass again. Anything else means a gate is not wired; fix it before finishing.

## Report

```
## Setup Report
Stacks    <ts, python, go, rust>
Gates     complexity <n> · depth <n> · params <n> · dead code via <knip | ruff | deadcode | rustc> · security via <eslint-plugin-security | ruff S | gosec | clippy>
Check     <command> · fast: <command>
Standards CODING_STANDARDS.md <created | existing> · pointer in <CLAUDE.md | AGENTS.md>
Hooks     <format-and-lint, check-on-stop, commit-gate | skipped>
Mutation  <tool installed | offered: <command> | none>
Proof     pass → fail (<rules>) → commit blocked → pass, per stack
Ratchet   <threshold raised to current max, or none>
```
