#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$ROOT_DIR/state/poll-loop.pid" ]; then
  kill "$(cat "$ROOT_DIR/state/poll-loop.pid")" || true
  rm -f "$ROOT_DIR/state/poll-loop.pid"
  echo "Poll loop parado"
fi
if command -v docker >/dev/null 2>&1; then
  (cd "$ROOT_DIR" && docker compose down) || true
fi
