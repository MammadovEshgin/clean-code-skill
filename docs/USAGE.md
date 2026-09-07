# Usage

Worked examples for each skill, recipes for common situations, and troubleshooting. Commands are shown as typed into Claude Code; Codex and Cursor users type the same skill names (or, for the Claude Code plugin install, the namespaced form such as `/clean-code:deslop`).

## Contents

- First hour in a new project
- First day in an existing project
- Daily flow
- Reading the reports
- Recipes
- Windows notes
- Troubleshooting

## First hour in a new project

1. Install the skills (see the README). Confirm with `/skills` in Claude Code: `clean-code`, `deslop`, `interrogate`, `clean-code-review`, `clean-code-setup` are listed.
2. Run `/clean-code-setup`. It detects the stack, merges the complexity and dead-code rules into the linter, adds a `check` command, creates `CODING_STANDARDS.md`, points `CLAUDE.md` or `AGENTS.md` at it, offers the format-on-edit hook, and proves each gate fails on a violation before passing again. Expect a report like:

   ```
   ## Setup Report
   Stacks    ts
   Gates     complexity 10 · depth 3 · params 4 · dead code via knip
   Check     npm run check
   Standards CODING_STANDARDS.md created · pointer in CLAUDE.md
   Hook      installed
   Proof     pass → fail (complexity, no-unused-vars) → pass
   Ratchet   none
   ```

3. Build the first feature the way you normally would. The `clean-code` skill fires on its own. Say what you want, name the seam if you have an opinion, and name the check:

   ```
   Add an orders module: create an order from a cart, reject empty carts,
   expose it through POST /orders. Tests at the HTTP seam. Run npm run check when done.
   ```

4. Read the Clean Code Report at the end. If `Left` names something you care about, make it the next task.

## First day in an existing project

The order matters: gates first, then cleanup in slices, then review.

### 1. Gates

```
/clean-code-setup
```

On a codebase that already exceeds the thresholds in many places, setup raises the threshold to the current maximum and records it as a ratchet in `CODING_STANDARDS.md`. The check passes today; the threshold comes down as cleanup lands.

### 2. Cleanup in slices

Start with a module you understand, so you can judge the result:

```
/deslop src/orders
```

What happens:

- The existing tests for the scope run; the baseline is recorded (for example `41/41`).
- Where coverage is thin over code about to be touched, characterization tests are added at the public interface first.
- The inventory tools run (`knip`, `ruff`, `vulture`, `deadcode`, `clippy`, `aislop`, whichever exist) and their counts are recorded.
- `complexity.sh` records the baseline: function count, maximum, functions over budget, erosion, hotspots.
- Nine passes in order: dead code, comments, abstractions, defensive paranoia, duplication, naming, tests, filler, complexity hotspots. Typecheck and focused tests after each; a failing pass is reverted.
- The report:

  ```
  ## Deslop Report
  Scope       src/orders · 14 files inspected · 9 files changed
  Diff        +38 / -412 lines · net -374
  Passes      dead code 131 · comments 96 · abstractions 3 · defensive 22 · duplication 2 · naming 4 · tests 6 · filler 11 · hotspots 1
  Gates       typecheck pass · lint pass · tests 41/41 → 38/38
  Complexity  max 23 → 9 · over budget 1 → 0 · erosion 18% → 0%
  Tools       knip: 7 unused exports → 0
  Verdict     behaviour preserved

  Found, not changed
  - src/orders/lib/pricing.ts:88 rounds before summing; likely a bug, needs a decision.
  - src/legacy/export.ts (out of scope): 40 lines of commented-out code.

  Suggested follow-ups
  1. /deslop src/legacy
  2. Decide on the pricing rounding, then add a regression test.
  ```

  Three tests were deleted in pass 7; the report says which behaviour the remaining tests cover. Pass 9 split the one function over the complexity budget along its responsibilities, with the tests unchanged.

Then widen:

```
/deslop src
/deslop repo
```

For `repo`, the skill lists every source directory at the start and confirms each was inspected before finishing.

Want a reviewable history? Say so in the same message: `/deslop src/orders and commit after each pass`.

### 3. Review before merging

```
/clean-code-review main
```

Paste the findings back into the working session (`apply the review findings`) and re-run the review until the verdict is `merge`.

## Daily flow

```
<describe the change>                   clean-code fires automatically, ends with a report
/interrogate                            challenge the diff: delete, simplify, stop
/clean-code-review main [spec-file]     fresh-context review; apply findings; repeat
git commit / open the PR
```

When the agent does something you dislike, add one dated line to `CODING_STANDARDS.md`. It is read on every run and overrides the skill. Delete the line once a linter enforces it.

## Reading the reports

Every skill ends with a block of ten lines or fewer. The fields:

| Field | Meaning |
|---|---|
| `Scope` | What was asked, and how many files were inspected or changed. |
| `Diff` | Added and removed lines from `git diff`, lock files excluded, and the net. Negative net on a cleanup is the point. |
| `Removed` / `Passes` | Counts per category. Comments and dead code are counted by pattern in the diff; abstractions and tests are counted by the agent. |
| `Gates` | Each check that actually ran, with its result. `n/a` means it did not run, which is a fact, not a pass. |
| `Complexity` | Highest per-function cyclomatic complexity, how many functions exceed the budget, and erosion (the share of complexity inside those functions). `/deslop` shows before → after. `n/a` when no ESLint, Ruff, or gocyclo is available. |
| `Tools` | Inventory tools before and after (unused exports, dead functions, slop score). |
| `Left` / `Found, not changed` | What was noticed and deliberately not touched. This is where scope discipline shows. |
| `Verdict` | `ready`, `behaviour preserved`, `needs decision: ...`, or the review's `merge` / `fix then merge` / `rethink`. |

To recompute the numbers yourself:

```bash
bash ~/.claude/skills/clean-code/scripts/diff-stats.sh          # working tree vs HEAD
bash ~/.claude/skills/clean-code/scripts/diff-stats.sh main     # since the merge-base with main
bash ~/.claude/skills/clean-code/scripts/complexity.sh src      # per-function complexity, hotspots, erosion
```

`complexity.sh` uses the linter the repo already has (ESLint through the repo's config, Ruff, gocyclo) and prints `n/a` when none applies. Erosion is the share of complexity that sits in functions over the budget; a rising number between two runs means the code is getting harder to change even if every test passes.

## Recipes

### Pull-request gate

Add a CI job that fails on slop and on complexity, independent of the agent:

```yaml
- run: npm run check                      # the umbrella command from /clean-code-setup
- run: npx aislop@latest ci --changes --base origin/main   # optional: deterministic slop score on changed files
```

### Legacy repository in a day

1. `/clean-code-setup` with ratchets.
2. `/deslop <hot directory>` for the two or three directories with the most recent commits (`git log --oneline -- <dir> | wc -l`). Cleanup pays off where change happens.
3. `/clean-code-review main` on the result; apply findings.
4. Lower one ratchet in `CODING_STANDARDS.md` and the lint config; repeat tomorrow.

### Refactoring checkpoints

Quality prompts improve the first version and then lose ground with every iteration; agents accumulate erosion several times faster than people do. Counter it with a schedule rather than more prompting:

- Before every PR: `/interrogate`, then `/clean-code-review main`.
- Every few features on the same module: `/deslop <module>`, and compare the `Complexity` line with the last run.
- When `complexity.sh` shows a hotspot over the budget: let `/deslop` pass 9 split it before the next feature lands on top of it.

### Measuring the skill itself

```bash
evals/run.sh              # runs /deslop on the fixtures in a fresh session and checks the result
evals/run.sh --keep       # keep the workspaces to read agent-output.txt
```

Add a fixture from your own codebase (`evals/fixtures/<name>/` with an `entry`, a `check.sh`, and a behaviour test) to measure against the slop you actually see.

### Writer and reviewer in two sessions

Session A implements. Session B runs `/clean-code-review main docs/spec.md` and posts the findings. Session A applies them. Fresh context on the review side catches what the author's context hides.

### A module the agent keeps getting wrong

Write the interface first, then hand over the inside:

```
Design the interface for a `notifications` module: send(templateId, recipient, data),
returning a delivery id. Two adapters: SES in production, in-memory in tests.
Show me the interface and the test file before implementing.
```

Approve the interface; the implementation behind it can be regenerated as often as needed while the tests hold.

### Auditing the skill itself

Models improve; instructions rot. Once per model release:

```
/interrogate skills/
```

in a checkout of this repo, then `scripts/check.sh`. Delete whatever the new model does correctly without being told.

## Windows notes

- `scripts/install.ps1 -Global` installs; the skills' own scripts (`diff-stats.sh`, `complexity.sh`, `format-on-edit.sh`) run under Git Bash, which comes with Git for Windows. Claude Code's Bash tool uses it automatically.
- Hook commands in `hooks.settings.json` call `bash` explicitly for this reason.
- Paths inside the skills use forward slashes; that is deliberate and works on Windows.

## Troubleshooting

**The clean-code skill does not fire.** Check `/skills` lists it. If it is installed as a plugin, the description is still loaded; if it is a project skill, make sure `.claude/skills/clean-code/SKILL.md` exists in the repo root, not a subdirectory. Mention "clean code" or "simplify" in the prompt to force it, or invoke it directly with `/clean-code`.

**Plugin commands have a prefix.** Plugin installs namespace skills: `/clean-code:deslop`, `/clean-code:interrogate`, `/clean-code:clean-code-review`, `/clean-code:clean-code-setup`. skills.sh and script installs use the bare names.

**`/clean-code-review` reports nothing.** Confirm the base ref: with a clean tree and no argument it diffs against the merge-base with `main` or `master`; on another default branch, pass it explicitly.

**`/deslop` refuses to clean a file.** It found no test signal for that code and would not change it blind. Either accept the characterization tests it proposes, or give it a scope that has tests.

**Reports show `n/a` for a gate.** The command did not run, usually because the repo has no such tool. Run `/clean-code-setup`.

**Too many findings in review.** The review filters to correctness, maintainability, and documented standards. If it still reports style preferences, write the preference into `CODING_STANDARDS.md` one way or the other; documented standards win, documented exceptions suppress the flag.
