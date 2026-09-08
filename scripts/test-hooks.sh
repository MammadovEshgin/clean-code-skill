#!/usr/bin/env bash
# Tests for the three hook templates: command variants, working directory, missing tooling,
# red and green checks, the bounded stop block. Run from anywhere; needs bash and git.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/skills/clean-code-setup/templates"
fail=0
pass=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=1; }
expect() { # expect <exit> <label> <command...>
  local want="$1" label="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then ok; else bad "$label (exit $got, wanted $want)"; fi
}
payload() {
  local c="$1"
  c="${c//\\/\\\\}"
  c="${c//\"/\\\"}"
  c="${c//$'\n'/\\n}"
  printf '{"session_id":"t1","tool_input":{"command":"%s"}}' "$c"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/hooks-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work"

# A repo whose check is red, and a nested repo whose check is green and records where it ran.
red="$work/red"; mkdir -p "$red"; (cd "$red" && git init -q && printf '{"name":"red","scripts":{"check":"exit 1"}}' > package.json)
green="$work/green"; mkdir -p "$green"; (cd "$green" && git init -q && printf '{"name":"green","scripts":{"check":"pwd > ran-in.txt"}}' > package.json)
none="$work/none"; mkdir -p "$none"; (cd "$none" && git init -q)

gate() { (cd "$1" && bash "$T/commit-gate.sh"); }
export T
export -f payload gate

# commit-gate: every way of spelling a commit is caught when the check is red
for c in 'git commit -m x' '  git commit -m x' 'git --no-pager commit -m x' 'git -c user.name=a commit -m x' \
         'git --git-dir=.git commit -m x' 'npm test && git commit -m x' 'git add -A; git commit -q -m x' \
         "sh -c 'git commit -m x'" 'bash -lc "git add . && git commit -m \"x y\""' $'git add .\ngit commit -m x'; do
  expect 2 "commit-gate blocks: $c" bash -c 'payload "$1" | gate "$2"' _ "$c" "$red"
done
# commit-gate: non-commits and other git subcommands pass through
for c in 'ls' 'git status' 'git log --oneline' 'git commit-tree HEAD^{tree}' 'echo commit' 'npm test'; do
  expect 0 "commit-gate ignores: $c" bash -c 'payload "$1" | gate "$2"' _ "$c" "$red"
done
# commit-gate: -C runs the check in that repository, not in the cwd
rm -f "$green/ran-in.txt"
expect 0 "commit-gate -C green from red" bash -c 'payload "$1" | gate "$2"' _ "git -C $green commit -m x" "$red"
if [ -f "$green/ran-in.txt" ] && grep -q "green" "$green/ran-in.txt"; then ok; else bad "commit-gate did not run the check inside the -C directory"; fi
# commit-gate: no check command means no opinion
expect 0 "commit-gate with no check command" bash -c 'payload "$1" | gate "$2"' _ "git commit -m x" "$none"
# commit-gate: green check passes
expect 0 "commit-gate green" bash -c 'payload "$1" | gate "$2"' _ "git commit -m x" "$green"
# commit-gate: empty payload
expect 0 "commit-gate empty payload" bash -c 'printf "{}" | gate "$1"' _ "$red"

# format-and-lint: unknown extension and missing tools never block; the edit marker is written
touch "$green/file.xyz"
expect 0 "format-and-lint unknown extension" bash -c 'cd "$1" && printf "{\"session_id\":\"s1\",\"tool_input\":{\"file_path\":\"file.xyz\"}}" | bash "$2/format-and-lint.sh"' _ "$green" "$T"
[ -f "$work/clean-code-s1.edited" ] && ok || bad "format-and-lint did not write the edit marker"
expect 0 "format-and-lint missing file" bash -c 'cd "$1" && printf "{\"tool_input\":{\"file_path\":\"nope.ts\"}}" | bash "$2/format-and-lint.sh"' _ "$green" "$T"

# check-on-stop: a copy with a red fast check, and one with a green fast check
sed 's/^FAST_CHECK="__FAST_CHECK__"/FAST_CHECK="exit 1"/' "$T/check-on-stop.sh" > "$work/stop-red.sh"
sed 's/^FAST_CHECK="__FAST_CHECK__"/FAST_CHECK="true"/' "$T/check-on-stop.sh" > "$work/stop-green.sh"
stop() { (cd "$1" && printf '%s' "$2" | bash "$3"); }
export -f stop
(cd "$red" && echo x > dirty.txt)
# no marker: nothing runs
rm -f "$work/clean-code-s2.edited" "$work/clean-code-s2.stopblocks"
expect 0 "stop without marker" stop "$red" '{"session_id":"s2","stop_hook_active":false}' "$work/stop-red.sh"
# marker + dirty tree + red gates: blocked, three times, then released with a message
touch "$work/clean-code-s2.edited"
expect 2 "stop red blocks (1)" stop "$red" '{"session_id":"s2","stop_hook_active":false}' "$work/stop-red.sh"
expect 2 "stop red blocks (2)" stop "$red" '{"session_id":"s2","stop_hook_active":true}' "$work/stop-red.sh"
expect 2 "stop red blocks (3)" stop "$red" '{"session_id":"s2","stop_hook_active":true}' "$work/stop-red.sh"
out="$(cd "$red" && printf '%s' '{"session_id":"s2","stop_hook_active":true}' | bash "$work/stop-red.sh")"; code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q systemMessage; then ok; else bad "stop did not release after $((3)) blocks (exit $code)"; fi
[ -f "$work/clean-code-s2.stopblocks" ] && bad "stop counter not cleared on release" || ok
# marker + dirty tree + green gates: passes and clears the marker
touch "$work/clean-code-s3.edited"
expect 0 "stop green" stop "$red" '{"session_id":"s3","stop_hook_active":false}' "$work/stop-green.sh"
[ -f "$work/clean-code-s3.edited" ] && bad "stop green did not clear the marker" || ok
# marker + clean tree: passes without running gates
touch "$work/clean-code-s4.edited"
expect 0 "stop clean tree" stop "$none" '{"session_id":"s4","stop_hook_active":false}' "$work/stop-red.sh"

echo "hooks: $pass checks passed$( [ "$fail" -ne 0 ] && echo ', with failures')"
exit $fail
