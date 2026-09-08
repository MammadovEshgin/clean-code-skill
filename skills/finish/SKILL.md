---
name: finish
description: Finish a change before it is committed. Interrogates the diff, removes slop, audits its tests, hunts bugs and security flaws in it, runs the gates, reviews it in a fresh context, applies the findings, and leaves the tree ready to commit with one report. Target is the uncommitted diff, or the branch when a base ref is given.
disable-model-invocation: true
argument-hint: [base-ref] [--commit]
---

# Finish

One command between "it works" and `git commit`. It runs the finishing skills in the order that wastes the least work: interrogate first, because a deleted function needs no cleaning; then deslop what remains; then make the change's tests able to fail; then hunt for what is wrong in it; then a review by a context that did not write the code; then the findings are applied. The change comes out smaller, proven, gated, and reviewed, with one report.

Arguments: `$ARGUMENTS`. The first argument that is not a flag is the base ref. `--commit` commits the result when the verdict is ready.

## 0. Pin the change

- Uncommitted changes present: the target is `git diff HEAD` plus the untracked files from `git status --short`.
- Clean tree: the target is `git diff <base>...HEAD`. Default base: the merge-base with `main` or `master`. Edits made below land in the working tree as a new change on top of the branch.
- Write the purpose in one sentence, from the request, the commit messages, the branch name, or a spec file the conversation named. Identify the check command (`CODING_STANDARDS.md`, the `check` script from `/clean-code-setup`, or typecheck plus lint plus tests). Record the file list and the `diff-stats.sh` numbers as the baseline.
- Empty target: stop and say so.

## 1. Interrogate

Read `${CLAUDE_SKILL_DIR}/../interrogate/SKILL.md` and apply it to the target. Make the cuts it finds and verify them. Keep its counts for the report.

## 2. Deslop

Read `${CLAUDE_SKILL_DIR}/../deslop/SKILL.md` and apply it to the target's files with `--refactor-only`, the hunks the target touches first. The passes stay behaviour-preserving; pass 10 runs the test audit on the tests the target added or changed and on the seams it changed that have no test, with mutation probes capped at the functions the target touched.

## 3. Audit

Read `${CLAUDE_SKILL_DIR}/../audit/SKILL.md` and apply it to the target: the changed hunks and the functions they call. A bug in the change is fixed with a test that failed first; a pre-existing bug the change did not introduce is reported with its reproduction, not fixed here.

## 4. Gate

Run the check command. Red caused by the target is fixed before step 5. Red caused by something outside the target stops the run with `needs decision`.

## 5. Review with fresh eyes

Use the Agent tool with the `general-purpose` agent and this prompt: "Read `${CLAUDE_SKILL_DIR}/../clean-code-review/SKILL.md` and apply it with the arguments `<base-ref> <spec-path, if any>`. Return the review block only." The reviewer sees the diff, the nearby code, and the standards, not this session's reasoning. On a host without subagents, run the review inline after re-reading the diff from the top, hunk by hunk, before writing a finding.

## 6. Apply

- **Slop** findings: apply all.
- **Design** findings: apply those with a concrete fix that keeps behaviour and stays inside the target's files. The rest go into the report as decisions.
- **Correctness** findings: reproduce each one (a test that fails, a command that shows the wrong outcome); fix the ones that reproduce; a finding that does not reproduce is dropped with a note. A weakened check the reviewer found (a test rewritten to match, a skip, a suppression, a lowered threshold) is restored and the code fixed instead.
- **Scope** findings: revert changed lines the purpose does not explain. A requirement the spec asked for and the change lacks is a decision, not something to build here.
- Verdict `rethink`: stop, apply nothing further, report `needs decision` with the reviewer's worst issue.

Run the check command again. When findings were applied, review once more (step 5) and apply once more. Two rounds at most; a finding that survives two rounds is reported, not chased.

## 7. Land

- Without `--commit`: leave the working tree as it is. Nothing is staged on the user's behalf.
- With `--commit` and verdict `ready`: stage the target's files and commit with a conventional message derived from the purpose (`feat:`, `fix:`, `refactor:`, and so on), the body naming what was decided and what was ruled out. Any other verdict commits nothing.

## Report

```
## Finish Report
Purpose     <one sentence>
Scope       <working tree | base..HEAD> · <N files>
Interrogate deleted <n> · simplified <n>
Deslop      dead code <n> · comments <n> · abstractions <n> · defensive <n> · duplication <n> · naming <n> · filler <n> · hotspots <n> · design <n> · docs <n>
Tests       deleted <n> · rewritten <n> · added <n> · probes killed <k>/<m>
Audit       fixed <n> (bugs <n> · weaknesses <n> · security <n>) · reported <n>
Review      round 1: <n> findings (slop <n> · design <n> · correctness <n> · scope <n>) · round 2: <n | skipped> · verdict <merge | fix then merge | rethink>
Diff        +<added> / -<removed> lines · net <±n>   (was +<a> / -<r> before finishing)
Gates       check <pass|fail|n/a> · typecheck <pass|fail|n/a> · lint <pass|fail|n/a> · tests <passed>/<total>
Complexity  max <n> · over budget <n> · erosion <x%>   (or n/a)
Unverified  <what could not be run, and why, or "nothing">
Verdict     <ready to commit | committed <sha> | needs decision: ...>
Commit      <suggested one-line message>
```

Numbers come from `diff-stats.sh` and `complexity.sh` in the `clean-code` skill folder (`${CLAUDE_SKILL_DIR}/../clean-code/scripts/`) and from the commands that ran. Below the block: the findings left open, each with file, line, and the reason it was not applied. Nothing else.
