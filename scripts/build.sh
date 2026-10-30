#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/pinned.env"

WORK="${WORK_DIR:-$ROOT/work}"
RESULTS="${RESULTS_FILE:-$ROOT/results/stages.csv}"
TAG="${IMAGE_TAG:-bench}"
mkdir -p "$WORK" "$(dirname "$RESULTS")"

# Cold scenario: wipe Docker images and build cache first (not timed)
if [ "${SCENARIO:-warm}" = "cold" ]; then
  bash "$ROOT/scripts/clean.sh"
fi

# Run a command and append "tool,scenario,run_id,stage,seconds" to the results CSV
stage() {
  local name="$1"; shift
  local start end
  start=$(date +%s.%N)
  "$@"
  end=$(date +%s.%N)
  echo "${PIPELINE_TOOL:-local},${SCENARIO:-warm},${RUN_ID:-0},${name},$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.2f", e-s}')" >> "$RESULTS"
}

# Fetch one exact commit (same source for every tool)
fetch_source() {
  local repo="$1" sha="$2" dir="$3"
  rm -rf "$dir"; mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$repo"
  git -C "$dir" fetch -q --depth 1 origin "$sha"
  git -C "$dir" checkout -q FETCH_HEAD
}

stage checkout_saleor    fetch_source "$SALEOR_REPO"    "$SALEOR_SHA"    "$WORK/saleor"
stage checkout_dashboard fetch_source "$DASHBOARD_REPO" "$DASHBOARD_SHA" "$WORK/saleor-dashboard"

stage build_api       docker build -t "saleor-api:$TAG" "$WORK/saleor"
stage build_dashboard docker build \
  --build-arg API_URL="${API_URL:-/graphql/}" \
  --build-arg APP_MOUNT_URI="${APP_MOUNT_URI:-/dashboard/}" \
  -t "saleor-dashboard:$TAG" "$WORK/saleor-dashboard"