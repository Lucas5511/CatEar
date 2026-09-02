---
run_scope: epic-level
run_key: epic-1
epic_num: 1
project: CatEar
author: Murat (Test Architect)
date: 2026-09-02
baseline: master @ 4da41bb (Stories 1.1 e 1.2 entregues)
stack_detected: mobile (Flutter, android/ios, local-first, sem backend)
---

# Test Design — Epic 1: Fundação técnica + primeiro loop de reconhecimento

## 1. Contexto e escopo

Epic 1 entrega um app de treino de ouvido jogável **sem voz**. Estado atual: Stories 1.1 (app shell, tema, `AppDatabase` Drift, navegação) e 1.2 (catálogo de currículo como dado + `CurriculoRepository` + gate de fading) mergeadas. Stories 1.3–1.10 no backlog.

**Perfil de risco do épico:** baixo em SEC (sem backend, sem auth, sem PII além de progresso local, sem rede na v1), **alto em DATA** (perda de dado local = perda total de progresso, sem recuperação) e **alto em OPS** (nenhuma verificação de que o app compila para um device real).

Suíte atual: **~141 testes unit/widget** (`flutter test`) + **8 E2E** (`integration_test/`, fora do CI).

---

## 2. Avaliação de risco (probabilidade × impacto, escala 1–3, score 1–9)

| ID | Cat | Risco | P | I | Score | Nível | Cobertura hoje |
|----|-----|-------|---|---|-------|-------|----------------|
| **R1** | OPS | CI nunca compila o app para device (`flutter build apk`/`ios`). O shell pode falhar build nativo com CI verde. | 2 | 3 | **6** | 🔴 ALTO | **nenhuma** |
| **R2** | DATA | Migração Drift: `onUpgrade` vazio + 1ª tabela real só na Story 1.8. Migração malfeita apaga/corrompe o banco local do usuário. | 2 | 3 | **6** | 🔴 ALTO | `database_test` (1 teste: abre em v1, FK pragma). Sem teste de migração — snapshots `drift_schemas/` não são exercidos. |
| **R3** | OPS | Suíte `integration_test/` (8 jornadas E2E) roda só manualmente. Regressão em navegação/tema/gate de DB passa com CI verde. | 2 | 2 | 4 | 🟡 MÉDIO | 8 testes E2E existem, não no CI |
| **R4** | TECH | `check_module_boundaries.dart` tem lacunas conhecidas: não força barrel-only a `domain/`, não checa direção de camada (core→feature), não sinaliza import relativo que escapa de `lib/`. Acoplamento arquitetural erode em silêncio. | 2 | 2 | 4 | 🟡 MÉDIO | 6 fixtures (regras 1–2 só) |
| **R5** | BUS | `content-model.md` §8 e `epics.md` AC1 contradizem o schema entregue (`scaffoldIntensity` em `exercises[]` vs por-estágio). Autores das Stories 1.3b/1.4 constroem em cima do doc errado. | 2 | 2 | 4 | 🟡 MÉDIO | rastreado em `deferred-work.md`, doc não corrigido |
| **R6** | TECH | Sem medição de cobertura (`flutter test --coverage`) nem threshold no CI. Não dá para ver o que não está testado. | 3 | 1 | 3 | 🟢 BAIXO | nenhuma |
| **R7** | A11Y | Contraste verificado só contra `surface-base`/`-dark`; pares sobre `surface-raised` (divisor/hairline em card ~2.6:1) e pares `onX` (onPrimary, onError, label da NavigationBar) sem teste. `accessibility_test` não cobre `DatabaseErrorScreen`/boot sob `TextScaler(2.0)` além do que foi corrigido. | 2 | 2 | 4 | 🟡 MÉDIO | `contrast_test` (19), `accessibility_test` (3) — parcial |
| **R8** | TECH | Código gerado git-ignorado + regenerado no CI; sem `git diff --exit-code` após regen. Drift entre `*.g.dart`/`*.drift.dart` local e CI, ou snapshot de schema/audit de contraste desatualizado, passa despercebido. | 2 | 1 | 2 | 🟢 BAIXO | nenhuma |
| **R9** | DATA | `database_test` e testes de currículo usam `NativeDatabase.memory()` sob `flutter test` — dependem de `libsqlite3` do sistema no runner. Imagem do runner mudar quebra os testes de forma confusa. | 1 | 2 | 2 | 🟢 BAIXO | nenhuma (sem `apt-get`/dep `sqlite3` explícita) |
| **R10** | OPS | `main()` sem handler global de erro (`FlutterError.onError`/`PlatformDispatcher.onError`/zona guardada). Crash em produção não tem trilha. | 2 | 2 | 4 | 🟡 MÉDIO | nenhuma |
| **R11** | BUS | `CurriculoRepository.load()` re-parseia o JSON a cada chamada (sem cache). A partir da Story 1.7 pode ser chamado por sessão; custo desconhecido. | 1 | 1 | 1 | 🟢 BAIXO | nenhuma (sem budget de perf) |
| **R12** | OPS | `_bmad/tea/config.yaml` diz `project_name: "Perfect Ear"`; `pubspec` é `catear`, README é "CatEar". Inconsistência de instalador. | 1 | 1 | 1 | 🟢 BAIXO | n/a |

**Regra de gate:** score ≥ 6 exige mitigação documentada com dono e prazo antes do fechamento do épico. Score = 9 bloqueia. Aqui: **nenhum score 9**, **dois scores 6 (R1, R2)** — mitigação obrigatória.

---

## 3. Estratégia de cobertura por nível

Princípio: nível mais baixo sempre que possível (unit > widget > integration > E2E > device).

| Nível | O que cobre | Estado |
|-------|-------------|--------|
| **Unit** | Modelos de domínio, `curriculum_validation` (as 7+ regras + R1–R3), WCAG (`contrastRatio`/`relativeLuminance`), parsing de enum, `CatText`/tema como função pura | ✅ **forte** — 1.2 tem 49 testes de validação + 22 de repositório; 1.1 tem contraste/tema/wcag |
| **Widget** | `HomeShell` (navegação, `PopScope`, sem `PageView`/`Drawer`), `CatEarApp` (gate loading/erro/data + retry), `SettingsScreen` (troca de tema ao vivo), acessibilidade sob `TextScaler(2.0)` | ✅ **boa** — cobre as linhas da I/O Matrix da 1.1 |
| **Integração (tool)** | `check_module_boundaries.dart`, `check_curriculum.dart`, `check_app_id.dart` via subprocesso com fixtures bom/ruim | 🟡 **parcial** — boundaries e curriculum têm fixtures; `check_app_id` **sem teste** (só `module_boundary` tem o padrão) |
| **Integração (E2E `integration_test`)** | Jornadas do app real: boot → HomeShell → 4 abas → back Android → troca de tema → modo escuro do sistema → falha do DB + retry → `TextScaler(2.0)` | 🟡 **existe (8), fora do CI** |
| **Device / build** | `flutter build apk` (debug) + `flutter analyze` para o target Android; iOS quando houver runner macOS | 🔴 **ausente** |
| **Migração de schema** | `drift` `SchemaVerifier` + os snapshots `drift_schemas/*.json` — testa v1→v2 preservando dados | 🔴 **ausente** (necessário **antes** de a Story 1.8 mergear a 1ª tabela) |

---

## 4. Plano de NFR

| NFR | Alvo | Evidência atual | Ação |
|-----|------|-----------------|------|
| **Reliability** | App não trava em branco; migração nunca apaga dados; erros observáveis | Gate de DB + retry ✅ · migração ❌ · handler global ❌ | Harness de migração (R2); `FlutterError.onError` + zona guardada em `main()` (R10) |
| **Performance** | Cold start < 2s em device médio; `catalog.load()` < 50ms | nenhuma medição | Smoke de perf no `integration_test` quando a Story 1.4 usar o catálogo por sessão; **não urgente agora** |
| **Maintainability** | Fronteira de módulos aplicada; sem drift de gerados; cobertura visível | boundaries (com lacunas) ✅ · format/analyze ✅ · cobertura ❌ · drift de gerados ❌ | `flutter test --coverage` + threshold informativo (R6); `git diff --exit-code` pós-regen no `ci.sh` (R8); fechar lacunas do `check_module_boundaries` (R4) |
| **Security** | Sem superfície na v1 | sem backend/auth/rede | **Reavaliar no Epic 3** (permissão de microfone) e em qualquer OTA de catálogo |
| **Accessibility** | AA em todo par de token; alvos ≥ 48dp; dynamic type sem truncar | contraste base ✅ · `TextScaler(2.0)` no shell ✅ · pares `surface-raised`/`onX` ❌ · telas de erro/boot ❌ | Estender `contrast_test` para `surface-raised` e pares `onX`; pumpar `DatabaseErrorScreen`/boot sob `TextScaler(2.0)` (R7) — **também é pendência de UX da hairline** |

---

## 5. Rastreabilidade (requisito → teste) — resumo

| Requisito / AC | Origem | Teste | Status |
|---|---|---|---|
| App abre no `HomeShell` aba Home, tema claro | spec 1.1 AC | `home_shell_test`, `cat_ear_app_test`, `integration_test` | ✅ |
| Modo escuro do SO troca sem reiniciar | spec 1.1 AC | `cat_ear_app_test` (platformBrightness), `integration_test` | ✅ |
| Falha ao abrir o DB → `DatabaseErrorScreen` + retry | spec 1.1 I/O + AC | `cat_ear_app_test` | ✅ |
| Back do Android numa aba ≠ Home volta p/ Home | spec 1.1 I/O | `home_shell_test`, `integration_test` | ✅ |
| Sem overflow em `TextScaler(2.0)`; alvos ≥ 48dp | spec 1.1 I/O + PRD a11y | `accessibility_test` | 🟡 parcial (telas de erro/boot não) |
| Contraste AA de todo par de token | spec 1.1 + PRD a11y | `contrast_test` | 🟡 parcial (só vs `surface-base`/`-dark`) |
| Import proibido falha `check_module_boundaries` | spec 1.1 AC | `module_boundary_test` | 🟡 regras 1–2 só |
| `AppDatabase` abre em v1; `drift_schemas/` tem snapshot v1 | spec 1.1 AC | `database_test` + CI `schema dump` | ✅ (abertura); ❌ migração |
| `applicationId` / bundle id / nome de exibição = `app.catear`/CatEar | spec 1.1 AC | `check_app_id.dart` no CI | ✅ (script), ❌ sem teste do próprio script |
| `catalog_v1.json` → `Curriculum` de domínio puro, 10 estágios | spec 1.2 AC | `curriculum_catalog_test` (22) | ✅ |
| Invariante de fading (`order`, `scaffoldIntensity`, `timbreScaffold`) | spec 1.2 AC / AD-4 / FR-14 | `curriculum_validation_test` (49) + `check_curriculum_test` (6) | ✅ forte |
| `resolution` inerte via `requiresVoice` | spec 1.2 | `curriculum_validation_test` (bicondicional) | ✅ dado; enforcement (skill tree/sessão) → Stories 1.7/2.1 |
| `errorTypes[]` == enum `ErrorType` | spec 1.2 | `curriculum_validation_test` | ✅ |

**Gaps de rastreabilidade:** nenhum AC sem teste **para as stories entregues**. Os buracos são de robustez (migração, build nativo, E2E no CI), não de aceitação.

---

## 6. Decisão de gate (Epic 1, escopo entregue)

**CONCERNS** — as Stories 1.1 e 1.2 cumprem seus critérios de aceitação com boa cobertura de nível baixo, mas dois riscos de score 6 (R1 build nativo, R2 migração) não têm nenhuma mitigação e são bloqueantes para o *fechamento do épico* (não para o merge das stories já feitas).

| Condição de PASS | Falta |
|---|---|
| R1 mitigado | Adicionar `flutter build apk --debug` (+ analyze do target) ao CI |
| R2 mitigado | Harness de `SchemaVerifier` usando `drift_schemas/`, pronto **antes** da Story 1.8 |
| R3 endereçado | `integration_test` no CI com emulador (job `reactivecircus/android-emulator-runner`) |

---

## 7. Ações priorizadas

### P0 — antes de fechar o Epic 1
1. **R1** — job de CI `flutter build apk --debug` (Android) + `flutter analyze`. ~30 min. Dono: dev.
2. **R2** — `test/migration_test.dart` com `drift` `SchemaVerifier` sobre `drift_schemas/`; falha se v1→vN não preservar dados. Escrever agora com só v1 (verifica integridade), estender na 1.8. Dono: dev + Murat.

### P1 — durante o Epic 1
3. **R3** — `integration_test` no CI (emulador Android). Reusar o AVD `pixel` documentado.
4. **R7** — estender `contrast_test` (`surface-raised`, pares `onX`) + `accessibility_test` (telas de erro/boot). Casa com a revisão de UX da hairline.
5. **R4** — fechar lacunas do `check_module_boundaries` (barrel-only `domain/`, direção de camada, escape de `lib/`) + fixtures.
6. **R5** — reconciliar `content-model.md` §8 e `epics.md` AC1 com o schema por-estágio. Doc, não teste.
7. **R10** — handler global de erro em `main()` + teste widget que injeta um throw e verifica o log.

### P2 — oportunista
8. **R6** — `flutter test --coverage` no CI + relatório (threshold informativo, sem gate ainda).
9. **R8** — `git diff --exit-code` após `build_runner`/`schema dump`/`contrast audit` no `ci.sh`.
10. **`check_app_id.dart`** — fixture test (padrão do `module_boundary_test`).
11. **R12** — corrigir `project_name` no `_bmad/tea/config.yaml`.

---

## 8. Padrões de teste a manter (DoD)

- Nível mais baixo primeiro — a suíte de 1.2 é o modelo (validação por import direto, subprocesso só p/ smoke).
- Sem `skip`/`solo`/`only` commitado; sem asserção que não pode falhar (o `accessibility_test` da 1.1 já teve esse bug — engolir exceções não-overflow — e foi corrigido; **não regredir**).
- Fixtures bom **e** ruim por regra (padrão `module_boundary_test` / `check_curriculum_test`).
- `integration_test` com locators semânticos (`find.text`/`find.byType`), fluxos lineares, DB em memória via override do provider.
- Flakiness = dívida crítica. Se um teste de emulador piscar no CI, quarentena + issue no mesmo dia.
