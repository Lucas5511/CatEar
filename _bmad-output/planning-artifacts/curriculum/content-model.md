---
purpose: "Taxonomia canônica de teoria musical do CatEar — fonte de verdade para o catálogo (AR-8), a taxonomia de ErrorType (AR-4) e o módulo de Resolução (FR-15)"
status: draft
created: 2026-09-01
sources:
  - "/home/clapthesun/Sync/Lucas Brain/Música/Teoria Músical/ (notas Obsidian do usuário)"
  - "../architecture/architecture-CatEar-2026-08-26/ARCHITECTURE-SPINE.md (AD-4)"
  - "../../implementation-artifacts/note-scope.md"
---

# Modelo de conteúdo — teoria musical do CatEar

Destila as notas de teoria do usuário (`Intervals.md`, `Chords.md`, `Cadence.md`,
`Notes & Scales.md`, `Minor scales.md`, `Modes.md`, `Circle of Fifths.md`, `Keys/*`)
na taxonomia que o **catálogo de currículo** (AR-8) usa. O que é código: nada disto —
tudo vira dado no JSON versionado. `ExerciseType` e `ErrorType` são definidos **só aqui
e no módulo Currículo** (AR-8).

> **Fora de escopo** (decisão de PRD — o produto não ensina técnica de instrumento):
> `Guitar.md`, os diagramas de braço nos `Keys/*`, tablatura. Aproveitamos desses
> arquivos só a soletração de escala/acordes por tonalidade.

---

## 1. Intervalos

Base: `Intervals.md`. Os 13 intervalos "de C", com nome PT-BR para a UI.

| Semitons | id (`ErrorType`/`interval`) | Nome UI (PT) | Abrev. | Qualidade | v1? |
|---|---|---|---|---|---|
| 0 | `P1` | uníssono justo | P1 | justo | Estágio 1 |
| 1 | `m2` | segunda menor | 2m | menor | Estágio 3 |
| 2 | `M2` | segunda maior | 2M | maior | Estágio 3 |
| 3 | `m3` | terça menor | 3m | menor | Estágio 2 |
| 4 | `M3` | terça maior | 3M | maior | Estágio 2 |
| 5 | `P4` | quarta justa | 4J | justo | Estágio 4 |
| 6 | `TT` | trítono (4ª aum. / 5ª dim.) | TT | — | Estágio 7 |
| 7 | `P5` | quinta justa | 5J | justo | Estágio 1 |
| 8 | `m6` | sexta menor | 6m | menor | Estágio 5 |
| 9 | `M6` | sexta maior | 6M | maior | Estágio 5 |
| 10 | `m7` | sétima menor | 7m | menor | Estágio 6 |
| 11 | `M7` | sétima maior | 7M | maior | Estágio 6 |
| 12 | `P8` | oitava justa | 8J | justo | Estágio 1 |

**Direção:** ascendente e descendente são variações do mesmo `interval` (campo
`direction: asc | desc`), não tipos separados. Descendente entra a partir do Estágio 2.

**Inversões** (`Intervals.md`): número + inversão = 9; maior↔menor; justo→justo;
aum↔dim. Não é tipo de exercício na v1 — é conteúdo de uma tela de explicação do
mascote (ex: "a 6ª menor é a 3ª maior de cabeça pra baixo").

**Intervalos compostos** (9ª–15ª): fora da v1. O schema aceita `semitones > 12`, mas
o catálogo v1 não os usa.

---

## 2. Taxonomia de ErrorType (AR-4 — `errorType` nunca é string livre)

`errorType` = **o que o usuário respondeu quando errou**, sempre um valor desta lista.
Para exercício de intervalo, é o `interval` id que ele escolheu por engano. Os pares
de confusão mais comuns, que a microcopy do mascote (FR-4) nomeia explicitamente:

| Confusão | `errorType` típico | Fala do mascote |
|---|---|---|
| 3ª maior ↔ 3ª menor | `M3` / `m3` | "Quase — você ouviu uma terça, mas era a **maior**, não a menor." |
| 4ª justa ↔ 5ª justa | `P4` / `P5` | "Perto! Confundiu a quarta com a quinta — a quinta é mais 'aberta'." |
| 6ª maior ↔ 6ª menor | `M6` / `m6` | idem terças |
| 7ª maior ↔ 7ª menor | `M7` / `m7` | "A sétima maior 'puxa' pra tônica; a menor não." |
| 2ª maior ↔ 2ª menor | `M2` / `m2` | "A segunda menor é a mais 'apertada' que existe." |
| Trítono ↔ 4ª/5ª | `TT` / `P4` / `P5` | "Esse é o trítono — o intervalo 'instável' por excelência." |
| erro de oitava (mesma classe de nota) | `octave-error` | "Nota certa, oitava errada." |
| totalmente fora | `far-miss` | sem nomear confusão específica — fallback da Story 1.6 |

Para acordes/escalas, `errorType` usa os ids da §3/§4 (ex: respondeu `minor` quando
era `major`).

---

## 3. Acordes

Base: `Chords.md`.

| id (`chordQuality`) | Nome UI (PT) | Intervalos | Gaps (semitons) | v1? |
|---|---|---|---|---|
| `major` | tríade maior | M3 + P5 | 4-3 | Estágio de acordes v1 |
| `minor` | tríade menor | m3 + P5 | 3-4 | Estágio de acordes v1 |
| `diminished` | tríade diminuta | m3 + d5 | 3-3 | pós-v1 |
| `augmented` | tríade aumentada | M3 + A5 | 4-4 | pós-v1 |
| `dominant7` | dominante com sétima | M3 P5 m7 | 4-3-3 | pós-v1 |
| `major7` | maior com sétima | M3 P5 M7 | 4-3-4 | pós-v1 |
| `minor7` | menor com sétima | m3 P5 m7 | 3-4-3 | pós-v1 |

**v1:** só `major` e `minor`, posição fundamental. Inversões e 7ªs pós-v1 (o schema
já prevê `inversion: 0|1|2` e a lista acima).

---

## 4. Escalas

Base: `Notes & Scales.md`, `Minor scales.md`, `Modes.md`.

| id (`scaleType`) | Nome UI (PT) | Fórmula (semitons) | v1? |
|---|---|---|---|
| `major` (Jônio) | escala maior | 2-2-1-2-2-2-1 | Estágio de escalas v1 |
| `natural_minor` (Eólio) | menor natural | 2-1-2-2-1-2-2 | Estágio de escalas v1 |
| `harmonic_minor` | menor harmônica | 2-1-2-2-1-3-1 | pós-v1 |
| `melodic_minor` | menor melódica (asc) | 2-1-2-2-2-2-1 | pós-v1 |
| `dorian` … `locrian` | modos | ver `Modes.md` | pós-v1 |
| `major_pentatonic` / `minor_pentatonic` | pentatônicas | 2-2-3-2-3 / 3-2-2-3-2 | pós-v1 |

**v1:** `major` e `natural_minor`, uma oitava, ascendente + descendente.

### Graus da escala (para microcopy — `Notes & Scales.md`)

1 tônica · 2 supertônica · 3 mediante · 4 subdominante · 5 dominante · 6 submediante ·
7 subtônica (2 semitons abaixo) / sensível (1 semitom abaixo) · 8 tônica (oitava).

Usado no feedback: "você cantou a **mediante**, o alvo era a **dominante**".

---

## 5. Cadências — módulo de Resolução (FR-15)

Base: `Cadence.md`.

| id (`cadence`) | Nome UI (PT) | Progressão | Sensação | v1? |
|---|---|---|---|---|
| `authentic` | cadência perfeita / autêntica | V → I | resolução total | **v1 — o alívio principal** |
| `plagal` | cadência plagal ("amém") | IV → I | resolução suave | v1 (segundo exemplo) |
| `half` | meia cadência | I/ii/IV → V | suspenso, pergunta | pós-v1 |
| `deceptive` | cadência de engano | V → vi | "ia resolver e não resolveu" | pós-v1 |

**v1:** o exercício de Resolução toca a tensão (V, ou ii–V) e pede o usuário cantar a
**tônica** (grau 1) da resolução. `authentic` é o núcleo; `plagal` como contraste.
`deceptive` é ótimo material pós-v1 — ensina a expectativa justamente quebrando-a.

O `demo_cadencia_resolucao.wav` do experimento já toca ii–V–I.

---

## 6. Tonalidade e transposição

Base: `Circle of Fifths.md`, `Keys/*`.

- **Material embarcado:** Dó maior / Lá menor (soletração canônica em `Keys/C.md`:
  I C, ii Dm, iii Em, IV F, V G, vi Am, vii° Bdim).
- **Transposição em runtime** gera a variação de tonalidade que a FR-6 (anti-decoreba)
  exige, sem multiplicar amostras — desloca os índices de semitom, reusa o set de 37
  notas de piano da Story 1.3b.
- O **círculo de quintas** não é exercício na v1. Pós-v1: tela visual de progressão
  (nó avançado do skill tree) e/ou seletor de tonalidade nas configurações.
  Mnemônicos das notas: *Father Charles Goes Down And Ends Battle* (♯) / inverso (♭).

### Andaime de timbre (paralelo ao FR-14)

Além do andaime de cor (FR-14), o **timbre** também é um andaime que desvanece:

| Fase | Timbre | Por quê |
|---|---|---|
| Estágios iniciais | Nota **sem vibrato** (sax NoVib / flauta `normal`) | pitch estável e inequívoco — o iniciante ouve o intervalo, não a flutuação |
| Estágios avançados | Nota **com vibrato** | música real tem vibrato; reconhecer sob condição realista é o objetivo final |

Campo no catálogo: `timbreScaffold: clean | vibrato` por estágio, não-crescente em
"limpeza" ao longo dos estágios (mesma lógica de invariante do `scaffoldIntensity`).
Também serve à variação anti-decoreba (FR-6) e à dificuldade adaptativa (FR-7).

---

## 7. Mapa para os estágios do skill tree

Consolida a §3 do `note-scope.md` com esta taxonomia:

| Estágio | Conteúdo | Tipos |
|---|---|---|
| 1 | Uníssono, 8ª justa, 5ª justa (asc) | `interval`: P1, P8, P5 |
| 2 | 3ª maior vs. 3ª menor (asc + desc) | `interval`: M3, m3 |
| 3 | 2ª maior vs. 2ª menor | `interval`: M2, m2 |
| 4 | 4ª justa (contraste com 5ª) | `interval`: P4 |
| 5 | 6ª maior vs. 6ª menor | `interval`: M6, m6 |
| 6 | 7ª maior vs. 7ª menor | `interval`: M7, m7 |
| 7 | Trítono | `interval`: TT |
| — Escalas — | maior, menor natural (1 oitava, asc + desc) | `scale`: major, natural_minor |
| — Acordes — | tríade maior vs. menor | `chord`: major, minor |
| — Resolução — | V→I (e IV→I), cantar a tônica | `cadence`: authentic, plagal |

Ordem exata dos blocos de escala/acorde/resolução vs. os estágios de intervalo:
decisão de design de currículo (o `order` do catálogo). Sugestão: Resolução cedo
(FR-15 pede "estágios iniciais"), acordes depois do Estágio 2 (precisa de 3ªs),
escalas depois do Estágio 3.

---

## 8. Forma sugerida no catálogo JSON (estende AR-8)

```json
{
  "stages": [
    {
      "stageId": "s1-consonancias",
      "order": 1,
      "exercises": [
        {
          "exerciseType": "interval",
          "interval": "P5",
          "direction": "asc",
          "audioSampleRefs": ["piano_c4", "piano_g4"],
          "scaffoldIntensity": 0.8
        }
      ]
    }
  ],
  "intervalCatalog": [
    { "id": "M3", "semitones": 4, "nameUi": "terça maior", "abbr": "3M", "quality": "major" }
  ],
  "chordCatalog": [
    { "id": "major", "nameUi": "tríade maior", "intervals": [4, 7], "inversion": 0 }
  ],
  "scaleCatalog": [
    { "id": "major", "nameUi": "escala maior", "steps": [2,2,1,2,2,2,1] }
  ],
  "cadenceCatalog": [
    { "id": "authentic", "nameUi": "cadência perfeita", "degrees": ["V", "I"] }
  ],
  "errorTypes": [
    "P1","m2","M2","m3","M3","P4","TT","P5","m6","M6","m7","M7","P8",
    "major","minor","diminished","augmented",
    "octave-error","far-miss"
  ]
}
```

`errorTypes` é a taxonomia canônica única (AR-8) — a UI de múltipla escolha e o
`errorType` do `SessionResultReported` só usam valores daqui.

---

## Resumo acionável

| Consumidor | O que tirar |
|---|---|
| **Catálogo AR-8 / Story 1.2** | Adicionar `intervalCatalog`, `chordCatalog`, `scaleCatalog`, `cadenceCatalog` ao schema; `errorTypes` expandido para a lista da §8 |
| **Story 1.6 (feedback)** | Microcopy dos pares de confusão da §2; graus de escala da §4 para "você cantou a mediante…" |
| **Story 3.5 (Resolução)** | `authentic` (V→I) é o núcleo; pedir a tônica cantada; `plagal` como contraste |
| **note-scope.md** | Os 7 estágios da §7 substituem/detalham a tabela de estágios de lá |
| **Roadmap pós-v1** | modos, menor harmônica/melódica, 7ªs, dim/aug, inversões, cadências half/deceptive, círculo de quintas visual, seletor de tonalidade |
