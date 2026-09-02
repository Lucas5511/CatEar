---
scope: Epic 1 — Stories 1.1 + 1.2
author: Murat (Test Architect)
date: 2026-09-02
baseline: master @ 4da41bb
coverageBasis: acceptance_criteria
oracleResolutionMode: formal_requirements
oracleConfidence: high
oracleSources:
  - _bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md
  - _bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md
  - _bmad-output/implementation-artifacts/epic-1-context.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-1.md
externalPointerStatus: not_used
collection_status: COLLECTED
allow_gate: true
gate_decision: CONCERNS
---

# Traceability Matrix — Epic 1

Oráculo: critérios de aceitação + I/O & Edge-Case Matrix das specs 1.1 e 1.2 (confiança **alta** — requisitos formais congelados). 33 itens rastreados.

Legenda de cobertura: **FULL** = comportamento asserido por teste automatizado que roda no CI · **PARTIAL** = coberto em parte, ou o teste é fraco/quase-tautológico, ou depende de execução fora do CI · **NONE** = sem teste · **N/A-CI** = verificado por gate de CI, não por teste.

---

## Story 1.1 — App shell, tema, banco

### I/O & Edge-Case Matrix

| ID | Cenário | Pri | Teste(s) | Cobertura |
|----|---------|-----|----------|-----------|
| IO-1.1-1 | Primeiro boot: `databaseProvider` resolve, HomeShell aba Home, schema v1 em app support dir | P0 | `cat_ear_app_test` (loading→boot→HomeShell), `database_test` (v1), `home_shell_test`, `integration_test#1` | **PARTIAL** — o path real `getApplicationSupportDirectory()` só é exercido em device; no CI é mock |
| IO-1.1-2 | Falha ao abrir DB → `AsyncError` → `DatabaseErrorScreen` + retry invalida provider; log | P0 | `cat_ear_app_test` (error→screen→retry→HomeShell), `integration_test#7` | **FULL** (comportamento); log via `dart:developer` não asserido |
| IO-1.1-3 | Troca de aba → `IndexedStack`, aba selecionada, sem swipe | P1 | `home_shell_test` (tab switch, sem `PageView`), `integration_test#2,#3` | **FULL** |
| IO-1.1-4 | Back Android numa aba ≠ Home → volta Home, não sai; `PopScope.canPop` só em index 0 | P1 | `home_shell_test` (`handlePopRoute`), `integration_test#4` | **FULL** |
| IO-1.1-5 | Modo escuro do SO no boot/runtime → tema escuro sem reiniciar | P1 | `cat_ear_app_test` (platformBrightness dark), `integration_test#6` | **FULL** |
| IO-1.1-6 | `TextScaler.linear(2.0)` → nenhum rótulo trunca, sem `RenderFlex overflow`, alvos ≥ 48dp | P1 | `accessibility_test` (3), `integration_test#8` | **PARTIAL** — shell OK; `DatabaseErrorScreen` quase-tautológico (TQ-2); boot screen não coberto; "não trunca" não asserido diretamente (só overflow) |
| IO-1.1-7 | Import proibido (incl. `export`/relativo, símbolo Drift) → `check_module_boundaries` falha nomeando a linha | P1 | `module_boundary_test` (6 fixtures) | **PARTIAL** — regras 1–2 (`data/`/`presentation/` reach-in, Drift fora de core); sem barrel-only `domain/`, direção de camada, escape de `lib/` (R4) |

### Critérios de Aceitação

| ID | AC | Pri | Teste(s) | Cobertura |
|----|-----|-----|----------|-----------|
| AC-1.1-a | `flutter run` → HomeShell aba Home tema claro; SO→dark troca sem reiniciar | P0 | widget + `integration_test` cobrem a lógica | **PARTIAL** — `flutter run`/build de device **nunca roda no CI** (R1) |
| AC-1.1-b | `flutter test` passa: contraste, dark≠light, fonte≠Fredoka, nav, sem `PageView`, sem overflow `TextScaler(2.0)`, `AppDatabase` v1 | P0 | `contrast_test`, `theme_test`, `home_shell_test`, `accessibility_test`, `database_test` | **FULL** — cada cláusula tem teste (dark verificado só por diferença — TQ-4) |
| AC-1.1-c | `ci.sh` exit 0; import proibido plantado (`export`/relativo) faz `check_module_boundaries` falhar nomeando o arquivo | P1 | `module_boundary_test` (fixtures `export` + relativo) | **PARTIAL** — o `ci.sh` em si não tem teste |
| AC-1.1-d | `flutter analyze` zero issues fora de gerados | P2 | etapa `analyze` do `ci.sh` | **N/A-CI** |
| AC-1.1-e | Falha DB → `DatabaseErrorScreen` retry funcional; app não trava em branco | P0 | = IO-1.1-2 | **FULL** |
| AC-1.1-f | `drift_schemas/` contém snapshot v1 | P2 | etapa `schema dump` + arquivo commitado | **PARTIAL** — nenhum teste asserta que o snapshot casa com o schema vivo |
| AC-1.1-g | `applicationId` + `PRODUCT_BUNDLE_IDENTIFIER` = `app.catear`; nome de exibição = CatEar (CI verifica) | P1 | `check_app_id.dart` no `ci.sh` | **PARTIAL** — o script não tem fixture test (padrão do `module_boundary_test` não foi replicado) |

---

## Story 1.2 — Catálogo de currículo como dado

### I/O & Edge-Case Matrix

| ID | Cenário | Pri | Teste(s) | Cobertura |
|----|---------|-----|----------|-----------|
| IO-1.2-1 | Carga ok → `Curriculum` 10 estágios; `direction`/`scaffoldIntensity`/`timbreScaffold`/`requiresVoice` mapeados; ids resolvidos | P0 | `curriculum_catalog_test` (grupo "via load()") | **FULL** |
| IO-1.2-2 | Asset ausente / JSON ilegível / raiz não-objeto → `assetNotFound`/`malformedCatalog`; nunca `FormatException`/`TypeError` | P0 | `curriculum_catalog_test` (`loadErrorFrom`), `curriculum_validation_test` (root shape) | **FULL** |
| IO-1.2-3 | `schemaVersion` ausente / `2` / `"1"` → `malformedCatalog('schemaVersion')` | P1 | `curriculum_validation_test` (grupo schemaVersion) | **FULL** |
| IO-1.2-4 | Valor fora da taxonomia → `unknownValue` nomeando o campo; nunca fallback | P0 | `curriculum_validation_test` (por enum) | **FULL** |
| IO-1.2-5 | Estrutura malformada (`stages: []`, `exercises: []`, `stageId` dup, `order` não-int, `scaffoldIntensity` 1.5/NaN, `audioSampleRefs` `[]`/`"Piano C4"`/string, `*Catalog` sem `nameUi`) → erro nomeando alvo | P1 | `curriculum_validation_test` (extenso, campos de `*Catalog` fechados no review) | **FULL** |
| IO-1.2-6 | `requiresVoice` mal-usado (`resolution` sem / `interval` com) → erro nos dois sentidos | P0 | `curriculum_validation_test` (bicondicional) | **FULL** — **crítico de segurança** (estágio `resolution` inerte) |
| IO-1.2-7 | `direction` mal-posicionado (`chord` com / `interval` sem) → erro | P1 | `curriculum_validation_test` | **FULL** |
| IO-1.2-8 | `order` não-monotônico / duplicado / array fora de ordem → R1 exit ≠ 0 | P1 | `curriculum_validation_test` (R1), `check_curriculum_test` (smoke) | **FULL** — nuance: `[1,3,2]` como *valores* ordena para `[1,2,3]` e passa; só duplicata falha (resolvido no review, texto da spec ficou obsoleto) |
| IO-1.2-9 | Fading de cor sobe → R2 exit ≠ 0; "buraco" válido → exit 0 | P1 | `curriculum_validation_test` (R2), `check_curriculum_test` (good fixture com buraco) | **FULL** — FR-14 |
| IO-1.2-10 | Fading de timbre sobe → R3 exit ≠ 0 | P1 | `curriculum_validation_test` (R3) | **FULL** |
| IO-1.2-11 | `errorTypes[]` fora de sincronia com o enum → erro nomeando id | P1 | `curriculum_validation_test` | **FULL** |
| IO-1.2-12 | id de exercício órfão → erro nomeando `stageId` + id | P1 | `curriculum_validation_test` (órfão em cada um dos 4 `*Catalog`) | **FULL** |

### Critérios de Aceitação

| ID | AC | Pri | Teste(s) | Cobertura |
|----|-----|-----|----------|-----------|
| AC-1.2-a | `load()` → domínio puro, 10 estágios / 13 intervalos / 2 escalas / 2 acordes / 2 cadências; todo `ResolutionExercise` `requiresVoice`, nenhum outro | P0 | `curriculum_catalog_test` (contagens, cobertura, `requiresVoice` nos dois sentidos) | **FULL** |
| AC-1.2-b | `flutter test` passa: round-trip + 1 caso por subtipo de `CurriculumError` + ≥14 fixtures ruins | P0 | `curriculum_catalog_test` + `curriculum_validation_test` (49) | **FULL** |
| AC-1.2-c | `check_curriculum` exit 0 no v1; exit ≠ 0 nos 6 cenários nomeados | P1 | `check_curriculum_test` (smokes) + `curriculum_validation_test` | **FULL** |
| AC-1.2-d | Array `stages` fora de ordem + `order` único/crescente + fading OK → exit 0 | P1 | `check_curriculum_test` (array revertido), `curriculum_catalog_test` (shuffled→sorted) | **FULL** |
| AC-1.2-e | `ci.sh` — etapa `curriculum` antes de `test`; catálogo ruim plantado → `ci.sh` exit ≠ 0 | P1 | etapa existe (`ci.sh:30`); `check_curriculum_test` prova o *script*, não o `ci.sh` | **PARTIAL** — nada asserta a ordem da etapa nem a agregação de exit do `ci.sh` |
| AC-1.2-f | `check_module_boundaries` + `analyze` exit 0; `_AssetCurriculoRepository` não público; barrel só domínio + provider | P1 | `curriculum_catalog_test` (grupo "guards the module's public surface") | **FULL** |
| AC-1.2-g | `git status` → `lib/curriculo/presentation/` só `.gitkeep` | P3 | verificação manual | **PARTIAL** — nenhum teste; um check estilo `module_boundary` poderia assertar |

---

## Análise de cobertura

| Métrica | Valor |
|---|---|
| Itens rastreados | 33 |
| **FULL** | 25 (76%) |
| **PARTIAL** | 8 (24%) |
| **NONE** | 0 (0%) |
| **N/A-CI** | 1 |
| Itens P0 | 11 · FULL 9 (82%) · PARTIAL 2 · NONE 0 |
| Itens P1 | ~18 · maioria FULL · PARTIAL 5 |

**Nenhum requisito das stories entregues está sem cobertura.** Os 8 PARTIAL se concentram em três temas, todos já nos riscos do test-design:
1. **Nada verifica o app num device real** (R1) — AC-1.1-a, IO-1.1-1 (path do banco).
2. **`ci.sh` / scripts de tool sem teste próprio** — AC-1.1-c, AC-1.1-g, AC-1.2-e.
3. **`check_module_boundaries` incompleto + acessibilidade parcial** (R4, R7) — IO-1.1-6, IO-1.1-7.

---

## Decisão de Gate — Fase 2

### **CONCERNS** 🟡

**Elegibilidade:** `collection_status = COLLECTED`, `allow_gate = true` → o gate é avaliado por cobertura.

**Por que não PASS:**
- Um AC **P0** (AC-1.1-a) está PARTIAL porque o build/execução em device **nunca roda no CI** — risco R1 (score 6), sem mitigação atribuída.
- Risco R2 (migração Drift, score 6) sem harness — não é um gap de rastreabilidade de AC (não há AC de migração ainda), mas é um risco de dado alto e conhecido que fecha o épico se ignorado.
- Cobertura P0 em 82% FULL (abaixo do patamar de PASS de ~90% + zero P0 partial em cláusula crítica).

**Por que não FAIL:**
- Zero itens NONE. Zero AC sem teste.
- Zero testes falhando; zero `skip`/`solo`.
- Nenhum risco score 9.

**Condições para virar PASS:**
1. R1 — job de CI `flutter build apk --debug` + `flutter analyze` do target (fecha AC-1.1-a).
2. R2 — `test/migration_test.dart` com `SchemaVerifier` sobre `drift_schemas/` (mesmo que só valide v1 hoje; obrigatório antes da Story 1.8).
3. (Recomendado) R3 — `integration_test` no CI com emulador (fecha IO-1.1-1 e sobe a confiança das jornadas).

**Waiver:** não recomendado. As três condições são baratas (~1–2h somadas) e endereçam risco de dado/OPS real, não polimento.

---

## Owners e prazos

| Ação | Risco | Status | Evidência |
|---|---|---|---|
| CI build nativo Android (`build-android` job) | R1 | ✅ **feito** (branch `test/epic-1-quality-gate`) | `.github/workflows/ci.yaml`; `flutter build apk --debug` verificado local (APK gerado) |
| Harness de migração (`test/migration_test.dart` + `SchemaVerifier`) | R2 | ✅ **feito** | 4 testes passando; guarda `schemaVersion` vs snapshots; pronto para estender na Story 1.8 |
| `integration_test` no CI com emulador (`e2e-android` job) | R3 | 🟡 **job adicionado, não verificado** | `.github/workflows/ci.yaml` (`reactivecircus/android-emulator-runner`, API 35) — precisa do 1º run no GitHub |

---

## Atualização de gate — 2026-09-02 (pós branch `test/epic-1-quality-gate`)

**PASS pendente do 1º CI verde.**

- **R1** mitigado: job `build-android` + prova local. AC-1.1-a sai de PARTIAL para FULL assim que o job passar no GitHub.
- **R2** mitigado: harness na suíte (`flutter test` agora 145 testes). IO-1.1-1 (path do banco) continua PARTIAL até o `e2e-android` rodar com `databaseProvider` real — recomendação TQ-6 (1 teste E2E com provider real no emulador) fecha isso.
- **R3** endereçado mas **não comprovado** — o gate só vira PASS quando `build-android` **e** `e2e-android` fecharem verdes num PR.

Enquanto os dois jobs novos não tiverem um run verde registrado: **CONCERNS → PASS-pending**. Nenhuma ação de código pendente; só falta a execução no CI real.
