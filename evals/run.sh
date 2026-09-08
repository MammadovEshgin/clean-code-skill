#!/usr/bin/env bash
# Run the skills against fixtures with a real agent and check the result mechanically.
#
# Usage:
#   evals/run.sh                    every fixture under evals/fixtures
#   evals/run.sh ts-pricing         one fixture
#   evals/run.sh --keep             keep the workspaces; agent-output.txt lands in <workspace>.meta/
#   evals/run.sh --baseline         no-skill arm: the same fixture, no skills installed, the plain-English
#                                   prompt from the fixture's `baseline` file (fixtures without one are skipped)
#   evals/run.sh --runs 3           repeat each fixture, to see variability
#
# Each fixture is a small project with a planted problem, a behaviour test, and a `check.sh` that passes
# only when behaviour is intact and the problem is gone. The prompt comes from `command` (the full skill
# invocation, `<entry>` replaced by the contents of `entry`) or defaults to `/deslop <entry>`. Files listed
# in `base` go into a first commit; everything else into a second one, so a fixture can present the
# problem as the branch's last commit. The harness copies the fixture into a fresh git repo, installs
# the skills from this checkout (not in the baseline arm), runs `claude -p` with JSON output so tokens,
# cost, and turns are recorded, then runs the fixture's check. Every run appends one line to
# evals/results/log.tsv with the Claude Code version, so results are dated and reproducible.
#
# Requires: claude (Claude Code CLI), git, bash, node. Fixtures may also need python.
# Each run costs real tokens and minutes.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
keep=0
baseline=0
runs=1
selected=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep) keep=1 ;;
    --baseline) baseline=1 ;;
    --runs) shift; runs="${1:-1}" ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) selected+=("$1") ;;
  esac
  shift
done

for tool in claude git node; do
  command -v "$tool" >/dev/null 2>&1 || { echo "evals: $tool not found" >&2; exit 1; }
done

if [ "${#selected[@]}" -eq 0 ]; then
  for d in "$REPO"/evals/fixtures/*/; do selected+=("$(basename "$d")"); done
fi

version="$(claude --version 2>/dev/null | head -1 | tr -d '\r')"
arm="skills"; [ "$baseline" -eq 1 ] && arm="baseline"
log="$REPO/evals/results/log.tsv"
mkdir -p "$(dirname "$log")"
[ -f "$log" ] || printf 'date\tclaude\tfixture\tarm\trun\tverdict\tseconds\tinput_tokens\toutput_tokens\tcost_usd\tturns\n' > "$log"
echo "evals: $version · arm $arm · $runs run(s) per fixture"

git_eval() { git -c user.name=eval -c user.email=eval@example.com -c core.safecrlf=false "$@"; }

passed=0
total=0
for name in "${selected[@]}"; do
  fixture="$REPO/evals/fixtures/$name"
  if [ ! -f "$fixture/check.sh" ] || { [ ! -f "$fixture/entry" ] && [ ! -f "$fixture/command" ]; }; then
    echo "SKIP  $name (needs check.sh and entry or command)"
    continue
  fi
  entry="$( [ -f "$fixture/entry" ] && tr -d '\r\n' < "$fixture/entry" || true)"
  if [ "$baseline" -eq 1 ]; then
    if [ ! -f "$fixture/baseline" ]; then echo "SKIP  $name (no baseline prompt)"; continue; fi
    prompt="$(tr -d '\r' < "$fixture/baseline" | sed "s|<entry>|$entry|g")"
  elif [ -f "$fixture/command" ]; then
    prompt="$(tr -d '\r\n' < "$fixture/command" | sed "s|<entry>|$entry|g")"
  else
    prompt="/deslop $entry"
  fi

  run=1
  while [ "$run" -le "$runs" ]; do
    total=$((total + 1))
    ws="$(mktemp -d "${TMPDIR:-/tmp}/clean-code-eval-$name.XXXXXX")"
    meta="$ws.meta"
    mkdir -p "$meta"

    cp -R "$fixture"/. "$ws"/
    rm -f "$ws/entry" "$ws/command" "$ws/base" "$ws/baseline" "$ws/check.sh"
    if [ "$baseline" -eq 0 ]; then
      mkdir -p "$ws/.claude/skills"
      for skill in "$REPO"/skills/*/; do cp -R "${skill%/}" "$ws/.claude/skills/"; done
    fi

    (
      cd "$ws" || exit 1
      git init -q -b main
      if [ -f "$fixture/base" ]; then
        base_files=()
        while IFS= read -r line; do [ -n "$line" ] && base_files+=("$line"); done < <(tr -d '\r' < "$fixture/base")
        [ -d .claude ] && git_eval add -- .claude
        git_eval add -- "${base_files[@]}"
        git_eval commit -qm "fixture baseline"
        git_eval add -A
        git_eval commit -qm "add the change under test"
      else
        git_eval add -A
        git_eval commit -qm "fixture baseline"
      fi
      git rev-list --max-parents=0 HEAD > "$meta/baseline.txt"
      printf '%s\n' "$prompt" > "$meta/prompt.txt"
      start=$(date +%s)
      claude -p "$prompt" --output-format json --permission-mode acceptEdits \
        --allowedTools "Read,Edit,Write,Bash,Glob,Grep,Agent" > "$meta/agent.json" 2> "$meta/agent-stderr.txt" < /dev/null
      echo $(( $(date +%s) - start )) > "$meta/elapsed.txt"
    )

    usage="$(node -e '
      const fs = require("fs");
      let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch { process.exit(1); }
      fs.writeFileSync(process.argv[2], (j.result || "") + "\n");
      const u = j.usage || {};
      const input = (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
      console.log([input, u.output_tokens || 0, j.total_cost_usd == null ? "" : j.total_cost_usd, j.num_turns || ""].join("\t"));
    ' "$meta/agent.json" "$meta/agent-output.txt" 2>/dev/null)" || { cp "$meta/agent.json" "$meta/agent-output.txt"; usage=$'\t\t\t'; }
    IFS=$'\t' read -r in_tok out_tok cost turns <<< "$usage"

    if (cd "$ws" && bash "$fixture/check.sh" > "$meta/check-output.txt" 2>&1); then
      verdict="PASS"; passed=$((passed + 1))
    else
      verdict="FAIL"
    fi
    elapsed="$(cat "$meta/elapsed.txt" 2>/dev/null || echo '?')"

    stats="$(cd "$ws" && bash "$REPO/skills/clean-code/scripts/diff-stats.sh" "$(cat "$meta/baseline.txt")" 2>/dev/null | sed -n '3,6p' | tr '\n' ' ' | tr -s ' ')"
    printf '%s  %-14s %-8s run %s  %4ss  in %s / out %s tokens  $%s  %s\n' "$verdict" "$name" "$arm" "$run" "$elapsed" "${in_tok:-?}" "${out_tok:-?}" "${cost:-?}" "$stats"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$version" "$name" "$arm" "$run" "$verdict" "$elapsed" "${in_tok:-}" "${out_tok:-}" "${cost:-}" "${turns:-}" >> "$log"
    if [ "$verdict" = "FAIL" ]; then
      sed 's/^/      /' "$meta/check-output.txt" | head -20
      grep -v '^$' "$meta/agent-stderr.txt" 2>/dev/null | tail -3 | sed 's/^/      stderr: /'
    fi
    if [ "$keep" -eq 1 ]; then
      echo "      workspace: $ws  (agent-output.txt and check-output.txt in $meta)"
    else
      rm -rf "$ws" "$meta"
    fi
    run=$((run + 1))
  done
done

echo "evals: $passed/$total passed ($arm arm, $version)"
[ "$passed" -eq "$total" ]
