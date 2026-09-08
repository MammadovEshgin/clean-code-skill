#!/usr/bin/env bash
# Install the clean-code skills into agent skill directories.
#
# Usage:
#   scripts/install.sh                 project install: ./.claude/skills (run from the target repo)
#   scripts/install.sh --global        personal install: ~/.claude/skills (every project)
#   scripts/install.sh --link          symlink instead of copy, so `git pull` in this repo updates the skills
#   scripts/install.sh --codex         also install into .agents/skills (Codex and other Agent Skills hosts)
#   scripts/install.sh --cursor        also install into .cursor/skills
#   scripts/install.sh --replace       overwrite an existing skill directory instead of backing it up
#
# An existing skill directory with local changes is moved to <name>.bak-<timestamp> first, so edits
# made after a skills.sh install survive. Identical directories and old symlinks are replaced in place.
# Flags combine: scripts/install.sh --global --link --codex
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
scope="project"
mode="copy"
replace=0
extra=()

for arg in "$@"; do
  case "$arg" in
    --global) scope="global" ;;
    --project) scope="project" ;;
    --link) mode="link" ;;
    --codex) extra+=("agents") ;;
    --cursor) extra+=("cursor") ;;
    --replace) replace=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ "$scope" = "global" ]; then
  root="$HOME"
else
  root="$PWD"
fi

dests=("$root/.claude/skills")
for e in "${extra[@]:-}"; do
  case "$e" in
    agents) dests+=("$root/.agents/skills") ;;
    cursor) dests+=("$root/.cursor/skills") ;;
  esac
done

for dest in "${dests[@]}"; do
  mkdir -p "$dest"
  for src in "$REPO"/skills/*/; do
    name="$(basename "$src")"
    target="$dest/$name"
    if [ -L "$target" ] || [ "$replace" = 1 ]; then
      rm -rf "$target"
    elif [ -d "$target" ]; then
      if diff -rq "${src%/}" "$target" >/dev/null 2>&1; then
        rm -rf "$target"
      else
        backup="$target.bak-$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo "kept your edited $name at $backup (use --replace to overwrite)"
      fi
    fi
    if [ "$mode" = "link" ]; then
      ln -s "${src%/}" "$target"
    else
      cp -R "${src%/}" "$target"
    fi
    echo "installed $name -> $target ($mode)"
  done
done

cat <<'EOF'

Done. In your agent:
  /clean-code-setup        once per repo: lint gates, check command, CODING_STANDARDS.md, hooks
  /finish                  before every commit: interrogate, deslop, test audit, audit, gates, fresh-context review
  /deslop <path|repo>      rewrite existing code to the senior standard, behaviour locked; repo = the whole codebase, one commit per slice
  /audit <path>            find and fix bugs, weaknesses, security flaws, red test first
  /test-audit <path>       delete tests that cannot fail, add seam tests, prove the suite with mutation probes
  /interrogate             challenge a finished change on its own
  /clean-code-review main  fresh-context review of the diff since main, on its own
The clean-code skill itself loads automatically whenever code is written or changed.
EOF
