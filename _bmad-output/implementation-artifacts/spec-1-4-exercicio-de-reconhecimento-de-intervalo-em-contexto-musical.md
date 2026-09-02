---
title: 'Story 1.4 — Exercício de reconhecimento de intervalo em contexto musical'
type: 'feature'
created: '2026-09-02'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'f180ff596d551c9c155f1d68fde43f8d0d32f688'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-3b-producao-do-conjunto-de-amostras-de-audio-da-v1.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Todas as peças de fundação existem (tema, catálogo como dado, `AudioService`, 14 amostras), mas não há nenhuma tela de exercício. A usuária não consegue treinar reconhecimento de intervalo.

**Approach:** Uma tela de exercício de intervalo em `exercicios/presentation/`, alcançada pelo CTA "Praticar" da Home. Ela percorre um loop fixo dos `IntervalExercise` do catálogo (ordem de estágio), um Exercise card por vez: toca o intervalo como um pequeno motivo rítmico (sequência de `playSample`, nunca par isolado em silêncio), com replay livre; a resposta é tap em 4 opções de múltipla escolha geradas na apresentação; resposta correta dá feedback visual + sonoro imediato sem mascote; o tempo de reação de cada tentativa é registrado num `ExerciseAttempt` (logado, sem persistência). Dimensionamento de sessão (1.7), variação anti-decoreba (1.8) e bubble de erro explicativo (1.6) ficam de fora.

## Boundaries & Constraints

**Always:**
- **Módulo `exercicios/`**: código novo em `domain/` e `presentation/`; `data/` fica só com `.gitkeep`. O barrel `exercicios.dart` reexporta de `domain/` **mais** a tela-rota de `presentation/` (Regra 1 do gate permite barrel reexportar `presentation/`). Nenhum outro módulo importa `exercicios/presentation|data/` direto.
- **Fluxo de estado (AD-5):** `UI → Riverpod Notifier → domain`. A tela lê `curriculoRepositoryProvider` e `audioServiceProvider` pelos barris `package:catear/{curriculo,audio}/*.dart`; estado assíncrono via `AsyncValue`; nenhum acesso a Drift.
- **Três funções puras no `domain/`:**
  1. loop fixo: `Curriculum` → `List<IntervalExercise>` achatados em ordem de `stage.order` (só `interval`; `chord`/`scale`/`resolution` fora). Sem dimensionamento por tempo, sem aleatório, sem variação.
  2. `intervalOptionsFor(IntervalSpec resposta, Iterable<IntervalSpec> pool, {required int seed})` → exatamente 4 `IntervalSpec` (resposta + 3 distratores), enviesada para `semitones` adjacentes, ordem embaralhada determinística por `seed`. `pool` = `IntervalSpec` distintos dos `IntervalExercise` do catálogo (13); pool < 4 → completa com o que há, sempre inclui a resposta.
  3. `ExerciseAttempt` (`exercise_attempt.dart`): valor imutável `{ExerciseType exerciseType, bool wasCorrect, ErrorType? errorType, int reactionTimeMs}` + `==`/`hashCode`/`toString`. Enums vêm do `curriculo` (AR-4/AR-8), nunca string livre. Erro: `errorType` = `ErrorType` cujo `.id` == `IntervalSpec.id` da opção escolhida; acerto: `null`. Só construído e logado (`dart:developer`), sem persistência nem evento (consumidor é 1.7).
- **Contexto musical (FR-2 / AC2):** um phrase player em `presentation/` sequencia `AudioService.playSample` num motivo de 3 eventos a partir de `audioSampleRefs` — `refs[0]`, `refs[1]`, `refs[0]` — com gaps musicais, deixando cada disparo interromper o anterior para encurtar a nota (default de ritmo documentado). Nunca só duas notas soltas em silêncio. Não estabelece tonalidade com acorde/escala (Ask First).
- **Replay:** botão sempre presente no card, sem limite (NFR-5); refaz o mesmo motivo.
- **Tempo de reação:** do instante em que as opções habilitam (1ª reprodução concluída) até o 1º tap; replays não reiniciam.
- **Exercise card (UX-DR6):** widget reutilizável em `presentation/` — `surface-raised`, `CatRadii.md`, um por tela, respiro generoso (`CatSpacing`), player + resposta centralizados. A Story 1.5 reusa sem ramificação por tipo.
- **Resposta correta:** opção certa destaca em estado positivo (`scaffold-consonant`; zero vermelho na tela) + flourish curto via `AudioService` reusando amostras (`sax_c4`→`sax_e4`→`sax_g4` rápido); mascote **não** aparece (UX-DR12); avança.
- **Resposta incorreta:** estado gentil ("não foi dessa vez", sem vermelho saturado, sem mascote — bubble é a 1.6), revela a correta, botão continuar; registra o `ExerciseAttempt`.
- **Fim do loop:** tela de encerramento simples com "Voltar" (`pop` para a Home). Sem card de vitória do mascote (é o Resumo de Sessão da 1.7).
- **Navegação:** Home ganha `FilledButton` "Praticar" (`accent`) → `Navigator.push` de `MaterialPageRoute` com a tela (um nível sobre o shell; back do Android faz `pop`). A 1.7 troca o destino.
- **Acessibilidade (base):** cada opção é alvo ≥48dp com `Semantics` (papel botão + rótulo = nome do intervalo); replay rotulado; estado certo/errado anunciado por texto, não só cor; sem truncar sob dynamic type.
- **Continuidade do Epic 1:** Riverpod codegen (`@riverpod`, `.g.dart` git-ignorado); `fake_async` nos testes com relógio; `FakeAudioService` via `audioServiceProvider.overrideWithValue` em todo teste — nenhum toca `just_audio`.

**Ask First:**
- Estabelecer tonalidade com acorde/arpejo/escala antes do intervalo, ou qualquer coisa que precise de amostras além das 14 (inclui um pacote de SFX dedicado para acerto/erro).
- Persistir tentativas, criar tabela em `progressao/`, ou emitir `SessionResultReported` (é 1.7/1.8/2.1).
- Reprodução simultânea de duas amostras (drone) — o `AudioService` é mono-player.
- Adicionar `go_router` ou outra lib de navegação.
- Mostrar bubble/explicação do mascote no erro (é a Story 1.6).

**Never:**
- Código específico por tipo de exercício no fluxo de apresentação — a diferença vem dos dados do catálogo (AR-8); o card e o fluxo têm que servir `chord`/`scale` na 1.5 sem ramificação.
- Tocar o intervalo como par de notas isoladas em silêncio (FR-2).
- Vermelho saturado / "X" duro / tela cheia de bloqueio no erro (UX-DR14).
- Mascote durante o exercício ou no acerto (UX-DR12).
- Síntese de áudio em runtime, download remoto, ou orquestração de fraseado dentro do `audio/` (fica em `exercicios/`).
- Limite de replays; mecânica que puna quem ouve mais vezes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Loop do catálogo | `Curriculum` real | sequência = todos os `IntervalExercise` em ordem de `stage.order`; `chord`/`scale`/`resolution` fora | N/A |
| Motivo em contexto | `IntervalExercise` com `audioSampleRefs: [r0, r1]` | `playSample` chamado na ordem `r0, r1, r0` com gaps; a 2ª e 3ª interrompem a anterior | `SamplePlaybackFailed` do `AudioService` → o card mostra estado de erro de áudio com "tentar de novo", não crash |
| Replay | tap em replay N vezes | o mesmo motivo toca de novo; contagem de RT não reinicia | idem |
| Opções geradas | `intervalOptionsFor(M3, pool13, seed: s)` | 4 `IntervalSpec` distintos, inclui `M3`, distratores enviesados p/ ±1–2 semitons, ordem determinística por `s` | pool < 4 → devolve o que há, ainda inclui a resposta |
| Resposta correta | tap na opção que casa `exercise.interval` | opção destaca positivo, flourish `sax_c4→e4→g4`, sem mascote, avança; `ExerciseAttempt(wasCorrect: true, errorType: null, reactionTimeMs > 0)` logado | N/A |
| Resposta incorreta | tap numa opção errada | estado gentil sem vermelho, revela a correta, botão continuar; `ExerciseAttempt(wasCorrect: false, errorType: <ErrorType do id da opção>, reactionTimeMs > 0)` logado | N/A |
| RT | opções habilitam em t0, tap em t1 | `reactionTimeMs ≈ (t1 - t0).inMilliseconds`, sempre > 0 | relógio de teste via `fake_async` |
| Fim do loop | responde o último exercício | tela de encerramento; "Voltar" faz `pop` para a Home | N/A |
| Catálogo falha ao carregar | `curriculoRepositoryProvider` completa com `CurriculumError` | a tela mostra estado de erro com "tentar de novo" (`ref.invalidate`), nunca tela branca / exceção crua | `AsyncValue.error` renderizado |
| CTA Praticar | tap em "Praticar" na Home | `Navigator.push` da tela; back do Android faz `pop` de volta à Home | N/A |

</frozen-after-approval>

## Code Map

- `assets/curriculum/catalog_v1.json` -- `IntervalExercise` traz `audioSampleRefs: [nota1, nota2]` (já ordenados por `direction`) + `interval` id + `direction`; `intervalCatalog` tem os 13 `IntervalSpec` (`id` ∈ `P1 m2 M2 m3 M3 P4 TT P5 m6 M6 m7 M7 P8`, casam 1:1 com `ErrorType.id`)
- `lib/curriculo/domain/curriculum.dart:96` -- `sealed class Exercise` + `final class IntervalExercise` (`interval: IntervalSpec`, `direction: Direction`, `audioSampleRefs`)
- `lib/curriculo/domain/catalogs.dart:10` -- `IntervalSpec` (`id`, `semitones`, `nameUi`, `abbr`, `quality`) — `nameUi` para exibir a opção, `semitones` para o viés dos distratores
- `lib/curriculo/domain/enums.dart` -- `ExerciseType`, `ErrorType` (com `.id`), `Direction`; **definidos só no `curriculo`** — importar, nunca redefinir
- `lib/curriculo/curriculo.dart` -- barrel: exporta `curriculoRepositoryProvider`, `Curriculum`, `Exercise`/`IntervalExercise`, os `*Spec`, os enums
- `lib/audio/audio.dart` -- barrel: `audioServiceProvider`, `AudioService`, `AudioError`/`SamplePlaybackFailed`
- `lib/audio/domain/audio_service.dart` -- `playSample(String ref)` (single-shot, interrompe o que estiver tocando, completa ao fim/interrupção), `stop()`
- `lib/audio/testing/fake_audio_service.dart:12` -- `FakeAudioService`: `playedRefs` (ordem), `interruptedRefs` (com `playLatency > 0`), `stopCount`, `unplayableRefs`, `playLatency` — usar para testar o phrase player e o wiring
- `lib/app/home_screen.dart:4` -- placeholder atual; adicionar o `FilledButton` "Praticar" + `Navigator.push`; importa `package:catear/exercicios/exercicios.dart`
- `lib/app/home_shell.dart:11` -- shell com `PopScope`/`IndexedStack`; a tela do exercício empilha por cima via `Navigator`, o `PopScope` só cobre as abas
- `lib/core/theme/tokens.dart:20` -- `CatColors` (`surfaceRaised`, `accent`, `scaffoldConsonant`, `inkPrimary`…), `CatRadii.md`, `CatSpacing`
- `lib/exercicios/exercicios.dart` -- barrel vazio hoje; passa a exportar `domain/` + a tela-rota
- `lib/exercicios/{data,domain,presentation}/.gitkeep` -- `domain/` e `presentation/` ganham código; `data/.gitkeep` fica
- `tool/check_module_boundaries.dart:1-19` + Regra 1 (`:134`) -- barrel pode reexportar `presentation/`; import cross-módulo de `presentation/` direto é violação
- `test/home_shell_test.dart` -- padrão de widget test: `ProviderScope` + `MaterialApp(theme: appTheme(...))`; espelhar
- `test/audio_service_test.dart` -- padrão de override de `audioServiceProvider` + `fake_async` para latência
- `test/curriculum_catalog_test.dart` -- `container.read(curriculoRepositoryProvider).load()` carrega o catálogo real sob `flutter test`; reusar

## Tasks & Acceptance

**Execution:**
- [x] `lib/exercicios/domain/exercise_attempt.dart` -- `ExerciseAttempt` (valor imutável, `==`/`hashCode`/`toString`), campos com enums do `curriculo`
- [x] `lib/exercicios/domain/interval_practice.dart` -- função pura: `Curriculum` → `List<IntervalExercise>` em ordem de estágio; e o `pool` de `IntervalSpec` distintos
- [x] `lib/exercicios/domain/interval_options.dart` -- `intervalOptionsFor(answer, pool, {seed})` → 4 opções, viés por `semitones`, shuffle determinístico
- [x] `lib/exercicios/presentation/phrase_player.dart` -- sequencia `AudioService.playSample` no motivo `r0,r1,r0` com gaps + interrupção; default de ritmo documentado
- [x] `lib/exercicios/presentation/exercise_card.dart` -- widget do Exercise card reutilizável (`surface-raised`, `rounded/md`, um por tela)
- [x] `lib/exercicios/presentation/interval_exercise_screen.dart` -- a tela-rota: `AsyncValue` do catálogo, loop fixo, player + replay, 4 opções tap, feedback correto (visual + flourish, sem mascote), estado de erro gentil, captura de RT + log do `ExerciseAttempt`, tela de fim, estados de erro de áudio/catálogo
- [x] `lib/exercicios/presentation/*_screen` Notifier(s) `@riverpod` conforme necessário para o estado do loop/tentativa
- [x] `lib/exercicios/exercicios.dart` -- barrel: `export 'domain/...'` + `export 'presentation/interval_exercise_screen.dart'`
- [x] `lib/app/home_screen.dart` -- `FilledButton` "Praticar" (`accent`) → `Navigator.push` da tela
- [x] `test/exercicios/interval_practice_test.dart` -- ordem do loop, filtro de tipo, pool de 13
- [x] `test/exercicios/interval_options_test.dart` -- 4 opções, inclui a resposta, determinismo por seed, viés de semitom, pool pequeno
- [x] `test/exercicios/exercise_attempt_test.dart` -- contrato de valor; mapeamento opção errada → `ErrorType` por `.id`
- [x] `test/exercicios/phrase_player_test.dart` -- `playedRefs == [r0,r1,r0]`, usa interrupção (`playLatency > 0` → `interruptedRefs`), `fake_async`
- [x] `test/exercicios/interval_exercise_screen_test.dart` -- card renderiza (`surface-raised`/`rounded/md`), replay ilimitado, tap correto → destaque + flourish (`playedRefs` recebe `sax_c4,sax_e4,sax_g4`) + sem mascote + avança, tap errado → estado gentil sem vermelho + revela correta + `ExerciseAttempt` errado, RT > 0 (`fake_async`), fim do loop → "Voltar" faz `pop`, `CurriculumError`/`SamplePlaybackFailed` → estado de erro com "tentar de novo"
- [x] `test/exercicios/home_praticar_test.dart` (ou estender `home_shell_test`) -- "Praticar" na Home empilha a tela; back volta

**Acceptance Criteria:**
- Given a Home, when a usuária toca "Praticar", then a tela do exercício de intervalo abre por cima do shell e o back do Android volta para a Home.
- Given um `IntervalExercise`, when o card é apresentado, then o intervalo toca como o motivo `r0,r1,r0` (verificável em `FakeAudioService.playedRefs`), nunca só `[r0, r1]`, e há um botão de replay sem limite.
- Given uma resposta correta, when a usuária toca a opção certa, then a opção destaca em estado positivo (sem vermelho em tela), um flourish curto toca via `AudioService`, o mascote não aparece, e o fluxo avança.
- Given uma resposta (certa ou errada), when respondida, then um `ExerciseAttempt` com `reactionTimeMs > 0` e `exerciseType == ExerciseType.interval` é logado; errada carrega o `ErrorType` da opção escolhida, certa carrega `errorType == null`.
- Given o catálogo ou o áudio falhando, when a tela tenta carregar/tocar, then aparece um estado de erro com ação de repetição — nunca exceção crua ou tela branca.
- Given `flutter analyze` + `dart run tool/ci.sh`, then "No issues found!" / exit 0, incluindo `module boundaries` (nada importa `exercicios/presentation/` ou `exercicios/data/` de fora; nada de `just_audio` fora de `audio/`).
- Given `git status`, then `lib/exercicios/data/` segue só com `.gitkeep`.

## Design Notes

**Motivo em vez de dyad (FR-2):** o catálogo dá exatamente duas notas por intervalo; a AC proíbe tocá-las soltas. O menor "contexto musical" honesto e dentro das 14 amostras é um contorno melódico de 3 eventos reusando as mesmas notas — `r0, r1, r0` — com ritmo. Como `playSample` interrompe o que está tocando e completa na interrupção, o phrase player dispara sem aguardar a nota inteira e usa `Future.delayed(gap)` entre disparos; a última nota pode soar até o fim ou ser cortada por um `stop()`. Default sugerido: gap ~450 ms nas duas primeiras, ~900 ms na volta. 1.5/1.7/1.8 podem enriquecer (progressão, tônica) — não regridem este contrato.

**Opções determinísticas:** `seed` explícito (ex.: `Object.hash(exercise.interval.id, exercise.direction, indiceNoLoop)`) mantém as opções estáveis entre rebuilds e testáveis. Viés: ordenar candidatos por `|cand.semitones - answer.semitones|` e pegar os mais próximos, garantindo pelo menos um "vizinho" (M3/m3, TT/P5) — as confusões que o treino de ouvido de verdade produz.

**`ErrorType` da opção errada:** `intervalCatalog[].id` e os 13 primeiros `ErrorType` têm os mesmos tokens (`P1..P8`), então `ErrorType.values.firstWhere((e) => e.id == picked.id)`. Isso já deixa o `errorType` pronto para a Story 1.6 (explicação) e 1.7 (`SessionResultReported`) sem retrabalho.

**Feedback sonoro de acerto:** não há SFX dedicado nas 14 amostras e adicionar um é Ask First. O flourish `sax_c4→sax_e4→sax_g4` (arpejo maior, rápido) reusa amostras existentes, soa celebratório e "parece um app de música". Um pacote de SFX próprio fica deferido.

## Verification

**Ambiente:** prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `flutter pub get` && `dart run build_runner build --delete-conflicting-outputs` -- gera os `.g.dart` dos novos providers
- `dart format --output=none --set-exit-if-changed .` -- sem diffs
- `flutter analyze` -- "No issues found!"
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `flutter test` -- todos passam, incluindo a suíte nova em `test/exercicios/`
- `dart run tool/ci.sh` -- exit 0
- `git status` -- `lib/exercicios/data/` só com `.gitkeep`

## Suggested Review Order

**O design do exercício (domínio puro)**

- Ponto de entrada — o loop fixo: todo `IntervalExercise` em ordem de estágio, nada de dimensionamento/aleatório.
  [`interval_practice.dart:13`](../../lib/exercicios/domain/interval_practice.dart#L13)
- Geração das 4 opções: resposta + 3 distratores mais próximos por semitom, shuffle determinístico por seed.
  [`interval_options.dart:19`](../../lib/exercicios/domain/interval_options.dart#L19)
- `ExerciseAttempt` — valor imutável com enums do `curriculo`; `errorType` resolvido do id da opção; `assert(reactionTimeMs > 0)`.
  [`exercise_attempt.dart:14`](../../lib/exercicios/domain/exercise_attempt.dart#L14)

**Contexto musical (FR-2)**

- `PhrasePlayer` sequencia `playSample` no motivo `r0,r1,r0` com gaps + interrupção; guarda de geração p/ replay/dispose; recheque de falha tardia.
  [`phrase_player.dart:85`](../../lib/exercicios/presentation/phrase_player.dart#L85)

**A tela e o estado**

- `IntervalPractice` notifier: carrega o catálogo, dono do loop/índice/opções/fase/tentativas; `answer()` loga o `ExerciseAttempt`.
  [`interval_exercise_screen.dart:96`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L96)
- `IntervalPracticeState` — `List.unmodifiable` nos 4 campos-lista para o `@immutable` valer.
  [`interval_exercise_screen.dart:47`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L47)
- Branch `error:` separa `CurriculumError` (transitório) de erro inesperado (não promete "temporário").
  [`interval_exercise_screen.dart:184`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L184)
- `_pick`: captura de RT (`_enabledAt` → tap), guarda `_picked` contra double-tap, flourish + `_advance` guardado por `_advanced`.
  [`interval_exercise_screen.dart:279`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L279)
- `_AudioErrorBanner` aditivo (não esconde as opções / "Continuar" após responder).
  [`interval_exercise_screen.dart:333`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L333)

**Card, opções e navegação**

- `ExerciseCard` reutilizável (`surface-raised`, `CatRadii.md`) — a Story 1.5 reusa.
  [`exercise_card.dart:12`](../../lib/exercicios/presentation/exercise_card.dart#L12)
- `_OptionButton`: alvo ≥52dp, `Semantics` botão + rótulo com estado, `softWrap` p/ dynamic type.
  [`interval_exercise_screen.dart:396`](../../lib/exercicios/presentation/interval_exercise_screen.dart#L396)
- CTA "Praticar" na Home → `Navigator.push`.
  [`home_screen.dart:1`](../../lib/app/home_screen.dart#L1)
- Barrel: exporta só `IntervalExerciseScreen` de `presentation/`.
  [`exercicios.dart:15`](../../lib/exercicios/exercicios.dart#L15)

**Testes (periféricos)**

- Suíte da tela: RT `closeTo` o tempo pumpado + invariância sob replay, double-tap, sem mascote nos 3 estados, dark, `textScaler` 2.2, replay falho pós-erro.
  [`interval_exercise_screen_test.dart:1`](../../test/exercicios/interval_exercise_screen_test.dart#L1)
- `phrase_player_test.dart` — motivo `[r0,r1,r0]`, interrupção, falha tardia, refs vazias.
  [`phrase_player_test.dart:1`](../../test/exercicios/phrase_player_test.dart#L1)
