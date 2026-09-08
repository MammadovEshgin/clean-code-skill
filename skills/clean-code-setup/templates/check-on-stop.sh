#!/usr/bin/env bash
# Claude Code Stop hook: when this session edited files, run the fast gates (lint and typecheck)
# before the agent stops. Red output goes to stderr with exit 2, so the agent keeps working
# until the gates are green. stop_hook_active guards against a loop.
#
# /clean-code-setup fills FAST_CHECK with the repo's fast gate command. Left as the placeholder,
# the script detects the stack and runs the usual commands.

FAST_CHECK="__FAST_CHECK__"

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"
  session="$(printf '%s' "$input" | jq -r '.session_id // empty')"
else
  if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then active=true; else active=false; fi
  session="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ "$active" = "true" ] && exit 0

marker="${TMPDIR:-/tmp}/clean-code-${session:-none}.edited"
[ -f "$marker" ] || exit 0
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then rm -f "$marker"; exit 0; fi

run_gates() {
  if [ -n "$FAST_CHECK" ] && [ "$FAST_CHECK" != "__FAST_CHECK__" ]; then
    bash -c "$FAST_CHECK"
    return
  fi
  local status=0
  if [ -f package.json ]; then
    if [ -f biome.json ] || [ -f biome.jsonc ]; then
      npx --no-install biome lint . || status=1
    else
      npx --no-install eslint . || status=1
    fi
    if [ -f tsconfig.json ]; then npx --no-install tsc --noEmit -p tsconfig.json || status=1; fi
  fi
  if [ -f pyproject.toml ] || ls requirements*.txt >/dev/null 2>&1; then
    ruff check . || python -m ruff check . || status=1
    if command -v mypy >/dev/null 2>&1; then mypy . || status=1; fi
  fi
  if [ -f go.mod ]; then go vet ./... || status=1; fi
  if [ -f Cargo.toml ]; then cargo check -q || status=1; cargo clippy -q --no-deps || status=1; fi
  return $status
}

out="$(run_gates 2>&1)"
if [ $? -ne 0 ]; then
  {
    echo "clean-code: the fast gates are red. Fix these before stopping:"
    printf '%s\n' "$out" | grep -v '^$' | tail -60
  } >&2
  exit 2
fi
rm -f "$marker"
exit 0
