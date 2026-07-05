# OpenCode Agent Factory

Fábrica portátil de software autônoma baseada em agentes, pensada para WSL2/Linux, Docker sem interface, repositórios privados no GitHub, OpenCode como agente principal e providers OpenAI-like locais ou externos.

Repositório oficial deste projeto:
- <https://github.com/denilsonbomjesus/opencode-agent-factory>

## Objetivo

Este projeto foi desenhado para funcionar como uma base portátil para automação de desenvolvimento orientado por agentes.

A proposta é simples:
- GitHub é a fonte de verdade da fila de trabalho.
- A máquina local consome a fila por polling.
- O OpenCode implementa no repositório local.
- Shell, Git e GitHub CLI fazem a parte operacional crítica.
- A automação pode criar branch, commitar, fazer push, abrir PR e fazer merge conforme as flags configuradas.

## Arquitetura

```text
[Issue/PR no GitHub]
          |
          v
[label ai-run]
          |
          v
[sync-queue.sh]
          |
          v
[run-pipeline.sh]
          |
          +--> OpenCode implementa e ajusta o código
          +--> shell roda testes, lint, format e build
          +--> git cria branch, commit e push
          +--> gh cria PR, comenta na issue e faz merge se permitido
          |
          v
[ai-done | ai-blocked]
```

## Estrutura do projeto

```text
opencode-agent-factory/
├── README.md
├── .env.example
├── docker-compose.yml
├── package.json
├── agents/
│   ├── orchestrator.md
│   └── git.md
├── config/
├── docs/
├── repos/
│   └── example.repo.env.example
├── scripts/
│   ├── install.sh
│   ├── doctor.sh
│   ├── start-factory.sh
│   ├── stop-factory.sh
│   ├── install-cron.sh
│   ├── poll-loop.sh
│   ├── sync-queue.sh
│   └── run-pipeline.sh
├── state/
└── templates/
```

## Instalação a partir do GitHub

### 1. Clonar o projeto

```bash
git clone https://github.com/denilsonbomjesus/opencode-agent-factory.git ~/tools/opencode-agent-factory
cd ~/tools/opencode-agent-factory
```

### 2. Executar a instalação inicial

```bash
bash scripts/install.sh
```

Esse script foi desenhado para:
- criar `.env` a partir de `.env.example` se ele ainda não existir;
- verificar dependências de sistema;
- tentar instalar o OpenCode;
- preparar diretórios como `state/logs` e `state/runs`;
- copiar a configuração opcional de MCP do GitHub para `~/.config/opencode-agent-factory/`.

### 3. Validar o ambiente

```bash
bash scripts/doctor.sh
```

### 4. Iniciar a fábrica

```bash
bash scripts/start-factory.sh
```

### 5. Parar a fábrica

```bash
bash scripts/stop-factory.sh
```

## Como operar no dia a dia

### Iniciar o loop contínuo

```bash
bash scripts/start-factory.sh
```

Esse script sobe o `docker compose` se Docker estiver disponível e depois inicia o `poll-loop.sh` em background com `nohup`, gravando o PID em `state/poll-loop.pid`.

### Rodar apenas uma varredura da fila

```bash
bash scripts/sync-queue.sh
```

### Rodar uma tarefa manualmente

```bash
bash scripts/run-pipeline.sh "Processar issue #42 de owner/repo: Ajustar validação" repos/meu-projeto.repo.env
```

### Acompanhar logs

```bash
tail -f state/logs/poll-loop.log
tail -f state/logs/$(ls -t state/logs | head -n1)
```

## Fluxo automático atual

Com a configuração de automação habilitada, o fluxo esperado é este:

1. Você abre uma issue no GitHub.
2. Aplica a label `ai-run`.
3. O polling encontra a tarefa.
4. A label muda para `ai-running`.
5. O pipeline cria uma branch do tipo `ai/issue-<numero>-<slug>`.
6. O OpenCode implementa a mudança no repositório local.
7. O shell roda `test`, `lint`, `format` e `build` conforme configurado.
8. Se tudo ficar verde, o shell faz `git add`, `git commit`, `git push` e cria a PR.
9. A PR é aberta com `Closes #<issue>`.
10. A issue recebe comentário automático com branch, commit e link da PR.
11. Se `AUTO_MERGE_ONLY_GREEN=true`, o fluxo tenta fazer merge e remover a branch.
12. A tarefa termina com label `ai-done`, ou `ai-blocked` em caso de falha.

## Arquivos de configuração

Existem dois níveis principais de configuração:

- configuração global da fábrica, em `.env`;
- configuração de cada repositório, em `repos/*.repo.env`.

## Configuração global: `.env`

Copie o exemplo se necessário:

```bash
cp .env.example .env
nano .env
```

### Explicação de cada parâmetro

#### Identidade do projeto

```env
FACTORY_NAME=opencode-agent-factory
WORKSPACE_ROOT=$HOME/workspace
FACTORY_ROOT=$HOME/tools/opencode-agent-factory
```

- `FACTORY_NAME`: nome lógico da instalação.
- `WORKSPACE_ROOT`: diretório onde ficam os repositórios que serão alterados.
- `FACTORY_ROOT`: diretório onde esta fábrica foi instalada.

#### Loop e limites

```env
POLL_INTERVAL_SECONDS=300
MAX_RETRIES=4
MAX_RUNTIME_SECONDS=600
TARGET_CONTEXT_TOKENS=12000
MAX_PARALLEL_TASKS=1
DEFAULT_BASE_BRANCH=main
```

- `POLL_INTERVAL_SECONDS`: intervalo entre verificações da fila quando o `poll-loop.sh` está ativo.
- `MAX_RETRIES`: limite lógico de tentativas do fluxo de correção.
- `MAX_RUNTIME_SECONDS`: timeout bruto do pipeline por execução.
- `TARGET_CONTEXT_TOKENS`: alvo operacional para conter contexto e custo.
- `MAX_PARALLEL_TASKS`: mantenha `1` no começo para evitar revisão caótica.
- `DEFAULT_BASE_BRANCH`: branch padrão usada como base quando o repo não sobrescreve isso.

#### GitHub

```env
GITHUB_TOKEN=
GITHUB_OWNER=
GITHUB_REPO=
GITHUB_API_URL=https://api.github.com
```

- `GITHUB_TOKEN`: token usado por chamadas API e, em alguns casos, pelo `gh` em modo headless.
- `GITHUB_OWNER`: opcional como padrão global; útil se você concentrar tudo em uma mesma conta.
- `GITHUB_REPO`: opcional como padrão global.
- `GITHUB_API_URL`: normalmente permanece `https://api.github.com`.

#### OpenCode

```env
OPENCODE_BIN=opencode
OPENCODE_NPM_PACKAGE=opencode-ai@latest
OPENCODE_MODEL=
OPENCODE_PROVIDER=openai
```

- `OPENCODE_BIN`: nome do executável final disponível no PATH.
- `OPENCODE_NPM_PACKAGE`: pacote usado pelo instalador para instalar ou atualizar o OpenCode.
- `OPENCODE_MODEL`: modelo que o OpenCode vai usar.
- `OPENCODE_PROVIDER`: provider configurado para o protocolo compatível.

#### Providers de modelo

```env
OPENAI_BASE_URL=
OPENAI_API_KEY=
OPENROUTER_API_KEY=
GOOGLE_API_KEY=
LOCAL_OPENAI_BASE_URL=
LOCAL_OPENAI_API_KEY=
```

Use conforme o seu backend:

- OpenRouter via compatibilidade OpenAI:
  - `OPENAI_BASE_URL=https://openrouter.ai/api/v1`
  - `OPENAI_API_KEY=...`
- Google AI Studio: depende do adaptador que você estiver usando.
- Laboratório local compatível com OpenAI:
  - `LOCAL_OPENAI_BASE_URL=http://127.0.0.1:8000/v1`
  - `LOCAL_OPENAI_API_KEY=...`

Se o seu fluxo estiver usando `OPENCODE_PROVIDER=openai`, o mais importante é que o endpoint e a chave efetivamente usados pelo OpenCode estejam corretos.

#### Labels de fila e estado

```env
QUEUE_LABEL=ai-run
RUNNING_LABEL=ai-running
BLOCKED_LABEL=ai-blocked
DONE_LABEL=ai-done
MERGE_LABEL=ai-merge
```

- `QUEUE_LABEL`: tarefa pronta para entrar na fila.
- `RUNNING_LABEL`: tarefa atualmente processada.
- `BLOCKED_LABEL`: falhou e precisa de intervenção humana.
- `DONE_LABEL`: terminou com sucesso.
- `MERGE_LABEL`: opcional para políticas extras de merge.

#### Flags de automação Git/GitHub

```env
AUTO_COMMIT=true
AUTO_PUSH=true
AUTO_PR=true
AUTO_MERGE_ONLY_GREEN=true
AUTO_COMMENT_ON_ISSUE=true
AUTO_CLOSE_VIA_PR=true
AI_BRANCH_PREFIX=ai
GIT_COMMIT_PREFIX=feat
PR_MERGE_METHOD=squash
```

- `AUTO_COMMIT`: faz commit automático após validações verdes.
- `AUTO_PUSH`: faz push automático da branch.
- `AUTO_PR`: abre PR automaticamente.
- `AUTO_MERGE_ONLY_GREEN`: tenta mergear apenas no caminho verde.
- `AUTO_COMMENT_ON_ISSUE`: comenta branch, commit e PR na issue.
- `AUTO_CLOSE_VIA_PR`: a intenção operacional é fechar a issue via PR mergeada com `Closes #N`.
- `AI_BRANCH_PREFIX`: prefixo da branch automática.
- `GIT_COMMIT_PREFIX`: prefixo da mensagem de commit, por exemplo `feat`, `fix`, `chore`.
- `PR_MERGE_METHOD`: normalmente `squash`, `merge` ou `rebase`, conforme a política do repositório.

#### Identidade Git

```env
GIT_AUTHOR_NAME=OpenCode Agent Factory
GIT_AUTHOR_EMAIL=bot@example.local
```

Esses valores podem ser usados se o repositório ainda não tiver `git config user.name` e `git config user.email` definidos.

## Configuração de cada repositório: `repos/*.repo.env`

Para cada novo repositório, copie o exemplo:

```bash
cp repos/example.repo.env.example repos/meu-projeto.repo.env
nano repos/meu-projeto.repo.env
```

### Exemplo completo

```env
REPO_OWNER=denilsonbomjesus
REPO_NAME=meu-projeto
LOCAL_PATH="$HOME/projetos/meu-projeto"
BASE_BRANCH=main
TASK_KIND=pr-or-issue
TEST_COMMAND="npm test"
LINT_COMMAND="npm run lint"
FORMAT_COMMAND="npm run format"
BUILD_COMMAND="npm run build"
PR_BRANCH_PREFIX="ai/"
DEFAULT_LABEL="ai-run"
```

### O que significa cada campo

- `REPO_OWNER`: owner no GitHub.
- `REPO_NAME`: nome do repositório no GitHub.
- `LOCAL_PATH`: caminho local do clone que será modificado.
- `BASE_BRANCH`: branch-base desse repositório, por exemplo `main` ou `master`.
- `TASK_KIND`: pode servir como documentação operacional; o fluxo atual aceita issue ou PR.
- `TEST_COMMAND`: comando real de testes (opcional — pode ficar vazio).
- `LINT_COMMAND`: comando real de lint (opcional — pode ficar vazio).
- `FORMAT_COMMAND`: comando real de formatação (opcional — pode ficar vazio).
- `BUILD_COMMAND`: comando opcional de build (pode ficar vazio).
- `PR_BRANCH_PREFIX`: prefixo usado na convenção de branches.
- `DEFAULT_LABEL`: label que dispara a fila naquele repositório.

> Importante: sempre coloque comandos com espaços entre aspas. Exemplo correto: `TEST_COMMAND="npm test"`.

### E se eu quiser deixar TEST_COMMAND, LINT_COMMAND e FORMAT_COMMAND vazios?

Sim, é totalmente possível. Esses campos são **opcionais**. Você pode tanto omiti-los do arquivo quanto deixá-los vazios (`=""`).

Isso é útil quando você quer conectar um repositório novo na fábrica sem ter decidido ainda a linguagem, os testes ou as ferramentas de lint e formatação. Basta descrever na Issue exatamente o que você quer — o agente OpenCode cuida do resto.

#### O que acontece internamente

O `scripts/run-pipeline.sh` usa a sintaxe `${TEST_COMMAND:-}` no Bash. Isso significa: "use o valor da variável, ou string vazia se ela não existir". A função que executa os comandos pula automaticamente quando o valor está vazio:

```bash
run_cmd() {
  local label="$1"
  local cmd="$2"
  [ -n "$cmd" ] || return 0    # Se vazio, simplesmente ignora
  log "$label: $cmd"
  bash -lc "$cmd"
}
```

Além disso, o bloco de reteste e relint só executa se `FORMAT_COMMAND` tiver conteúdo:

```bash
if [ -n "${FORMAT_COMMAND:-}" ]; then
  run_cmd "Retest" "${TEST_COMMAND:-}"
  run_cmd "Relint" "${LINT_COMMAND:-}"
fi
```

Resultado: com os campos vazios, o pipeline simplesmente **pula todos esses passos sem erro nenhum**.

#### Como descrever os testes na própria Issue

Mesmo com comandos vazios, o agente OpenCode já recebe a instrução de criar, executar e corrigir testes. No prompt enviado pelo `run-pipeline.sh`, consta:

- Crie ou atualize testes obrigatoriamente.
- Rode e corrija até ficar verde em testes, lint e format.
- Não pergunte por autorização.

Você pode descrever na Issue exatamente como quer os testes — framework, cobertura, o que testar — que o agente implementa, executa e corrige. A validação fica por conta do próprio agente.

#### Diferença entre comandos preenchidos e vazios

| Situação | O que acontece |
|----------|----------------|
| `TEST_COMMAND="npm test"` | OpenCode cria código e testes. Depois o **shell também valida** rodando `npm test`. Dupla verificação. |
| `TEST_COMMAND=""` | OpenCode cria código e testes. A validação **fica apenas sob palavra do agente** — ele reporta `DONE`, `BLOCKED` ou `NEEDS_HUMAN`. |

#### Estratégia recomendada

1. Comece com comandos vazios e conecte o repositório.
2. Deixe o agente criar os primeiros testes e estruturas.
3. Quando o projeto amadurecer, edite o `.repo.env` e preencha os comandos reais.
4. A partir daí, o shell fará a validação dupla.

```env
# Fase 1 — início sem definir nada
TEST_COMMAND=""
LINT_COMMAND=""
FORMAT_COMMAND=""
BUILD_COMMAND=""
```

```env
# Fase 2 — projeto maduro com comandos definidos
TEST_COMMAND="npm test"
LINT_COMMAND="npm run lint"
FORMAT_COMMAND="npx prettier --write ."
BUILD_COMMAND="npm run build"
```

## Como preparar novos repositórios

Antes de adicionar um repositório na fábrica, ele precisa estar minimamente operacional para automação. Isso significa que a IA não deve ser a primeira entidade a descobrir como rodar testes básicos naquele projeto.

O repositório precisa ter, no mínimo:
- comandos reprodutíveis para testar;
- lint configurado, se você quiser bloquear estilo e problemas estáticos;
- format configurado, se quiser padronização automática;
- dependências instaladas;
- branch principal definida;
- clone local existente em `LOCAL_PATH`.

### Exemplo em JavaScript/Node

Criação rápida de projeto:

```bash
npm init -y
npm install -D vitest eslint prettier
```

No `package.json`, ajuste seus scripts para algo previsível:

```json
{
  "scripts": {
    "test": "vitest run",
    "lint": "eslint .",
    "format": "prettier --write ."
  }
}
```

### Por que esses scripts devem ser assim?

- `test`: a fábrica precisa de um comando único e direto para validar comportamento.
- `lint`: a fábrica precisa de um comando único para qualidade estática.
- `format`: a fábrica precisa de um comando único para padronização final.

O importante não é usar exatamente Vitest, ESLint e Prettier; o importante é que exista um contrato simples e estável para o shell chamar.

#### Exemplo JS mínimo

`package.json`

```json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "vitest run",
    "lint": "eslint .",
    "format": "prettier --write ."
  },
  "devDependencies": {
    "eslint": "^9.0.0",
    "prettier": "^3.0.0",
    "vitest": "^4.0.0"
  }
}
```

Se usar ESLint moderno, normalmente você também vai querer um `eslint.config.js` no formato flat config.

### Exemplo em TypeScript

```bash
npm init -y
npm install -D typescript vitest eslint prettier @typescript-eslint/parser @typescript-eslint/eslint-plugin
npx tsc --init
```

Scripts típicos:

```json
{
  "scripts": {
    "test": "vitest run",
    "lint": "eslint .",
    "format": "prettier --write .",
    "build": "tsc -p tsconfig.json"
  }
}
```

### Exemplo em Python com pytest

```bash
python -m venv .venv
source .venv/bin/activate
pip install pytest ruff black
```

Exemplo de comandos:

```env
TEST_COMMAND="pytest -q"
LINT_COMMAND="ruff check ."
FORMAT_COMMAND="black ."
BUILD_COMMAND=""
```

### Exemplo em Python com Poetry

```bash
poetry init
poetry add --group dev pytest ruff black
```

Exemplo de comandos:

```env
TEST_COMMAND="poetry run pytest -q"
LINT_COMMAND="poetry run ruff check ."
FORMAT_COMMAND="poetry run black ."
BUILD_COMMAND=""
```

### Exemplo em Go

```env
TEST_COMMAND="go test ./..."
LINT_COMMAND="golangci-lint run"
FORMAT_COMMAND="gofmt -w ."
BUILD_COMMAND="go build ./..."
```

### Exemplo em Rust

```env
TEST_COMMAND="cargo test"
LINT_COMMAND="cargo clippy --all-targets --all-features -- -D warnings"
FORMAT_COMMAND="cargo fmt"
BUILD_COMMAND="cargo build"
```

### Exemplo em PHP

```env
TEST_COMMAND="vendor/bin/phpunit"
LINT_COMMAND="vendor/bin/pint --test"
FORMAT_COMMAND="vendor/bin/pint"
BUILD_COMMAND=""
```

### Regra prática para qualquer linguagem

Se você consegue abrir o terminal no repositório e rodar manualmente os comandos abaixo sem pensar muito, então o repositório está perto do ponto ideal para a fábrica:

```bash
<teste>
<lint>
<format>
<build>
```

Se isso ainda depende de contexto implícito, aliases obscuros ou passos manuais não documentados, vale estabilizar o projeto antes de entregá-lo à automação.

## Como conseguir e configurar o `GITHUB_TOKEN`

O GitHub recomenda o uso de fine-grained personal access tokens em vez dos tokens clássicos quando possível.

### Onde criar

Página oficial de tokens do GitHub:
- <https://github.com/settings/tokens>

Documentação oficial:
- GitHub Docs — Managing your personal access tokens: <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- GitHub Docs — Permissions required for fine-grained personal access tokens: <https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens>

### Recomendação prática

Para repositórios pessoais, prefira um fine-grained token limitado apenas aos repositórios que a fábrica realmente precisa acessar.

### Permissões mínimas típicas

O conjunto exato depende do que você quer automatizar, mas em geral o fluxo precisa conseguir:
- ler e escrever conteúdo do repositório;
- criar e atualizar pull requests;
- ler e comentar em issues;
- eventualmente disparar operações relacionadas ao merge.

Ao criar o token:
1. escolha **Fine-grained token**;
2. selecione sua conta ou organização correta;
3. limite o token aos repositórios necessários;
4. defina expiração;
5. conceda apenas as permissões necessárias.

### Como configurar no `.env`

```env
GITHUB_TOKEN=cole_aqui_o_seu_token
```

Depois, recarregue o shell ou reinicie a fábrica.

## Como configurar o `gh auth login`

O GitHub CLI pode autenticar por navegador ou por token, e também respeita variáveis de ambiente para uso headless.

Documentação oficial:
- Manual do GitHub CLI: <https://cli.github.com/manual/>
- `gh auth login`: <https://cli.github.com/manual/gh_auth_login>
- Quickstart do GitHub CLI: <https://docs.github.com/en/github-cli/github-cli/quickstart>

### Modo interativo recomendado

```bash
gh auth login
```

Caminho mais comum:
1. escolha `GitHub.com`;
2. escolha o protocolo Git, geralmente `HTTPS` ou `SSH`;
3. escolha autenticação por navegador;
4. autorize no navegador;
5. confirme com:

```bash
gh auth status
```

### Modo por token

Você também pode fazer login assim:

```bash
echo "$GITHUB_TOKEN" | gh auth login --with-token
```

### Quando usar token em variável

O manual do `gh` também informa que o CLI respeita token em variável de ambiente para uso headless e automação.

## Como conferir a configuração do repositório no GitHub

### 1. Permissões do token

Verifique se o token consegue de fato atuar no repositório alvo. Se a conta usar organização, ela pode impor políticas de aprovação ou restrição de tokens.

Referências:
- GitHub Docs — Managing your personal access tokens
- GitHub Docs — Permissions required for fine-grained personal access tokens
- GitHub Docs — Setting a personal access token policy for your organization: <https://docs.github.com/en/organizations/managing-programmatic-access-to-your-organization/setting-a-personal-access-token-policy-for-your-organization>

### 2. Branch protection

Se a branch principal tiver proteção, isso pode impedir push direto e forçar merge apenas por PR com checks e reviews.

Documentação oficial:
- <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule>

O ponto importante aqui é alinhar a política do repositório com o seu fluxo automático. Se você quer a Opção B — commit, push, PR e fechamento da issue ao merge — branch protection normalmente ajuda, porque desestimula mudanças diretas na `main`.

### 3. Política de merge

Confirme no repositório se o método de merge que você configurou em `PR_MERGE_METHOD` está habilitado. Se você configurou `squash`, mas o repositório só permite `merge commit`, o passo de merge vai falhar.

Verifique em:
- Settings → General → Pull Requests

Referência:
- GitHub Docs sobre configuração de branches e merges: <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository>

### 4. Labels

Por padrão, seu fluxo usa labels como:
- `ai-run`
- `ai-running`
- `ai-blocked`
- `ai-done`

Você pode criá-las manualmente uma vez no repositório e reaproveitar esse padrão em todos os projetos.

## Comportamento quando a máquina está ligada, desligada ou reiniciada

### Quando a máquina está ligada e a fábrica foi iniciada

Se `start-factory.sh` foi executado, o `poll-loop.sh` roda em background, chama `sync-queue.sh`, dorme por `POLL_INTERVAL_SECONDS` e repete indefinidamente.

Na prática:
- você abre uma issue;
- adiciona a label `ai-run`;
- o loop encontra a tarefa no próximo ciclo;
- o processamento começa sozinho.

### Quando a máquina está desligada

Nada é perdido porque a fila está persistida no GitHub. A issue continua aberta com a label correspondente. Quando a máquina voltar e o polling for retomado, a fila volta a ser consumida.

### Quando a máquina é religada

Se você instalou o cron com `bash scripts/install-cron.sh`, existe uma entrada `@reboot` que chama `scripts/start-factory.sh`.

Isso significa que, após reiniciar a máquina e o cron subir corretamente, a fábrica tende a iniciar sozinha.

## O que exatamente faz `bash scripts/install-cron.sh`

O script atual escreve duas entradas no crontab:

```text
@reboot bash <ROOT_DIR>/scripts/start-factory.sh
*/5 * * * * bash <ROOT_DIR>/scripts/sync-queue.sh >> <ROOT_DIR>/state/logs/cron-sync.log 2>&1
```

### Consequências práticas

1. No reboot, ele tenta iniciar a fábrica automaticamente.
2. A cada 5 minutos, ele também chama `sync-queue.sh` diretamente.

Isso significa que, no estado atual do projeto, você tem dois mecanismos possíveis de varredura:
- o `poll-loop.sh` em background, iniciado por `start-factory.sh`;
- a linha periódica do cron rodando `sync-queue.sh` a cada 5 minutos.

Isso funciona, mas vale entender que existe redundância operacional.

## Preciso rodar `install-cron.sh` mais de uma vez?

Na prática, a intenção é rodar **uma vez** por instalação.

Mas existe um detalhe importante: o script atual simplesmente reaplica linhas no crontab. Se você rodá-lo várias vezes, ele pode duplicar entradas.

Então a recomendação é:
- rode uma vez;
- confira com `crontab -l`;
- evite repetir sem necessidade.

## Se eu der `stop` e depois `start`, preciso rodar `install-cron.sh` de novo?

Não.

- `stop-factory.sh` mata o processo do loop atual e derruba o `docker compose` local.
- `start-factory.sh` sobe novamente e recria o loop.
- `install-cron.sh` é para registrar comportamento automático no sistema, não para o ciclo normal de start/stop diário.

Ou seja: `install-cron.sh` é configuração do sistema; `start-factory.sh` e `stop-factory.sh` são operação cotidiana.

## Como validar que está tudo pronto

### Validar ambiente

```bash
bash scripts/doctor.sh
```

### Validar autenticação do GitHub CLI

```bash
gh auth status
```

### Validar processo em background

```bash
cat state/poll-loop.pid
ps -fp "$(cat state/poll-loop.pid)"
```

### Validar consumo manual da fila

```bash
bash scripts/sync-queue.sh
```

### Validar logs

```bash
tail -f state/logs/poll-loop.log
tail -f state/logs/cron-sync.log
```

## Estratégia recomendada para novos repositórios

1. Clonar o repositório localmente.
2. Garantir que os comandos de teste, lint, format e build funcionam manualmente.
3. Criar `repos/<nome>.repo.env` com os comandos corretos.
4. Executar `bash scripts/doctor.sh`.
5. Rodar uma issue pequena primeiro.
6. Validar branch, commit, push, PR e merge.
7. Só depois levar projetos críticos para o fluxo automático completo.

## Boas práticas finais

- Prefira repositórios com suíte de testes real antes de automatizar mudanças maiores.
- Mantenha os arquivos Markdown dos agentes curtos e declarativos.
- Evite empurrar toda a política para prompts longos; prefira contratos operacionais no shell.
- Comece com tarefas pequenas e observáveis.
- Só habilite merge automático em repositórios cujo fluxo e proteções você entende bem.