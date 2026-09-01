
## Deferred from: code review of spec-1-1 (2026-09-01)

- Escolha de roteamento de navegação (go_router `StatefulShellRoute.indexedStack` vs `Navigator` aninhado por aba). A Story 1.1 usa `IndexedStack` de placeholders. Revisitar antes da Story 2.6 (skill tree), quando as abas ganham conteúdo real e a regra "modal empilha só um nível" começa a importar. Adicionar `go_router` à stack é decisão de arquitetura (Ask First).
- Migrar a fronteira de módulos de script para `custom_lint` ou pacote-por-módulo (melos), quando o projeto justificar.
