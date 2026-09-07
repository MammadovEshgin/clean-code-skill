# Deslop: repo scope

Cleaning a whole codebase in one sitting fails in two ways. The context fills up halfway through and the second half gets less care than the first. Or one giant diff lands that nobody can review and nobody dares revert. The remedy is the one used for large-scale changes everywhere: plan, shard, and land each shard on its own. Google ships large-scale changes as shards that are tested and committed independently. Kent Beck keeps tidyings in their own small commits, apart from behaviour changes. Anthropic's harness for long-running agents gives each unit of work a fresh session, a progress file, and a commit, because an agent asked to do everything at once leaves the tree half done.

`/deslop repo` is that loop. The main session plans and keeps the books. A fresh-context worker cleans one slice. The main session confines the diff, gates it, commits it, and records the result. Repeat. Stop at any point; `/deslop repo` resumes from the plan.

## Preflight

- The working tree is clean (`git status --porcelain` prints nothing). Otherwise stop and say so; commit or stash first.
- On the default branch (`main`, `master`, or whatever `origin/HEAD` points at): create `deslop/<yyyy-mm-dd>` and switch to it. On any other branch: stay.
- Identify the check command: `CODING_STANDARDS.md` names it, or the umbrella script from `/clean-code-setup`, or typecheck plus lint plus the full suite assembled by hand. Run it now and record the baseline. A red baseline is recorded as it is; every gate below compares against the baseline, not against zero.
- `.deslop/plan.md` already exists: this is a resume. Skip to Run.

## Plan

Write `.deslop/plan.md`. It is the only state the loop has, so a new session can pick the work up where the last one stopped.

1. **Inventory.** Every source file, minus what is never cleaned: dependencies and build output (`node_modules`, `dist`, `build`, `.next`, `target`, `vendor`, `venv`), dot-directories (`.claude`, `.agents`, `.cursor`, `.github`), lockfiles, migrations, snapshots and fixtures, minified files, and anything marked generated (`@generated`, `DO NOT EDIT`, `Code generated`). The plan lists the exclusions.
2. **Measure.** `complexity.sh .` for hotspots and erosion. Churn: `git log --since='1 year ago' --name-only --format=` piped through `sort | uniq -c | sort -rn`. Which directories have tests.
3. **Slice.** Group files by module: a folder with its entry point, implementation, and tests together, so the worker sees the whole seam. Split a folder by subfolder when it exceeds about 15 files or 1,500 lines; merge tiny sibling folders. Every slice must be committable on its own.
4. **Order.** Lowest risk and highest value first. Slices that have tests before slices that do not. Leaf modules (few importers) before shared ones. Within a tier, the most churn and the highest erosion first, because cleanup pays off where change happens. Shared utilities and the core go last; everything cleaned before them uses their interfaces.
5. **Write the plan** in the shape below and show it to the user in one message, then start slice 1. Do not wait for approval: every slice is a separate commit on its own branch, and the user can stop the run, reorder rows, or delete rows in the plan at any time. With `--plan`, stop after writing.

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

## Run

For each slice with status `pending`, in order:

1. **Hand it to a fresh context.** Use the Agent tool with the `general-purpose` agent and this prompt, paths filled in:

   > Read `<skill directory>/SKILL.md` and apply it with the scope `<slice paths>`. Rules for this run: touch nothing outside the scope; do not commit; create no files outside the scope except tests beside the code they cover; the existing tests are the behaviour lock, add characterization tests where they are thin. Return only the Deslop Report block, the "Found, not changed" list, and the "Suggested follow-ups" list.

   The worker sees nothing of the other slices or of the planning. That is the point: each slice gets the attention the first slice of a long session gets. Run workers one at a time. Two workers editing at once make each other's gates fail on half-finished files; parallel slices need separate worktrees, which this loop does not manage. A host without subagents runs the slice inline, and after the commit stops with a note that `/deslop repo` resumes when the context is getting long.
2. **Confine the diff.** `git status --porcelain` shows only paths inside the slice, plus new tests beside them. Anything else is reverted (`git checkout -- <path>`, or deleted when untracked) and noted in the plan.
3. **Gate.** Run the check command. The result must be no worse than the baseline: the same tests passing, or a difference explained by tests deleted in pass 7 of the worker's report. On red: revert the slice (`git checkout -- <slice paths>` and remove untracked files inside it), mark the row `reverted: <reason>`, continue with the next slice. Three reverts in a row mean the problem is outside the slices (a flaky suite, a global lint failure); stop and report.
4. **Commit.** `git add <slice paths> .deslop/plan.md`, then `refactor(deslop): <slice>` with the worker's report block as the body. One slice, one commit, revertible with `git revert`.
5. **Record.** Update the row: `done <short sha> · net <±n> · CC max <a> → <b>`, or `reverted: <reason>`, or `untestable` when the worker found no test signal. Append the worker's "Found, not changed" items to a `## Found, not changed` section at the end of the plan.

A worker that returns partial output, or reports that it could not lock behaviour, counts as red for that slice.

## Finish

- Run the check command and `complexity.sh .` once more; record the repo-wide before and after.
- Put the plan's final table into the commit message and delete `.deslop/`: `refactor(deslop): finish repo cleanup (<n> slices, net <±n> lines)`. The history keeps the plan; the tree does not.
- Report:

```
## Deslop Report (repo)
Branch      deslop/2026-09-07 · 12 slices · 11 committed · 1 reverted · 0 untestable
Diff        +412 / -3,908 lines · net -3,496   (main..HEAD)
Passes      dead code 640 · comments 1,102 · abstractions 19 · defensive 87 · duplication 11 · naming 23 · tests 31 · filler 58 · hotspots 9
Gates       check pass · tests 214/214 → 203/203
Complexity  max 31 → 12 · over budget 9 → 2 · erosion 22% → 4%
Verdict     behaviour preserved · reverted: src/legacy (characterization tests could not pin the export format)
```

Below the block: the merged "Found, not changed" list, bugs first, and at most three follow-ups. The usual three: lower a ratchet in `CODING_STANDARDS.md`, retry the reverted slice with a decision in hand, and `/clean-code-review main` on the branch before it merges.
