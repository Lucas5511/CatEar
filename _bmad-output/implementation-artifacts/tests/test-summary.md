# Resumo de Automação de Testes — Story 1.1 (app shell)

**Data:** 2026-09-01 · **QA:** automação (bmad-qa-generate-e2e-tests)
**Framework:** `flutter_test` (widget) + `integration_test` (E2E) — Flutter 3.47.2 / Dart 3.13.2

## Testes gerados

### Testes de API
Não aplicável — o projeto não tem camada de API/backend nesta fase (persistência local via Drift, sem endpoints).

### Testes E2E

- [x] `integration_test/app_shell_test.dart` — jornadas de usuário no app shell, dirigindo o `CatEarApp` real

| # | Cenário | O que valida |
|---|---------|--------------|
| 1 | Primeiro boot | Abre no `HomeShell`, aba Home, tema claro |
| 2 | Navegação completa | Tap em Trilha → Progresso → Ajustes → Home; tela e `selectedIndex` corretos |
| 3 | Sem swipe / sem Drawer | Sem `PageView`, sem `Drawer`, `IndexedStack` presente |
| 4 | Back do Android | Botão voltar numa aba profunda retorna à Home (não sai do app) |
| 5 | Troca de tema em Settings | Escolher "Escuro" / "Claro" aplica o brilho na hora, sem reiniciar |
| 6 | Modo escuro do sistema | `platformBrightness = dark` + `ThemeMode.system` → tema escuro |
| 7 | Falha ao abrir o DB + retry | `DatabaseErrorScreen` aparece; "Tentar de novo" recupera → `HomeShell` |
| 8 | Text scaling extremo | `TextScaler.linear(2.0)` em todas as abas sem `RenderFlex overflow` |

**Padrões usados:** locators semânticos (`find.text`, `find.byType`), fluxos lineares, asserção de resultados visíveis, `databaseProvider` sobrescrito com Drift em memória (roda headless e on-device; on-device também exercita `path_provider`/`sqlite3` reais).

### Testes de widget pré-existentes (não gerados aqui, contexto)

`test/`: `cat_ear_app_test` (5), `home_shell_test` (4), `accessibility_test` (2), `contrast_test` (19), `theme_test` (6), `database_test` (1), `module_boundary_test` (6) — **43 no total, todos passando**.

## Execução

| Comando | Resultado |
|---------|-----------|
| `flutter analyze integration_test` | No issues found |
| `dart format integration_test` | sem mudanças |
| `flutter test` (suíte widget) | **43 passed** |
| Lógica E2E verificada como widget test (binding trocado, arquivo temporário) | **8 passed** |
| `flutter test integration_test/app_shell_test.dart` | **não executado aqui** — exige device/emulador; sem emulador Android disponível e o projeto é só android/ios (adicionar `linux/` é vetado pela spec) |

## Cobertura

- **Endpoints de API:** n/a (0 endpoints no projeto)
- **Fluxos de UI (Story 1.1):** 8/8 dos cenários da I/O & Edge-Case Matrix da spec cobertos por E2E
  - Primeiro boot ok · Falha ao abrir o DB · Troca de aba · Back do Android · Modo escuro do sistema · Text scaling máximo — cobertos
  - "Import proibido" — coberto por `test/module_boundary_test.dart` (não é fluxo de UI)

## Próximos passos

- **Rodar no CI com emulador Android:** adicionar job com `reactivecircus/android-emulator-runner@v2` e `flutter test integration_test` (ou `flutter drive`). O `tool/ci.sh` atual roda em `ubuntu-latest` sem emulador e não inclui E2E.
- Adicionar cenários E2E conforme novas stories do Epic 1 (nivelamento, exercícios) forem entrando.
- Quando houver telas reais, trocar asserções de texto placeholder por locators de papel/semântica mais estáveis.
