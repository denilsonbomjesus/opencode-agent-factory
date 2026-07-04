#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT_DIR/state/logs"
( crontab -l 2>/dev/null; echo "@reboot bash $ROOT_DIR/scripts/start-factory.sh"; echo "*/5 * * * * bash $ROOT_DIR/scripts/sync-queue.sh >> $ROOT_DIR/state/logs/cron-sync.log 2>&1" ) | crontab -
echo "Crontab instalada"
