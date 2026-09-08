#!/usr/bin/env bash
# /test-audit over a suite with a tautological test, a mock-call test, a framework test, and a test that
# asserts a type instead of a value, plus a seam (applyCoupon) with no real coverage. Passes only when
# the trash tests are gone, the seam is covered, the suite is green, and the suite kills three mutants.
set -uo pipefail
f=src/cart.test.ts
fail=0

node --test "src/**/*.test.ts" >/dev/null 2>&1 || { echo "suite failed"; fail=1; }

grep -q 'reduce(' "$f" && { echo "tautological test survived"; fail=1; }
grep -Eq 'calls|spy' "$f" && { echo "mock-call test survived"; fail=1; }
grep -q 'assert.ok(true)' "$f" && { echo "framework test survived"; fail=1; }
grep -q 'typeof applyCoupon' "$f" && { echo "type-only assertion survived"; fail=1; }
grep -q 'applyCoupon(' "$f" || { echo "applyCoupon has no test"; fail=1; }

[ -z "$(git status --porcelain | grep -v '\.test\.ts$' | grep -v '^?? src/.*\.test\.ts$')" ] || { echo "production code or other files changed"; git status --short; fail=1; }
ls src/*.probe >/dev/null 2>&1 && { echo "probe file left behind"; fail=1; }

probe() {
  local from="$1" to="$2" label="$3"
  cp src/cart.ts src/cart.ts.bak
  python - "$from" "$to" <<'EOF'
import io, sys
p = "src/cart.ts"
s = io.open(p, encoding="utf-8").read()
assert sys.argv[1] in s, sys.argv[1]
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(sys.argv[1], sys.argv[2], 1))
EOF
  if node --test "src/**/*.test.ts" >/dev/null 2>&1; then echo "mutant survived: $label"; fail=1; fi
  mv src/cart.ts.bak src/cart.ts
}
probe 'total * 0.5' 'total * 0.6' 'HALF gives 60% instead of 50%'
probe 'Math.max(0, total - 10)' 'total - 10' 'TEN goes below zero'
probe 'total += item.price * item.qty' 'total += item.price' 'quantity ignored'

exit $fail
