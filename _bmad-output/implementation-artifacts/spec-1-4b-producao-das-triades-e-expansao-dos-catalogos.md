---
title: 'Story 1.4b — Produção das tríades e expansão dos catálogos'
type: 'feature'
created: '2026-09-03'
status: 'ready-for-dev'
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

- [ ] **1. `assets/audio/<as 14 notas>.wav`** -- rerenderizar a partir dos AIFFs de origem (ver §Verification → Ambiente). Ordem dos filtros: estéreo→mono → `atrim` de cabeça deixando ~10 ms de pré-ataque → `asetpts=PTS-STARTPTS` → **`loudnorm` em duas passagens medidas** → `atrim=end=2.5` → `afade=t=out` com `st` calculado da duração real → PCM 16-bit 44,1 kHz
- [ ] **2. `assets/audio/sax_{maj,min,dim,aug}_{c4,d4}.wav`** -- gerar as 8 tríades **a partir das notas já rerenderizadas na tarefa 1** (mixar as originais desalinhadas produziria arpejo, não acorde):
  ```
  ffmpeg -i sax_c4.wav -i sax_e4.wav -i sax_g4.wav \
    -filter_complex "[0:a][1:a][2:a]amix=inputs=3:duration=shortest:normalize=0[m]; \
      [m]atrim=start=<onset-0.010>,asetpts=PTS-STARTPTS[t]" \
    -map "[t]" -ar 44100 -c:a pcm_s16le /tmp/triade_raw.wav
  # depois: loudnorm two-pass (mede, aplica) -> atrim=end=2.5 -> afade calculado -> sax_maj_c4.wav
  ```
  `normalize=0` é obrigatório: o default do `amix` divide por N e entrega a tríade mais baixa que as notas
- [ ] **3. `assets/curriculum/catalog_v1.json`** -- as 4 entradas de catálogo completas, os 3 `errorTypes`, `s-acordes` 2→8 (os 2 existentes reescritos com o ref do bloco), `s-escalas` 4→8
- [ ] **4. `lib/curriculo/domain/enums.dart`** -- `ErrorType` += `tercaAlterada` / `sextaAlterada` / `setimaAlterada`. **Sobe no mesmo commit que a tarefa 3** — qualquer um dos dois sozinho reprova o `check_curriculum`
- [ ] **5. `test/curriculum_catalog_test.dart`** -- estender os conjuntos congelados (linhas 117-118) para `{major,minor,diminished,augmented}` e `{major,natural_minor,dorian,mixolydian}`
- [ ] **6. `test/audio_assets_bundle_test.dart`** -- manifesto 14→22; docstring e nome do teste; assertivas de conteúdo PCM (onset, pico, RMS); pareamento tríade↔vozes; contagens `s-acordes`==8 e `s-escalas`==8; guarda relacional contra `flourishGap`/`noteGap`
- [ ] **7. `integration_test/catear_e2e_test.dart`** -- laço de `playSample` sobre os 8 tokens de tríade sob `_playTimeout`
- [ ] **8. `docs/audio/samples-v1.md`** -- seção de segunda derivação (receita + tabela tríade→vozes + licença); regenerar a tabela SHA-256 para 22; atualizar duração/RMS esperados; "14 arquivos" → 22; **reverificar o texto da licença na página nova** (`MIS-Pitches-2012/MISEbAltoSaxophone2012.html`), atualizar a citação verbatim, a data de acesso e o link do Web Archive, substituindo as 3 URLs nomeadamente
- [ ] **9. `pubspec.yaml`** -- comentário "14 mono .wav notes" → 22
- [ ] **10. `deferred-work.md`** -- corrigir "tríade=3" para "acorde = 4 refs (bloco + 3 vozes)"
- [ ] **11. `sprint-status.yaml`** -- a chave `1-4b-produção-das-tríades-e-expansão-dos-catálogos` já existe como `ready-for-dev`; mover para `in-progress` ao começar e `review` ao abrir o PR

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

## Review Triage Log

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
