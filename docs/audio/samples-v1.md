---
purpose: "Proveniência, licença e receita de conversão do conjunto de amostras de áudio da v1"
status: done
created: 2026-09-02
updated: 2026-09-04
story: 1.3b, 1.4b
---

# Amostras de áudio da v1 — `assets/audio/*.wav`

Os **22** arquivos em `assets/audio/` são as amostras que o currículo v1
(`assets/curriculum/catalog_v1.json`) referencia por `audioSampleRef`:

- **14 notas sustentadas** de saxofone alto (primeira derivação, Story 1.3b);
- **8 tríades pré-renderizadas** (segunda derivação, Story 1.4b) — mixagem
  determinística de três daquelas notas, porque `AudioService.playSample`
  interrompe qualquer amostra em curso e o `_JustAudioService` tem um único
  `AudioPlayer`: simultaneidade só existe **dentro do arquivo**.

O contexto musical (sequência, transposição, fraseado) é montado em runtime
pelas Stories 1.4+, não aqui.

> **Rerenderização de 2026-09-04 (Story 1.4b).** As 14 notas foram **regeradas a
> partir dos AIFFs de origem** — mesma fonte, mesmo pitch, mesma duração-alvo,
> mesmos tokens. Mudou só o processamento: corte do silêncio de cabeça (achado
> A-2 da sessão C1) e loudness medido em duas passagens (achado A-3). Ver
> §Rerenderização.

## Fonte

**University of Iowa Musical Instrument Samples (MIS)** — AltoSax, No Vibrato,
dinâmica *ff*, gravação estéreo.

- Página do instrumento:
  <https://theremin.music.uiowa.edu/MIS-Pitches-2012/MISEbAltoSaxophone2012.html>
  — **acessada e verificada em 2026-09-04** (HTTP 200; lista os
  `AltoSax.NoVib.ff.<Nota>.stereo.aif` e o zip
  `AltoSax.NoVib.ff.stereo.zip`).
  Snapshot: <https://web.archive.org/web/20260129163013/https://theremin.music.uiowa.edu/MIS-Pitches-2012/MISEbAltoSaxophone2012.html>
- Índice da coleção: <https://theremin.music.uiowa.edu/MIS.html>
  — acessado e verificado em 2026-09-04 (HTTP 200).
  Snapshot: <https://web.archive.org/web/20260619045647/https://theremin.music.uiowa.edu/MIS.html>
- ⚠️ **URL morta:** <https://theremin.music.uiowa.edu/MISsaxophone.html>, citada
  na primeira versão deste documento, responde **404** desde (pelo menos)
  2026-09-04 (achado A-4 da sessão C1). Foi substituída pelas duas acima.
- Coleção local usada: `~/Downloads/AltoSax.NoVib.ff.stereo/`
  (`AltoSax.NoVib.ff.<Nota>.stereo.aif`, AIFF 24-bit / 44,1 kHz / estéreo).

### Licença

Fonte consultada: <https://theremin.music.uiowa.edu/MIS.html> —
**reacessada e reconferida em 2026-09-04**. Snapshot:
<https://web.archive.org/web/20260619045647/https://theremin.music.uiowa.edu/MIS.html>

Texto **verbatim** da página, reconferido palavra por palavra em 2026-09-04:

> "The University of Iowa Musical Instrument Samples (MIS) are created by
> Lawrence Fritts, Director of the Electronic Music Studios and Professor of
> Composition at the University of Iowa. Since 1997, these recordings have been
> freely available on this website and may be downloaded and used for any
> projects, without restrictions."

- **Autoria / copyright:** **Lawrence Fritts**, University of Iowa Electronic
  Music Studios — agora citado verbatim (na versão anterior era paráfrase).
- **Atribuição:** não é exigida. A página pede, como cortesia, notificação de
  uso ("Please let me know if these have been helpful…") — não é obrigação.
- **Obras derivadas:** as 8 tríades são derivadas das 14 notas, que já são
  derivadas desta mesma fonte. "used for any projects, without restrictions"
  cobre a segunda derivação sem condição nova; **a licença é a mesma**.
- **Redistribuição da coleção crua:** os AIFFs de origem **não** entram no repo
  (cf. `_bmad-output/implementation-artifacts/audio-sourcing.md`, Balde 1). Só
  os 22 `.wav` derivados e recortados são versionados.
- **Nota comercial:** para lançamento comercial, confirmar a licença por escrito
  ou migrar para uma fonte CC0 (VSCO 2 Community Edition) — ver `audio-sourcing.md`.

## Verificação de pitch — feita, nada a transpor

`experiments/meow-sampler/verify_pitch.py` foi rodado na pasta de origem
(2026-09-01): **32/32 arquivos com offset +0 semitons**. Os nomes de arquivo já
estão em *concert pitch* (pitch soante), dentro de ±20 cents do nominal (afinação
acústica normal). Nenhum arquivo foi renomeado nem transposto.

## Primeira derivação — tabela token → AIFF de origem

| token catálogo | nota (concert) | AIFF de origem |
|---|---|---|
| `sax_c4`  | C4  | `AltoSax.NoVib.ff.C4.stereo.aif`  |
| `sax_db4` | Db4 | `AltoSax.NoVib.ff.Db4.stereo.aif` |
| `sax_d4`  | D4  | `AltoSax.NoVib.ff.D4.stereo.aif`  |
| `sax_eb4` | Eb4 | `AltoSax.NoVib.ff.Eb4.stereo.aif` |
| `sax_e4`  | E4  | `AltoSax.NoVib.ff.E4.stereo.aif`  |
| `sax_f4`  | F4  | `AltoSax.NoVib.ff.F4.stereo.aif`  |
| `sax_gb4` | Gb4 | `AltoSax.NoVib.ff.Gb4.stereo.aif` |
| `sax_g4`  | G4  | `AltoSax.NoVib.ff.G4.stereo.aif`  |
| `sax_ab4` | Ab4 | `AltoSax.NoVib.ff.Ab4.stereo.aif` |
| `sax_a4`  | A4  | `AltoSax.NoVib.ff.A4.stereo.aif`  |
| `sax_bb4` | Bb4 | `AltoSax.NoVib.ff.Bb4.stereo.aif` |
| `sax_b4`  | B4  | `AltoSax.NoVib.ff.B4.stereo.aif`  |
| `sax_c5`  | C5  | `AltoSax.NoVib.ff.C5.stereo.aif`  |
| `sax_d5`  | D5  | `AltoSax.NoVib.ff.D5.stereo.aif`  |

## Segunda derivação — as 8 tríades (Story 1.4b)

**Nenhum AIFF novo entrou no repo.** Cada tríade é a soma das três notas já
commitadas, **depois** de elas terem sido rerenderizadas (o alinhamento de
ataque é pré-requisito: mixar as notas antigas, com 180–320 ms de ar morto
desigual, produziria arpejo, não acorde).

4 qualidades × 2 raízes. Duas raízes, não uma: com raiz fixa o exercício vira
reconhecimento de altura absoluta, e cada qualidade numa raiz só permite decorar
o par altura↔qualidade.

| token | qualidade | raiz | vozes mixadas |
|---|---|---|---|
| `sax_maj_c4` | major      | C4 | `sax_c4` + `sax_e4` + `sax_g4`   |
| `sax_min_c4` | minor      | C4 | `sax_c4` + `sax_eb4` + `sax_g4`  |
| `sax_dim_c4` | diminished | C4 | `sax_c4` + `sax_eb4` + `sax_gb4` |
| `sax_aug_c4` | augmented  | C4 | `sax_c4` + `sax_e4` + `sax_ab4`  |
| `sax_maj_d4` | major      | D4 | `sax_d4` + `sax_gb4` + `sax_a4`  |
| `sax_min_d4` | minor      | D4 | `sax_d4` + `sax_f4` + `sax_a4`   |
| `sax_dim_d4` | diminished | D4 | `sax_d4` + `sax_f4` + `sax_ab4`  |
| `sax_aug_d4` | augmented  | D4 | `sax_d4` + `sax_gb4` + `sax_bb4` |

O catálogo guarda os quatro juntos: `audioSampleRefs` de um exercício `chord` é
`[<tríade>, <raiz>, <terça>, <quinta>]` — o bloco primeiro, as três vozes depois.
Assim a Story 1.5 monta bloco → arpejo → bloco sem asset novo, e um consumidor
que só leia `refs[0]` toca o bloco e degrada corretamente.

**Escala não vira asset:** escala é sequência de notas isoladas, e as duas novas
(dórica e mixolídia sobre C4) cabem nas 14 notas existentes. Só o acorde é
simultâneo.

## Receita de conversão

Um-off, **fora do CI**. Requer `ffmpeg` (testado com o build do sistema em
`/usr/bin/ffmpeg`, versão 8.0.1), `python3` + `numpy` (para medir onset e
loudness) e a pasta de origem em `~/Downloads/AltoSax.NoVib.ff.stereo/`.

Formato-alvo, idêntico entre as 22: **WAV PCM 16-bit, mono, 44,1 kHz**, ≤ 2,5 s,
loudness por EBU R128 (`I=-16 LUFS / TP=-1.5 dBTP / LRA=11`) **medido em duas
passagens**, fade-out de 40 ms na cauda, ataque preservado com ~10 ms de
pré-ataque.

### Primeira derivação — receita da Story 1.3b (histórica, ainda reproduzível)

Foi a receita que produziu a primeira versão das 14 notas. Fica registrada
porque é a única forma de reproduzir aquele conjunto — e porque é o contraponto
concreto do que a rerenderização mudou. **Não é a receita corrente:** ela é a
causa-raiz dos achados A-2 (sem corte de cabeça) e A-3 (`loudnorm` de passagem
única). Para reproduzir os arquivos que estão hoje em `assets/audio/`, use a
§Rerenderização abaixo.

```
ffmpeg -y -i AltoSax.NoVib.ff.C4.stereo.aif \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=mono,atrim=end=2.5,afade=t=out:st=2.46:d=0.04" \
  -ar 44100 -ac 1 -c:a pcm_s16le assets/audio/sax_c4.wav
```

O laço sobre os 14 tokens, executado uma vez:

```bash
declare -A MAP=(
  [sax_c4]=C4  [sax_db4]=Db4 [sax_d4]=D4  [sax_eb4]=Eb4 [sax_e4]=E4
  [sax_f4]=F4  [sax_gb4]=Gb4 [sax_g4]=G4  [sax_ab4]=Ab4 [sax_a4]=A4
  [sax_bb4]=Bb4 [sax_b4]=B4  [sax_c5]=C5  [sax_d5]=D5
)
FILTER="atrim=end=2.5,loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=mono,afade=t=out:st=2.46:d=0.04"
for token in "${!MAP[@]}"; do
  ffmpeg -y -i "$HOME/Downloads/AltoSax.NoVib.ff.stereo/AltoSax.NoVib.ff.${MAP[$token]}.stereo.aif" \
    -af "$FILTER" -ar 44100 -ac 1 -c:a pcm_s16le "assets/audio/$token.wav"
done
```

**Ordem dos filtros nessa versão:** `atrim` vinha **antes** de `loudnorm`. As 14
fontes têm 2,77–3,54 s; cortar a cauda primeiro garantia duração de saída de
exatamente 2,500 s e nunca tocava no ataque. (Com `loudnorm` antes de `atrim`, o
atraso de lookahead do limitador de true-peak empurra o PTS e o `atrim=end=2.5`
acaba comendo 40–60 ms do início.) `aformat=channel_layouts=mono` faz o downmix
estéreo→mono; `afade` suaviza os últimos 40 ms.

### Rerenderização — as 14 notas (Story 1.4b, tarefa 1)

Cadeia, por nota, a partir do AIFF 24-bit de origem:

1. **estéreo → mono**, 44,1 kHz, em float 32-bit (intermediários em
   `pcm_f32le`; nenhuma etapa intermediária passa por 16-bit);
2. **medir o onset**: primeira amostra com `|x| ≥ -40 dBFS` (1% do fundo de
   escala) dentro dos primeiros 500 ms;
3. **`atrim=start=<onset − 10 ms>` + `asetpts=N/SR/TB`** — corta o ar morto e
   deixa 10 ms de pré-ataque, preservando o transiente;
4. **`atrim=end=<dur>`**, com `dur = min(2.5 s, duração restante)` — o corte de
   cauda entra **antes** da medição, para que o loudness medido seja o do
   arquivo entregue e não o de um sinal mais longo;
5. **`loudnorm` em duas passagens medidas**: passagem 1 com
   `print_format=json` colhe `measured_I/TP/LRA/thresh/offset`; passagem 2
   aplica esses valores com `linear=true`;
6. **recorte final exato** para `dur`, **`afade=t=out:st=<dur − 0.04>:d=0.04`**
   (o `st` sai da duração **real**, não de uma constante) e conversão para
   `pcm_s16le` 44,1 kHz mono — o `loudnorm` reamostra internamente para
   192 kHz, e este último passo garante contagem de amostras exata
   (110250 quadros = 220500 bytes de `data`) e um fade que cai dentro do
   arquivo.

```bash
# 3+4 — shaping (float), com <start> e <dur> medidos em python
ffmpeg -y -i mono.wav -af \
  "atrim=start=<start>,asetpts=N/SR/TB,atrim=end=<dur>,asetpts=N/SR/TB" \
  -ar 44100 -ac 1 -c:a pcm_f32le shaped.wav

# 5a — medir
ffmpeg -hide_banner -nostats -i shaped.wav \
  -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null -

# 5b — aplicar (linear, medido)
ffmpeg -y -i shaped.wav -af \
  "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=<I>:measured_TP=<TP>:measured_LRA=<LRA>:measured_thresh=<thresh>:offset=<offset>:linear=true" \
  -ar 44100 -ac 1 -c:a pcm_f32le normalized.wav

# 6 — corte exato + fade + 16-bit
ffmpeg -y -i normalized.wav -af \
  "atrim=end=<dur>,asetpts=N/SR/TB,afade=t=out:st=<dur-0.04>:d=0.04" \
  -ar 44100 -ac 1 -c:a pcm_s16le assets/audio/<token>.wav
```

**Por que mudou em relação à receita da 1.3b** (que ficava em uma passagem e sem
corte de cabeça):

- a regra *"ataque preservado (sem cortar o início)"* protegeu o transiente e
  manteve junto **180–320 ms de silêncio** antes dele. Com `PhrasePlayer`
  disparando notas a cada 450 ms (e o flourish a cada 170 ms), cada nota soava
  por 130–270 ms e duas das três notas do flourish eram cortadas antes do
  próprio ataque. É o achado **A-2** da sessão C1;
- `loudnorm` de **passagem única** entregou **-19,0 LUFS** contra os -16
  declarados como AC — achado **A-3**. Em material de ~2,5 s o modo dinâmico é
  impreciso; a passagem medida com `linear=true` é um ganho estático e acerta o
  alvo.

Os onsets **na fonte**, medidos antes do corte. **Método:** primeira amostra com
`|x| ≥ -40 dBFS` no **AIFF de origem** já convertido para mono. A tabela do A-2
na sessão C1 mede outra coisa de outro jeito — varredura de RMS em janelas de
20 ms sobre os **`.wav` já entregues** — então os números diferem por token
(`sax_d4` 171 aqui contra 200 lá, `sax_c5` 185 contra 180). São duas medições do
mesmo defeito, não a mesma medição:

| ms até o ataque, no AIFF | notas |
|---|---|
| 170–210 | `sax_d4` (171), `sax_c5` (185), `sax_c4` (206), `sax_d5` (214) |
| 230–270 | `sax_bb4` (233), `sax_ab4` (239), `sax_f4` (254), `sax_db4` (261), `sax_e4` (262), `sax_b4` (264), `sax_g4` (268) |
| 290–320 | `sax_eb4` (298), `sax_gb4` (303), `sax_a4` (313) |

### Mixagem — as 8 tríades (Story 1.4b, tarefa 2)

A partir dos `.wav` **já rerenderizados** na tarefa 1:

```bash
ffmpeg -y -i assets/audio/sax_c4.wav \
       -i assets/audio/sax_e4.wav \
       -i assets/audio/sax_g4.wav \
  -filter_complex "[0:a][1:a][2:a]amix=inputs=3:duration=shortest:normalize=0[m]" \
  -map "[m]" -ar 44100 -ac 1 -c:a pcm_f32le mix.wav
# depois: mesmos passos 2..6 da rerenderização -> assets/audio/sax_maj_c4.wav
```

- **`normalize=0` é obrigatório.** O default do `amix` divide por N e entregaria
  a tríade mais baixa que as notas, desperdiçando faixa dinâmica antes da
  normalização.
- **`loudnorm` roda depois do `amix`.** Somar três vozes correlacionadas eleva o
  loudness; sem renormalizar, a tríade sairia audivelmente mais alta que a nota
  isolada — viés direto no exercício.
- **Intermediários em float.** O `amix` de três sinais a -16 LUFS excede o
  fundo de escala; em `pcm_f32le` isso não clipa, e o `loudnorm` seguinte traz
  tudo de volta (pico final medido entre -3,9 e -4,9 dBFS nas tríades).

O script one-off completo (laço sobre os 22 tokens, com a medição de onset em
`numpy`) foi executado uma vez a partir de um script equivalente ao descrito
acima; **não** foi versionado, pela mesma razão da 1.3b — é derivação de asset,
não passo de build.

## Verificação da saída

```bash
for f in assets/audio/*.wav; do
  ffprobe -v error -show_entries stream=channels,sample_rate,codec_name \
    -show_entries format=duration -of default=nw=1 "$f"
done
```

Esperado, 22×: `codec_name=pcm_s16le`, `channels=1`, `sample_rate=44100`,
`duration=2.500000`.

Medição por amostra (2026-09-04) — `I`/true peak por `ffmpeg -af ebur128`,
onset/pico/RMS lidos do PCM. **Todas as 22 em `I = -16,0 LUFS`** (dentro de
±1 LU do alvo), **onset ≤ 8,3 ms** (orçamento: 20 ms) e **pico ≤ -3,89 dBFS**
(teto: -1,0 dBFS). A mediana de RMS é **-15,85 dBFS**, e o desvio máximo é
**-1,69 dB** (`sax_d5`) — bem dentro da faixa de ±6 dB.

| token | dur (s) | onset (ms) | I (LUFS) | true peak (dBTP) | pico (dBFS) | RMS (dBFS) |
|---|---|---|---|---|---|---|
| `sax_c4` | 2.500 | 1.9 | -16.0 | -8.2 | -8.21 | -15.90 |
| `sax_db4` | 2.500 | 8.3 | -16.0 | -8.6 | -8.56 | -15.88 |
| `sax_d4` | 2.500 | 3.7 | -16.0 | -10.4 | -10.38 | -15.59 |
| `sax_eb4` | 2.500 | 3.0 | -16.0 | -6.3 | -6.32 | -15.95 |
| `sax_e4` | 2.500 | 4.0 | -16.0 | -7.6 | -7.65 | -16.02 |
| `sax_f4` | 2.500 | 3.2 | -16.0 | -6.9 | -6.92 | -15.84 |
| `sax_gb4` | 2.500 | 2.6 | -16.0 | -7.2 | -7.16 | -16.10 |
| `sax_g4` | 2.500 | 4.9 | -16.0 | -8.1 | -8.14 | -15.90 |
| `sax_ab4` | 2.500 | 5.0 | -16.0 | -6.9 | -6.99 | -15.70 |
| `sax_a4` | 2.500 | 4.5 | -16.0 | -7.3 | -7.35 | -15.69 |
| `sax_bb4` | 2.500 | 5.8 | -16.0 | -9.1 | -9.09 | -15.72 |
| `sax_b4` | 2.500 | 6.1 | -16.0 | -9.1 | -9.09 | -16.05 |
| `sax_c5` | 2.500 | 6.2 | -16.0 | -8.9 | -8.96 | -16.83 |
| `sax_d5` | 2.500 | 6.8 | -16.0 | -9.2 | -9.27 | -17.54 |
| `sax_maj_c4` | 2.500 | 2.2 | -16.0 | -4.7 | -4.75 | -15.86 |
| `sax_min_c4` | 2.500 | 2.2 | -16.0 | -4.1 | -4.09 | -15.83 |
| `sax_dim_c4` | 2.500 | 3.0 | -16.0 | -3.9 | -3.89 | -16.04 |
| `sax_aug_c4` | 2.500 | 4.5 | -16.0 | -4.8 | -4.81 | -15.80 |
| `sax_maj_d4` | 2.500 | 3.7 | -16.0 | -4.4 | -4.44 | -15.74 |
| `sax_min_d4` | 2.500 | 2.2 | -16.0 | -4.4 | -4.40 | -15.71 |
| `sax_dim_d4` | 2.500 | 3.2 | -16.0 | -4.5 | -4.53 | -15.71 |
| `sax_aug_d4` | 2.500 | 2.6 | -16.0 | -4.9 | -4.90 | -15.73 |

> O onset medido no arquivo final fica **abaixo** dos 10 ms de pré-ataque
> deixados no corte: o ganho do `loudnorm` (~+3 a +4 dB) empurra acima do limiar
> de -40 dBFS amostras do sopro que antes ficavam abaixo dele. É esperado, e
> está bem dentro do orçamento de 20 ms.

O teste `test/audio_assets_bundle_test.dart` fecha o loop no lado do app (job
`gates`): cada `audioSampleRef` do catálogo real resolve para um `.wav`
carregável pelo `rootBundle`; o cabeçalho RIFF/WAVE é PCM / mono / 44,1 kHz /
16-bit com payload `data` ≤ 220500 bytes (≤ 2,5 s); **o PCM tem onset ≤ 20 ms,
pico ≤ -1,0 dBFS e RMS dentro de ±6 dB da mediana das 22**; o pior onset fica
abaixo de metade do menor gap do `PhrasePlayer`; todo exercício `chord` é
`[tríade, raiz, terça, quinta]`; e não há arquivo órfão em `assets/audio/`.

## Checksums (SHA-256)

`sha256sum assets/audio/*.wav` — regenerados com os arquivos rerenderizados
(2026-09-04). **Os checksums da versão anterior deste documento não valem mais**:
as 14 notas mudaram de bytes (mesmo conteúdo musical, processamento diferente).

| token | SHA-256 |
|---|---|
| `sax_a4.wav`  | `4764f9eda2158ca696b420100aa52132b44793ce5fc69860582ae317bb4d668e` |
| `sax_ab4.wav` | `69f7601976954ae8e5af90813754374d0309d820d7c39f2a21ec85a8365c2665` |
| `sax_aug_c4.wav` | `87e971b638ec1f7d5639de57855f1dc82f768bbb3496bc0e5ad3d6063946996c` |
| `sax_aug_d4.wav` | `37718c8502869dc825b3f3bf985bccace179dac4e09bf22e86114b08a67b505e` |
| `sax_b4.wav`  | `62979454a5378fbd33dfc3c51a2872e21e4eb215d78abd8365ac01c77d048d24` |
| `sax_bb4.wav` | `166bbe008fbf9213cc8017cf547786116bc161555991f461558dc5d4badd8619` |
| `sax_c4.wav`  | `3ce2be230855422f6e6214c697b6d19af8ead2aa3838740025cd28e1d732c525` |
| `sax_c5.wav`  | `c3d5e97de356802552881645863b196f261a449006533e5e6809116aac6f84f5` |
| `sax_d4.wav`  | `474d9a0d1963f175254e3c09b7ceab05242170724801e8e2c9e4b36769c28ec0` |
| `sax_d5.wav`  | `701c8d56d0dc94067239d93d8eb5645314264c67fd67cab607932e878acbd63f` |
| `sax_db4.wav` | `e2830ed31435bcb20d3c9ba8ae952f743304b14d2df99a55e80895e5dc82ec26` |
| `sax_dim_c4.wav` | `929b8c91e86cebafdc3d0f829dff6310d4481b5ca75ea36c1c99f199c7d6d75c` |
| `sax_dim_d4.wav` | `8953b572e1c5f98f1840e026959d74bc42a4a460f092461dd245c9ada500418c` |
| `sax_e4.wav`  | `0a3aa8ee694d851e5d52706a30a418d6d695c5d3e2ef7c6ea605b39956d47152` |
| `sax_eb4.wav` | `408f75dd4c9187d14b246f3e4e7f74002810ef331848e0e03303a47b10e125ea` |
| `sax_f4.wav`  | `609738fffdd518327e68b894bd1d95b0ee7b2222586666ebe4e23ec7ecc0dffa` |
| `sax_g4.wav`  | `4b9ba63aff366e16716c5228f2379480d559bbe135f69b353b43de69e673e5fc` |
| `sax_gb4.wav` | `40ae0f942844e1c1c7e4ca4304097864d5bf32df3ce36b663948da1f307e3d8f` |
| `sax_maj_c4.wav` | `d13721d1853f8c976e32beb95c3f6b6256f23c5229fdee41e2eb6c7bf96f6bcf` |
| `sax_maj_d4.wav` | `15f9067c965d59aafdd79a5057a3202303ec6089ff47555341f7b300dde6f048` |
| `sax_min_c4.wav` | `517dfed057eef99b31c7d1b6944a0b6ffb4bda425b071ff544f60c380c8903af` |
| `sax_min_d4.wav` | `03aa7865985250fb685415cc1253633657ce33fd80a59eaa5b26c0ae9fb9a8e7` |
