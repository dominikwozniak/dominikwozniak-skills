#!/usr/bin/env bash
# new-run.sh — create a fresh .ai/runs/<id>/ with a correctly-formed SPEC frontmatter.
#
# The deterministic spine of dw-spec: the run-folder name and the SPEC frontmatter
# (run / ticket / status / created / branch) are pure functions of (date, ticket,
# branch) and must be machine-exact, so the artifact validator and dw-resume can
# rely on them. The SPEC *body* (TLDR, Open Questions, …) is judgment work that
# dw-spec fills in afterwards — this script owns only the spine.
#
# Usage:
#   new-run.sh <ticket> <desc>     ticket may be '' or 'none' for a ticketless run
#
# Prints the created run directory (absolute path) on the last stdout line.
# Refuses (exit 1) if the target run directory already exists — never clobbers.
# $SLUG_DATE (YYYYMMDD) overrides the date for deterministic tests.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
slugify="$here/slugify.sh"

ticket_raw="${1:-}"
desc="${2:-}"
if [ -z "$desc" ]; then
  echo "usage: new-run.sh <ticket> <desc>" >&2
  exit 1
fi

# The frontmatter `ticket:` keeps the original case (commit/PR subjects use the
# uppercase [ABC-123]); only the run-id folder is lowercased (slugify does that).
ticket_fm="$ticket_raw"
case "$ticket_raw" in
  "" | none | NONE | None) ticket_fm="none"; ticket_raw="" ;;
esac

run_id="$("$slugify" run-id "$ticket_raw" "$desc")"

created="${SLUG_DATE:+${SLUG_DATE:0:4}-${SLUG_DATE:4:2}-${SLUG_DATE:6:2}}"
created="${created:-$(date +%F)}"

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
run_dir="$root/.ai/runs/$run_id"

if [ -e "$run_dir" ]; then
  echo "new-run.sh: run already exists: $run_dir" >&2
  echo "new-run.sh: continue that run instead of creating a new one (do not clobber)." >&2
  exit 1
fi

mkdir -p "$run_dir"
cat > "$run_dir/SPEC.md" <<EOF
---
run: $run_id
ticket: $ticket_fm
status: draft
created: $created
branch: $branch
---

# Spec — $desc
EOF

echo "new-run.sh: created $run_dir/SPEC.md (status: draft)" >&2
printf '%s\n' "$run_dir"
