#!/usr/bin/env bash
# Self-test for new-run.sh: the run-folder name and SPEC frontmatter (run / ticket / status /
# created / branch) are the deterministic spine dw-resume and the artifact validator rely on, yet
# nothing pinned them. This asserts that spine directly — happy path, ticketless, no-clobber, usage
# guard, and the stdout contract (last line = the run dir callers consume).
#
# Each case runs in a throwaway git repo (the script derives root/branch from git). $SLUG_DATE pins
# the date so the run-id is exact. macOS resolves the mktemp /var -> /private/var symlink in
# `git rev-parse --show-toplevel`, so the stdout-contract check matches a suffix + existence rather
# than string-comparing the mktemp path.
#
# Run standalone (`bash scripts/tests/new-run.test.sh`) or via scripts/validate-artifacts.sh.
# Exit 0 iff every case matches. bash 3.2 / macOS + BSD safe.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
NEW_RUN="$ROOT/scripts/runtime/new-run.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/new-run-selftest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }

# mk_repo <branch> — fresh git repo on <branch> with one commit (so HEAD is born and the branch
# name is reliable). Signing is forced off: the dev's global config SSH-signs every commit.
mk_repo() {
  d="$(mktemp -d "$tmp/repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@example.com -c user.name=test -c commit.gpgsign=false \
    commit --allow-empty -q -m init
  git -C "$d" switch -q -c "$1"
  echo "$d"
}

# run_newrun <repo> <ticket> <desc> — sets RC and OUT (last stdout line) from new-run.sh.
run_newrun() {
  r="$1"; shift
  (cd "$r" && SLUG_DATE=20260620 "$NEW_RUN" "$@") >"$tmp/out" 2>/dev/null
  RC=$?
  OUT="$(tail -1 "$tmp/out")"
}

# fm_eq <spec> <exact-line> <name> — frontmatter must contain that full line verbatim.
fm_eq() {
  if grep -Fxq "$2" "$1" 2>/dev/null; then note_pass "$3"; else note_fail "$3" "missing '$2' in $1"; fi
}

echo "happy path (ticket ABC-123, branch feature-x, SLUG_DATE=20260620):"
repo="$(mk_repo feature-x)"
run_newrun "$repo" "ABC-123" "add foo"
spec="$repo/.ai/runs/20260620-abc-123-add-foo/SPEC.md"
if [ "$RC" -eq 0 ] && [ -f "$spec" ]; then
  note_pass "created"
else
  note_fail "created" "rc=$RC spec=$([ -f "$spec" ] && echo present || echo missing)"
fi
fm_eq "$spec" "run: 20260620-abc-123-add-foo" "fm-run"
fm_eq "$spec" "ticket: ABC-123"               "fm-ticket-case-preserved"
fm_eq "$spec" "status: draft"                 "fm-status"
fm_eq "$spec" "created: 2026-06-20"           "fm-created"
fm_eq "$spec" "branch: feature-x"             "fm-branch"
# stdout contract: last line is an absolute run dir that exists (suffix-match; see header re: symlink).
case "$OUT" in
  /*/.ai/runs/20260620-abc-123-add-foo) [ -d "$OUT" ] && note_pass "stdout-contract" || note_fail "stdout-contract" "OUT not a dir: '$OUT'" ;;
  *) note_fail "stdout-contract" "OUT='$OUT'" ;;
esac

echo "ticketless (empty ticket -> ticket: none, no ticket segment in run-id):"
repo="$(mk_repo feature-y)"
run_newrun "$repo" "" "add foo"
spec="$repo/.ai/runs/20260620-add-foo/SPEC.md"
if [ "$RC" -eq 0 ] && [ -f "$spec" ]; then note_pass "empty-created"; else note_fail "empty-created" "rc=$RC spec missing"; fi
fm_eq "$spec" "run: 20260620-add-foo" "empty-fm-run"
fm_eq "$spec" "ticket: none"          "empty-fm-ticket"

echo "literal 'none' ticket -> same as ticketless:"
repo="$(mk_repo feature-z)"
run_newrun "$repo" "none" "add foo"
spec="$repo/.ai/runs/20260620-add-foo/SPEC.md"
if [ "$RC" -eq 0 ] && [ -f "$spec" ]; then note_pass "none-created"; else note_fail "none-created" "rc=$RC spec missing"; fi
fm_eq "$spec" "ticket: none" "none-fm-ticket"

echo "no-clobber (re-run identical args -> exit 1, SPEC untouched):"
repo="$(mk_repo feature-clobber)"
run_newrun "$repo" "ABC-123" "add foo"
spec="$repo/.ai/runs/20260620-abc-123-add-foo/SPEC.md"
before="$(cat "$spec" 2>/dev/null)"
run_newrun "$repo" "ABC-123" "add foo"
after="$(cat "$spec" 2>/dev/null)"
if [ "$RC" -ne 0 ] && [ -n "$before" ] && [ "$before" = "$after" ]; then
  note_pass "no-clobber"
else
  note_fail "no-clobber" "rc=$RC mutated=$([ "$before" = "$after" ] && echo no || echo yes)"
fi

echo "usage guard (missing <desc> -> exit 1, nothing created):"
repo="$(mk_repo feature-usage)"
(cd "$repo" && "$NEW_RUN" "ABC-123") >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ]; then note_pass "usage-exit"; else note_fail "usage-exit" "expected non-zero"; fi
if [ -z "$(ls -A "$repo/.ai/runs" 2>/dev/null)" ]; then note_pass "usage-no-dir"; else note_fail "usage-no-dir" "a run dir was created"; fi

echo
echo "new-run self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
