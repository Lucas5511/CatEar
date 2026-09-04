---
title: 'Story 1.4b — Produção das tríades e expansão dos catálogos'
type: 'feature'
created: '2026-09-03'
status: 'draft'
review_loop_iteration: 0
baseline_commit: '1c30586a06a8f2364654cde44d483c34533ccda7'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-3b-producao-do-conjunto-de-amostras-de-audio-da-v1.md'
  - '{project-root}/_bmad-output/test-artifacts/atdd-preflight-1-5.md'
  - '{project-root}/_bmad-output/test-artifacts/session-c1-ouvir-o-app-2026-09-04.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A Story 1.5 pede exercícios de acorde e escala "no mesmo card e fluxo da 1.4", com o áudio "em contexto musical, não como bloco isolado". Três coisas impedem isso hoje, todas de conteúdo, nenhuma de código de apresentação:

1. **Acorde não pode soar como acorde.** `AudioService.playSample` promete, por contrato, interromper qualquer amostra ainda tocando, e o `_JustAudioService` tem um único `AudioPlayer` serializando mutações. As 14 amostras da v1 são notas isoladas. Simultaneidade é arquiteturalmente impossível — uma tríade só sairia arpejada.
2. **Não há distratores.** `chordCatalog` e `scaleCatalog` têm 2 entradas cada, contra 4 alternativas na tela. Um exercício de acorde renderizaria 2 botões — 50% de acerto por chute, contaminando qualquer sinal de habilidade que o Epic 2 construa sobre as tentativas.
3. **Não há taxonomia de erro para escala.** `errorTypes` cobre os 13 intervalos e as 4 qualidades de acorde. Para escala, nada — e a Story 1.6 exige `errorType` da taxonomia canônica, "nunca string livre".

**Approach:** Produzir 8 amostras de tríade pré-renderizadas (mixagem determinística das notas já commitadas, mesma fonte e licença), estender `chordCatalog` / `scaleCatalog` / `errorTypes`, adicionar os exercícios correspondentes ao catálogo, e estender o `ErrorType` para acomodar os erros de escala. Nenhuma linha de apresentação: a 1.5 consome, esta story produz — a mesma separação que a 1.3b manteve em relação à 1.4.

## Boundaries & Constraints

**Always:**

- **Manifesto de tríades — exatamente estes 8 tokens**, 4 qualidades × 2 raízes. Duas raízes, não uma: com raiz fixa o exercício vira reconhecimento de altura absoluta, e cada qualidade numa raiz só permite decorar o par altura↔qualidade.

  | token | qualidade | raiz | mixagem (notas já em `assets/audio/`) |
  |---|---|---|---|
  | `sax_maj_c4` | major | C4 | `sax_c4 + sax_e4 + sax_g4` |
  | `sax_min_c4` | minor | C4 | `sax_c4 + sax_eb4 + sax_g4` |
  | `sax_dim_c4` | diminished | C4 | `sax_c4 + sax_eb4 + sax_gb4` |
  | `sax_aug_c4` | augmented | C4 | `sax_c4 + sax_e4 + sax_ab4` |
  | `sax_maj_d4` | major | D4 | `sax_d4 + sax_gb4 + sax_a4` |
  | `sax_min_d4` | minor | D4 | `sax_d4 + sax_f4 + sax_a4` |
  | `sax_dim_d4` | diminished | D4 | `sax_d4 + sax_f4 + sax_ab4` |
  | `sax_aug_d4` | augmented | D4 | `sax_d4 + sax_gb4 + sax_bb4` |

- **Derivação, não sourcing.** As três vozes de cada tríade já estão em `assets/audio/`. Mixar com `ffmpeg amix`, mesma fonte (Iowa MIS, AltoSax NoVib ff), mesma licença já documentada. Nenhum AIFF novo entra no repo.
- **Formato idêntico às 14 existentes:** WAV PCM 16-bit, mono, 44,1 kHz, ≤ 2,5 s, com o mesmo alvo de loudness EBU R128 (`I=-16 / TP=-1.5 / LRA=11`) aplicado **depois** da mixagem — somar três vozes eleva o loudness, e uma tríade mais alta que uma nota isolada é um viés no exercício.
- **Alinhamento de ataque — todas as 22 amostras, não só as 8 novas.** Cada `.wav` começa com no máximo **20 ms** antes do ataque. Hoje as 14 existentes têm **180–320 ms** de ar morto (sessão C1, achado A-2), e o `PhrasePlayer` dispara notas a cada 450 ms: cada nota soa por 130–270 ms em vez de 450, e o spread de 140 ms entre amostras faz o ritmo do motif variar conforme quais notas o exercício sorteia. Cortar o silêncio inicial preservando o transiente (~10 ms de pré-ataque) é requisito desta story, e obriga a **rerenderizar as 14 existentes** junto das 8 novas.
- **Loudness verificado, não presumido.** As 14 atuais estão em **I = -19,0 LUFS** contra os `-16` que a spec-1-3b declarou como AC (achado A-3). A rerenderização acerta o alvo e o resultado é **medido** por amostra, não assumido a partir dos parâmetros do filtro.
- **`audioSampleRefs` de um exercício de acorde = `[<tríade>, <raiz>, <terça>, <quinta>]`** — o bloco primeiro, as três notas depois. A 1.5 monta o contexto musical (bloco → arpejo → bloco) sem asset novo; um consumidor que só leia o primeiro ref toca o bloco e degrada corretamente.
- **Expansão dos catálogos:**
  - `chordCatalog` += `diminished` (`intervals: [3, 6]`), `augmented` (`intervals: [4, 8]`) — ambos já existiam em `errorTypes` sem entrada correspondente.
  - `scaleCatalog` += `dorian` (`steps: [2,1,2,2,2,1,2]`), `mixolydian` (`steps: [2,2,1,2,2,1,2]`). Ambos somam 12. **Zero áudio novo** — escala é sequência de notas isoladas e os dois modos cabem nas 14 amostras.
  - `errorTypes` += `altered-third`, `altered-sixth`, `altered-seventh`.
- **Exercícios adicionados:** `s-acordes` vai de 2 para **8** (as 8 tríades do manifesto); `s-escalas` vai de 4 para **8** (dórica e mixolídia, `asc` e `desc`, sobre C4).
- **`ErrorType` estendido** em `lib/curriculo/domain/enums.dart` com `alteredThird('altered-third')`, `alteredSixth('altered-sixth')`, `alteredSeventh('altered-seventh')`. É mudança de `lib/`, declarada aqui de propósito: `ErrorType.fromJson` valida `errorTypes` contra a enum, então catálogo e enum sobem juntos ou o build gate reprova.
- **`test/audio_assets_bundle_test.dart` atualizado**: o manifesto congelado passa de 14 para 22 tokens (a assertiva de "sem órfão" é derivada do catálogo e se ajusta sozinha; a lista congelada, não) **e passa a olhar o conteúdo PCM, não só o cabeçalho RIFF**: onset ≤ 20 ms, pico com folga, e RMS dentro de uma faixa comum a todas as amostras. Hoje o teste lê `audioFormat`/`numChannels`/`sampleRate`/`bitsPerSample`/tamanho do `data` e nada mais — foi por isso que 320 ms de silêncio, 3 dB fora do alvo de loudness e ruído de sopro passaram em todos os critérios. Os bytes já estão carregados; falta olhá-los.
- **Proveniência:** `docs/audio/samples-v1.md` ganha uma seção de segunda derivação — a receita de mixagem exata, a tabela tríade → vozes, e a nota de que a licença é a mesma (derivado de material já derivado da mesma fonte).

**Ask First:**

- **Número de exercícios de acorde e escolha das raízes.** 4 qualidades × 2 raízes (C4, D4) é a recomendação da TEA: mantém `s-acordes` na faixa dos outros estágios (2–4 hoje, 8 aqui é o maior), cobre as 4 qualidades e quebra o atalho de altura absoluta. As 14 notas suportam **20** tríades (5 raízes: C4, Db4, D4, Eb4, E4) se a Curadoria quiser mais. Decisão de currículo, não de teste.
- **Dinâmica da fonte: manter `ff` ou trocar para `mf`.** A sessão C1 relatou chiado; a medição mostrou ruído de sopro banda-larga 33 dB abaixo do tom (> 8 kHz a -51,3 dBFS), típico de sax em *fortissimo*. Iowa MIS oferece **pp, mf e ff** — mesma fonte, mesma licença, mesma receita. **Decisão pendente do A/B** (`pw-play assets/audio/sax_c4.wav` no host vs. no app): se o chiado sumir fora do emulador, a causa é a cadeia de reprodução e nada muda. Se trocar, as 22 amostras vêm de uma fonte nova e o alinhamento de ataque sai na mesma passagem.
- **Nomes dos `errorTypes` de escala.** `altered-third` / `-sixth` / `-seventh` seguem o estilo kebab-inglês de `octave-error` / `far-miss` e nomeiam o grau alterado — que é a confusão real entre os 4 modos (maior×mixolídia = 7ª; dórica×menor = 6ª; dórica×mixolídia = 3ª; o resto é `far-miss`). Taxonomia é da Curadoria de Currículo.
- Trocar fonte, formato, alvo de loudness, ou o diretório `assets/audio/`.
- Tornar a mixagem um passo de `tool/ci.sh` (é one-off, como a conversão da 1.3b).
- Amostras além do manifesto (inversões, tétrades, vibrato, `resolution` do Epic 3).

**Never:**

- Tocar em `lib/exercicios/**`, `lib/audio/**`, ou qualquer coisa de apresentação. Esta story não renderiza nada. O seam type-agnostic (`IntervalPracticeState`, `intervalOptionsFor`, `_ActiveExerciseView`) é da 1.5 — ver o preflight do ATDD.
- Mudar `audioAssetKeyFor`, o contrato do `AudioService`, ou o `schemaVersion` do catálogo. A expansão é aditiva: nenhuma entrada existente muda de forma.
- Alterar as 14 amostras existentes, ou os exercícios de intervalo já no catálogo.
- Síntese em runtime, download remoto, multi-voz no `AudioService`. A simultaneidade é resolvida **no asset**, e é exatamente por isso que ela é resolvida aqui e não em código.
- Redistribuir a coleção crua da Iowa.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cobertura do catálogo | os 22 `audioSampleRefs` do catálogo | `rootBundle.load(audioAssetKeyFor(ref))` resolve para cada | teste falha nomeando o `ref` sem arquivo |
| Sem órfão | arquivos em `assets/audio/` vs. união dos refs | conjunto de `.wav` == exatamente os 22 tokens | teste falha nomeando o arquivo a mais |
| Formato da tríade | `ffprobe` / header RIFF de cada `sax_(maj\|min\|dim\|aug)_*.wav` | `pcm_s16le`, mono, 44,1 kHz, 16-bit, ≤ 2,5 s | mesma assertiva das 14 notas |
| Loudness da tríade | tríade vs. nota isolada | mesmo alvo R128; nenhuma tríade audivelmente mais alta | verificação no doc de proveniência |
| Acorde bem-formado | exercício `chord` do catálogo | `audioSampleRefs` = 4 entradas: tríade + 3 vozes | `check_curriculum` reprova cardinalidade errada |
| Catálogo × enum | `errorTypes` do JSON | todo token resolve em `ErrorType.fromJson` | `unknownValue` no build gate se a enum não subir junto |
| Invariantes de conteúdo | R1/R2/R3 após a expansão | inalteradas — só exercícios foram somados, nenhum `order` / `scaffoldIntensity` / `timbreScaffold` mudou | `check_curriculum` exit 0 |
| Pool de opções | `chordCatalog` / `scaleCatalog` | 4 entradas cada — 4 alternativas na tela da 1.5 | N/A (consumido pela 1.5) |
| Reprodução real | `playSample('sax_maj_c4')` no emulador | completa sem erro, soa como tríade simultânea | `SamplePlaybackFailed` se o asset faltar |
| Alinhamento de ataque | qualquer `assets/audio/*.wav` | primeira amostra PCM acima do limiar em ≤ 20 ms | teste falha nomeando o arquivo e o onset medido |
| Loudness por amostra | `ebur128` em cada `.wav` | `I` dentro de ±1 LU do alvo, igual entre notas e tríades | verificação registrada no doc de proveniência |
| Consistência de nível | RMS das 22 amostras | dentro de uma faixa comum; nenhuma destoa | teste falha nomeando a amostra fora da faixa |

</frozen-after-approval>

## Code Map

- `assets/audio/*.wav` -- 14 notas hoje; +8 tríades. `.gitattributes` já trata `*.wav` como binário
- `assets/curriculum/catalog_v1.json` -- `chordCatalog` (+2), `scaleCatalog` (+2), `errorTypes` (+3), `stages[s-acordes].exercises` (2→8), `stages[s-escalas].exercises` (4→8). Aditivo: nenhuma entrada existente muda
- `lib/curriculo/domain/enums.dart:60-93` -- `enum ErrorType`; adicionar 3 valores. **Única mudança em `lib/` desta story**
- `lib/curriculo/domain/curriculum_validation.dart:169-175` -- `_validateCatalog` já valida `chordCatalog.intervals` / `scaleCatalog.steps` como lista de int; nada a mudar. `_validateErrorTypes` chama `ErrorType.fromJson`, que é onde a enum e o JSON se encontram
- `lib/curriculo/domain/curriculum.dart:129-177` -- `ScaleExercise` / `ChordExercise` já existem e já leem `audioSampleRefs`; nada a mudar
- `test/audio_assets_bundle_test.dart:18,56` -- manifesto congelado de 14 → 22; o resto (header RIFF, órfãos) é derivado e se ajusta
- `test/curriculum_catalog_test.dart` -- cobertura do catálogo real; conferir se alguma assertiva conta entradas de catálogo ou exercícios
- `test/check_curriculum_test.dart` -- gate R1/R2/R3; a expansão não deve mexer nele
- `tool/check_curriculum.dart` -- build gate; roda no job `gates`, deve continuar exit 0
- `docs/audio/samples-v1.md` -- seção nova de segunda derivação (receita de mixagem + tabela tríade→vozes + nota de licença)
- `experiments/meow-sampler/prep_instrument.py` -- referência da conversão da 1.3b; a mixagem é one-off, não versionar script novo

## Tasks & Acceptance

**Execution:**

- [ ] `assets/audio/*.wav` -- **rerenderizar as 14 notas existentes** com corte do silêncio inicial (~10 ms de pré-ataque preservado) e o alvo de loudness medido depois
- [ ] `assets/audio/sax_{maj,min,dim,aug}_{c4,d4}.wav` -- gerar as 8 tríades pela receita de mixagem (amix das 3 vozes → loudnorm R128 → mono → corte de cabeça → trim ≤2,5 s → fade-out → PCM 16-bit 44,1 kHz)
- [ ] `test/audio_assets_bundle_test.dart` -- somar as assertivas de conteúdo PCM: onset ≤ 20 ms, pico com folga, RMS dentro da faixa comum
- [ ] `docs/audio/samples-v1.md` -- corrigir a URL da licença (a atual dá 404; a página migrou para `MIS-Pitches-2012/MISEbAltoSaxophone2012.html`) e registrar o loudness medido por amostra
- [ ] `assets/curriculum/catalog_v1.json` -- `chordCatalog` += diminished/augmented; `scaleCatalog` += dorian/mixolydian; `errorTypes` += altered-third/-sixth/-seventh; `s-acordes` 2→8 exercícios; `s-escalas` 4→8
- [ ] `lib/curriculo/domain/enums.dart` -- `ErrorType` += `alteredThird` / `alteredSixth` / `alteredSeventh`
- [ ] `test/audio_assets_bundle_test.dart` -- manifesto congelado 14 → 22 tokens
- [ ] `docs/audio/samples-v1.md` -- seção de segunda derivação: receita, tabela tríade→vozes, nota de licença
- [ ] `_bmad-output/implementation-artifacts/deferred-work.md` -- registrar que o item "cardinalidade de `audioSampleRefs` por tipo" ganhou um caso concreto (acorde = 4 refs), sem apagar a entrada
- [ ] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story 1.4b

**Acceptance Criteria:**

- Given qualquer `assets/audio/*.wav`, then o ataque começa em **≤ 20 ms** — verificado pelo teste, não por inspeção.
- Given `ebur128` em cada `assets/audio/*.wav`, then o loudness integrado medido está dentro de ±1 LU do alvo, e o valor por amostra está registrado em `docs/audio/samples-v1.md`.
- Given `flutter test`, then `test/audio_assets_bundle_test.dart` passa com 22 tokens — todo `audioSampleRef` do catálogo tem `.wav` carregável, nenhum órfão, e cada tríade satisfaz PCM/mono/44,1 kHz/16-bit/≤2,5 s como as notas.
- Given `dart run tool/check_curriculum.dart`, then exit 0 — R1/R2/R3 intactas e todo `errorTypes` resolve na enum.
- Given `chordCatalog` e `scaleCatalog`, then ambos têm **4** entradas, de modo que a 1.5 consiga montar 4 alternativas para os dois tipos.
- Given qualquer exercício `chord` do catálogo, then `audioSampleRefs` tem 4 entradas — a tríade seguida das 3 vozes, nessa ordem.
- Given `flutter test integration_test` num emulador, then `playSample` de cada token de tríade completa sem erro.
- Given ouvir `sax_maj_c4` e `sax_c4` em sequência, then não há salto de volume perceptível entre tríade e nota.
- Given `git status`, then a única mudança em `lib/` é a extensão do `ErrorType` — nada em `lib/exercicios/**` nem em `lib/audio/**`.
- Given `dart run tool/ci.sh`, then exit 0.

## Spec Change Log

- **2026-09-04 — ampliação do escopo após a sessão exploratória C1 (aprovada pelo humano).**
  A escuta do app (charter C1, `_bmad-output/test-artifacts/session-c1-ouvir-o-app-2026-09-04.md`)
  relatou chiado. A medição de follow-up não encontrou distorção nem ruído de
  gravação — os arquivos têm piso de ruído em -88 dBFS e zero amostras clipadas —
  mas encontrou **três outros problemas**, dois deles confirmados por medição:

  1. **A-2, confirmado:** toda amostra tem **180–320 ms de silêncio antes do
     ataque**, com spread de 140 ms entre elas. Contra os 450 ms de gap do
     `PhrasePlayer`, isso encurta cada nota para 130–270 ms e faz o ritmo do motif
     variar conforme as notas sorteadas. Causa raiz na regra da spec-1-3b
     *"ataque preservado (sem cortar o início)"*, que protegeu o transiente e
     manteve o ar morto junto.
  2. **A-3, confirmado:** loudness real em **-19,0 LUFS** contra os `-16` que a AC
     da 1.3b declarou. Passagem única de `loudnorm` errou ~3 dB e nada mediu depois.
  3. **A-1, pendente:** o chiado é provavelmente ruído de sopro do sax em `ff`
     (> 8 kHz a -51,3 dBFS, 33 dB abaixo do tom). Fica em **Ask First** até o A/B
     `pw-play` separar arquivo de cadeia de reprodução.

  **Efeito no escopo congelado:** a story deixa de produzir só 8 tríades e passa a
  **rerenderizar as 22 amostras**, porque o corte de cabeça e o alvo de loudness
  valem para as 14 existentes também. É a mesma passagem de `ffmpeg`, mas é
  escopo maior e está declarado aqui em vez de aparecer na implementação.

  **Por que aqui e não numa story nova:** esta é a única story do backlog que já
  ia tocar no pipeline de áudio e no `audio_assets_bundle_test.dart`. Abrir uma
  segunda story de produção sobre os mesmos arquivos criaria dois PRs mexendo no
  mesmo conjunto de assets — exatamente o padrão que a retro de 2026-09-03
  identificou como fonte de retrabalho.

## Design Notes

**Por que pré-renderizar e não arpejar.** `AudioService.playSample` documenta "interrupts any sample still playing", e a impl tem um `AudioPlayer` só — invariante que as PRs #13/#14 acabaram de estabilizar com `_chain` e a guarda de `PlayerInterruptedException`. Tocar três notas simultâneas exigiria múltiplos players e quebraria esse contrato num módulo que sangrou para ficar estável. Resolver no asset custa 8 arquivos e zero risco arquitetural.

**Por que o acorde carrega as 3 vozes além do bloco.** A AC2 da 1.5 pede contexto musical, não bloco isolado. Com `[tríade, raiz, terça, quinta]` a 1.5 pode tocar bloco → arpejo → bloco sem asset novo. Guardar só o bloco fecharia essa porta e forçaria uma segunda rodada de produção.

**Por que loudnorm depois da mixagem.** Somar três vozes correlacionadas sobe o loudness em vários LU. Normalizar cada voz antes e mixar depois deixaria toda tríade mais alta que toda nota — e num exercício de reconhecimento, volume é uma pista que não deveria existir.

**Por que a enum sobe junto com o JSON.** `_validateErrorTypes` chama `ErrorType.fromJson`, que lança `unknownValue` para token fora da enum. Catálogo com `altered-third` e enum sem ele reprova no `check_curriculum` — e o inverso (enum sem uso) é inofensivo mas inútil. São uma mudança só, e é por isso que esta story declara a exceção a "não tocar em `lib/`" no bloco congelado, em vez de descobri-la no meio da implementação como a 1.3b descobriu a tradução de `FlutterError`.

**Receita de mixagem (exemplo, uma tríade):**
```
ffmpeg -i assets/audio/sax_c4.wav -i assets/audio/sax_e4.wav -i assets/audio/sax_g4.wav \
  -filter_complex "[0:a][1:a][2:a]amix=inputs=3:duration=shortest:normalize=0[m]; \
    [m]loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=mono, \
    atrim=end=2.5,afade=t=out:st=2.46:d=0.04[o]" \
  -map "[o]" -ar 44100 -c:a pcm_s16le assets/audio/sax_maj_c4.wav
```
`normalize=0` é essencial: o padrão do `amix` divide por N e deixa a tríade mais baixa que as notas — o `loudnorm` seguinte corrige o nível, mas partir de um sinal atenuado desperdiça faixa dinâmica.

**Escala não vira asset.** Uma escala É uma sequência de notas isoladas; pré-renderizá-la seria transformar em asset o que a apresentação monta em runtime, contra o `epic-1-context.md` ("transposição em runtime sem multiplicar amostras"). Só o acorde precisa de asset, porque só ele é simultâneo.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`. `ffmpeg`/`ffprobe` em `/usr/bin`. Emulador: subir `emulator -avd pixel -no-snapshot -no-boot-anim -gpu swiftshader_indirect -no-window` como processo próprio, esperar `adb shell getprop sys.boot_completed` = 1, então `flutter test integration_test -d emulator-5554`.

**Commands:**
- `for f in assets/audio/sax_{maj,min,dim,aug}_{c4,d4}.wav; do ffprobe -v error -show_entries stream=channels,sample_rate,codec_name,duration -of default=nw=1 "$f"; done` -- 8× `channels=1 / 44100 / pcm_s16le / ≤ 2.5`
- `ffprobe -v error -f lavfi -i "amovie=assets/audio/sax_maj_c4.wav,ebur128=metadata=1" -show_entries frame=pkt_pts_time:frame_tags=lavfi.r128.I -of csv=p=0 | tail -1` -- loudness integrado próximo de -16 LUFS; comparar com `sax_c4.wav`
- `dart run tool/check_curriculum.dart` -- exit 0
- `flutter test` -- todos passam, incl. `audio_assets_bundle_test` com 22 tokens
- `flutter test integration_test -d <emulador>` -- passa
- `dart run tool/ci.sh` -- exit 0
- `git status` -- só `enums.dart` em `lib/`; 8 `.wav` + catálogo + doc + teste
