#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

shopt -s nullglob
repo_files=("$ROOT_DIR"/repos/*.repo.env)
[ ${#repo_files[@]} -gt 0 ] || fail "Nenhum repos/*.repo.env encontrado"

for repo_file in "${repo_files[@]}"; do
  # shellcheck disable=SC1090
  source "$repo_file"

  repo_slug="${REPO_OWNER}/${REPO_NAME}"
  queue_label="${DEFAULT_LABEL:-${QUEUE_LABEL:-ai-run}}"
  running_label="${RUNNING_LABEL:-ai-running}"
  blocked_label="${BLOCKED_LABEL:-ai-blocked}"
  done_label="${DONE_LABEL:-ai-done}"

  log "Verificando fila de ${repo_slug}"
  endpoint="repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&labels=${queue_label}&per_page=10"
  tasks_json="$(gh_api "$endpoint")"
  count="$(printf '%s' "$tasks_json" | jq 'length')"
  [ "$count" -gt 0 ] || { log "Sem tarefas pendentes"; continue; }

  number="$(printf '%s' "$tasks_json" | jq '.[0].number')"
  title="$(printf '%s' "$tasks_json" | jq -r '.[0].title')"
  kind="issue"
  if printf '%s' "$tasks_json" | jq -e '.[0].pull_request' >/dev/null 2>&1; then
    kind="pr"
  fi

  log "Tarefa capturada: #$number [$kind] $title"

  gh issue edit "$number" --repo "$repo_slug" --remove-label "$queue_label" --add-label "$running_label" >/dev/null 2>&1 || true

  if bash "$ROOT_DIR/scripts/run-pipeline.sh" "Processar ${kind} #$number de ${repo_slug}: $title" "$repo_file"; then
    gh issue edit "$number" --repo "$repo_slug" --remove-label "$running_label" --add-label "$done_label" >/dev/null 2>&1 || true
  else
    gh issue edit "$number" --repo "$repo_slug" --remove-label "$running_label" --add-label "$blocked_label" >/dev/null 2>&1 || true
    gh issue comment "$number" --repo "$repo_slug" --body "Pipeline automático falhou. Verifique os logs locais em \`state/logs\`." >/dev/null 2>&1 || true
    exit 1
  fi

  break
done