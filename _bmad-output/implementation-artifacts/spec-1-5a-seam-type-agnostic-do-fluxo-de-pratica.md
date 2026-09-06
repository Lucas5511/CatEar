---
title: 'Story 1.5a — Seam type-agnostic do fluxo de prática'
type: 'refactor'
created: '2026-09-05'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'd0ddcd009c539a881fe6549ac9642b267e4fd911'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/test-artifacts/atdd-preflight-1-5.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A AC3 da Story 1.5 proíbe "código específico por tipo de exercício no fluxo de apresentação", mas hoje a cadeia inteira abaixo do `ExerciseCard` é tipada em `IntervalSpec` / `IntervalExercise`: o state, o notifier, os botões de opção, a linha de resultado, o prompt fixo `'Que intervalo é este?'` e a resolução de `errorType`. Enquanto isso não mudar, acorde e escala só entram por duplicação — e um teste de widget passa feliz contra uma árvore duplicada, então nada hoje impede esse desfecho.

**Approach:** Trocar a maquinaria por um **modelo de resposta type-agnostic** (pergunta, opções `{id, nameUi}`, resposta, `audioSampleRefs`), com a diferença por tipo atrás dele no domínio, e travar o resultado com uma **regra estática** que proíbe os tipos de intervalo dentro de `lib/exercicios/presentation/`. O loop continua só de intervalo e o comportamento observável não muda: acorde e escala são exercitados por teste, e entram em uso na Story 1.5.

## Boundaries & Constraints

**Always:**

- **Comportamento de intervalo idêntico.** Mesmo motif, mesmas 4 opções, mesmos textos, mesma contagem de 23 exercícios no loop. Esta story é refatoração: se o usuário notar qualquer diferença, ela falhou.
- **Reusar sem tocar:** `ExerciseCard` (já recebe só `child` — o action item S1 apontava para cá por engano), a API de `PhrasePlayer`, `AnswerPhase`, `_RetryView`, `_AudioErrorBanner`, e a manobra `listenManual(audioServiceProvider)` de `initState`, que existe porque o provider é auto-dispose.
- **A regra estática é o entregável central, não um extra.** `check_module_boundaries` ganha a Regra 6: nenhum arquivo sob `lib/exercicios/presentation/` menciona `IntervalSpec` ou `IntervalExercise`. Sem ela a AC3 não tem gate — um teste de widget não distingue uma árvore genérica de três árvores duplicadas.
- **`errorType` é resolvido por `ExerciseType`, nunca por lookup global de `id`.** `scaleCatalog` tem `id: "major"` e `ErrorType.major` significa *qualidade de acorde*; um lookup global gravaria erro de escala como erro de acorde. Hoje `ExerciseAttempt.errorTypeForIntervalId` é exatamente esse lookup global.
- **Nenhum caminho de resposta lança no meio da sessão.** O `orElse: throw` atual fica fora do `AsyncValue.error` e derruba a tela. Um par (resposta, escolha) sem `errorType` correspondente resolve para `far-miss`.
- **`errorType` de escala é função do par (resposta, escolha)**, derivada dos `steps`: se os dois modos diferirem em exatamente um grau, usar o `errorType` daquele grau (3ª → `terca-alterada`, 6ª → `sexta-alterada`, 7ª → `setima-alterada`); em qualquer outro caso, `far-miss`.
- **O prompt por tipo é uma tabela por `ExerciseType` no domínio de exercícios**, fora da apresentação — decisão do humano em 2026-09-05, contra criar campo no catálogo, que mexeria no schema (Ask First desde a 1.2).
- **Acorde e escala são exercitados por teste**, renderizando um `ChordExercise` e um `ScaleExercise` pela mesma árvore de widgets. É o que prova a AC3 sem alterar o produto.

**Never:**

- Ligar acorde ou escala no loop de prática. O filtro continua selecionando só intervalo; virá-lo é a Story 1.5.
- Mudar a forma do motif, `noteGap`, `flourishGap` ou `returnHold`. As formas por tipo são da 1.5.
- Tocar em `assets/**`, `lib/audio/**`, ou no `schemaVersion` do catálogo.
- Duplicar a árvore de widgets por tipo de exercício.
- Alterar `test/exercicios/interval_practice_test.dart:21,56` (`loop.length == 23`, `pool.length == 13`) para acomodar tipos novos — nesta story esses números **não** mudam, e se mudarem é sinal de que o loop vazou.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Intervalo inalterado | o catálogo v1 real | 23 no loop, 13 no pool, 4 opções, motif de 3 eventos, textos idênticos | os testes atuais da tela passam sem edição semântica |
| Acorde pela mesma árvore | `ChordExercise` injetado em teste | renderiza sem widget específico por tipo; opções vêm de `chordCatalog` | teste falha nomeando o widget por tipo |
| Escala pela mesma árvore | `ScaleExercise` injetado em teste | idem, opções de `scaleCatalog` | idem |
| Regra 6 satisfeita | `lib/exercicios/presentation/` atual | `check_module_boundaries` sai 0 | — |
| Regra 6 violada | `IntervalSpec` reintroduzido em `presentation/` | sai 1 nomeando `arquivo:linha` | build reprova |
| Erro de escala, 1 grau | era maior, escolheu mixolídia | `errorType == setimaAlterada` | N/A |
| Erro de escala, vários graus | era maior, escolheu menor natural | `errorType == farMiss` | N/A |
| Colisão de id | escolheu escala `major` | errorType de escala, **nunca** `ErrorType.major` | teste que falharia com lookup global |
| Erro de acorde | era maior, escolheu diminuto | `errorType == diminished` | N/A |
| Par sem mapeamento | qualquer (resposta, escolha) sem regra | `far-miss` | nunca lança; a sessão continua |
| Resposta certa | qualquer tipo | `errorType == null`, flourish, avança | N/A |
| Resolução fora | catálogo com 2 exercícios `resolution` | continuam fora do loop | N/A |

</frozen-after-approval>

## Code Map

**A mudar:**

- `lib/exercicios/presentation/interval_exercise_screen.dart` -- 606 linhas, o núcleo. `IntervalPracticeState:38` (`loop:53`, `pool:56`, `options:62`, `picked:71`, `current:73`, `answer:74`), notifier `IntervalPractice:96`, `_optionsFor:112` (o `seed` usa `exercise.interval.id` + `direction`, exclusivos de intervalo), `answer(IntervalSpec):127`, `_ActiveExerciseViewState:220`, `_pick(IntervalSpec):321`, prompt fixo `:367`, `_OptionButton:407` e `_ResultLine:489` (ambos usam **só** `.id` e `.nameUi` — é o que torna a generalização barata), fim de loop `:589`. O state precisa sair de `presentation/` para a Regra 6 poder passar
- `lib/exercicios/domain/interval_practice.dart:13,22,28` -- `intervalLoop` filtra `is IntervalExercise` na `:22`; `intervalPool:28` dedupe por `.id`. Generalizar a *forma*, mantendo a seleção em intervalo
- `lib/exercicios/domain/interval_options.dart:19,30-45` -- ranqueia por `|Δsemitones|` (`:31`), pega 3 + resposta (`:37`), Fisher-Yates determinístico por `seed` (`:39-45`). `semitones` só existe em `IntervalSpec`; precisa de métrica genérica
- `lib/exercicios/domain/exercise_attempt.dart:43,58,61-65` -- `forInterval` hardcoda `ExerciseType.interval`; `errorTypeForIntervalId:58` é o lookup global, com o `orElse: throw` nas `:61-65` (único no repo)
- `tool/check_module_boundaries.dart` -- **puramente sintático hoje**: só inspeciona diretivas `import`/`export` (laço em `:101-170`). A Regra 6 é sobre *símbolos*, então precisa de varredura nova sobre o conteúdo, inserida entre `:97` e `:99`, onde `parsed.lineInfo` já existe. Atenção: `.g.dart` é filtrado da varredura. Documentar no doc-comment `:1-22`
- `test/module_boundary_test.dart:158-212` -- formato do par passa/falha a copiar; o harness monta árvores sintéticas em tempdir e roda o script como subprocesso (`write():17`, `run():23`)
- `test/exercicios/interval_exercise_screen_test.dart` -- 675 linhas, 21 `testWidgets`. Acoplamento concentrado no helper `_state:81` (~28 usos); `.answer.nameUi` presume `IntervalSpec`. Somar os casos de acorde e escala pela mesma árvore
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story

**Verificado, nada a mudar:**

- `lib/exercicios/presentation/exercise_card.dart:12-15` -- recebe só `child`; já agnóstico, e o doc-comment já prevê chord/scale
- `lib/curriculo/domain/catalogs.dart:13,43,75,101` -- os 4 specs têm `id` + `nameUi`; só `IntervalSpec` tem `semitones`
- `lib/curriculo/data/curriculo_repository_impl.dart:154` -- `_Catalogs` é privado; o app só alcança um spec através de um `Exercise`, então o pool tem de sair do `Curriculum`
- `lib/curriculo/domain/enums.dart:60` -- `ErrorType` já tem os 22 valores necessários
- `lib/exercicios/presentation/phrase_player.dart` -- a API `List<String>` já é agnóstica; a forma do motif é da 1.5

## Tasks & Acceptance

**Execution:**

- [x] 1. `lib/exercicios/domain/` -- o modelo de resposta type-agnostic (pergunta, opções `{id, nameUi}`, resposta, `audioSampleRefs`) e a estratégia por tipo atrás dele, incluindo a tabela de prompt por `ExerciseType`
- [x] 2. `lib/exercicios/domain/interval_practice.dart` -- loop e pool com forma genérica, seleção ainda em intervalo
- [x] 3. `lib/exercicios/domain/interval_options.dart` -- métrica de distância genérica, preservando a ordem determinística por `seed` que os testes atuais congelam
- [x] 4. `lib/exercicios/domain/exercise_attempt.dart` -- `errorType` por `ExerciseType`; par de escala derivado dos `steps`; `far-miss` no lugar do `orElse: throw`
- [x] 5. `lib/exercicios/presentation/interval_exercise_screen.dart` -- state movido para `domain/`; widgets tipados no modelo genérico; prompt vindo da tabela
- [x] 6. `tool/check_module_boundaries.dart` -- Regra 6, com varredura de símbolos além das diretivas
- [x] 7. `test/module_boundary_test.dart` -- par passa/falha da Regra 6
- [x] 8. `test/exercicios/interval_exercise_screen_test.dart` -- acorde e escala pela mesma árvore; os casos de intervalo existentes permanecem
- [x] 9. `_bmad-output/implementation-artifacts/sprint-status.yaml` -- `in-progress` ao começar, `review` ao abrir o PR

**Acceptance Criteria:**

- Given o catálogo v1 real, when o loop de prática é montado, then ele tem 23 exercícios e o pool 13 — inalterados por esta story.
- Given um `ChordExercise` e um `ScaleExercise` injetados em teste, when renderizados, then é a mesma árvore de widgets do intervalo, sem widget específico por tipo.
- Given `lib/exercicios/presentation/`, when `check_module_boundaries` roda, then sai 0; e reprova nomeando `arquivo:linha` se `IntervalSpec` ou `IntervalExercise` reaparecer ali.
- Given qualquer par (resposta, escolha) em qualquer tipo, when a tentativa é registrada, then `errorType` vem da taxonomia canônica ou é `far-miss` — nunca uma exceção, nunca `ErrorType.major` para uma escala.
- Given os comandos de §Verification, then todos saem com exit 0.

## Implementation Notes

- **Onde o modelo mora.** `lib/exercicios/domain/exercise_question.dart` (novo):
  `AnswerOption {id, nameUi, semitoneProfile}`, `ExerciseQuestion {type, prompt,
  answer, audioSampleRefs, variantKey}`, a tabela `exercisePrompts` por
  `ExerciseType`, e `questionFor(Exercise)` — o **único** switch sobre a sealed
  class. `lib/exercicios/domain/practice_state.dart` (novo) recebeu `AnswerPhase`
  e o state, renomeado `IntervalPracticeState` → `PracticeState`.
- **A métrica genérica é o `semitoneProfile`** — offsets em semitons acima da
  referência: `[4]` para a 3ª maior, `[4, 7]` para a tríade maior,
  `[2,4,5,7,9,11,12]` para a escala maior (`degreesFromSteps`). `distanceTo` é a
  soma das diferenças posição a posição, o que **reproduz exatamente**
  `|Δsemitones|` para intervalo (perfil de 1 elemento). Verificado por um teste
  de paridade descartável que rodou o algoritmo da 1.4 lado a lado nas 23
  posições do loop real: mesma ordem de opções, mesmos refs, mesmos textos.
- **A seed foi preservada, não reinventada.** `ExerciseQuestion.optionSeed(index)`
  é `Object.hash(answer.id, variantKey, index)` e `variantKey` é a `direction` —
  a mesma expressão que a 1.4 usava. Sem isso a ordem dos botões mudaria, que é
  visível para a usuária.
- **`errorType` por tipo, com fatias explícitas da taxonomia.**
  `intervalErrorTypes` (13) e `chordErrorTypes` (4) são conjuntos const; a busca
  por `id` acontece **dentro** da fatia do tipo, então a colisão `major`
  escala × acorde é impossível por construção, não por convenção. Escala deriva
  do par pelos graus; `orElse: throw` virou `ErrorType.farMiss` em todos os
  caminhos.
- **Regra 6 é uma varredura de tokens**, não de texto nem de diretivas: casa o
  lexema inteiro, então `IntervalExerciseScreen` não é falso positivo, e menções
  em doc-comment ou string literal também não. Os quatro casos estão em
  `test/module_boundary_test.dart`. Verificado ainda por injeção manual de
  `IntervalSpec?` no arquivo real — saiu 1 nomeando `arquivo:linha`.
- **Como acorde e escala entram no teste sem entrar no produto.**
  `practiceExerciseTypesProvider` devolve `defaultPracticeTypes`
  (`{ExerciseType.interval}`) em produção; o teste de widget o sobrescreve para
  `{chord}` / `{scale}` e o exercício atravessa a árvore real
  (`_ActiveExerciseView`, `ExerciseCard`, `_OptionButton`, `_ResultLine`) sem
  nenhum ramo por tipo. O filtro do loop continua em intervalo.

## Spec Change Log

## Review Triage Log

**Iteração 1 — 2026-09-05.** Três lentes sobre o diff desde `d0ddcd0`. 32 achados brutos,
com convergência das três num só ponto grave. Todos os achados empíricos foram **reproduzidos
por mim** antes de aceitar. Sem `intent_gap` nem `bad_spec` → sem loopback: toda correção
sobrevivente cabe em arquivos de teste, no `tool/`, ou em artefatos de planejamento.

| # | Achado (lente) | Veredito | Evidência da verificação | Rota |
|---|---|---|---|---|
| 1 | A Regra 6 proíbe 2 símbolos de 8: uma árvore duplicada para acorde/escala nomeia `ChordSpec`/`ScaleSpec` e passa (3 lentes) | **high** | Reproduzido por mim: injetei `ChordSpec? _chordProbe; ChordExercise? _chordEx;` em `interval_exercise_screen.dart` e o checker saiu **0**. A lente de verification-gap foi além e injetou um `_ChordBody` + `_ChordOptionButton` completos — checker 0 e 25/25 testes verdes. O gate que a spec chama de "entregável central" protege o único tipo que nunca será duplicado. Causa raiz: o bloco congelado que **eu** escrevi nomeia só os dois símbolos de intervalo. Não exige editá-lo: um superconjunto continua satisfazendo "nenhum arquivo menciona `IntervalSpec` ou `IntervalExercise`". | patch |
| 2 | A taxonomia de escala é verificada contra fixture copiado à mão, não contra o catálogo real (blind, vgap) | **high** | Reproduzido por mim: mutei `mixolydian.steps` de `[2,2,1,2,2,1,2]` para `[2,2,1,2,1,2,2]` no `catalog_v1.json` real; `check_curriculum` saiu 0 e os 60 testes de `exercicios/` passaram. Em produção maior×mixolídia passaria a diferir em 2 graus e viraria `far-miss` silencioso, e a Story 1.6 explicaria o conceito errado. Agrava: o comentário do fixture afirma "the real modes rather than invented ones" — é falso. | patch |
| 3 | `practicePool` dedupe por `id` nu entre tipos: chord `major` e scale `major` colapsam (3 lentes) | **medium** | Confirmado por leitura: `seen` é keyed em `question.answer.id`. Hoje inerte (default é só intervalo), mas a decisão registrada para a 1.5 é loop misto de 39 — e aí `_OptionButton` compara `option.id == state.answer.id` e marcaria a escala maior como certa numa pergunta de acorde. É a mesma colisão que esta story existe para matar, reintroduzida um nível acima. | patch |
| 4 | O guard `requiresVoice` sumiu; `resolution` ganhou prompt e ramo em `questionFor` (blind) | **medium** | Confirmado: o filtro virou `types.contains(exercise.type)`. Inerte hoje, mas dá superfície de múltipla escolha a um exercício que é cantado (Epic 3), com `semitoneProfile` vazio que degenera o ranking. A decisão registrada para a 1.5 é filtrar por `requiresVoice == false`. | patch |
| 5 | A afirmação central da story — "comportamento de intervalo idêntico" — não tem guarda de regressão (blind, edge) | **medium** | Confirmado: o teste de paridade rodou e foi descartado; nada em `test/` congela a sequência de opções. `interval_options_test` só assere determinismo por seed, que qualquer fórmula satisfaz. Uma golden das 23 posições trava o único fato que um PR de refatoração não pode mover. | patch |
| 6 | `degree = index + 2` só vale para escalas de 7 graus; perfis de tamanhos diferentes são preenchidos (blind, edge) | **medium** | Confirmado por leitura. Hoje cai em `far-miss` por acidente, não por desenho. Uma pentatônica na 1.8 arquivaria o erro no grau errado. | patch |
| 7 | `interval_practice_test` trocou igualdade de conjunto por checagem de comprimento (edge, deleção) | **medium** | Confirmado no diff: `expect(loopRefs, allInterval)` virou `expect(loop.length, ...)`. Deriva de conteúdo passa despercebida — o loop pode ter 23 questões construídas dos exercícios errados. | patch |
| 8 | O teste de distratores mais próximos passou a comparar a implementação consigo mesma (edge, deleção) | **low** | Confirmado: a ordenação de referência usa `answer.distanceTo`, a própria função sob teste. Mitigado pelo teste novo que fixa `distanceTo` em `|Δsemitones|` para 3 pares, mas a âncora deveria vir do catálogo. | patch |
| 9 | O ramo de loop vazio é novo e não tem teste (blind) | **low** | Confirmado: `loop.isEmpty ? const [] : ...` não existia antes e agora é alcançável via `practiceExerciseTypesProvider`. Correção direta de 4 linhas. | patch |
| 10 | `epic-1-context.md` foi reescrito fora de escopo e perdeu toda a rastreabilidade (blind) | **medium** | Reproduzido por mim: o arquivo tinha 12 identificadores (`AD-1..AD-5`, `AR-4/6/8/11`, `FR-1/3/15`) e agora tem **zero**. É como uma spec cita arquitetura e UX. Causa: **eu** disparei o recompile por uma diferença de mtime de 1,7 ms — artefato de checkout, não atualização de conteúdo. Reverto e preservo o arquivo commitado. | patch (meu) |
| 11 | O bloco novo do `deferred-work.md` aponta para spec inexistente (blind) | **medium** | Confirmado: aponta para `spec-1-5-exercicios-...md`, que **eu** deletei ao regenerar com escopo estreito. As duas decisões do humano ficam sem casa alcançável quando a 1.5 começar. | patch (meu) |
| 12 | O action item S1 segue `open` embora esta story o tenha quitado (blind) | **low** | Confirmado no `sprint-status.yaml`. O preflight derrubou a premissa dele e a Regra 6 entrega o que ele queria de fato. Itens irmãos usam `status: done` + `resolution`. | patch (meu) |
| 13 | O gate `check_deferred_owners` não enxerga `1.5a`; 7 itens com `owner: dev da 1.5` não disparam (blind) | **low** | Confirmado: são 7 itens, não 5. Mas o gate está **correto** — esses itens pertencem à 1.5 (consumo de acorde/escala), que segue em `backlog`. O efeito real é que os 7 disparam de uma vez quando a 1.5 começar, que é o gate funcionando. Registrado para o planejamento da 1.5. | defer |
| 14 | `ExerciseAttempt.forAnswer` recebe `exerciseType` solto, sem amarrar às opções (blind) | **low** | Real, mas a correção mínima (carregar o tipo em `AnswerOption`) muda superfície pública do modelo recém-criado e é exatamente o que o guard do achado 3 já impede na prática. Redundante com o 3. | rejeitado |
| 15 | Nenhum teste cobre par de escalas divergindo num grau sem `ErrorType` (ex.: 4ª/lídia) (blind) | **low** | Real, mas o fallback já é `far-miss` e está correto; a lídia não existe no catálogo. O achado 6 (guard de comprimento) e o 2 (catálogo real) cobrem a classe. | rejeitado |
| 16 | Regra 6 não pega `switch (s.current.type)` dentro de presentation (edge, vgap) | **low** | Verdadeiro e reconhecido pela própria lente: `ExerciseType` é nomeado legitimamente no arquivo, então não pode entrar na lista de banidos. Vira linha no doc-comment da Regra 6, não código. | patch (junto do 1) |
| 17 | Inversões de acorde com mesmo `id` colapsariam no pool (edge) | **low** | Não ocorre: `chordCatalog` tem `inversion: 0` nas 4 entradas e a 1.4b não produziu inversões. Torna-se real só se a 1.8 as adicionar — e aí o guard do achado 3, keyed em `(tipo, id)`, é o lugar natural. | rejeitado |
| 18 | Metadados de status divergem entre três arquivos (blind) | **false** | É a sequência desenhada do workflow: o step-04 põe a spec em `in-review`, e a tarefa 9 amarra o `sprint-status` a `review` na abertura do PR. Quanto ao `1-4b: done`, ele existe — na PR #25, aberta; esta branch saiu do `master` antes dela. | rejeitado |
| 19 | `distanceTo` preenche perfis desiguais com zero e ranqueia por contagem de notas (edge) | **maybe-false → coberto** | Só se manifesta com pool misto, que o achado 3 passa a impedir. O guard explícito de comprimento do achado 6 fecha o resto. | patch (junto do 3 e 6) |
| 20 | `PhrasePlayer` trunca os 8 refs de escala para 2; nada registra a forma atual (vgap, other) | **low** | Verdadeiro, mas é literalmente o `Never` da spec ("mudar a forma do motif ... é da 1.5"), e a decisão já está registrada no `deferred-work.md`. Corrigir aqui violaria o bloco congelado. | rejeitado |

**Agrupamento e rota:** 12 entradas para `patch` (9 para o subagente da implementação, 3 minhas
em artefatos de planejamento), 1 para `defer`, 6 rejeitadas com refutação. Sem `intent_gap` nem
`bad_spec` → `review_loop_iteration` fica em 0.

**Lição de autoria, registrada sem loopback:** o achado 1 nasceu do bloco congelado que eu
escrevi, que nomeou só `IntervalSpec` e `IntervalExercise`. A implementação seguiu a spec ao pé
da letra e ficou incompleta porque a spec estava incompleta. A correção não exige renegociar o
bloco — um superconjunto continua satisfazendo o texto congelado — mas a próxima spec que
definir um gate deve declarar a **propriedade** ("nenhum símbolo específico de tipo"), não uma
lista de símbolos.


## Design Notes

- **O seam não é o card.** O preflight do ATDD derrubou a premissa do action item S1: `ExerciseCard` já recebe só `child`. O acoplamento vive no state, nos widgets de opção/resultado e na resolução de erro.
- **Por que a regra estática é o entregável central.** A AC3 é estrutural. Um teste de widget que exercita os três tipos passa igualmente bem contra uma árvore genérica e contra três duplicadas — só a regra estática distingue.
- **A colisão `major`.** Argumento concreto contra o lookup global por `id`, que hoje existe e é o que a Story 1.6 vai consumir.
- **Por que o loop não muda aqui.** Ligar acorde e escala é mudança visível de produto; separá-la deixa esta story como refatoração de comportamento idêntico, que é o tipo de PR mais fácil de revisar com confiança.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `flutter test test/module_boundary_test.dart` -- passa, incl. o par novo da Regra 6
- `flutter test` -- todos passam; `interval_practice_test.dart` segue com 23 e 13
- `bash tool/ci.sh` -- exit 0
- `git diff` -- nenhuma mudança em `assets/`, `lib/audio/`, ou no `schemaVersion`
