#!/usr/bin/env bash
# Validate every marketplace.json + plugin.json via Claude CLI,
# then verify version sync between marketplace.json[].version and
# each <source>/.claude-plugin/plugin.json.version.
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
echo "Checking plugin-level shared scripts..."
# plan-status.sh is shared across dw-planning's skills via ${CLAUDE_PLUGIN_ROOT}; it lives
# once at the plugin root, so just assert it exists and is executable.
PS_SHARED="plugins/dw-planning/scripts/plan-status.sh"
if [ ! -f "$PS_SHARED" ]; then
  echo "::error::missing shared script: $PS_SHARED"
  FAILED=1
elif [ ! -x "$PS_SHARED" ]; then
  echo "::error::$PS_SHARED is not executable (chmod +x)"
  FAILED=1
else
  echo "OK  $PS_SHARED (present, executable)"
fi

exit $FAILED
