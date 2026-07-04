#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"
[ -f "$ROOT_DIR/config/limits.env" ] && source "$ROOT_DIR/config/limits.env"

log(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail(){ log "ERROR: $*"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "Dependência ausente: $1"; }

gh_api(){
  local endpoint="$1"
  if command -v gh >/dev/null 2>&1; then
    gh api "$endpoint"
  else
    curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN:?GITHUB_TOKEN ausente}" -H "Accept: application/vnd.github+json" "https://api.github.com/$endpoint"
  fi
}
