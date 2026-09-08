#!/usr/bin/env bash
# Validate the skills in this repo against the Agent Skills constraints and this repo's own rules.
#   - frontmatter has name and description; name matches the directory; name is lowercase-hyphen, <= 64 chars
#   - description is non-empty and <= 1024 chars
#   - SKILL.md body is <= 500 lines
#   - relative links in every skill markdown file resolve
#   - no em dashes in skills/, docs/, evals/, README, CHANGELOG (an AI-writing tell this repo bans in its own text)
#   - shell scripts parse; JSON templates and manifests parse; plugin.json lists every skill
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

if grep -rl $'\xe2\x80\x94' "$REPO/skills" "$REPO/README.md" "$REPO/docs" "$REPO/evals" "$REPO/CHANGELOG.md" 2>/dev/null; then
  problem "em dash found in the files above"
fi

for sh in "$REPO"/skills/*/templates/*.sh "$REPO"/skills/*/scripts/*.sh "$REPO"/scripts/*.sh "$REPO"/evals/run.sh "$REPO"/evals/fixtures/*/check.sh; do
  [ -f "$sh" ] || continue
  bash -n "$sh" || problem "$sh: shell syntax"
done

for js in "$REPO"/skills/*/templates/*.json "$REPO"/.claude-plugin/*.json; do
  [ -f "$js" ] || continue
  if command -v python >/dev/null 2>&1; then
    python -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$js" 2>/dev/null || problem "$js: invalid JSON"
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$js" 2>/dev/null || problem "$js: invalid JSON"
  fi
done

manifest_skills="$(python -c "import json; print(' '.join(json.load(open('$REPO/.claude-plugin/plugin.json', encoding='utf-8'))['skills']))" 2>/dev/null || true)"
for skill_md in "$REPO"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$skill_md")")"
  case " $manifest_skills " in *"./skills/$dir "*) ;; *) [ -n "$manifest_skills" ] && problem "plugin.json does not list ./skills/$dir" ;; esac
done

if [ "$fail" -ne 0 ]; then
  echo "check: failures"; exit 1
fi
echo "check: all skills valid"
