#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before the agent runs `git commit`, run the repo's check
# command. Red blocks the commit (exit 2) and shows the failures, so the agent commits nothing red.
#
# This is development feedback for the agent's own commits through the Bash tool. It does not see
# commits made from a shell or by CI; the CI check is the merge gate.
#
# /clean-code-setup fills CHECK_COMMAND. Left as the placeholder, the script looks for a `check`
# script in package.json, a Makefile target, or a justfile recipe, and does nothing when none exists.

CHECK_COMMAND="__CHECK_COMMAND__"

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)"
  cmd="${cmd//\\\"/\"}"
  cmd="${cmd//\\n/ }"
fi
[ -n "$cmd" ] || exit 0

# Find `git [global options] commit` anywhere in the command: after chaining operators, inside
# quotes, inside `sh -c '...'`. Global options that take a value are skipped with their value.
norm="$(printf '%s' "$cmd" | tr '\n\t;|&(){}' '           ' | sed "s/[\"'\`]/ /g")"
read -ra words <<< "$norm"
count=${#words[@]}
is_commit=0
repo_dir=""
i=0
while [ "$i" -lt "$count" ]; do
  if [ "${words[$i]}" = "git" ]; then
    j=$((i + 1))
    dir=""
    while [ "$j" -lt "$count" ]; do
      case "${words[$j]}" in
        -C) dir="${words[$((j + 1))]:-}"; j=$((j + 2)) ;;
        -c|--git-dir|--work-tree|--namespace|--exec-path|--config-env) j=$((j + 2)) ;;
        -*) j=$((j + 1)) ;;
        *) break ;;
      esac
    done
    if [ "$j" -lt "$count" ] && [ "${words[$j]}" = "commit" ]; then
      is_commit=1
      repo_dir="$dir"
      break
    fi
  fi
  i=$((i + 1))
done
[ "$is_commit" -eq 1 ] || exit 0

if [ -n "$repo_dir" ]; then
  cd "$repo_dir" 2>/dev/null || exit 0
fi

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
    echo "clean-code: '$CHECK_COMMAND' is red in $(pwd); the commit is blocked until it passes:"
    printf '%s\n' "$out" | grep -v '^$' | tail -60
  } >&2
  exit 2
fi
exit 0
