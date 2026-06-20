#!/usr/bin/env bash
# validate-ai-artifacts.sh — structural schema-check for .ai/ work artifacts.
#
# This validates STRUCTURE, never content quality (that is the quality skills'
# job). It is the machine guard for what new-run.sh / dw-plan / dw-build write:
# a malformed SPEC.md or PLAN.md should fail here, loudly, not trip a downstream
# skill later. Status/slug DERIVATION already lives in plan-status.sh + slugify.sh;
# this script reuses them rather than re-deriving, so there is one rule, no drift.
#
# Checks:
#   SPEC.md   frontmatter fenced; keys run/ticket/status/created/branch present;
#             status in {draft, open-questions, ready}; created is YYYY-MM-DD.
#   PLAN.md   frontmatter fenced; keys run/spec/status present; status in
#             {todo, doing, done, blocked}; table has Phase|Step|Title|Status|Commit;
#             each row status in the enum; done rows carry a hex SHA (7-40) in Commit;
#             step ids well-formed N.M, unique, strictly increasing; AND
#             plan-status.sh --check passes (frontmatter == derived-from-table).
#   verify/   .ai/verify/<dir>/ name == slugify.sh branch-slug <branch:> from a
#             contained *.md frontmatter.
#
# Usage:
#   validate-ai-artifacts.sh <run-dir>      validate one .ai/runs/<id>/ (SPEC required, PLAN if present)
#   validate-ai-artifacts.sh --all [root]   sweep every .ai/runs/*/ and .ai/verify/*/ under root (default: git root)
#
# Exit 0 if all checks pass, 1 if any fail. bash 3.2 / macOS safe.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_STATUS="$SCRIPT_DIR/plan-status.sh"
SLUGIFY="$SCRIPT_DIR/slugify.sh"

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
ok()   { echo "OK   $*"; }

# --- frontmatter helpers (first --- ... --- block) ---------------------------

# fm_ok <file> — succeed if the file opens with a --- fence and has a closing ---.
# NB: awk runs END even after a body `exit`, so the verdict is computed in END
# from flags — an `exit 0` in the body would be overridden by `END { exit 1 }`.
fm_ok() {
  awk '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { bad=1; exit }
    /^---[[:space:]]*$/ { f++ }
    END { exit (bad || f < 2) ? 1 : 0 }
  ' "$1"
}

# fm_has_key <file> <key> — succeed if the frontmatter declares <key>:.
fm_has_key() {
  awk -v key="$2" '
    /^---[[:space:]]*$/ { f++; if (f==2) exit; next }
    f==1 && $0 ~ ("^" key ":") { found=1; exit }
    END { exit found ? 0 : 1 }
  ' "$1"
}

# fm_value <file> <key> — print the frontmatter value of <key> (empty if absent).
fm_value() {
  awk -v key="$2" '
    /^---[[:space:]]*$/ { f++; if (f==2) exit; next }
    f==1 && $0 ~ ("^" key ":") {
      v=$0; sub("^" key ":[[:space:]]*","",v); sub(/[[:space:]]*#.*$/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
      print v; exit
    }
  ' "$1"
}

# --- SPEC ---------------------------------------------------------------------

validate_spec() {
  spec="$1"
  before="$FAILED"
  if [ ! -f "$spec" ]; then fail "$spec: SPEC.md not found"; return; fi
  if ! fm_ok "$spec"; then fail "$spec: missing or unterminated --- frontmatter"; return; fi

  for k in run ticket status created branch; do
    fm_has_key "$spec" "$k" || fail "$spec: missing frontmatter key '$k'"
  done

  st=$(fm_value "$spec" status)
  case "$st" in
    draft | open-questions | ready) ;;
    *) fail "$spec: invalid status '$st' (want draft|open-questions|ready)" ;;
  esac

  cr=$(fm_value "$spec" created)
  case "$cr" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) fail "$spec: created '$cr' is not YYYY-MM-DD" ;;
  esac

  [ "$FAILED" -eq "$before" ] && ok "$spec"
}

# --- PLAN ---------------------------------------------------------------------

validate_plan() {
  plan="$1"
  before="$FAILED"
  if ! fm_ok "$plan"; then fail "$plan: missing or unterminated --- frontmatter"; return; fi

  for k in run spec status; do
    fm_has_key "$plan" "$k" || fail "$plan: missing frontmatter key '$k'"
  done

  st=$(fm_value "$plan" status)
  case "$st" in
    todo | doing | done | blocked) ;;
    *) fail "$plan: invalid frontmatter status '$st' (want todo|doing|done|blocked)" ;;
  esac

  # Status table: columns, row enums, done-row SHA, step-id shape/uniqueness/order.
  table_errs=$(awk '
    BEGIN { hdr=0; pcol=stepcol=tcol=scol=ccol=0; allcols=0; first=1; pmaj=0; pmin=0 }
    function err(m){ print m }
    hdr==0 && /\|/ && /[Pp]hase/ && /[Ss]tatus/ && /[Cc]ommit/ {
      hdr=1; nf=split($0,c,"|")
      for(i=1;i<=nf;i++){ x=c[i]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",x); lx=tolower(x)
        if(lx=="phase")pcol=i; if(lx=="step")stepcol=i; if(lx=="title")tcol=i
        if(lx=="status")scol=i; if(lx=="commit")ccol=i }
      allcols=(pcol&&stepcol&&tcol&&scol&&ccol)
      next
    }
    hdr==1 {
      if ($0 !~ /\|/) { hdr=2; next }
      if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]+\|[[:space:]]*$/) next
      if (!allcols) next
      nf=split($0,c,"|")
      s=c[scol]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); gsub(/`/,"",s); s=tolower(s)
      if (s=="") next
      if (s!="todo"&&s!="doing"&&s!="done"&&s!="blocked") err("bad row status: \"" s "\"")
      step=c[stepcol]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",step); gsub(/`/,"",step)
      commit=c[ccol]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",commit); gsub(/`/,"",commit)
      if (s=="done" && commit !~ /^[0-9a-fA-F]{7,40}$/) err("done step " step " has no valid commit SHA: \"" commit "\"")
      if (step !~ /^[0-9]+\.[0-9]+$/) { err("malformed step id: \"" step "\"") }
      else {
        if (step in seen) err("duplicate step id: " step); seen[step]=1
        n=split(step,p,"."); maj=p[1]+0; mn=p[2]+0
        if (first) first=0
        else if (maj<pmaj || (maj==pmaj && mn<=pmin)) err("non-monotonic step id: " step " after " pmaj "." pmin)
        pmaj=maj; pmin=mn
      }
    }
    END {
      if (hdr==0) err("no status table (need a | Phase | Step | Title | Status | Commit | header)")
      else if (!allcols) err("status table missing a column (need Phase, Step, Title, Status, Commit)")
    }
  ' "$plan")
  if [ -n "$table_errs" ]; then
    # here-string keeps the loop in this shell (a pipe would lose FAILED)
    while IFS= read -r line; do
      fail "$plan: $line"
    done <<<"$table_errs"
  fi

  # Frontmatter status must equal the table-derived status (reuse the deriver).
  if [ -x "$PLAN_STATUS" ]; then
    if ! ps_out=$("$PLAN_STATUS" --check "$plan" 2>&1); then
      fail "$plan: $ps_out"
    fi
  fi

  [ "$FAILED" -eq "$before" ] && ok "$plan"
}

# --- verify dir ---------------------------------------------------------------

validate_verify_dir() {
  vdir="$1"
  before="$FAILED"
  base=$(basename "$vdir")
  found_branch=0
  for md in "$vdir"/*.md; do
    [ -f "$md" ] || continue
    b=$(fm_value "$md" branch)
    [ -n "$b" ] || continue
    found_branch=1
    slug=$("$SLUGIFY" branch-slug "$b")
    if [ "$slug" != "$base" ]; then
      fail "$vdir: dir name '$base' != branch-slug '$slug' (branch '$b' in $(basename "$md"))"
    fi
  done
  if [ "$found_branch" -eq 0 ]; then
    fail "$vdir: no *.md with a 'branch:' frontmatter to derive the slug from"
  else
    [ "$FAILED" -eq "$before" ] && ok "$vdir (slug matches branch)"
  fi
}

# --- run dir ------------------------------------------------------------------

validate_run_dir() {
  dir="${1%/}"
  if [ ! -d "$dir" ]; then fail "$dir: not a directory"; return; fi
  validate_spec "$dir/SPEC.md"
  [ -f "$dir/PLAN.md" ] && validate_plan "$dir/PLAN.md"
}

# --- main ---------------------------------------------------------------------

if [ "${1:-}" = "--all" ]; then
  root="${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  for d in "$root"/.ai/runs/*/; do
    [ -d "$d" ] || continue
    [ -f "$d/SPEC.md" ] || continue
    validate_run_dir "$d"
  done
  for d in "$root"/.ai/verify/*/; do
    [ -d "$d" ] || continue
    validate_verify_dir "${d%/}"
  done
else
  dir="${1:-}"
  if [ -z "$dir" ]; then
    echo "usage: validate-ai-artifacts.sh <run-dir> | --all [root]" >&2
    exit 1
  fi
  validate_run_dir "$dir"
fi

exit $FAILED
