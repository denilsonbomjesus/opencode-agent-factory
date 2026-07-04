#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
while true; do
  bash "$ROOT_DIR/scripts/sync-queue.sh" || true
  sleep "${POLL_INTERVAL_SECONDS:-300}"
done
