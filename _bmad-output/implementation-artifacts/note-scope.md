---
purpose: "Escopo de notas/registro do CatEar v1 — alimenta o spike 3.1 (Etapa 0), a Story 1.3b (amostras) e o catálogo AR-8"
status: draft
created: 2026-09-01
---

# Escopo de notas — CatEar v1

Três consumidores deste documento:

1. **Spike 3.1 / Etapa 0** — que faixa de f0 o detector de pitch precisa cobrir, e que notas o corpus de teste deve conter.
2. **Story 1.3b** — que amostras de instrumento real produzir.
3. **Catálogo de currículo (AR-8)** — que intervalos/acordes/escalas entram na v1 e em que ordem.

---

## 1. Faixa vocal (produção ativa — FR-3)

Fundamentais de canto por tipo de voz (notação científica, A4 = 440 Hz):

| Voz | Faixa | f0 |
|---|---|---|
| Baixo | E2–E4 | 82–330 Hz |
| Barítono | A2–A4 | 110–440 Hz |
| Tenor | C3–C5 | 131–523 Hz |
| Contralto | F3–F5 | 175–698 Hz |
| Mezzo | A3–A5 | 220–880 Hz |
| Soprano | C4–C6 | 262–1047 Hz |

Adulto **sem treino** canta ~1,5 oitava, centrado na fala (homens ~110 Hz, mulheres ~200 Hz). Fontes: [singing-bell.com](https://www.singing-bell.com/frequency-ranges-of-human-singing-voices/), [axiomaudio.com](https://www.axiomaudio.com/blog/audio-oddities-frequency-ranges-of-male-female-and-childrens-voices).

### Decisão de design que reduz o problema

CatEar é **ouvido relativo**. Nos exercícios de produção, o app toca uma nota de referência **na oitava confortável do usuário** (escolhida/confirmada no onboarding ou por calibração) e pede o intervalo a partir dela. O usuário nunca é obrigado a cantar um Dó4 absoluto — canta **a terça acima da nota que acabou de ouvir*, no registro dele. Isso mantém cada sessão numa janela estreita, mas **o detector, somando todos os usuários, ainda vê ~E2 a ~C6**.

### Requisito do detector (Etapa 0)

- **Faixa a rastrear:** f0 de **75 Hz a 1100 Hz**.
- O lado **grave é o difícil** para autocorrelação/YIN: em 82 Hz um período ≈ 12 ms ≈ 540 amostras @ 44,1 kHz. Precisa de ≥ 2–3 períodos por janela → **janela de análise ≥ 3072 amostras** (usar 4096). No agudo não há problema.
- Cuidado com **erro de sub-harmônico** (detectar f0/2): validar oitava pela energia dos harmônicos.

### Corpus de teste da Etapa 0

Notas-alvo cantadas (vogal "ah" sustentada, 1,5–2,5 s), por qualquer voz disponível — o que importa é cobrir a faixa:

| Faixa | Notas | f0 |
|---|---|---|
| Grave | E2, A2, C3 | 82 / 110 / 131 Hz |
| **Médio (onde a maioria canta)** | **E3, G3, A3, C4, E4** | 165 / 196 / 220 / 262 / 330 Hz |
| Agudo | G4, C5, E5 | 392 / 523 / 659 Hz |
| Muito agudo | A5 | 880 Hz |

Cada nota: 1× em silêncio + 1× com ruído de fundo moderado. Alvo mínimo: 8–10 arquivos cobrindo o médio + 2–3 nos extremos. `synth_meow.py --hz <freq> --glide 0` gera sinais de frequência exata para conferir o detector antes da voz real.

---

## 2. Registro dos exercícios de escuta (FR-2 → Story 1.3b)

Apps de treino de ouvido apresentam intervalos/acordes num **registro médio**.

> **Ajuste (2026-09-01):** timbre do protótipo é **sax alto** (Iowa MIS), faixa
> **D3–Ab5**; flauta (Philharmonia, C4–C7) como 2º timbre. Ver `audio-sourcing.md`.

- **Notas-raiz:** C4 a C5 (o sax cobre de D3, dá folga no grave).
- **Topo dos intervalos:** até ~C6.
- **Faixa de amostras:** sax **D3–Ab5** (33 notas), flauta **C4–C6**.
- **Polifonia:** sax e flauta são monofônicos — acordes e cadências (§3, §5 do
  content-model) exigem **empilhar 3 amostras** ou instrumento polifônico (VSCO2 CE
  piano, CC0, no lançamento).
- **Verificar transposição:** conferir o pitch real dos AIFF do sax antes de empacotar
  (nomes podem estar em pitch escrito, não soante).

### Amostras a produzir (Story 1.3b)

Opção recomendada: **37 notas cromáticas isoladas de um instrumento real**, e o app monta os intervalos/acordes/escalas em runtime (como o `make_demo.py` já faz). Menos assets, mais flexível para variações (FR-6).

- **Instrumento:** piano é o default seguro — ataque claro, pitch inequívoco, familiar a todos. (Guitarra/outros podem entrar como timbres alternativos depois.)
- **Cada nota:** ~2,5–3 s (o usuário pediu notas longas, fáceis de reconhecer), com decaimento natural.
- **Contexto musical (FR-2 exige "não notas isoladas"):** o app envolve as notas num fraseado curto — ex: toca a raiz, uma nota de passagem, e o alvo — em vez de dois bipes secos. Isso é lógica de apresentação, não asset.
- Formato: WAV mono, 44,1 kHz, loudness normalizado entre notas.

### Achado sobre o miado

O miado do Npeo tem f0 ≈ **G5 (~800 Hz)** — bem acima do registro dos exercícios (raízes C3–C5). Usá-lo como timbre de exercício exigiria descer 7 a 24 semitons → perda grande de qualidade. **Conclusão:** o miado serve para a camada do mascote (demonstrar, celebrar — momentos curtos, agudos), **não** como timbre dos exercícios-núcleo. Se quiser um "timbre de gato" nos exercícios, gravar/achar uma vocalização felina mais grave (ronronado, trinado).

---

## 3. Conteúdo do currículo v1 (AR-8)

> A taxonomia canônica completa (intervalos, acordes, escalas, cadências, `ErrorType`,
> forma do JSON) vive em **`../planning-artifacts/curriculum/content-model.md`**,
> destilada das notas de teoria do usuário. Esta seção é o resumo.

Ordem pedagógica: intervalos → escalas → acordes → progressões. Dentro de intervalos, do mais consonante/distinto para o mais ambíguo. Fontes: [musical-u.com](https://www.musical-u.com/learn/ultimate-guide-to-interval-ear-training/), [arkansasmta.org (currículo)](https://arkansasmta.org/wp-content/uploads/2021/11/15-Curriculum-Musicianship-EarTrainingAllLevels.pdf).

### Intervalos — todos os 13, introduzidos em estágios

| Estágio | Intervalos novos | Por quê |
|---|---|---|
| 1 | Uníssono, 8ª justa, 5ª justa | Os mais estáveis e fáceis de isolar |
| 2 | 3ª maior, 3ª menor | O par que define maior vs. menor — alto valor |
| 3 | 2ª maior, 2ª menor | Passo de escala; 2ª menor é a tensão |
| 4 | 4ª justa | Ambígua (fácil confundir com 5ª) |
| 5 | 6ª maior, 6ª menor | Inversões das 3ªs |
| 6 | 7ª maior, 7ª menor | 7ª maior = tensão de sensível |
| 7 | Trítono | O mais difícil — deixa por último |

Cada intervalo praticado **ascendente e descendente** (a partir do estágio 2). Em contexto musical, não par isolado (FR-2).

### Escalas v1

- Maior (Jônio)
- Menor natural (Eólio)
- Uma oitava, ascendente + descendente.
- (Modos, menor harmônica/melódica, pentatônicas → pós-v1.)

### Acordes v1

- Tríade maior (posição fundamental)
- Tríade menor (posição fundamental)
- (7ªs, diminuta, aumentada, inversões → pós-v1.)

### Módulo de Resolução (FR-15)

- **V → I** em maior (cadência autêntica) — o "alívio" mais forte.
- **ii → V → I** como extensão (é a cadência que o `demo_cadencia_resolucao.wav` já toca).
- Em Dó maior para o material embarcado; transpor em runtime para variação.

### Tonalidades

- Material embarcado: **Dó maior / Lá menor** (mantém o set de amostras em 37 notas).
- **Transposição em runtime** dá a variação de tonalidade que a FR-6 (anti-decoreba) precisa, sem multiplicar assets.
- Andaime de cor (FR-14): consonância/dissonância independe de tonalidade, então não afeta o set.

---

## Resumo acionável

| Consumidor | O que tirar daqui |
|---|---|
| **Spike 3.1 / Etapa 0** | Detector cobre f0 75–1100 Hz; janela ≥ 4096 amostras; corpus de ~12 arquivos cantados (tabela §1); guarda contra erro de oitava |
| **Story 1.3b** | Protótipo: ~25 notas de flauta C4–C6 (Philharmonia, `_15_mezzo-forte_normal`), WAV mono 44,1 kHz normalizado, empilhar 3 p/ acordes. Lançamento: migrar p/ VSCO2 CE (CC0). Ver `audio-sourcing.md` |
| **Catálogo AR-8** | 13 intervalos em 7 estágios (tabela §3); escalas maior + menor natural; tríades maior + menor; Resolução V–I e ii–V–I; embarcado em Dó, transpõe em runtime |
| **Produto** | Miado só na camada do mascote (agudo, curto), não nos exercícios-núcleo |
