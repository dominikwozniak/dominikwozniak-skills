#!/usr/bin/env bash
# Self-test for validate-ai-artifacts.sh: proves the schema gate ACCEPTS well-formed
# .ai/ artifacts and REJECTS malformed ones. Each case is built in a throwaway dir at
# run time — no committed fixture tree. Structure is base+mutation: the document builders
# (sourced from fixtures.sh) emit one canonical good doc per kind; each malformed case =
# that doc through a one-line defect here, so the defect is the diff.
#
# Run standalone (`bash scripts/tests/validate-artifacts.test.sh`) or via scripts/validate-artifacts.sh.
# Exit 0 iff every case behaves as expected. bash 3.2 / macOS + BSD-sed safe.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VALIDATOR="$ROOT/plugins/dw-planning/scripts/validate-ai-artifacts.sh"

# Document builders ("fixtures") live in a sibling file, sourced relative to this script.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/fixtures.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/ai-selftest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }

# --- case dir: a fresh .ai/runs/x with SPEC (required) + optional PLAN ---------
mk_run() {
  d="$(mktemp -d "$tmp/run.XXXXXX")"
  mkdir -p "$d/.ai/runs/x"
  printf '%s\n' "$2" >"$d/.ai/runs/x/SPEC.md"
  [ "$#" -ge 3 ] && printf '%s\n' "$3" >"$d/.ai/runs/x/PLAN.md"
  echo "$d"
}

# expect_pass <name> <spec> [plan] — discovers ≥1 artifact AND exits 0.
# The ^OK grep is the non-vacuous guard: --all exits 0 on an empty sweep, so a
# builder typo that discovers nothing must fail here loudly, not pass silently.
expect_pass() {
  d="$(mk_run "$@")"
  out="$("$VALIDATOR" --all "$d" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK'; then
    note_pass "$1"
  else
    note_fail "$1" "expected pass with a validated artifact (exit $rc)"
  fi
}

# expect_fail <name> <spec> [plan] — must exit non-zero.
expect_fail() {
  d="$(mk_run "$@")"
  if "$VALIDATOR" --all "$d" >/dev/null 2>&1; then
    note_fail "$1" "expected rejection but it passed"
  else
    note_pass "$1"
  fi
}

# expect_verify_{pass,fail} <name> <slug> <branch> — .ai/verify/<slug>/ slug check.
mk_verify() {
  d="$(mktemp -d "$tmp/verify.XXXXXX")"
  mkdir -p "$d/.ai/verify/$2"
  printf '%s\n' "$(good_review "$3")" >"$d/.ai/verify/$2/review.md"
  echo "$d"
}
expect_verify_pass() {
  d="$(mk_verify "$@")"
  out="$("$VALIDATOR" --all "$d" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK'; then
    note_pass "$1"
  else
    note_fail "$1" "expected pass (exit $rc)"
  fi
}
expect_verify_fail() {
  d="$(mk_verify "$@")"
  if "$VALIDATOR" --all "$d" >/dev/null 2>&1; then
    note_fail "$1" "expected rejection but it passed"
  else
    note_pass "$1"
  fi
}

# --- cases --------------------------------------------------------------------
echo "good (expect pass):"
expect_pass "spec-draft-only" "$(spec_draft)"
expect_pass "plan-todo" "$(good_spec)" "$(good_plan_todo)"
expect_pass "plan-done" "$(good_spec)" "$(good_plan_done)"
expect_verify_pass "verify-slug" "my-feature-branch" "my-feature-branch"

echo "malformed (expect rejection):"
expect_fail "spec-bad-status" "$(good_spec | sed 's/ready/shipping/')"
expect_fail "spec-missing-key" "$(good_spec | sed '/^branch:/d')"
expect_fail "plan-bad-status" "$(good_spec)" "$(good_plan_todo | sed 's/| todo |/| wip |/')"
expect_fail "plan-done-no-sha" "$(good_spec)" "$(good_plan_done | sed 's/abc1234//')"
expect_fail "plan-bad-header" "$(good_spec)" "$(plan_bad_header)"
expect_fail "plan-nonmonotonic" "$(good_spec)" "$(plan_nonmonotonic)"
expect_verify_fail "verify-slug-mismatch" "feature-x" "totally-different-branch"

echo
echo "self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
