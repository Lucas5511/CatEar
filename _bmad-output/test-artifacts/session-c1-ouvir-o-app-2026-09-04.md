---
type: exploratory-session
charter: C1 — ouvir o app
date: 2026-09-04
explorador: Clapthesun (escuta) + Murat (medição de follow-up)
ambiente: emulador pixel API 35 · build profile · PipeWire → Behringer UMC202HD 192k
build: 9e0adfe
status: 2 achados confirmados, 1 pendente de A/B
---

# Sessão C1 — ouvir o app

## O que foi feito

App instalado em build `--profile` no emulador `pixel` (API 35) e percorrido o
fluxo de prática. Volume de mídia do Android estava em **5/15** e foi subido para
14 antes da escuta — vale registrar porque qualquer sessão futura começa com o
mesmo padrão baixo.

Saída de áudio: PipeWire → sink padrão `UMC202HD 192k` (interface Behringer). A
cadeia foi verificada ativa (`qemu-system-x86_64 → UMC202HD:playback [active]`)
antes de julgar qualquer coisa.

## O que foi observado

> "o áudio está um pouco saturado" → corrigido pelo explorador para
> **"não é saturado e sim com um chiado"**.

A correção importa: as duas hipóteses levam a diagnósticos opostos, e a primeira
rodada de medição (procurando clipping) partiu da palavra errada. Vale como nota
de método — pedir a descrição do som antes de medir.

## Medições de follow-up

Todas sobre `assets/audio/*.wav` no commit `9e0adfe`, com `ffmpeg astats` /
`ebur128`.

### Não é distorção, e não é ruído de gravação

| Métrica | Valor |
|---|---|
| Amostras clipadas | **0** |
| True peak | -11,2 dBFS |
| Piso de ruído (primeiros 100 ms, mudos) | **-88 a -81 dBFS** |
| SNR do derivado vs. fonte AIFF 24-bit | **idêntico** (~46 dB medido no mesmo trecho) |

A conversão 24-bit → 16-bit não degradou nada: o `loudnorm` aplicou ~4,2 dB de
ganho uniformemente em sinal e ruído. O arquivo em si é limpo.

### A-1 (provável) — o chiado é ruído de sopro do sax em `ff`

| Banda, durante a nota sustentada (1,0–1,5 s) | RMS |
|---|---|
| nota inteira | -17,8 dBFS |
| **> 8 kHz** | **-51,3 dBFS** (33 dB abaixo) |
| > 12 kHz | -57,9 dBFS (40 dB abaixo) |

Energia banda-larga de alta frequência montada sobre o tom — ar passando pela
palheta. Característico de saxofone em *fortissimo*, que é exatamente a dinâmica
da fonte (`AltoSax.NoVib.**ff**`).

**PENDENTE DE CONFIRMAÇÃO.** A cadeia de reprodução (emulador reamostrando
44,1 kHz → interface a 192 kHz) é suspeita alternativa. O A/B decisivo é
`pw-play assets/audio/sax_c4.wav` direto no host: chiado presente nos dois =
arquivo; ausente no `pw-play` = emulador. **Não rerenderizar nada antes disso.**

### A-2 (confirmado) — silêncio variável no início de toda amostra

Achado de raspão, não estava no charter. Medido por varredura de RMS em janelas
de 20 ms:

| ms até o ataque | amostras |
|---|---|
| 180 | `sax_c5` |
| 200 | `sax_c4`, `sax_d4` |
| 220 | `sax_d5` |
| 240 | `sax_ab4`, `sax_bb4` |
| 260 | `sax_b4`, `sax_db4`, `sax_e4`, `sax_f4`, `sax_g4` |
| 300 | `sax_eb4`, `sax_gb4` |
| **320** | **`sax_a4`** |

O `PhrasePlayer` dispara as notas a cada **450 ms**. Consequências:

- cada nota **soa por 130–270 ms**, não pelos 450 ms projetados;
- o **spread de 140 ms** entre amostras faz o ritmo do motif mudar conforme quais
  notas o exercício sorteia — dois exercícios com o mesmo desenho rítmico soam em
  andamentos diferentes;
- a nota final, que a Design Note da 1.4 diz segurar 900 ms, segura ~600;
- `_enabledAt` — a âncora do tempo de reação que o Epic 2 vai consumir — é fixada
  quando o motif "termina", mas o som real terminou antes.

**Causa raiz, registrada na própria spec-1-3b:** *"ataque preservado (sem
time-stretch, sem cortar o início)"*. A regra existia para proteger o transiente
de ataque; o efeito colateral foi manter o ar morto que o precede.

### A-3 (confirmado) — loudness não bateu o alvo documentado

`I = -19,0 LUFS` medido em `sax_c4`, `sax_g4` e `sax_d5`. O
`docs/audio/samples-v1.md` e a AC da spec-1-3b documentam **I = -16**. O
`loudnorm` de passagem única errou ~3 dB e nada verificou depois.

Não causa o chiado (está mais baixo, não mais alto), mas é uma AC declarada
cumprida sem medição.

### A-4 (confirmado) — URL da licença está morta

`https://theremin.music.uiowa.edu/MISsaxophone.html`, citada em
`docs/audio/samples-v1.md`, retorna **404**. A página migrou para
`MIS-Pitches-2012/MISEbAltoSaxophone2012.html`. O snapshot do Wayback que a
Story 1.3b guardou é o que preservou o registro da licença — a prática se pagou.

## Por que nada disso foi pego pela suíte

`test/audio_assets_bundle_test.dart` parseia o cabeçalho RIFF — `audioFormat`,
`numChannels`, `sampleRate`, `bitsPerSample`, tamanho do chunk `data` — e **nunca
olha o conteúdo PCM**. Um arquivo com 320 ms de silêncio, 3 dB fora do alvo de
loudness e ruído de sopro passa em todos os critérios.

Essa é a lacuna estrutural que a sessão expôs, e ela é fechável: onset, pico e
RMS são calculáveis a partir dos bytes que o teste já carrega.

## Perguntas e riscos

- O ruído de sopro pode ser desejável? Um timbre real tem ar. A questão é se ele
  atrapalha o reconhecimento de intervalo — que é o propósito do exercício.
- Se a dinâmica mudar para `mf`, as 14 amostras são rerenderizadas de uma fonte
  nova, e o A-2 sai junto de graça. Se não mudar, o A-2 ainda exige rerenderizar
  as 14.
- Iowa MIS oferece **pp, mf e ff** (confirmado na página índice da coleção), então
  a dinâmica mais suave é a mesma fonte, mesma licença, mesma receita.

## Tempo

Escuta ~20% · medição de follow-up ~70% · setup (volume, roteamento) ~10%.
