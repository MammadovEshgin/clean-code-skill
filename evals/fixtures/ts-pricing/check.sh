#!/usr/bin/env bash
# Passes only when behaviour holds and the planted slop is gone.
set -uo pipefail
f=src/pricing.ts
fail=0

node --test src/pricing.test.ts >/dev/null 2>&1 || { echo "behaviour test failed"; fail=1; }

for pattern in 'console\.log' '// ={3,}' 'TODO' '^[[:space:]]*// (const|return) ' 'catch \(' 'getPriceFromItem' '!== null'; do
  if grep -Eq "$pattern" "$f"; then echo "slop survived: $pattern"; fail=1; fi
done

lines=$(wc -l < "$f")
[ "$lines" -le 16 ] || { echo "file still $lines lines (limit 16)"; fail=1; }

exit $fail
