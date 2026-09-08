# Deslop: repo scope

Cleaning a whole codebase in one sitting fails in two ways. The context fills up halfway through and the second half gets less care than the first. Or one giant diff lands that nobody can review and nobody dares revert. The remedy is the one used for large-scale changes everywhere: plan, shard, and land each shard on its own. Google ships large-scale changes as shards that are tested and committed independently. Kent Beck keeps tidyings in their own small commits, apart from behaviour changes. Anthropic's harness for long-running agents gives each unit of work a fresh session, a progress file, and a commit, because an agent asked to do everything at once leaves the tree half done.

`/deslop repo` is that loop. The main session plans and keeps the books. A fresh-context worker cleans one slice; a second fresh-context worker audits it for bugs. The main session confines each diff, gates it, commits it, and records the result. Repeat. When every slice has landed, a structure phase fixes the layout. Stop at any point; `/deslop repo` resumes from the plan.

## Preflight

- `.deslop/plan.md` already exists: this is a resume. Changes under `.deslop/` are expected; anything else in `git status --porcelain` must be clean. Skip to Run.
- Otherwise the working tree is clean (`git status --porcelain` prints nothing). If not, stop and say so; commit or stash first.
- On the default branch (`main`, `master`, or whatever `origin/HEAD` points at): create `deslop/<yyyy-mm-dd>` and switch to it. On any other branch: stay. Other branches are never touched; they receive the cleanup when this branch merges and they rebase.
- Identify the check command: `CODING_STANDARDS.md` names it, or the umbrella script from `/clean-code-setup`, or typecheck plus lint plus the full suite assembled by hand. Run it now and record the baseline. A red baseline is recorded as it is; every gate below compares against the baseline, not against zero.

**Ownership.** The loop reverts only what it caused. `${CLAUDE_SKILL_DIR}/scripts/slice.sh` keeps the books: `snapshot` records the tree before a worker starts, `confine` reverts changes outside the slice that were not there at the snapshot, and `red-check` proves a fix against the pre-fix code. `.deslop/` is never reverted; it is the loop's own state and travels with every commit.

## Plan

Write `.deslop/plan.md`. It is the only state the loop has, so a new session can pick the work up where the last one stopped.

1. **Inventory.** Every source file, plus the instruction and doc files at the root (`README.md`, `CLAUDE.md`, `AGENTS.md`, `docs/`), minus what is never cleaned: dependencies and build output (`node_modules`, `dist`, `build`, `.next`, `target`, `vendor`, `venv`), dot-directories (`.claude`, `.agents`, `.cursor`, `.github`), lockfiles, migrations, snapshots and fixtures, minified files, and anything marked generated (`@generated`, `DO NOT EDIT`, `Code generated`). The plan lists the exclusions.
2. **Measure.** `complexity.sh .` for hotspots and erosion. Churn: `git log --since='1 year ago' --name-only --format=` piped through `sort | uniq -c | sort -rn`. Which directories have tests. Entry points that face untrusted input (handlers, consumers, CLIs), because those slices get the audit's closest attention.
3. **Slice.** Group files by module: a folder with its entry point, implementation, and tests together, so the worker sees the whole seam. Split a folder by subfolder when it exceeds about 15 files or 1,500 lines; merge tiny sibling folders. The docs and instruction files form one slice of their own, last. Every slice must be committable on its own.
4. **Order.** Lowest risk and highest value first. Slices that have tests before slices that do not. Leaf modules (few importers) before shared ones. Within a tier, the most churn and the highest erosion first, because cleanup pays off where change happens. Shared utilities and the core go last; everything cleaned before them uses their interfaces.
5. **Write the plan** in the shape below and show it to the user in one message, then start slice 1. Do not wait for approval: every slice is a separate commit on its own branch, and the user can stop the run, reorder rows, or delete rows in the plan at any time. With `--plan`, stop after writing.

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

## Run

For each slice with status `pending`, in order:

1. **Clean it in a fresh context.** First `bash <skill directory>/scripts/slice.sh snapshot`. Then use the Agent tool with the `general-purpose` agent and this prompt, paths filled in:

   > Read `<skill directory>/SKILL.md` and apply it with the scope `<slice paths>` and the flag `--refactor-only`. Change record: check `<check command>`, focused tests `<command for this slice>`, standards `<CODING_STANDARDS.md or none>`, baseline `<tests N/N, complexity max, hotspots in this slice>`, inventory `<the knip/ruff/deadcode findings inside this slice, or none>`. Use the record instead of rediscovering it. Rules for this run: touch nothing outside the scope; do not commit; create no files outside the scope except tests beside the code they cover; the existing tests are the behaviour lock, add characterization tests where they are thin. Return only the Deslop Report block, the "Found, not changed" list, and the "Suggested follow-ups" list.

   The worker sees nothing of the other slices or of the planning. That is the point: each slice gets the attention the first slice of a long session gets. Run workers one at a time. Two workers editing at once make each other's gates fail on half-finished files; parallel slices need separate worktrees, which this loop does not manage. A host without subagents runs the slice inline, and after the commit stops with a note that `/deslop repo` resumes when the context is getting long.
2. **Confine the diff.** `bash <skill directory>/scripts/slice.sh confine <slice paths>`. It leaves the slice, `.deslop/`, and every change that existed at the snapshot alone, reverts the rest (tracked files back to `HEAD`, untracked files deleted), and prints what it reverted; note that list in the plan.
3. **Gate.** Run the check command. The result must be no worse than the baseline: the same tests passing, or a difference explained by tests deleted or added in pass 10 of the worker's report. On red: revert the slice (`git checkout -- <slice paths>` and remove untracked files inside it), mark the row `reverted: <reason>`, continue with the next slice. Three reverts in a row mean the problem is outside the slices (a flaky suite, a global lint failure); stop and report.
4. **Commit the cleanup.** `git add <slice paths> .deslop/plan.md`, then `refactor(deslop): <slice>` with the worker's report block as the body. One slice, one commit, revertible with `git revert`.
5. **Audit it in a second fresh context**, unless `--refactor-only`. Same Agent tool, this prompt:

   > Read `<skill directory>/../audit/SKILL.md` and apply it with the scope `<slice paths>`. Change record: check `<check command>`, focused tests `<command for this slice>`, entry points `<from the plan row>`, standards `<path or none>`, baseline `<tests N/N>`. Use the record instead of rediscovering it. Rules for this run: touch nothing outside the scope; do not commit; every fix ships with a test that failed before it; report anything you cannot prove instead of changing it. Return only the Audit Report block and the findings list.

   The orchestrator measures each slice: worker wall time and, where the host reports it, tokens. A slice whose audit worker finds nothing three slices in a row on a codebase with no entry points is a signal to run the remaining audits at `--report-only` and read the reports instead.

   Snapshot, confine, and gate exactly as in steps 1 to 3. Then prove each fix: `bash <skill directory>/scripts/slice.sh red-check "<focused test command>" <production paths the fix changed>` puts the pre-fix production code back, runs the tests (the new regression tests stay in place), and restores the fix; a fix whose tests pass on the pre-fix code is unproven and is reverted. Commit as `fix(audit): <slice>` with the report as the body. No changes, no commit. The cleanup and the fixes are separate commits on purpose: a reviewer reads a refactor for "same behaviour" and a fix for "new behaviour, proven".
6. **Record.** Update the row: `done <sha> · fix <sha | none> · net <±n> · CC max <a> → <b>`, or `reverted: <reason>`, or `untestable` when the worker found no test signal. Append the worker's "Found, not changed" items and the audit's reported findings to a `## Found, not changed` section at the end of the plan.

A worker that returns partial output, or reports that it could not lock behaviour, counts as red for that slice.

## Structure

After the last slice, unless `--no-structure`. Layout problems cross slices, so they are fixed once, at the end, when every module is clean and every test bites.

1. Read `${CLAUDE_SKILL_DIR}/../clean-code/STRUCTURE.md`, "Structure problems" in particular. Walk the tree and list the problems with their fix: technical-layer top-level folders holding one feature in five places; `utils/`, `helpers/`, `common/` dumping grounds; deep imports past a module's entry point; barrels re-exporting subtrees; import cycles; tests far from the code they cover when the repo convention is colocation; files over 400 lines with more than one responsibility; a module nested inside another module; types living away from their users.
2. Apply the moves that tooling can verify: `git mv`, update imports (the language server, `tsc` errors, `goimports`, the IDE-free equivalent), run the check command. Green lands as one commit, `refactor(structure): <what moved>`. Red is reverted and the move goes in the report as a proposal. A move that needs a decision (a new module boundary, a rename callers outside the repo depend on) is a proposal, never done.
3. Moves are the changes most likely to conflict with open branches. The report names every moved path so those branches can rebase with the map in hand.

## Finish

- Run the check command and `complexity.sh .` once more; record the repo-wide before and after.
- Put the plan's final table into the commit message and delete `.deslop/`: `refactor(deslop): finish repo cleanup (<n> slices, net <±n> lines)`. The history keeps the plan; the tree does not.
- Report:

```
## Deslop Report (repo)
Branch      deslop/2026-09-08 · 12 slices · 11 committed · 1 reverted · 0 untestable
Diff        +612 / -3,908 lines · net -3,296   (main..HEAD)
Passes      dead code 640 · comments 1,102 · abstractions 19 · defensive 87 · duplication 11 · naming 23 · filler 58 · hotspots 9 · design 14 · docs 31
Tests       214 → 221 · deleted 31 · rewritten 12 · added 50 · probes killed 118/126
Audit       fixed 9 (bugs 5 · weaknesses 2 · security 2) · reported 6 · high 2 · medium 4 · low 3
Structure   moved 7 paths · proposals 2   (or skipped)
Gates       check pass · tests 214/214 → 221/221
Complexity  max 31 → 12 · over budget 9 → 2 · erosion 22% → 4%
Verdict     behaviour preserved outside the 9 audited fixes · reverted: src/legacy (characterization tests could not pin the export format)
```

Below the block: the audit's fixed findings with their tests; the merged "Found, not changed" list, unproven bugs first; the moved-path map; and at most three follow-ups. The usual three: lower a ratchet in `CODING_STANDARDS.md`, retry the reverted slice with a decision in hand, and `/clean-code-review main` on the branch before it merges.
