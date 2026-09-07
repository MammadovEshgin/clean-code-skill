#!/usr/bin/env bash
# Claude Code PostToolUse hook: format the file that was just edited.
# Reads the hook payload from stdin, picks a formatter by extension, always exits 0
# so a missing formatter never blocks an edit.

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  file="${file//\\\\/\\}"
fi

[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.yml|*.yaml)
    if [ -f biome.json ] || [ -f biome.jsonc ]; then
      npx --no-install biome format --write "$file" >/dev/null 2>&1
    else
      npx --no-install prettier --write "$file" >/dev/null 2>&1
    fi
    ;;
  *.py)
    ruff format "$file" >/dev/null 2>&1 || python -m ruff format "$file" >/dev/null 2>&1
    ;;
  *.go)
    gofmt -w "$file" >/dev/null 2>&1
    ;;
  *.rs)
    rustfmt "$file" >/dev/null 2>&1
    ;;
esac

exit 0
