#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

info(){ printf '\n==> %s\n' "$*"; }
warn(){ printf '\n[WARN] %s\n' "$*"; }
fail(){ printf '\n[ERROR] %s\n' "$*"; exit 1; }

load_env() {
  local env_file
  for env_file in "$ROOT_DIR/.env" "$ROOT_DIR/.env.example"; do
    if [ -f "$env_file" ]; then
      set -a
      # shellcheck disable=SC1090
      source "$env_file"
      set +a
    fi
  done
}

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

install_pkg() {
  local pkg="$1"

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "$pkg"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "$pkg"
    return 0
  fi

  if command -v yum >/dev/null 2>&1; then
    sudo yum install -y "$pkg"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm "$pkg"
    return 0
  fi

  warn "Nenhum gerenciador compatível foi detectado automaticamente para instalar: $pkg"
  return 1
}

ensure_cmd() {
  local cmd="$1"
  local pkg="${2:-$1}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    install_pkg "$pkg" || warn "Instale manualmente '$pkg' antes de continuar."
  fi
}

ensure_cmd git git
ensure_cmd curl curl
ensure_cmd jq jq
ensure_cmd unzip unzip
ensure_cmd zip zip
ensure_cmd node nodejs
ensure_cmd npm npm

if ! command -v gh >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    install_pkg gh || warn "GitHub CLI não pôde ser instalado automaticamente."
  else
    warn "GitHub CLI não encontrado; instale manualmente se seu sistema não usar apt."
  fi
fi

if [ ! -f .env ]; then
  cp .env.example .env
  info ".env criado a partir de .env.example"
fi

load_env
mkdir -p state/logs state/runs

if [ -f package.json ]; then
  if jq -e '((.dependencies // {}) | length) > 0 or ((.devDependencies // {}) | length) > 0' package.json >/dev/null 2>&1; then
    npm install
  else
    info "package.json sem dependências locais; pulando npm install"
  fi
fi

if ! command -v opencode >/dev/null 2>&1; then
  info "OpenCode não encontrado; tentando instalador oficial"
  if curl -fsSL https://opencode.ai/install | bash; then
    refresh_shell_path
  else
    warn "Instalador oficial falhou; tentando npm"
    npm install -g "${OPENCODE_NPM_PACKAGE:-opencode-ai@latest}" || true
    refresh_shell_path
  fi
fi

if ! command -v opencode >/dev/null 2>&1; then
  fail "OpenCode não foi instalado ou ainda não está disponível nesta sessão."
fi

info "OpenCode disponível em: $(command -v opencode)"

if command -v gh >/dev/null 2>&1; then
  info "GitHub CLI disponível em: $(command -v gh)"
else
  warn "GitHub CLI continua ausente; o fluxo com API/curl pode funcionar, mas gh é recomendado."
fi

mkdir -p "$HOME/.config/opencode-agent-factory"
cp config/mcp/github.mcp.json "$HOME/.config/opencode-agent-factory/github.mcp.json"
info "Config opcional de MCP copiada para $HOME/.config/opencode-agent-factory/github.mcp.json"

cat <<MSG

Instalação base concluída.

O que já foi feito automaticamente:
- dependências básicas verificadas/instaladas quando possível
- .env criado a partir de .env.example, se ausente
- OpenCode instalado e validado
- pastas state/logs e state/runs criadas
- config opcional de MCP copiada para ~/.config/opencode-agent-factory/

Próximos passos manuais:
1. Edite $ROOT_DIR/.env
2. Crie ao menos um arquivo em repos/*.repo.env baseado em repos/example.repo.env.example
3. Autentique o GitHub CLI: gh auth login
4. Rode: bash scripts/doctor.sh
5. Inicie a fila: bash scripts/start-factory.sh

Se estiver na mesma sessão em que o OpenCode acabou de ser instalado e algo não aparecer:
source ~/.bashrc && hash -r
MSG