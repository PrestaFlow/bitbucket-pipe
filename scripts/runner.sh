#!/usr/bin/env bash
#
# Run `composer run prestaflow:json:file` in the workspace. Test failures are not
# treated as script errors — the API/upload step reports them — so we swallow the
# composer exit code and only fail on truly missing prerequisites.
#
set -euo pipefail

if [ "${PRESTAFLOW_EXECUTE:-true}" != "true" ]; then
  echo "runner: EXECUTE=false — skipping composer run"
  exit 0
fi

cd "${PRESTAFLOW_WORKSPACE:-$PWD}"

if [ ! -f composer.json ]; then
  echo "runner: no composer.json — skipping composer run"
  exit 0
fi

if ! command -v composer >/dev/null 2>&1; then
  echo "runner: composer binary not available inside the pipe image"
  exit 1
fi

SUITES="${PRESTAFLOW_SUITES:-}"
if [ -n "$SUITES" ]; then
  export PRESTAFLOW_SUITES="$SUITES"
fi

echo "runner: composer run prestaflow:json:file (suites=${SUITES:-<all>})"

# With Flashlight, flashlight.sh merged the PRESTAFLOW_* pipe variables into
# .env.local. They are removed from composer's environment, or phpdotenv
# (immutable) would skip the file's value for them (src/runner in the Action).
STRIP=()
KEYS_FILE="$PWD/.prestaflow-flashlight/dotenv-keys"
if [ -f "$KEYS_FILE" ]; then
  while IFS= read -r key; do
    if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then STRIP+=(-u "$key"); fi
  done < "$KEYS_FILE"
fi

set +e
env ${STRIP[@]+"${STRIP[@]}"} composer run prestaflow:json:file
RC=$?
set -e

if [ $RC -ne 0 ]; then
  echo "runner: composer exited $RC — parsing/uploading results anyway (test failures are reported through the API)"
fi
