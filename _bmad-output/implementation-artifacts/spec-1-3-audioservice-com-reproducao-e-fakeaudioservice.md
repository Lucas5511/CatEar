---
title: 'Story 1.3 — AudioService com reprodução e FakeAudioService'
type: 'feature'
created: '2026-09-02'
status: 'done'
review_loop_iteration: 0
baseline_commit: '3f845771f9efb48f18526ff317344199e831fcca'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os exercícios (Stories 1.4+) precisam tocar amostras de áudio pré-renderizadas, mas não existe camada de áudio. Acoplar a lógica de exercício direto a `just_audio` violaria AD-3/AR-6 e forçaria reescrita quando a captura de voz (Epic 3) entrar; e nenhum teste de Exercícios/Nivelamento/Progressão pode depender de hardware de áudio.

**Approach:** Uma interface `AudioService` no `domain/` do módulo `audio` expondo **só** reprodução de uma amostra por referência de asset. Implementação real `_JustAudioService` (library-private, único ponto que importa `just_audio`) atrás de um `audioServiceProvider` Riverpod. `FakeAudioService` público que registra as chamadas e simula reprodução sem tocar áudio, injetado nos testes via override do provider. Gravação e `evaluatePitch` ficam para a Story 3.2.

## Boundaries & Constraints

**Always:**
- Continuidade do Epic 1: Riverpod codegen (`@riverpod` + `riverpod_annotation` 4.0.6, `.g.dart` git-ignorado, regenerado no CI) como em `lib/curriculo/data/`; `just_audio` 0.10.6 (já no `pubspec`). Erros de domínio como `sealed class ... implements Exception`; `Future`/`async` para toda operação de áudio.
- Estrutura: `lib/audio/{domain,data}` + barris. O barrel `audio.dart` reexporta **só** de `domain/` **mais** `audioServiceProvider` (padrão idêntico ao `curriculo.dart`). Um segundo barrel `lib/audio/testing.dart` reexporta o `FakeAudioService`. Nenhum outro módulo importa `package:just_audio/…` nem toca em `audio/data/`. `presentation/` fica só com `.gitkeep`.
- **`AudioService`** (interface abstrata em `lib/audio/domain/audio_service.dart`):
  - `Future<void> playSample(String ref)` — toca uma única amostra pré-renderizada identificada pelo token de catálogo `ref` (ex.: `sax_c4`). Interrompe qualquer amostra ainda tocando. Completa quando a reprodução termina. Sem limite de chamadas (replay livre).
  - `Future<void> stop()` — silencia a amostra atual; no-op se ocioso.
  - `Future<void> dispose()` — libera recursos de plataforma; chamado pelo provider em `onDispose`; instância não reutilizável depois.
- **Erros** (`lib/audio/domain/audio_error.dart`): `sealed class AudioError implements Exception` com um subtipo `SamplePlaybackFailed(String ref, String message)` (com `==`/`hashCode`/`toString`). Toda falha de `playSample` sai como `AudioError` — nunca `PlayerException`/`PlatformException` cru cruzando a fronteira. `playSample`/`stop` após `dispose` lançam `StateError`.
- **Mapa ref → asset** (`lib/audio/domain/audio_assets.dart`): função pura `String audioAssetKeyFor(String ref)` → `assets/audio/$ref.wav`. É o contrato que a Story 1.3b satisfaz (arquivos `.wav` mono nesse diretório, um por `audioSampleRef` do catálogo v1).
- **`_JustAudioService`** (library-private em `audio/data/`; o único símbolo público do arquivo é `audioServiceProvider` `@riverpod`): detém um `AudioPlayer` do `just_audio`; `playSample` faz `stop → setAsset(audioAssetKeyFor(ref)) → play → stop`, embrulhando qualquer exceção do pacote em `SamplePlaybackFailed`. `audioServiceProvider` cria a instância e registra `ref.onDispose(service.dispose)`.
- **`FakeAudioService`** (`lib/audio/testing/fake_audio_service.dart`, público via `lib/audio/testing.dart`): implementa `AudioService`; expõe `List<String> playedRefs` (ordem), `int stopCount`, `bool disposed`; `playSample` honra `dispose` (→`StateError`) e um `Set<String> unplayableRefs` opcional (→`SamplePlaybackFailed`); `Duration playLatency` opcional (default `Duration.zero`) aguardado antes de completar. Zero dependência de `just_audio` ou de plataforma.
- **Gate AR-6** (`tool/check_module_boundaries.dart`): nova regra — qualquer `import`/`export` de `package:just_audio/…` ou `package:record/…` a partir de arquivo fora de `lib/audio/` é violação, nomeando arquivo + linha. Etapa `module boundaries` do `tool/ci.sh` sem mudança.
- `assets/audio/` registrado no `pubspec.yaml` (com um `.gitkeep`); os arquivos reais vêm na Story 1.3b.

**Ask First:**
- Expandir a interface com gravação/`evaluatePitch`/`Stream` (é a Story 3.2), ou com reprodução de sequência/fraseado (é lógica de apresentação das Stories 1.4+).
- Trocar `.wav` como formato/extensão das amostras, ou o diretório `assets/audio/`.
- Nova dependência, `custom_lint`, ou mover a checagem AR-6 para fora de `check_module_boundaries.dart`.
- Persistir volume/mudo ou qualquer configuração de áudio (é a Story 1.10).

**Never:**
- Sintetizar áudio em runtime, baixar áudio remoto, ou definir o fraseado/contexto musical de um exercício (Stories 1.4+/1.3b).
- Produzir, converter ou verificar a existência de arquivos de áudio reais (Story 1.3b).
- Renderizar tela, widget de player, ou consumir o `AudioService` em qualquer outro módulo nesta story.
- Gravação de microfone, permissões, `record`, biblioteca de pitch (Epic 3).
- Testar `_JustAudioService` contra `just_audio` real sob `flutter test` (precisa de plataforma; fica para integração pós-1.3b).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Reprodução ok (fake) | `playSample('sax_c4')` | `playedRefs` recebe `'sax_c4'`; completa após `playLatency` | N/A |
| Replay livre | `playSample('sax_c4')` 3× | `playedRefs == ['sax_c4','sax_c4','sax_c4']`; sem erro | N/A |
| `stop` ocioso | `stop()` sem reprodução ativa | `stopCount` incrementa; completa | N/A |
| Mapa de asset | `audioAssetKeyFor('sax_db4')` | `'assets/audio/sax_db4.wav'` | N/A |
| Amostra não reproduzível (real) | `setAsset`/`play` lança exceção do `just_audio` (asset ausente até 1.3b, arquivo corrompido) | `playSample` completa com `AudioError.samplePlaybackFailed(ref, …)` | erro de domínio (`implements Exception`), nunca `PlayerException`/`PlatformException` cru |
| Amostra não reproduzível (fake) | `ref` em `unplayableRefs` | idem: `SamplePlaybackFailed` nomeando o `ref` | idem |
| Uso após dispose | `dispose()` e depois `playSample`/`stop` | lança `StateError` | síncrono, antes de tocar plataforma |
| Provider descartado | `ProviderContainer.dispose()` | `AudioService.dispose()` chamado exatamente uma vez; `AudioPlayer` liberado | N/A |
| Override de teste | `audioServiceProvider.overrideWithValue(FakeAudioService())` | consumidores recebem o fake; nenhum acesso a `just_audio` | N/A |

</frozen-after-approval>

## Code Map

Estado atual:
- `lib/audio/audio.dart` -- barrel doc-comment-only (Story 1.1); reescrever
- `lib/audio/{data,domain,presentation}/.gitkeep` -- `data/` e `domain/` substituídos por código; `presentation/.gitkeep` fica
- `lib/curriculo/curriculo.dart` + `lib/curriculo/data/curriculo_repository_impl.dart` + `lib/curriculo/data/catalog_asset_bundle.dart` -- **padrão a espelhar**: barrel reexporta `domain/` + o provider; impl library-private com `@riverpod` como único símbolo público; seam de teste via override de provider
- `lib/curriculo/domain/curriculum_error.dart` -- padrão do `sealed class ... implements Exception` com `==`/`hashCode`/`toString` por subtipo
- `lib/core/database/database_provider.dart:33` -- padrão `ref.onDispose(...)` para recurso que precisa fechar
- `tool/check_module_boundaries.dart:1-19` + `:88-135` -- doc-comment (adicionar Regra 4), `_modules`/`_moduleOf`, laço de `directives`; a Regra 4 checa a `uri` crua **antes** de `_resolveTarget` (que devolve `null` para `package:` externo)
- `test/module_boundary_test.dart:11-24` -- helpers `write`/`run` temp-dir a reusar para os casos da Regra 4
- `tool/ci.sh:37` -- etapa `module boundaries`; sem mudança
- `pubspec.yaml:44-46` -- bloco `flutter: assets:`; adicionar `assets/audio/`
- `pubspec.lock` -- `just_audio` 0.10.6 já resolvido
- `_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/EXPERIENCE.md:68` -- frase "já baixado / sincroniza ao voltar a conexão" a reconciliar com "já embarcado no app" (retro action item #4)
- `_bmad-output/implementation-artifacts/deferred-work.md` -- entrada da 1.2 já registra os 14 tokens `sax_*` do `catalog_v1.json` como manifesto da 1.3b

Arquivos a criar:
- `lib/audio/domain/audio_service.dart` -- `abstract interface class AudioService` (`playSample`, `stop`, `dispose`) + `export 'audio_error.dart'`
- `lib/audio/domain/audio_error.dart` -- `sealed class AudioError implements Exception` + `SamplePlaybackFailed`
- `lib/audio/domain/audio_assets.dart` -- `audioAssetKeyFor(String ref)` puro
- `lib/audio/data/audio_service_impl.dart` -- `_JustAudioService` + `audioServiceProvider` (`@riverpod`)
- `lib/audio/testing/fake_audio_service.dart` -- `FakeAudioService`
- `lib/audio/testing.dart` -- barrel: reexporta `testing/fake_audio_service.dart`
- `assets/audio/.gitkeep` -- placeholder até a Story 1.3b
- `test/audio_service_test.dart` -- `FakeAudioService` (todos os cenários "fake" da matriz), `audioAssetKeyFor`, wiring do provider por override + `dispose` propagado no `ProviderContainer.dispose()`

Arquivos a modificar:
- `lib/audio/audio.dart` -- barrel: `export 'domain/...'` (service, error, assets) + `export 'data/audio_service_impl.dart' show audioServiceProvider`
- `tool/check_module_boundaries.dart` -- Regra 4 (`just_audio`/`record` só sob `lib/audio/`) + doc-comment
- `test/module_boundary_test.dart` -- casos bom/ruim da Regra 4
- `pubspec.yaml` -- registrar `assets/audio/`
- `EXPERIENCE.md:68` -- "já baixado" → "já embarcado no app"; remover "sincroniza ao voltar a conexão"; ajustar o `[ASSUMPTION]`
- `_bmad-output/implementation-artifacts/deferred-work.md` -- anexar entradas (ver Tasks)

## Tasks & Acceptance

**Execution:**
- [x] `lib/audio/domain/audio_error.dart` + `audio_service.dart` + `audio_assets.dart` -- interface, hierarquia de erro selada, mapa `ref`→asset puro
- [x] `lib/audio/data/audio_service_impl.dart` -- `_JustAudioService` (embrulha exceções do `just_audio` em `SamplePlaybackFailed`; `StateError` pós-dispose) + `audioServiceProvider` `@riverpod` com `ref.onDispose(service.dispose)`
- [x] `lib/audio/testing/fake_audio_service.dart` + `lib/audio/testing.dart` -- fake que registra chamadas e honra `unplayableRefs`/`playLatency`/`dispose`
- [x] `lib/audio/audio.dart` -- barrel: `domain/` + `audioServiceProvider`
- [x] `pubspec.yaml` + `assets/audio/.gitkeep` -- registrar o diretório de amostras
- [x] `tool/check_module_boundaries.dart` -- Regra 4: `just_audio`/`record` só sob `lib/audio/`; atualizar o doc-comment do arquivo
- [x] `test/audio_service_test.dart` -- cobertura do fake + `audioAssetKeyFor` + wiring/dispose do provider
- [x] `test/module_boundary_test.dart` -- caso bom (import dentro de `lib/audio/`) + caso ruim (import fora) da Regra 4
- [x] `_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/EXPERIENCE.md` -- reconciliar a linha 68 com "áudio embarcado no app, sem download remoto na v1"
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- anexar: (1) teste de integração do `_JustAudioService` real (pós-1.3b, precisa de plataforma + assets); (2) orquestração de fraseado/sequência de amostras (apresentação, Stories 1.4+); (3) expansão da interface para gravação/`evaluatePitch` (Story 3.2)

**Acceptance Criteria:**
- Given o módulo `audio`, when um consumidor importa `package:catear/audio/audio.dart`, then vê `AudioService`, `AudioError`/`SamplePlaybackFailed`, `audioAssetKeyFor` e `audioServiceProvider` — e **nada** de `data/` nem símbolo do `just_audio`.
- Given `audioServiceProvider` sem override, when lido num `ProviderContainer` que depois é descartado, then a instância é um `AudioService` e `dispose()` roda exatamente uma vez.
- Given um teste que faz `audioServiceProvider.overrideWithValue(FakeAudioService())`, when o código sob teste chama `playSample`/`stop`, then as chamadas ficam registradas no fake e nenhum código de plataforma de áudio executa.
- Given `dart run tool/check_module_boundaries.dart`, then exit 0 no repo atual; e exit ≠ 0 nomeando o arquivo quando qualquer lib fora de `lib/audio/` importa `package:just_audio/…` ou `package:record/…`.
- Given `flutter analyze`, then "No issues found!" — `_JustAudioService` não é público, o barrel expõe só `domain/` + o provider.
- Given `dart run tool/ci.sh`, then todas as etapas passam, incluindo `module boundaries` e `test`.
- Given `git status`, then `lib/audio/presentation/` segue só com `.gitkeep`.

## Design Notes

**Só reprodução nesta story:** AD-3 fixa o contrato completo de `AudioService` (reprodução + gravação + `evaluatePitch`), mas a Story 1.3 e `epic-1-context.md` escopam explicitamente só "reprodução por referência de asset". A interface fica mínima; a `sealed class AudioError` já nasce selada para os erros de gravação da Story 3.2 entrarem sem quebrar exaustividade. Expandir é Ask First.

**Seam de teste = override do provider, não injeção de `AudioPlayer`:** `AudioPlayer` do `just_audio` é classe concreta sem interface; fingi-la é inviável. A AC da story ("testes recebem o fake") já põe o seam no nível certo — `audioServiceProvider.overrideWithValue`. Consequência: `_JustAudioService` real não tem teste unitário (roda contra plataforma); é exercido ao rodar o app a partir da Story 1.4 e por um teste de integração pós-1.3b (registrado em `deferred-work.md`).

**`ref` é token opaco:** `playSample` recebe o mesmo token que aparece em `audioSampleRefs` do catálogo (`^[a-z0-9_]+$`, ex. `sax_c4`). `audioAssetKeyFor` é a única tradução token→bundle e vive no `domain/` porque é contrato com a Story 1.3b, não detalhe do `just_audio`. Formato `.wav` mono (cf. `audio-sourcing.md`); trocar é Ask First.

**Regra 4 do gate:** `_resolveTarget` devolve `null` para `package:` que não seja `package:catear/`, então a checagem de `just_audio`/`record` opera sobre a `uri` crua antes dessa resolução, comparando `_moduleOf(libRelative) == 'audio'`. Fecha AR-6 com o mesmo mecanismo da Regra 2 (Drift só em `core/`).

## Verification

**Commands:**
- `flutter pub get` -- resolve; `assets/audio/` registrado
- `dart run build_runner build --delete-conflicting-outputs` -- gera `audio_service_impl.g.dart`
- `dart format --output=none --set-exit-if-changed .` -- sem diffs
- `flutter analyze` -- "No issues found!"
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `flutter test` -- todos passam (novo `audio_service_test.dart` + casos da Regra 4)
- `dart run tool/ci.sh` -- exit 0

## Suggested Review Order

**Contrato do módulo (o design)**

- Ponto de entrada: a porta só-reprodução, `playSample`/`stop`/`dispose`, nada de gravação.
  [`audio_service.dart:12`](../../lib/audio/domain/audio_service.dart#L12)
- Superfície pública: o barrel expõe só `domain/` + o provider (`show`), nunca `data/` nem símbolo do `just_audio`.
  [`audio.dart:10`](../../lib/audio/audio.dart#L10)
- Erro selado que `implements Exception`; selado para os erros de gravação da Story 3.2.
  [`audio_error.dart:11`](../../lib/audio/domain/audio_error.dart#L11)
- Mapa `ref`→asset puro, com `assert` do formato `^[a-z0-9_]+$`; é o contrato da Story 1.3b.
  [`audio_assets.dart:14`](../../lib/audio/domain/audio_assets.dart#L14)

**Implementação real (atrás do provider)**

- `_JustAudioService` library-private; `playSample` faz `stop→setAsset→play→stop`.
  [`audio_service_impl.dart:28`](../../lib/audio/data/audio_service_impl.dart#L28)
- Tradução de erro: só `on Exception` vira `SamplePlaybackFailed` (bugs sobem); reset best-effort no erro.
  [`audio_service_impl.dart:35`](../../lib/audio/data/audio_service_impl.dart#L35)
- `audioServiceProvider` cria a instância e registra `ref.onDispose(service.dispose)`.
  [`audio_service_impl.dart:20`](../../lib/audio/data/audio_service_impl.dart#L20)

**Seam de teste**

- `FakeAudioService` público: registra chamadas, honra `unplayableRefs`/`playLatency`/`dispose`.
  [`fake_audio_service.dart:12`](../../lib/audio/testing/fake_audio_service.dart#L12)
- Barrel de teste separado — nunca importado por produção.
  [`testing.dart:7`](../../lib/audio/testing.dart#L7)

**Gate AR-6**

- Regra 4: nome do pacote `just_audio`/`record` ou prefixo `just_audio_`/`record_` fora de `lib/audio/` é violação.
  [`check_module_boundaries.dart:103`](../../tool/check_module_boundaries.dart#L103)

**Testes e conteúdo (periféricos)**

- Cobertura do fake, `audioAssetKeyFor`, contrato de valor de `SamplePlaybackFailed`, wiring do provider via spy.
  [`audio_service_test.dart:16`](../../test/audio_service_test.dart#L16)
- Regra 4: casos bom/ruim, pacote irmão, `import`/`export`.
  [`module_boundary_test.dart:84`](../../test/module_boundary_test.dart#L84)
- `assets/audio/` registrado (arquivos `.wav` reais vêm na Story 1.3b).
  [`pubspec.yaml:52`](../../pubspec.yaml#L52)
