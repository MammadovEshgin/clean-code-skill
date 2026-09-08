#!/usr/bin/env bash
# Tests for skills/deslop/scripts/slice.sh: snapshot, confine (ownership and scope), red-check.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/skills/deslop/scripts/slice.sh"
fail=0; pass=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=1; }
g() { git -c user.name=t -c user.email=t@t -c core.safecrlf=false "$@"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/slice-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cd "$work" && g init -q -b main
mkdir -p a b d src
echo one > a/x.txt; echo two > b/y.txt; echo four > d/z.txt
cat > src/f.js <<'EOF'
export function half(n) { return n / 2; }
EOF
g add -A && g commit -qm base

# Someone else's change exists before the worker starts.
echo "theirs" > d/z.txt
bash "$S" snapshot >/dev/null
# The worker edits inside the slice, outside it, adds an untracked file outside, and writes the plan.
echo "mine" > a/x.txt
echo "drift" > b/y.txt
mkdir -p c && echo new > c/new.txt
mkdir -p .deslop && echo plan > .deslop/plan.md
echo staged > b/staged.txt && g add b/staged.txt

out="$(bash "$S" confine a)"
[ "$(cat a/x.txt)" = "mine" ] && ok || bad "confine reverted the slice's own change"
[ "$(cat b/y.txt)" = "two" ] && ok || bad "confine kept a change outside the slice"
[ ! -e c/new.txt ] && ok || bad "confine kept an untracked file outside the slice"
[ ! -e b/staged.txt ] && ok || bad "confine kept a staged new file outside the slice"
[ "$(cat d/z.txt)" = "theirs" ] && ok || bad "confine reverted a change that existed at snapshot"
[ -f .deslop/plan.md ] && ok || bad "confine removed .deslop/"
printf '%s\n' "$out" | grep -q "3 path(s) reverted" && ok || bad "confine count wrong: $out"

# red-check: a fix whose test goes red on the old code is proven; one whose test passes is not.
g checkout -q -- . && rm -rf c .deslop && g add -A && g commit -qm clean >/dev/null 2>&1
cat > src/f.js <<'EOF'
export function half(n) { return Math.floor(n / 2); }
EOF
cat > src/f.test.mjs <<'EOF'
import { half } from "./f.js";
if (half(3) !== 1) { console.error("expected 1"); process.exit(1); }
EOF
bash "$S" red-check "node src/f.test.mjs" src/f.js >/dev/null && ok || bad "red-check did not recognise a proven fix"
grep -q "Math.floor" src/f.js && ok || bad "red-check did not restore the fix"
cat > src/f.test.mjs <<'EOF'
import { half } from "./f.js";
if (half(4) !== 2) process.exit(1);
EOF
bash "$S" red-check "node src/f.test.mjs" src/f.js >/dev/null && bad "red-check accepted an unproven fix" || ok
grep -q "Math.floor" src/f.js && ok || bad "red-check did not restore the fix after an unproven check"
[ -z "$(ls src/*.fix 2>/dev/null)" ] && ok || bad "red-check left backup files"
# a brand-new production file counts as absent on the pre-fix code
echo "export const k = 1;" > src/g.js
cat > src/g.test.mjs <<'EOF'
import { k } from "./g.js";
if (k !== 1) process.exit(1);
EOF
bash "$S" red-check "node src/g.test.mjs" src/g.js >/dev/null && ok || bad "red-check did not treat a new file as absent"
[ -f src/g.js ] && ok || bad "red-check did not restore a new file"

echo "slice: $pass checks passed$( [ "$fail" -ne 0 ] && echo ', with failures')"
exit $fail
