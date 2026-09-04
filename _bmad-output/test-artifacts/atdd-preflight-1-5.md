---
type: atdd-preflight
story: "1.5"
story_title: Exercícios de reconhecimento de acordes e escalas
date: 2026-09-03
author: Murat (TEA)
status: decisions-taken
---

# Preflight do ATDD — Story 1.5

O passo 1 do `bmad-testarch-atdd` exige uma story com ACs aprovadas. A 1.5 não
tem spec: as ACs vivem só no `epics.md`. Antes de decidir se isso bloqueia, fiz
a análise do action item **S1** ("a spec da 1.5 deve conter a extração dos slots
type-agnostic do `ExerciseCard`").

Ela derrubou a premissa do próprio S1, e encontrou três coisas que precisam ser
decididas antes de qualquer teste vermelho.

## O S1 aponta para o lugar errado

O S1 (e o item correspondente no `deferred-work.md`) diz para extrair "slots
type-agnostic do `ExerciseCard`". Mas `ExerciseCard` **já é type-agnostic** — é
um `Container` decorado que recebe um `child`. Não há nada de intervalo nele.

O acoplamento real está numa cadeia inteira abaixo dele:

| Peça | Acoplamento a intervalo | Nota |
|---|---|---|
| `ExerciseCard` | **nenhum** | já agnóstico; não é o problema |
| `PhrasePlayer.playMotif` | implícito | motif fixo `r0, r1, r0` — assume 2 notas |
| `IntervalPracticeState` | total | `loop: List<IntervalExercise>`, `pool`/`options`/`picked`: `List<IntervalSpec>`, `answer => current.interval` |
| `IntervalPractice` (notifier) | total | `intervalLoop` / `intervalPool` filtram por `IntervalExercise` |
| `intervalOptionsFor` | total | ranqueia distratores por `|Δsemitones|` — acorde e escala não têm `semitones` |
| `_ActiveExerciseViewState` | total | prompt fixo "Que intervalo é este?"; itera `s.options` como `IntervalSpec` |
| `_OptionButton` / `_ResultLine` | total | tipados em `IntervalSpec` |
| `ExerciseAttempt.errorTypeForIntervalId` | total | mapeia `IntervalSpec.id` → `ErrorType` |

O domínio, ao contrário, **já está pronto**: `sealed class Exercise` com
`IntervalExercise` / `ScaleExercise` / `ChordExercise` / `ResolutionExercise`,
e o catálogo v1 já traz 31 exercícios com `exerciseType` discriminado.

**Consequência para a spec:** o seam a extrair não é um slot de card, é um
**modelo de resposta type-agnostic** que a apresentação consome — algo como
`prompt` (a pergunta), `options` / `answer` (opções com `id` + `nameUi`),
`audioSampleRefs` e a **forma do motif**. Com isso, `_ActiveExerciseView` fica
sem nenhuma menção a `IntervalSpec`, e a diferença por tipo vira uma estratégia
por trás do modelo — que é exatamente o que a AC3 pede.

Reescrever o S1 nesses termos é pré-requisito da spec. Do jeito que está, um dev
pode "cumprir" o S1 mexendo no `ExerciseCard` e deixar a AC3 tão violada quanto
hoje.

## Três decisões que bloqueiam o teste vermelho

### D1 — Um acorde não pode soar como acorde com a v1

`AudioService.playSample` promete, por contrato, *"interrupts any sample still
playing"*, e a implementação tem **um** `AudioPlayer` que serializa mutações. As
14 amostras da v1 são notas individuais de sax. Logo, **simultaneidade é
arquiteturalmente impossível hoje** — uma tríade só pode sair arpejada.

A AC2 da 1.5 diz "o áudio é apresentado em contexto musical, não como bloco
isolado". Um arpejo é defensável musicalmente, mas tem de ser decisão, não
acidente. As saídas:

- **arpejo** — nada muda na stack de áudio; o "acorde" é ouvido como arpejo.
- **amostras pré-renderizadas de tríade** — trabalho de conteúdo tipo 1.3b (2
  qualidades × N fundamentais), zero mudança de código.
- **AudioService multi-voz** — quebra o contrato de `playSample` e o invariante
  de player único que as PRs #13/#14 acabaram de estabilizar.

### D2 — Acorde e escala não têm distratores suficientes para 4 opções

O `chordCatalog` da v1 tem **2 entradas** (`major`, `minor`); o `scaleCatalog`
tem **2** (`major`, `natural_minor`). A tela da 1.4 mostra 4 alternativas.

`intervalOptionsFor` já degrada sem quebrar ("returns as many distinct specs as
it can"), então um exercício de acorde renderiza **2 botões** — uma questão de
cara ou coroa, com 50% de acerto por chute. Isso contamina qualquer sinal de
habilidade que o Epic 2 for construir em cima das tentativas.

Saídas: aceitar 2 opções para esses tipos; ampliar os catálogos (`diminished` e
`augmented` **já existem em `errorTypes`** mas não têm entrada no
`chordCatalog`); ou tornar o número de opções função do pool, declaradamente.

### D3 — Não existe taxonomia de erro para escala

`errorTypes` tem 19 entradas: os 13 intervalos, mais `major`, `minor`,
`diminished`, `augmented`, `octave-error`, `far-miss`. As quatro de qualidade de
acorde servem para acorde. **Para escala não há nenhuma.**

A Story 1.6 (feedback explicativo) depende de `errorType` vir da taxonomia
canônica, "nunca string livre" (AR-4/AR-8). Se a 1.5 gravar tentativas de escala
sem `errorType`, a 1.6 nasce com um buraco por tipo — e `errorTypeForIntervalId`
usa `orElse: throw`, então um id sem par correspondente **quebra em runtime, no
meio da sessão**, fora do `AsyncValue.error` (já registrado no `deferred-work`).

## O que dá para testar independente das decisões

A AC3 é uma restrição estrutural e não depende de D1–D3. O teste vermelho dela é
escrevível hoje:

> Renderizar um `ChordExercise` e um `ScaleExercise` pela **mesma** árvore de
> widgets do fluxo de prática, e assertar que nenhum tipo específico de
> exercício aparece na camada de apresentação.

A parte "não aparece" é verificável de duas formas complementares: um teste de
widget que exercita os três tipos pelo mesmo caminho, e uma regra estática (no
estilo do `check_module_boundaries`) proibindo `IntervalSpec` / `IntervalExercise`
em `exercicios/presentation/`. A segunda é a que impede a cópia do
`_ActiveExerciseView` — um teste de widget passa feliz com o widget duplicado.

## Decisões tomadas (2026-09-03)

| # | Decisão | Escolha |
|---|---|---|
| D1 | apresentação do acorde | **pré-renderizar amostras de tríade** |
| D2 | pool de opções | **ampliar os catálogos** |
| D3 | taxonomia de erro de escala | **adicionar `errorTypes` de escala agora** |

### O que isso custa — bem menos do que parecia

**Acorde (D1 + D2):** não é problema de sourcing. As 14 notas de `assets/audio/`
já cobrem **20 tríades** — 4 qualidades × 5 raízes — e a coleção de origem
(Iowa MIS, 33 AIFFs, licença "may be downloaded and used for any projects,
without restrictions") continua disponível, com o tooling de conversão em
`experiments/meow-sampler/`.

| raiz | major | minor | diminished | augmented |
|---|---|---|---|---|
| C4  | c4+e4+g4 | c4+eb4+g4 | c4+eb4+gb4 | c4+e4+ab4 |
| Db4 | db4+f4+ab4 | db4+e4+ab4 | db4+e4+g4 | db4+f4+a4 |
| D4  | d4+gb4+a4 | d4+f4+a4 | d4+f4+ab4 | d4+gb4+bb4 |
| Eb4 | eb4+g4+bb4 | eb4+gb4+bb4 | eb4+gb4+a4 | eb4+g4+b4 |
| E4  | e4+ab4+b4 | e4+g4+b4 | e4+g4+bb4 | e4+ab4+c5 |

Cinco raízes importam: com raiz fixa em C4 o exercício vira reconhecimento de
altura absoluta, não de qualidade harmônica. `ffmpeg` está disponível e a mixagem
é determinística — mesma proveniência, mesma licença, um segundo passo de
derivação no `docs/audio/samples-v1.md`.

**Escala (D2):** **zero áudio novo**. Escala é sequência de notas isoladas, e os
modos que faltam cabem nas 14 amostras — C dórica (`c d eb f g a bb c5`) e C
mixolídia (`c d e f g a bb c5`) usam só tokens existentes. É mudança de catálogo.

**Erro de escala (D3):** taxonomia proposta, mapeada nos pares de confusão reais
(dona é a Curadoria de Currículo, não a TEA — isto é insumo, não decisão):

| `errorType` | grau | separa |
|---|---|---|
| `terca-alterada` | 3ª | maior/mixolídia × menor/dórica |
| `sexta-alterada` | 6ª | dórica × menor natural |
| `setima-alterada` | 7ª | maior × mixolídia |

`far-miss` (já existe) cobre o resto. Junto disso, `diminished` e `augmented`
ganham entrada no `chordCatalog` — hoje existem em `errorTypes` sem par.

## Consequência: a 1.5 ganhou um pré-requisito de conteúdo

Como a 1.3b precedeu a 1.4, a 1.5 agora precede-se de uma story de produção:
20 `.wav` de tríade + expansão de `chordCatalog`/`scaleCatalog`/`errorTypes` +
proveniência. É pequena (derivação de material já licenciado e já no repo), mas
é uma story, não um detalhe da 1.5 — e a lição da 1.3b/1.4 é que produção de
amostra e consumo de amostra não cabem no mesmo PR.

## Nota sobre o red phase e a branch protection

Com `gates`/`build-android`/`build-ios`/`e2e-android` obrigatórios desde
2026-09-03, **scaffolds vermelhos não podem ser mergeados no master**. Eles vivem
na branch da feature até ficarem verdes, ou entram marcados como `skip` com o
motivo. Não é limitação do ATDD — é a proteção funcionando.

## Sequência

1. Story de produção das tríades + expansão dos três catálogos.
2. Spec da 1.5, com o S1 reescrito em termos do **modelo de resposta
   type-agnostic** (não "slots do `ExerciseCard`", que já é agnóstico).
3. `bmad-testarch-atdd` completo sobre essa spec.
4. `bmad-build`.

O teste vermelho da AC3 é escrevível já, e independe de D1–D3: renderizar um
`ChordExercise` e um `ScaleExercise` pela mesma árvore de widgets, mais uma regra
estática proibindo `IntervalSpec`/`IntervalExercise` em `exercicios/presentation/`
— esta última é a que impede a cópia do `_ActiveExerciseView`, porque um teste de
widget passa feliz com o widget duplicado.
