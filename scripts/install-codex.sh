#!/usr/bin/env bash
# install-codex.sh — expose every dw-skill to Codex CLI by symlinking it into a Codex skills dir.
#
# Codex reads SKILL.md from ~/.codex/skills/<name>/ (global), the same open format Claude Code uses.
# The skills carry no Claude-only env var, so they run as-is. Their scripts resolve because skill
# bodies call them skill-relative (`<this-skill-dir>/scripts/<s>.sh`), which follows the symlink back
# to this repo's scripts/runtime/ regardless of your working directory.
#
# Usage:
#   bash scripts/install-codex.sh            # symlink into ~/.codex/skills/
#   bash scripts/install-codex.sh <dir>      # symlink into <dir> instead
#   CODEX_SKILLS_DIR=/path bash scripts/install-codex.sh
#
# Re-running is safe (idempotent). It never deletes a real directory — only manages its own symlinks.
# NOTE: tooling, never shipped in a plugin. Codex installs by directory placement, not a marketplace.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-${CODEX_SKILLS_DIR:-$HOME/.codex/skills}}"

mkdir -p "$DEST"
echo "Installing dw-skills into $DEST"
echo

installed=0
skipped=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  link="$DEST/$name"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "SKIP  $name — $link exists and is not a symlink (left untouched)"
    skipped=$((skipped + 1))
    continue
  fi
  # absolute target; -n replaces an existing symlinked dir instead of following it
  if ln -sfn "${d%/}" "$link"; then
    printf 'LINK  %-28s -> %s\n' "$name" "${d%/}"
    installed=$((installed + 1))
  else
    echo "FAIL  $name — could not symlink $link"
  fi
done

echo
echo "Done: $installed linked, $skipped skipped."
echo "Open Codex CLI in any repo — the dw-* skills are now discoverable. (Claude Code users keep"
echo "using the plugin marketplace; this is the Codex path only.)"
