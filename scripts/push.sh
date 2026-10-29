#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/pinned.env"

RESULTS="${RESULTS_FILE:-$ROOT/results/stages.csv}"
TAG="${IMAGE_TAG:-bench}"
mkdir -p "$(dirname "$RESULTS")"

stage() {
  local name="$1"; shift
  local start end
  start=$(date +%s.%N)
  "$@"
  end=$(date +%s.%N)
  echo "${PIPELINE_TOOL:-local},${RUN_ID:-0},${name},$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.2f", e-s}')" >> "$RESULTS"
}

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"

ecr_login() {
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"
}

push_image() {
  local local_name="$1" repo="$2"
  docker tag "$local_name:$TAG" "$REGISTRY/$repo:$TAG"
  docker push "$REGISTRY/$repo:$TAG"
}

stage ecr_login     ecr_login
stage push_api       push_image saleor-api           "$ECR_API_REPO"
stage push_dashboard push_image saleor-dashboard     "$ECR_DASHBOARD_REPO"