#!/usr/bin/env bash
# Self-test for find-active-run.sh: dw-resume / dw-build / dw-sync all ask it the same two
# questions — which run belongs to this branch, and (with --step) the first not-done PLAN row. That
# logic (branch match, multi-match recency tie-break, the resume-point awk) was untested, so a
# regression would silently send every resume to the wrong run. This pins each answer.
#
# Each case runs in a throwaway git repo with a synthetic .ai/runs tree. macOS resolves the mktemp
# /var -> /private/var symlink in `git rev-parse --show-toplevel`, so matches are asserted by
# basename, not by string-comparing the mktemp path. Recency is pinned with `touch -t`, never sleep.
#
# Run standalone (`bash scripts/tests/find-active-run.test.sh`) or via scripts/validate-artifacts.sh.
# Exit 0 iff every case matches. bash 3.2 / macOS + BSD safe.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FIND="$ROOT/scripts/runtime/find-active-run.sh"
. "$ROOT/scripts/tests/fixtures.sh" # good_plan_done, plan_bad_header

tmp="$(mktemp -d "${TMPDIR:-/tmp}/find-active-run-selftest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }

# mk_repo <branch> — fresh git repo on <branch> with one commit (born HEAD = reliable branch name).
# Signing forced off (the dev's global config SSH-signs every commit).
mk_repo() {
  d="$(mktemp -d "$tmp/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@example.com -c user.name=test -c commit.gpgsign=false \
    commit --allow-empty -q -m init
  git -C "$d" switch -q -c "$1"
  echo "$d"
}

# add_spec <repo> <run-id> <branch-value> — write a SPEC.md (only `branch:` matters here); echo dir.
add_spec() {
  rd="$1/.ai/runs/$2"
  mkdir -p "$rd"
  printf '%s\n' '---' "run: $2" 'ticket: none' 'status: ready' 'created: 2026-06-20' \
    "branch: $3" '---' '' '# Spec — fixture' >"$rd/SPEC.md"
  echo "$rd"
}

# run_find <repo> [--step] — sets RC, OUT (stdout), and writes stderr to $tmp/err.
run_find() {
  r="$1"; shift
  OUT="$((cd "$r" && "$FIND" "$@") 2>"$tmp/err")"
  RC=$?
}

out_has() { case "$OUT" in *"$1"*) note_pass "$2" ;; *) note_fail "$2" "OUT lacks '$1': [$OUT]" ;; esac; }

echo "branch matching:"
repo="$(mk_repo feature-x)"
add_spec "$repo" "20260620-x" "feature-x" >/dev/null
run_find "$repo"
if [ "$RC" -eq 0 ] && [ "$(basename "$OUT")" = "20260620-x" ]; then
  note_pass "single-match"
else
  note_fail "single-match" "rc=$RC out=$(basename "$OUT")"
fi

repo="$(mk_repo other-branch)"
add_spec "$repo" "20260620-x" "feature-x" >/dev/null # branch value != current branch
run_find "$repo"
if [ "$RC" -ne 0 ]; then note_pass "no-match-exit1"; else note_fail "no-match-exit1" "expected non-zero"; fi

repo="$(mk_repo feature-x)" # repo with no .ai/runs at all
run_find "$repo"
if [ "$RC" -ne 0 ]; then note_pass "no-runs-dir-exit1"; else note_fail "no-runs-dir-exit1" "expected non-zero"; fi

echo "multi-match recency (most-recently-modified wins, warns on stderr):"
repo="$(mk_repo feature-x)"
add_spec "$repo" "20260620-old" "feature-x" >/dev/null
add_spec "$repo" "20260620-new" "feature-x" >/dev/null
touch -t 202606200000 "$repo/.ai/runs/20260620-old" # older dir mtime
touch -t 202606201200 "$repo/.ai/runs/20260620-new" # newer dir mtime -> should win
run_find "$repo"
if [ "$RC" -eq 0 ] && [ "$(basename "$OUT")" = "20260620-new" ]; then
  note_pass "multi-match-recency"
else
  note_fail "multi-match-recency" "rc=$RC out=$(basename "$OUT")"
fi
if grep -q "runs match" "$tmp/err"; then note_pass "multi-match-warns"; else note_fail "multi-match-warns" "no stderr warning"; fi

echo "--step resume point:"
repo="$(mk_repo feature-x)"
rd="$(add_spec "$repo" "20260620-step" "feature-x")"
{
  printf '%s\n' '---' 'run: 20260620-step' 'spec: ./SPEC.md' 'status: doing' '---' '' '# Plan'
  printf '%s\n' '| Phase | Step | Title | Status | Commit |' '| --- | --- | --- | --- | --- |'
  printf '%s\n' '| 1 | 1.1 | first | done | abc1234 |' '| 1 | 1.2 | second | todo |  |'
} >"$rd/PLAN.md"
run_find "$repo" --step
out_has "step: 1.2"     "step-first-not-done-id"
out_has "status: todo"  "step-first-not-done-status"
out_has "title: second" "step-first-not-done-title"

repo="$(mk_repo feature-x)"
rd="$(add_spec "$repo" "20260620-alldone" "feature-x")"
good_plan_done >"$rd/PLAN.md" # single row, done
run_find "$repo" --step
out_has "step: none (all steps done)" "step-all-done"

repo="$(mk_repo feature-x)"
add_spec "$repo" "20260620-noplan" "feature-x" >/dev/null # SPEC but no PLAN.md
run_find "$repo" --step
out_has "step: none (no PLAN.md yet" "step-no-plan"

repo="$(mk_repo feature-x)"
rd="$(add_spec "$repo" "20260620-badtable" "feature-x")"
plan_bad_header >"$rd/PLAN.md" # status table missing the Commit column
run_find "$repo" --step
if [ "$RC" -eq 3 ]; then note_pass "step-malformed-table-exit3"; else note_fail "step-malformed-table-exit3" "rc=$RC (want 3)"; fi

echo
echo "find-active-run self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
