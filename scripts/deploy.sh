#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/pinned.env"

RESULTS="${RESULTS_FILE:-$ROOT/results/stages.csv}"
TAG="${IMAGE_TAG:-bench}"
CLUSTER="${EKS_CLUSTER:-project-01-saleor-eks}"
mkdir -p "$(dirname "$RESULTS")"

stage() {
  local name="$1"; shift
  local start end
  start=$(date +%s.%N)
  "$@"
  end=$(date +%s.%N)
  echo "${PIPELINE_TOOL:-local},${SCENARIO:-warm},${RUN_ID:-0},${name},$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.2f", e-s}')" >> "$RESULTS"
}

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"

update_kubeconfig() {
  aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION" > /dev/null
}

deploy() {
  helm upgrade --install saleor "$ROOT/deploy/helm/saleor-stack" -n saleor \
    --set api.image="$REGISTRY/$ECR_API_REPO:$TAG" \
    --set worker.image="$REGISTRY/$ECR_API_REPO:$TAG" \
    --set dashboard.image="$REGISTRY/$ECR_DASHBOARD_REPO:$TAG" \
    --wait --timeout 15m
}

stage kubeconfig update_kubeconfig
stage deploy     deploy