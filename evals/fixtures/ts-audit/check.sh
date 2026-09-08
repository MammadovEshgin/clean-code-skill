#!/usr/bin/env bash
# /audit over a file with a SQL injection and an off-by-one. Passes only when both are fixed,
# each fix has a test the agent added, the existing tests still pass, and nothing was committed.
set -uo pipefail
fail=0

node --test "src/**/*.test.ts" >/dev/null 2>&1 || { echo "test suite failed"; fail=1; }

if grep -Eq "' \+ name|\\\$\{name\}|name \+ \"'" src/users.ts; then echo "SQL is still built from the name"; fail=1; fi
grep -Eq 'query\([^)]*,\s*\[' src/users.ts || { echo "query is not parameterized"; fail=1; }

cat > src/zz-check.test.ts <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { findUserByName, pageOf } from "./users.ts";

test("pageOf returns whole pages", () => {
  assert.deepEqual(pageOf([1, 2, 3, 4], 0, 2), [1, 2]);
  assert.deepEqual(pageOf([1, 2, 3, 4], 1, 2), [3, 4]);
  assert.deepEqual(pageOf([1, 2, 3], 1, 2), [3]);
});

test("findUserByName passes the name as a parameter", async () => {
  const calls: { sql: string; params?: unknown[] }[] = [];
  const db = { async query(sql: string, params?: unknown[]) { calls.push({ sql, params }); return []; } };
  await findUserByName(db, "x' OR '1'='1");
  assert.equal(calls.length, 1);
  assert.ok(!calls[0].sql.includes("'1'='1"), "the payload reached the SQL text");
  assert.ok(calls[0].params && calls[0].params.includes("x' OR '1'='1"), "the payload was not passed as a parameter");
});
EOF
node --test src/zz-check.test.ts >/dev/null 2>&1 || { echo "behaviour check failed (page boundary or parameterization)"; fail=1; }
rm -f src/zz-check.test.ts

# Red first, mechanically: the suite as it now stands must fail against the pre-fix production code.
cp src/users.ts src/users.ts.fix && git show HEAD:src/users.ts > src/users.ts
if node --test "src/**/*.test.ts" >/dev/null 2>&1; then echo "the tests pass on the pre-fix code: the fixes are unproven"; fail=1; fi
mv -f src/users.ts.fix src/users.ts

tests=$(grep -ch '^test(' src/*.test.ts | awk '{s+=$1} END {print s+0}')
[ "$tests" -ge 4 ] || { echo "expected at least 4 tests after the audit (2 existing + a regression test per fix), found $tests"; fail=1; }
grep -Elq 'pageOf' src/*.test.ts || { echo "no test covers pageOf"; fail=1; }

[ "$(git rev-list --count HEAD)" -eq 1 ] || { echo "the audit committed"; fail=1; }
[ -n "$(git status --porcelain)" ] || { echo "nothing changed"; fail=1; }
[ -z "$(git status --porcelain | grep -v 'src/')" ] || { echo "files changed outside src/"; git status --short; fail=1; }

exit $fail
