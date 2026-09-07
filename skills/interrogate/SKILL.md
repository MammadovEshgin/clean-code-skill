---
name: interrogate
description: Challenge a finished change from first principles before calling it done. Delete, then simplify, then stop. Target is a path or git range; default is the uncommitted diff.
disable-model-invocation: true
argument-hint: [path | git-range]
---

# Interrogate

Think from first principles about what the change is trying to achieve, then interrogate what was built before calling it done.

Target: `$ARGUMENTS`. Empty means the uncommitted diff (`git diff HEAD`); a ref means the diff since its merge-base.

## Questions

Answer each in writing, against the actual diff, before touching anything.

1. **What is this change for?** One sentence, from the user's point of view, without reference to the implementation.
2. **What is unnecessary, over-complicated, or resting on a weak assumption?** Challenge each assumption: is it true, and is it needed?
3. **What can be deleted entirely?** Files, functions, parameters, options, branches, tests, comments. Apply the deletion test: would removing it lose behaviour or information the user asked for?
4. **What becomes simpler once the deleted pieces are gone?** A helper with two callers may now have one; a parameter may now have one value; a layer may now only forward.

## Order of preference

Deleting over simplifying. Simplifying over optimizing. Optimizing over automating.

A cut lower on this list is only considered after the cuts above it are exhausted.

## Act

- Make the cuts, smallest edit first. Keep each cut independently reviewable.
- Run typecheck and the focused tests after the cuts; run the full suite once at the end.
- A cut that changes observable behaviour is reverted and reported.
- It might already be done. There is no obligation to change anything: when the answers to the questions are "nothing", say so and leave the change alone.

## Report

```
## Interrogation
Target    <range> · <N files>
Purpose   <one sentence>
Deleted   <list: what and why, or "nothing">
Simplified <list, or "nothing">
Diff      +<added> / -<removed> lines · net <±n>   (scripts/diff-stats.sh in the clean-code skill folder)
Gates     typecheck <pass|fail> · tests <passed>/<total>
Verdict   <done | done after cuts | needs decision: ...>
```

Under ten lines. No cut is listed without the verification that followed it.
