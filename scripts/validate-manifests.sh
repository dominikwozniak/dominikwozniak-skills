#!/usr/bin/env bash
# Validate every marketplace.json + plugin.json via Claude CLI, verify version sync between
# marketplace.json[].version and each <source>/.claude-plugin/plugin.json.version, and check the
# shipped scripts (canon in scripts/runtime/, symlinked into each plugin's scripts/ dir).
set -uo pipefail

FOUND=0
FAILED=0

while IFS= read -r file; do
  FOUND=1
  echo "Validating $file..."
  if ! claude plugin validate "$file"; then
    FAILED=1
  fi
done < <(find . -type f \( -name 'marketplace.json' -o -name 'plugin.json' \) -not -path './node_modules/*' | sort)

if [ "$FOUND" -eq 0 ]; then
  echo "No manifest files found."
  exit 0
fi

echo
echo "Checking version sync between marketplace.json and plugin.json..."
while IFS=$'\t' read -r name source mp_v; do
  pj_v=$(jq -r '.version' "${source#./}/.claude-plugin/plugin.json")
  if [ "$mp_v" = "$pj_v" ]; then
    echo "OK  $name=$mp_v"
  else
    echo "::error::$name: marketplace.json=$mp_v vs plugin.json=$pj_v"
    FAILED=1
  fi
done < <(jq -r '.plugins[] | [.name, .source, .version] | @tsv' .claude-plugin/marketplace.json)

echo
echo "Checking shipped scripts (canon in scripts/runtime/, symlinked into each consuming skill)..."
# Plugin-level shipped scripts live once under scripts/runtime/ and are exposed to each consuming
# skill via a git-tracked symlink skills/<name>/scripts/<s>.sh -> ../../../scripts/runtime/<s>.sh.
# Skill bodies invoke them as <this-skill-dir>/scripts/<s>.sh — a path that resolves both in Claude
# Code's plugin cache AND in Codex's .codex/skills/, with no ${CLAUDE_PLUGIN_ROOT} env var. `claude
# plugin install` deep-derefs the skill dir, turning each nested symlink into a real file in the
# cache (0 symlinks). We assert (1) each canon exists and is executable, and (2) every symlink under
# skills/*/scripts/ resolves into the canon and is executable — never dangling, never drifting.
RUNTIME_SCRIPTS="slugify.sh new-run.sh find-active-run.sh plan-status.sh validate-ai-artifacts.sh"
for s in $RUNTIME_SCRIPTS; do
  c="scripts/runtime/$s"
  if [ ! -f "$c" ]; then
    echo "::error::missing canonical script: $c"
    FAILED=1
  elif [ ! -x "$c" ]; then
    echo "::error::$c is not executable (chmod +x)"
    FAILED=1
  else
    echo "OK  $c (canon, executable)"
  fi
done

echo
echo "Checking skill script symlinks resolve into scripts/runtime/..."
# Symlinks share one canon, so the slugify-copy drift the old plugin layout risked is gone by
# construction. A real file here (e.g. dw-doctor/scripts/doctor.sh — a single-skill bundled script)
# is allowed but must still be executable.
for link in skills/*/scripts/*.sh; do
  [ -e "$link" ] || [ -L "$link" ] || continue
  if [ -L "$link" ]; then
    tgt=$(readlink "$link")
    if [ ! -e "$link" ]; then
      echo "::error::$link is a dangling symlink (target '$tgt' missing)"
      FAILED=1
    elif [ ! -x "$link" ]; then
      echo "::error::$link resolves to a non-executable target"
      FAILED=1
    elif ! printf '%s' "$tgt" | grep -q 'scripts/runtime/'; then
      echo "::error::$link must point into scripts/runtime/ (got '$tgt')"
      FAILED=1
    else
      echo "OK  $link -> $tgt"
    fi
  elif [ ! -x "$link" ]; then
    echo "::error::$link is a real file but not executable (chmod +x)"
    FAILED=1
  else
    echo "OK  $link (bundled, executable)"
  fi
done

echo
echo "Checking no SKILL.md still references \${CLAUDE_PLUGIN_ROOT} (must use <this-skill-dir>)..."
# The whole point of the skill-relative layout: skills carry no Claude-only env var, so they run
# unchanged under Codex. A stray \${CLAUDE_PLUGIN_ROOT} would silently break the Codex path.
if grep -rn 'CLAUDE_PLUGIN_ROOT' skills/ >/dev/null 2>&1; then
  echo "::error::SKILL.md still references \${CLAUDE_PLUGIN_ROOT} — use <this-skill-dir>/scripts/ instead:"
  grep -rn 'CLAUDE_PLUGIN_ROOT' skills/
  FAILED=1
else
  echo "OK  no \${CLAUDE_PLUGIN_ROOT} in any SKILL.md"
fi

echo
echo "Checking no SKILL.md has a doubled <this-skill-dir> placeholder..."
# Guards against a bad search-and-replace prepending the placeholder onto a path that already
# had it (e.g. <this-skill-dir><this-skill-dir>/scripts/x.sh) — valid markdown, so nothing else
# would catch it, but the resolved path is wrong.
if grep -rn '<this-skill-dir><this-skill-dir>' skills/ >/dev/null 2>&1; then
  echo "::error::doubled <this-skill-dir> placeholder — collapse to a single one:"
  grep -rn '<this-skill-dir><this-skill-dir>' skills/
  FAILED=1
else
  echo "OK  no doubled <this-skill-dir> placeholder"
fi

echo
echo "Checking .codex/skills/ stays in sync with skills/ (Codex in-repo discovery)..."
# Every skill needs a committed .codex/skills/<name> -> ../../skills/<name> symlink so Codex working
# inside this repo discovers it. A skill with no .codex link (Claude Code sees it via plugins/, Codex
# does not) is silent drift the other checks miss; a dangling or wrong-target link is just as bad.
for d in skills/*/; do
  name="$(basename "$d")"
  link=".codex/skills/$name"
  if [ ! -L "$link" ]; then
    echo "::error::$link missing — add: ln -s ../../skills/$name $link (skill not discoverable under Codex in-repo)"
    FAILED=1
  elif [ ! -e "$link" ]; then
    echo "::error::$link is a dangling symlink (target '$(readlink "$link")' missing)"
    FAILED=1
  elif [ "$(readlink "$link")" != "../../skills/$name" ]; then
    echo "::error::$link must point to ../../skills/$name (got '$(readlink "$link")')"
    FAILED=1
  else
    echo "OK  $link -> ../../skills/$name"
  fi
done
# And no orphan: a .codex/skills entry whose skill was renamed/removed dangles.
for link in .codex/skills/*; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    echo "::error::$link is a dangling .codex symlink (target '$(readlink "$link")' missing)"
    FAILED=1
  fi
done

exit $FAILED
