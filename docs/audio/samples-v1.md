---
purpose: "Proveniência, licença e receita de conversão do conjunto de amostras de áudio da v1"
status: done
created: 2026-09-02
story: 1.3b
---

# Amostras de áudio da v1 — `assets/audio/*.wav`

Os 14 arquivos em `assets/audio/` são as notas sustentadas de saxofone alto que o
currículo v1 (`assets/curriculum/catalog_v1.json`) referencia por `audioSampleRef`.
Uma nota real por arquivo; o contexto musical (sequência, transposição, fraseado)
é montado em runtime pelas Stories 1.4+, não aqui.

## Fonte

**University of Iowa Musical Instrument Samples (MIS)** — AltoSax, No Vibrato,
dinâmica *ff*, gravação estéreo.

- Página oficial: <https://theremin.music.uiowa.edu/MISsaxophone.html>
  (índice: <https://theremin.music.uiowa.edu/MIS.html>)
- Coleção local usada: `~/Downloads/AltoSax.NoVib.ff.stereo/`
  (`AltoSax.NoVib.ff.<Nota>.stereo.aif`, AIFF 24-bit / 44,1 kHz / estéreo).

### Licença

Fonte consultada: <https://theremin.music.uiowa.edu/MIS.html> —
**acessado em 2026-09-02**. Snapshot:
<https://web.archive.org/web/2026*/https://theremin.music.uiowa.edu/MIS.html>

Texto confirmado **verbatim** da página (a única frase citada palavra por palavra):

> "these recordings have been freely available on this website and may be
> downloaded and used for any projects, without restrictions."

- **Autoria / copyright:** a página atribui as gravações a **Lawrence Fritts**,
  descrito como *Director of the Electronic Music Studios and Professor of
  Composition at the University of Iowa*. (Paráfrase da página, não citação
  verbatim.)
- **Atribuição:** não é exigida. A página pede, como cortesia, notificação de
  uso ("Please let me know if these have been helpful…") — não é obrigação.
- **Redistribuição da coleção crua:** os AIFFs de origem **não** entram no repo
  (cf. `_bmad-output/implementation-artifacts/audio-sourcing.md`, Balde 1). Só os
  14 `.wav` derivados e recortados são versionados.
- **Nota comercial:** para lançamento comercial, confirmar a licença por escrito
  ou migrar para uma fonte CC0 (VSCO 2 Community Edition) — ver `audio-sourcing.md`.

## Verificação de pitch — feita, nada a transpor

`experiments/meow-sampler/verify_pitch.py` foi rodado na pasta de origem
(2026-09-01): **32/32 arquivos com offset +0 semitons**. Os nomes de arquivo já
estão em *concert pitch* (pitch soante), dentro de ±20 cents do nominal (afinação
acústica normal). Nenhum arquivo foi renomeado nem transposto.

## Tabela token → AIFF de origem

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

O conjunto é a união exata dos `audioSampleRefs` de `catalog_v1.json` (raízes
C4–C5, topo até D5). Nenhum arquivo a mais; nenhum a menos. Inclui as amostras
usadas pelos estágios `resolution` (`sax_g4 sax_b4 sax_d5 …`) — os mesmos 14
tokens cobrem tudo.

## Receita de conversão

Um-off, **fora do CI**. Requer `ffmpeg` (testado com o build do sistema em
`/usr/bin/ffmpeg`) e a pasta de origem em `~/Downloads/AltoSax.NoVib.ff.stereo/`.

Formato-alvo, idêntico entre as 14: **WAV PCM 16-bit, mono, 44,1 kHz**, ≤ 2,5 s,
loudness por EBU R128 (`I=-16 LUFS / TP=-1.5 dBTP / LRA=11`), fade-out de 40 ms na
cauda, ataque intacto.

### Cadeia de filtros (uma nota)

```
ffmpeg -y -i AltoSax.NoVib.ff.C4.stereo.aif \
  -af "atrim=end=2.5,loudnorm=I=-16:TP=-1.5:LRA=11,aformat=channel_layouts=mono,afade=t=out:st=2.46:d=0.04" \
  -ar 44100 -ac 1 -c:a pcm_s16le assets/audio/sax_c4.wav
```

**Ordem dos filtros:** `atrim` vem **antes** de `loudnorm`. As 14 fontes têm
2,77–3,54 s; cortar a cauda primeiro garante duração de saída de exatamente
2,500 s e **nunca** toca no ataque. (Com `loudnorm` antes de `atrim`, o atraso de
lookahead do limitador de true-peak empurra o PTS e o `atrim=end=2.5` acaba
comendo 40–60 ms do início — por isso a ordem invertida em relação ao exemplo da
spec-1-3b.) `loudnorm` roda em passagem única — suficiente para material curto e
o objetivo é igualar *loudness percebido*, não peak. `aformat=channel_layouts=mono`
faz o downmix estéreo→mono (espacialização não ajuda treino de ouvido e dobra o
tamanho). `afade` suaviza os últimos 40 ms para não haver clique no corte.

### Script de lote

O laço sobre os 14 tokens está preservado em
`_bmad-output/implementation-artifacts/spec-1-3b-…` e foi executado uma vez a
partir de um script equivalente a:

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

## Verificação da saída

```
for f in assets/audio/*.wav; do
  ffprobe -v error -show_entries stream=channels,sample_rate,codec_name \
    -show_entries format=duration -of default=nw=1 "$f"
done
```

Esperado, 14×: `codec_name=pcm_s16le`, `channels=1`, `sample_rate=44100`,
`duration=2.500000`. Loudness medido (`volumedetect`): RMS ≈ −19 a −21 dB,
pico de amostra ≈ −10 a −12 dB — consistente entre as notas (o objetivo do
`loudnorm`).

O teste `test/audio_assets_bundle_test.dart` fecha o loop no lado do app (job
`gates`): cada `audioSampleRef` do catálogo real resolve para um `.wav`
carregável pelo `rootBundle`, o cabeçalho RIFF/WAVE de cada um é PCM / mono /
44,1 kHz / 16-bit com payload `data` ≤ 220500 bytes (≤ 2,5 s), e não há arquivo
órfão em `assets/audio/`.

## Checksums (SHA-256)

`sha256sum assets/audio/*.wav` — gerados junto com os arquivos (2026-09-02):

| token | SHA-256 |
|---|---|
| `sax_a4.wav`  | `d94b9a331a7e0b5eed733b0ea759b978165fcc84cf1afbb45b8465521ed74fd6` |
| `sax_ab4.wav` | `055d48752fde0ec31ab82005f13a856104754643e846f5c5ab4083c29b8767ec` |
| `sax_b4.wav`  | `5d1218518990adc92afa52f2d312bddcedfa21d743a666af39ecc3d59a7bc4f1` |
| `sax_bb4.wav` | `6048a052f8d2227f9cbdef48f835ca8d579f044edf50516848ff2166c2ddf30c` |
| `sax_c4.wav`  | `7461048cda524e5081b9682d13a5471ea43b84deb03d0f48a0f7497b0db79232` |
| `sax_c5.wav`  | `c4785131710b08790498bee6e21fb7fa790c2d814c1b71b7d1185f06e3c17446` |
| `sax_d4.wav`  | `44302eee2f16c34f8a2574d35beae48a102d0c73b43b87395f9913afd87c83ce` |
| `sax_d5.wav`  | `f63a9e9393f7fae78b83efbc12bf6210fc2d45048a2ccb1bebf1eb2eb5f60947` |
| `sax_db4.wav` | `1e43511eece9fd4e07d75e2fafbb81d0c75547358d5ac4b4042ebbd6de452c11` |
| `sax_e4.wav`  | `0a53a08e7e995bde9e84fc2e80185a5009b2966f883437afd11c5ed6739492de` |
| `sax_eb4.wav` | `27da54918753b4daf454845634a977c382c881b7ce189e92c7653e2d0c2369fb` |
| `sax_f4.wav`  | `e27ea509fa46a75050df6e4d33aea3b3716cc0c9706014b0581b0a54e94916c1` |
| `sax_g4.wav`  | `ca71b20391ed8aa129cfde445de8eeffb3c9813b0abf962627a4dafa7a5a2b02` |
| `sax_gb4.wav` | `38493325e13ffa3ac4998d3de461adfd7ed3f720306a2cbb7664731fb1f65778` |
