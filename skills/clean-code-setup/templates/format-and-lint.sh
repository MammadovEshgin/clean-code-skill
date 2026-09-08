#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit|Write): format the file that was just edited, then lint it.
# Lint findings go to stderr with exit 2 so the agent sees them and fixes them now.
# A missing formatter or linter never blocks an edit: the script exits 0 in that case.
# Also records that this session edited a file, so check-on-stop.sh knows to run.

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
  session="$(printf '%s' "$input" | jq -r '.session_id // empty')"
else
  file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  file="${file//\\\\/\\}"
  session="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

[ -n "$file" ] && [ -f "$file" ] || exit 0
[ -n "$session" ] && touch "${TMPDIR:-/tmp}/clean-code-${session}.edited" 2>/dev/null

lint_out=""
case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    if [ -f biome.json ] || [ -f biome.jsonc ]; then
      npx --no-install biome format --write "$file" >/dev/null 2>&1
      lint_out="$(npx --no-install biome lint "$file" 2>&1)" || true
    else
      npx --no-install prettier --write "$file" >/dev/null 2>&1
      lint_out="$(npx --no-install eslint --no-warn-ignored "$file" 2>&1)" || true
    fi
    ;;
  *.json|*.css|*.scss|*.md|*.yml|*.yaml)
    npx --no-install prettier --write "$file" >/dev/null 2>&1
    ;;
  *.py)
    ruff format "$file" >/dev/null 2>&1 || python -m ruff format "$file" >/dev/null 2>&1
    lint_out="$(ruff check "$file" 2>&1 || python -m ruff check "$file" 2>&1)" || true
    ;;
  *.go)
    gofmt -w "$file" >/dev/null 2>&1
    ;;
  *.rs)
    rustfmt "$file" >/dev/null 2>&1
    ;;
esac

# Only real findings are reported. A missing tool or a clean pass is silence.
if printf '%s' "$lint_out" | grep -Eq '^[[:space:]]*[0-9]+:[0-9]+|error|warning|[A-Z]+[0-9]{3,4}' \
   && ! printf '%s' "$lint_out" | grep -Eqi 'not found|ENOENT|could not|No such file|All checks passed'; then
  {
    echo "clean-code: lint findings in $file (fix them before moving on):"
    printf '%s\n' "$lint_out" | head -40
  } >&2
  exit 2
fi
exit 0
