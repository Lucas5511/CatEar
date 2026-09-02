---
purpose: "De onde vem cada áudio do CatEar, com licença e risco comercial"
status: draft
created: 2026-09-01
---

# Sourcing de áudio — CatEar

Quatro baldes. A coluna **Comercial** importa: monetização é Open Question do PRD,
então nada que bloqueie uso comercial deve virar dependência crítica.

## Balde 1 — Timbre dos exercícios (FR-2, Story 1.3b)

> **✅ RESOLVIDO (Story 1.3b, 2026-09-02).** Os 14 `.wav` da v1 (sax alto Iowa MIS,
> NoVib ff, mono 44,1 kHz, normalizados por R128) estão em `assets/audio/`.
> Proveniência, licença Iowa MIS verbatim, detentor do copyright (Lawrence Fritts,
> University of Iowa Electronic Music Studios), tabela token→AIFF e a receita de
> conversão exata: **`docs/audio/samples-v1.md`**. O texto abaixo é o material de
> pesquisa original que levou a essa decisão.

### O que temos agora — sax alto (preferido) + flauta (alternativo)

**University of Iowa MIS — AltoSax, ff, estéreo.** Duas pastas:
`~/Downloads/AltoSax.NoVib.ff.stereo/` e `~/Downloads/AltoSax.vib.ff.stereo/` (33 notas cada).

- **Faixa: D3–Ab5** cromático — cobre bem as raízes (D3–C5) e passa do topo (C6 só
  chegando via intervalo). Melhor extremo grave que a flauta.
- **Formato:** AIFF, 44,1 kHz, **estéreo**, ~3,75 s por nota (sustentado, ótimo — o
  usuário queria 2–3 s). Converter para **WAV mono** (spatialização não ajuda treino
  de ouvido e dobra o tamanho).
- **Monofônico** (como a flauta) — acordes/cadências: empilhar 3 notas.

#### ✅ Verificação de transposição — feita (2026-09-01)

`experiments/meow-sampler/verify_pitch.py` rodado nas duas pastas:
**32/32 arquivos com offset +0 semitons em cada** → os nomes **já estão em pitch soante**
(concert pitch), não em pitch escrito. **Nada a renomear.** Detecção dentro de ±20 cents
do nominal (afinação acústica normal; leve tendência a subir no registro agudo).

#### Licença — mais amigável que a Philharmonia

University of Iowa MIS: as gravações são disponibilizadas **livres para uso**, inclusive
em trabalho comercial derivado (só pedem não redistribuir a coleção crua). Bem mais
segura que a Philharmonia para lançamento. **Ainda assim: verificar a página oficial e
guardar o texto da licença no repo.** Se quiser risco zero, VSCO2 CE (CC0) continua a
recomendação final.

#### Vibrato vs. sem vibrato — ideia pedagógica

- **Sem vibrato = timbre padrão dos exercícios.** Pitch limpo e inequívoco, ideal para
  iniciante ouvir o intervalo.
- **Com vibrato = variação avançada.** Música real tem vibrato; ele **dificulta** o
  reconhecimento de pitch. Introduzir nos estágios mais avançados do skill tree como um
  **"andaime de timbre" que desvanece** — paralelo ao andaime de cor (FR-14): começa
  com o tom mais fácil de ler e vai ficando realista. Alimenta também a variação
  anti-decoreba (FR-6) e a dificuldade adaptativa (FR-7).

### Alternativo — flauta (Philharmonia)

`~/Downloads/Woodwind/flute/` (879 MP3).

- **Faixa:** C4–C7 (a flauta não desce abaixo de C4) — extremo grave pior que o sax.
- **Monofônica** — mesma limitação de acordes do sax.
- **Subconjunto útil:** `flute_<NOTA>_15_mezzo-forte_normal.mp3` (1,5 s), articulação
  `normal`. Esticar para 2–2,5 s com `rubberband`.
- **Formato:** MP3 (~200 kbps) → WAV mono 44,1 kHz, normalizar.
- **Uso:** timbre alternativo. Ter 2 timbres (sax + flauta) já ajuda a variação
  anti-decoreba (FR-6).

### ⚠️ Licença Philharmonia — risco comercial

Livre para uso comercial **em obra musical criativa** (álbum, filme, etc.), sem
royalties — **mas** as amostras **não podem ser vendidas/distribuídas "as is", como
amostras ou como instrumento de sampler**.
[philharmonia.co.uk/resources/sound-samples](https://www.philharmonia.co.uk/resources/sound-samples/)

Um app de treino de ouvido que toca notas isoladas ao apertar um botão está **na
fronteira de "instrumento de sampler"**. Envolver as notas num fraseado curto (FR-2 já
pede contexto musical) ajuda o argumento de "uso criativo", mas é fino.

**Veredito:** ok para o protótipo e fase de aprendizado. **Para lançamento comercial:**
trocar por fonte CC0 (abaixo) ou obter permissão escrita da Philharmonia.

### Substituto CC0 para o lançamento — recomendado

| Fonte | Licença | O que tem |
|---|---|---|
| **VSCO 2 Community Edition** (Versilian Studios) | **CC0** | Orquestra completa — flauta, piano, cordas, etc. Zero atribuição, comercial livre. **A resposta.** |
| **Versilian Community Sample Library (VCSL)** | **CC0** | Multi-instrumento, mesma casa |
| **Sonatina Symphonic Orchestra** | CC Sampling Plus | Comercial ok |
| **University of Iowa MIS** | "free of copyright" (verificar redistribuição) | Notas cromáticas isoladas, gravação limpa |

Melhor caminho: **SoundFont CC0** (VSCO2 tem SF2) + `fluidsynth` renderizando as notas
cromáticas offline → um instrumento, todas as notas, afinação perfeita, licença
inequívoca, e resolve polifonia (acordes/cadências) de graça.

## Balde 2 — Corpus de voz (spike 3.1, Etapa 0)

Pulado por enquanto (decisão do usuário). Não vai pro app — não tem questão de licença
para o produto, só para eventual publicação do relatório do spike.

## Balde 3 — Camada do mascote (gato)

| Arquivo | freesound | Licença | Uso |
|---|---|---|---|
| `203121__npeo__kitty-meow` | [/s/203121](https://freesound.org/s/203121/) | **CC-BY** (creditar "Npeo") | miado agudo ~G5, glissando |
| `333916__lextrack__cat-meowing` | [/s/333916](https://freesound.org/s/333916/) | **CC0** (comercial livre, sem atribuição) | miado curto ~1,4 s |

Ambos servem para os momentos do mascote (demonstrar, celebrar, feedback), **não** como
timbre dos exercícios (miado é agudo e glissando demais). Manter um `ATTRIBUTIONS.md`
para o de CC-BY; para lançamento comercial, priorizar o CC0 e/ou **gravar um gato real**
(seu ou de conhecido) — aí você é dono de tudo.

## Balde 4 — Sons de UI (acerto, erro, marco, toque)

Ninguém mapeou ainda. Tom gentil (`EXPERIENCE.md`: sem buzzer, sem vermelho sonoro).

| Fonte | Licença | Nota |
|---|---|---|
| **Kenney.nl** (audio packs: "UI Audio", "Interface Sounds") | **CC0** | Feito para jogos/apps, comercial livre, sem atribuição. **Primeira parada.** |
| **freesound** filtrado por CC0 | CC0 | `success chime`, `soft ding`, `kalimba`, `pop`, `gentle error` |
| **ZapSplat** | grátis c/ atribuição, ou pago sem | comercial ok |
| **Sonniss GDC Game Audio Bundle** | royalty-free, comercial | grátis todo ano, gigante |
| **Mixkit** | licença própria, comercial livre | efeitos de UI e conquista |

Evitar: `buzzer`, `alarm`, `error harsh`, `wrong answer game show`.

## Onde pegar áudio para uso comercial — resumo

1. **CC0 é o padrão-ouro** (sem atribuição, sem risco): Kenney.nl, VSCO2 CE, VCSL,
   freesound (filtro CC0), Wikimedia Commons, archive.org (verificar item a item).
2. **CC-BY** aceitável com `ATTRIBUTIONS.md` no app (tela "Créditos" em Settings).
3. **Bibliotecas royalty-free por assinatura** (contrato comercial explícito):
   Epidemic Sound, Artlist, Soundstripe — caro, mas cobre tudo com licença clara.
4. **Avulso royalty-free:** Pond5, Envato/AudioJungle, Soundsnap — por clipe.
5. **Bundles grátis royalty-free:** Sonniss GDC (anual), GameDev Market free section.
6. **Evitar sempre:** CC-BY-**NC** (proíbe comercial), "free sample libraries" de
   orquestras/estúdios cuja licença proíbe redistribuir a amostra crua (Philharmonia,
   às vezes Iowa) — a menos que fique só no protótipo.
7. **Mais seguro de todos:** gravar/encomendar você mesmo → propriedade total.

## Ações

| Quando | Ação |
|---|---|
| ~~Verificação de transposição~~ | ✅ feita — nomes em pitch soante, nada a renomear |
| ~~Balde 1 — conjunto v1~~ | ✅ feito (Story 1.3b) — 14 `.wav` sax NoVib em `assets/audio/`; ver `docs/audio/samples-v1.md` |
| Protótipo (agora) | Sax NoVib como timbre padrão (D3–Ab5), sax vib como variação avançada, flauta como 2º timbre. Empilhar 3 notas p/ acordes/cadências. Converter AIFF/MP3 → WAV mono 44,1 kHz normalizado. Gato: os dois arquivos. |
| Antes do lançamento comercial | Confirmar licença Iowa MIS por escrito **ou** migrar timbre para VSCO2 CE (CC0). UI: Kenney.nl CC0. Consolidar `ATTRIBUTIONS.md`. |
| `content-model.md` | Registrar "andaime de timbre" (NoVib → vib) como scaffold que desvanece, paralelo ao FR-14 |
