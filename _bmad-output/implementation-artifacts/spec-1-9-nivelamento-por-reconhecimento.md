---
title: 'Story 1.9 — Nivelamento por reconhecimento'
type: 'feature'
created: '2026-09-15'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '57aad049114607303c6ebb85584a978e737ee748'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-8b-costura-do-card-de-exercicio.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O app abre na Home para todo mundo; não há nivelamento, nível de partida nem "primeira vitória" (FR-1, porção de reconhecimento; UX-DR12 "primeiro uso abre direto no Nivelamento"). O Epic 2 (Story 2.1) precisa de um nível de partida persistido para abrir os nós do skill tree.

**Approach:** Novo módulo `nivelamento/` com notifier próprio que monta o `ExerciseCardFlow` (1.8b) numa sequência curta e fixa de reconhecimento de intervalos, abre com boas-vindas do mascote, termina sempre num momento positivo, atribui um nível de partida e o persiste através de um port do módulo Progressão (dono único, AD-2). O gate de boot em `CatEarApp` roteia para o nivelamento enquanto não houver nível persistido.

## Boundaries & Constraints

**Always:**

- **Primeiro uso = nenhum nível persistido.** `CatEarApp`, depois do banco abrir, lê o nível pelo `domain/` da Progressão: ausente → `NivelamentoScreen` em tela cheia (sem tab bar, sem login); presente → `HomeShell`. Nivelamento abandonado (app fechado no meio) recomeça do zero na próxima abertura — nada parcial é persistido.
- **O card é o `ExerciseCardFlow`** importado do barrel `exercicios.dart`, dirigido pelo notifier do nivelamento; obrigações do dono cumpridas (key por exercício, `listenManual(audioServiceProvider)` pela vida da rota, `onAnswer` síncrono, montar só com exercício corrente). Nenhuma cópia de widget; nenhum `if (isLeveling)` no `PracticeController`.
- **Primeiro exercício deliberadamente fácil:** resposta `P8 asc`, e as 4 opções são a resposta + as 3 **mais distantes** em semitons do pool de intervalos (portanto `P1` está entre elas). Os demais exercícios usam `answerOptionsFor` como a prática (3 mais próximas).
- **Sequência (decisão humana, 2026-09-15):** 7 intervalos ascendentes, um por estágio de intervalo, em ordem de dificuldade, refs do catálogo: `P8` (s-consonancias) → `M3` (s-tercas) → `M2` (s-segundas) → `P4` (s-quarta) → `M6` (s-sextas) → `m7` (s-setimas) → `TT` (s-tritono). Fixa em código no `domain/` do nivelamento; mudar = recompilar.
- **Nível de partida (decisão humana, 2026-09-15):** o `stageId` do **primeiro estágio em que errou**; acertou todos → `s-tritono`; 0 acertos → `s-consonancias`. Persistido como texto. Nome humano por tabela `stageId → nameUi` no `domain/` do nivelamento (ex.: "Consonâncias", "Terças", "Segundas", "Quarta", "Sextas", "Sétimas", "Trítono") — o catálogo não muda.
- **Áudio:** refs do catálogo verbatim (`questionFor(exercise)`), sem variação e sem gravar no histórico de variações — o nivelamento não é uma Sessão de Exercício (AD-2: não emite `SessionResultReported` nem `BaselineRecorded`).
- **Fim sempre positivo (mascote em `MascotBubble`):** ≥1 acerto → celebra a primeira vitória nomeando-a ("Essa foi sua primeira vitória"); 0 acertos → celebra a conclusão e o começo ("Você deu o primeiro passo — é daqui que a gente parte") **sem** mostrar placar. A tela final mostra o nível de partida com nome humano e um único CTA que leva à `HomeShell` (aba Home, onde já existe "Praticar").
- **Boas-vindas:** `MascotBubble` antes do primeiro card; nunca durante o áudio (UX-DR4). O balão de erro do card continua como na prática (nomeia a confusão).
- **Nível persistido pela Progressão:** tabela nova `placements` (schema **v3**: `stageId` texto, `correctCount` int, `recordedAt` ISO-8601 UTC), port `PlacementRepository` em `progressao/domain/` (`current()` / `record(...)`), implementação Drift em `progressao/data/`, provider exportado no barrel. Nivelamento escreve **só** por esse port. Migração 2→3 com dados sobrevivendo, snapshots e `migration_test` estendidos. Spine AD-2 ganha "nível de partida" na lista de dados da Progressão.
- **`MascotBubble` sai de `exercise_card_flow.dart` para `lib/core/widgets/mascot_bubble.dart`** (público; UX-DR4 pede o balão em 4 lugares). Move puro, `exercicios` passa a importar de `core`. Fecha o item de `deferred-work.md` sobre `_MascotBubble` privado.
- **Testes existentes continuam verdes:** os harnesses que hoje esperam `HomeShell` no boot (widget: `cat_ear_app_test`; E2E: `pumpApp`) passam a partir de "nível já registrado" — no widget test por override do provider de leitura da Progressão; no E2E gravando um placement no Drift em memória pelo port real antes do `pumpWidget` (caminho real, nada mockado). Nenhuma asserção existente muda.
- **A11y como nas telas atuais:** `Semantics` em cada interativo, `TextScaler(2.0)` sem overflow no welcome/summary, alvos ≥ 48 dp.

**Never:**

- Pedir microfone, gravar voz, mostrar item de voz (Epic 3). Login/conta.
- Mudar o schema do catálogo JSON (Ask First desde a 1.2) — decidido: não muda.
- Tocar em `lib/exercicios/domain/**` além de importar; mudar `PracticeController`/`PracticeScreen`.
- Expor placar quando houve zero acertos; vermelho saturado; "errado" seco.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Primeiro boot | DB aberto, `placements` vazia | `NivelamentoScreen` (welcome bubble), sem `NavigationBar` | N/A |
| Boot com nível | `placements` tem 1 linha | `HomeShell` aba Home, como hoje | N/A |
| Q1 fácil | primeiro card | resposta `P8 asc`; opções contêm `P1`; motif = refs do catálogo | N/A |
| Acerto | tap na resposta | flourish, sem mascote, avança (contrato do card) | N/A |
| Erro | tap em distrator | bubble nomeia a confusão, "Continuar" | N/A |
| Fim com ≥1 acerto | último `onAdvance` | summary: bubble "primeira vitória" + nível nomeado + CTA Home; `placements` tem 1 linha | gravação falha → summary mesmo assim, erro logado, nível fica na memória para o CTA seguir |
| Fim com 0 acertos | idem | summary: bubble de "primeiro passo", **sem** número de acertos, nível = 1º estágio; CTA Home | idem |
| CTA Home | tap | `HomeShell` aba Home; back não volta ao nivelamento | N/A |
| Abandono | app fechado no meio | próximo boot: nivelamento do zero, `placements` vazia | N/A |
| Áudio falha | `AudioService` lança | banner do card, opções liberadas (contrato do card) | `SamplePlaybackFailed` |
| Catálogo falha | `CurriculoError` | estado de retry como na `PracticeScreen` | nunca tela branca |
| Migração 2→3 | banco v2 com `recent_variants` | linhas sobrevivem; `placements` criada vazia | `migration_test` |

</frozen-after-approval>

## Code Map

- `lib/app/cat_ear_app.dart:17-36` -- gate `database.when(data: HomeShell)`; passa a `data: (_) => const _EntryGate()` que faz `ref.watch(placementProvider)` (Progressão) e escolhe `NivelamentoScreen` / `HomeShell`; loading do placement usa o mesmo `_BootScreen`.
- `lib/app/home_screen.dart:26-31` -- CTA "Praticar" existente; o summary do nivelamento navega para cá via `HomeShell` (`Navigator.pushAndRemoveUntil` ou troca do gate — o gate re-lê o provider após `record`, então basta invalidar `placementProvider`).
- `lib/exercicios/presentation/exercise_card_flow.dart` -- `ExerciseCardFlow({state, onAnswer, onAdvance})`; doc da classe lista as obrigações do dono. `_MascotBubble` (`:442-490`) sai daqui para `core/widgets/`.
- `lib/exercicios/presentation/practice_screen.dart:60-130` -- **modelo** do dono: `listenManual(audioServiceProvider)` no `initState`, `_answer` devolve `phase == correct`, `key: ValueKey(state.index)`, `_RetryView` para `CurriculoError`.
- `lib/exercicios/domain/practice_state.dart` -- `PracticeState` (session, loop, pool, index, options, phase, attempts, picked); o nivelamento reusa o tipo com `session` mínima. `AnswerPhase`.
- `lib/exercicios/domain/exercise_question.dart:226` -- `questionFor(exercise)` (refs verbatim). `AnswerOption.distanceTo`.
- `lib/exercicios/domain/interval_options.dart:56-89` -- `answerOptionsFor(answer, pool, seed:)` = 3 **mais próximas**; para a Q1 o nivelamento escreve a variante "3 mais distantes" no seu `domain/`.
- `lib/exercicios/domain/interval_practice.dart:149` -- `practicePool(curriculum, types:)` para o pool de intervalos.
- `lib/exercicios/domain/exercise_attempt.dart:51` -- `ExerciseAttempt.forAnswer(...)` para registrar acerto/erro e alimentar o balão de erro do card.
- `lib/exercicios/exercicios.dart` -- barrel; já exporta `ExerciseCardFlow`, `PracticeState`, `questionFor`, `answerOptionsFor`, `practicePool`, `ExerciseAttempt`. Conferir `show`s.
- `lib/progressao/domain/variant_history.dart:60-78`, `lib/progressao/data/variant_history_repository_impl.dart` -- **modelo** do port + impl Drift + `@riverpod` provider (`databaseProvider.future`). `PlacementRepository` segue igual.
- `lib/core/database/recent_variants.dart`, `app_database.dart:14-35` -- tabela + DAO + `onUpgrade` `if (from < 2)`; somar `Placements` + `if (from < 3)`; `schemaVersion => 3`.
- `drift_schemas/`, `test/generated/migrations/`, `test/migration_test.dart:85-130` -- `dart run drift_dev schema dump` + `schema generate` (manual); casos 2→3 e "v3 tem exatamente recent_variants + placements".
- `lib/nivelamento/nivelamento.dart` -- barrel vazio hoje; exporta `NivelamentoScreen` (via `show`) + o que o gate precisa.
- `lib/curriculo/curriculo.dart` -- `curriculoRepositoryProvider`, `Stage.stageId/order`, `IntervalExercise.interval/direction`.
- `tool/check_module_boundaries.dart` Regra 1/5/6 -- `nivelamento/presentation/` importa só barrels; Regra 6 vale só para `exercicios/presentation/`, então o nivelamento **pode** nomear `IntervalExercise` no seu `domain/` para montar a sequência.
- `test/cat_ear_app_test.dart`, `test/home_shell_test.dart`, `test/exercicios/home_praticar_test.dart` -- esperam `HomeShell` no boot; ganham override "nível registrado".
- `integration_test/catear_e2e_test.dart:57-83` (`pumpApp`) -- grava placement no Drift em memória pelo port real antes do `pumpWidget`; somar 1 jornada E2E "primeiro boot → nivelamento completo (áudio real) → summary → Home → 2º boot cai na Home".
- `test/exercicios/exercise_card_flow_test.dart` -- gabarito de teste do card com callbacks gravados.
- `_bmad-output/planning-artifacts/architecture/.../ARCHITECTURE-SPINE.md:45-49` (AD-2 Binds/Rule) -- somar "nível de partida (Story 1.9)".
- `_bmad-output/implementation-artifacts/deferred-work.md:~481` -- item `_MascotBubble` privado → marcar resolvido.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/widgets/mascot_bubble.dart` -- mover `_MascotBubble` → `MascotBubble` público (move puro); `exercise_card_flow.dart` importa de `core` -- fecha o deferred
- [x] `lib/core/database/placements.dart` + `app_database.dart` -- tabela `Placements` + DAO; `schemaVersion => 3`; `onUpgrade` `if (from < 3)` -- schema
- [x] `drift_schemas/`, `test/generated/migrations/`, `test/migration_test.dart` -- dump, snapshot v3, casos 2→3 -- trip-wire
- [x] `lib/progressao/domain/placement.dart` + `data/placement_repository_impl.dart` + barrel -- `Placement{stageId, correctCount, recordedAt}`, `PlacementRepository{current(), record()}`, `placementRepositoryProvider`, `placementProvider` (leitura) -- dono único
- [x] `lib/nivelamento/domain/placement_sequence.dart` -- sequência fixa dos 7, opções "mais distantes" para a Q1, regra do nível (1º estágio errado), nomes humanos -- domínio puro, testável por import
- [x] `lib/nivelamento/presentation/nivelamento_controller.dart` -- notifier: monta `PracticeState`, `answer(option, ms) → bool`, `advance()`, no fim `record()` pelo port (falha → log, segue) -- dono do card
- [x] `lib/nivelamento/presentation/nivelamento_screen.dart` -- welcome bubble → `ExerciseCardFlow` keyed → summary (bubble + nível + CTA) ; `listenManual(audioServiceProvider)`; retry em `CurriculoError` -- tela
- [x] `lib/nivelamento/nivelamento.dart` -- barrel `show NivelamentoScreen`
- [x] `lib/app/cat_ear_app.dart` -- gate por `placementProvider` -- primeiro uso
- [x] `test/nivelamento/*` -- domínio (sequência, Q1 fácil, regra do nível, 0 acertos), notifier, tela (welcome, fim ≥1, fim 0 sem placar, gravação falha, a11y 2.0), gate (`cat_ear_app_test`) -- as linhas da matriz
- [x] `test/cat_ear_app_test.dart`, `home_shell_test.dart`, `exercicios/home_praticar_test.dart`, `integration_test/catear_e2e_test.dart` -- harness "nível registrado" + 1 jornada E2E nova -- verdes sem mudar asserção
- [x] `ARCHITECTURE-SPINE.md` AD-2, `deferred-work.md`, `sprint-status.yaml` -- docs

**Acceptance Criteria:**
- Given um banco vazio, when o app abre, then cai no nivelamento sem login e sem tab bar; when o usuário completa a sequência, then vê o mascote celebrar (primeira vitória se ≥1 acerto; primeiro passo sem placar se 0), o nível nomeado e um CTA que leva à Home; when o app abre de novo, then cai na Home.
- Given o primeiro card, when renderizado, then a resposta é `P8 asc` e `P1` está entre as opções.
- Given o fim do nivelamento, when o nível é gravado, then `placements` tem exatamente uma linha via `PlacementRepository`, e nenhum `SessionResultReported` nem linha em `recent_variants` foi produzida.
- Given `dart run tool/ci.sh`, when roda, then exit 0; os 373 testes existentes passam sem asserção alterada.

## Implementation Notes

- **Hand-off para a Home é do gate, não do nivelamento.** `NivelamentoScreen({required onDone})`: a tela não conhece o `HomeShell` (seria `nivelamento/presentation/` importando `lib/app/` — inversão de camada que a Regra 1 não pega porque `app/` não é módulo). O `_EntryGate` em `cat_ear_app.dart` é `ConsumerStatefulWidget`: `onDone` vira `setState(_levelled = true)` e o gate troca para o `HomeShell` **no lugar**, sem push de rota — back nunca volta ao nivelamento (não há rota atrás) e funciona mesmo quando a gravação falhou (a matriz pede "summary mesmo assim, nível fica na memória para o CTA seguir"; invalidar `placementProvider` sozinho deixaria o aprendiz preso no summary nesse caso). O CTA espera `NivelamentoController.recorded` (a escrita em voo, que nunca rejeita) antes de chamar `onDone`, para o 2º boot ser determinístico no E2E.
- **Leitura do nível falha no boot** (linha ausente da matriz): o banco já abriu, então é a mesma classe de problema que um open falho — `DatabaseErrorScreen` com retry que invalida `placementProvider`. Tratar erro como "sem nível" mandaria um aprendiz já nivelado de volta ao nivelamento e sobrescreveria o nível dele. Testado em `cat_ear_app_test`.
- **`placements` tem `id` autoincrement** além das 3 colunas da spec (`stageId`, `correctCount`, `recordedAt`): Drift precisa de uma chave e "exatamente uma linha" é garantido pelo DAO (`record` = `DELETE` + `INSERT` numa transação; `current()` = maior `id`). Data class gerada renomeada `PlacementRow` para não colidir com o `Placement` puro do `domain/`.
- **Retry do Riverpod 3:** um `build` que lança fica em `AsyncLoading(error:)` com backoff (200 ms → 6,4 s) antes de virar `AsyncError`; os widget tests passam pelo `pumpAndSettle` (relógio fake) como na `PracticeScreen`. O teste do notifier pina só o tipo do erro (`.error is AssetNotFound`), sem esperar os retries.
- **`test/database_test.dart`** assertava `schemaVersion == 2` — única asserção existente que mudou (→ 3), inevitável ao subir o schema; a 1.8 fez o mesmo de 1 para 2. `practice_harness.mascotBubble()` trocou o `runtimeType.toString() == '_MascotBubble'` por `find.byType(MascotBubble)` (helper, não asserção).
- **`home_shell_test` / `home_praticar_test`** montam `HomeShell` direto, não `CatEarApp` — não passam pelo gate e não precisaram de override. Só `cat_ear_app_test` ganhou `levelled` (override de `placementProvider`) nos 4 testes de boot.
- **E2E:** `pumpApp` grava um placement pelo port real (`levelledDatabase()`) por padrão e aceita `database:` para reusar o mesmo Drift em memória entre dois boots; o teste de text scaling que pumpava o próprio scope também semeia. Jornada nova `levelling (Story 1.9)`: primeiro boot → 7 cards com áudio real → summary com `placements` lida pelo port → CTA → Home → back fica na Home → 2º boot cai na Home. **Não rodado on-device nesta sessão** (sem emulador) — confiar no job `e2e-android`; compila (`flutter analyze` limpo).
- **`dart run tool/ci.sh`** na seção Verification é um typo do spec: é shell script — `bash tool/ci.sh`.
- **`PracticeState` reusado** como a spec manda; o incômodo (`session` cunhado só porque o tipo exige, `ending` setado para o `switch` ter estado terminal) foi registrado no `deferred-work.md` com `owner: dev da 3.3`, como as Design Notes pedem.

- **Primeira execução on-device (PR #34, run 35029303484):** a jornada nova passou, mas o job travou 40 min depois até o timeout de 45 min. Causa: `tester.binding.handlePopRoute()` na `HomeShell` em rota raiz — `PopScope` deixa passar no índice 0, o `Navigator` não tem o que desempilhar e o Flutter cai em `SystemNavigator.pop()`, que dá `finish()` na Activity; os plugins desanexam e o `AudioPlayer()` do grupo seguinte espera um method channel morto para sempre. O teste terminou verde porque a árvore de widgets continua viva. Corrigido no E2E: a asserção "back não volta ao nivelamento" virou `Navigator.canPop() == false` na `HomeShell` (não há rota abaixo). Lição para o `deferred-work`/harness: nunca disparar `handlePopRoute` numa rota raiz em `integration_test`.

## Spec Change Log

## Review Triage Log

Passo 4, iteração 0 (2026-09-15). BH = blind hunter · EC = edge-case hunter · VG = verification-gap.

| # | Achado | Veredito | Evidência | Rota |
|---|---|---|---|---|
| EC1 / EC2 | Riverpod 3 `defaultRetry` (10 tentativas, 200 ms→6,4 s, ~38 s) mantém `nivelamentoControllerProvider` e `placementProvider` em `loading` antes de expor o erro; `when()` mostra spinner o tempo todo | medium | Verificado em `riverpod-3.4.2/lib/src/core/element.dart:766-796` + `provider_container.dart:982`: `CurriculumError`/`NivelamentoError` são `Exception` → retry aplica. Os testes passam porque `pumpAndSettle` atravessa os timers falsos. Usuário: ~38 s de spinner na primeira tela se o catálogo falhar; ~38 s de boot se a leitura do nível falhar | patch (P1) — os dois providers novos; o caso pré-existente vai para defer |
| VG1 | Nada verifica que o CTA "Ir para a Home" espera `recorded` (mutação: fire-and-forget passa 15/15) | medium | Pré-verificado por mutação (VG) | patch (P2) |
| VG2 / BH6 | O port real `PlacementRepository` não tem teste: `record` 2× → 1 linha; `recordedAt` via `clock` em UTC; banco indisponível rejeita (mutação: sem `delete` e sem `.toUtc()` passa 59/59) | medium | Pré-verificado por mutação (VG); não existe `test/progressao/placement_test.dart` irmão do `variant_history_test.dart` | patch (P3) |
| VG3 | Estado `loading` do gate entre banco aberto e leitura do nível não é pinado (mutação: `SizedBox.shrink()` passa 8/8) | low | Pré-verificado por mutação (VG); frame em branco em todo boot passaria | patch (P4) |
| BH1 | Doc do controller diz "`ending` fica no default" mas `_finish` seta `SessionEnd.reachedEnd` | low | Verificado `:13` vs `:128` | patch (P5) |
| BH2 | Welcome hardcoda "São 7 trechos" enquanto a sequência é `placementSequence.length` | low | Verificado `:150`; o domínio diz "mudar = recompilar" e a cópia não acompanharia | patch (P5) |
| BH12 | Doc da tabela `placements` justifica "histórico de re-nivelamentos" mas `record` faz DELETE+INSERT | low | Verificado; doc contradiz o código | patch (P5) |
| BH3 (a11y) | CTA "Tentar de novo" do `_RetryView` do nivelamento sem `Semantics(button, label)` nem altura ≥ 48 dp, ao contrário dos outros CTAs da tela; bloco congelado exige "Semantics em cada interativo, alvos ≥ 48 dp" | medium | Verificado: `FilledButton` cru (`:280`), altura Material default 40 dp | patch (P6) |
| BH3 (duplicação) | `_RetryView` é cópia verbatim do de `practice_screen.dart` (diff = 0 linhas) | low | Verdadeiro; compartilhar exige tocar `PracticeScreen`, que o bloco congelado proíbe | defer |
| BH9 | Segundo tap em "Ir para a Home" enquanto `recorded` pende chama `onDone` duas vezes; doc diz "chamado uma vez" | low | Verificado `_goHome:77-81` sem guarda; o gate é idempotente (`setState` repetido), então o dano hoje é só o contrato | patch (P7) |
| BH10 | Summary monta dois `Semantics(liveRegion: true)` no mesmo frame (bubble + nome do nível) — anúncio duplo em ordem indefinida | low | Verificado `:214,:266`; a `PracticeScreen` mantém uma live region por view | patch (P8) |
| BH11 | README `:11` ainda diz "9 de 11 stories, última 1.8"; sem linha 1.8b/1.9 na tabela | low | Verificado por grep (a linha `:13` foi atualizada, a `:11` e a tabela não) | patch (P9) |
| EC3 | Retry do gate invalida só `placementProvider`; conexão morta re-lê o mesmo handle | low | Verificado `cat_ear_app.dart:73`; `placementRepositoryProvider` observa `databaseProvider.future`, então invalidar os dois reabre — correção de uma linha | patch (P10) |
| BH4 | Status em três lugares (spec `in-review`, sprint `in-progress`, README) | low | Estado intermediário do workflow; sincronizado no passo 5 | patch (passo 5) |
| BH5 / EC7 | AC congelada "os 373 testes existentes passam sem asserção alterada" vs `database_test` `schemaVersion` 2→3; task da harness cita `home_shell_test`/`home_praticar_test` que não precisaram mudar | low | Verdadeiro: a própria AC congelada exige schema v3, então a asserção de versão **tem** de mudar (contradição interna; 1.8 fez o mesmo 1→2). Nenhuma asserção de comportamento mudou. Correção = editar o spec → fora da regra; **surfaceado ao humano no passo 5** | rejeitado |
| BH7 | Falta widget test do hand-off do gate andando 7 cards | low | O gate tem testes null/valor/erro; o hand-off completo é a jornada E2E nova, que roda no `e2e-android` de todo PR (VG conferiu). Duplicar os 7 cards em widget test é mais que correção direta | rejeitado |
| BH8 / EC5 | `DateTime.parse` em `recorded_at` corrompido → `FormatException` a cada boot, retry nunca recupera | low | Verdadeiro, mas o único escritor é `record`, que sempre grava `toIso8601String()`; situação não alcançável pelo app. Falha ruidosa é o comportamento correto | rejeitado |
| BH13 | Barrel exporta todo o `domain/` | low | Convenção dos outros módulos (`exercicios.dart` exporta o domínio inteiro); testes e E2E usam os símbolos | rejeitado |
| BH14 | `_RetryView` após `PlacementExerciseMissing` é beco sem saída | low | Erro determinístico de build; `placement_sequence_test` pina a sequência contra o catálogo real, então o CI reprova antes de existir um build assim | rejeitado |
| EC4 | `placementOptionsFor` Q1 sem pool de intervalo → botão único | low | `placementPool` é os 13 intervalos, pinado por teste; inalcançável | rejeitado |
| EC6 | Back do sistema na tela de nivelamento (rota raiz) sai do app sem confirmação | low | Comportamento padrão da rota raiz no Android e igual à linha "Abandono" da matriz congelada (recomeça do zero). Diálogo de confirmação seria UX fora do intent — mencionado ao humano | rejeitado |

## Design Notes

O nivelamento **reusa `PracticeState`** em vez de criar um estado próprio: o `ExerciseCardFlow` o exige, e a Regra de Três (1.8b) mandou esperar o segundo consumidor dizer o que precisa afinar — este é ele; se `session`/`endOffered`/`ending` incomodarem, registrar no `deferred-work.md` para a 3.3 decidir, não abstrair agora.

Gravação do nível **no fim, não a cada resposta**: abandono = nada persistido, e o summary é o único ponto em que o nível existe. Falha de gravação não pode roubar a primeira vitória — o summary aparece de qualquer jeito e o gate re-tenta ler no próximo boot (cai no nivelamento de novo; aceitável, raro, logado).

## Verification

**Commands:**
- `dart run tool/ci.sh` -- expected: `CI: OK`; `flutter test` ≥ 373 + novos, 0 falhas
- `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/ && dart run drift_dev schema generate drift_schemas/ test/generated/migrations/` -- expected: `versions [1,2,3]`
- `flutter test integration_test` em emulador -- expected: 23 passed (ou o job `e2e-android` do PR)
- `dart run tool/check_module_boundaries.dart` -- expected: OK (nivelamento importa só barrels)
