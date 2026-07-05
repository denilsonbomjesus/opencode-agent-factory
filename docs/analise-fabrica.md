# Análise Técnica — OpenCode Agent Factory

> Data: julho de 2026
> Objetivo: revisão completa do projeto, seus scripts, agentes, configuração e arquitetura.

---

## Resumo

Projeto bem construído, funcional e que entrega valor real rodando **localmente com custo zero**. A arquitetura é enxuta, os agentes Markdown são minimalistas e o fluxo polling → implementação → validação → git está coeso. Abaixo, a análise separada em **correções necessárias**, **melhorias recomendadas** e **pontos fortes**.

---

## 🔴 Correções necessárias

### 1. `install-cron.sh` vs `start-factory.sh` — duplicação de polling

O `install-cron.sh` cria duas entradas:

```
@reboot bash start-factory.sh       → inicia poll-loop.sh em background
*/5 * * * * bash sync-queue.sh      → também chama sync-queue.sh
```

Isso significa que a fila é varrida **duas vezes** a cada ciclo:
- pelo `poll-loop.sh` (background)
- pelo cron a cada 5 minutos

Além disso, o `@reboot` e o cron `*/5` podem conflitar — quando a máquina reinicia, o `@reboot` sobe o `poll-loop.sh`, e 5 minutos depois o cron também dispara `sync-queue.sh`.

**Problema:** não é um bug grave, mas gera logs duplicados e duas execuções concorrentes.

**Solução:** Decida uma estratégia — ou só cron, ou só background loop. Sugiro manter só o cron (`*/5 * * * *`), que é mais simples e auto-recuperável (não precisa de PID file, não morre silenciosamente).

---

### 2. `run-pipeline.sh` não valida variáveis obrigatórias

O script faz `source "$REPO_ENV_FILE"` e depois usa as variáveis, mas **nunca valida se `REPO_OWNER`, `REPO_NAME` e `LOCAL_PATH` existem**. Se o usuário criar um `.repo.env` incompleto, o erro vai aparecer em algum lugar obscuro — talvez no `gh_api`, talvez no `cd "$LOCAL_PATH"`.

```bash
# Sugestão: adicionar antes de usar as variáveis
[ -n "${REPO_OWNER:-}" ] || fail "REPO_OWNER não definido em $REPO_ENV_FILE"
[ -n "${REPO_NAME:-}" ] || fail "REPO_NAME não definido em $REPO_ENV_FILE"
[ -n "${LOCAL_PATH:-}" ] || fail "LOCAL_PATH não definido em $REPO_ENV_FILE"
[ -d "${LOCAL_PATH:-}" ] || fail "LOCAL_PATH não é um diretório: $LOCAL_PATH"
```

---

### 3. `sync-queue.sh` processa apenas 1 tarefa por ciclo

```bash
break   # ← depois de processar a primeira tarefa, sai do loop
```

O loop `for repo_file in ...` tem um `break` no final, o que significa que **apenas 1 task de 1 repo é processada por ciclo**. Se você tiver 5 repositórios com issues pendentes, só 1 será processado. O resto fica na fila até o próximo ciclo.

Se isso é intencional (evitar concorrência), vale documentar. Se não for, o `break` deveria ser removido ou reposicionado.

---

### 4. `common.sh` — `gh_api` sem fallback com erro descritivo

Se `gh` não estiver instalado e `GITHUB_TOKEN` também não estiver definido, a mensagem de erro será `GITHUB_TOKEN ausente`, o que pode ser confuso quando o usuário configurou o `gh auth login` (que é o caminho recomendado).

```bash
gh_api(){
  local endpoint="$1"
  if command -v gh >/dev/null 2>&1; then
    gh api "$endpoint"
  else
    curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN:?GITHUB_TOKEN ausente}" ...
  fi
}
```

Se o `gh` existe mas não está autenticado, o erro do `gh` vai ser genérico. E se o curl falha, o `-fsSL` não dá informação útil.

---

### 5. `doctor.sh` valida OpenCode mas não valida a sintaxe dos `.repo.env`

O doctor verifica se as ferramentas existem e se `.env` existe, mas **não valida os arquivos de repositório** — se um `REPO_OWNER` está em branco, se `LOCAL_PATH` existe, se o `.repo.env` tem a sintaxe mínima.

---

## 🟡 Melhorias recomendadas

### 6. Tratamento de erro no `run_cmd`

```bash
run_cmd() {
  local label="$1"
  local cmd="$2"
  [ -n "$cmd" ] || return 0
  log "$label: $cmd"
  bash -lc "$cmd"    # ← se falhar, o erro é ignorado porque não tem "|| fail"
}
```

Se o `set -e` estiver ativo, um comando que falhe dentro de `bash -lc` pode não propagar o erro corretamente. Isso significa que **se o teste falhar, o pipeline continua como se nada tivesse acontecido**, vai comitar, fazer push e abrir PR com código quebrado.

**Solução:**

```bash
run_cmd() {
  local label="$1"
  local cmd="$2"
  [ -n "$cmd" ] || return 0
  log "$label: $cmd"
  bash -lc "$cmd" || fail "$label falhou"
}
```

---

### 7. `REVIEW_BEFORE_PUSH=true` nos limits.env mas não implementado

A config tem:

```
REVIEW_BEFORE_PUSH=true
```

Mas em nenhum lugar do `run-pipeline.sh` ou `sync-queue.sh` essa variável é lida. O fluxo sempre vai de `@make` → `@test` → commit/push sem uma pausa para revisão humana.

---

### 8. `docker-compose.yml` — imagem pesada para o propósito

```yaml
command: >-
  bash -lc "apt-get update && apt-get install -y git curl jq unzip zip python3 python3-venv make gcc g++ && ..."
```

O Docker instala `make gcc g++` que não são usados em lugar nenhum do projeto. Além disso, o `apt-get update` roda **toda vez que o container sobe**, o que é lento e desnecessário — poderia ser um `Dockerfile` separado.

---

### 9. Falta de validação de labels e permissões

O `sync-queue.sh` tenta `gh issue edit` (remover/adicionar labels) mas não valida se as labels existem no repositório. Se alguma label não existir, o comando falha silenciosamente com `|| true`. Seria melhor logar um aviso.

---

### 10. Logs sem rotação

Logs vão para `state/logs/` com nome baseado em data/hora. Não há rotação ou limpeza. Dependendo do volume, isso pode encher o disco com o tempo.

**Sugestão:** Adicionar um comando opcional de cleanup no `scripts/doctor.sh` ou um:

```bash
find state/logs -name '*.log' -mtime +30 -delete
```

---

## 🟢 Pontos fortes (boas práticas que o projeto já acerta)

| Prática | Status |
|---------|--------|
| **Separação de configuração** (`.env` global + `*.repo.env` por repo) | ✅ Excelente |
| **Agentes minimalistas** — arquivos Markdown curtos, sem firula, cada um com um papel claro | ✅ Destaque do projeto |
| **Pipeline sequencial com auto-healing** (OpenCode → testa, se falha → volta pro OpenCode) | ✅ Bem pensado |
| **Não depender de GitHub Actions pagos** — tudo local, polling via shell | ✅ Economia real |
| **Variáveis com fallback seguro** `${VAR:-}` e `[ -n "$cmd" ] || return 0` | ✅ Bem feito |
| **Uso de labels para estado da fila** (ai-run → ai-running → ai-done/ai-blocked) | ✅ Clara e rastreável |
| **Commit prefix configurável** + mensagem descritiva | ✅ Detalhe que faz diferença |
| **`.gitignore` bem configurado** — protege `.env`, `state/`, `repos/*.repo.env` | ✅ Segurança |
| **Shellcheck source seguro** (`"$(cd "$(dirname "$0")" && pwd)/common.sh"`) | ✅ Robusto |
| **Factory thread-safe** com `MAX_PARALLEL_TASKS=1` e lock implícito | ✅ Evita caos |
| **Documentação README completa em Português** | ✅ Acima da média |
| **Templates de repositório** (`templates/repo/`) | ✅ Visão de longo prazo |

---

## 📊 Arquitetura resumida

```
Issue com label ai-run
        ↓
sync-queue.sh (polling via cron ou loop)
        ↓
run-pipeline.sh
   ├─ OpenCode (implementa via prompt)
   ├─ Shell roda TEST_COMMAND (se existir)
   ├─ Shell roda LINT_COMMAND  (se existir)
   ├─ Shell roda FORMAT_COMMAND (se existir)
   ├─ Git: add, commit, push
   └─ GitHub CLI: PR, comentário, merge
```

Princípios de design:
- **Baixo custo** → modelos gratuitos do OpenRouter
- **Baixo consumo de tokens** → agentes curtos, contexto pequeno (12k tokens)
- **Simplicidade operacional** → shell script puro, sem frameworks
- **Resiliência** → fila persistida no GitHub, nada se perde se a máquina desligar

---

## 🎯 Prioridades recomendadas

1. **Corrigir o `run_cmd` sem tratamento de erro** (item 6) — pode comitar código quebrado sem perceber
2. **Validar variáveis obrigatórias no `run-pipeline.sh`** (item 2) — mais segurança ao criar novos repos
3. **Resolver a duplicação de polling** (item 1) — escolher entre cron ou loop
4. **Remover o `break` do `sync-queue.sh` ou documentar** (item 3)
5. **Adicionar limpeza de logs** (item 10)

---

*Análise gerada em julho de 2026 após revisão completa do código-fonte.*
