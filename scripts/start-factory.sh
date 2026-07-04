#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p state/logs state/runs
if command -v docker >/dev/null 2>&1; then
  docker compose up -d || true
fi
nohup bash "$ROOT_DIR/scripts/poll-loop.sh" > "$ROOT_DIR/state/logs/poll-loop.log" 2>&1 &
echo $! > "$ROOT_DIR/state/poll-loop.pid"
echo "Factory iniciada. PID: $(cat "$ROOT_DIR/state/poll-loop.pid")"
