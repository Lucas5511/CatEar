---
title: 'Story 1.4b — Produção das tríades e expansão dos catálogos'
type: 'feature'
created: '2026-09-03'
status: 'done'
route: 'dispatch'
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
- **Expansão dos catálogos — entradas completas.** `_validateCatalog` exige `nameUi` em toda entrada e `inversion` em `chordCatalog`; entrada sem esses campos reprova o build.
  - `chordCatalog` += `{"id":"diminished","nameUi":"tríade diminuta","intervals":[3,6],"inversion":0}` e `{"id":"augmented","nameUi":"tríade aumentada","intervals":[4,8],"inversion":0}` — ambos já existiam em `errorTypes` sem entrada correspondente.
  - `scaleCatalog` += `{"id":"dorian","nameUi":"escala dórica","steps":[2,1,2,2,2,1,2]}` e `{"id":"mixolydian","nameUi":"escala mixolídia","steps":[2,2,1,2,2,1,2]}`. Ambos somam 12. **Zero áudio novo** — escala é sequência de notas isoladas e os dois modos cabem nas 14 amostras.
  - `errorTypes` += `terca-alterada`, `sexta-alterada`, `setima-alterada`.
- **Exercícios: `s-acordes` 2 → 8, `s-escalas` 4 → 8.** Os 2 exercícios `chord` existentes hoje têm **3** refs e são **reescritos** com o token da tríade na posição 0 (`[sax_maj_c4, sax_c4, sax_e4, sax_g4]` e `[sax_min_c4, sax_c4, sax_eb4, sax_g4]`); os 6 restantes são novos. `s-escalas` ganha dórica e mixolídia, `asc` e `desc`, sobre C4.
- **`ErrorType` estendido** em `lib/curriculo/domain/enums.dart` com `tercaAlterada('terca-alterada')`, `sextaAlterada('sexta-alterada')`, `setimaAlterada('setima-alterada')` — identificador Dart em lowerCamelCase espelhando o id, como os existentes fazem. É mudança de `lib/`, declarada aqui de propósito: `ErrorType.fromJson` valida `errorTypes` contra a enum, então catálogo e enum sobem juntos ou o build gate reprova.
- **`test/audio_assets_bundle_test.dart` atualizado**: o manifesto congelado passa de 14 para 22 tokens (a assertiva de "sem órfão" é derivada do catálogo e se ajusta sozinha; a lista congelada, não) **e passa a olhar o conteúdo PCM, não só o cabeçalho RIFF**, com limiares fixos — nada de "com folga" ou "faixa comum":
  - **onset ≤ 20 ms** — primeiro sample com `|x| ≥ -40 dBFS` (1% do fundo de escala), procurado nos primeiros 500 ms;
  - **pico ≤ -1,0 dBFS** — folga contra clipping na soma de vozes;
  - **RMS dentro de ±6 dB da mediana das 22** — guarda larga contra truncamento e silêncio, **não** casamento de nível: o nível percebido é governado pelo LUFS medido, e uma tríade densa tem crest factor diferente de uma nota isolada;
  - **guarda relacional:** maior onset das 22 ≤ **50 %** de `PhrasePlayer.flourishGap` (o menor dos dois gaps). Hoje o teste lê `audioFormat`/`numChannels`/`sampleRate`/`bitsPerSample`/tamanho do `data` e nada mais — foi por isso que 320 ms de silêncio, 3 dB fora do alvo de loudness e ruído de sopro passaram em todos os critérios. Os bytes já estão carregados; falta olhá-los.
- **Proveniência:** `docs/audio/samples-v1.md` ganha uma seção de segunda derivação — a receita de mixagem exata, a tabela tríade → vozes, e a nota de que a licença é a mesma (derivado de material já derivado da mesma fonte).

**Ask First:**

- Trocar fonte, formato, alvo de loudness, ou o diretório `assets/audio/`.
- Tornar a mixagem um passo de `tool/ci.sh` (é one-off, como a conversão da 1.3b).
- Amostras além do manifesto (inversões, tétrades, vibrato, `resolution` do Epic 3).

**Never:**

- Tocar em `lib/exercicios/**`, `lib/audio/**`, ou qualquer coisa de apresentação. Esta story não renderiza nada. O seam type-agnostic (`IntervalPracticeState`, `intervalOptionsFor`, `_ActiveExerciseView`) é da 1.5 — ver o preflight do ATDD.
- Mudar `audioAssetKeyFor`, o contrato do `AudioService`, ou o `schemaVersion` do catálogo. A expansão é aditiva **exceto** pelos 2 exercícios `chord` existentes, que ganham o ref do bloco na posição 0 (ver Always); nenhuma outra entrada muda de forma.
- Trocar a fonte, o pitch, a duração-alvo ou o *token* das 14 amostras — a rerenderização exigida por A-2/A-3 é permitida e obrigatória, o conteúdo musical é que não muda. Alterar os exercícios de **intervalo** já no catálogo.
- Síntese em runtime, download remoto, multi-voz no `AudioService`. A simultaneidade é resolvida **no asset**, e é exatamente por isso que ela é resolvida aqui e não em código.
- Redistribuir a coleção crua da Iowa.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cobertura do catálogo | os 22 `audioSampleRefs` do catálogo | `rootBundle.load(audioAssetKeyFor(ref))` resolve para cada | teste falha nomeando o `ref` sem arquivo |
| Sem órfão | arquivos em `assets/audio/` vs. união dos refs | conjunto de `.wav` == exatamente os 22 tokens | teste falha nomeando o arquivo a mais |
| Formato da tríade | `ffprobe` / header RIFF de cada `sax_(maj\|min\|dim\|aug)_*.wav` | `pcm_s16le`, mono, 44,1 kHz, 16-bit, ≤ 2,5 s | mesma assertiva das 14 notas |
| Loudness da tríade | tríade vs. nota isolada | mesmo alvo R128; nenhuma tríade audivelmente mais alta | verificação no doc de proveniência |
| Acorde bem-formado | exercício `chord` do catálogo | `audioSampleRefs` = 4 entradas: `refs[0]` = token de tríade, `refs[1..3]` = exatamente as 3 vozes que o manifesto declara para esse token | teste novo em `audio_assets_bundle_test.dart` — **nenhum gate cobre cardinalidade hoje** (item deferido, `deferred-work.md:55`) |
| Alinhamento das vozes | cada tríade vs. suas 3 vozes | as 3 entram juntas: onset da tríade ≤ 20 ms como qualquer amostra | mixar de notas não realinhadas produziria arpejo — por isso a tarefa 2 depende da 1 |
| Catálogo × enum | `errorTypes` do JSON | todo token resolve em `ErrorType.fromJson` | `unknownValue` no build gate se a enum não subir junto |
| Invariantes de conteúdo | R1/R2/R3 após a expansão | inalteradas — só exercícios foram somados, nenhum `order` / `scaffoldIntensity` / `timbreScaffold` mudou | `check_curriculum` exit 0 |
| Pool de opções | `chordCatalog` / `scaleCatalog` | 4 entradas cada — 4 alternativas na tela da 1.5 | N/A (consumido pela 1.5) |
| Reprodução real | `playSample('sax_maj_c4')` no emulador | completa sem erro, soa como tríade simultânea | `SamplePlaybackFailed` se o asset faltar |
| Alinhamento de ataque | qualquer `assets/audio/*.wav` | primeira amostra PCM acima do limiar em ≤ 20 ms | teste falha nomeando o arquivo e o onset medido |
| Loudness por amostra | `ebur128` em cada `.wav` | `I` dentro de ±1 LU do alvo, igual entre notas e tríades | verificação registrada no doc de proveniência |
| Consistência de nível | RMS das 22 amostras | dentro de ±6 dB da mediana — sanidade, não casamento de nível | teste falha nomeando a amostra fora da faixa |

</frozen-after-approval>

## Code Map

**A mudar:**

- `assets/audio/*.wav` -- as 14 notas são **rerenderizadas** (corte de cabeça + loudness) e 8 tríades entram. `.gitattributes` já trata `*.wav` como binário
- `assets/curriculum/catalog_v1.json` -- `chordCatalog` (+2), `scaleCatalog` (+2), `errorTypes` (+3), `s-acordes` 2→8 exercícios (os 2 existentes **reescritos** com o ref do bloco), `s-escalas` 4→8
- `lib/curriculo/domain/enums.dart:60-93` -- `enum ErrorType`; +3 valores. **Única mudança em `lib/`**
- `test/curriculum_catalog_test.dart:117-118` -- **congela os conjuntos exatos** `expect(chords, {'major','minor'})` e `expect(scales, {'major','natural_minor'})`. Vai vermelho com a expansão; estender para os 4 de cada. A linha ~122 ainda exige que nenhuma entrada de catálogo fique sem referência — as 4 novas precisam aparecer em exercícios (e aparecem)
- `test/audio_assets_bundle_test.dart` -- manifesto congelado 14 → 22 tokens (linha 23); o docstring (linha 18) e o nome do teste (linha 56) ainda dizem "14"; somar as assertivas de conteúdo PCM e a guarda relacional. Órfãos e header RIFF são derivados e se ajustam sozinhos
- `integration_test/catear_e2e_test.dart` -- o grupo de contrato toca `sax_c4`/`sax_g4`; somar cobertura dos 8 tokens de tríade
- `docs/audio/samples-v1.md` -- seção de segunda derivação, tabela SHA-256 (14 → 22 linhas), bloco de duração/RMS esperados, prosa "os 14 arquivos" → 22, e as URLs da licença
- `pubspec.yaml:63` -- comentário diz "14 mono .wav notes"
- `_bmad-output/implementation-artifacts/deferred-work.md:55` -- o item de cardinalidade registra "tríade=3"; **corrigir para 4** (bloco + 3 vozes), não só anexar caso
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- registrar a story

**Verificado, nada a mudar:**

- `lib/curriculo/domain/curriculum_validation.dart:160-178` -- `_validateCatalog` exige `nameUi` em toda entrada e `inversion` em `chordCatalog`; as entradas novas da spec já vêm completas. `_validateErrorTypes` compara o JSON com `ErrorType.values` **inteiro**: enum sem entrada no JSON também reprova
- `lib/curriculo/domain/curriculum.dart:129-177` -- `ScaleExercise` / `ChordExercise` já existem e já leem `audioSampleRefs`
- `test/curriculum_catalog_test.dart:58` -- `stages.length == 10`: só somamos exercícios a estágios existentes
- `test/curriculum_catalog_test.dart:180` -- `audioSampleRefs` só precisa ser não-vazio e casar `^[a-z0-9_]+$`; sem cardinalidade, então 4 refs passa e `sax_maj_c4` casa
- `test/exercicios/interval_practice_test.dart:21,56` -- 23 e 13 são do loop de **intervalo**, que `intervalLoop` filtra por `IntervalExercise`
- `test/curriculum_validation_test.dart:107-121` -- grupo "errorTypes sync" já guarda o acoplamento JSON↔enum nos dois sentidos
- `lib/exercicios/presentation/phrase_player.dart:26-30` -- `noteGap` (450 ms) e `flourishGap` (170 ms) são campos de instância com default, não `static const`. A guarda relacional constrói um `PhrasePlayer(FakeAudioService())` para ler os defaults e importa `presentation/phrase_player.dart` **direto** — o barrel documenta esse padrão ("tests that need them import the file directly"), então não é violação do Never
- `experiments/meow-sampler/prep_instrument.py` -- referência da conversão da 1.3b; a mixagem é one-off, não versionar script novo

## Tasks & Acceptance

**Execution** (em ordem de dependência — a 2 consome a saída da 1):

- [x] **1. `assets/audio/<as 14 notas>.wav`** -- rerenderizar a partir dos AIFFs de origem (ver §Verification → Ambiente). Ordem dos filtros: estéreo→mono → `atrim` de cabeça deixando ~10 ms de pré-ataque → `asetpts=PTS-STARTPTS` → **`loudnorm` em duas passagens medidas** → `atrim=end=2.5` → `afade=t=out` com `st` calculado da duração real → PCM 16-bit 44,1 kHz
- [x] **2. `assets/audio/sax_{maj,min,dim,aug}_{c4,d4}.wav`** -- gerar as 8 tríades **a partir das notas já rerenderizadas na tarefa 1** (mixar as originais desalinhadas produziria arpejo, não acorde):
  ```
  ffmpeg -i sax_c4.wav -i sax_e4.wav -i sax_g4.wav \
    -filter_complex "[0:a][1:a][2:a]amix=inputs=3:duration=shortest:normalize=0[m]; \
      [m]atrim=start=<onset-0.010>,asetpts=PTS-STARTPTS[t]" \
    -map "[t]" -ar 44100 -c:a pcm_s16le /tmp/triade_raw.wav
  # depois: loudnorm two-pass (mede, aplica) -> atrim=end=2.5 -> afade calculado -> sax_maj_c4.wav
  ```
  `normalize=0` é obrigatório: o default do `amix` divide por N e entrega a tríade mais baixa que as notas
- [x] **3. `assets/curriculum/catalog_v1.json`** -- as 4 entradas de catálogo completas, os 3 `errorTypes`, `s-acordes` 2→8 (os 2 existentes reescritos com o ref do bloco), `s-escalas` 4→8
- [x] **4. `lib/curriculo/domain/enums.dart`** -- `ErrorType` += `tercaAlterada` / `sextaAlterada` / `setimaAlterada`. **Sobe no mesmo commit que a tarefa 3** — qualquer um dos dois sozinho reprova o `check_curriculum`
- [x] **5. `test/curriculum_catalog_test.dart`** -- estender os conjuntos congelados (linhas 117-118) para `{major,minor,diminished,augmented}` e `{major,natural_minor,dorian,mixolydian}`
- [x] **6. `test/audio_assets_bundle_test.dart`** -- manifesto 14→22; docstring e nome do teste; assertivas de conteúdo PCM (onset, pico, RMS); pareamento tríade↔vozes; contagens `s-acordes`==8 e `s-escalas`==8; guarda relacional contra `flourishGap`/`noteGap`
- [x] **7. `integration_test/catear_e2e_test.dart`** -- laço de `playSample` sobre os 8 tokens de tríade sob `_playTimeout`
- [x] **8. `docs/audio/samples-v1.md`** -- seção de segunda derivação (receita + tabela tríade→vozes + licença); regenerar a tabela SHA-256 para 22; atualizar duração/RMS esperados; "14 arquivos" → 22; **reverificar o texto da licença na página nova** (`MIS-Pitches-2012/MISEbAltoSaxophone2012.html`), atualizar a citação verbatim, a data de acesso e o link do Web Archive, substituindo as 3 URLs nomeadamente
- [x] **9. `pubspec.yaml`** -- comentário "14 mono .wav notes" → 22
- [x] **10. `deferred-work.md`** -- corrigir "tríade=3" para "acorde = 4 refs (bloco + 3 vozes)"
- [x] **11. `sprint-status.yaml`** -- a chave `1-4b-produção-das-tríades-e-expansão-dos-catálogos` já existe como `ready-for-dev`; mover para `in-progress` ao começar e `review` ao abrir o PR

**Acceptance Criteria:**

- Given qualquer `assets/audio/*.wav`, when o teste mede o onset, then ele é ≤ 20 ms — primeiro sample com `|x| ≥ -40 dBFS` nos primeiros 500 ms.
- Given o maior onset entre as 22, then ele é ≤ 50 % de `PhrasePlayer.flourishGap` — nenhuma nota do motif ou do flourish é interrompida antes do próprio ataque.
- Given `ebur128` em cada uma das 22, then `I` está dentro de ±1 LU de -16 LUFS, e a tabela por amostra está em `docs/audio/samples-v1.md`.
- Given o header RIFF de cada `.wav`, then PCM / mono / 44,1 kHz / 16-bit / ≤ 2,5 s, pico ≤ -1,0 dBFS e RMS dentro de ±6 dB da mediana das 22.
- Given qualquer exercício `chord`, then `refs[0]` é o token de tríade e `refs[1..3]` são exatamente as 3 vozes que o manifesto declara para ele; os 8 tokens aparecem uma vez cada; `s-acordes` tem 8 exercícios e `s-escalas` tem 8.
- Given `chordCatalog` e `scaleCatalog`, then ambos têm 4 entradas — a 1.5 monta 4 alternativas para os dois tipos.
- Given os comandos de §Verification, then todos saem com exit 0, e o `git status` mostra `enums.dart` como **única** mudança em `lib/`.

**Verificação humana (não bloqueia o agente):**

- Ouvir o motif e o flourish em aparelho físico: as três notas do flourish soam, o motif tem ritmo estável entre exercícios, e não há salto de volume entre tríade e nota. É o charter C1 refeito sobre os assets corrigidos.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`. `ffmpeg`/`ffprobe` em `/usr/bin`. **Fonte da rerenderização:** `~/Downloads/AltoSax.NoVib.ff.stereo/AltoSax.NoVib.ff.<Nota>.stereo.aif` — diretório local, fora do repo e sem checksum. Se ele não existir, **HALT e pergunte**: rerenderizar a partir dos `.wav` de 16-bit já normalizados acumularia perda e está proibido. Rollback: `git checkout -- assets/audio/`. Emulador: subir `emulator -avd pixel -no-snapshot -no-boot-anim -gpu swiftshader_indirect -no-window` como processo próprio, esperar `adb shell getprop sys.boot_completed` = 1, então `flutter test integration_test -d emulator-5554`.

**Commands:**
- `for f in assets/audio/*.wav; do ffprobe -v error -show_entries stream=channels,sample_rate,codec_name,duration -of default=nw=1 "$f"; done` -- 22× `channels=1 / 44100 / pcm_s16le / ≤ 2.5`
- Tabela por amostra (`arquivo, I, TP, RMS`) para colar no doc de proveniência:
  `for f in assets/audio/*.wav; do i=$(ffmpeg -hide_banner -i "$f" -af ebur128 -f null - 2>&1 | grep -E "^ +I:" | tail -1); echo "$(basename $f) $i"; done`
- `dart run tool/check_curriculum.dart` -- exit 0
- `flutter test` -- todos passam, incl. `audio_assets_bundle_test` com 22 tokens e `curriculum_catalog_test` com os conjuntos estendidos
- `flutter test integration_test -d <emulador>` -- passa, incl. os 8 tokens de tríade
- `bash tool/ci.sh` -- exit 0
- `git status` -- só `enums.dart` em `lib/`; 22 `.wav`, catálogo, 3 testes, doc, pubspec, deferred-work, sprint-status

## Spec Change Log

- **2026-09-04 — correções do `bmad-review` (3 lentes: adversarial, edge-case, structure).**
  A revisão achou 19 + 18 + 12 findings, com sobreposição forte em quatro itens
  que eu havia afirmado errado. Todos verificados contra o repositório antes de
  aceitar. Mudanças no bloco congelado, com aprovação do humano:
  1. **Contradição resolvida.** "Never: alterar as 14 amostras existentes"
     contradizia "Always: obriga a rerenderizar as 14". O Never passou a proibir
     o que de fato continua proibido — trocar fonte, pitch, duração-alvo ou token.
  2. **"A expansão é aditiva" era falso.** Os 2 exercícios `chord` existentes têm
     3 refs e são **reescritos** com o token do bloco na posição 0.
  3. **Entradas de catálogo estavam incompletas.** `_validateCatalog` exige
     `nameUi` em toda entrada e `inversion` em `chordCatalog`; as 4 novas agora
     vêm escritas por extenso, com `nameUi` decidido pelo humano (tríade
     diminuta / aumentada, escala dórica / mixolídia).
  4. **Limiares dos testes eram placeholders.** "pico com folga", "faixa comum",
     "com margem" viraram números: onset ≤ 20 ms a -40 dBFS, pico ≤ -1,0 dBFS,
     RMS ±6 dB da mediana, guarda relacional ≤ 50 % de `flourishGap`. **KEEP:**
     o RMS é sanidade larga, não casamento de nível — o gate de percepção é o
     LUFS medido; exigir os dois como casamento seria insatisfazível, porque uma
     tríade densa tem crest factor diferente de uma nota isolada.
  5. **A matriz afirmava um gate inexistente** ("`check_curriculum` reprova
     cardinalidade"); nenhuma cardinalidade é validada hoje — é item deferido.

  Fora do bloco congelado: `test/curriculum_catalog_test.dart:117-118` congela
  `{major,minor}` / `{major,natural_minor}` e vai vermelho com a expansão — meu
  Code Map afirmava "não quebram (verificado)", conferindo as linhas erradas.
  A receita repetia o `loudnorm` de passagem única que **causou** o A-3, não
  tinha passo de corte de cabeça, e o `afade` fixo em 2.46 s cairia fora do
  arquivo depois do trim. A tarefa das tríades não declarava depender das notas
  já realinhadas — mixá-las como estão produziria arpejo, o defeito que a story
  existe para evitar. `dart run tool/ci.sh` é inválido (`ci.sh` é bash).
  A Design Note dizia que enum sem entrada no JSON é "inofensivo": é reprovação.
  Seções reordenadas para §Verification ficar junto das tarefas, e a receita saiu
  das Design Notes para dentro da tarefa que a executa.


- **2026-09-04 — decisões do checkpoint de planejamento (respondidas pelo humano).**
  As duas entradas de `Ask First` que eram intent gaps foram resolvidas e saíram
  do bloco:
  1. **Exercícios de acorde: 8 (4 qualidades × 2 raízes, C4 e D4)** — como
     recomendado. Mantém `s-acordes` na faixa dos outros estágios e quebra o
     atalho de altura absoluta. As 14 notas suportariam 20 tríades em 5 raízes;
     fica registrado para a Story 1.8 (variação anti-decoreba), não acionado aqui.
  2. **`errorTypes` de escala em português: `terca-alterada`, `sexta-alterada`,
     `setima-alterada`** — contra a proposta original em inglês. O produto é
     pt-BR; os 19 ids existentes são notação musical (`M3`, `TT`) ou kebab-inglês
     (`octave-error`, `far-miss`), então a taxonomia fica mista por ora. **KEEP:**
     nomear pelo grau alterado, não pelo modo confundido — três entradas cobrem
     qualquer par de modos, inclusive os que a 1.8 adicionar.

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
  3. **A-1, descartado em 2026-09-04:** o chiado não está no arquivo. O A/B
     `pw-play` direto no host reproduziu sem chiado e com ótima qualidade — a
     causa é a cadeia de reprodução do emulador. A dinâmica `ff` fica, e a
     entrada correspondente saiu de `Ask First`. Evitou rerenderizar 22 amostras
     e trocar a fonte por um defeito que não existia nos assets.

  **Efeito no escopo congelado:** a story deixa de produzir só 8 tríades e passa a
  **rerenderizar as 22 amostras**, porque o corte de cabeça e o alvo de loudness
  valem para as 14 existentes também. É a mesma passagem de `ffmpeg`, mas é
  escopo maior e está declarado aqui em vez de aparecer na implementação.

  **Por que aqui e não numa story nova:** esta é a única story do backlog que já
  ia tocar no pipeline de áudio e no `audio_assets_bundle_test.dart`. Abrir uma
  segunda story de produção sobre os mesmos arquivos criaria dois PRs mexendo no
  mesmo conjunto de assets — exatamente o padrão que a retro de 2026-09-03
  identificou como fonte de retrabalho.

## Implementation Notes

**Rodada de implementação — 2026-09-04.** Tarefas 1–10 concluídas; a 11 está em
`in-progress` e vira `review` na abertura do PR.

**Produção dos assets (tarefas 1–2).** Script one-off em `python3` + `ffmpeg`
8.0.1, não versionado (mesma razão da 1.3b). Os AIFFs de origem estavam onde a
spec previa — nenhum HALT foi necessário. Resultado das 22, medido no arquivo
entregue:

- **onset ≤ 8,3 ms** (orçamento 20 ms; guarda relacional: 50 % de
  `flourishGap` = 85 ms);
- **`I` = -16,0 LUFS em todas as 22** (±1 LU do alvo);
- **pico entre -10,4 e -3,9 dBFS** (teto -1,0);
- **RMS: mediana -15,85 dBFS, desvio máximo -1,69 dB** (`sax_d5`; faixa ±6 dB);
- duração 2,500 s exatos, `data` = 220500 bytes — no limite superior do cap, por
  construção.

Tabela completa por amostra em `docs/audio/samples-v1.md` §Verificação da saída.

**Desvio da ordem de filtros declarada na tarefa 1.** A spec listava
`… → loudnorm → atrim=end=2.5 → afade`. A implementação faz
`atrim de cabeça → atrim=end=<dur> → loudnorm (2 passagens) → atrim=end=<dur> +
afade → pcm_s16le`. Duas razões, ambas de correção:

1. **medir o que é entregue.** Com o corte de cauda depois do `loudnorm`, o `I`
   medido é o de um sinal 0,3–1,0 s mais longo que o arquivo final — a mesma
   classe de erro que produziu o A-3. Cortando antes, o valor medido é o do
   arquivo entregue, e por isso as 22 batem -16,0 exatos.
2. **contagem de amostras exata.** O `loudnorm` reamostra internamente para
   192 kHz; sair dele direto para 16-bit devolvia comprimentos com ±1–2
   amostras de folga, e 2,5 s **é** o teto de `maxDataBytes` (220500 B) no
   `audio_assets_bundle_test`. O recorte final garante 110250 quadros.
   O `afade` continua sendo o último filtro, com `st` calculado da duração real,
   como a spec exige.

Intermediários todos em `pcm_f32le` — nenhuma etapa passa por 16-bit antes da
saída. As tríades são mixadas dos `.wav` de 16-bit já commitados (é o que a
tarefa 2 manda: "a partir das notas já rerenderizadas na tarefa 1"), com
`normalize=0`, em float, e só então normalizadas.

**Onset final menor que os 10 ms de pré-ataque.** Esperado: o ganho do
`loudnorm` (+3 a +4 dB) empurra acima do limiar de -40 dBFS amostras do sopro
que antes ficavam abaixo dele. Registrado no doc de proveniência.

**Um arquivo de teste fora do Code Map: `test/curriculum_validation_test.dart`.**
O grupo "orphan exercise id in each *Catalog" usava `'dorian'` como id
deliberadamente inexistente no `scaleCatalog` (linha ~338). Com a expansão,
`dorian` passou a existir e o teste ficou vermelho por construção. Trocado por
`'phrygian'`, com comentário explicando por quê. É consequência direta da
expansão de catálogo, não escopo novo — o Code Map só havia conferido o grupo
"errorTypes sync" desse arquivo.

**Licença reverificada (tarefa 8).** `MISsaxophone.html` confirmado **404**;
a página do instrumento vive em
`MIS-Pitches-2012/MISEbAltoSaxophone2012.html` (HTTP 200, lista os
`AltoSax.NoVib.ff.*.stereo.aif`), e o texto da licença está em `MIS.html`
(HTTP 200). A citação verbatim foi **ampliada**: a atribuição a Lawrence Fritts,
antes parafraseada, agora é citada palavra por palavra. Links do Web Archive
trocados de wildcard para snapshots datados
(`20260619045647` para `MIS.html`, `20260129163013` para a página do
instrumento).

**Cobertura de teste somada.** `audio_assets_bundle_test.dart` foi de 3 para 11
testes: manifesto de 22, header RIFF, onset ≤ 20 ms, pico ≤ -1,0 dBFS, RMS ±6 dB
da mediana, guarda relacional contra `PhrasePlayer`, sem órfãos, forma
`[tríade, raiz, terça, quinta]` (com pareamento token↔vozes e token↔`chordQuality`),
e as contagens `s-acordes`/`s-escalas` = 8. `catear_e2e_test.dart` ganhou um laço
de `playSample` sobre os 8 tokens de tríade contra o serviço real.

**Rodada de review (2026-09-04).** O gate que faltava era o principal: nada
verificava que um `.wav` contém o *pitch* que o token nomeia — todas as
assertivas eram agnósticas de altura, e o grupo e2e só assere "não lançou" (o
emulador do CI roda `-noaudio`). Somados dois testes e um âncora:

- **`every sample carries the pitches its token names`** — Goertzel (sem FFT,
  sobre os frames que `measure()` já decodifica) contra uma tabela congelada
  token→Hz, em **duas janelas de 100 ms** (onset+30 ms e 1,30 s; janelas longas
  perdem coerência para o drift de afinação da fonte e dariam falso negativo).
  Duas propriedades: as vozes nomeadas soam **juntas** (spread ≤ 8 dB; pior
  spread real medido 3,3 dB) e nada que o token **não** nomeia é mais alto
  (≥ 3 dB abaixo da voz mais fraca; pior margem real 6,4 dB), pulando candidatos
  harmonicamente relacionados — a oitava de uma nota real é legitimamente forte.
  **Mutation-testado:** `sax_c4.wav` copiado sobre `sax_maj_c4.wav`,
  `sax_dim_d4`↔`sax_aug_d4` trocados e `sax_e4`↔`sax_f4` trocados **falham**
  (no caso do swap de tríade, spread de 55 dB contra o teto de 8).
- **Âncora absoluta de RMS.** A faixa de ±6 dB é relativa à mediana das próprias
  22, então uma regressão **uniforme** — que é exatamente o A-3, ~3 dB em todas —
  arrasta a mediana junto e deixa todo desvio por amostra perto de zero. Somada
  a assertiva de que a mediana fica a ≤ 1,5 dB dos -15,85 dBFS medidos. A faixa
  de ±6 dB por amostra e seu comentário ficam intactos (o **KEEP** da spec).
  Mutation-testado: -3 dB uniforme nas 22 falha com "median RMS ... -18.85".
- **`PhrasePlayer.flourishRefs ⊆ manifesto`** — `flourishRefs` é hardcoded e
  `playFlourish` engole falhas com `.ignore()`; sem essa linha, uma mudança de
  catálogo que derrubasse um desses tokens obrigaria a apagar o arquivo (o teste
  de órfãos exige) e o flourish emudeceria em silêncio — o sintoma que abriu o C1.

Endurecimentos menores da mesma rodada: `measureAll` memoizada (os 22 assets
eram decodificados e varridos 5× por execução); a guarda relacional passou a
ordenar onset ausente como **pior** caso (`?? double.infinity`) em vez de melhor;
`_parseWav` mantém o clamp de `dataBytes` mas agora **assere** que o `size`
declarado cabe nos bytes disponíveis, nomeando o arquivo; `firstWhere` do teste
de contagem ganhou `orElse: () => fail(...)`; o lookup de `_qualityToken` é
checado antes de virar `'_null_'`; e o probe de órfão em
`curriculum_validation_test.dart` passou de `'phrygian'` para `'not-a-scale-id'`
— `'phrygian'` só adiaria para a Story 1.8 a mesma armadilha que `'dorian'`
acabou de disparar. Em `docs/audio/samples-v1.md`, a receita de lote da 1.3b
(`declare -A MAP=(…)`) foi **restaurada** — a tarefa 8 era somar a segunda
derivação, não remover a primeira — e a tabela de onsets na fonte ganhou a frase
que nomeia método e objeto medido, para não ser lida como a mesma medição da
tabela do A-2 na sessão C1 (limiar por amostra no AIFF vs. janelas de RMS de
20 ms no `.wav` entregue). `deferred-work.md` teve as duas linhas que ainda
diziam "14 `.wav`" corrigidas para 22.

Verificação desta rodada (escopo dos arquivos tocados): `dart format`,
`flutter analyze`, `flutter test test/audio_assets_bundle_test.dart
test/curriculum_validation_test.dart` (60 testes) e
`dart run tool/check_deferred_owners.dart` — todos verdes. A suíte completa e o
`integration_test` foram rodados verdes na rodada anterior e não foram
reexecutados aqui.

**Verificação extra (não pedida, barata):** FFT de 1 s no sustain de cada tríade
confirma os **três fundamentais simultâneos** esperados (ex.: `sax_dim_d4` →
294 / 352 / 417 Hz, todos dentro de 2 % do nominal). É a prova de que a mixagem
casou as vozes certas e de que o resultado é bloco, não arpejo.

**Todos os comandos de §Verification saíram com exit 0**, incluindo
`bash tool/ci.sh` (11 gates) e `flutter test integration_test -d emulator-5554`
(19 testes, com o grupo novo "pre-rendered triads (Story 1.4b)" verde no
emulador `pixel`). `git status` mostra `lib/curriculo/domain/enums.dart` como
**única** mudança em `lib/`.

## Review Triage Log

**Iteração 1 — 2026-09-04.** Três lentes (blind-hunter, edge-case-hunter, verification-gap)
sobre o diff desde `1c30586`. 33 achados brutos, forte sobreposição. Nenhum roteou para
`intent_gap` nem `bad_spec`, então não houve loopback: todo achado sobrevivente tem correção
mínima confinada a arquivos de teste/doc que esta story já possui.

| # | Achado (lente) | Veredito | Evidência da verificação | Rota |
|---|---|---|---|---|
| 1 | Nada verifica que um `.wav` contém a altura que seu token nomeia; tríade pode ser nota única, arpejo ou vozes trocadas (todas as 3 lentes) | **high** | Confirmado. Copiar `sax_c4.wav` sobre `sax_maj_c4.wav` passa manifesto, header, onset, pico, RMS, pareamento e órfãos — todos são agnósticos de altura. O e2e só assere não-lançou: `-noaudio` está nas 4 invocações de emulador (`.github/workflows/ci.yaml:167,178`; `e2e-burn-in.yaml:79,95`). A propriedade que define a story não tem gate. | patch |
| 2 | Sem âncora absoluta de nível: A-3 (erro uniforme de 3 dB) pode voltar em silêncio (todas as 3 lentes) | **medium** | Confirmado por construção: a banda de RMS é ±6 dB da **mediana das mesmas 22**. Uma regressão uniforme move a mediana junto e todo desvio fica ~0 dB. O `I = -16 LUFS` só é verificado por loop de shell colado em tabela markdown. | patch |
| 3 | `docs/audio/samples-v1.md` perdeu o script batch da 1.3b (`declare -A MAP`) | **medium** | Confirmado: `git show HEAD:docs/audio/samples-v1.md` tem o loop na linha 113; o doc atual não tem nenhum. A tarefa 8 mandava *somar* a segunda derivação, não remover a primeira. | patch |
| 4 | `PhrasePlayer.flourishRefs` não é garantido estar no manifesto; `playFlourish` engole falhas | **medium** | Confirmado: `flourishRefs` é `['sax_c4','sax_e4','sax_g4']` hardcoded (`phrase_player.dart:47`) e `playFlourish` usa `.ignore()` (`:132`). Se um ref sair do catálogo, o teste de órfãos manda deletar o arquivo e o flourish emudece — o sintoma exato do C1. | patch |
| 5 | `?? 0` no `reduce` da guarda relacional inverte o significado de onset ausente | **low** | Confirmado no código. Mitigado: o teste irmão (`:199`) já assere `isNotNull` para os 22, então um arquivo silencioso reprova ali antes. Fica o defeito latente (`worst.onsetMs!` lançaria `TypeError` em vez de falha diagnóstica). Correção direta. | patch |
| 6 | `_parseWav` passou a clampar `dataBytes = min(size, disponível)`, mascarando header inflado | **low** | Confirmado: HEAD tinha `dataBytes = size`. O clamp é correto para não ler fora do buffer, mas apaga a discrepância em vez de reportá-la. | patch |
| 7 | `firstWhere` sem `orElse` no teste de contagem de estágios | **low** | Confirmado: lança `StateError` nu se um `stageId` for renomeado, contra o estilo diagnóstico do resto do arquivo. | patch |
| 8 | `_qualityToken[e.chord.id]` nulo degrada o matcher para `contains('_null_')` | **low** | Confirmado: mapa de 4 entradas sem guarda; uma 5ª qualidade produziria mensagem enganosa. | patch |
| 9 | `deferred-work.md:145,147` ainda descreve o conjunto de assets como "14 `.wav`" | **low** | Confirmado por grep. Arquivo que a story já editou. | patch |
| 10 | Sonda de órfão trocou `'dorian'` por `'phrygian'` — id que a Story 1.8 pode tornar real | **low** | Confirmado: é a mesma armadilha que acabou de quebrar, adiada. Correção direta: usar id que nenhuma expansão pode reivindicar. | patch |
| 11 | `measureAll()` recomputado do zero em 5 testes (~12M iterações e 110 loads redundantes) | **low** | Confirmado: 5 chamadas independentes, dados imutáveis no run. Correção direta por memoização. | patch |
| 12 | As duas tabelas de onset (samples-v1.md × sessão C1) discordam sem reconciliação | **low** | Confirmado: métodos e objetos medidos diferem (AIFF de origem × WAV entregue; limiar por amostra × janelas RMS), mas o texto sugere a mesma medição. | patch |
| 13 | `phrase_player.dart:7` ainda diz "within the 14 v1 samples" | **low** | Confirmado e real. Mas o bloco congelado tem `Never: tocar em lib/exercicios/**` e a AC exige `enums.dart` como única mudança em `lib/` — a **intenção** exclui a correção, e a Story 1.5 já é dona desse arquivo. | defer |
| 14 | Nada liga a sequência de notas de um exercício `scale` aos `steps` do seu `scaleType` | **medium** | Confirmado (a própria lente verification-gap arquivou como `defer`): trocar `sax_eb4` por `sax_e4` na dórica ascendente passa todos os gates. É o item de validação semântica já registrado em `deferred-work.md:55`, sem consumidor em runtime até a 1.5. | defer |
| 15 | Os 3 `ErrorType` novos não têm consumidor nem teste semântico | **low** | Verifiquei a Design Note por conta própria e ela está **correta**: maior 0,2,4,5,7,9,11 × mixolídia …,10 diferem só no 7º grau; menor …,8,10 × dórica …,9,10 só no 6º; dórica 0,2,3 × mixolídia 0,2,4 só no 3º. Sem consumidor até a 1.6 e a correção é um teste novo, não uma correção direta. | defer |
| 16 | Onset tem teto (20 ms) mas não piso: cortar *dentro* do transiente é indetectável | **low** | Real, mas um piso a partir do cruzamento de -40 dBFS é frágil: os onsets entregues variam 1,9–8,3 ms por conteúdo espectral, não por corte. Um piso fixo produziria falha espúria. Correção acrescenta complexidade para um caso improvável. | rejeitado |
| 17 | Lista de tríades do e2e é uma 3ª cópia hardcoded do manifesto | **low** | O manifesto congelado de 22 tokens (`:158`) reprova qualquer 9ª tríade, então a divergência não passa silenciosa — obriga a editar o teste unitário primeiro. Derivar por regex no integration test acrescenta complexidade sem fechar risco novo. | rejeitado |
| 18 | Silêncio no fim do arquivo (áudio curto com padding até 2,5 s) passaria | **low** | Subsumido pelo patch #1: a sonda espectral mede também uma janela de sustain tardia, então um arquivo que emudece antes reprova ali. | rejeitado |
| 19 | Duas raízes a um tom de distância (C4/D4) mal entrega o objetivo anti-altura-absoluta | **medium** | Argumento tem mérito, mas a correção é editar o bloco congelado: 4 qualidades × 2 raízes (C4, D4) é **decisão explícita do humano** registrada no Change Log de 2026-09-04. Regra de triagem: rejeitar achado cuja correção é editar a spec desta build. Levado ao humano no step-05. | rejeitado |
| 20 | `measure()` decodifica com constantes congeladas antes de validar o header parseado | **false** | Não ocorre: os 22 arquivos são gerados pelo mesmo pipeline e o teste de header (`:166`) reprova qualquer não-mono/não-16-bit. Um asset heterogêneo falharia lá; a leitura equivocada seria consequência, não causa não detectada. | rejeitado |
| 21 | `frames == 0` produz divisão por zero e RMS `NaN` | **false** | Não ocorre: `minDataBytes` (88200) reprova qualquer payload < 1 s antes, e `expect(data.lengthInBytes, greaterThan(44))` já barra o arquivo vazio. | rejeitado |
| 22 | Banda de RMS ±6 dB é ~3,5× mais larga que o espalhamento observado (máx 1,69 dB) | **false** | Não é defeito: a largura é **decisão congelada e justificada** ("sanidade larga, não casamento de nível — uma tríade densa tem crest factor diferente"). Medi e confirmei o espalhamento. O buraco real de nível é o #2, tratado por âncora absoluta em vez de estreitar esta banda. | rejeitado |
| 23 | Story deixada "mid-flight" (`in-progress`, `review_loop_iteration: 0`, log de triagem vazio) | **false** | É o estado correto do workflow no momento em que a lente leu o diff: a tarefa 11 especifica `review` na abertura do PR, e este log estava vazio porque o review ainda não havia rodado. | rejeitado |
| 24 | `audio-sourcing.md:14,147` ainda diz "14 `.wav`" | **false** | Ambas as linhas são afirmações **históricas** sobre a Story 1.3b ("✅ RESOLVIDO (Story 1.3b)", "Balde 1 — feito (Story 1.3b)"), corretas no seu tempo verbal. Não descrevem o estado atual. | rejeitado |
| 25 | Contrato posicional dos refs de acorde não está documentado em `curriculum.dart` | **medium** | Real, mas a correção é comentário em `lib/curriculo/domain/curriculum.dart`, e a AC congelada exige `enums.dart` como única mudança em `lib/`. Mesma exclusão de intenção do #13; a 1.5 é a consumidora. | defer |

**Agrupamento e rota:** 12 entradas para `patch` (#1–#12), 4 para `defer` (#13, #14, #15, #25),
9 rejeitadas. Sem `intent_gap` nem `bad_spec` → sem loopback; `review_loop_iteration` fica em 0.


## Design Notes

- **Pré-render, não arpejo:** contrato de `playSample` (Intent, problema 1).
- **`audioSampleRefs` com bloco + 3 vozes:** deixa a 1.5 tocar bloco → arpejo → bloco sem asset novo. Guardar só o bloco fecharia essa porta.
- **`loudnorm` depois do `amix`, com `normalize=0`:** somar três vozes correlacionadas sobe o loudness; e o default do `amix` divide por N, o que desperdiçaria faixa dinâmica antes da normalização.
- **`loudnorm` em duas passagens:** a passagem única é a causa-raiz do A-3 (-19,0 contra -16 declarado); em arquivos de ~2,3 s o modo dinâmico é impreciso. Medir com `print_format=json` e aplicar `measured_*` com `linear=true`.
- **Enum e JSON sobem juntos:** `_validateErrorTypes` compara o JSON com `ErrorType.values` inteiro — **os dois sentidos reprovam**, não só o token sem enum.
- **Escala não vira asset:** escala é sequência de notas isoladas; só o acorde é simultâneo.
- **Duas raízes para acorde, uma para escala:** o acorde é asset pré-renderizado, então a raiz fica congelada no arquivo e precisa das duas agora. A escala é montada em runtime a partir de notas isoladas — a Story 1.8 transpõe sem produzir nada. O argumento anti-altura-absoluta vale para os dois; só o custo de atendê-lo difere.
- **Taxonomia de erro de escala:** os três graus que separam os 4 modos, medidos par a par — maior×mixolídia difere só na 7ª, menor×dórica só na 6ª, dórica×mixolídia só na 3ª. Os outros pares diferem em 2–3 graus e caem em `far-miss`. Nomear pelo grau, não pelo modo, mantém três entradas mesmo se modos novos entrarem.
- **Dinâmica `ff` mantida:** o A/B de 2026-09-04 (`pw-play` no host) descartou o chiado como artefato do emulador. Ver Change Log, A-1.
