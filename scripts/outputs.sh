#!/usr/bin/env bash
#
# Aggregate final counters from results.json and expose them:
#  - printed to stdout (visible in the pipeline UI),
#  - appended to $BITBUCKET_WORKSPACE/prestaflow.env (source-able in downstream steps
#    that keep the workspace via `artifacts:`),
#  - copied into $BITBUCKET_PIPE_SHARED_STORAGE_DIR so subsequent pipes in the same
#    step can consume them without needing artifacts wiring.
#
# Exits non-zero when any test failed — this is what turns the whole pipeline red.
#
set -euo pipefail

WORKSPACE="${PRESTAFLOW_WORKSPACE:-$PWD}"
cd "$WORKSPACE"

RESULTS=""
for c in tests/prestaflow/results.json prestaflow/results.json; do
  if [ -f "$c" ]; then RESULTS="$c"; break; fi
done

if [ -n "$RESULTS" ]; then
  STATS=$(jq '
    def tonum(x): (x // 0 | tonumber? // 0);
    def acc(s): s as $s |
      { passed: ($s.stats.passes | tonum(.)),
        failed: ($s.stats.failures | tonum(.)),
        skipped: (($s.stats.skips | tonum(.)) + ($s.stats.skippeds | tonum(.))),
        todos: ($s.stats.todos | tonum(.)),
        durationMs: ($s.stats.time | tonum(.)) };
    (if (.suites | type == "array") then [ .suites[] | acc(.) ]
     elif .stats then [ acc(.) ]
     else [] end)
    | { passed: ([.[].passed] | add // 0),
        failed: ([.[].failed] | add // 0),
        skipped: ([.[].skipped] | add // 0),
        todos: ([.[].todos] | add // 0),
        durationMs: ([.[].durationMs] | add // 0) }
    | .total = (.passed + .failed + .skipped + .todos)
  ' "$RESULTS")
else
  STATS='{"passed":0,"failed":0,"skipped":0,"total":0,"durationMs":0}'
  echo "outputs: no results.json — writing zero counters"
fi

PASSED=$(echo "$STATS" | jq -r '.passed')
FAILED=$(echo "$STATS" | jq -r '.failed')
SKIPPED=$(echo "$STATS" | jq -r '.skipped')
TOTAL=$(echo "$STATS" | jq -r '.total')
DURATION_MS=$(echo "$STATS" | jq -r '.durationMs')

STATUS="success"
[ "$FAILED" != "0" ] && STATUS="failure"

{
  echo "PRESTAFLOW_PASSED=${PASSED}"
  echo "PRESTAFLOW_FAILED=${FAILED}"
  echo "PRESTAFLOW_SKIPPED=${SKIPPED}"
  echo "PRESTAFLOW_TOTAL=${TOTAL}"
  echo "PRESTAFLOW_DURATION_MS=${DURATION_MS}"
  echo "PRESTAFLOW_STATUS=${STATUS}"
} >> "$WORKSPACE/prestaflow.env"

# Mirror to shared-storage so `pipe:`-only consumers (no artifact wiring) can see it.
if [ -n "${BITBUCKET_PIPE_SHARED_STORAGE_DIR:-}" ]; then
  cp -f "$WORKSPACE/prestaflow.env" "$BITBUCKET_PIPE_SHARED_STORAGE_DIR/prestaflow.env" 2>/dev/null || true
fi

echo "outputs: total=${TOTAL} passed=${PASSED} failed=${FAILED} skipped=${SKIPPED} status=${STATUS}"

if [ "$FAILED" != "0" ]; then
  echo "outputs: ${FAILED} test(s) failed — exiting non-zero"
  exit 1
fi
