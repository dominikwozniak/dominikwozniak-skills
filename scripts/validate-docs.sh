#!/usr/bin/env bash
# validate-docs.sh — guard the README / DESIGN ↔ skills contract that AGENTS.md's add-a-skill
# checklist otherwise keeps by hand. CI already validates manifests and .ai/ artifacts but never the
# prose, so a skill added / renamed / removed — or an explicit-invoke flag flipped — can ship with
# the docs silently out of sync. Three mechanical, no-judgement checks:
#   1. no dead skill links   — every skills/<x>/SKILL.md linked in README exists on disk
#   2. no undocumented skill — every skills/<x>/ on disk is linked in the README task-router
#   3. explicit-invoke sync  — a skill's `disable-model-invocation: true` <=> it is marked `⭑` in
#                              the task-router AND named in the README + DESIGN explicit-only lists
# Run from the repo root (`pnpm validate:docs`) or via CI. Exit 0 iff the docs match the skills.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

README="README.md"
DESIGN="docs/DESIGN.md"
FAILED=0

# in_list <needle> <space-separated-haystack> — exit 0 if present.
in_list() {
  for w in $2; do [ "$w" = "$1" ] && return 0; done
  return 1
}

# --- skill sets --------------------------------------------------------------
disk_skills=""
explicit_disk="" # frontmatter disable-model-invocation: true
for d in skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name="$(basename "$d")"
  disk_skills="$disk_skills $name"
  if grep -qE '^disable-model-invocation:[[:space:]]*true' "$d/SKILL.md"; then
    explicit_disk="$explicit_disk $name"
  fi
done

# --- check 1: no dead skill links --------------------------------------------
echo "Checking README skill links resolve to skills on disk..."
linked="$(grep -oE 'skills/dw-[a-z-]+/SKILL\.md' "$README" | sort -u)"
for path in $linked; do
  if [ -f "$path" ]; then
    echo "OK  $path"
  else
    echo "::error::$README links $path but no such skill exists on disk"
    FAILED=1
  fi
done

# --- check 2: no undocumented skill ------------------------------------------
echo
echo "Checking every skill on disk is linked in the README task-router..."
for name in $disk_skills; do
  if printf '%s\n' "$linked" | grep -qx "skills/$name/SKILL.md"; then
    echo "OK  $name documented"
  else
    echo "::error::skills/$name/ exists but is not linked in $README task-router"
    FAILED=1
  fi
done

# --- check 3: explicit-invoke consistency ------------------------------------
echo
echo "Checking explicit-invoke (⭑ / disable-model-invocation) consistency..."
# A task-router row "carries ⭑" iff the line linking the skill also contains the ⭑ marker.
star_rows=""
for name in $disk_skills; do
  if grep "skills/$name/SKILL.md" "$README" | grep -q '⭑'; then
    star_rows="$star_rows $name"
  fi
done
readme_line="$(grep -F '**Explicit-only skills**' "$README" || true)"
design_section="$(awk '/^## Explicit-only skills/{f=1;next} f&&/^## /{exit} f{print}' "$DESIGN")"

# contains_name <text> <skill> — text mentions `<skill>` (backtick-wrapped).
contains_name() { case "$1" in *"\`$2\`"*) return 0 ;; *) return 1 ;; esac; }

# forward: each explicit-on-disk skill must appear in all three doc places.
for name in $explicit_disk; do
  in_list "$name" "$star_rows" \
    || { echo "::error::$name is explicit (disable-model-invocation) but has no \`⭑\` in the $README task-router"; FAILED=1; }
  contains_name "$readme_line" "$name" \
    || { echo "::error::$name is explicit but is not named in the $README \"Explicit-only skills\" list"; FAILED=1; }
  contains_name "$design_section" "$name" \
    || { echo "::error::$name is explicit but is not named in $DESIGN's \"Explicit-only skills\" section"; FAILED=1; }
done

# reverse: nothing may claim explicit status it doesn't actually have on disk.
for name in $star_rows; do
  in_list "$name" "$explicit_disk" \
    || { echo "::error::$name carries \`⭑\` in $README but its SKILL.md is not disable-model-invocation: true"; FAILED=1; }
done
for name in $(printf '%s\n' "$readme_line" | grep -oE 'dw-[a-z-]+' | sort -u); do
  in_list "$name" "$explicit_disk" \
    || { echo "::error::$name is listed in the $README \"Explicit-only skills\" sentence but is not explicit on disk"; FAILED=1; }
done
for name in $(printf '%s\n' "$design_section" | grep -oE 'dw-[a-z-]+' | sort -u); do
  in_list "$name" "$explicit_disk" \
    || { echo "::error::$name is listed in $DESIGN's \"Explicit-only skills\" section but is not explicit on disk"; FAILED=1; }
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All doc checks passed."
else
  echo "Doc validation FAILED."
fi
exit $FAILED
