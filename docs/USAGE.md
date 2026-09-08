# Usage

Worked examples for each skill, recipes for common situations, branch behaviour, and troubleshooting. Commands are shown as typed into Claude Code; Codex and Cursor users type the same skill names (or, for the Claude Code plugin install, the namespaced form such as `/clean-code:deslop`).

## Contents

- The short version
- First hour in a new project
- First day in an existing project
- Daily flow
- Branches
- Reading the reports
- Recipes
- Windows notes
- Troubleshooting

## The short version

```
/clean-code-setup      once per repo: gates, check command, CODING_STANDARDS.md, three hooks
<describe the change>  clean-code fires on its own; hooks lint every edit and gate every stop
/finish                before every commit; /finish --commit to commit when ready
/deslop repo           once, on a codebase that already exists; resume by typing it again
```

Everything else is a piece of one of those.

## First hour in a new project

1. Install the skills (see the README). Confirm with `/skills` in Claude Code: `clean-code`, `finish`, `deslop`, `audit`, `test-audit`, `interrogate`, `clean-code-review`, `clean-code-setup` are listed.
2. Run `/clean-code-setup`. It detects the stack, merges the complexity, dead-code, and security rules into the linter, adds a `check` command and a fast subset, creates `CODING_STANDARDS.md`, points `CLAUDE.md` or `AGENTS.md` at it, installs the three hooks, and proves each gate fails on a violation before passing again. Expect a report like:

   ```
   ## Setup Report
   Stacks    ts
   Gates     complexity 10 · depth 3 · params 4 · dead code via knip · security via eslint-plugin-security
   Check     npm run check · fast: npm run check:fast
   Standards CODING_STANDARDS.md created · pointer in CLAUDE.md
   Hooks     format-and-lint, check-on-stop, commit-gate
   Mutation  offered: npm i -D @stryker-mutator/core
   Proof     pass → fail (complexity, no-unused-vars, security/detect-child-process) → commit blocked → pass
   Ratchet   none
   ```

3. Build the first feature the way you normally would. The `clean-code` skill fires on its own. Say what you want, name the seam if you have an opinion, and name the check:

   ```
   Add an orders module: create an order from a cart, reject empty carts,
   expose it through POST /orders. Tests at the HTTP seam. Run npm run check when done.
   ```

   While the agent works, the edit hook formats and lints each file it touches and hands findings straight back. When the agent tries to stop with the fast gates red, the stop hook keeps it working, up to three times; after that it lets the agent stop and tells you, because a gate that stays red is usually outside the change. The hooks see only the agent's own edits and commits; CI is the merge gate.

4. Read the Clean Code Report at the end. If `Left` names something you care about, make it the next task. If `Unverified` names something, decide whether it needs a run before you commit.
5. Before the first commit:

   ```
   /finish
   ```

   It interrogates the diff, deslops it, makes the change's tests able to fail, hunts for bugs in the change, runs the check, reviews it in a fresh context, applies the findings, and ends with a Finish Report whose last line is a suggested commit message. `/finish --commit` commits when the verdict is `ready`. Even without `/finish`, the commit gate hook runs the check before any `git commit` the agent makes and blocks a red one.

## First day in an existing project

The order matters: gates first, then the whole-repo rewrite, then review of the branch it produced.

### 1. Gates

```
/clean-code-setup
```

On a codebase that already exceeds the thresholds in many places, setup raises the threshold to the current maximum and records it as a ratchet in `CODING_STANDARDS.md`. The check passes today; the threshold comes down as cleanup lands. Security rules that fire on existing code are listed for the audit, not suppressed.

### 2. The whole repo, one command

From `main`, with a clean tree:

```
/deslop repo
```

What happens:

- Preflight: the tree must be clean; on `main` a `deslop/<date>` branch is created; the check command runs and its result is the baseline.
- Plan: the source is inventoried (generated code, vendored code, migrations, snapshots, dot-directories excluded; docs and instruction files included as their own last slice), complexity, churn, and entry points are measured, files are grouped into slices (a module with its tests), and the slices are ordered: with tests before without, leaves before shared code, hot spots first within a tier. The plan is written to `.deslop/plan.md` and shown to you. The run starts without waiting.

  ```
  # Deslop plan
  Branch deslop/2026-09-08 from main @ 3f2a1c9 · check: npm run check · baseline 214/214 · complexity max 31 · erosion 22%
  Excluded: dist/, src/generated/, prisma/migrations/
  Flags: audit on · structure on

  | # | Slice | Files | Lines | CC max | Churn | Entry points | Status |
  |---|---|---|---|---|---|---|---|
  | 1 | src/orders | 14 | 1,180 | 23 | 41 | 3 | pending |
  | 2 | src/billing | 9 | 760 | 12 | 28 | 2 | pending |
  | 3 | src/lib | 11 | 940 | 31 | 63 | 0 | pending |
  | 4 | docs, README.md, CLAUDE.md | 6 | 900 | n/a | 12 | 0 | pending |
  ```

- Per slice, two fresh-context workers. The first runs the eleven passes (through the design pass, the test audit, and the docs pass) on that slice alone and returns its Deslop Report; the main session reverts anything outside the slice, runs the check command, and commits `refactor(deslop): src/orders` with the report as the body. The second audits the cleaned slice; each fix is checked by stashing it and watching its test fail on the old code; the fixes land as `fix(audit): src/orders`. A red check reverts the slice, marks it in the plan, and moves on. Three reverts in a row stop the run: that is a suite or lint problem, not a slice problem.
- Structure: after the last slice, layout problems (technical-layer folders, `utils/` dumping grounds, deep imports, barrels, cycles, oversized files) are fixed with tool-verified moves, one commit per move, and the moved paths are listed in the report. `--no-structure` skips it.
- Finish: the check and `complexity.sh` run once more, the plan goes into the final commit message and `.deslop/` is deleted, and the report sums the slices:

  ```
  ## Deslop Report (repo)
  Branch      deslop/2026-09-08 · 12 slices · 11 committed · 1 reverted · 0 untestable
  Diff        +612 / -3,908 lines · net -3,296   (main..HEAD)
  Passes      dead code 640 · comments 1,102 · abstractions 19 · defensive 87 · duplication 11 · naming 23 · filler 58 · hotspots 9 · design 14 · docs 31
  Tests       214 → 221 · deleted 31 · rewritten 12 · added 50 · probes killed 118/126
  Audit       fixed 9 (bugs 5 · weaknesses 2 · security 2) · reported 6 · high 2 · medium 4 · low 3
  Structure   moved 7 paths · proposals 2
  Gates       check pass · tests 214/214 → 221/221
  Complexity  max 31 → 12 · over budget 9 → 2 · erosion 22% → 4%
  Verdict     behaviour preserved outside the 9 audited fixes · reverted: src/legacy (characterization tests could not pin the export format)
  ```

Stop the run whenever you want; the next `/deslop repo` resumes at the first `pending` row. Edit `.deslop/plan.md` to reorder or drop slices. `/deslop repo --plan` writes the plan and stops, for a look before committing to a long run. `--refactor-only` skips the audit workers. Every slice is one or two commits, so `git revert <sha>` undoes exactly one module's cleanup or exactly one module's fixes.

Want to judge the result on one module before the whole repo? Run it on that module first:

```
/deslop src/orders
```

The same passes and the same audit, in the working tree, no commits, one report. Say `and commit after each pass` in the same message if you want a reviewable history.

### 3. Review the branch before merging

```
/clean-code-review main
```

On the `deslop/<date>` branch, the review reads the whole cleanup as one diff, test changes first. Apply its findings in the working session, re-run until the verdict is `merge`, then merge the branch. Then lower one ratchet in `CODING_STANDARDS.md` and the lint config.

## Daily flow

```
<describe the change>       clean-code loads on a matching task; hooks lint each edit and gate the stop
/finish                     interrogate, deslop, test audit, audit, gates, fresh-context review, findings applied
git commit                  or: /finish --commit   (the commit gate runs the check either way)
```

`/finish` picks a level from the change: `fast` for one module under about 40 lines with no risk marker (interrogate, mechanical passes, fast gates, inline review), `standard` for the rest, `deep` when the diff touches auth, persistence, concurrency, external side effects, public contracts, migrations, or many files (mutation tool where installed, callers two levels out, a second fresh review). `--fast`, `--standard`, `--deep` override. It ends with a Finish Report:

```
## Finish Report
Purpose     Retry webhook delivery with exponential backoff · level deep (external side effects)
Scope       working tree · 3 files
Interrogate deleted 2 · simplified 1
Deslop      dead code 4 · comments 11 · abstractions 1 · defensive 2 · duplication 0 · naming 1 · filler 0 · hotspots 0 · design 1 · docs 0
Tests       deleted 1 · rewritten 0 · added 2 · probes killed 5/5
Audit       fixed 1 (bugs 0 · weaknesses 1 · security 0) · reported 0
Review      round 1: 3 findings (slop 2 · design 1 · correctness 0 · scope 0) · round 2: 0 · verdict merge
Diff        +49 / -87 lines · net -38   (was +88 / -87 before finishing)
Gates       check pass · typecheck pass · lint pass · tests 60/60
Complexity  max 7 · over budget 0 · erosion 0%
Unverified  nothing
Verdict     ready to commit
Commit      feat(webhooks): retry delivery with exponential backoff
```

The one weakness it fixed: the retry had no cap, so a dead endpoint would have been retried forever; the fix came with a test that fails on the old code. `needs decision` means the reviewer said `rethink`, or a finding needs a call only you can make; the block lists it. The pieces on their own, when you want just one: `/interrogate`, `/deslop`, `/test-audit`, `/audit`, `/clean-code-review main [spec-file]`.

When the agent does something you dislike, add one dated line to `CODING_STANDARDS.md`. It is read on every run and overrides the skill. Delete the line once a linter enforces it. The agent will offer the line itself when you correct it.

## Branches

Every skill works on the branch that is checked out, because git cannot edit a branch that is not. The consequences:

- `/deslop repo` from `main` creates `deslop/<date>` and commits there. `main` and every other branch are untouched until you merge.
- `/deslop repo` from a feature branch stays on that branch and commits there. Run it from `main` unless that is what you want.
- Your other branches receive the cleanup when the deslop branch merges into `main` and they rebase or merge `main`. Expect conflicts in files both a feature and the cleanup changed, and more of them from the structure phase, which moves files. Best order: finish and merge short-lived branches first, run `/deslop repo`, merge it, then start new branches from the clean `main`. For long-lived branches, `--no-structure` avoids the moves, and the moved-path map in the final report is what you need to rebase by hand.
- To clean only what a feature branch changed: check it out and run `/finish main`.
- `/deslop <path>`, `/audit`, `/test-audit`, and `/finish` edit the working tree of the current branch and do not commit unless asked.

## Reading the reports

Every skill ends with a block of about ten lines. The fields:

| Field | Meaning |
|---|---|
| `Scope` | What was asked, and how many files were inspected or changed. |
| `Diff` | Added and removed lines from `git diff`, lock files excluded, and the net. Negative net on a cleanup is the point. |
| `Removed` / `Passes` | Counts per category. Comments and dead code are counted by pattern in the diff; abstractions, design moves, and docs cuts are counted by the agent. |
| `Tests` | Tests before and after, what was deleted, rewritten, or added, and mutation probes killed over total. A survivor means a behaviour the suite does not protect; the list below the block names it. |
| `Audit` | Fixes made (each with a test that went red first) by kind, and findings reported but not fixed: unproven, out of scope, or needing a decision. |
| `Gates` | Each check that actually ran, with its result. `n/a` means it did not run, which is a fact, not a pass. |
| `Complexity` | Highest per-function cyclomatic complexity, how many functions exceed the budget, and erosion (the share of complexity inside those functions). `/deslop` shows before → after. `n/a` when no ESLint, Ruff, or gocyclo is available. |
| `Tools` | Inventory tools before and after (unused exports, dead functions, slop score). |
| `Interrogate` / `Review` | `/finish` only: what the interrogation cut, and the fresh-context reviewer's findings per axis and round with its verdict. |
| `Branch` / `Structure` | `/deslop repo` only: the branch, how many slices were committed, reverted, or found untestable, and the paths the structure phase moved. |
| `Unverified` | What could not be run, and why. An empty line here is a claim; read it as one. |
| `Left` / `Found, not changed` | What was noticed and deliberately not touched. This is where scope discipline shows. |
| `Verdict` | `ready to commit`, `behaviour preserved`, `clean`, `suite bites`, `needs decision: ...`, or the review's `merge` / `fix then merge` / `rethink`. |
| `Commit` | `/finish` only: a suggested one-line commit message. |

To recompute the numbers yourself:

```bash
bash ~/.claude/skills/clean-code/scripts/diff-stats.sh          # working tree vs HEAD
bash ~/.claude/skills/clean-code/scripts/diff-stats.sh main     # since the merge-base with main
bash ~/.claude/skills/clean-code/scripts/complexity.sh src      # per-function complexity, hotspots, erosion
```

## Recipes

### Pull-request gate

Add a CI job that fails on slop, complexity, and known vulnerabilities, independent of the agent:

```yaml
- run: npm run check                                       # the umbrella command from /clean-code-setup
- run: npm audit --audit-level=high                        # or pip-audit, cargo audit, govulncheck
- run: npx aislop@latest ci --changes --base origin/main   # optional: deterministic slop score on changed files
```

### Legacy repository in a day

1. `/clean-code-setup` with ratchets.
2. `/deslop repo`. It orders the slices by churn and erosion on its own, so the hot directories land first; stop it at the end of the day and resume tomorrow. The `fix(audit)` commits are the ones to read first in the morning.
3. `/clean-code-review main` on the `deslop/<date>` branch; apply findings; merge.
4. Lower one ratchet in `CODING_STANDARDS.md` and the lint config; repeat after the next batch of features.

### Overnight repo cleanup

The repo loop needs no one at the keyboard. From the repo root, with a clean tree:

```bash
claude -p "/deslop repo" --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Bash,Glob,Grep,Agent" > deslop-run.txt 2>&1
```

In the morning: `git log --oneline main..` shows a `refactor(deslop)` and, where there were fixes, a `fix(audit)` commit per slice, `deslop-run.txt` ends with the repo report, and `/clean-code-review main` reviews the branch. A slice marked `reverted` in the final commit message is the one to look at by hand.

### Security pass before a release

```
/audit src --report-only
```

reports every proven finding with its reproduction and changes nothing. Drop `--report-only` to fix them, one red test each. For a change that touches auth, payments, secrets, or untrusted input, `/finish` already runs the audit on it; a human still reads that diff.

### Refactoring checkpoints

Quality prompts improve the first version and then lose ground with every iteration; agents accumulate erosion several times faster than people do. Counter it with a schedule rather than more prompting:

- Before every commit: `/finish`.
- Every few features on the same module: `/deslop <module>`, and compare the `Complexity` and `Tests` lines with the last run.
- After a big merge, or once a quarter: `/deslop repo`.
- When `complexity.sh` shows a hotspot over the budget: let `/deslop` pass 8 split it before the next feature lands on top of it.

### Measuring the skill itself

```bash
evals/run.sh                    # runs each fixture's command in a fresh session and checks the result
evals/run.sh ts-audit           # one fixture: /audit over an injection and an off-by-one
evals/run.sh --baseline ts-audit  # the same fixture, no skills, a plain-English prompt
evals/run.sh --runs 3 ts-clean  # repeat, to see variability
evals/run.sh --keep ts-test-audit # keep the workspace; agent-output.txt lands in <workspace>.meta/
```

Every run appends tokens, cost, turns, time, and the Claude Code version to `evals/results/log.tsv`. Add a fixture from your own codebase (`evals/fixtures/<name>/` with a `check.sh`, a behaviour test, a `baseline` prompt, and either an `entry` for `/deslop <entry>` or a `command` with the full invocation) to measure against the slop you actually see.

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

- `scripts/install.ps1 -Global` installs; the skills' own scripts (`diff-stats.sh`, `complexity.sh`) and the three hooks run under Git Bash, which comes with Git for Windows. Claude Code's Bash tool uses it automatically.
- Hook commands in `hooks.settings.json` call `bash` explicitly for this reason.
- Paths inside the skills use forward slashes; that is deliberate and works on Windows.

## Troubleshooting

**The clean-code skill does not fire.** Check `/skills` lists it. If it is installed as a plugin, the description is still loaded; if it is a project skill, make sure `.claude/skills/clean-code/SKILL.md` exists in the repo root, not a subdirectory. Mention "clean code" or "simplify" in the prompt to force it, or invoke it directly with `/clean-code`.

**Plugin commands have a prefix.** Plugin installs namespace skills: `/clean-code:finish`, `/clean-code:deslop`, `/clean-code:audit`, `/clean-code:test-audit`, `/clean-code:interrogate`, `/clean-code:clean-code-review`, `/clean-code:clean-code-setup`. skills.sh and script installs use the bare names.

**The stop hook keeps the agent working on something that was already red.** The fast gates were red before the agent touched the tree, usually a pre-existing lint failure. The hook blocks at most three stops per session and then lets the agent stop with a message. Fix the cause or raise the ratchet; the hook compares against zero, not against a baseline. To pause the hooks, remove their entries from `.claude/settings.json`; to never install them, `/clean-code-setup --no-hooks`.

**The commit gate blocks a commit I want.** The check command is red. The hook prints the failures; fix them. It catches every spelling of `git commit` the agent can run through its Bash tool (`scripts/test-hooks.sh` lists them). From your own shell, `git commit` is not affected, and neither is CI; make CI the gate that matters.

**`/deslop repo` refuses to start.** The working tree is not clean. Commit or stash, then run it again. It also stops before the first slice when no check command can be found and no tests exist; run `/clean-code-setup` first.

**`/deslop repo` stopped after a few slices.** Three consecutive reverts stop the run because the failure is outside the slices: a flaky suite, a lint rule the whole repo fails, a typecheck that was already red. The plan in `.deslop/plan.md` says which slices were reverted and why. Fix the cause, then `/deslop repo` resumes at the first `pending` row.

**An audit fix was reverted with "the test did not go red".** The regression test passed on the pre-fix code, so it proves nothing. The fix is listed in the plan; give it a test that fails first, or leave it as a reported finding.

**`/finish` reports `needs decision`.** The fresh-context reviewer said `rethink`, or the check is red for a reason outside the change, or a spec requirement is missing from the diff, or an audit finding needs a call only you can make. The block names it. Decide, make the change, run `/finish` again.

**`/finish` or `/deslop repo` did everything in the main context.** The host has no subagents (or the Agent tool was not allowed in a `claude -p` run). The result is the same; only the freshness of the review and the per-slice context isolation are lost. In `claude -p`, add `Agent` to `--allowedTools`.

**`/test-audit` reports survivors.** A mutant nothing killed. Each survivor names the behaviour the suite does not protect; it is untested behaviour or dead code. Write the test, or let `/deslop` remove the code.

**`/clean-code-review` reports nothing.** Confirm the base ref: with a clean tree and no argument it diffs against the merge-base with `main` or `master`; on another default branch, pass it explicitly.

**`/deslop` refuses to clean a file.** It found no test signal for that code and would not change it blind. Either accept the characterization tests it proposes, or give it a scope that has tests.

**Reports show `n/a` for a gate.** The command did not run, usually because the repo has no such tool. Run `/clean-code-setup`.

**Too many findings in review.** The review filters to correctness, maintainability, security, and documented standards, and drops anything a second reading does not support. If it still reports style preferences, write the preference into `CODING_STANDARDS.md` one way or the other; documented standards win, documented exceptions suppress the flag.
