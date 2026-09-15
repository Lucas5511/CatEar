---
scope: Epic 1 — estado entregue até a Story 1.8 (PR #31)
author: Murat (Test Architect)
date: 2026-09-15
baseline: master @ ad9e18d
suite: 366 testes unit/widget (flutter test) · 22 testes E2E on-device (integration_test)
gate_decision: CONCERNS
allow_next_story: true
---

# Quality Review — Epic 1 em 2026-09-15

Objetivo: dizer, com evidência, se o que foi entregue nas Stories 1.1–1.8 sustenta
as próximas (1.9 Nivelamento, 1.10 Settings) e o fechamento do Epic 1, e o que
precisa fechar antes disso. Última avaliação formal: gate da Story 1.3
(2026-09-02). Desde então entraram **seis stories sem gate formal** — 1.3b, 1.4,
1.4b, 1.5a, 1.5, 1.6, 1.7, 1.8.

## 1. Estado medido (não o estado documentado)

| Métrica | Valor hoje | Como foi medido |
|---|---|---|
| Stories do Epic 1 mergeadas | **9 de 11** (1.1–1.8, incl. 1.3b/1.4b/1.5a) | `git log`, PRs #1–#31 |
| `flutter test` | **366 passed, 0 failed, 0 skipped** | execução local, Flutter 3.47.2 |
| `integration_test/` | **22 testes** em 5 grupos (shell, prática com áudio real, contrato do `_JustAudioService`, tríades, wiring do provider) | contagem do arquivo + log do job `e2e-android` |
| `skip`/`solo`/`sleep()` commitados | **0** | grep em `test/` e `integration_test/` |
| CI (`ci.yaml`) | 4 jobs: `gates` (~5 min), `build-android` (~4,5 min), `build-ios` (~6 min, build smoke sem teste), `e2e-android` (~6,5 min, emulador API 35) | run 34985662764 (merge da 1.8) |
| Taxa de sucesso do `e2e-android` | **24/25** nos últimos 25 runs; a única falha foi defeito real no teste (container lido da tela errada), corrigida em `ee01a0a` — **zero falhas de infraestrutura na janela** | `gh run list` + log do run 34498472221 |
| Burn-in noturno (`e2e-burn-in.yaml`) | **0 execuções válidas — falha há 8 noites seguidas em ~3,5 min** | ver F1 |
| Gates de conteúdo/arquitetura no `ci.sh` | format · analyze · fronteiras de módulo (6 regras) · app id · currículo (fading) · owners do deferred-work · migração Drift v1→v2 | `tool/ci.sh`, `test/migration_test.dart` |
| Cobertura de linha | **não medida** (R6 do test-design segue aberto) | — |

## 2. O que está bom (manter)

- **Nível de teste certo.** A regra "unit > widget > E2E" foi respeitada: lógica de
  domínio (`exercise_variation`, `interval_practice`, `error_explanation`,
  `session_result`, `exercise_attempt`) tem suíte própria de import direto; a
  tela tem 48 testes de widget com `FakeAudioService` e `clock` injetado (a oferta
  de 12 min roda em milissegundos); só o que precisa de hardware (áudio real,
  Drift real, `path_provider`) vai para o emulador.
- **E2E que prova o que o fake não prova.** Os 22 testes on-device cobrem
  exatamente a lacuna do `FakeAudioService` ("playSample foi chamado" ≠ "saiu
  som"): cada contorno (intervalo, acorde, escala), cada token de tríade, o
  contrato de erro do player real e — desde a 1.8 — a tabela de histórico com o
  grafo de providers real. É a melhor parte da suíte.
- **Gates de conteúdo como dado.** `check_curriculum` (invariante de fading),
  `audio_assets_bundle_test` (paridade catálogo ↔ `assets/audio/` nos dois
  sentidos, sem órfão), `check_module_boundaries` com 6 regras (incl. a regra 6,
  que impede a apresentação de nomear tipos de exercício — protege o seam da 1.5a).
- **Migração com trip-wire.** `migration_test` já cobre v1→v2 com dados
  sobrevivendo; a Story 1.9 (nível de partida persistido) vai criar v3 e o
  harness está pronto.
- **Higiene de processo.** `check_deferred_owners` força triagem de dívida por
  story; `deferred-work.md` registra decisões com "por quê" (ex.: relógio de
  parede aceito na 1.7 com justificativa de custo × dano).

## 3. Achados (ordenados por risco)

Escala P×I 1–3, score 1–9. ≥6 exige mitigação com dono antes de fechar o épico.

### F1 — Burn-in noturno nunca executou; 8 noites vermelhas sem ninguém olhar · **score 6 (P3×I2) 🔴**

`reactivecircus/android-emulator-runner` executa `script` **linha por linha**,
cada linha num `sh -c` próprio. O `case "$ITERATIONS" in` multi-linha morre na
primeira linha: `Syntax error: end of file unexpected (expecting ")")` (run
34953732989, e os 7 anteriores). Consequências:

1. O action item #2 do retro ("ler a taxa do burn-in após ~3 noites") esperava um
   número que **nunca existiu**. A resolução parcial registrada no
   `sprint-status.yaml` descreve o workflow como funcionando.
2. Um job que falha toda noite e não muda comportamento de ninguém é um sinal
   morto — é o padrão "check que não pode ficar verde" do evidence-integrity,
   ao contrário.

Mitigação **aplicada nesta review (2026-09-15)**: loop movido para
`tool/e2e_burn_in.sh`, `script` com uma linha (`bash tool/e2e_burn_in.sh`);
validação do argumento e tally/exit verificados localmente com um `flutter`
stub. **Ainda não comprovado em CI** — disparar `workflow_dispatch` com
`iterations=3` após o merge e ler a tally. Enquanto isso, a taxa substituta é a do próprio `e2e-android`: 24/25, com a
única falha sendo defeito de teste. Boa notícia, amostra pequena.

### F2 — Rastreabilidade parou na 1.3; seis stories sem gate formal · **score 4 (P2×I2) 🟡**

A matriz de rastreabilidade cobre 1.1+1.2; o único gate por story é o da 1.3.
Por leitura, cada AC das Stories 1.4–1.8 tem teste (a tabela abaixo é o
resultado dessa leitura, não de um trace formal):

| Story | AC principais | Evidência encontrada | Lacuna |
|---|---|---|---|
| 1.4 | card único, motif em contexto, replay ilimitado, feedback positivo sem mascote, tempo de reação | `interval_exercise_screen_test`, `motif_test`, `exercise_attempt_test`, E2E "interval motif" | nenhuma |
| 1.5 / 1.5a | chord/scale no mesmo fluxo, zero código por tipo na apresentação | regra 6 do `check_module_boundaries`, E2E chord + scale | nenhuma |
| 1.6 | bubble nomeia a confusão, `far-miss` nunca `null`, sem vermelho saturado, inline sem rota | `error_explanation_test` (191 linhas), widget tests, `expectExplainedResult` no E2E | "sem vermelho saturado" verificado só por token; sem golden (TQ da review anterior, P2) |
| 1.7 | sessão 10–15 min, oferta sem culpa, `sessionId` UUID v4, concluída vs abandono, `SessionResultReported` exatamente 1× | 11 widget tests nomeados sobre sessão/oferta/report, `session_result_test`, E2E "leaving after answering reports no session" | nenhuma; relógio de parede aceito e documentado |
| 1.8 | janela por contagem (N=39, `variantWindow`), sem repetição idêntica, LRU quando pool esgota, tabela no módulo Progressão | `exercise_variation_test` (524 linhas), `variant_history_test`, `migration_test` v1→v2, E2E com Drift real | nenhuma |

Nada aqui bloqueia a 1.9. Mas fechar o Epic 1 sem matriz é fechar no "eu li e
parecia ok". Mitigação: rodar `bmad-testarch-trace` para 1.4–1.8 (Fase 1 +
Fase 2) — ≈1 sessão. Dono: Murat.

### F3 — Documentação de estado defasada · **score 3 (P3×I1) 🟢**, mas barato e visível

- `README.md` dizia "2 de 11 stories", "141 testes", "`record`/`just_audio` ainda
  não usados", "`integration_test` não roda no CI" — tudo falso hoje.
  **Corrigido nesta review.**
- `sprint-status.yaml` marcava `1-8` como `review` com o PR #31 mergeado.
  **Corrigido nesta review.**
- Comentário em `integration_test/catear_e2e_test.dart:557` aponta para
  `test/exercicios/audio_lifecycle_test.dart`, que não existe.
- `planejamento.md` vazio (0 B) na raiz.
- `_bmad/tea/config.yaml` ainda diz `project_name: Perfect Ear` (R12).

### F4 — `interval_exercise_screen.dart` virou monólito antes da 1.9 · **score 4 (P2×I2) 🟡**

1.031 linhas contendo o `Notifier` `IntervalPractice` (type-agnostic desde a 1.5a,
com sessão, oferta de fim, histórico de variações e report) **mais** 10 classes
de widget. O teste espelho tem 1.978 linhas. O nome mente — não é só intervalo
e não é só tela. A Story 1.9 (Nivelamento) precisa de "sequência curta de
exercícios de reconhecimento" — ou reusa esse notifier (e o arquivo cresce) ou
duplica (e a regra 6 das fronteiras não pega duplicação de fluxo).

Isto é uma decisão de arquitetura, não de teste — levar ao Winston. A
recomendação de qualidade é: **antes** da 1.9, extrair o notifier para um
arquivo próprio (`practice_controller.dart` ou similar), renomear a tela para
`practice_screen.dart`, e dividir o teste no mesmo corte. Custo ≈ 1 PR
mecânico com a suíte verde como rede. Depois da 1.9 o custo dobra.

### F5 — Paridade iOS só por build smoke · **score 6 (P2×I3) 🔴, risco já aceito**

`build-ios` prova que compila; nunca ninguém ouviu o app tocar num iPhone ou
simulador. O item `AudioSession` do `deferred-work.md` foi feito às cegas. NFR-4
promete paridade completa. Não há macOS no loop. Mitigação mínima: **uma**
execução manual de `integration_test/` num simulador iOS antes de fechar o Epic
1, com o log anexado ao gate. Se não houver Mac disponível, registrar o risco
como aceito por decisão explícita no `deferred-work.md` — hoje ele está
implícito num comentário do `ci.yaml`.

### F6 — Ações P1/P2 do test-design de 2026-09-02 ainda abertas

| Ação | Risco | Estado hoje |
|---|---|---|
| R10 — handler global de erro em `main()` | 4 | **aberto** — `main.dart` é `runApp` puro |
| R4 — lacunas do `check_module_boundaries` (barrel-only `domain/`, direção core→feature, escape de `lib/`) | 4 | **aberto** — 6 regras hoje, nenhuma das 3 |
| R6 — `flutter test --coverage` no CI | 3 | **aberto** |
| R8 — `git diff --exit-code` pós-regen no `ci.sh` | 2 | **aberto** |
| `check_app_id` sem fixture test | 2 | **aberto** |
| R7 — contraste `surface-raised` + telas de erro/boot | 4 | ✅ **fechado** (`contrast_test` itera `surface-raised`; `accessibility_test` cobre `DatabaseErrorScreen`) |
| R5 — reconciliar `content-model.md` / `epics.md` | 4 | ✅ **fechado** (2026-09-02) |
| TQ — `dart_test.yaml` com tags | — | ✅ parcial: tags definidas, só `migration` em uso; `slow`/`e2e` não aplicadas |

Nenhum destes bloqueia a 1.9. R10 e R6 valem antes do fechamento do épico.

### F7 — Esperas fixas no E2E on-device · **score 2 (P1×I2) 🟢**

`tester.pump(const Duration(seconds: 5|6))` para "deixar o player real tocar".
Funciona (24/25), mas é o tipo de espera que vira flake num runner lento. Quando
o burn-in (F1) estiver de pé, se aparecer falha aqui, trocar por um sinal de
conclusão observável (o `FakeAudioService` já modela isso; o real pode expor
`playbackCompleted` ou o teste pode observar o estado do notifier).

## 4. NFRs — situação

| NFR | Status | Evidência |
|---|---|---|
| NFR-1 áudio real, nunca síntese | ✅ | `audio_assets_bundle_test` + `docs/audio/samples-v1.md` (proveniência) |
| NFR-2 tom de música, não aula | 🟡 | microcopy revisada por teste de texto; sem golden visual |
| NFR-3 local-first | ✅ | sem rede no código; Drift em `path_provider` |
| NFR-4 paridade iOS/Android | 🟡 | ver F5 |
| NFR-5 acessibilidade | ✅ base | contraste AA em todos os pares light/dark; `TextScaler(2.0/2.2)` no shell, erro e exercício; `Semantics` em 8 pontos da tela; alvos ≥ 48 dp na `NavigationBar` — **falta** asserção de alvo ≥ 48 dp nos botões de opção do exercício |
| Reliability — handler global de erro | ❌ | R10 |
| Maintainability — cobertura visível | ❌ | R6 |

## 5. Decisão de gate

**CONCERNS 🟡** — para o escopo entregue (1.1–1.8).

- **Pode seguir para a Story 1.9? Sim.** Suíte verde, sem skip, cada AC lido tem
  teste, E2E on-device estável na janela observada, migração com harness.
- **Pode fechar o Epic 1 nesse estado? Não.** Faltam: burn-in real (F1),
  rastreabilidade formal de 1.4–1.8 (F2), decisão explícita sobre iOS (F5), e
  R10.
- **Sem FAIL** porque: zero testes falhando, zero NONE por leitura, zero score 9.

## 6. Próximos passos — ordem recomendada

| # | Ação | Por quê agora | Custo | Dono |
|---|---|---|---|---|
| 1 | ~~Consertar `e2e-burn-in.yaml`~~ **feito** — falta mergear, disparar manual com 3 iterações e ler a tally | F1: um gate morto há 8 dias; sem isso não há número para tornar `e2e-android` obrigatório | 1 run | dev |
| 2 | ~~Extrair o notifier de `interval_exercise_screen.dart` e renomear (F4)~~ **feito** — Story 1.8b (`practice_controller.dart` / `exercise_card_flow.dart` / `practice_screen.dart`), spec + review em `spec-1-8b-costura-do-card-de-exercicio.md` | A 1.9 vai reusar o fluxo de prática; refatorar depois custa o dobro | 1 PR mecânico | Winston + dev |
| 3 | `bmad-testarch-trace` para 1.4–1.8 (F2) | Fecha a lacuna de evidência antes de o épico fechar; não bloqueia a 1.9, pode rodar em paralelo | 1 sessão | Murat |
| 4 | **Story 1.9** com ATDD (`bmad-testarch-atdd`) — o nivelamento tem 7 ACs com regras de borda (zero acertos, primeiro exercício fácil, nível persistido = v3 do schema) | É a story mais rica em regra de negócio que resta no épico | normal | dev |
| 5 | R10 — `FlutterError.onError` + `PlatformDispatcher.onError` em `main()` com teste | Antes de fechar o épico: crash sem trilha em produção | 1 h | dev |
| 6 | Story 1.10 (Settings) — pequena; incluir o item "Microfone" desabilitado como gancho do Epic 3 | Fecha o épico | normal | dev |
| 7 | Decisão sobre iOS (F5): 1 run manual em simulador **ou** aceite explícito no `deferred-work.md` | NFR-4 | 30 min ou 5 min | humano |
| 8 | Gate de fechamento do Epic 1: `GATE` (test-review final + trace Fase 2) + retro | Formaliza o fechamento; o retro de 2026-09-02 foi de meio-épico | 1 sessão | Murat |
| 9 | Oportunista: R6 (cobertura informativa), R8, `check_app_id` test, tags `slow`/`e2e`, limpar `planejamento.md` e o comentário órfão do E2E, R12 | Dívida pequena e conhecida | pequeno | dev |

O item 2 é o único em que a ordem importa de verdade: fazer **antes** da 1.9.
