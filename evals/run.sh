#!/usr/bin/env bash
# Run the skills against slop fixtures with a real agent and check the result.
#
# Usage:
#   evals/run.sh                    every fixture under evals/fixtures
#   evals/run.sh ts-pricing         one fixture
#   evals/run.sh --keep             keep the workspaces; agent-output.txt lands in <workspace>.meta/
#
# Each fixture is a small project with slop in it, a behaviour test, and a `check.sh` that passes
# only when behaviour is intact and the slop is gone. The prompt comes from `command` (the full
# skill invocation, `<entry>` replaced by the contents of `entry`) or defaults to `/deslop <entry>`.
# Files listed in `base` go into a first commit; everything else into a second one, so a fixture
# can present the slop as the branch's last commit. The harness copies the fixture into a fresh git
# repo, installs the skills from this checkout, runs `claude -p`, then runs the fixture's check.
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
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
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

git_eval() { git -c user.name=eval -c user.email=eval@example.com -c core.safecrlf=false "$@"; }

passed=0
total=0
for name in "${selected[@]}"; do
  fixture="$REPO/evals/fixtures/$name"
  if [ ! -f "$fixture/check.sh" ] || { [ ! -f "$fixture/entry" ] && [ ! -f "$fixture/command" ]; }; then
    echo "SKIP  $name (needs check.sh and entry or command)"
    continue
  fi
  total=$((total + 1))
  entry="$( [ -f "$fixture/entry" ] && tr -d '\r\n' < "$fixture/entry" || true)"
  if [ -f "$fixture/command" ]; then
    prompt="$(tr -d '\r\n' < "$fixture/command" | sed "s|<entry>|$entry|g")"
  else
    prompt="/deslop $entry"
  fi
  ws="$(mktemp -d "${TMPDIR:-/tmp}/clean-code-eval-$name.XXXXXX")"
  meta="$ws.meta"
  mkdir -p "$meta"

  cp -R "$fixture"/. "$ws"/
  rm -f "$ws/entry" "$ws/command" "$ws/base" "$ws/check.sh"
  mkdir -p "$ws/.claude/skills"
  for skill in "$REPO"/skills/*/; do cp -R "${skill%/}" "$ws/.claude/skills/"; done

  (
    cd "$ws" || exit 1
    git init -q -b main
    if [ -f "$fixture/base" ]; then
      base_files=()
      while IFS= read -r line; do [ -n "$line" ] && base_files+=("$line"); done < <(tr -d '\r' < "$fixture/base")
      git_eval add -- .claude "${base_files[@]}"
      git_eval commit -qm "fixture baseline"
      git_eval add -A
      git_eval commit -qm "add the change under test"
    else
      git_eval add -A
      git_eval commit -qm "fixture baseline"
    fi
    git rev-list --max-parents=0 HEAD > "$meta/baseline.txt"
    start=$(date +%s)
    claude -p "$prompt" --output-format text --permission-mode acceptEdits \
      --allowedTools "Read,Edit,Write,Bash,Glob,Grep,Agent" > "$meta/agent-output.txt" 2>&1 < /dev/null
    echo $(( $(date +%s) - start )) > "$meta/elapsed.txt"
  )

  if (cd "$ws" && bash "$fixture/check.sh" > "$meta/check-output.txt" 2>&1); then
    verdict="PASS"; passed=$((passed + 1))
  else
    verdict="FAIL"
  fi

  stats="$(cd "$ws" && bash "$REPO/skills/clean-code/scripts/diff-stats.sh" "$(cat "$meta/baseline.txt")" 2>/dev/null | sed -n '3,6p' | tr '\n' ' ' | tr -s ' ')"
  printf '%s  %-14s %ss  %s\n' "$verdict" "$name" "$(cat "$meta/elapsed.txt" 2>/dev/null || echo '?')" "$stats"
  if [ "$verdict" = "FAIL" ]; then
    sed 's/^/      /' "$meta/check-output.txt" | head -20
  fi
  if [ "$keep" -eq 1 ]; then
    echo "      workspace: $ws  (agent-output.txt and check-output.txt in $meta)"
  else
    rm -rf "$ws" "$meta"
  fi
done

echo "evals: $passed/$total passed"
[ "$passed" -eq "$total" ]
