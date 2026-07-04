#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

refresh_shell_path() {
  local file
  for file in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$file" ]; then
      set +u
      # shellcheck disable=SC1090
      . "$file" >/dev/null 2>&1 || true
      set -u
    fi
  done
  hash -r || true
}

for cmd in git curl jq node npm; do
  need "$cmd"
done

refresh_shell_path

if command -v docker >/dev/null 2>&1; then
  docker --version >/dev/null
fi

if command -v gh >/dev/null 2>&1; then
  log "GitHub CLI: $(command -v gh)"
  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI auth: OK"
  else
    log "GitHub CLI auth: pendente (rode 'gh auth login')"
  fi
else
  log "GitHub CLI: não encontrado"
fi

if command -v opencode >/dev/null 2>&1; then
  log "OpenCode: $(command -v opencode)"
else
  log "OpenCode: não encontrado nesta sessão; tente 'source ~/.bashrc && hash -r'"
fi

[ -f "$ROOT_DIR/.env" ] || fail ".env ausente"

log "Repo env files: $(find "$ROOT_DIR/repos" -maxdepth 1 -name '*.repo.env' | wc -l | xargs)"
log "MCP config opcional: $HOME/.config/opencode-agent-factory/github.mcp.json"
log "Doctor concluído"