---
title: 'Story 1.3b — Produção do conjunto de amostras de áudio da v1'
type: 'feature'
created: '2026-09-02'
status: 'done'
review_loop_iteration: 0
baseline_commit: '9bee71464eefc06cbfbd82a1cea9b496d9e57f7d'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-3-audioservice-com-reproducao-e-fakeaudioservice.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A Story 1.3 entregou o `AudioService` e o contrato `audioAssetKeyFor(ref) → assets/audio/$ref.wav`, mas `assets/audio/` só tem `.gitkeep`. Sem os arquivos reais nenhum exercício (Stories 1.4+) tem áudio, e o `_JustAudioService` real nunca foi exercido contra `just_audio` (F2/F7 do review da 1.3).

**Approach:** Converter as 14 notas de sax alto que o `catalog_v1.json` referencia (fonte: University of Iowa MIS, AltoSax NoVib ff) para `.wav` mono normalizado por loudness, commitá-las em `assets/audio/`, documentar proveniência/licença, e adicionar os dois testes que a 1.3 empurrou para cá: existência de arquivo por chave (`flutter test`) e integração do `_JustAudioService` real (`integration_test/`).

## Boundaries & Constraints

**Always:**
- **Manifesto fixo — exatamente estes 14 tokens** (união dos `audioSampleRefs` de `assets/curriculum/catalog_v1.json`): `sax_c4 sax_db4 sax_d4 sax_eb4 sax_e4 sax_f4 sax_gb4 sax_g4 sax_ab4 sax_a4 sax_bb4 sax_b4 sax_c5 sax_d5`. Um `assets/audio/<token>.wav` por token, nome idêntico ao token, nenhum arquivo a mais.
- **Uma nota real sustentada por arquivo** (~2,5 s). O contexto musical de FR-2/NFR-1 é montado pela apresentação nas Stories 1.4+ (sequência + transposição em runtime), não aqui. Nada sintetizado.
- **Fonte:** `~/Downloads/AltoSax.NoVib.ff.stereo/AltoSax.NoVib.ff.<Nota>.stereo.aif`. Pitch já verificado em concert pitch (`experiments/meow-sampler/verify_pitch.py`, 32/32 offset 0) — nada a transpor ou renomear.
- **Formato idêntico entre as 14:** WAV PCM 16-bit, **mono**, 44,1 kHz; loudness por **EBU R128** (`ffmpeg loudnorm`, alvo `I=-16 / TP=-1.5 / LRA=11`); cauda cortada para ≤ 2,5 s com fade-out curto; ataque preservado (sem time-stretch, sem cortar o início).
- **Proveniência:** `docs/audio/samples-v1.md` — URL da fonte, citação verbatim da licença Iowa MIS, detentor do copyright, tabela token → AIFF de origem, e a receita de conversão exata (reproduzível, um-off — **não** entra no CI).
- **Dois testes, ambos exigidos** (F7/F2 do review da 1.3):
  - `flutter test` (job `gates`): lê os `audioSampleRefs` do catálogo **real** via `curriculoRepositoryProvider.load()`; `rootBundle.load(audioAssetKeyFor(ref))` resolve para cada; e o conjunto de `.wav` em `assets/audio/` é exatamente os 14 tokens (sem órfãos).
  - `integration_test/` (job `e2e-android`): `audioServiceProvider` **sem override** (instância real); `playSample` de amostra válida completa; `playSample` de token bem-formado sem arquivo vira `SamplePlaybackFailed` — nunca `PlayerException`/`PlatformException` cru; `dispose` via `ProviderContainer.dispose()` não lança.

**Ask First:**
- Trocar fonte, formato/extensão, alvo de loudness, ou o diretório `assets/audio/`.
- Pré-renderizar frases/intervalos/acordes em vez de notas únicas.
- Nova dependência, ou tornar a geração de assets um passo de `tool/ci.sh`.
- Amostras além dos 14 tokens (vibrato, ou samples dos estágios `resolution` do Epic 3).

**Never:**
- Alterar `lib/audio/**`, `audioAssetKeyFor`, ou o schema do catálogo (contratos congelados na 1.3/1.2). **Exceção renegociada com o humano (2026-09-02):** `_JustAudioService.playSample` pode ser ajustado para traduzir também `FlutterError` (asset ausente vem do `rootBundle` como `Error`, não `Exception`) em `SamplePlaybackFailed` — é a lacuna AC-12 deferida da 1.3 e sem ela o requisito "nunca exceção crua" é inalcançável. Nenhuma outra mudança em `lib/` é permitida (interface, assinatura, barrel, `audioAssetKeyFor` seguem intocados).
- Redistribuir a coleção crua da Iowa (os AIFFs de origem não entram no repo).
- Síntese em runtime, download remoto, ou lógica de fraseado/sequência/contexto musical (Stories 1.4+).
- Gravação de microfone, `record`, `AudioSession` iOS, serialização de concorrência do `_JustAudioService` (Story 1.4).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cobertura do catálogo | os 14 `audioSampleRefs` reais | `rootBundle.load(audioAssetKeyFor(ref))` resolve para cada | teste falha nomeando o `ref` sem arquivo |
| Sem órfão | arquivos em `assets/audio/` vs. manifesto | conjunto de `.wav` == exatamente os 14 tokens | teste falha nomeando arquivo a mais |
| Reprodução real ok | `audioServiceProvider` real, `playSample('sax_c4')` no emulador | completa sem erro | N/A |
| Amostra ausente (real) | `playSample('sax_zz9')` (token válido, sem `.wav`) | completa com `SamplePlaybackFailed('sax_zz9', …)` | erro de domínio, nunca exceção crua do `just_audio` |
| Dispose real | `ProviderContainer.dispose()` após uso | `_JustAudioService.dispose()` roda uma vez, sem exceção | teardown best-effort |
| Formato consistente | `ffprobe` em cada `.wav` | `channels=1`, `sample_rate=44100`, `pcm_s16le`, `duration` ≤ 2,5 | inspeção / verificação no doc |

</frozen-after-approval>

## Code Map

- `assets/curriculum/catalog_v1.json` -- fonte de verdade dos 14 `audioSampleRefs` (`sax_*`); os testes leem via repositório, não parseando o JSON
- `assets/audio/.gitkeep` -- placeholder da 1.3; **remover** ao entrar os `.wav`
- `pubspec.yaml:52-56` -- `flutter: assets:` já lista o diretório `assets/audio/`; só atualizar o comentário (entrega concluída)
- `lib/audio/domain/audio_assets.dart:17` -- `audioAssetKeyFor(ref)` → `assets/audio/$ref.wav`; contrato a satisfazer — **não tocar**
- `lib/audio/data/audio_service_impl.dart:28-63` -- `_JustAudioService` library-private; `playSample` = `stop→setAsset→play→stop`, `on Exception` → `AudioError.samplePlaybackFailed`. Acessível só via `audioServiceProvider`; o integration test lê o provider sem override, não instancia a classe
- `lib/audio/domain/audio_error.dart:30` -- `SamplePlaybackFailed(ref, message)` com `==`/`hashCode`/`toString`
- `test/audio_service_test.dart:156-184` -- T-A11 já itera os 14 tokens e valida a **chave**; o novo teste valida o **arquivo**. Reusar o padrão `ProviderContainer` + `curriculoRepositoryProvider.load()` e a estrutura de imports/`group`
- `integration_test/app_shell_test.dart:1-45` -- padrão de `integration_test/`: `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, `ProviderContainer`/`ProviderScope`, `addTearDown`
- `dart_test.yaml:4` + `.github/workflows/ci.yaml:48-82` -- tag `e2e` e job `e2e-android` (`flutter test integration_test`) já existem; nada muda no workflow
- `experiments/meow-sampler/prep_instrument.py` / `verify_pitch.py` -- referência de conversão e a verificação de pitch já rodada; citar no doc, não versionar script novo
- `_bmad-output/implementation-artifacts/deferred-work.md` -- blocos F2 ("implementation of spec-1-3") e F7 ("TEA review de story 1.3") a marcar resolvidos; itens da Story 1.4 (concorrência, `AudioSession`) permanecem
- `_bmad-output/implementation-artifacts/audio-sourcing.md` -- "Balde 1" a marcar resolvido, apontando para `docs/audio/samples-v1.md`

## Tasks & Acceptance

**Execution:**
- [x] `assets/audio/*.wav` -- gerar e commitar as 14 amostras via a receita de `docs/audio/samples-v1.md` (loudnorm R128 → mono → trim ≤2,5 s → fade-out → PCM 16-bit 44,1 kHz); `git rm assets/audio/.gitkeep`
- [x] `docs/audio/samples-v1.md` -- criar: fonte + URL, licença Iowa MIS verbatim + copyright (University of Iowa EMS / Lawrence Fritts), tabela token→AIFF, nota da verificação de pitch, receita `ffmpeg` exata e parâmetros de normalização
- [x] `pubspec.yaml` -- atualizar o comentário do bloco `assets/audio/`; `flutter pub get`
- [x] `test/audio_assets_bundle_test.dart` -- criar: `rootBundle.load` de cada chave dos `audioSampleRefs` do catálogo real + assertiva de "sem órfão" (conjunto de arquivos == 14 tokens)
- [x] `integration_test/audio_service_test.dart` -- criar: `audioServiceProvider` real → `playSample` ok / ausente→`SamplePlaybackFailed` / `dispose` limpo
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- anexar nota de resolução de F2 e F7 (não apagar entradas)
- [x] `_bmad-output/implementation-artifacts/audio-sourcing.md` -- "Balde 1" resolvido → `docs/audio/samples-v1.md`

**Acceptance Criteria:**
- Given `flutter test`, then `test/audio_assets_bundle_test.dart` passa — todo `audioSampleRef` do catálogo v1 tem um `.wav` carregável e não há arquivo órfão em `assets/audio/`.
- Given `flutter test integration_test` num emulador Android, then `playSample` de amostra válida completa, amostra ausente vira `SamplePlaybackFailed` (nunca exceção crua), e `dispose` do provider não lança.
- Given `ffprobe` em qualquer `assets/audio/*.wav`, then `channels=1`, `sample_rate=44100`, `codec_name=pcm_s16le`, `duration` ≤ 2,5. Este critério passou a ser verificado automaticamente no job `gates`: `test/audio_assets_bundle_test.dart` faz `rootBundle.load` de cada chave e parseia o cabeçalho RIFF/WAVE — assere `audioFormat=1` (PCM), `numChannels=1`, `sampleRate=44100`, `bitsPerSample=16` e payload `data` ≤ 220500 bytes (≤ 2,5 s) e > 88200 bytes (guarda de truncamento).
- Given `docs/audio/samples-v1.md`, then cada um dos 14 tokens tem linha de proveniência e a licença Iowa MIS está citada verbatim com o detentor do copyright.
- Given `flutter analyze` e `dart run tool/ci.sh`, then "No issues found!" / exit 0.
- Given `git status`, then a única mudança em `lib/` é a tradução de `FlutterError` em `_JustAudioService.playSample` (renegociada, ver Never + Spec Change Log); `assets/audio/.gitkeep` removido.

## Spec Change Log

- **2026-09-02 — renegociação do bloco congelado (aprovada pelo humano).** O teste de integração F2 ("amostra ausente (real)") provou que `AudioPlayer.setAsset()` num asset não empacotado lança `FlutterError` (um `Error`, não `Exception`), que o `on Exception catch` de `_JustAudioService` deixava vazar cru — violando o requisito congelado "nunca `PlayerException`/`PlatformException` cru". O "Never: alterar `lib/audio/**`" foi renegociado para permitir só a tradução dessa exceção (9 linhas em `lib/audio/data/audio_service_impl.dart`: `import FlutterError`; `catch (e) { if (e is! Exception && e is! FlutterError) rethrow; … }`). É a lacuna AC-12 que a Story 1.3 explicitamente deferiu para cá. **KEEP:** o seam de teste continua sendo o provider real sem override (não instanciar a classe privada); erros de programação (`StateError`, `TypeError`) ainda sobem intocados.

## Design Notes

**Por que nota única e não frase:** o manifesto do catálogo é por nota (`sax_c4`), `epic-1-context.md` fixa "transposição em runtime sem multiplicar amostras", e a spec-1-3 (Never) põe fraseado nas Stories 1.4+. `playSample(ref)` é single-shot por design. As 14 notas cobrem C4–D5; intervalos acima de D5 são resolvidos pela apresentação transpondo, não por mais assets.

**Loudnorm R128 vs. peak:** a peak igual, notas agudas soam mais altas — ruim num exercício de comparação de timbre. `loudnorm` (uma passagem basta para material curto) iguala loudness percebido; `-16 LUFS` é padrão mobile.

**Receita (exemplo, uma nota):**
```
ffmpeg -i AltoSax.NoVib.ff.C4.stereo.aif \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=mono,atrim=end=2.5,afade=t=out:st=2.46:d=0.04" \
  -ar 44100 -c:a pcm_s16le assets/audio/sax_c4.wav
```
Ajustar `atrim/afade` se alguma fonte for < 2,5 s (não esticar).

**Integration test acessa o privado pelo provider:** `_JustAudioService` é library-private; o teste lê `audioServiceProvider` sem override e recebe a instância real. Fecha as lacunas P2 de AC-02 (wiring de `ref.onDispose`) e AC-12 (tradução de exceção real) da traceability da 1.3. `sax_zz9` casa `^[a-z0-9_]+$`, então `setAsset` de um asset não empacotado é o gatilho do erro — sem precisar commitar arquivo corrompido.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`. `ffmpeg`/`ffprobe` estão em `/usr/bin` (ok). Emulador Android para o `integration_test`: subir `emulator -avd pixel -no-snapshot -no-boot-anim -gpu swiftshader_indirect -no-window` como processo próprio em background (sem `-no-audio` — o teste exercita reprodução), esperar `adb shell getprop sys.boot_completed` = 1, então `flutter test integration_test -d emulator-5554` (1ª execução baixa NDK, ~5-7 min). O job `e2e-android` do CI é a validação canônica; se o emulador local não colaborar com áudio, registrar isso e confiar no CI.

**Commands:**
- `flutter pub get` -- resolve; `assets/audio/` com 14 `.wav`
- `for f in assets/audio/*.wav; do ffprobe -v error -show_entries stream=channels,sample_rate,codec_name,duration -of default=nw=1 "$f"; done` -- 14× `channels=1 / sample_rate=44100 / pcm_s16le / duration ≤ 2.5`
- `flutter analyze` -- "No issues found!"
- `flutter test` -- todos passam, incl. `test/audio_assets_bundle_test.dart`
- `flutter test integration_test -d <emulador>` -- `integration_test/audio_service_test.dart` passa
- `dart run tool/ci.sh` -- exit 0
- `git status` -- `lib/` limpo, `.gitkeep` removido, 14 `.wav` + doc adicionados

## Suggested Review Order

**Endurecimento do contrato de erro (`_JustAudioService`)**

- Ponto de entrada — as três guardas de `catch` agora idênticas: traduz `Exception`+`FlutterError`, faz rethrow de erro de programação.
  [`audio_service_impl.dart:45`](../../lib/audio/data/audio_service_impl.dart#L45)
- `stop()` best-effort: sem erro de domínio, engole `Exception`/`FlutterError` para não cruzar a fronteira do módulo.
  [`audio_service_impl.dart:77`](../../lib/audio/data/audio_service_impl.dart#L77)
- `dispose()` roda dentro de `ref.onDispose` — engole falha de teardown, só erro de programação sobe.
  [`audio_service_impl.dart:93`](../../lib/audio/data/audio_service_impl.dart#L93)

**Verificação real da implementação (F2, `integration_test/`)**

- `audioServiceProvider` sem override + subscription viva = instância real exercitada; tear-downs à prova de vazamento do `AudioPlayer`.
  [`audio_service_test.dart:33`](../../integration_test/audio_service_test.dart#L33)
- Token bem-formado sem asset → `SamplePlaybackFailed`, nunca exceção crua; `.timeout` para falhar rápido em vez de travar o CI.
  [`audio_service_test.dart:68`](../../integration_test/audio_service_test.dart#L68)

**Cobertura do catálogo + formato dos assets (F7, job `gates`)**

- Manifesto de 14 tokens do catálogo real == conjunto de `.wav`; `equals` pega troca de token com contagem intacta.
  [`audio_assets_bundle_test.dart:55`](../../test/audio_assets_bundle_test.dart#L55)
- Parse do cabeçalho RIFF/WAVE por chave: PCM / mono / 44,1 kHz / 16-bit / `data` ≤ 2,5 s — a AC do `ffprobe` agora vive no CI.
  [`audio_assets_bundle_test.dart:63`](../../test/audio_assets_bundle_test.dart#L63)
- Parser de cabeçalho WAV (chunk-walking) — suporte, sem dependência.
  [`audio_assets_bundle_test.dart:147`](../../test/audio_assets_bundle_test.dart#L147)

**Assets e proveniência (periféricos)**

- Proveniência: fonte, licença (só a frase verbatim confirmada + data/Wayback), tabela token→AIFF, receita, SHA-256.
  [`samples-v1.md:25`](../../docs/audio/samples-v1.md#L25)
- 14 `.wav` binários em `assets/audio/`; `.gitkeep` removido; `pubspec.yaml` comentário atualizado.
  [`pubspec.yaml:52`](../../pubspec.yaml#L52)
- `.gitattributes` novo — `*.wav`/`*.aif` como binário.
  [`.gitattributes:1`](../../.gitattributes#L1)
