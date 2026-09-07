#!/usr/bin/env bash
# Passes only when behaviour holds and the planted slop is gone.
set -uo pipefail
f=orders.py
fail=0

py() { if command -v python >/dev/null 2>&1; then python "$@"; else python3 "$@"; fi; }
py -m unittest -q test_orders >/dev/null 2>&1 || { echo "behaviour test failed"; fail=1; }

for pattern in 'print\(' '# ={3,}' 'TODO' '^[[:space:]]*# (old_total|return old)' 'except Exception' '_get_price' 'is None' 'type: ignore'; do
  if grep -Eq "$pattern" "$f"; then echo "slop survived: $pattern"; fail=1; fi
done

lines=$(wc -l < "$f")
[ "$lines" -le 14 ] || { echo "file still $lines lines (limit 14)"; fail=1; }

exit $fail
