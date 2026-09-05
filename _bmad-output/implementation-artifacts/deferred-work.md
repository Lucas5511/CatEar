
## Deferred from: code review of spec-1-1 (2026-09-01)

- Escolha de roteamento de navegação (go_router `StatefulShellRoute.indexedStack` vs `Navigator` aninhado por aba). A Story 1.1 usa `IndexedStack` de placeholders. Revisitar antes da Story 2.6 (skill tree), quando as abas ganham conteúdo real e a regra "modal empilha só um nível" começa a importar. Adicionar `go_router` à stack é decisão de arquitetura (Ask First).
- Migrar a fronteira de módulos de script para `custom_lint` ou pacote-por-módulo (melos), quando o projeto justificar.

## Deferred from: step-04 review de spec-1-1 (2026-09-01, review_loop 1)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Contraste só é verificado contra `surface-base`/`-dark`; pares sobre `surface-raised` (divisor/hairline em card ~2.6:1) e pares `onX` (onPrimary em accent, onError, label da NavigationBar) não têm teste.
  evidence: `test/contrast_test.dart` itera só os dois backgrounds base; `dividerTheme`/`cardTheme` usam `borderHairline` sobre `surfaceRaised` (#FFFFFF), abaixo de 3:1.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `tool/ci.sh` regenera `drift_schemas/` e `docs/design/contrast-audit.md` mas não roda `git diff --exit-code` depois — drift de arquivos derivados passa despercebido.
  evidence: Nenhuma etapa do `ci.sh` compara a saída regenerada com a versão commitada.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `tool/gen_contrast_audit.dart` duplica a matemática WCAG de `wcag.dart` e recopia toda a paleta em `_tokens` em vez de importar `CatColors`.
  evidence: Comentário no próprio arquivo admite "Keep them in sync".
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: CI não tem smoke de build de plataforma (`flutter build apk`/`ios`); o shell pode falhar a compilação nativa com CI verde.
  evidence: `ci.sh` para em `flutter test`; só roda em `ubuntu-latest`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `test/database_test.dart` usa `NativeDatabase.memory()` sob `flutter test`, que depende de `libsqlite3` do sistema no runner; sem passo `apt-get` nem dep `sqlite3`.
  evidence: `sqlite3_flutter_libs` empacota a lib só no app, não na VM de teste.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `check_module_boundaries.dart` não força acesso barrel-only a `domain/`, não checa direção de camada (core importando feature) nem import relativo que escapa de `lib/`.
  evidence: Rule 1 cobre só `data/` e `presentation/`; `_resolveTarget` não sinaliza alvo `../..`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Sem infra de extração de l10n (arb/AppLocalizations); strings pt_BR inline nos widgets (a spec já adia isso, mas fica registrado).
  evidence: Delegates e `supportedLocales` configurados, mas nenhum `l10n.yaml`/`.arb`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `main()` não instala handler global de erro (`FlutterError.onError`/`PlatformDispatcher.onError`/zona guardada); único log é `developer.log` dentro do provider do DB.
  evidence: `lib/main.dart` só chama `runApp`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Contraste da hairline pós-ajuste (#BA843E light / #826C55 dark) ficou muito mais forte que o DESIGN.md pretendia — pendente de revisão com a UX (Sally).
  evidence: Cumprir ≥3:1 como borda não-textual (WCAG 1.4.11) empurrou o hex bem além de uma hairline típica.

## Deferred from: implementation of spec-1-2 (2026-09-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Enforcement de "estágio `resolution` inerte" no skill tree e na geração de sessão é das Stories 1.7 / 2.1. Nesta story os estágios `resolution` existem só como dado; o único sinal é a flag `requiresVoice: true` no domínio (`ResolutionExercise`). Não há consumidor que os oculte/desabilite ainda.
  evidence: `lib/curriculo/domain/curriculum.dart` — `ResolutionExercise.requiresVoice` sempre `true`; nenhum leitor em `nivelamento/` ou `exercicios/`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Manifesto de amostras de áudio da v1 = a união exata dos `audioSampleRefs` de `assets/curriculum/catalog_v1.json`. É a entrada de contrato da Story 1.3b (inclui as amostras dos estágios `resolution` — a 1.3b decide renderizar já ou adiar até o Epic 3).
  evidence: 14 tokens no v1 — `sax_c4, sax_db4, sax_d4, sax_eb4, sax_e4, sax_f4, sax_gb4, sax_g4, sax_ab4, sax_a4, sax_bb4, sax_b4, sax_c5, sax_d5` (raiz C4, topo até D5; sax alto sem vibrato como timbre padrão, cf. `epic-1-context.md`).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `epics.md` AC1 e `content-model.md` §8 põem `scaffoldIntensity` em `exercises[]`; esta spec moveu para o **estágio**. Os dois documentos de planejamento devem ser reconciliados com essa decisão (registrado na spec, Design Notes).
  evidence: `lib/curriculo/domain/curriculum.dart` — `Stage.scaffoldIntensity` / `Stage.timbreScaffold`; `content-model.md` §8 ainda mostra o campo em `exercises[]`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Seam de teste do `AssetBundle` ficou num arquivo próprio (`lib/curriculo/data/catalog_asset_bundle.dart`, com `catalogAssetBundleProvider` + `catalogAssetKey`) em vez de dentro de `curriculo_repository_impl.dart`, para manter o impl com um único símbolo público (`curriculoRepositoryProvider`) como a spec pede. Ainda em `data/` — não exportado pelo barrel, não importável de fora do módulo; testes fazem override do provider.
  evidence: `lib/curriculo/data/catalog_asset_bundle.dart`; `test/curriculum_catalog_test.dart` (`catalogAssetBundleProvider.overrideWithValue`).

## Deferred from: step-04 review de spec-1-2 (2026-09-02, review_loop 1)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Validação semântica de conteúdo musical no `check_curriculum` — `scaleCatalog[].steps` somar 12; `chordCatalog[].intervals` crescente e dentro da oitava; cardinalidade de `audioSampleRefs` por tipo (intervalo=2, **acorde = 4 refs (bloco de tríade + 3 vozes)** desde a Story 1.4b, escala=steps+1, cadência ~6). Fora do R1–R3 do frozen; adicionar quando o módulo `audio` (1.3) fixar a semântica das refs.
  evidence: `lib/curriculo/domain/curriculum_validation.dart` só checa tipo/formato, não faixa/soma. Parcialmente coberto desde 2026-09-04: `test/audio_assets_bundle_test.dart` ("every chord exercise is a triad block plus its three voices") assere a cardinalidade **e** o pareamento tríade↔vozes dos exercícios `chord`; os outros tipos e as somas continuam sem gate.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `IntervalSpec.quality` e `intervalCatalog[].id` são strings livres não cross-checadas contra os 13 ids canônicos de intervalo — 3ª cópia da taxonomia (junto de `errorTypes[]` e do enum `ErrorType`). Um `IntervalId` enum unificaria; é mudança de schema (Ask First).
  evidence: `curriculum_validation.dart` `_validateCatalog` case `intervalCatalog` — só `_requireString(quality)`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `catalog_v1.json` não tem JSON Schema / `$schema` / cabeçalho de proveniência. Para "conteúdo editável sem recompilar", um editor de conteúdo não tem como validar uma edição sem rodar o toolchain Dart. Gerar um JSON Schema a partir de `curriculum_validation.dart` (ou à mão) num chore.
  evidence: schema existe só como Dart imperativo + prosa da spec.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Estratégia de versionamento do asset (como chega o v2: arquivo novo + troca do `catalogAssetKey` vs. bump de `schemaVersion` in-place; expectativa de migração/compat) não documentada, apesar de `curriculo_repository.dart` anunciar "asset hoje, OTA depois".
  evidence: versão codificada no nome do arquivo e em `schemaVersion`, sem doc de transição.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `tool/ci.sh` não tem teste — a etapa `curriculum` antes de `test` pode ser removida/reordenada num edit futuro com todos os testes verdes (R1–R3 só vivem nesse gate). Sem precedente no repo de testar `ci.sh`.
  evidence: grep de `test/` por `ci.sh` não retorna nada.

## Deferred from: implementation of spec-1-3 (2026-09-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: Teste de integração do `_JustAudioService` real contra `just_audio` — precisa de plataforma (device/emulador) + os assets `.wav` da Story 1.3b, não roda sob `flutter test`. Cobrir `playSample` (`stop → setAsset → play → stop`), embrulho de `PlayerException`/`PlatformException` em `SamplePlaybackFailed`, reset best-effort do player quando `play()` falha após `setAsset`, `stop` best-effort quando ocioso, `dispose` liberando o `AudioPlayer` e `StateError` pós-dispose. Nenhuma instância de `_JustAudioService` é construída no suite unitário (a spec proíbe exercitá-lo sob `flutter test`); a lógica de interface é exercida pelo `FakeAudioService` e o wiring do provider por uma instância de `FakeAudioService` sob override. **Disposição (TEA review, F2): entra no DoD da 1.3b, mesmo PR.**
  evidence: `lib/audio/data/audio_service_impl.dart` — `_JustAudioService` sem teste unitário (Design Notes da spec: `AudioPlayer` é classe concreta sem interface); `test/audio_service_test.dart` cobre o `FakeAudioService`, o contrato de valor de `SamplePlaybackFailed` e o wiring/dispose do provider.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: Orquestração de fraseado/sequência de amostras (tocar o intervalo/acorde/escala dentro de uma melodia ou progressão curta, replay, encadeamento) é lógica de apresentação das Stories 1.4+. `AudioService.playSample` toca uma única amostra pré-renderizada por `ref`; compor a frase e o contexto musical é do consumidor.
  evidence: `lib/audio/domain/audio_service.dart` — interface só com `playSample(String ref)` single-shot, sem sequência/`Stream`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: Expansão da interface `AudioService` para gravação de voz / `evaluatePitch` / `Stream` de pitch é a Story 3.2 (Epic 3). A `sealed class AudioError` já nasce selada para os erros de gravação entrarem sem quebrar exaustividade; o gate AR-6 (Regra 4) já cobre `package:record/…` para quando o Epic 3 adicionar a dependência.
  evidence: `lib/audio/domain/audio_service.dart` — só reprodução; `record` está no `pubspec` mas sem uso; lib de pitch fora da stack até o Epic 3.

## Deferred from: step-04 review de spec-1-3 (2026-09-02, review_loop 1)

## TEA review de story 1.3 (Murat, 2026-09-02) — triagem dos itens acima

Findings F1–F8 do review. F1, F3, F4, F5, F6, F8 **resolvidos neste PR**; F2 e F7
retêm como itens com dono, não follow-up genérico.

- F1 — RESOLVIDO: `test/audio_service_test.dart` do teste `playLatency` migrado para
  `fakeAsync` (dep `fake_async` em `dev_dependencies`); zero espera de relógio real.
- F3 — RESOLVIDO: `FakeAudioService` agora modela interrupção (`isPlaying`,
  `interruptedRefs`) e um `playSample`/`stop` seguinte corta o anterior, como o
  `just_audio` real. Cobre o que as Stories 1.4+ vão assertar.
- F4 — RESOLVIDO: `audioAssetKeyFor` lança `ArgumentError` (não mais só `assert`) —
  guarda real de path-traversal válida em build release.
- F5 — RESOLVIDO: `FakeAudioService` ganhou `disposeCount`; `_SpyAudioService`
  duplicado removido do teste de wiring do provider.
- F6 — RESOLVIDO: `_JustAudioService.stop`/`dispose`/reset usam `on Exception`
  (não `catch (_)`); erro de programação sobe, alinhado com `playSample`.
- F8 — RESOLVIDO: Regra 5 no `check_module_boundaries.dart` — nenhum arquivo de
  `lib/` referencia `lib/<m>/testing.dart` nem `lib/<m>/testing/**`; 3 casos de
  teste em `test/module_boundary_test.dart`.

- F2 — puxar-para-story 1.3b (DoD): teste de integração do `_JustAudioService`
  real contra `just_audio` + assets `.wav`. Já descrito no bloco "implementation of
  spec-1-3" acima; a mudança de disposição é que **entra no DoD da 1.3b, mesmo PR**
  (retro action item #5), não como PR de follow-up sem dono. owner: dev da 1.3b.
- F7 — RESOLVIDO PARCIAL / finalizar na 1.3b: `test/audio_service_test.dart` agora
  itera todos os `audioSampleRefs` do `catalog_v1.json` real e valida a chave de
  cada um. Falta (1.3b): assertar que o arquivo `.wav` existe de fato para cada
  chave. owner: dev da 1.3b.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: **✅ RESOLVIDO** (2026-09-03, PRs #13 + follow-up). (F3-adjacente) `_JustAudioService.playSample`/`stop` não serializavam chamadas concorrentes: duas chamadas corriam `stop→setAsset→play→stop` no mesmo `AudioPlayer` com ordem indefinida. O primeiro consumidor real (o `PhrasePlayer` da Story 1.4, que sobrepõe chamadas de propósito para encurtar notas) expôs isso quebrando o job `e2e-android`. Agora `_chain` serializa as mutações do player, `stop()` preempta fora da fila, e a interrupção é reconhecida por `PlayerInterruptedException` (não por generation obsoleta, que engoliria falhas reais).
  evidence: `lib/audio/data/audio_service_impl.dart` — `_chain` + `_predecessorWait` + guarda `PlayerInterruptedException`; regressão em `integration_test/audio_service_test.dart` ("overlapping playSample calls interrupt cleanly" e "a missing sample still reports failure when other calls are in flight").
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: **✅ RESOLVIDO** (2026-09-03). `_JustAudioService` não configurava `AudioSession`/categoria de sessão de áudio; no iOS a reprodução exige a sessão configurada antes de `play()` ou fica silenciosa / mistura errado. Agora o construtor dispara `AudioSession.instance.configure(AudioSessionConfiguration.music())` e `_playSerialized` aguarda esse future antes do primeiro `setAsset`. `music()` mantém o som com a chave de silêncio ligada e toma o foco em vez de duckar — uma amostra que a aluna tem de identificar não pode vir misturada. Configuração é best-effort (mesmo guard de `_quietStop`/`dispose`): uma falha de sessão não vira erro de reprodução no Android, que não precisa dela. **Ainda não verificado em device iOS** — nenhum job de CI consegue; o `build-ios` prova só compilação, e o `e2e-android` prova que configurar a sessão não regride o Android.
  evidence: `lib/audio/data/audio_service_impl.dart` — só `AudioPlayer()`, sem `AudioSession.instance.configure(...)`.

## Resolução na story 1.3b (2026-09-02)

- **F2 — RESOLVIDO**: teste de integração do `_JustAudioService` real criado em
  `integration_test/audio_service_test.dart`. Lê `audioServiceProvider` sem
  override (instância real), cobre: `playSample` de amostra empacotada completa;
  token bem-formado sem asset (`sax_zz9`) vira `SamplePlaybackFailed` (nunca
  `PlayerException`/`PlatformException` cru); `ProviderContainer.dispose()`
  dispara `_JustAudioService.dispose()` sem lançar e uso pós-dispose vira
  `StateError`. Roda no job `e2e-android` (`flutter test integration_test`).
  - **Defeito encontrado e corrigido (AC-12):** o teste de integração revelou que
    `_player.setAsset()` de um asset não empacotado lança um `FlutterError`
    (`Unable to load asset: …`) — que **é um `Error`, não `Exception`** —, então
    o `on Exception catch` de `_JustAudioService.playSample` não o traduzia e o
    erro cru cruzava a fronteira do módulo. Corrigido com um `catch (e)` que
    rethrow só erros de programação (`e is! Exception && e is! FlutterError`) e
    traduz o resto para `SamplePlaybackFailed`. **Isto exigiu editar
    `lib/audio/data/audio_service_impl.dart`**, contra a AC da spec-1-3b
    ("nenhuma mudança em `lib/`" / "`lib/audio/**` inalterado"). Nenhum contrato
    mudou — a correção faz a impl **cumprir** o contrato já documentado em
    `audio_service.dart` ("Every failure surfaces as an AudioError, never a raw
    PlayerException / PlatformException"). Era exatamente a lacuna P2 que a F2
    existia para fechar.
- **F7 — RESOLVIDO**: `test/audio_assets_bundle_test.dart` criado. Lê os
  `audioSampleRefs` do `catalog_v1.json` real via `curriculoRepositoryProvider`,
  faz `rootBundle.load(audioAssetKeyFor(ref))` para cada, e assere que
  `assets/audio/` contém exatamente os `.wav` dos tokens — sem órfão, sem
  `.gitkeep`. Roda no job `gates` (`flutter test`). **Atualizado na Story 1.4b:**
  são 22 tokens (14 notas + 8 tríades pré-renderizadas), não 14.
- Assets: 22 `.wav` mono 44,1 kHz PCM 16-bit em `assets/audio/` (sax alto, Iowa
  MIS) — 14 notas isoladas da 1.3b mais 8 blocos de tríade acrescentados pela
  Story 1.4b, que também rerenderizou as 14; `assets/audio/.gitkeep` removido. Proveniência, licença verbatim e receita
  de conversão em `docs/audio/samples-v1.md`.
- Itens da Story 1.4 acima (serialização de concorrência do `_JustAudioService`,
  `AudioSession`) **permanecem abertos** — fora do escopo da 1.3b.

## Deferred da review adversarial de spec-1-3b (2026-09-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3b-producao-do-conjunto-de-amostras-de-audio-da-v1.md`
  summary: A tradução real de `PlayerException`/`PlatformException` (arquivo
  presente mas corrompido/indecodificável) → `SamplePlaybackFailed` no
  `_JustAudioService` não tem cobertura determinística em plataforma real. O
  `integration_test/audio_service_test.dart` exercita o caminho de asset
  **ausente**, que sai como `FlutterError` (um `Error`), não como `Exception`. O
  ramo `e is Exception` do `catch` fica sem teste de plataforma. Cobrir quando
  houver um fixture de `.wav` deliberadamente corrompido carregado de fora de
  `assets/` (ou um `AudioSource` mock). **Re-triado 2026-09-03** de
  `owner: dev da 1.4` (encerrada sem executá-lo) para a próxima story que
  mexe no consumidor de áudio. owner: dev da 1.5.
  evidence: `lib/audio/data/audio_service_impl.dart` — `catch (e) { if (e is! Exception && e is! FlutterError) rethrow; … }`; só o ramo `FlutterError` é exercido pelo teste de integração.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3b-producao-do-conjunto-de-amostras-de-audio-da-v1.md`
  summary: `_JustAudioService.playSample` com `ref` malformado propaga o
  `ArgumentError` cru de `audioAssetKeyFor` (um `Error`, não `AudioError`) — o
  `catch` o rethrow como erro de programação. Isso contraria o doc-comment de
  `audio_service.dart` ("Every failure surfaces as an AudioError"). Hoje o único
  chamador seria o próprio app com tokens do catálogo (sempre bem-formados), mas
  a story que herdar isto deve decidir: `playSample` embrulha `ArgumentError`
  em `SamplePlaybackFailed`, ou "ref malformado" é contrato-quebrado do
  chamador (e o doc-comment é ajustado para dizer isso). **Re-triado
  2026-09-03** de `owner: dev da 1.4` (encerrada sem decidir). owner: dev da 1.5.
  evidence: `lib/audio/domain/audio_assets.dart` — `audioAssetKeyFor` lança `ArgumentError`; `_JustAudioService.playSample` chama-o dentro do `try` mas o guard `e is! Exception` deixa `ArgumentError` (que é `Error`) subir cru.

## Deferred da review adversarial de spec-1-4 (2026-09-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `_OptionButton` e `ExerciseCard` decidem cor por
  `Theme.of(context).brightness == dark ? xDark : x` na mão. Criar um
  `ThemeExtension` de `CatColors` (tokens semânticos — `scaffoldConsonant`,
  `surfaceRaised`, `borderHairline`…) resolvidos por brightness uma vez, para os
  widgets de exercício (e 1.5+) não bifurcarem. owner: dev da 1.5.
  evidence: `lib/exercicios/presentation/interval_exercise_screen.dart`
  (`_OptionButton.build`), `lib/exercicios/presentation/exercise_card.dart`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `PhrasePlayer` (gaps 450/450/900 ms) e o `_advanceTimer` de 700 ms
  não têm seam de injeção; os widget tests hard-codam `tester.pump()` casando com
  os defaults. Adicionar um seam (provider ou factory `@visibleForTesting`)
  quando a Story 1.5 reusar o fluxo para acordes/escalas. owner: dev da 1.5.
  evidence: `lib/exercicios/presentation/phrase_player.dart` (construtor com
  `noteGap`/`returnHold`/`flourishGap`), `interval_exercise_screen.dart`
  (`_advanceTimer = Timer(const Duration(milliseconds: 700), _advance)`).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: O log de tentativa (`developer.log('$attempt', …)`) é stringly-typed
  via `toString()`. O consumidor da Story 1.7 lê `state.attempts` (estruturado),
  então o log é só debug. Revisitar o formato se a 1.7 quiser log estruturado
  (JSON / campos nomeados). owner: dev da 1.7.
  evidence: `lib/exercicios/presentation/interval_exercise_screen.dart`
  (`IntervalPractice.answer`).

## Deferred from: /code-review de f180ff5..0f153b3 (Story 1.4, 2026-09-03)

Corrigidos num follow-up (`fix/interval-exercise-audio-lifecycle`): o bug crítico
do `audioServiceProvider` auto-descartado, o `catch` estreito do `_playMotif`, o
trap em falha de áudio persistente, a corrida replay-vs-auto-advance, o motivo
que continuava tocando após responder, e `MalformedCatalog`/`UnknownValue`
mostrados como "temporário". Itens abaixo ficam para stories futuras.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `_RetryView` em `exercicios/presentation/` reimplementa
  `lib/app/database_error_screen.dart` (mesma árvore, string "temporário"
  copiada). Promover o "warm retry screen" para `core/` e reusar nos dois lados.
  evidence: `lib/exercicios/presentation/interval_exercise_screen.dart`
  (`_RetryView`) vs `lib/app/database_error_screen.dart`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: 3 subclasses ad-hoc de `CachingAssetBundle` no `test/` (`_RealCatalogBundle`,
  `_FakeBundle`) + `_FailingRepo` duplicam seams que `test/support/` já poderia
  centralizar; parte dos testes de `exercicios/` nem precisa do bundle override
  (basta `curriculoRepositoryProvider.load()` sob `flutter test`). Consolidar em
  `test/support/`.
  evidence: `test/exercicios/interval_exercise_screen_test.dart`,
  `test/curriculum_catalog_test.dart`, `test/support/curriculum_fixtures.dart`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: Três idiomas separados de "delay cancelável" (`PhrasePlayer._wait`/
  `_generation`, `_advanceTimer`+`_advanced`, `FakeAudioService` `Completer`+
  `identical`). Um `CancelableDelay` em `core/` colapsaria os três.
  evidence: `lib/exercicios/presentation/phrase_player.dart`,
  `interval_exercise_screen.dart`, `lib/audio/testing/fake_audio_service.dart`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: Redundância de estado no `_ActiveExerciseViewState` — `_optionsEnabled`
  é o shadow booleano de `_enabledAt != null`; `_motifInFlight` reimplementa o
  `_generation` do `PhrasePlayer`; `_advanced` duplica a guarda de fase do
  `IntervalPractice.advance()`. Enxugar quando a 1.5 tocar neste widget.
  evidence: `lib/exercicios/presentation/interval_exercise_screen.dart:217-232`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `IntervalPracticeState` copia `loop`/`pool` (23 + 13 itens) com
  `List.unmodifiable` a cada `answer()`/`advance()` embora sejam constantes pela
  vida da tela; `intervalPool` chama `intervalLoop` de novo no `build()`. Passar
  `loop` pré-computado / guardar as listas imutáveis uma vez.
  evidence: `lib/exercicios/presentation/interval_exercise_screen.dart`
  (`IntervalPracticeState` ctor, `IntervalPractice.build`),
  `lib/exercicios/domain/interval_practice.dart` (`intervalPool`).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `ExerciseCard` só carrega estilo (`Container` decorado) — não é o seam
  slot-based que "1.5 reusa sem ramificar por tipo" pede. O prompt, o player, o
  loop de opções, `_ResultLine` e "Continuar" estão presos a `IntervalSpec` no
  `_ActiveExerciseViewState`. Extrair slots type-agnostic (player / resposta /
  resultado) antes da 1.5, ou aceitar a cópia.
  evidence: `lib/exercicios/presentation/exercise_card.dart`,
  `interval_exercise_screen.dart` (`_ActiveExerciseViewState.build`).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-exercicio-de-reconhecimento-de-intervalo-em-contexto-musical.md`
  summary: `ExerciseAttempt.errorTypeForIntervalId` acopla `IntervalSpec.id` e
  `ErrorType.id` por igualdade de string com `orElse: throw` — quebra em runtime
  (mid-sessão, fora do `AsyncValue.error`) se um catálogo v2 trouxer um id de
  intervalo sem `ErrorType` correspondente. Um mapa const validado por teste
  sobre o catálogo, ou `ErrorType.forIntervalId` checado, fecharia isso.
  evidence: `lib/exercicios/domain/exercise_attempt.dart`.

## Resolução do item de concorrência da 1.3 (2026-09-03)

O e2e do fluxo de prática (adicionado na PR #12) derrubou o CI no merge e expôs
o item que a Story 1.3 deferiu com dono "dev da 1.4" e nunca foi executado:
`_JustAudioService` não serializava chamadas concorrentes. O `PhrasePlayer` da
1.4 dispara `playSample` sobrepostos **de propósito** (é assim que encurta as
notas), então o primeiro consumidor real é justamente quem viola a premissa de
chamador único.

Duas causas, ambas necessárias:
1. Duas execuções de `setAsset → play → stop` corriam no mesmo `AudioPlayer` com
   ordem indefinida. Agora `_chain` serializa as mutações; só o `stop()` fica
   fora da fila, porque precisa poder preemptar um `play()` em andamento.
2. Quando esse `stop()` preemptivo abortava um `setAsset` em andamento, o
   `just_audio` lançava e nós traduzíamos em `SamplePlaybackFailed` — reportando
   uma **interrupção intencional** (que o contrato promete) como falha. Agora um
   erro cuja `generation` está obsoleta é engolido.

Reprodução determinística: encurtando os gaps do motivo para 40/80 ms (o que o
runner de 2 cores do CI produz na prática, já que o `setAsset` não termina dentro
dos 450 ms) o e2e falha no baseline, falha só com (1), e passa com (1)+(2).

Guarda de regressão: `integration_test/audio_service_test.dart` —
"overlapping playSample calls interrupt cleanly, without a spurious error".

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md`
  summary: **✅ RESOLVIDO** (2026-09-03, junto das chores de qualidade).
  `AudioSession`/categoria de sessão de áudio do iOS — o outro item que a Story
  1.4 herdou e não executou. Ver o bloco resolvido acima; `audio_session` virou
  dependência direta (0.2.4, já estava na árvore via `just_audio`) e entrou na
  Regra 4 do `check_module_boundaries` para não vazar de `lib/audio/`.
  evidence: `lib/audio/data/audio_service_impl.dart` — `_sessionReady` +
  `_configureSession()`; `tool/check_module_boundaries.dart` Regra 4;
  `test/module_boundary_test.dart` ("audio_session import outside lib/audio/
  fails").

## Triagem de owners (2026-09-03) — `tool/check_deferred_owners.dart`

O gate `deferred owners` entrou no `tool/ci.sh` nesta data. Ele falha o build
quando um bloco **não resolvido** deste arquivo carrega `owner: dev da X` e a
story X está `in-progress`/`review` no `sprint-status.yaml`. É a versão
executável do action item S2 — a Story 1.3 deferiu dois itens com
`owner: dev da 1.4` por escrito, a 1.4 passou por spec, implementação, review e
merge sem tocar em nenhum, e um deles derrubou o `e2e-android`.

Na primeira execução o gate acusou **três** itens com `owner: dev da 1.4` (a
story ainda em `review`) — um a mais do que a retro tinha contado. Triagem:

| Item | Antes | Depois | Razão |
|---|---|---|---|
| `AudioSession` do iOS | `dev da 1.4` | — **executado no mesmo dia** | Foi re-triado para `dev, antes do primeiro device iOS` e então implementado, em vez de sobreviver a mais uma story. |
| Ramo `e is Exception` do `catch` sem teste de plataforma (`.wav` corrompido) | `dev da 1.4` | `dev da 1.5` | Cobertura do serviço de áudio; vai junto da próxima story que mexe no consumidor. |
| Contrato de `ref` malformado (`ArgumentError` cru vs `SamplePlaybackFailed`) | `dev da 1.4` | `dev da 1.5` | Decisão de contrato que a 1.4 devia ter tomado e não tomou; a 1.5 reusa o mesmo caminho. |

Re-triar com a razão registrada é a saída legítima do gate. Apagar a tag não é —
e o gate não sabe distinguir, então isso fica como acordo, não como código.

## Deferred from: step-04 review de spec-1-4b (2026-09-04, review_loop 0)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4b-producao-das-triades-e-expansao-dos-catalogos.md`
  owner: dev da 1.5
  summary: `lib/exercicios/presentation/phrase_player.dart:7` ainda diz "within the 14 v1 samples"; são 22 desde a Story 1.4b (14 notas + 8 tríades).
  evidence: Real e verificado por leitura do arquivo. Não corrigido na 1.4b porque o bloco congelado tem `Never: tocar em lib/exercicios/**` e a AC exige `enums.dart` como única mudança em `lib/` — a intenção exclui a correção. A 1.5 já é dona desse arquivo (extração dos slots type-agnostic).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4b-producao-das-triades-e-expansao-dos-catalogos.md`
  owner: dev da 1.5
  summary: O contrato posicional novo dos refs de acorde (`[tríade, fundamental, terça, quinta]`) não está documentado onde um consumidor olha — `lib/curriculo/domain/curriculum.dart:91-92` ainda descreve `audioSampleRefs` como "opaque sample tokens".
  evidence: Real. Um consumidor que passe os refs de um `ChordExercise` para `PhrasePlayer.playMotif` renderiza `tríade, fundamental, tríade`. Não corrigido na 1.4b pela mesma exclusão de intenção acima (seria mudança em `lib/` além de `enums.dart`); a 1.5 é a primeira consumidora.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4b-producao-das-triades-e-expansao-dos-catalogos.md`
  summary: Nada liga a sequência de notas de um exercício `scale` aos `steps` do seu `scaleType`; a Story 1.4b dobrou essa superfície (4 modos, 8 exercícios, cada um com 8 tokens escritos à mão).
  evidence: Trocar `sax_eb4` por `sax_e4` na dórica ascendente passa em todos os gates — o token existe no manifesto, casa a regex e o conjunto de ids não muda; um exercício rotulado "escala dórica" tocaria uma escala maior. É o item de validação semântica já registrado neste arquivo; sem consumidor em runtime até a 1.5.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4b-producao-das-triades-e-expansao-dos-catalogos.md`
  summary: Os três `ErrorType` novos (`terca-alterada`, `sexta-alterada`, `setima-alterada`) não têm teste semântico ligando cada grau ao par de modos que ele separa.
  evidence: A afirmação das Design Notes é derivável de `scaleCatalog[].steps` e eu a verifiquei à mão — maior (0,2,4,5,7,9,11) × mixolídia (…,10) diferem só no 7º; menor (…,8,10) × dórica (…,9,10) só no 6º; dórica (0,2,3) × mixolídia (0,2,4) só no 3º. Um teste tabelado fixaria a premissa e falharia se a Story 1.8 acrescentar um modo que a quebre. Sem consumidor até a Story 1.6 (feedback explicativo).

## Deferred from: advanced elicitation sobre a Story 1.4b (2026-09-05)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4b-producao-das-triades-e-expansao-dos-catalogos.md`
  owner: dev da 1.8
  summary: Acorde é o único tipo de exercício cuja raiz fica congelada dentro do asset, então a Story 1.8 (variações anti-decoreba) consegue variar todos os tipos menos esse. Decidir entre despachar acorde da variação ou reabrir o `Never` de simultaneidade em runtime da 1.4b.
  evidence: Escala é sequência de notas isoladas e o app a monta em runtime em qualquer altura, de graça. Acorde é simultâneo e `AudioService.playSample` toca um arquivo por vez (`_JustAudioService` serializa mutações num único `AudioPlayer`), então a altura vem colada no arquivo pré-renderizado. A 1.4b proíbe explicitamente as duas saídas: "Never: síntese em runtime, download remoto, multi-voz no `AudioService`".

  **Teto medido (2026-09-05, para não redescobrir do zero):** das 14 notas commitadas, só **5 raízes** suportam as 4 qualidades — dó, ré bemol, ré, mi bemol e mi — porque as 4 qualidades exigem os offsets {3,4,6,7,8} acima da raiz, e a partir de fá o conjunto não tem mais as notas necessárias. As 5 raízes cabem em **4 semitons**. Ou seja: ampliar de 2 para 5 raízes dá 20 arquivos com o *mesmo* espalhamento de registro, e os gates forçam 20 exercícios junto (`audio_assets_bundle_test.dart` assere um exercício `chord` por tríade, e o teste de órfãos assere `assets/audio/` == união dos refs do catálogo). `s-acordes` iria a 20 contra 2–4 dos outros estágios. Mais custo, mesma propriedade.

  **Correção de rationale:** o bloco congelado da 1.4b justifica as 2 raízes com "com raiz fixa o exercício vira reconhecimento de altura absoluta". O efeito real é mais modesto — 2 raízes **dobram o custo de memorizar**, não eliminam o mecanismo: o exercício continua sendo função determinística de 8 arquivos com resposta constante, e um aluno pode decorar o som do arquivo sem ouvir a relação musical. Isso contamina o sinal de habilidade que o Epic 2 constrói sobre as tentativas. Mantido como está na 1.5 por decisão do humano em 2026-09-05: a alternativa disponível não compra a propriedade que falta.
