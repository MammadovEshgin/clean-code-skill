#!/usr/bin/env bash
# Validate the skills in this repo against the Agent Skills constraints and this repo's own rules.
#   - frontmatter has name and description; name matches the directory; name is lowercase-hyphen, <= 64 chars
#   - description is non-empty and <= 1024 chars
#   - SKILL.md body is <= 500 lines
#   - relative links in every skill markdown file resolve
#   - no em dashes anywhere in skills/ (an AI-writing tell this repo bans in its own text)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
problem() { echo "FAIL  $1"; fail=1; }

for skill_md in "$REPO"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$skill_md")")"
  front="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$skill_md")"
  name="$(printf '%s\n' "$front" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  desc="$(printf '%s\n' "$front" | sed -n 's/^description:[[:space:]]*//p' | head -1)"

  [ -n "$name" ] || problem "$dir: missing name"
  [ "$name" = "$dir" ] || problem "$dir: name '$name' does not match directory"
  printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || problem "$dir: name must be lowercase letters, digits, hyphens"
  [ "${#name}" -le 64 ] || problem "$dir: name longer than 64 characters"
  [ -n "$desc" ] || problem "$dir: missing description"
  [ "${#desc}" -le 1024 ] || problem "$dir: description longer than 1024 characters (${#desc})"

  body_lines="$(awk 'NR>1 && $0=="---" {found=1; next} found {n++} END {print n+0}' "$skill_md")"
  [ "$body_lines" -le 500 ] || problem "$dir: SKILL.md body is $body_lines lines (limit 500)"
  echo "ok    $dir  (${#desc} chars description, $body_lines body lines)"
done

while IFS= read -r -d '' md; do
  dir="$(dirname "$md")"
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    case "$link" in http://*|https://*|mailto:*) continue ;; esac
    [ -e "$dir/$link" ] || problem "$md: link target missing: $link"
  done < <(grep -oE '\]\(([^)#]+)(#[^)]*)?\)' "$md" | sed -E 's/^\]\((.*)\)$/\1/; s/#.*$//' || true)
done < <(find "$REPO/skills" -name '*.md' -print0)

if grep -rl $'\xe2\x80\x94' "$REPO/skills" "$REPO/README.md" 2>/dev/null; then
  problem "em dash found in the files above"
fi

if [ "$fail" -ne 0 ]; then
  echo "check: failures"; exit 1
fi
echo "check: all skills valid"
