#!/usr/bin/env bash
# Remove all Docker images and build cache so the next run starts cold
set -euo pipefail
docker system prune -af
docker builder prune -af