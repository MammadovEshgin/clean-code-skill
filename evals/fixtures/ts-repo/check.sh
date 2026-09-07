#!/usr/bin/env bash
# /deslop repo over two modules. Passes only when behaviour holds in both, the planted slop is gone
# from both, each module landed in its own commit, the plan file is gone, and the tree is clean.
set -uo pipefail
fail=0

node --test src/pricing/pricing.test.ts src/orders/orders.test.ts >/dev/null 2>&1 || { echo "behaviour test failed"; fail=1; }

for pattern in 'console\.log' '// ={3,}' 'TODO' '^[[:space:]]*// (const|return) ' 'catch \(' 'getPriceFromItem' '!== null'; do
  if grep -Eq "$pattern" src/pricing/pricing.ts; then echo "pricing: slop survived: $pattern"; fail=1; fi
done
for pattern in 'console\.log' '// ={3,}' 'TODO' '^[[:space:]]*// (const|return) ' 'catch \(' 'getItemQuantity' '=== null' '@ts-ignore'; do
  if grep -Eq "$pattern" src/orders/orders.ts; then echo "orders: slop survived: $pattern"; fail=1; fi
done

p=$(wc -l < src/pricing/pricing.ts); [ "$p" -le 16 ] || { echo "pricing.ts still $p lines (limit 16)"; fail=1; }
o=$(wc -l < src/orders/orders.ts);   [ "$o" -le 16 ] || { echo "orders.ts still $o lines (limit 16)"; fail=1; }

[ -z "$(git status --porcelain)" ] || { echo "working tree not clean"; git status --short; fail=1; }
[ ! -e .deslop ] || { echo ".deslop/ still present"; fail=1; }

base=$(git rev-list --max-parents=0 HEAD)
touched_pricing=0; touched_orders=0
for c in $(git rev-list HEAD ^"$base"); do
  files=$(git show --pretty= --name-only "$c")
  tp=$(printf '%s\n' "$files" | grep -c '^src/pricing/'); to=$(printf '%s\n' "$files" | grep -c '^src/orders/')
  [ "$tp" -gt 0 ] && touched_pricing=1
  [ "$to" -gt 0 ] && touched_orders=1
  if [ "$tp" -gt 0 ] && [ "$to" -gt 0 ]; then echo "commit $c touches both slices"; fail=1; fi
done
[ "$touched_pricing" -eq 1 ] || { echo "no commit touches src/pricing"; fail=1; }
[ "$touched_orders" -eq 1 ] || { echo "no commit touches src/orders"; fail=1; }
echo "commits: $(git rev-list --count HEAD) · branch: $(git branch --show-current)"

exit $fail
