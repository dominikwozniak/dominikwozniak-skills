#!/bin/bash
# PreToolUse Bash hook — blocks dangerous git operations.
# Reads tool_input.command from stdin (Claude Code hook protocol).
# Exit 2 + stderr message causes Claude to see the block and self-correct.
# Adapted from mattpocock/skills/skills/misc/git-guardrails-claude-code.

set -uo pipefail

command -v jq >/dev/null || exit 0

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

[[ -z "$COMMAND" ]] && exit 0

DANGEROUS_PATTERNS=(
  "git push --force"
  "git push -f"
  "git reset --hard"
  "git clean -f"
  "git clean -fd"
  "git clean -df"
  "git branch -D"
  "git checkout \\."
  "git restore \\."
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. Refused by claude-kit guardrail. If you genuinely need this, the user must run it manually." >&2
    exit 2
  fi
done

exit 0
