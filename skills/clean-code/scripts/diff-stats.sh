#!/usr/bin/env bash
# Diff statistics for the Clean Code Report.
#
# Usage:
#   scripts/diff-stats.sh            working tree vs HEAD (falls back to the last commit when the tree is clean)
#   scripts/diff-stats.sh <ref>      working tree vs the merge-base of <ref> and HEAD (e.g. main)
#   scripts/diff-stats.sh <a>..<b>   an explicit range
#
# Counts are heuristics over the unified diff; they are meant to fill the report, not to judge.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "diff-stats: not a git repository" >&2
  exit 1
fi

target="${1:-}"
if [ -z "$target" ]; then
  if git -c core.safecrlf=false diff --quiet HEAD 2>/dev/null; then
    if git rev-parse --verify -q HEAD~1 >/dev/null; then
      range_desc="HEAD~1..HEAD (tree is clean; showing last commit)"
      diff_args=(HEAD~1 HEAD)
    else
      range_desc="initial commit"
      diff_args=(4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD)
    fi
  else
    range_desc="working tree vs HEAD"
    diff_args=(HEAD)
  fi
elif [[ "$target" == *..* ]]; then
  range_desc="$target"
  diff_args=("$target")
else
  base="$(git merge-base "$target" HEAD 2>/dev/null || echo "$target")"
  range_desc="working tree vs merge-base($target)"
  diff_args=("$base")
fi

numstat="$(git -c core.safecrlf=false diff --numstat "${diff_args[@]}" -- . ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)pnpm-lock.yaml' ':(exclude)yarn.lock' ':(exclude)Cargo.lock' ':(exclude)go.sum')"
files="$(printf '%s\n' "$numstat" | sed '/^$/d' | wc -l | tr -d ' ')"
added="$(printf '%s\n' "$numstat" | awk '$1 != "-" { a += $1 } END { print a + 0 }')"
removed="$(printf '%s\n' "$numstat" | awk '$2 != "-" { r += $2 } END { print r + 0 }')"
net=$((added - removed))

diff="$(git -c core.safecrlf=false diff --unified=0 "${diff_args[@]}" -- . ':(exclude)*.lock' ':(exclude)package-lock.json' ':(exclude)pnpm-lock.yaml' ':(exclude)yarn.lock' ':(exclude)Cargo.lock' ':(exclude)go.sum' | grep -E '^[-+]' | grep -Ev '^(\+\+\+|---)' || true)"

count() { # $1 = sign (- or +), $2 = extended regex
  printf '%s\n' "$diff" | grep -E "^\\$1" | sed -E "s/^[-+]//" | grep -Ec "$2" || true
}

comment_re='^[[:space:]]*(//|#[^!]|/\*|\*[^/]|\*$|<!--|--[[:space:]]|"""|'"'''"')'
code_in_comment_re='^[[:space:]]*(//|#)[[:space:]]*([A-Za-z_][A-Za-z0-9_.]*[[:space:]]*(\(|=[^=]|\+=|-=)|(const|let|var|if|for|while|return|import|from|def|class|function|fn|pub|func|export)[[:space:]]|[{}]|.*;[[:space:]]*$)'
debug_re='(console\.(log|debug|info|trace)\(|(^|[^A-Za-z_])print\(|println!\(|dbg!\(|fmt\.Print(ln|f)?\(|System\.out\.print|(^|[^A-Za-z_])debugger[[:space:]]*;?$|\.debug\()'
todo_re='(TODO|FIXME|XXX|HACK)'
cast_re='(:[[:space:]]*any\b|as[[:space:]]+any\b|as[[:space:]]+unknown[[:space:]]+as|@ts-ignore|@ts-expect-error|type:[[:space:]]*ignore|\bAny\b|#[[:space:]]*noqa|eslint-disable)'

c_removed="$(count - "$comment_re")"
c_added="$(count + "$comment_re")"
dead_removed="$(count - "$code_in_comment_re")"
dead_added="$(count + "$code_in_comment_re")"
dbg_removed="$(count - "$debug_re")"
dbg_added="$(count + "$debug_re")"
todo_removed="$(count - "$todo_re")"
todo_added="$(count + "$todo_re")"
cast_added="$(count + "$cast_re")"

printf 'range      %s\n' "$range_desc"
printf 'files      %s\n' "$files"
printf 'lines      +%s / -%s · net %+d\n' "$added" "$removed" "$net"
printf 'comments   removed %s · added %s\n' "$c_removed" "$c_added"
printf 'dead-ish   removed %s · added %s   (commented-out code lines)\n' "$dead_removed" "$dead_added"
printf 'debug      removed %s · added %s\n' "$dbg_removed" "$dbg_added"
printf 'todo       removed %s · added %s\n' "$todo_removed" "$todo_added"
printf 'suppress   added %s   (any / casts / ignore comments)\n' "$cast_added"

if [ "$files" -gt 0 ]; then
  printf 'largest    '
  printf '%s\n' "$numstat" | awk '$1 != "-" { print ($1 + $2) "\t" $3 }' | sort -rn | head -3 | awk -F'\t' '{ printf "%s (%s)  ", $2, $1 } END { print "" }'
fi
