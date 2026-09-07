#!/usr/bin/env bash
# Install the clean-code skills into agent skill directories.
#
# Usage:
#   scripts/install.sh                 project install: ./.claude/skills (run from the target repo)
#   scripts/install.sh --global        personal install: ~/.claude/skills (every project)
#   scripts/install.sh --link          symlink instead of copy, so `git pull` in this repo updates the skills
#   scripts/install.sh --codex         also install into .agents/skills (Codex and other Agent Skills hosts)
#   scripts/install.sh --cursor        also install into .cursor/skills
#
# Flags combine: scripts/install.sh --global --link --codex
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
scope="project"
mode="copy"
extra=()

for arg in "$@"; do
  case "$arg" in
    --global) scope="global" ;;
    --project) scope="project" ;;
    --link) mode="link" ;;
    --codex) extra+=("agents") ;;
    --cursor) extra+=("cursor") ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
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
    rm -rf "$target"
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
  /clean-code-setup        once per repo: lint gates, check command, CODING_STANDARDS.md
  /deslop <path|repo>      clean existing code, behaviour-preserving
  /interrogate             challenge a finished change before calling it done
  /clean-code-review main  fresh-context review of the diff since main
The clean-code skill itself loads automatically whenever code is written or changed.
EOF
