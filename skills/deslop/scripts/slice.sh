#!/usr/bin/env bash
# Stateful steps of the /deslop repo loop, made deterministic.
#
#   slice.sh snapshot
#       Record the working tree before a worker starts (.deslop/before.txt). Changes present now
#       belong to someone else and are never reverted by confine.
#   slice.sh confine <path>...
#       Revert every change outside the given paths that was not present at snapshot. .deslop/ is
#       always kept. Prints one line per reverted path.
#   slice.sh red-check "<test command>" <production path>...
#       Prove a fix: put the HEAD version of each production path back (a new file is removed),
#       run the test command, expect it to fail, then restore the fix. Exit 0 when the tests went
#       red on the pre-fix code, 1 when they passed (the fix is unproven), 2 on misuse.
set -uo pipefail

state=".deslop"
before="$state/before.txt"

inside() { # inside <path> <root>...
  local p="$1"; shift
  local r
  for r in "$@"; do
    r="${r%/}"
    [ "$p" = "$r" ] && return 0
    case "$p" in "$r"/*) return 0 ;; esac
  done
  return 1
}

case "${1:-}" in
  snapshot)
    mkdir -p "$state"
    git status --porcelain > "$before"
    echo "snapshot: $(wc -l < "$before" | tr -d ' ') pre-existing change(s) recorded"
    ;;

  confine)
    shift
    [ "$#" -ge 1 ] || { echo "usage: slice.sh confine <path>..." >&2; exit 2; }
    [ -f "$before" ] || : > "$before"
    reverted=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      status="${line:0:2}"
      path="${line:3}"
      path="${path##* -> }"
      inside "$path" "$state" "$@" && continue
      grep -qxF -- "$line" "$before" && continue
      case "$status" in
        '??') rm -rf -- "$path"; echo "reverted (untracked): $path" ;;
        A*|'M'*|' M'|'MM'|' D'|'D '*|R*|C*)
          if git cat-file -e "HEAD:$path" 2>/dev/null; then
            git checkout -q HEAD -- "$path"
          else
            git rm -q --cached -- "$path" 2>/dev/null; rm -f -- "$path"
          fi
          echo "reverted: $path" ;;
        *) git checkout -q HEAD -- "$path" 2>/dev/null && echo "reverted: $path" ;;
      esac
      reverted=$((reverted + 1))
    done < <(git status --porcelain)
    echo "confine: $reverted path(s) reverted"
    ;;

  red-check)
    shift
    [ "$#" -ge 2 ] || { echo "usage: slice.sh red-check \"<test command>\" <production path>..." >&2; exit 2; }
    test_cmd="$1"; shift
    backups=()
    restore() {
      local p
      for p in "${backups[@]}"; do
        if [ -f "$p.fix" ]; then mv -f -- "$p.fix" "$p"; fi
      done
    }
    trap restore EXIT
    for p in "$@"; do
      [ -e "$p" ] || { echo "red-check: no such file: $p" >&2; exit 2; }
      cp -- "$p" "$p.fix"
      backups+=("$p")
      if git cat-file -e "HEAD:$p" 2>/dev/null; then
        git show "HEAD:$p" > "$p"
      else
        rm -f -- "$p"
      fi
    done
    if bash -c "$test_cmd" >/dev/null 2>&1; then
      echo "red-check: the tests PASSED on the pre-fix code; the fix is unproven"
      exit 1
    fi
    echo "red-check: the tests went red on the pre-fix code; the fix is proven"
    exit 0
    ;;

  *)
    sed -n '2,14p' "$0" >&2
    exit 2
    ;;
esac
