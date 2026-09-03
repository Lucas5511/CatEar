---
type: session-retrospective
date: 2026-09-03
scope: Stories 1.3 → 1.4 + 4 PRs de correção
range: d7d878b..74e1acc
epic: 1
---

# Retro de sessão — 2026-09-03

Marco de sessão, não de épico. Cobre o fechamento da Story 1.3, a entrega da
1.3b e da 1.4, e as quatro PRs de correção que a 1.4 gerou.

## O que entrou

| PR | Entrega | Estado |
|---|---|---|
| #10 | Story 1.3b — 14 amostras de sax + proveniência/licença + testes F2/F7 | merged |
| #11 | Story 1.4 — primeira tela de exercício jogável | merged |
| #12 | Fix: ciclo de vida do `audioServiceProvider` + e2e do fluxo de prática | merged |
| #13 | Fix: serialização de `playSample` concorrente | merged |
| #14 | Fix: interrupção por tipo, `stop()` fora da fila, timeout na chain | merged |
| #15 | Chore: consolida `integration_test/` num arquivo (metade do build) | merged |

**Números:** 167 → **213** testes unitários; 8 → **15** e2e; `lib/exercicios/`
saiu de um barrel vazio para 6 arquivos; `assets/audio/` de um `.gitkeep` para
14 `.wav` versionados.

**Sprint:** 1.1, 1.2, 1.3, 1.3b `done`; 1.4 em `review`. Epic 1 segue
`in-progress` com 6 stories no backlog.

## O arco real da sessão

1. Validei o repo, fechei a 1.3, entreguei a 1.3b e a 1.4 pelo `bmad-build`
   (spec → implementação → review adversarial → PR).
2. O `/code-review` da 1.4 — **depois** dela já estar mergeada — achou um bug
   que impedia o exercício de tocar qualquer áudio no app real.
3. O e2e que adicionei para guardar esse bug **derrubou o CI e expôs um segundo
   bug**, diferente e mais antigo.
4. Minha correção do segundo bug **introduziu duas regressões próprias**, pegas
   por outro review.
5. Consolidei o `integration_test/` porque a estrutura do job era a causa de
   três merges seguidos com CI incompleto.

Três das quatro PRs de correção existem porque a 1.4 foi mergeada antes de ser
suficientemente exercitada. Isso é o achado central desta retro.

## O que funcionou

- **O e2e se pagou duas vezes no mesmo dia.** Dois bugs reais em duas execuções,
  ambos invisíveis para os 213 testes unitários.
- **Reproduzir antes de corrigir.** Não dava para reproduzir a corrida do CI
  localmente com os tempos reais. Forçá-la (gaps do motivo em 40/80 ms) deu um
  sinal vermelho→verde determinístico — e provou que a serialização **sozinha
  não bastava**. Sem isso eu teria enviado meio fix e declarado vitória.
- **Review em camadas diferentes acha bugs diferentes.** O review adversarial do
  `bmad-build` (3 revisores, 16 patches) **não viu** o bug do auto-dispose; o
  rastreador cross-file do `/code-review` viu. Não são substitutos.
- **Revisar o próprio fix.** A PR #13 trocou um bug barulhento por um silencioso.
  Só apareceu porque rodei review nela também.

## O que não funcionou

### 1. A suíte inteira fakeia o `AudioService` — uma classe inteira de bug era estruturalmente invisível

Todo teste de widget do exercício faz
`audioServiceProvider.overrideWithValue(FakeAudioService())`. Nenhum exercitava
o `_JustAudioService` real nem seu ciclo de vida. Resultado: **213 testes verdes
convivendo com "o exercício não toca áudio nenhum"**.

O fake também não modela a implementação real — ele serializa (última chamada
vence), então o contrato parecia cumprido enquanto a impl real corria.

### 2. Item deferido com dono nominal não se executa sozinho

A Story 1.3 deferiu, com texto explícito:

> `_JustAudioService.playSample`/`stop` não serializam chamadas concorrentes…
> Endurecer quando existir um consumidor real (Stories 1.4+). **owner: dev da 1.4.**

A 1.4 foi planejada, implementada, revisada e mergeada **sem tocar nisso** — e
foi exatamente o consumidor que quebrou por causa disso. O `deferred-work.md`
não é lido no planejamento da story que herda o item.

**Havia dois itens com "owner: dev da 1.4".** Um explodiu no CI. O outro
(`AudioSession` do iOS) **segue aberto**. Mesma falha de processo, duas vezes.

### 3. Merges antes do `e2e-android` fechar

As PRs #10, #11 e #13 foram mergeadas com o job incompleto ou vermelho. É assim
que os dois bugs chegaram em master. O job é lento e instável — mas a resposta
foi contorná-lo, não consertá-lo.

### 4. O job de e2e era estruturalmente frágil

`flutter test integration_test` compila um APK **por arquivo**. Dois arquivos =
dois builds Gradle de ~8 min num runner de 2 cores. Nos três merges anteriores o
job falhou no **segundo** build — emulador starved, e uma vez o runner foi morto
sem que um único teste rodasse. Nenhuma dessas falhas foi causada pelo código
sob teste. A #15 corta isso pela metade.

### 5. A 1.4 furou o action item #5 do próprio time

O retro do Epic 1 já dizia: *"Geração de E2E entra no DoD da story, não em PR de
follow-up"*. A 1.4 — a primeira tela real do app — foi mergeada com zero
cobertura e2e, e o e2e veio numa PR de follow-up. O item existia e foi ignorado.

## Dívida conhecida em aberto

- `ExerciseCard` é só estilo, não o seam type-agnostic que a AC da 1.4 promete
  para a 1.5. Se a 1.5 começar sem isso, o `_ActiveExerciseView` inteiro
  (captura de RT, trava de double-tap, corrida do advance, banner de áudio) é
  copiado.
- `AudioSession` do iOS — deferido da 1.3, dono "dev da 1.4", nunca feito.
- Achados de qualidade do `/code-review` da 1.4 (reuse / simplification /
  altitude / efficiency) registrados em `deferred-work.md`.
- Burn-in do `e2e-android` (action item #2 do Epic 1) — a #15 atacou o tempo
  estrutural, não a flakiness do emulador.

## Action items

| # | Ação | Dono |
|---|---|---|
| S1 | Spec da 1.5 **deve** conter a extração dos slots type-agnostic do `ExerciseCard` — não deixar o dev copiar o widget | dev da 1.5 |
| S2 | `bmad-build` step-01/02: ao planejar a story X, varrer `deferred-work.md` por itens com `owner: dev da X` e puxá-los para a spec | processo |
| S3 | Não mergear com `e2e-android` incompleto ou vermelho; se o job morrer por infra, re-rodar e esperar | processo |
| S4 | Toda tela nova precisa de uma journey e2e **na mesma PR** (reafirma o item #5 do Epic 1, que foi furado) | processo |
| S5 | Executar o `AudioSession` do iOS antes de rodar em device | dev |
| S6 | Burn-in do `e2e-android` segue aberto (item #2 do Epic 1) | Murat |

## Veredito

Sessão produtiva em entrega — duas stories e a primeira tela jogável — e cara em
retrabalho: **4 PRs de correção para 2 de feature**. O retrabalho não veio de
código ruim; veio de **sinal insuficiente na hora certa**. As correções
estruturais (e2e sobre providers reais, consolidação do job) tornam o próximo
ciclo mais barato, desde que S2, S3 e S4 sejam respeitados.
