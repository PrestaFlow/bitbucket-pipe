#!/usr/bin/env bash
#
# Ship results.json (plus error/visual PNGs) to PrestaFlow. The backend reads the
# `ci` multipart part to detect the CI provider — we pack Bitbucket's BITBUCKET_*
# env vars there. Visual actual/diff PNGs ride in the same multipart POST, which is
# why there's no separate visual-upload script (kept as no-op for parity).
#
set -euo pipefail

API_URL="${PRESTAFLOW_API_URL:-https://api.prestaflow.io}"
TOKEN="${PRESTAFLOW_TOKEN:-}"
PROJECT_ID="${PRESTAFLOW_PROJECT_ID:-}"
WORKSPACE="${PRESTAFLOW_WORKSPACE:-$PWD}"

cd "$WORKSPACE"

if [ -z "$TOKEN" ]; then
  echo "upload: PRESTAFLOW_TOKEN is empty — refusing to call the API"
  exit 1
fi

RESULTS=""
for c in tests/prestaflow/results.json prestaflow/results.json; do
  if [ -f "$c" ]; then RESULTS="$c"; break; fi
done

if [ -z "$RESULTS" ]; then
  echo "upload: no results.json found (looked in tests/prestaflow/, prestaflow/) — skipping upload"
  exit 0
fi

echo "upload: sending $RESULTS to $API_URL/ci/github-action"

# BITBUCKET_GIT_HTTP_ORIGIN is the repository web URL — we synthesize the pipeline
# results URL from it so the backend can link back to the run.
PIPELINE_URL=""
if [ -n "${BITBUCKET_GIT_HTTP_ORIGIN:-}" ] && [ -n "${BITBUCKET_BUILD_NUMBER:-}" ]; then
  PIPELINE_URL="${BITBUCKET_GIT_HTTP_ORIGIN%.git}/pipelines/results/${BITBUCKET_BUILD_NUMBER}"
fi

CI_JSON=$(jq -n \
  --arg bitbucket_pipelines "true" \
  --arg build_number    "${BITBUCKET_BUILD_NUMBER:-}" \
  --arg pipeline_url    "$PIPELINE_URL" \
  --arg http_origin     "${BITBUCKET_GIT_HTTP_ORIGIN:-}" \
  --arg actor           "${BITBUCKET_STEP_TRIGGERER_UUID:-}" \
  --arg commit_sha      "${BITBUCKET_COMMIT:-}" \
  --arg ref_name        "${BITBUCKET_BRANCH:-}" \
  --arg repo_slug       "${BITBUCKET_REPO_SLUG:-}" \
  --arg workspace       "${BITBUCKET_WORKSPACE:-}" \
  --arg pr_id           "${BITBUCKET_PR_ID:-}" \
  --arg repo_full_name  "${BITBUCKET_REPO_FULL_NAME:-}" \
  '{BITBUCKET_PIPELINES: $bitbucket_pipelines,
    BITBUCKET_BUILD_NUMBER: $build_number,
    BITBUCKET_PIPELINE_URL: $pipeline_url,
    BITBUCKET_GIT_HTTP_ORIGIN: $http_origin,
    BITBUCKET_STEP_TRIGGERER_UUID: $actor,
    BITBUCKET_COMMIT: $commit_sha,
    BITBUCKET_BRANCH: $ref_name,
    BITBUCKET_REPO_SLUG: $repo_slug,
    BITBUCKET_WORKSPACE: $workspace,
    BITBUCKET_PR_ID: $pr_id,
    BITBUCKET_REPO_FULL_NAME: $repo_full_name}')

FORM_ARGS=(
  -F "projectId=${PROJECT_ID}"
  -F "ci=${CI_JSON};type=application/json"
)
[ -n "${BITBUCKET_BRANCH:-}" ]         && FORM_ARGS+=(-F "branch=${BITBUCKET_BRANCH}")
[ -n "${BITBUCKET_COMMIT:-}" ]         && FORM_ARGS+=(-F "commit_sha=${BITBUCKET_COMMIT}")
[ -n "${BITBUCKET_BRANCH:-}" ]         && FORM_ARGS+=(-F "ref=refs/heads/${BITBUCKET_BRANCH}")
[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]   && FORM_ARGS+=(-F "ci_run_id=${BITBUCKET_BUILD_NUMBER}")
[ -n "${BITBUCKET_REPO_FULL_NAME:-}" ] && FORM_ARGS+=(-F "github_repository=${BITBUCKET_REPO_FULL_NAME}")

FORM_ARGS+=(-F "file[]=@${RESULTS};filename=results.json")

while IFS= read -r -d '' f; do
  FORM_ARGS+=(-F "file[]=@${f};filename=screens/$(basename "$f")")
done < <(find . -type f -path '*/prestaflow/screens/errors/*.png' -print0 2>/dev/null)

while IFS= read -r -d '' f; do
  FORM_ARGS+=(-F "file[]=@${f};filename=visual/actual/$(basename "$f")")
done < <(find . -type f -path '*/prestaflow/screens/actual/*.png' -print0 2>/dev/null)

while IFS= read -r -d '' f; do
  FORM_ARGS+=(-F "file[]=@${f};filename=visual/diff/$(basename "$f")")
done < <(find . -type f -path '*/prestaflow/screens/diff/*.png' -print0 2>/dev/null)

RESPONSE=$(curl -sS -X POST "${API_URL}/ci/github-action" \
  -H "X-Api-Token: ${TOKEN}" \
  "${FORM_ARGS[@]}" \
  --write-out '\n%{http_code}' || true)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "upload: API returned HTTP $HTTP_CODE"
  echo "$BODY" | head -c 2000
  exit 0
fi

REPORT_ID=$(echo "$BODY" | jq -r '.id // empty')
REPORT_URL=$(echo "$BODY" | jq -r '.url // empty')

echo "upload: report id=$REPORT_ID"
echo "upload: report url=$REPORT_URL"

{
  echo "PRESTAFLOW_REPORT_ID=${REPORT_ID}"
  echo "PRESTAFLOW_REPORT_URL=${REPORT_URL}"
} >> "$WORKSPACE/prestaflow.env"

# Optional: persist for downstream steps via Bitbucket's shared-storage dir.
if [ "${PRESTAFLOW_UPLOAD_ARTIFACTS:-true}" = "true" ] && [ -n "${BITBUCKET_PIPE_SHARED_STORAGE_DIR:-}" ]; then
  cp -f "$RESULTS" "$BITBUCKET_PIPE_SHARED_STORAGE_DIR/results.json" 2>/dev/null || true
fi
