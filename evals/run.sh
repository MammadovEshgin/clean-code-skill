#!/usr/bin/env bash
# Run the skills against slop fixtures with a real agent and check the result.
#
# Usage:
#   evals/run.sh                    every fixture under evals/fixtures
#   evals/run.sh ts-pricing         one fixture
#   evals/run.sh --keep             keep the temporary workspaces for inspection
#
# Each fixture is a small project with slop in it, a behaviour test, an `entry` file naming the
# scope to pass to /deslop, and a `check.sh` that passes only when behaviour is intact and the
# slop is gone. The harness copies the fixture into a fresh git repo, installs the skills from
# this checkout, runs `claude -p "/deslop <entry>"`, then runs the fixture's check.
#
# Requires: claude (Claude Code CLI), git, bash. Fixtures may also need node or python.
# Each run costs real tokens and a few minutes.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
keep=0
selected=()
for arg in "$@"; do
  case "$arg" in
    --keep) keep=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) selected+=("$arg") ;;
  esac
done

if ! command -v claude >/dev/null 2>&1; then
  echo "evals: claude CLI not found" >&2
  exit 1
fi

if [ "${#selected[@]}" -eq 0 ]; then
  for d in "$REPO"/evals/fixtures/*/; do selected+=("$(basename "$d")"); done
fi

passed=0
total=0
for name in "${selected[@]}"; do
  fixture="$REPO/evals/fixtures/$name"
  if [ ! -f "$fixture/entry" ] || [ ! -f "$fixture/check.sh" ]; then
    echo "SKIP  $name (needs entry and check.sh)"
    continue
  fi
  total=$((total + 1))
  entry="$(tr -d '\r\n' < "$fixture/entry")"
  ws="$(mktemp -d "${TMPDIR:-/tmp}/clean-code-eval-$name.XXXXXX")"

  cp -R "$fixture"/. "$ws"/
  rm -f "$ws/entry" "$ws/check.sh"
  mkdir -p "$ws/.claude/skills"
  for skill in "$REPO"/skills/*/; do cp -R "${skill%/}" "$ws/.claude/skills/"; done

  (
    cd "$ws" || exit 1
    git init -q -b main
    git -c user.name=eval -c user.email=eval@example.com add -A
    git -c user.name=eval -c user.email=eval@example.com commit -qm "fixture baseline"
    start=$(date +%s)
    claude -p "/deslop $entry" --output-format text --permission-mode acceptEdits \
      --allowedTools "Read,Edit,Write,Bash,Glob,Grep" > agent-output.txt 2>&1 < /dev/null
    echo $(( $(date +%s) - start )) > elapsed.txt
  )

  if (cd "$ws" && bash "$fixture/check.sh" > check-output.txt 2>&1); then
    verdict="PASS"; passed=$((passed + 1))
  else
    verdict="FAIL"
  fi

  stats="$(cd "$ws" && bash "$REPO/skills/clean-code/scripts/diff-stats.sh" 2>/dev/null | sed -n '3,6p' | tr '\n' ' ' | tr -s ' ')"
  printf '%s  %-14s %ss  %s\n' "$verdict" "$name" "$(cat "$ws/elapsed.txt" 2>/dev/null || echo '?')" "$stats"
  if [ "$verdict" = "FAIL" ]; then
    sed 's/^/      /' "$ws/check-output.txt" | head -20
  fi
  if [ "$keep" -eq 1 ]; then
    echo "      workspace: $ws"
  else
    rm -rf "$ws"
  fi
done

echo "evals: $passed/$total passed"
[ "$passed" -eq "$total" ]
