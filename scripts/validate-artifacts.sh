#!/usr/bin/env bash
# Validate the repo's .ai/ work artifacts against the structural schema, then run
# the validator's self-test (synthetic good/malformed cases prove the gate accepts
# valid artifacts and rejects malformed ones). Backs `pnpm validate:artifacts` and
# the validate-ai-artifacts CI workflow.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VALIDATOR="$ROOT/plugins/dw-planning/scripts/validate-ai-artifacts.sh"
SELFTEST="$ROOT/scripts/tests/validate-artifacts.test.sh"

FAILED=0

if [ ! -x "$VALIDATOR" ]; then
  echo "::error::missing or non-executable validator: $VALIDATOR"
  exit 1
fi

echo "Validating repo .ai/ artifacts..."
if "$VALIDATOR" --all "$ROOT"; then
  echo "OK  repo .ai/ artifacts valid"
else
  echo "::error::repo .ai/ artifacts failed schema validation"
  FAILED=1
fi

echo
echo "Running validator self-test..."
bash "$SELFTEST" || FAILED=1

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All artifact checks passed."
else
  echo "Artifact validation FAILED."
fi
exit $FAILED
