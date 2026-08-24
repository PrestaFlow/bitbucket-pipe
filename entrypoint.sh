#!/usr/bin/env bash
#
# PrestaFlow Bitbucket Pipe entrypoint.
# Bitbucket mounts the repository at $BITBUCKET_CLONE_DIR and runs the pipe container
# with that dir as CWD; we cd into it explicitly for robustness and expose it as
# PRESTAFLOW_WORKSPACE for all downstream scripts.
#
set -euo pipefail

WORKSPACE="${BITBUCKET_CLONE_DIR:-$PWD}"
cd "$WORKSPACE"

# Map the Pipe's declared variables (from pipe.yml) onto the PRESTAFLOW_* names used
# by the shell scripts. This mirrors the input surface of the GitHub Action and the
# GitLab component so behaviour stays uniform across CIs.
export PRESTAFLOW_TOKEN="${TOKEN:-${PRESTAFLOW_TOKEN:-}}"
export PRESTAFLOW_PROJECT_ID="${PROJECT_ID:-${PRESTAFLOW_PROJECT_ID:-}}"
export PRESTAFLOW_API_URL="${API_URL:-https://api.prestaflow.io}"
export PRESTAFLOW_EXECUTE="${EXECUTE:-true}"
export PRESTAFLOW_SUITES="${SUITES:-}"
export PRESTAFLOW_FLASHLIGHT="${FLASHLIGHT:-false}"
export PRESTAFLOW_PS_VERSION="${PS_VERSION:-latest}"
export PRESTAFLOW_FLASHLIGHT_MOUNT="${FLASHLIGHT_MOUNT:-auto}"
export PRESTAFLOW_FLASHLIGHT_INIT_SCRIPTS="${FLASHLIGHT_INIT_SCRIPTS:-}"
export PRESTAFLOW_PR_COMMENT="${PR_COMMENT:-}"
export PRESTAFLOW_UPLOAD_ARTIFACTS="${UPLOAD_ARTIFACTS:-true}"
export PRESTAFLOW_VISUAL="${VISUAL:-true}"
export PRESTAFLOW_WORKSPACE="$WORKSPACE"
export BITBUCKET_ACCESS_TOKEN="${BITBUCKET_ACCESS_TOKEN:-}"

if [ -z "$PRESTAFLOW_TOKEN" ]; then
  echo "prestaflow: variable TOKEN is required (add a masked repository variable and pass it as \$PRESTAFLOW_TOKEN)."
  exit 1
fi

# Fresh shared state file — every script appends KEY=VALUE lines that we later expose
# to downstream steps via $BITBUCKET_PIPE_SHARED_STORAGE_DIR.
: > "$WORKSPACE/prestaflow.env"

echo "prestaflow: workspace=$WORKSPACE api=$PRESTAFLOW_API_URL"

bash /opt/pipe/scripts/flashlight.sh
bash /opt/pipe/scripts/visual-download.sh
bash /opt/pipe/scripts/runner.sh
bash /opt/pipe/scripts/upload.sh
bash /opt/pipe/scripts/comment-pr.sh

# outputs.sh exits non-zero when tests failed, so it must run last.
bash /opt/pipe/scripts/outputs.sh
