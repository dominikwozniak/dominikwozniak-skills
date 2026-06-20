#!/usr/bin/env bash
# plan-status.sh — recompute a PLAN.md's frontmatter `status:` from its status table.
#
# The frontmatter scalar is DERIVED state: a pure function of the table's Status column.
# It has no other owner — dw-build/dw-sync flip the table rows, this script keeps the
# scalar in sync so it can never drift (the bug that motivated this script: a fully-done
# table left the frontmatter reading `todo` forever).
#
# Rule (precedence):
#   any row blocked   -> blocked      # surface the blocker first
#   else all done     -> done
#   else any started  -> doing        # any row in {doing, done}, but not all done
#   else              -> todo         # every row still todo (or empty table)
#
# Usage:
#   plan-status.sh <PLAN.md>          rewrite the frontmatter status: line in place (idempotent)
#   plan-status.sh --check <PLAN.md>  report-only: print drift, exit non-zero, write NOTHING
set -euo pipefail

check_only=0
if [ "${1:-}" = "--check" ]; then
  check_only=1
  shift
fi

plan="${1:-}"
if [ -z "$plan" ]; then
  echo "usage: plan-status.sh [--check] <PLAN.md>" >&2
  exit 1
fi
if [ ! -f "$plan" ]; then
  echo "plan-status.sh: no such file: $plan" >&2
  exit 1
fi

# Parse: emit "OLD<TAB>DERIVED", or "ERROR<TAB><reason>".
result=$(awk '
  BEGIN { fm=0; fm_done=0; have_status=0; old=""; hdr=0; col=0; rows=0
          n_blocked=0; n_done=0; n_doing=0 }
  /^---[[:space:]]*$/ {
    if (fm==0 && NR<=2)            { fm=1; next }       # opening fence
    else if (fm==1 && fm_done==0)  { fm_done=1; next }  # closing fence
  }
  fm==1 && fm_done==0 {                                 # inside frontmatter
    if ($0 ~ /^status:/) {
      have_status=1
      v=$0
      sub(/^status:[[:space:]]*/, "", v)                # strip key
      sub(/[[:space:]]*#.*$/, "", v)                    # strip trailing comment
      gsub(/[[:space:]]/, "", v)
      old=v
    }
    next
  }
  hdr==0 && /\|/ && /[Ss]tatus/ && /[Cc]ommit/ {        # status-table header row
    hdr=1
    nf=split($0, cells, "|")
    for (i=1;i<=nf;i++) {
      c=cells[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
      if (tolower(c)=="status") col=i
    }
    next
  }
  hdr==1 {                                              # table body
    if ($0 !~ /\|/) { hdr=2; next }                     # non-table line ends the table
    if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]+\|[[:space:]]*$/) next   # |---| separator
    split($0, cells, "|")
    s=cells[col]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    gsub(/`/, "", s)
    s=tolower(s)
    if (s=="") next
    rows++
    if (s=="blocked")    n_blocked++
    else if (s=="done")  n_done++
    else if (s=="doing") n_doing++
    next
  }
  END {
    if (have_status==0)        { print "ERROR\tno frontmatter status: line"; exit }
    if (hdr==0 || col==0)      { print "ERROR\tno status table (need a | Status | Commit | header)"; exit }
    if (rows==0)               derived="todo"
    else if (n_blocked>0)      derived="blocked"
    else if (n_done==rows)     derived="done"
    else if (n_done>0 || n_doing>0) derived="doing"
    else                       derived="todo"
    printf "%s\t%s\n", old, derived
  }
' "$plan")

old="${result%%$'\t'*}"
new="${result#*$'\t'}"

if [ "$old" = "ERROR" ]; then
  echo "plan-status.sh: ${new}: $plan" >&2
  exit 1
fi

if [ "$check_only" -eq 1 ]; then
  if [ "$old" = "$new" ]; then
    echo "status: $new (ok)"
    exit 0
  fi
  echo "plan-status.sh: status drift in $plan — frontmatter=$old, table implies=$new" >&2
  exit 1
fi

if [ "$old" = "$new" ]; then
  echo "status: $new (unchanged)"
  exit 0
fi

# Rewrite only the frontmatter status: value, preserving any trailing comment.
tmp=$(mktemp "$(dirname "$plan")/.plan-status.XXXXXX")
awk -v new="$new" '
  BEGIN { fm=0; fm_done=0; replaced=0 }
  /^---[[:space:]]*$/ {
    if (fm==0 && NR<=2)           { fm=1; print; next }
    else if (fm==1 && fm_done==0) { fm_done=1; print; next }
  }
  fm==1 && fm_done==0 && replaced==0 && /^status:/ {
    comment=""
    if (match($0, /#.*$/)) comment=substr($0, RSTART)
    if (comment!="") printf "status: %s %s\n", new, comment
    else             printf "status: %s\n", new
    replaced=1
    next
  }
  { print }
' "$plan" > "$tmp"
mv "$tmp" "$plan"
echo "status: $old → $new"
