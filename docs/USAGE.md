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

1. Install the skills (see the README). Confirm with `/skills` in Claude Code: `clean-code`, `finish`, `deslop`, `interrogate`, `clean-code-review`, `clean-code-setup` are listed.
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
5. Before the first commit:

   ```
   /finish
   ```

   It interrogates the diff, deslops it, runs the check, reviews it in a fresh context, applies the findings, and ends with a Finish Report whose last line is a suggested commit message. `/finish --commit` commits when the verdict is `ready`.

## First day in an existing project

The order matters: gates first, then the whole-repo cleanup, then review of the branch it produced.

### 1. Gates

```
/clean-code-setup
```

On a codebase that already exceeds the thresholds in many places, setup raises the threshold to the current maximum and records it as a ratchet in `CODING_STANDARDS.md`. The check passes today; the threshold comes down as cleanup lands.

### 2. Cleanup: the whole repo, one command

```
/deslop repo
```

What happens:

- Preflight: the tree must be clean; on `main` a `deslop/<date>` branch is created; the check command runs and its result is the baseline.
- Plan: the source is inventoried (generated code, vendored code, migrations, snapshots, dot-directories excluded), complexity and churn are measured, files are grouped into slices (a module with its tests), and the slices are ordered: with tests before without, leaves before shared code, hot spots first within a tier. The plan is written to `.deslop/plan.md` and shown to you. The run starts without waiting.

  ```
  # Deslop plan
  Branch deslop/2026-09-07 from main @ 3f2a1c9 · check: npm run check · baseline 214/214 · complexity max 31 · erosion 22%
  Excluded: dist/, src/generated/, prisma/migrations/

  | # | Slice | Files | Lines | CC max | Churn | Status |
  |---|---|---|---|---|---|---|
  | 1 | src/orders | 14 | 1,180 | 23 | 41 | pending |
  | 2 | src/billing | 9 | 760 | 12 | 28 | pending |
  | 3 | src/lib | 11 | 940 | 31 | 63 | pending |
  ```

- Per slice: a fresh-context worker runs the nine passes on that slice alone and returns its Deslop Report. The main session reverts anything outside the slice, runs the check command, and commits the slice as `refactor(deslop): src/orders` with the report as the commit body. A red check reverts the slice, marks it in the plan, and moves on. Three reverts in a row stop the run: that is a suite or lint problem, not a slice problem.
- Finish: the check and `complexity.sh` run once more, the plan goes into the final commit message and `.deslop/` is deleted, and the report sums the slices:

  ```
  ## Deslop Report (repo)
  Branch      deslop/2026-09-07 · 12 slices · 11 committed · 1 reverted · 0 untestable
  Diff        +412 / -3,908 lines · net -3,496   (main..HEAD)
  Passes      dead code 640 · comments 1,102 · abstractions 19 · defensive 87 · duplication 11 · naming 23 · tests 31 · filler 58 · hotspots 9
  Gates       check pass · tests 214/214 → 203/203
  Complexity  max 31 → 12 · over budget 9 → 2 · erosion 22% → 4%
  Verdict     behaviour preserved · reverted: src/legacy (characterization tests could not pin the export format)
  ```

Stop the run whenever you want; the next `/deslop repo` resumes at the first `pending` row. Edit `.deslop/plan.md` to reorder or drop slices. `/deslop repo --plan` writes the plan and stops, for a look before committing to a long run. Every slice is one commit, so `git revert <sha>` undoes exactly one module.

Want to judge the result on one module before the whole repo? Run it on that module first:

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

Want a reviewable history on a single-module run? Say so in the same message: `/deslop src/orders and commit after each pass`.

### 3. Review the branch before merging

```
/clean-code-review main
```

On the `deslop/<date>` branch, the review reads the whole cleanup as one diff. Apply its findings in the working session, re-run until the verdict is `merge`, then merge the branch. Then lower one ratchet in `CODING_STANDARDS.md` and the lint config.

## Daily flow

```
<describe the change>       clean-code fires automatically, ends with a report
/finish                     interrogate, deslop, gates, fresh-context review, findings applied
git commit                  or: /finish --commit
```

`/finish` ends with a Finish Report:

```
## Finish Report
Purpose     Retry webhook delivery with exponential backoff
Scope       working tree · 3 files
Interrogate deleted 2 · simplified 1
Deslop      dead code 4 · comments 11 · abstractions 1 · defensive 2 · duplication 0 · naming 1 · tests 1 · filler 0 · hotspots 0
Review      round 1: 3 findings (slop 2 · design 1 · scope 0) · round 2: 0 · verdict merge
Diff        +41 / -87 lines · net -46   (was +88 / -87 before finishing)
Gates       check pass · typecheck pass · lint pass · tests 58/58
Complexity  max 7 · over budget 0 · erosion 0%
Verdict     ready to commit
Commit      feat(webhooks): retry delivery with exponential backoff
```

`needs decision` means the reviewer said `rethink`, or a finding needs a call only you can make; the block lists it. The pieces on their own, when you want just one: `/interrogate`, `/deslop`, `/clean-code-review main [spec-file]`.

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
| `Interrogate` / `Review` | `/finish` only: what the interrogation cut, and the fresh-context reviewer's findings per round with its verdict. |
| `Branch` | `/deslop repo` only: the branch, and how many slices were committed, reverted, or found untestable. |
| `Left` / `Found, not changed` | What was noticed and deliberately not touched. This is where scope discipline shows. |
| `Verdict` | `ready to commit`, `behaviour preserved`, `needs decision: ...`, or the review's `merge` / `fix then merge` / `rethink`. |
| `Commit` | `/finish` only: a suggested one-line commit message. |

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
2. `/deslop repo`. It orders the slices by churn and erosion on its own, so the hot directories land first; stop it at the end of the day and resume tomorrow.
3. `/clean-code-review main` on the `deslop/<date>` branch; apply findings; merge.
4. Lower one ratchet in `CODING_STANDARDS.md` and the lint config; repeat after the next batch of features.

### Overnight repo cleanup

The repo loop needs no one at the keyboard. From the repo root, with a clean tree:

```bash
claude -p "/deslop repo" --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Bash,Glob,Grep,Agent" > deslop-run.txt 2>&1
```

In the morning: `git log --oneline main..` shows one commit per slice, `deslop-run.txt` ends with the repo report, and `/clean-code-review main` reviews the branch. A slice marked `reverted` in the final commit message is the one to look at by hand.

### Refactoring checkpoints

Quality prompts improve the first version and then lose ground with every iteration; agents accumulate erosion several times faster than people do. Counter it with a schedule rather than more prompting:

- Before every commit: `/finish`.
- Every few features on the same module: `/deslop <module>`, and compare the `Complexity` line with the last run.
- After a big merge, or once a quarter: `/deslop repo`.
- When `complexity.sh` shows a hotspot over the budget: let `/deslop` pass 9 split it before the next feature lands on top of it.

### Measuring the skill itself

```bash
evals/run.sh              # runs each fixture's command in a fresh session and checks the result
evals/run.sh ts-repo      # one fixture: /deslop repo over two modules
evals/run.sh --keep       # keep the workspaces; agent-output.txt lands beside each in <workspace>.meta/
```

Add a fixture from your own codebase (`evals/fixtures/<name>/` with a `check.sh`, a behaviour test, and either an `entry` for `/deslop <entry>` or a `command` with the full invocation) to measure against the slop you actually see.

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

**Plugin commands have a prefix.** Plugin installs namespace skills: `/clean-code:finish`, `/clean-code:deslop`, `/clean-code:interrogate`, `/clean-code:clean-code-review`, `/clean-code:clean-code-setup`. skills.sh and script installs use the bare names.

**`/deslop repo` refuses to start.** The working tree is not clean. Commit or stash, then run it again. It also stops before the first slice when no check command can be found and no tests exist; run `/clean-code-setup` first.

**`/deslop repo` stopped after a few slices.** Three consecutive reverts stop the run because the failure is outside the slices: a flaky suite, a lint rule the whole repo fails, a typecheck that was already red. The plan in `.deslop/plan.md` says which slices were reverted and why. Fix the cause, then `/deslop repo` resumes at the first `pending` row.

**`/finish` reports `needs decision`.** The fresh-context reviewer said `rethink`, or the check is red for a reason outside the change, or a spec requirement is missing from the diff. The block names it. Decide, make the change, run `/finish` again.

**`/finish` or `/deslop repo` did everything in the main context.** The host has no subagents (or the Agent tool was not allowed in a `claude -p` run). The result is the same; only the freshness of the review and the per-slice context isolation are lost. In `claude -p`, add `Agent` to `--allowedTools`.

**`/clean-code-review` reports nothing.** Confirm the base ref: with a clean tree and no argument it diffs against the merge-base with `main` or `master`; on another default branch, pass it explicitly.

**`/deslop` refuses to clean a file.** It found no test signal for that code and would not change it blind. Either accept the characterization tests it proposes, or give it a scope that has tests.

**Reports show `n/a` for a gate.** The command did not run, usually because the repo has no such tool. Run `/clean-code-setup`.

**Too many findings in review.** The review filters to correctness, maintainability, and documented standards. If it still reports style preferences, write the preference into `CODING_STANDARDS.md` one way or the other; documented standards win, documented exceptions suppress the flag.
