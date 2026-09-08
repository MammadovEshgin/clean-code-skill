---
name: finish
description: Finish a change before it is committed. Interrogates the diff, removes slop, audits its tests, hunts bugs and security flaws in it, runs the gates, reviews it in a fresh context, applies the findings, and leaves the tree ready to commit with one report. Sized to the risk of the change. Target is the uncommitted diff, or the branch when a base ref is given.
disable-model-invocation: true
argument-hint: [base-ref] [--fast | --standard | --deep] [--commit]
---

# Finish

One command between "it works" and `git commit`. It runs the finishing skills in the order that wastes the least work (interrogate first, because a deleted function needs no cleaning), sized to the risk of the change, with the discovery done once and handed to every step.

Arguments: `$ARGUMENTS`. The first argument that is not a flag is the base ref. `--commit` commits when the verdict is ready. `--fast`, `--standard`, `--deep` force a level; otherwise the level comes from the change.

## 0. Pin the change and write the record

- Target: with uncommitted changes, `git diff HEAD` plus untracked files from `git status --short`; with a clean tree, `git diff <base>...HEAD` (default base: the merge-base with `main` or `master`), and edits below land in the working tree on top of the branch. Empty target: stop and say so.
- Write the **change record**, once, and hand it to every step and to the reviewer:

  ```
  Purpose   <one sentence, from the request, commit messages, branch name, or a spec file>
  Target    <working tree | base..HEAD> · <files> · <hunks per file>
  Checks    check: <command> · fast: <lint + typecheck command> · focused tests: <command>
  Standards <CODING_STANDARDS.md | CONTRIBUTING.md | CLAUDE.md sections, or none>
  Baseline  tests <N/N> · diff-stats <+a / -r>
  Risk      <markers present: auth, persistence, concurrency, external side effects, public contract, migrations, >10 files, or none>
  Level     <fast | standard | deep>
  ```

  A step that receives the record skips its own discovery. A check result is reused until a file it covers changes; after an edit, only typecheck and the focused tests rerun; the full check runs once before the review and once at the end.

- **Level.** `fast` when the target is one module, under about 40 changed lines, and carries no risk marker. `deep` when any risk marker is present. `standard` otherwise. A flag overrides.

| Step | fast | standard | deep |
|---|---|---|---|
| 1 Interrogate | yes | yes | yes |
| 2 Deslop the hunks (`--refactor-only`) | passes 1 to 7 on the hunks | all passes | all passes |
| 3 Test audit of the change's tests | none | probes on touched functions, six at most | mutation tool where installed, twelve probes at most |
| 4 Audit of the diff and its callees | none | yes | yes, entry points and callers two levels out |
| 5 Gate | fast command | check command | check command |
| 6 Review | inline, after re-reading the diff from the top | fresh context | fresh context, second round even without changes |
| 7 Apply and re-gate | slop findings | all axes, two rounds at most | all axes, two rounds at most |

## 1. Interrogate

Read `${CLAUDE_SKILL_DIR}/../interrogate/SKILL.md` and apply it to the target with the record. Make the cuts, verify with the focused tests. Keep its counts.

## 2. Deslop

Read `${CLAUDE_SKILL_DIR}/../deslop/SKILL.md` and apply it to the target's files with `--refactor-only` and the record, the hunks the target touches first. Behaviour-preserving throughout.

## 3. Test audit

Read `${CLAUDE_SKILL_DIR}/../test-audit/SKILL.md` and apply it to the tests the target added or changed and to the seams it changed that have no test, with the probe cap for the level.

## 4. Audit

Read `${CLAUDE_SKILL_DIR}/../audit/SKILL.md` and apply it to the target's hunks and the functions they call. A bug in the change is fixed with a test that failed first; a pre-existing bug the change did not introduce is reported with its reproduction, not fixed here.

## 5. Gate

Run the level's check. Red caused by the target is fixed before the review. Red caused by something outside the target stops the run with `needs decision`.

## 6. Review with fresh eyes

Use the Agent tool with the `general-purpose` agent and this prompt: "Read `${CLAUDE_SKILL_DIR}/../clean-code-review/SKILL.md` and apply it with the arguments `<base-ref> <spec-path, if any>`. Change record: `<the record>`. Return the review block only." The reviewer sees the diff, the nearby code, the standards, and the record, not this session's reasoning. At `fast`, or on a host without subagents, review inline after re-reading the diff from the top, hunk by hunk, before writing a finding.

## 7. Apply

- **Slop**: apply all. **Design**: apply those with a concrete fix that keeps behaviour and stays inside the target's files; the rest are decisions in the report. **Correctness**: reproduce each (a failing test, a command that shows the wrong outcome); fix what reproduces, drop what does not with a note; restore any weakened check and fix the code instead. **Scope**: revert changed lines the purpose does not explain; a missing spec requirement is a decision, not something to build here.
- Verdict `rethink`: stop, apply nothing further, report `needs decision` with the reviewer's worst issue.
- Re-gate. When findings were applied, review once more and apply once more. Two rounds at most; a finding that survives two rounds is reported, not chased.

## 8. Land

Without `--commit`: leave the working tree as it is; nothing is staged on the user's behalf. With `--commit` and verdict `ready`: stage the target's files and commit with a conventional message from the purpose (`feat:`, `fix:`, `refactor:`), the body naming what was decided and ruled out. Any other verdict commits nothing.

## Report

```
## Finish Report
Purpose     <one sentence> · level <fast | standard | deep> (<why>)
Scope       <working tree | base..HEAD> · <N files>
Interrogate deleted <n> · simplified <n>
Deslop      dead code <n> · comments <n> · abstractions <n> · defensive <n> · duplication <n> · naming <n> · filler <n> · hotspots <n> · design <n> · docs <n>
Tests       deleted <n> · rewritten <n> · added <n> · probes killed <k>/<m>   (or skipped at fast)
Audit       fixed <n> (bugs <n> · weaknesses <n> · security <n>) · reported <n>   (or skipped at fast)
Review      round 1: <n> findings (slop <n> · design <n> · correctness <n> · scope <n>) · round 2: <n | skipped> · verdict <merge | fix then merge | rethink> · <fresh | inline>
Diff        +<added> / -<removed> lines · net <±n>   (was +<a> / -<r> before finishing)
Gates       check <pass|fail|n/a> · typecheck <pass|fail|n/a> · lint <pass|fail|n/a> · tests <passed>/<total>
Complexity  max <n> · over budget <n> · erosion <x%>   (or n/a)
Unverified  <what could not be run, and why, or "nothing">
Verdict     <ready to commit | committed <sha> | needs decision: ...>
Commit      <suggested one-line message>
```

Numbers from `diff-stats.sh` and `complexity.sh` in the `clean-code` skill folder (`${CLAUDE_SKILL_DIR}/../clean-code/scripts/`) and from the commands that ran. Below the block: the findings left open, each with file, line, and the reason. Nothing else.
