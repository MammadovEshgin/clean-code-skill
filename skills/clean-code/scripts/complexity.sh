#!/usr/bin/env bash
# Per-function cyclomatic complexity snapshot for the Clean Code Report.
#
# Usage:
#   scripts/complexity.sh [path ...]        default: the current directory
#   CLEAN_CODE_COMPLEXITY=15 scripts/complexity.sh src   change the budget (default 10)
#
# Uses the tools the repo already has: ESLint (via the repo's own config) for JavaScript and
# TypeScript, Ruff for Python, gocyclo for Go. Prints the function count, the maximum, how many
# functions exceed the budget, the erosion (share of complexity that sits in over-budget functions,
# after SlopCodeBench's structural-erosion metric), and the top hotspots. Prints n/a when no tool
# applies, never a guess.
set -uo pipefail

paths=("$@")
[ "${#paths[@]}" -eq 0 ] && paths=(.)
budget="${CLEAN_CODE_COMPLEXITY:-10}"
rows=""

have() { command -v "$1" >/dev/null 2>&1; }
py() { if have python; then python "$@"; elif have python3; then python3 "$@"; else return 1; fi; }

# JavaScript / TypeScript through the repo's ESLint configuration, with complexity forced to report every function.
if [ -f package.json ] && have npx && have node; then
  out="$(npx --no-install eslint --format json --rule 'complexity: [1, 0]' "${paths[@]}" 2>/dev/null || true)"
  if [ -n "$out" ]; then
    parsed="$(printf '%s' "$out" | node -e '
      const path = require("path");
      let s = "";
      process.stdin.on("data", d => s += d).on("end", () => {
        let files; try { files = JSON.parse(s); } catch { return; }
        for (const f of files) for (const m of f.messages || []) {
          if (m.ruleId !== "complexity") continue;
          const cc = /has a complexity of (\d+)/.exec(m.message || "");
          if (!cc) continue;
          const name = (m.message.split(" has a complexity")[0] || "function").replace(/^(Async |Static )?/, "");
          const where = path.relative(process.cwd(), f.filePath).split(path.sep).join("/") + ":" + m.line;
          console.log(cc[1] + "\t" + where + "\t" + name);
        }
      });' 2>/dev/null)"
    [ -n "$parsed" ] && rows+="$parsed"$'\n'
  fi
fi

# Python through Ruff's mccabe check, threshold 0 so every function is reported.
ruff_cmd=()
if have ruff; then ruff_cmd=(ruff); elif py -m ruff --version >/dev/null 2>&1; then ruff_cmd=(py -m ruff); fi
if [ "${#ruff_cmd[@]}" -gt 0 ]; then
  out="$("${ruff_cmd[@]}" check --select C901 --config 'lint.mccabe.max-complexity=0' --output-format json --no-cache "${paths[@]}" 2>/dev/null || true)"
  if [ -n "$out" ]; then
    parsed="$(printf '%s' "$out" | py -c '
import json, os, re, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for m in data:
    if m.get("code") != "C901":
        continue
    x = re.search(r"`([^`]*)` is too complex \((\d+)", m.get("message", ""))
    if not x:
        continue
    where = os.path.relpath(m["filename"]).replace(os.sep, "/") + ":" + str(m["location"]["row"])
    print(x.group(2) + "\t" + where + "\t" + x.group(1))
' 2>/dev/null)"
    [ -n "$parsed" ] && rows+="$parsed"$'\n'
  fi
fi

# Go through gocyclo.
if [ -f go.mod ] && have gocyclo; then
  parsed="$(gocyclo -over 0 "${paths[@]}" 2>/dev/null | awk '{ print $1 "\t" $4 "\t" $3 }')"
  [ -n "$parsed" ] && rows+="$parsed"$'\n'
fi

rows="$(printf '%s' "$rows" | sed '/^$/d')"
if [ -z "$rows" ]; then
  echo "complexity  n/a (no eslint, ruff, or gocyclo result for: ${paths[*]})"
  exit 0
fi

printf '%s\n' "$rows" | awk -F'\t' -v budget="$budget" '
  { n++; cc = $1 + 0; sum += cc; if (cc > max) max = cc; if (cc > budget) { over++; oversum += cc } }
  END {
    erosion = (sum > 0) ? int(100 * oversum / sum + 0.5) : 0;
    printf "functions   %d · max %d · over %d: %d · erosion %d%%   (CC-weighted share in functions over %d)\n", n, max, budget, over, erosion, budget;
  }'
printf 'hotspots    '
printf '%s\n' "$rows" | sort -t$'\t' -k1,1 -rn | head -5 | awk -F'\t' 'NR>1 { printf "            " } { printf "%s  %s  %s\n", $1, $2, $3 }'
