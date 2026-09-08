#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before the agent runs `git commit`, run the repo's check
# command. Red blocks the commit (exit 2) and shows the failures, so nothing red is committed.
#
# /clean-code-setup fills CHECK_COMMAND. Left as the placeholder, the script looks for a `check`
# script in package.json, a Makefile target, or a justfile recipe, and does nothing when none exists.

CHECK_COMMAND="__CHECK_COMMAND__"

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)"
fi
printf '%s' "$cmd" | grep -Eq '(^|[;&|][[:space:]]*)git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)' || exit 0

if [ -z "$CHECK_COMMAND" ] || [ "$CHECK_COMMAND" = "__CHECK_COMMAND__" ]; then
  if [ -f package.json ] && grep -q '"check"[[:space:]]*:' package.json; then
    CHECK_COMMAND="npm run check"
  elif [ -f Makefile ] && grep -Eq '^check:' Makefile; then
    CHECK_COMMAND="make check"
  elif [ -f justfile ] && grep -Eq '^check' justfile; then
    CHECK_COMMAND="just check"
  else
    exit 0
  fi
fi

out="$(bash -c "$CHECK_COMMAND" 2>&1)"
if [ $? -ne 0 ]; then
  {
    echo "clean-code: '$CHECK_COMMAND' is red; the commit is blocked until it passes:"
    printf '%s\n' "$out" | grep -v '^$' | tail -60
  } >&2
  exit 2
fi
exit 0
