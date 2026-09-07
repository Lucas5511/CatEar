---
title: 'Story 1.6 — Feedback explicativo em erro'
type: 'feature'
created: '2026-09-07'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '1f086cd93ecd615ed6a786f2f613f2cd0769d806'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Ao errar, o app diz `'Não foi dessa vez. Era 3ª maior.'` — nomeia o que era certo, nunca o que foi confundido. Desde a 1.5a cada tentativa já grava um `errorType` da taxonomia canônica, resolvido por `ExerciseType` e, no caso de escala, derivado do par de graus que separa os dois modos. Nada da apresentação lê esse dado. O erro pune sem ensinar, que é o oposto do FR-4.

**Approach:** Um balão de fala do mascote, inline e elevado, que nomeia o conceito confundido. O texto é montado em `domain/` a partir de `(answer, picked, errorType)`, em duas camadas: um template genérico que cobre todos os casos, e frases próprias onde o `errorType` diz algo que os nomes das opções não dizem — o grau alterado numa escala, o erro de oitava, o far-miss.

## Boundaries & Constraints

**Always:**

- **A explicação é construída em `domain/`, não no widget.** Mesma razão da Regra 6: a apresentação não ramifica por tipo de exercício. O widget recebe uma string pronta e a desenha.
- **Duas camadas de texto** (decisão do humano, 2026-09-07):
  - **Base:** nomeia o par, com os `nameUi` que a tela já tem — "Quase lá — você confundiu {answer} com {picked}."
  - **Específica, onde a taxonomia acrescenta:** escala resolve pelo grau (`terca-alterada` / `sexta-alterada` / `setima-alterada` → "a 3ª/6ª/7ª ficou diferente"), mais `octave-error` e `far-miss`. É para isso que a 1.4b escolheu nomear pelo grau em vez de pelo modo.
- **`far-miss` é um caso de primeira classe, não um fallback envergonhado.** Desde a 1.5a `errorType` **nunca é `null`** numa resposta errada — tudo sem mapeamento resolve para `far-miss`, de propósito, porque `null` ou exceção no meio da sessão derrubava a tela. A frase de far-miss ainda nomeia o certo e convida a ouvir de novo; nunca é só "errado".
- **Atualizar `epics.md` no mesmo PR.** A AC da 1.6 lá ainda descreve o caso sem correspondência como `errorType == null`, estado que o código tornou inalcançável na 1.5a. É o item #4 da retro do Epic 1: quando o congelado diverge de um artefato de planejamento, o artefato sobe junto.
- **Balão inline elevado, nunca rota nova.** `EXPERIENCE.md` diz "num bubble curto, **sem tela cheia de bloqueio**"; `DESIGN.md` diz que ele "flutua visualmente acima do conteúdo com leve sombra". A AC do `epics.md` fala em "o modal empilha só um nível" — é a restrição de navegação herdada da 1.1, e um balão que não empilha nada a satisfaz trivialmente.
- **O mascote não aparece no acerto.** `EXPERIENCE.md` é explícito: no acerto o feedback é visual e sonoro, "mascote não aparece (fluxo não interrompe o ritmo da sessão)". E nunca durante o áudio do exercício.
- **Fredoka só através de `CatText.display`.** É a única fala do mascote no app; corpo e números nunca a usam. O estilo já existe e tem fallback para `sans-serif`.
- **Fundo `accent-soft` (`accentSoftDark` no escuro), `rounded/lg` (28 px), sombra quente acima do conteúdo** — os tokens já existem em `CatColors`.
- **Contraste entra no gate.** `test/contrast_test.dart` hoje itera só `surface-base` e `surface-base-dark`. Texto sobre `accent-soft` é um par novo e precisa entrar, nos dois temas — é exatamente o buraco que a retro do Epic 1 registrou como item P1 (R7).
- **A mensagem é anunciada por leitor de tela.** O `_ResultLine` já usa `Semantics(liveRegion: true)`; o balão não pode perder isso.

**Never:**

- Vermelho saturado (UX-DR14). A paleta não tem nenhum vermelho hoje — não introduzir um.
- Rota, `showDialog` ou qualquer coisa que empilhe navegação.
- Mudar `ErrorType`, a taxonomia, ou como `ExerciseAttempt.errorTypeFor` resolve. Esta story **lê**; a 1.5a produziu.
- Mostrar o balão no acerto, ou enquanto o motif toca.
- Usar Fredoka fora de `CatText.display`.
- Ramificar por `ExerciseType` dentro de `lib/exercicios/presentation/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Intervalo confundido | era M3, escolheu m3 | balão nomeia os dois pelo `nameUi` | — |
| Acorde confundido | era maior, escolheu diminuto | idem | — |
| Escala, um grau | era maior, escolheu mixolídia (`setimaAlterada`) | a frase nomeia **a 7ª**, não os modos | — |
| Escala, vários graus | era maior, escolheu menor natural (`farMiss`) | frase de far-miss, nomeando o certo | — |
| Erro de oitava | `octaveError` | frase própria de oitava | — |
| Resposta certa | qualquer tipo | **nenhum balão**; a linha de acerto atual permanece | — |
| Durante o áudio | motif tocando | nenhum balão | — |
| Sem `picked` | estado inicial / `answering` | nenhum balão, nenhuma exceção | nunca lança no meio da sessão |
| Contraste claro | texto do balão sobre `accent-soft` | ≥ 4.5:1 | `contrast_test` reprova |
| Contraste escuro | sobre `accent-soft-dark` | ≥ 4.5:1 | idem |
| Leitor de tela | balão aparece | anunciado como `liveRegion` | — |
| Sem código por tipo | `exercicios/presentation/` | `check_module_boundaries` exit 0 | build reprova |

</frozen-after-approval>

## Code Map

**A mudar:**

- `lib/exercicios/presentation/interval_exercise_screen.dart` -- `_ResultLine` monta o texto hoje (`'Isso! …'` / `'Não foi dessa vez. Era …'`) e já é `Semantics(liveRegion: true)`. Ganha o balão no ramo de erro; o ramo de acerto não muda. `state.picked` e `state.answer` são ambos `AnswerOption` com `nameUi`, e `state.attempts.last.errorType` traz a taxonomia
- `lib/exercicios/domain/` -- arquivo novo com a função que recebe `(answer, picked, errorType)` e devolve a explicação. É o único lugar que conhece as duas camadas de texto
- `lib/core/theme/tokens.dart:27,41` -- `accentSoft` / `accentSoftDark` já existem, nada a criar
- `lib/core/theme/typography.dart:30-38` -- `CatText.display` é o único estilo Fredoka, com fallback `sans-serif`. Usar como está
- `test/contrast_test.dart:13,48` -- os mapas `backgrounds` iteram só `surface-base` e `surface-base-dark`; somar `accent-soft` e `accent-soft-dark`
- `test/exercicios/interval_exercise_screen_test.dart` -- cobertura do balão: presente no erro, ausente no acerto, texto por família de `errorType`
- `_bmad-output/planning-artifacts/epics.md` -- corrigir a AC que fala em `errorType == null`
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story

**Verificado, nada a mudar:**

- `lib/exercicios/domain/exercise_attempt.dart` -- `errorTypeFor` já resolve por `ExerciseType`, com escala pelo par de graus e `far-miss` como fallback. Os 22 valores de `ErrorType` cobrem o que a story precisa
- `lib/core/theme/` -- a paleta não tem nenhum token vermelho, então UX-DR14 já está satisfeita por construção
- `lib/exercicios/presentation/exercise_card.dart` -- type-agnostic; o balão vive dentro do card, não o substitui

## Tasks & Acceptance

**Execution:**

- [x] 1. `lib/exercicios/domain/` -- a função de explicação, com as duas camadas e o far-miss como caso de primeira classe
- [x] 2. `lib/exercicios/presentation/interval_exercise_screen.dart` -- o balão do mascote no ramo de erro, com `accent-soft`, `rounded/lg`, sombra quente e `CatText.display`
- [x] 3. `test/contrast_test.dart` -- `accent-soft` e `accent-soft-dark` nos mapas de fundo
- [x] 4. `test/exercicios/**` -- balão no erro e ausente no acerto; uma asserção por família de `errorType`
- [x] 5. `_bmad-output/planning-artifacts/epics.md` -- corrigir a AC do `errorType == null` para o comportamento real (`far-miss`)
- [~] 6. `sprint-status.yaml` -- `in-progress` ao começar, `review` ao abrir o PR

**Acceptance Criteria:**

- Given uma resposta errada de qualquer tipo, when o resultado aparece, then há um balão que nomeia o conceito confundido — nunca só "errado".
- Given um erro de escala que difere em exatamente um grau, when o balão aparece, then a frase nomeia **o grau**, não os dois modos.
- Given uma resposta certa, when o resultado aparece, then não há balão.
- Given o balão nos dois temas, when `contrast_test` roda, then o texto sobre `accent-soft` passa de 4.5:1.
- Given `lib/exercicios/presentation/`, when `check_module_boundaries` roda, then exit 0.
- Given os comandos de §Verification, then todos saem com exit 0.

**Verificação humana (não bloqueia o agente):**

- Errar de propósito um intervalo, um acorde e uma escala no emulador e ler as três frases. O tom é de professor gentil, não de correção — e o texto de escala deve soar mais útil que o de intervalo, porque nomeia o grau.

## Implementation Notes

**A explicação (`lib/exercicios/domain/error_explanation.dart`).** Uma função,
`errorExplanation({answer, picked, errorType})`, total por construção: chamada
de dentro de um `build` no meio da sessão, nunca lança e nunca devolve vazio.
`picked`/`errorType` são anuláveis só para absorver um estado que não deveria
chegar ali (resultado desenhado sem tentativa) — esse caminho ainda nomeia o
certo, então o widget não monta texto nenhum. A camada específica é
`alteredDegreeNames` (o inverso exato de `scaleErrorTypeByDegree`, com o teste
afirmando a igualdade dos conjuntos de chave) mais o ramo de `far-miss`; todo o
resto cai no template base.

**Correção da matriz de I/O — `octave-error` não existe no runtime.** A linha
"Erro de oitava | `octaveError` | frase própria de oitava" descreve um caminho
que o app não tem: `errorTypeFor` resolve um pick de intervalo por id, e o id de
oitava é `P8` (`ErrorType.p8`, o intervalo). Nenhum id de catálogo é
`octave-error`, e acorde/escala/resolução também não o alcançam. Detecção real
de salto de oitava exige mexer em `errorTypeFor`, que o Never desta story
proíbe, então o ramo morto foi removido e o item registrado em
`deferred-work.md` para a story que mexer nisso.

**O balão (`_MascotBubble`).** Inline dentro do `ExerciseCard`, no ramo de erro
do `_ResultLine`. O ramo de acerto ficou byte-idêntico. O guard do `_ResultLine`
é `== AnswerPhase.correct` (falha fechado: uma fase inesperada cai na
explicação, nunca em parabéns), e a tentativa lida de `attempts.last` é
descartada se for `wasCorrect` — o balão não pode explicar o erro de outro
exercício. `accent-soft`
(`accentSoftDark` no escuro), `rounded/lg`, sombra quente com `ink-primary` a
16% (claro) / `surface-base-dark` a 55% (escuro), `Semantics(liveRegion: true)`
preservado. A linha antiga `'Não foi dessa vez. Era …'` **saiu**: o balão já
nomeia o certo, e mantê-la deixaria dois `liveRegion` anunciando a mesma coisa
com tons diferentes.

**Desvio registrado — `CatText.display` com `fontSize: 20`.** O token é 28 px,
tamanho de manchete; a frase do balão tem duas orações dentro de um card. Só a
escala foi reduzida por `copyWith` — família e peso (a voz do mascote) vêm do
token intacto, e ele continua sendo o único `TextStyle` Fredoka do app.

**Desvio registrado — `contrast_test.dart`.** A spec pedia `accent-soft` /
`accent-soft-dark` nos mapas `backgrounds`. Feito como dois testes próprios em
vez disso: os mapas cruzam todo fundo com **todos** os inks, e `ink-secondary`
sobre `accent-soft` dá 3,62:1 (4,37:1 no escuro). Reprovar aí exigiria escurecer
`ink-secondary` — mudança de token fora do escopo desta story — por um par que o
app nunca desenha: no balão só existe `ink-primary` (9,86:1 claro, 7,55:1
escuro). `tool/gen_contrast_audit.dart` ganhou as mesmas duas linhas para o doc
não divergir do teste.

**"Continuar" fora da dobra — corrigido no app, não no teste.** O balão é a
coisa mais alta do card e empurrava o botão de avanço ~148 px abaixo da dobra
num 360x640. A tela agora chama `Scrollable.ensureVisible` no `SizedBox` do
"Continuar" num post-frame callback, uma vez por exercício, só no ramo de erro
(o acerto avança sozinho). Um teste de regressão num viewport de 360x640 afirma
que o botão fica dentro da viewport e que o tap realmente avança — o guard
implícito que um `ensureVisible` no teste teria apagado para sempre. Efeito
colateral aceito: em tela pequena o "Ouvir de novo" sai por cima depois do
erro; o card rola e o teste de replay sobe até ele como a usuária faria.

**Fora do Code Map, necessário.** `integration_test/catear_e2e_test.dart`
afirmava `find.textContaining('Não foi dessa vez')` em duas jornadas; virou
`expectExplainedResult(tester)`, que lê o rótulo da opção destacada como
resposta certa e exige que a frase do balão **contenha** esse rótulo — FR-4
verificado de ponta a ponta, e não só "existe um texto em Fredoka".

**O gate de `TextScaler.linear(2.2)`.** O teste existente respondia **certo**,
então o balão — a maior superfície de texto da tela — nunca era medido sob
escala. Ganhou um irmão que responde errado. Dois testes em vez de dois
`pumpWidget` no mesmo: desmontar um `ProviderScope` deixa um timer de
auto-dispose sem flush (é o que o comentário do `_app` já registrava).

**`epics.md` (três correções).** A AC do `errorType == null` foi reescrita para
o comportamento real desde a 1.5a (`far-miss`, `null` inalcançável). A AC do
"modal de explicação empilha só um nível" virou "balão inline, nada empilhado" —
esta story deliberadamente não construiu um modal. E o exemplo da primeira AC
dizia "3ª maior"/"3ª menor", que não são os `nameUi` que o app mostra; agora diz
"terça maior"/"terça menor". Item #4 da retro do Epic 1.

**`DESIGN.md` se contradizia sobre este componente.** A linha 53 do frontmatter
pedia "sempre em `surface-raised` com **borda** `accent-soft`", enquanto
§Components e §Shapes pedem `accent-soft` como **fundo**. Implementei a leitura
de preenchimento (a que as duas seções em prosa e o `epic-1-context.md` repetem)
e a linha 53 foi reconciliada com ela, com a divergência anotada no próprio
campo para a próxima story não reabrir a dúvida.

**`tokens.dart`.** `accentSoft` / `accentSoftDark` ganharam a restrição por
escrito: só `ink-primary` passa AA sobre eles (9,86:1 / 7,55:1); `ink-secondary`
dá 3,62:1 (4,37:1 no escuro). Sem isso, uma story futura poria tinta secundária
no balão com o gate verde.

**Não feito de propósito.** `sprint-status.yaml` ficou em `in-progress` — a
transição para `review` é do momento de abrir o PR, que não aconteceu nesta
sessão.


**Verificação — o que rodou (2026-09-07).** `bash tool/ci.sh` exit 0, 11 gates e 300 testes,
rodado pelo orquestrador depois dos patches. O achado alto do review foi **medido por sonda de
layout própria, antes e depois**: o "Continuar" após um erro saía de `bottom=788` contra
viewport 640 (360×640) e voltou para 626; no default 800×600, de 629 para 586. Os seis casos
medidos cabem. Os contrastes do balão também foram recalculados de forma independente:
`ink-primary` 9,86:1 claro e 7,55:1 escuro.

**`flutter test integration_test -d <emulador>` NÃO foi executado** — sem device nesta sessão.
As mudanças na e2e (`expectExplainedResult`) são reais e sem `skip:`, mas a primeira execução
será no `e2e-android`, required check da PR.

## Spec Change Log

## Review Triage Log

**Iteração 1 — 2026-09-07.** Três lentes sobre o diff desde `1f086cd`. Convergência num achado
alto de layout que o CI verde não pegava, medido por mim. Sem `intent_gap` nem `bad_spec`.

| # | Achado (lente) | Veredito | Evidência da verificação | Rota |
|---|---|---|---|---|
| 1 | O balão empurra o "Continuar" para fora da tela depois de errar (3 lentes) | **high** | Medido por mim com sonda de layout: em 360×640 o botão fica em `bottom=788` contra viewport 640 — 148 px abaixo da dobra; no default de teste 800×600, em 629. No acerto cabe (607). Em Pixel 6 (411×869) cabe. Agrava: os dois testes que tocavam "Continuar" depois de errar ganharam `ensureVisible`, que **rola o card antes de tocar** — antes, um toque fora da viewport não despachava e a asserção de índice falhava, então o par era guarda implícita de posicionamento. Agora nada flagra a piora. | patch |
| 2 | O gate de overflow a `TextScaler.linear(2.2)` nunca renderiza o balão (vgap) | **medium** | Confirmado: o teste responde com `find.text(state.answer.nameUi)` — a opção **certa** — então `_ResultLine` cai no ramo "Isso!" e o balão nunca é construído sob escala de texto. Hoje não há overflow; o risco é a próxima restrição no balão (um `maxLines`, um `Row` com a ilustração do gato) passar batida. | patch |
| 3 | `ErrorType.octaveError` é inalcançável, então a frase dedicada é código morto (3 lentes) | **medium** | Confirmado: `errorTypeFor` resolve intervalo por `picked.id` dentro de `intervalErrorTypes`, que contém `p8` (a oitava justa) e **não** `octave-error`; acorde idem, escala devolve grau ou far-miss, resolution far-miss. Nenhum id do catálogo é `octave-error`. A linha "Erro de oitava" da minha matriz descreve um caminho que o app não tem. | patch |
| 4 | `alteredDegreeNames` e `scaleErrorTypeByDegree` podem divergir, e os testes são tautológicos (blind, edge, vgap) | **medium** | Confirmado: o teste itera `alteredDegreeNames` e injeta a chave direto, então assere só que o mapa mapeia a si mesmo. Um grau **acrescentado** à taxonomia cai em silêncio no template base. O `hasLength(3)` só pega remoção. | patch |
| 5 | O gate de contraste é mais estreito que a AC escrita para ele (blind, edge) | **medium** | Calculei por conta própria: `ink-primary` sobre `accent-soft` = 9,86:1 e no escuro 7,55:1 (passam); `ink-secondary` = **3,62:1** e **4,37:1** (reprovam). O desvio da implementação foi correto — a instrução literal da minha spec cruzaria todos os inks e quebraria o build num par que o app não desenha. Mas nada registra a restrição junto do token, então uma story futura põe texto secundário no balão com o gate verde. | patch |
| 6 | `epics.md` foi só metade atualizado (blind) | **medium** | Confirmado. A AC irmã ainda diz "O modal de explicação empilha só um nível", enquanto a story construiu deliberadamente algo que **não** é modal — a spec argumenta em volta em vez de corrigir. E o exemplo da AC ("3ª maior"/"3ª menor") não bate com os `nameUi` que o app usa (`terça maior`/`terça menor`). "Atualizar `epics.md` no mesmo PR" é Always congelado. | patch |
| 7 | A e2e ficou mais fraca, não só renomeada (blind, edge, vgap) | **medium** | Confirmado: `landedOnAResult()` casa **qualquer** `Text` com `fontFamily == 'Fredoka'`, então as duas jornadas passam mesmo se o balão renderizar frase vazia ou errada. A asserção antiga ao menos fixava conteúdo. Nada na e2e verifica que a explicação nomeia a resposta — que é o FR-4 em si. | patch |
| 8 | Contradição interna do `DESIGN.md` foi decidida em silêncio (blind) | **low** | Confirmado: a linha 53 especifica o balão como "sempre em `surface-raised` com **borda** `accent-soft`", enquanto as linhas 69 e 102 dizem **fundo** `accent-soft`. A implementação seguiu o preenchimento e não pôs borda alguma. Nem a spec nem o diff registram o conflito, então a próxima story herda a ambiguidade. | patch |
| 9 | Asserção vazia no teste de unidade (blind) | **low** | Confirmado: `expect(text.toLowerCase(), isNot(equals('errado')))` compara a frase inteira com a palavra isolada — verdadeira para qualquer string. O teste de widget acerta usando `isNot(contains(...))`. | patch |
| 10 | `_ResultLine` devolve a linha de acerto para qualquer fase que não seja `incorrect` (blind, edge) | **low** | Confirmado, e hoje é seguro porque a chamada é guardada por `if (answered)`. Mas `== AnswerPhase.correct` falharia fechado em vez de parabenizar numa fase inesperada. Correção direta. | patch |
| 11 | `attempts.last` pode ser de outro exercício ou de um acerto (edge) | **low** | Real mas não alcançável hoje (uma tentativa por exercício, e o ramo só roda em `incorrect`). Guarda de uma linha. | patch |
| 12 | A tarefa 6 está marcada `[x]` para trabalho explicitamente não feito (blind, edge) | **low** | Confirmado: o `sprint-status.yaml` segue `in-progress` e as Implementation Notes dizem "não feito de propósito". Um checkbox marcado para trabalho não realizado é pior que nenhum. | patch (meu) |
| 13 | Não há mascote no balão do mascote (blind) | **low** | Verdadeiro: é um `Container` com um `Text`, sem ilustração, avatar ou rabicho que o faça ler como *fala*. A spec pediu os tokens, não o asset, então não é desvio — mas não estar registrado como deferido faz parecer concluído. | defer |
| 14 | O balão é privado de uma tela, mas o design o pede em quatro lugares (blind) | **low** | Confirmado: `DESIGN.md:102` lista nivelamento, erro, vitória e resumo de sessão; `_MascotBubble` é privado do `interval_exercise_screen.dart` e não há camada de widgets compartilhados. O custo já apareceu: a e2e identifica o balão por `fontFamily == 'Fredoka'` porque a classe é inalcançável. | defer |
| 15 | O balão continua visível durante o replay do motif (edge) | **low** | Real na letra do Never ("enquanto o motif toca"), mas rejeitado no mérito: o propósito registrado no `DESIGN.md` é "não distrai da escuta" **durante o exercício**. Depois de respondido, reouvir com a explicação à vista é justamente a função pedagógica da story. Esconder a explicação no replay pioraria o produto. | rejeitado |
| 16 | Uma diferença de um grau fora de {3,6,7} cairia em far-miss dizendo "bem longe" (edge) | **low** | Inalcançável na v1: os 4 modos diferem só em 3ª, 6ª e 7ª. Vira real se a 1.8 acrescentar lídia (4ª). A sincronia dos dois mapas (achado 4) é o lugar certo para pegar isso. | rejeitado |
| 17 | `gen_contrast_audit.dart` duplica os hex dos tokens (blind) | **low** | Verdadeiro, mas **pré-existente**: já é item registrado no `deferred-work.md` desde a review da 1.1 ("duplica a matemática WCAG e recopia a paleta em `_tokens`"). Esta story só acrescenta duas linhas ao padrão existente. | rejeitado |

**Agrupamento e rota:** 12 para `patch` (11 do subagente, 1 minha), 2 para `defer`, 3 rejeitadas
com refutação. Sem loopback.


## Design Notes

- **Por que duas camadas e não uma.** O template genérico cobre 100% dos casos com zero conteúdo para manter, mas para escala diria "confundiu escala maior com mixolídia" quando o app já sabe que a diferença é só a 7ª. A 1.4b escolheu nomear o erro pelo grau exatamente para que a 1.6 pudesse dizer isso; a camada específica é o resgate desse investimento.
- **`far-miss` não é ausência de informação.** Ele significa "os dois estão longe demais para nomear uma confusão única" — o que é uma informação pedagógica, e a frase deve tratá-la assim.
- **O balão sai de `domain/` como texto pronto.** Se a escolha da frase morasse no widget, a apresentação voltaria a ramificar por tipo — a dívida que a 1.5a gastou uma story inteira para eliminar.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `flutter test test/contrast_test.dart` -- passa com os pares novos
- `flutter test` -- todos passam
- `bash tool/ci.sh` -- exit 0
