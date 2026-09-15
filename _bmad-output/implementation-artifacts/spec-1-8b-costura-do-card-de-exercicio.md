---
title: 'Story 1.8b — Costura do card de exercício (pré-1.9)'
type: 'refactor'
created: '2026-09-15'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '5903ac0defcf5c4b1e96906183414ab42df0c102'
context:
  - '{project-root}/_bmad-output/test-artifacts/quality-review-epic-1-2026-09-15.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `lib/exercicios/presentation/interval_exercise_screen.dart` (1.031 linhas) solda o card de exercício (`_ActiveExerciseView`: motif, opções, pick, flourish, balão de erro, auto-avanço) ao notifier de *sessão* — o card chama `ref.read(intervalPracticeProvider.notifier).answer/advance` direto. A Story 1.9 (Nivelamento, módulo próprio por AD-1) precisa desse card com outro notifier; hoje só o obtém copiando ~400 linhas ou virando um "modo" do notifier de sessão. Achado F4 do quality review; decisão do arquiteto em 2026-09-15.

**Approach:** Dividir o arquivo em três no corte que solta o card: `practice_controller.dart` (notifier + timings, só move/renomeia), `exercise_card_flow.dart` (`ExerciseCardFlow` público, dirigido por dois callbacks) e `practice_screen.dart` (tela de sessão, privada no resto). Comportamento observável idêntico.

## Boundaries & Constraints

**Always:**

- **Comportamento idêntico.** Mesmos textos, timings, fases, emissões e histórico de variações. Os 366 testes e 22 E2E existentes passam com **só renomes** (símbolos/paths), nunca com mudança de asserção.
- **A única mudança de código real** é em `ExerciseCardFlow`: os dois `ref.read(...notifier)` viram `onAnswer(AnswerOption option, int reactionTimeMs)` e `onAdvance()`. `onAnswer` devolve `bool wasCorrect` (o card precisa saber síncrono se toca o flourish; a regra de acerto continua no notifier, não no widget). O card continua lendo `audioServiceProvider` e `practiceTimingsProvider` sozinho e continua recebendo `PracticeState` — o segundo consumidor (1.9) diz se esse tipo precisa afinar; Regra de Três.
- **Renomes:** `IntervalPractice` → `PracticeController` (`practiceControllerProvider`); `IntervalExerciseScreen` → `PracticeScreen`; `_ActiveExerciseView` → `ExerciseCardFlow`. Rota `Home → Praticar` inalterada.
- **Barrel `exercicios.dart`** exporta `PracticeScreen` e `ExerciseCardFlow` via `show`; o E2E passa a importar só o barrel.
- **Regra 6** (`check_module_boundaries`) continua valendo sobre os três arquivos novos — nenhum nomeia tipo de exercício.
- **Spine:** AD-1 ganha a aresta `Nivelamento --> Exercicios` no grafo e uma frase: um módulo pode reexportar de `presentation/` via barrel `show` um widget que é contrato de UI compartilhado (precedente: `IntervalExerciseScreen` exportado para o shell desde a 1.4).
- **Testes:** o arquivo de 1.978 linhas é **dividido mecanicamente** por tema (card vs. sessão/report/variação), mantendo cada teste dirigindo a tela real; **mais** um `exercise_card_flow_test.dart` novo que prova a costura: `ExerciseCardFlow` montado sozinho, com `PracticeState` construído à mão e callbacks gravados, sem catálogo nem notifier no container.
- **`sprint-status.yaml`** ganha `1-8b-costura-do-card-de-exercicio` (precedente 1.5a).

**Never:**

- Mover o notifier para `domain/` (AD-5: notifier é apresentação). Criar interface `ExerciseDriver`. Mudar o balão de erro. Tocar em `lib/exercicios/domain/**`, `lib/audio/**`, `assets/**`, schema.
- Reescrever asserções dos testes existentes para "encaixar" — se um teste precisa mudar semanticamente, a refatoração vazou.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Card sozinho, acerto | `ExerciseCardFlow` com `PracticeState` manual; `onAnswer` devolve `true` | chama `onAnswer(opção, ms>0)` uma vez; flourish; `onAdvance` após `advanceDelay`; nenhum `practiceControllerProvider` lido | N/A |
| Card sozinho, erro | `onAnswer` devolve `false` | sem flourish; "Continuar" aparece; tap → `onAdvance` uma vez | N/A |
| Card sozinho, tap duplo | dois taps síncronos | `onAnswer` chamado uma vez | N/A |
| Card sozinho, áudio falha | `AudioService` que lança | banner aditivo, opções liberadas, replay recupera | erro vira `SamplePlaybackFailed` |
| Tela de sessão | catálogo real, 39 posições | tudo como antes: oferta aos 12 min, report 1×, histórico gravado | idem hoje |
| Regra 6 | os 3 arquivos novos | `check_module_boundaries` exit 0 | build reprova se vazar |

</frozen-after-approval>

## Code Map

- `lib/exercicios/presentation/interval_exercise_screen.dart` -- origem; `:76-104` `PracticeTimings`+providers, `:105-360` notifier, `:362-432` tela+`_RetryView`/`_EndOfferView`/`_EndOfSessionView` (`:859-1031`), `:433-658` `_ActiveExerciseView`, `:659-858` `_OptionButton`/`_ResultLine`/`_MascotBubble`/`_AudioErrorBanner`. Apagar após a divisão. `part 'interval_exercise_screen.g.dart'` → cada arquivo com `@riverpod` ganha o seu `part`.
- `:550-583` `_pick` -- o acoplamento: `answer()` + leitura de `phase == correct` → vira `final ok = widget.onAnswer(option, ms)`.
- `:599-605` `_advance` -- `→ widget.onAdvance()`.
- `lib/exercicios/exercicios.dart:27` -- export do screen; trocar por `practice_screen.dart show PracticeScreen` + `exercise_card_flow.dart show ExerciseCardFlow`.
- `lib/app/home_screen.dart:28` -- `IntervalExerciseScreen()` → `PracticeScreen()`.
- `integration_test/catear_e2e_test.dart:30,399` -- remover import direto de `presentation/`; `find.byType(PracticeScreen)`.
- `test/exercicios/interval_exercise_screen_test.dart` -- helpers `:19-286` (`_container`, `_app`, `_state`, `_answerAndAdvance`, fakes) vão para `test/exercicios/support/practice_harness.dart`; testes `:288-1377` (card, a11y, tipos, bubble, timings) → `practice_screen_test.dart`; `:1405-1946` (sessão, oferta, report, histórico) → `practice_session_test.dart`. Só renomes.
- `test/exercicios/home_praticar_test.dart:30,35` -- rename.
- `test/module_boundary_test.dart:295-312` -- fixture já usa `practice_screen.dart`; sem mudança.
- `tool/check_module_boundaries.dart:44,131` -- comentários citam `IntervalExerciseScreen` como exemplo de near-miss; atualizar para `PracticeScreen`.
- `lib/exercicios/presentation/exercise_card.dart`, `phrase_player.dart` -- reusar sem tocar.
- `_bmad-output/planning-artifacts/architecture/architecture-CatEar-2026-08-26/ARCHITECTURE-SPINE.md:35,113-124` -- AD-1 frase + aresta no grafo.

## Tasks & Acceptance

**Execution:**
- [x] `lib/exercicios/presentation/practice_controller.dart` -- mover `PracticeTimings`, `practiceTimingsProvider`, `practiceExerciseTypesProvider`, notifier renomeado `PracticeController`; docs do topo do arquivo antigo que falam de sessão vêm junto -- zero lógica nova
- [x] `lib/exercicios/presentation/exercise_card_flow.dart` -- `ExerciseCardFlow({required state, required onAnswer, required onAdvance})` + 4 widgets privados; callbacks no lugar dos `ref.read` -- a costura
- [x] `lib/exercicios/presentation/practice_screen.dart` -- `PracticeScreen` + 3 views de sessão; passa `onAnswer: (o, ms) { c.answer(o, ms); return c.state.value?.phase == correct; }`, `onAdvance: c.advance` -- consumidor 1
- [x] apagar `interval_exercise_screen.dart`; `dart run build_runner build` -- regenera `.g.dart`
- [x] `lib/exercicios/exercicios.dart`, `lib/app/home_screen.dart`, `integration_test/catear_e2e_test.dart`, `tool/check_module_boundaries.dart` -- renomes
- [x] `test/exercicios/support/practice_harness.dart`, `practice_screen_test.dart`, `practice_session_test.dart` -- divisão mecânica; apagar o arquivo antigo
- [x] `test/exercicios/exercise_card_flow_test.dart` -- as 4 linhas "card sozinho" da matriz
- [x] `ARCHITECTURE-SPINE.md`, `sprint-status.yaml` -- aresta + frase; story `in-progress`

**Acceptance Criteria:**
- Given o app, when Home → Praticar, then a sessão se comporta exatamente como no baseline (`5903ac0`) — nenhum teste existente mudou de asserção.
- Given `ExerciseCardFlow` num `ProviderScope` sem override de `practiceControllerProvider` nem de catálogo, when um teste o monta e responde, then os callbacks são chamados e nenhum provider de sessão é lido.
- Given `dart run tool/ci.sh`, when roda, then exit 0.

## Implementation Notes

- **Barrel exporta também `practiceExerciseTypesProvider`** (`practice_controller.dart show practiceExerciseTypesProvider`). O E2E (`integration_test/catear_e2e_test.dart:69`) já usava esse seam para estreitar o loop a um tipo — via o import direto de `presentation/` que a spec manda remover. Sem o reexport, "o E2E importa só o barrel" e "comportamento idêntico" não fecham ao mesmo tempo. O notifier continua interno.
- **`tool/check_module_boundaries.dart`:** os dois comentários de near-miss não puderam virar literalmente `PracticeScreen` — o exemplo precisa ser um identificador que *contém* um nome banido, e `PracticeScreen` não contém. Ficou `IntervalExerciseScreen` explicado como "nome pré-1.8b de `PracticeScreen`, mantido como fixture em `test/module_boundary_test.dart`". Por isso o grep de verificação devolve 2 linhas em `tool/` + a fixture (`test/module_boundary_test.dart:302`, que a spec manda não tocar); `lib/`, `integration_test/` e os testes de exercício estão limpos.
- **`README.md`** (fora do Code Map): duas linhas citavam `IntervalExerciseScreen` / `interval_exercise_screen.dart` como monólito a refatorar — atualizadas para os três arquivos novos e o item de dívida removido. Doc-only.
- **Testes:** 366 → 373 (`exercise_card_flow_test.dart` = as 4 linhas "card sozinho" da matriz + 1 para o `catch` amplo virar `SamplePlaybackFailed` + 1 para o rebuild com `phase: correct`; `practice_screen_test.dart` + 1 para o contrato do dono `key: ValueKey(state.index)`, que falha sem a key). A prova de "nenhum provider de sessão lido" é um `ProviderObserver` que loga tudo que o container inicializa e uma allowlist: o conjunto é exatamente `{audioServiceProvider, practiceTimingsProvider}`. A divisão mecânica foi conferida por diff token-a-token módulo o mapa de renomes: 54/54 testes, 589/589 linhas de asserção iguais; as únicas diferenças são cabeçalhos, re-wraps do `dart format`, `activeView()` que virou `find.byType(ExerciseCardFlow)` (o card é público agora) e `PushToPractice({super.key})` exigido pelo lint em widget público.
- **Helpers do harness** viraram públicos com prefixo onde o nome colidia com variáveis locais: `_container`→`practiceContainer`, `_app`→`practiceApp`, `_state`→`stateOf`; o resto só perdeu o `_`.
- **E2E on-device não rodado** aqui (sem emulador nesta sessão) — confiar no job `e2e-android` do PR. O import direto foi removido e `find.byType(PracticeScreen)` compila (`flutter analyze` limpo).

## Spec Change Log

## Review Triage Log

Passo 4, iteração 0 (2026-09-15). BH = blind hunter · EC = edge-case hunter · VG = verification-gap.

| # | Achado | Veredito | Evidência | Rota |
|---|---|---|---|---|
| BH1 | AD-1 do spine: as frases "Rule" e "Enforcement" (`:35,:37`) contradizem o parágrafo novo (`:39`) | medium | Verificado: as duas frases dizem "nunca importa `presentation/`" / "só `domain/`" sem apontar a exceção; um revisor da 1.9 lendo só a regra marca `Nivelamento → Exercicios` como violação | patch (P1) |
| BH2 / EC5 | Barrel exporta `practiceExerciseTypesProvider`; o parágrafo do spine só cobre "widget"; task diz "renomes" | low | O bloco congelado não diz "só"; a exportação está justificada nas Implementation Notes e segue a convenção (barrels de `audio`/`progressao` já exportam providers). Falta só a frase do spine cobrir o seam | patch (P1, junto com BH1) |
| BH3 | `## Verification` do spec espera grep vazio, devolve 3 linhas | — | Rejeitado: a correção é editar o spec desta build. As 3 linhas (2 comentários em `tool/` + fixture) estão explicadas nas Implementation Notes | rejeitado |
| BH4 | Status inconsistente: spec `in-review`, sprint-status `in-progress` | low | Verdadeiro; é o estado intermediário do próprio workflow | patch (sync no passo 5) |
| BH5 | README ainda diz 366 testes em 3 lugares (`:31,:86,:123`) | low | Verificado por grep; são 371 | patch (P2) |
| BH6 / EC6 | `deferred-work.md` cita `interval_exercise_screen.dart` / `_ActiveExerciseViewState` / `interval_exercise_screen_test.dart` em ~12 evidências (`:203-293,:481,:503`) de itens abertos | medium | Verificado por grep; o dono de cada item não encontra mais o código nomeado | patch (P3) |
| BH7 | Doc pública do `ExerciseCardFlow` não diz que o dono precisa manter `audioServiceProvider` vivo (`listenManual`) | medium | Verificado: o card faz `ref.read(audioServiceProvider)` no `initState` e a obrigação só está num comentário privado "see `PracticeScreen`"; a 1.9 que copiar o teste isolado como gabarito reproduz a regressão de auto-dispose que a E2E "Praticar plays a real interval motif" existe para pegar | patch (P4) |
| BH8 | `onAnswer` não documenta que precisa atualizar estado de forma síncrona (o `_revealContinue` depende do rebuild no frame seguinte) | low | Verificado: com dono assíncrono o scroll até "Continuar" vira no-op silencioso (é o que o teste de viewport 360×640 protege na tela real) | patch (P4) |
| EC4 | Card montado com `index >= loop.length` → `RangeError` cru | low | Verificado, mas é falha ruidosa numa situação que nenhum caminho do app alcança (a tela só monta o card nas fases answering/correct/incorrect). Vira uma linha de pré-condição na doc | patch (P4) |
| BH9 | Card importa `practice_controller.dart` por causa de `PracticeTimings`; sugere `practice_timings.dart` | low | Verdadeiro no import graph, sem ciclo; o card lê só `flourishGap`/`advanceDelay`. A correção adiciona arquivo e superfície pública — fora do que o intent pede | rejeitado (low, fix > correção direta) |
| BH10 | `_expectNoSessionProviderRead` é denylist incompleta (`variantHistoryRepositoryProvider`, `sessionResultReporterProvider` não checados) | medium | Verificado: um card que passasse a ler o histórico passaria no teste que existe para impedir isso | patch (P5) |
| BH11 | Suíte isolada nunca re-pumpa o card com `AnswerPhase.correct` ("Isso!", "Continuar" durante a celebração) | low | Verificado: só o caminho `incorrect` tem o rebuild do dono; o gabarito da 1.9 fica pela metade | patch (P6) |
| BH12 | Sem `typedef` para o callback | low | Adiciona superfície pública que dois consumidores não pedem ainda | rejeitado |
| BH13 | `interval_exercise_screen.g.dart` órfão em checkouts existentes quebra `flutter analyze` até rodar `build_runner --delete-conflicting-outputs` | low | Verdadeiro (`.g.dart` é git-ignorado); não é correção de código — vai na descrição do PR | rejeitado (nota no PR) |
| VG1 / EC3 | A obrigação "key por exercício" do dono não é observada por teste: removendo `key: ValueKey(state.index)` os 54 testes de tela/sessão e os 5 do card passam, e o aprendiz trava no 2º card | medium | Pré-verificado por mutação pelo VG (rodei o mesmo mutante: 54/54 verdes). O `assert` em `didUpdateWidget` (EC3) fica de fora — mudaria comportamento fora do que o intent permite; o teste basta | patch (P7) |
| EC1 | "Ouvir de novo" durante o flourish (~510 ms) arma o timer de auto-avanço depois do replay começar; card avança no meio do replay | medium | Verificado no código: `_playMotif` cancela o timer, mas `_pick` o arma **depois** do `await playFlourish()`. Idêntico ao baseline `:570-573` — pré-existente, não causado por esta story | defer |
| EC2 | `PracticeScreen._answer`: `notifier.answer()` faz early-return e o card lê como "errado" → trava | false | `widget.state` é o mesmo valor que `ref.watch(practiceControllerProvider)` produziu no mesmo build; o guard do card (`_s.phase != answering`) roda antes com esse valor. Comportamento byte-idêntico ao baseline (que lia `.value?.phase == correct` no mesmo ponto) | rejeitado |

## Design Notes

`onAnswer` devolve `bool` e não `void` porque `_pick` decide flourish vs. "Continuar" **antes** do rebuild do pai; ler `widget.state.phase` ali é ler o estado velho. A alternativa (`option.id == state.answer.id` no widget) duplicaria a regra de `ExerciseAttempt.forAnswer`.

Os testes existentes **não** são reescritos para dirigir o card isolado: são 40+ testes que protegem comportamento; reescrevê-los é onde uma refatoração perde cobertura sem ninguém ver. A prova da costura é um arquivo novo e pequeno — é também o gabarito que a 1.9 copia.

## Verification

**Commands:**
- `dart run tool/ci.sh` -- expected: `CI: OK`; `flutter test` = 366 + novos do `exercise_card_flow_test`, 0 falhas
- `git diff --stat 5903ac0 -- test/` -- expected: só renomes/moves nos arquivos antigos (revisar o diff das asserções manualmente: nenhuma mudou)
- `grep -rn "IntervalExerciseScreen\|intervalPracticeProvider\|IntervalPractice\b" lib test integration_test tool` -- expected: vazio
- `flutter test integration_test` num emulador -- expected: 22 passed (ou confiar no job `e2e-android` do PR)
