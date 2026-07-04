# Arquitetura

```text
GitHub Issue/PR/comment
        |
        v
[queue label / state on GitHub]
        |
        v
[poll-loop local ou VPS]
        |
        v
[Orchestrator]
   |--> @make  -> altera código
   |--> @test  -> executa testes/lint/build
   |--> self-healing loop (máx. MAX_RETRIES)
   |--> @check -> revisão final
   '--> @git   -> commit/push/comentário/merge via GitHub MCP
```

## Gatilho recomendado
- Laptop/WSL2: polling com fila persistida no GitHub por label/comando.
- VPS sempre ligada: opcionalmente trocar polling por webhook.
- Máquina desligada: nada é perdido; a fila continua no GitHub e é drenada na próxima inicialização.
