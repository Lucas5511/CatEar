---
title: 'Story 1.7 — Estrutura de sessão de 10–15 minutos'
type: 'feature'
created: '2026-09-08'
status: 'review'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-6-feedback-explicativo-em-erro.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O loop de 39 exercícios não é uma sessão — é uma lista. Não tem identidade (`sessionId`), não tem fim negociado, e não reporta nada quando acaba. O Epic 2 inteiro consome `SessionResultReported`, que ainda não existe: hoje cada tentativa é logada solta com `developer.log` e some. E não há teto de tempo, então quem repete muito o áudio fica sem saída oferecida.

**Approach:** Dar identidade e fronteiras à sessão. Ela abre com um `sessionId` UUID v4, percorre a sequência que já existe, e termina de duas formas — no fim dos 39 ou aceitando a oferta de encerrar aos 12 min. Ao terminar, emite `SessionResultReported` uma vez. Sair antes é abandono e não emite nada.

## Boundaries & Constraints

**Always:**

- **A sequência é o loop inteiro de 39** (decisão do humano, 2026-09-08). A ~15 s por exercício isso já cai em ~10 min, dentro do alvo do FR-5. O corte por tempo é rede de segurança para quem é mais lento, não a forma primária de dimensionar. Nenhum conteúdo fica inacessível, e a Story 1.8 pode crescer o catálogo sem rever esta decisão.
- **A oferta de encerrar aparece aos 12 min** (decisão do humano, 2026-09-08) — meio do alvo — e **só entre exercícios**, nunca durante um card em andamento nem durante o áudio. Quem quiser continuar segue até o fim dos 39.
- **A oferta é sem culpa (UX-DR12).** Ela conta o que já foi feito e trata continuar e encerrar como escolhas iguais. Nada de "tem certeza que quer desistir?".
- **Nenhuma mecânica recompensa sessão mais longa.** Não somar bônus por passar do alvo, nem streak por volume. O que existe é a sequência e o seu fim.
- **`sessionId` é UUID v4 gerado na abertura** (AR-11). `uuid: ^4.0.0` já é dependência direta. O id vive enquanto a sessão vive e não se repete entre sessões.
- **Sessão concluída = chegou ao fim da sequência OU aceitou a oferta, tendo respondido ao menos um exercício.** Qualquer outra saída é **abandono**.
- **`SessionResultReported` é emitido exatamente uma vez por sessão concluída**, com `sessionId` e `attempts` (uma entrada por tentativa: `exerciseType`, `wasCorrect`, `errorType?`, `reactionTimeMs`). `ExerciseAttempt` já carrega os quatro campos desde a 1.5a — nada a acrescentar nele.
- **Abandono não emite nada.** Fechar o app ou voltar descarta as tentativas para fins de progressão. Zero exercícios respondidos também é abandono, mesmo chegando ao fim.
- **Nesta fase o evento é só emitido//logado.** Não há consumidor: o módulo Progressão é Epic 2. Sem event bus global (AR-4) — a emissão é um ponto de extensão explícito, não um broadcast.
- **A emissão é idempotente sob recomposição.** O fim da sequência é um estado de UI que rebuilda; emitir de dentro de um `build` duplicaria o evento.
- **Swipe continua fora da navegação primária (UX-DR13).** Já é verdade — `home_shell.dart` documenta a ausência de `PageView` e `Drawer`. Não introduzir.

**Never:**

- Persistir a sessão ou as tentativas. Banco é Epic 2; aqui o evento é emitido e logado.
- Consumir `SessionResultReported`, agregar, pontuar ou calcular medidor. É Epic 2.
- Seleção adaptativa, reordenação ou sorteio da sequência — Story 2.8.
- Mudar o conteúdo do catálogo, os contornos de motif ou o feedback de erro.
- Emitir o evento em abandono, ou mais de uma vez por sessão.
- Introduzir `PageView`, `Dismissible` ou gesto de swipe para navegar entre exercícios.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Abertura | tela de prática abre | `sessionId` UUID v4 novo, distinto do anterior | — |
| Conclusão natural | 39 respondidos | `SessionResultReported` uma vez, com 39 `attempts` | — |
| Conclusão por oferta | aceita encerrar aos 12 min com N ≥ 1 | evento uma vez, com N `attempts` | — |
| Recusa da oferta | continua depois dos 12 min | nenhum evento ainda; a sessão segue até o fim | a oferta não reaparece a cada exercício |
| Abandono | sai antes do fim, sem aceitar | **nenhum** evento | tentativas descartadas |
| Zero respostas | chega ao fim sem responder nada | **nenhum** evento — é abandono por definição | — |
| Oferta no meio do card | 12 min atingidos com exercício em andamento | a oferta espera o exercício terminar | nunca interrompe áudio nem resposta |
| Recomposição | widget de fim rebuilda | evento **não** duplica | idempotente |
| Sessão nova | volta e abre de novo | `sessionId` diferente; `attempts` zeradas | — |
| Sem swipe | qualquer gesto lateral | não navega entre exercícios | — |

</frozen-after-approval>

## Code Map

**A mudar:**

- `lib/exercicios/domain/` -- a sessão: `sessionId`, o relógio da sessão, a decisão concluída × abandonada, e o evento `SessionResultReported` como tipo. É onde a regra mora, fora da apresentação
- `lib/exercicios/domain/practice_state.dart` -- `PracticeState` já tem `attempts` e `index`; ganha o vínculo com a sessão
- `lib/exercicios/presentation/interval_exercise_screen.dart` -- `IntervalPractice.build` monta o estado inicial (`:94`, `attempts: const []`); `answer` acrescenta a tentativa (`:119-131`); `_EndOfLoopView` é o fim natural. A oferta de encerrar entra entre exercícios; a emissão precisa de um ponto que rode uma vez, não em `build`
- `lib/exercicios/presentation/interval_exercise_screen.dart` -- `PracticeTimings` (`:56-63`) é o seam de tempo que a 1.6 criou; o alvo de 12 min é candidato natural a viver ali, para os testes não esperarem 12 minutos reais
- `test/exercicios/**` -- conclusão natural, conclusão por oferta, abandono, zero respostas, não-duplicação sob recomposição, `sessionId` distinto entre sessões
- `integration_test/catear_e2e_test.dart` -- a jornada já responde exercícios; somar a asserção de que sair no meio não emite
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story

**Verificado, nada a mudar:**

- `lib/exercicios/domain/exercise_attempt.dart` -- os quatro campos que o evento exige já existem desde a 1.5a
- `pubspec.yaml:37` -- `uuid: ^4.0.0` já é dependência direta
- `lib/app/home_shell.dart:9` -- já documenta a ausência de swipe e `PageView`; UX-DR13 satisfeita por construção
- `lib/exercicios/domain/motif.dart` -- as durações por tipo alimentam a estimativa de ~15 s/exercício, mas a sessão mede tempo real, não estimado

## Tasks & Acceptance

**Execution:**

- [x] 1. `lib/exercicios/domain/` -- `SessionResultReported`, o `sessionId` UUID v4 e a regra concluída × abandonada
- [x] 2. `lib/exercicios/domain/practice_state.dart` -- vínculo da sessão com o estado
- [x] 3. `lib/exercicios/presentation/interval_exercise_screen.dart` -- a oferta aos 12 min entre exercícios, e a emissão única no fim
- [x] 4. `PracticeTimings` -- o alvo de 12 min como campo injetável, para os testes não esperarem tempo real
- [x] 5. `test/exercicios/**` -- as linhas da matriz, com ênfase em abandono e não-duplicação
- [x] 6. `integration_test/catear_e2e_test.dart` -- abandono não emite
- [x] 7. `sprint-status.yaml` -- `in-progress` ao começar, `review` ao abrir o PR

**Acceptance Criteria:**

- Given a tela de prática abrindo duas vezes, then os dois `sessionId` são UUID v4 distintos.
- Given uma sessão concluída de qualquer das duas formas, then `SessionResultReported` é emitido **exatamente uma vez**, com um `attempts` por tentativa respondida.
- Given uma sessão abandonada, ou concluída com zero respostas, then nenhum evento é emitido.
- Given 12 min atingidos, then a oferta aparece entre exercícios, nunca durante um; recusá-la deixa a sessão seguir até o fim.
- Given os comandos de §Verification, then todos saem com exit 0.

**Verificação humana (não bloqueia o agente):**

- Percorrer uma sessão até o fim e conferir que o encerramento não cobra nem culpa; e sair no meio, conferindo que o app não insiste.

## Implementation Notes

**A sessão como valor, a emissão como método.** `PracticeSession` (`sessionId`
UUID v4 + `startedAt`) entrou no `PracticeState`, então o relógio da sessão e a
sua identidade viajam com o estado e um teste os lê sem tocar em widget. O que
**não** entrou no estado foi o `_reported` do notifier: ele é fato sobre um
efeito colateral já executado, não dado de UI, e um `copyWith` não pode
carregá-lo para lugar nenhum.

**Onde a emissão mora.** `IntervalPractice._finish`, chamado por `advance()` (fim
da sequência) e por `acceptEndOffer()`. Nenhum `build` participa. Há duas
travas e nenhuma é redundante: as guardas de fase impedem uma segunda chamada
pela UI, e o `_reported` a impede de todo. O teste que protege isso reconstrói a
tela de fim (troca de tema + pumps) e reconfere a contagem — a falha que ele
pega é invisível na tela e vira progresso dobrado no Epic 2.

**A oferta como fase, não como diálogo.** `AnswerPhase.offeringEnd` é a lacuna
entre dois exercícios: o card anterior já foi respondido e o próximo ainda não
montou, então não há áudio tocando nem resposta pela metade — a restrição "só
entre exercícios" é satisfeita por construção, não por checagem. O próximo
exercício já é escolhido antes da oferta, então recusar monta o card que já
estava decidido, sem segunda passada no gerador de opções. `endOffered` fica
marcado ao oferecer: a oferta não volta.

**O seam de tempo rendeu de novo.** `PracticeTimings.endOfferAfter` (12 min por
padrão) segue os outros dois campos que a 1.6 criou. Nos testes ele é explícito
(30 s, cruzados com um `pump`) em vez de depender do motif ser mais longo que o
alvo — a primeira versão dos testes fazia isso por acidente e a oferta aparecia
um exercício antes do esperado.

**O item deferido da 1.4 que era desta story** (log de tentativa
stringly-typed) foi resolvido decidindo *onde* a estrutura mora: no evento
tipado, não na linha de log. O log por tentativa fica como debug; o log de
sessão (`LoggingSessionResultReporter`) é que virou campos nomeados.

**Fora do escopo, observado:** a tela de fim de sessão agora tem duas redações
(percorreu tudo / encerrou por hoje) e nenhuma delas mostra o que foi acertado —
o resumo de sessão é a Story 2.4, e antecipá-lo aqui exigiria agregar, que é
exatamente o que esta story não faz.

## Spec Change Log

## Review Triage Log

**`/code-review high`, 2026-09-08** — quatro achados, três corrigidos em
`fix/story-1-7-review-followup`, um aceito como está.

1. **Corrigido — `audioServiceProvider` descartado durante a oferta.** A
   assinatura que segura o provider auto-dispose morava no card do exercício, e
   a oferta desmonta o card: o `_JustAudioService` real morria com a oferta na
   tela e um segundo `AudioPlayer` nascia ao recusar. Nada estava tocando
   naquele instante, que é exatamente por que nenhum teste pegou. A assinatura
   subiu para `IntervalExerciseScreen`, que agora é `ConsumerStatefulWidget` —
   a invariante que o comentário do card já afirmava passou a ser verdade. O
   teste novo foi rodado contra o código antigo e falha nele (`disposeCount` 1
   em vez de 0).
2. **Corrigido — contagem por sessão redigida como total do dia.** "Você já
   praticou N exercícios **hoje**" mostra `state.attempts.length`, que é por
   sessão e é descartado no abandono. Numa segunda sessão no mesmo dia,
   subestima. Virou "nesta sessão"; um total do dia é coisa que só a Progressão
   pode saber (Epic 2).
3. **Corrigido — `report()` sem tratamento de erro.** Hoje o reporter só loga e
   não tem como lançar, mas ele roda a partir do `Timer` de auto-advance: com a
   ingestão em banco do Epic 2, uma exceção escaparia como erro assíncrono não
   tratado e derrubaria a sessão que a pessoa acabou de terminar. O `_reported`
   continua sendo marcado **antes** da chamada — a ingestão do Epic 2 é
   idempotente por `sessionId`, então duplicar é pior que falhar uma vez.
4. **Aceito como está — relógio de parede na oferta dos 12 min.** Registrado em
   `deferred-work.md` com o motivo: trocar por `Stopwatch` mata o seam de
   `clock` que faz os testes rodarem em milissegundos, e o dano de um salto de
   NTP é uma oferta fora de hora, recusável com um toque. Nenhuma tentativa se
   perde. Revisitar se o relógio da sessão passar a alimentar pontuação.

## Design Notes

- **Por que os 39 e não um subconjunto.** Sortear uma sequência menor exigiria decidir *como* escolher, e seleção adaptativa é explicitamente Story 2.8. Um sorteio ingênuo agora viraria dívida a desfazer.
- **Por que a emissão não pode morar no `build`.** O fim da sequência é um estado de UI que rebuilda por qualquer motivo — mudança de tema, rotação, `setState` vizinho. O Epic 2 vai agregar em cima deste evento, e um evento duplicado vira progresso duplicado.
- **Por que abandono não emite.** É decisão de produto herdada do `epics.md`: tentativas de uma sessão não terminada não contam para progressão. A telemetria do Epic 4, se ligada, registra o abandono por outro caminho.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `dart run tool/check_deferred_owners.dart` -- exit 0
- `flutter test` -- todos passam
- `bash tool/ci.sh` -- exit 0
