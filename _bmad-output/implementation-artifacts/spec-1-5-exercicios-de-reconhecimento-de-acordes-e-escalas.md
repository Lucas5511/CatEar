---
title: 'Story 1.5 — Exercícios de reconhecimento de acordes e escalas'
type: 'feature'
created: '2026-09-06'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '94a5e2115382684ce4c43a3db6dd6972dfa83627'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-5a-seam-type-agnostic-do-fluxo-de-pratica.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A Story 1.4b produziu o conteúdo e a 1.5a a maquinaria, mas o usuário continua vendo só intervalos. `defaultPracticeTypes` é `{interval}`, então os 8 acordes e as 8 escalas do catálogo nunca aparecem. Virar esse default sozinho não basta e é ativamente perigoso: `practicePool` passaria a devolver as 21 opções dos três tipos juntas e `answerOptionsFor` sortearia distratores **entre tipos** — uma pergunta de intervalo ofereceria "tríade maior" como alternativa. Além disso `playMotif` toca um contorno fixo de 3 eventos usando só `refs[0]` e `refs[1]`, o que trunca as 8 notas de uma escala para duas e reduz uma tríade ao bloco.

**Approach:** Ligar os dois tipos no loop e dar a cada um a sua forma musical, com as duas coisas decididas em `domain/`: o pool de distratores passa a ser por tipo, e o **contorno do motif vira dado do `ExerciseQuestion`** em vez de lógica dentro do `PhrasePlayer`. A apresentação continua sem saber que tipos existem.

## Boundaries & Constraints

**Always:**

- **Distratores nunca cruzam tipos.** As alternativas de uma pergunta vêm só do catálogo do próprio tipo — 13 intervalos, 4 qualidades de acorde, 4 modos. Hoje `answerOptionsFor` ranqueia o pool inteiro por `distanceTo`, e uma tríade maior (`[4,7]`) fica a distância 3 de uma terça maior (`[4]`), mais perto que a maioria dos intervalos. Sem essa separação o exercício fica sem sentido e o sinal de habilidade do Epic 2 nasce contaminado.
- **O contorno do motif é dado, não código.** `questionFor` decide a sequência de eventos por tipo; `PhrasePlayer` toca a sequência que receber. Isso é o que mantém a AC3 satisfeita com formas diferentes por tipo — a alternativa (um `switch` no player ou na tela) é código específico por tipo no fluxo de apresentação, e a Regra 6 não pega porque `ExerciseType` é nomeado legitimamente ali.
  - **Intervalo:** `r0, r1, r0` — inalterado.
  - **Acorde:** bloco → arpejo → bloco, isto é `refs[0], refs[1], refs[2], refs[3], refs[0]`. A 1.4b guardou `audioSampleRefs` como `[bloco, fundamental, terça, quinta]` exatamente para isso.
  - **Escala:** as 8 notas em sequência, na ordem em que o catálogo as guarda (`direction` já está aplicada nos refs).
- **Ritmo por tipo** (decisão do humano, 2026-09-06): cada tipo tem o seu gap, em vez de um `noteGap` único. A escala anda em ~250–300 ms por nota, ficando em ~2,0–2,4 s; o acorde deixa o bloco soar mais que as notas do arpejo. Uma escala a 450 ms/nota arrasta e não é ouvida como escala. Os números exatos são do implementador, dentro dessas faixas; o intervalo fica em 450/450/900 como está.
- **O texto de fim de loop deixa de falar em intervalos.** Hoje é `'Você percorreu todos os intervalos de hoje.'`, uma string — a Regra 6 varre símbolos e não a enxerga. Com três tipos na sessão ela passa a mentir.
- **Comportamento de intervalo preservado no que é do exercício:** mesmas 4 alternativas, mesmo ranking por `|Δsemitones|`, mesmos textos, mesmo contorno de 3 eventos. **A ordem embaralhada muda**, e isso é esperado: `optionSeed` inclui a posição no loop, e acorde e escala deslocam os índices. O que não pode mudar é o *conjunto* de alternativas e a regra de ranking.
- **Seleção do loop por `requiresVoice == false`**, não por lista de tipos — o filtro já existe desde a 1.5a. Resultado: 39 exercícios, com os 2 de `resolution` fora por serem cantados (Epic 3).
- **Triagem dos 7 itens com `owner: dev da 1.5`** (decisão do humano, 2026-09-06), exigida pelo gate `check_deferred_owners`:
  - **Entram nesta story (3):** o contrato posicional dos refs de acorde em `curriculum.dart`; o comentário defasado "the 14 v1 samples" no `phrase_player.dart`; e o **seam de injeção** dos tempos do `PhrasePlayer` e do `_advanceTimer` — este deixa de ser opcional, porque a story cria durações por tipo e os widget tests hoje hard-codam `pump(1800ms)`.
  - **Re-triados para uma story de UI (1):** o `ThemeExtension` de `CatColors`, hoje resolvido à mão com `brightness == dark ? xDark : x`. É refatoração de tema, não de exercício.
  - **Re-triados para uma story de robustez de áudio (2):** a tradução determinística de `PlayerException`/`PlatformException` em `SamplePlaybackFailed`, e o `ArgumentError` cru de `audioAssetKeyFor`. São do módulo `audio`, que esta story não toca.

**Never:**

- Ramificar por `ExerciseType` dentro de `lib/exercicios/presentation/`. A Regra 6 não pega isso — é a residência declarada dela — então é responsabilidade da revisão e do desenho.
- Amostras de áudio novas, mudança em `assets/`, ou no `schemaVersion` do catálogo.
- Síntese em runtime ou multi-voz no `AudioService`.
- Mudar o ranking de distratores de intervalo, os textos do exercício de intervalo, ou o contorno de 3 eventos dele.
- Estrutura de sessão, corte por tempo ou ordenação adaptativa — é a Story 1.7, e a 1.5 entrega o loop inteiro de 39.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Loop completo | catálogo v1 | 39 exercícios: 23 intervalos + 8 acordes + 8 escalas | — |
| Resolução fora | 2 exercícios `resolution` | continuam fora, por `requiresVoice` | — |
| Distrator de acorde | pergunta `chord` | as 4 alternativas são qualidades de acorde | teste falha se aparecer id de outro tipo |
| Distrator de escala | pergunta `scale` | as 4 alternativas são modos | idem |
| Distrator de intervalo | pergunta `interval` | as 4 alternativas são intervalos, mesmo ranking de antes | idem |
| Motif de acorde | `[bloco, f, t, q]` | 5 eventos: bloco, f, t, q, bloco | `SamplePlaybackFailed` habilita opções com banner |
| Motif de escala | 8 refs | 8 eventos, na ordem dos refs | idem |
| Motif de intervalo | 2 refs | 3 eventos `r0, r1, r0` — inalterado | idem |
| Refs insuficientes | `chord` com menos de 4 refs | degrada sem lançar, tocando o que há | nunca `RangeError` no meio da sessão |
| Fim de loop | as 39 respondidas | texto não menciona um tipo específico | — |
| Erro de escala | era maior, escolheu mixolídia | `errorType == setimaAlterada` | já coberto desde a 1.5a |
| Sem código por tipo | `exercicios/presentation/` | `check_module_boundaries` exit 0 | build reprova |

</frozen-after-approval>


## Code Map

**A mudar:**

- `lib/exercicios/domain/interval_practice.dart:19` -- `defaultPracticeTypes` é `{ExerciseType.interval}`; vira os três tipos tapáveis. O filtro `requiresVoice` e o dedupe por `(type, id)` já estão prontos desde a 1.5a
- `lib/exercicios/domain/interval_options.dart` -- `answerOptionsFor(answer, pool, seed:)` ranqueia o pool inteiro. Precisa receber só o pool do tipo da pergunta; o pool passa a ser por tipo (a forma fica a critério da implementação — `Map<ExerciseType, List<AnswerOption>>` no state é o caminho óbvio)
- `lib/exercicios/domain/exercise_question.dart:107` -- `ExerciseQuestion` ganha o contorno do motif; `questionFor` (o único `switch` sobre a sealed class) o preenche por tipo
- `lib/exercicios/presentation/phrase_player.dart:85` -- `playMotif` tem o contorno de 3 eventos hard-coded, usando `refs.first` e `refs[1]`. Vira executor de uma sequência qualquer, preservando o `_generation`, o `_wait` cancelável, o `stop()` final e a propagação de `failure` — essa mecânica é delicada e não é o alvo da mudança
- `lib/exercicios/presentation/interval_exercise_screen.dart:551` -- texto de fim de loop; `:54` lê `practiceExerciseTypesProvider`; `:235` chama `playMotif`
- `test/exercicios/interval_practice_test.dart:21` -- `loop.length == 23` vira 39; o pool de intervalo continua 13. A golden das posições precisa ser regerada — os índices mudam
- `test/exercicios/interval_exercise_screen_test.dart:76` -- `_motifDuration = 1800ms` é global; passa a depender do tipo
- `_bmad-output/implementation-artifacts/deferred-work.md` -- resolver ou re-triar os 7 itens da Open Question 2
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story

**Verificado, nada a mudar:**

- `lib/exercicios/domain/exercise_attempt.dart` -- `errorTypeFor` já resolve por `ExerciseType`, com escala derivada dos `steps` e `far-miss` como fallback
- `tool/check_module_boundaries.dart` -- a Regra 6 já bane os 8 símbolos de tipo; **não** pega `switch (ExerciseType)`, e essa residência está documentada no doc-comment
- `lib/exercicios/presentation/exercise_card.dart` -- type-agnostic desde sempre
- `assets/curriculum/catalog_v1.json` -- os 8 acordes e as 8 escalas já estão lá desde a 1.4b, com os refs na ordem que o motif de acorde espera

## Tasks & Acceptance

**Execution:**

- [x] 1. `lib/exercicios/domain/exercise_question.dart` -- contorno do motif por tipo, preenchido em `questionFor`
- [x] 2. `lib/exercicios/presentation/phrase_player.dart` -- tocar a sequência recebida, preservando geração/cancelamento/erro; tempos conforme a Open Question 1
- [x] 3. `lib/exercicios/domain/interval_options.dart` + o pool -- distratores só do tipo da pergunta
- [x] 4. `lib/exercicios/domain/interval_practice.dart:19` -- virar `defaultPracticeTypes`
- [x] 5. `lib/exercicios/presentation/interval_exercise_screen.dart` -- texto de fim de loop type-agnostic
- [x] 6. `test/exercicios/**` -- 39 no loop, distratores por tipo, os três contornos de motif, e a golden regerada
- [x] 7. `deferred-work.md` -- resolver os 3 puxados e re-triar os 4 restantes com a justificativa acima
- [~] 8. `sprint-status.yaml` -- `in-progress` ao começar, `review` ao abrir o PR

**Acceptance Criteria:**

- Given o catálogo v1, when o loop é montado, then tem 39 exercícios e nenhum `requiresVoice`.
- Given uma pergunta de qualquer tipo, when as alternativas são montadas, then todas pertencem ao catálogo daquele tipo — nunca uma mistura.
- Given um exercício de acorde, when o motif toca, then são 5 eventos começando e terminando no bloco.
- Given um exercício de escala, when o motif toca, then são 8 eventos na ordem dos refs.
- Given um exercício de intervalo, when comparado ao anterior a esta story, then as 4 alternativas e o ranking são os mesmos e o motif tem 3 eventos.
- Given os comandos de §Verification, then todos saem com exit 0.

**Verificação humana (não bloqueia o agente):**

- Ouvir um acorde e uma escala em aparelho físico: o acorde soa como bloco, o arpejo é reconhecível, a escala tem andamento de escala e não de sequência arrastada. É a escuta que a 1.4b deixou pendente, agora com o material que a justifica.

## Implementation Notes

**Verificação — o que rodou e o que não rodou (2026-09-06).** `bash tool/ci.sh` saiu 0 com os
11 gates e 282 testes, rodado pelo orquestrador depois dos patches do review, não só pelo
implementador. Três correções foram validadas por **mutação**: pool misto reprova 3 testes,
acorde sem bloco final reprova 4, e remover de novo o `variantKey` do ramo de escala reprova o
teste do loop. A degradação do motif de acorde foi medida em 0/1/2/3/4 refs (0→0, 1→1, 2→3,
3→4, 4→5 eventos), sem `RangeError`.

**`flutter test integration_test -d <emulador>` NÃO foi executado** — não havia device nesta
sessão. As duas jornadas novas (um card de acorde e um de escala pelo `AudioService` real)
estão escritas e registradas, sem `skip:`, mas a primeira execução delas será no
`e2e-android`, que é required check da PR. Enquanto esse job não passar, os contornos de 5 e 8
eventos permanecem provados só contra o `FakeAudioService`.

- **O contorno mora em `lib/exercicios/domain/motif.dart` (novo).** `MotifEvent
  {ref, hold}` é a unidade: cada evento carrega o seu próprio gap, então o ritmo
  por tipo é dado e não configuração do player. Os construtores são
  `intervalMotif` / `chordMotif` / `scaleMotif` / `sequenceMotif`, chamados uma
  vez em cada ramo de `questionFor`; `ExerciseQuestion.motif` os guarda e
  `motifTotal` soma os holds (é o que os widget tests usam para avançar o
  relógio, no lugar do `_motifDuration = 1800 ms` global).
- **Números escolhidos, dentro das faixas do bloco congelado:** intervalo
  450/450/900 = 1800 ms (inalterado); acorde 700 no bloco, 260 em cada nota do
  arpejo, 900 no bloco final = 2380 ms; escala 270 ms por nota com 450 ms na
  última = 2340 ms (dentro de 2,0–2,4 s, com 250–300 ms/nota). A 450 ms/nota as
  mesmas 8 notas dariam 4050 ms — há um teste que fixa essa comparação.
- **`PhrasePlayer` virou executor.** `playMotif(List<MotifEvent>)` é um laço
  sobre a sequência; `_generation`, o `_wait` cancelável, o `stop()` final e o
  `Future.delayed(Duration.zero)` antes da última checagem de `failure` estão
  preservados byte a byte. A checagem de `failure` continua **fora** do último
  evento (só entre eventos), que é o que faz o teste "rejects mid-note" ainda
  silenciar o player antes de propagar. `noteGap`/`returnHold` deixaram de ser
  campos; `flourishGap` ficou.
- **Pool por tipo:** `practicePool` devolve `Map<ExerciseType,
  List<AnswerOption>>`, e `PracticeState.pool` acompanha (congelado em
  profundidade: o `Map.unmodifiable` guarda listas também `unmodifiable`).
  O caminho fácil passou a ser o certo: `answerOptionsForQuestion(question,
  poolsByType, seed:)` lê o tipo da própria pergunta, então passar o pool errado
  não é algo que um chamador consiga fazer por descuido. `answerOptionsFor`
  continua existindo, sem mudança de ranking.
- **Regressão de intervalo travada por golden de *conjunto*, não de ordem.** A
  ordem embaralhada mudou (era esperado: `optionSeed` inclui o índice e os
  índices deslocaram). O que não podia mudar — as 4 alternativas por id de
  intervalo — foi extraído da golden anterior à story e congelado em
  `GOLDEN: the interval option SET is the one Story 1.4 shipped`. A golden de
  ordenação foi regerada para as 39 posições.
- **`resolution` não ganhou contorno.** O motif fica `const []`: a cadência é
  cantada, `requiresVoice` a mantém fora do loop, e escolher o andamento de dois
  acordes é decisão musical da Story 3.5. Um motif vazio força essa decisão em
  vez de herdar em silêncio o gap de nota do intervalo.
- **Seam de tempos:** `PracticeTimings {flourishGap, advanceDelay}` +
  `practiceTimingsProvider` na tela, lido uma vez no `initState` (documentado
  como não-reativo). O `_advanceTimer` deixou de ser
  `const Duration(milliseconds: 700)` inline. O `flourishGap` tem **uma** fonte,
  `defaultFlourishGap` em `phrase_player.dart`: o default do player e o de
  `PracticeTimings` apontam para ela, e a âncora de onset do
  `audio_assets_bundle_test.dart` também — não há mais como baixar o gap real e
  deixar a guarda medindo 170 ms.
- **Fim de loop:** `'Você percorreu todos os exercícios de hoje.'`, com teste
  que também assere que a palavra "intervalos" não aparece mais.
- **`sprint-status.yaml` está em `in-progress`.** A metade `review` da tarefa 8
  pertence à abertura do PR, que não foi feita nesta passada.
- **`test/audio_assets_bundle_test.dart` foi puxado junto** (não estava no Code
  Map): ele ancorava o onset das amostras em `PhrasePlayer.noteGap`, campo que
  deixou de existir. Agora ancora no menor gap da app inteira — os 8 valores de
  `motif.dart` mais o `flourishGap`. O menor continua sendo 170 ms
  (`flourishGap`), então o limite numérico não mudou; o acoplamento é que ficou
  correto, já que os gaps novos (260/270 ms) são menores que os antigos.


**Verificação humana concluída — 2026-09-07.** O humano instalou o release da 1.5 no emulador
e percorreu o loop: acorde e escala aparecem, os contornos soam como pretendido e o
comportamento foi aprovado ("está funcionando bem"). É a escuta que estava pendente desde a
1.4b, agora feita sobre o material que a justifica — os três contornos tocando de verdade.
Ressalva registrada: o emulador distorce timbre e ruído (falso positivo do charter C1), então
esta verificação cobre **ritmo e forma**, não qualidade de amostra.

## Spec Change Log

## Review Triage Log

**Iteração 1 — 2026-09-06.** Três lentes sobre o diff desde `94a5e21`. As três convergiram
num achado alto que o CI verde não pegava. Todos os achados empíricos foram reproduzidos por
mim. Sem `intent_gap` nem `bad_spec` → sem loopback.

| # | Achado (lente) | Veredito | Evidência da verificação | Rota |
|---|---|---|---|---|
| 1 | `variantKey: exercise.direction` sumiu do ramo `ScaleExercise` de `questionFor` (3 lentes) | **high** | Reproduzido: `git show 94a5e21` mostra a linha no baseline; hoje ela foi **substituída** por `motif:`, não acrescentada ao lado. O catálogo tem 8 escalas = 4 modos × asc/desc, então maior-asc e maior-desc passam a ter `variantKey: null`, mesmo `optionSeed` e `==`/`hashCode` que não os distingue. É exatamente a colisão que o doc do próprio campo diz existir para evitar. Nenhum teste lê `variantKey` de escala — as duas assertivas existentes são em `loop.first`/`loop.last`, ambos intervalos. | patch |
| 2 | `flourishGap` passou a existir em dois lugares, e a guarda de onset ancora no que o app não usa (blind, vgap) | **medium** | Confirmado: `phrase_player.dart:31` e `interval_exercise_screen.dart:58` declaram 170 ms cada; o app injeta o do `PracticeTimings` na `:239`, e `audio_assets_bundle_test.dart:325` lê `player.flourishGap`. Baixar o `PracticeTimings.flourishGap` mudaria a reprodução real com a guarda A-2 verde. A metade `flourishGap` do seam novo também não tem teste — só `advanceDelay` tem. | patch |
| 3 | O doc novo de `Exercise.audioSampleRefs` afirma duas coisas falsas (edge) | **medium** | Reproduzido contra o catálogo: diz `[lower, upper]` "já reordenado por `direction`" — as duas metades se contradizem, e M3 desc é `[sax_e4, sax_c4]`, isto é upper-lower. E diz que `ResolutionExercise` guarda "os acordes da cadência", mas o catálogo guarda 6 refs de **notas** (`sax_g4, sax_b4, sax_d5, sax_c4, sax_e4, sax_g4`). Agrava: este é o item que a story marcou ✅ RESOLVIDO. | patch |
| 4 | Acorde e escala nunca passam pelo `AudioService` real (blind) | **medium** | Confirmado: `integration_test/catear_e2e_test.dart` só percorre o primeiro exercício, que é P1 (intervalo), e o comentário ainda descreve 450+450+900. Os contornos novos — 5 disparos de acorde com 3 a 260 ms, 8 de escala a 270 ms — são a carga nova sobre o player de plataforma e só existem atrás do `FakeAudioService`. O repo já registrou duas vezes em retro que E2E entra no DoD da story. | patch |
| 5 | `PracticeState.pool` deixou de ser profundamente imutável (edge, deleção) | **low** | Confirmado: era `List.unmodifiable`; virou `Map` sem congelar as listas internas, então `poolFor(type)` devolve lista mutável. | patch |
| 6 | `answerOptionsForQuestion` degrada em silêncio para um card de uma opção só (blind) | **low** | Real: `poolsByType[type] ?? const []` alimenta `answerOptionsFor`, que devolve `[answer]`. Hoje inalcançável (mapa e loop saem da mesma fonte), mas é estado alcançável se as duas divergirem, e a matriz não o cobre. Correção direta: falhar alto. | patch |
| 7 | `PracticeState.poolFor` é código morto em `lib/` (blind) | **low** | Confirmado: único chamador é um teste. O caminho de produção usa `answerOptionsForQuestion`, que faz o próprio lookup — e duplica o fallback nulo. | patch |
| 8 | `practiceTimingsProvider` é lido uma vez no `initState` e nunca observado (blind) | **low** | Confirmado. É escolha defensável, mas nada documenta que a configuração não é reativa, e o nome sugere o contrário. | patch |
| 9 | Doc-comments defasados pela generalização (blind, edge) | **low** | Confirmado: `phrase_player.dart:26` ainda diz "Plays the interval motif"; `audio_assets_bundle_test.dart:9` ainda justifica o import por `noteGap`, campo que este diff deletou; `home_screen.dart:4` ainda descreve a CTA como levando ao exercício de intervalo. | patch |
| 10 | O ramo de motif de `resolution` é inalcançável, sem teste, e assume um andamento sem registro (blind) | **low** | Confirmado. Uma cadência é sequência de acordes e recebeu o gap de nota de intervalo; é premissa musical que o Epic 3 herda sem justificativa escrita. | patch |
| 11 | Os 3 itens re-triados ficaram sem owner legível por máquina (blind) | **medium** | Confirmado: o gate casa `dev da <N.N>`; `dev da story de UI (sem número; a criar)` não casa. A intenção era boa — impedir que o gate fosse satisfeito por outra story cuja intenção também os exclui — mas o efeito é que ficaram menos enforçáveis do que antes. O repo já tem o mecanismo certo para isso: `action_items` no `sprint-status.yaml`. | patch (meu) |
| 12 | A dívida de nomes não está registrada em lugar nenhum (blind) | **low** | Confirmado: `interval_practice.dart`, `interval_options.dart`, `interval_exercise_screen.dart`, `IntervalPractice`, `IntervalExerciseScreen` e dois testes guardam código type-agnostic desde a 1.5a. O diff reescreve a prosa deles e mantém todos os identificadores. Não é decisão, é omissão. | patch (meu) |
| 13 | Bookkeeping da spec inconsistente (blind) | **medium** | Parcialmente real. A tarefa 8 marcada `[x]` com metade feita é imprecisa, e as Implementation Notes precisam dizer que `integration_test` **não** rodou. O resto — spec `in-review` com sprint `in-progress`, logs vazios — é a sequência desenhada do workflow no instante em que a lente leu. | patch (meu) |
| 14 | A tabela de triagem diz 4 resolvidos / 3 re-triados, contra 3 puxados / 4 re-triados da spec (edge) | **false** | A implementação está certa e a **minha spec errou a conta**: o item "ligar acorde e escala" é um dos 7 e é resolvido pela própria story, então são 4 resolvidos + 3 re-triados. O bloco congelado listou 3 "entram" porque não contou a própria story. | rejeitado |
| 15 | O erro do último evento do motif não silencia o player antes de subir (edge) | **false** | É o comportamento do baseline, preservado de propósito: o `stop()` vem antes do `Future.delayed(Duration.zero)` que deixa o `onError` rodar, então o player **já** está silenciado quando o erro sobe. A guarda `i < motif.length - 1` existe exatamente para isso. | rejeitado |
| 16 | A lista de âncora do teste de asset enumera as constantes de `motif.dart` à mão (edge, vgap) | **low** | Real, mas a correção (derivar por reflexão ou expor uma lista pública) acrescenta superfície para um risco que o achado 2 já reduz ao trocar a fonte do `flourishGap`. Uma constante nova de ritmo é adição deliberada, que passa por review. | rejeitado |

**Agrupamento e rota:** 13 entradas para `patch` (10 para o subagente, 3 minhas em artefatos de
planejamento), 3 rejeitadas com refutação. Sem `intent_gap` nem `bad_spec`.

**Nota de autoria:** o achado 14 é erro meu de aritmética no bloco congelado, não da
implementação. Registrado aqui em vez de corrigido, porque o bloco é congelado e a contagem
não muda o que foi feito.


## Design Notes

- **Por que o contorno vira dado.** É a mesma jogada da 1.5a: tudo que difere por tipo desce para `questionFor`, o único lugar que abre a sealed class. Um `switch` no `PhrasePlayer` seria código por tipo no fluxo de apresentação — e a Regra 6 não o pegaria.
- **Por que o pool por tipo é obrigatório e não uma melhoria.** `distanceTo` compara perfis de semitons sem noção de tipo: uma tríade maior fica mais perto de uma terça maior do que a maioria dos intervalos. A revisão da 1.5a registrou isso como armadilha para esta story.
- **A ordem das alternativas de intervalo vai mudar** e não é regressão: `optionSeed` inclui o índice no loop. E, desde a 1.5a, sabe-se que essa ordem já não é estável entre execuções (o `hashCode` do enum `Direction` é de identidade) — item registrado no `deferred-work.md` para a Story 1.8.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `dart run tool/check_deferred_owners.dart` -- exit 0 (os 7 itens resolvidos ou re-triados)
- `flutter test` -- todos passam
- `flutter test integration_test -d <emulador>` -- passa
- `bash tool/ci.sh` -- exit 0
