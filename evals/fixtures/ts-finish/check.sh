#!/usr/bin/env bash
# /finish HEAD~1 on a branch whose last commit added src/pricing.ts with slop.
# Passes only when behaviour holds, the planted slop is gone, and nothing was committed on the user's behalf.
set -uo pipefail
f=src/pricing.ts
fail=0

node --test src/pricing.test.ts >/dev/null 2>&1 || { echo "behaviour test failed"; fail=1; }

for pattern in 'console\.log' '// ={3,}' 'TODO' '^[[:space:]]*// (const|return) ' 'catch \(' 'getPriceFromItem' '!== null'; do
  if grep -Eq "$pattern" "$f"; then echo "slop survived: $pattern"; fail=1; fi
done

lines=$(wc -l < "$f")
[ "$lines" -le 16 ] || { echo "file still $lines lines (limit 16)"; fail=1; }

commits=$(git rev-list --count HEAD)
[ "$commits" -eq 2 ] || { echo "expected 2 commits (no --commit was passed), found $commits"; fail=1; }
git diff --quiet HEAD -- "$f" && { echo "working tree has no change to $f"; fail=1; }

exit $fail
