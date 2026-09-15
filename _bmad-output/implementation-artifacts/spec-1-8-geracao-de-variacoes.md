---
title: 'Story 1.8 — Geração de variações (anti-decoreba)'
type: 'feature'
created: '2026-09-09'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '323fc3ebdb9b5ed4b8908b57c8c135509fa88a30'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-7-estrutura-de-sessao.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A sequência de 39 exercícios é a mesma toda sessão — mesmos arquivos, mesma ordem, mesma resposta. Dá para decorar o som do arquivo sem ouvir a relação musical, e é esse sinal contaminado que o Epic 2 vai virar medidor de habilidade. Nada lembra o que já tocou: a sessão da 1.7 descarta as tentativas ao terminar.

**Approach:** Transpor. Intervalo e escala são montados em runtime a partir de notas isoladas, então a mesma relação toca a partir de raízes diferentes sem nenhum arquivo novo — os semitons vêm do catálogo, as raízes possíveis do inventário de notas. Para não repetir dentro de uma janela, a story cria a fatia mínima de `progressao/`: a tabela de variações recentes e o repositório que escreve nela, que é quem a arquitetura define como dono desse estado.

## Boundaries & Constraints

**Always:**

- **A variação é transposição, e os parâmetros musicais saem do catálogo** — `intervalCatalog[].semitones` e `scaleCatalog[].steps`. A lógica não conhece nenhum intervalo nem modo por nome.
- **O mapa token→semitom mora no domínio de `audio/`** (decisão do humano, 2026-09-09), que já é dono de `audioAssetKeyFor` e do vocabulário de tokens. É propriedade do conjunto de amostras, não do currículo — por isso não vira campo de catálogo e não bumpa o `schemaVersion` dele.
- **Nenhum arquivo de áudio novo.** As 22 amostras já são todas referenciadas pelo catálogo, então transpor dentro do inventário produz refs já legais e o gate de paridade catálogo↔assets não muda.
- **O teto desigual é aceito como está** (decisão do humano, 2026-09-09): intervalo rende de 2 a 14 raízes, escala rende 1 (maior) ou 2, acorde nenhuma. Nenhum exercício fica pior do que é hoje; alguns ficam muito melhores.
- **Acorde fica fora da variação** (decisão do humano, 2026-09-09) — a raiz vem colada no arquivo pré-renderizado. Seus refs seguem verbatim do catálogo, e isso é comportamento definido, não lacuna.
- **Uma variação só é oferecida se todas as suas notas existirem.** O inventário é irregular (falta Db5), então a raiz é escolhida entre as que resolvem, nunca assumida.
- **A janela é de 39 exercícios** — uma sequência completa — e conta por exercício, não por sessão, para não penalizar quem pratica várias vezes no mesmo dia.
- **A janela proíbe; o histórico desempata** (decisão do humano, 2026-09-09). Entre as raízes que a janela deixa livres, a escolhida é a **menos recentemente usada em todo o histórico** — nunca a mais grave. Sem isso a regra colapsa: a janela de 39 alcança pouco mais de uma sessão, cada relação tem no máximo um uso dentro dela, e "a mais grave que sobrou" alterna entre as duas mesmas raízes para sempre, com pool de 14 ou de 2.
- **Pool esgotado escolhe a menos recentemente usada.** Repetição controlada é comportamento definido; travar ou repetir a última, não.
- **O histórico pertence a `progressao/`** (AD-2): tabela + repositório de escrita, que a Story 2.1 estende sem reescrever. `exercicios/` o alcança só pelo barrel `progressao.dart`.
- **A ordem das alternativas passa a ser determinística.** `optionSeed` mistura o `hashCode` de um enum, que é de identidade e re-sorteado por isolate: a ordem muda a cada abertura do app enquanto o código afirma determinismo. Variação controlada não convive com variação acidental.

**Never:**

- Síntese em runtime, download remoto ou multi-voz no `AudioService` — os `Never` da 1.4b continuam de pé.
- Persistir tentativas, agregar, pontuar ou calcular medidor. É Epic 2; aqui só o histórico de variações é escrito.
- Seleção adaptativa por habilidade (Story 2.8) — a escolha aqui é anti-repetição, não pedagógica.
- Mudar `SessionResultReported`, a regra de sessão concluída ou a estrutura da sessão da 1.7.
- Mudar as durações de motif por tipo, o feedback de erro ou o conteúdo dos catálogos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Variação disponível | intervalo, histórico vazio | escolhe uma das raízes possíveis; refs transpostos | — |
| Sem repetição na janela | a relação já tocou na raiz R | escolhe raiz != R enquanto houver | — |
| Pool esgotado | todas as raízes dentro da janela | a menos recentemente usada | nunca trava, nunca repete a última |
| Raiz impossível | a transposição sairia do inventário | a raiz não entra no pool | jamais gera ref inexistente |
| Pool de uma só | escala maior (só C4 resolve) | toca sempre a mesma, sem erro | o teto é dado, não falha |
| Acorde | qualquer posição de acorde | refs verbatim do catálogo | fora da variação por decisão |
| Primeira execução | tabela vazia | qualquer variação; passa a registrar | — |
| Banco indisponível | a leitura do histórico falha | a sessão roda com variação, sem histórico | degrada, não bloqueia a prática |
| Ordem das alternativas | mesma pergunta, dois processos | mesma ordem | determinístico entre execuções |

</frozen-after-approval>

## Code Map

**A mudar:**

- `lib/audio/domain/audio_assets.dart` -- `audioAssetKeyFor` (`:24-29`) já mapeia token → arquivo e valida `^[a-z0-9_]+$`; ganha o mapa token→semitom das 14 notas isoladas e o cálculo de "existe o token N semitons acima de X"
- `lib/exercicios/domain/exercise_question.dart` -- `questionFor` projeta o exercício em `ExerciseQuestion` com `audioSampleRefs` verbatim; é aqui que a transposição entra. `optionSeed` (`:157`) e `hashCode` (`:178-186`) misturam `variantKey` e precisam do termo estável
- `lib/exercicios/domain/interval_practice.dart` -- `practiceLoop` (`:33-52`) é 1:1 com o catálogo; passa a escolher a variação de cada posição consultando o histórico
- `lib/exercicios/domain/` -- o tipo da variação (relação + raiz) e a regra de seleção/LRU como função pura, testável sem banco
- `lib/core/database/app_database.dart` -- hoje `tables: []`, `schemaVersion => 1`, `onUpgrade` vazio. A tabela precisa morar sob `core/database/` (Rule 2) e ser alcançada por `progressao/data/` via o barrel `core.dart`
- `lib/progressao/` -- criar `domain/` (interface do repositório) e `data/` (impl privada + provider `@riverpod`), no padrão de `curriculo/`. O barrel exporta o domínio e, de `data/`, só o provider
- `drift_schemas/` + `test/generated/migrations/` -- dump e snapshots regenerados; `versions` vai a `[1, 2]`. `schema generate` é passo manual, não roda no `ci.sh`
- `test/migration_test.dart` -- somar o caso 1→2 (insere em v1, migra, linhas sobrevivem). O caso que fixa "v1 tem zero tabelas" (`:79-92`) continua válido
- `test/exercicios/interval_practice_test.dart` -- o gate mais apertado: `loop.length == 39` (`:30`), igualdade ordenada do loop inteiro, `loop.first.answer.id == 'P1'` com `Direction.asc`, goldens de refs e durações de motif (`:175-215`) — todos assumem refs fixos
- `test/exercicios/interval_exercise_screen_test.dart:1162` -- `loop.length == 39` e a caminhada pelas 39 posições

**Verificado, nada a mudar:**

- `assets/audio/` -- 22 arquivos: 14 notas isoladas (C4–C5 cromático + D5, **sem Db5**) e 8 blocos de tríade. Todas as 22 já referenciadas pelo catálogo
- `test/audio_assets_bundle_test.dart:459-484` -- a paridade catálogo↔assets, igualdade de conjuntos nos dois sentidos. Não deve mudar, e provar isso é parte do trabalho
- `lib/exercicios/domain/motif.dart:59-88` -- o ritmo é função pura dos refs e de constantes por tipo; transpor não mexe no contorno
- `lib/exercicios/presentation/` -- consome `ExerciseQuestion` e é agnóstica de tipo desde a 1.5a (Rule 6); a variação não chega até lá

## Tasks & Acceptance

**Execution:**

- [x] 1. `lib/audio/domain/audio_assets.dart` -- o mapa token→semitom e a consulta de existência por deslocamento
- [x] 2. `lib/exercicios/domain/` -- o tipo da variação e o cálculo das raízes possíveis por exercício, a partir dos semitons do catálogo
- [x] 3. `lib/exercicios/domain/exercise_question.dart` -- `questionFor` aceita a variação e projeta os refs transpostos; `optionSeed`/`hashCode` passam ao termo estável de `variantKey`
- [x] 4. `lib/exercicios/domain/` -- a regra de seleção: não repetir na janela de 39, desempate entre as livres pela menos recentemente usada no histórico completo, LRU ao esgotar — função pura sobre o histórico
- [x] 5. `lib/core/database/app_database.dart` -- a tabela de variações recentes, `schemaVersion` 2, `onUpgrade` criando-a
- [x] 6. `lib/progressao/` -- interface no `domain/`, impl privada e provider no `data/`, barrel exportando domínio + provider
- [x] 7. `lib/exercicios/domain/interval_practice.dart` -- `practiceLoop` escolhe a variação por posição
- [x] 8. `drift_schemas/`, `test/generated/migrations/`, `test/migration_test.dart` -- dump, snapshots e o caso 1→2
- [x] 9. `test/` -- as linhas da matriz, com ênfase em pool esgotado, raiz impossível, pool de um, acorde invariante e banco indisponível
- [x] 10. `test/exercicios/interval_practice_test.dart` e `interval_exercise_screen_test.dart` -- ajustar os goldens que assumem refs fixos, preservando o que protegem (39 posições, ordem de estágio, nenhum card misturando tipos)
- [x] 11. `sprint-status.yaml` -- `in-progress` ao começar, `review` ao abrir o PR

**Acceptance Criteria:**

- Given duas sessões seguidas, then nenhuma posição toca a mesma variação nas duas, enquanto o pool daquela relação tiver mais de uma raiz.
- Given uma relação com pool de N raízes e N sessões seguidas, then as N raízes são todas visitadas — a variedade entregue acompanha o pool medido, e não uma alternância entre duas.
- Given o pool de uma relação esgotado na janela, then a variação escolhida é a menos recentemente usada, e a sessão continua.
- Given qualquer variação gerada, then todos os seus `audioSampleRefs` existem em `assets/audio/`, e `assets/audio/` continua sem órfãos.
- Given uma posição de acorde, then seus refs são exatamente os do catálogo, em qualquer sessão.
- Given a mesma pergunta em dois processos distintos, then a ordem das alternativas é a mesma.
- Given um banco na v1, when o app abre, then ele migra para a v2 e as linhas anteriores sobrevivem.
- Given os comandos de §Verification, then todos saem com exit 0.

**Verificação humana (não bloqueia o agente):**

- Percorrer duas sessões e conferir de ouvido que os mesmos exercícios não soam idênticos, e que nenhum soa fora do registro do sax.

## Implementation Notes

## Spec Change Log

## Review Triage Log

**Passo 1 (2026-09-09) — 3 lentes, 27 achados.**

| Verdito | Achado | Evidência |
|---|---|---|
| high | A janela de 39 colapsa a variedade em 2 raízes, qualquer que seja o pool | Reproduzido de forma independente: 12 sessões simuladas contra o catálogo real visitam 2 raízes em pools de 14, 12 e 8. A janela alcança ~1,26 sessão (31 exercícios variam por sessão), então cada relação tem um único uso dentro dela e "a mais grave livre" alterna. Causa raiz na linha congelada da janela → levado ao humano, que escolheu "janela proíbe, histórico desempata". Emendado acima; código corrigido sem reverter, por decisão do humano |
| medium | `usedAt` é gravado e nunca lido; o teste que leva o nome do relógio não o observa | `VariantUse` não tem o campo e `mostRecent` não o devolve; trocar `clock.now()` por `DateTime.now()` deixa tudo verde. `patch` |
| medium | `recent()` não espera as escritas em voo, e o provider é auto-dispose | Sair e reentrar na tela constrói outro repositório com a cadeia `_writes` vazia enquanto as escritas anteriores podem não ter chegado. `patch` |
| low | Um exercício é registrado antes da oferta de encerrar poder intervir | `_recordVariant(s.loop[next])` roda antes de `_shouldOfferEnd`; aceitar a oferta grava um exercício nunca ouvido. Contradiz o comentário "one row per exercise reached" na mesma linha. `patch` |
| medium | O recompile do `epic-1-context.md` derrubou as tags AD-/AR-/UX-DR | O código novo cita "AD-2" em três arquivos e o documento não tem mais o identificador. Causado pela recompilação do contexto no passo 1, não pela implementação. `patch` |
| medium | A nota deferida do `sax_db5` subestima o ganho | Recalculado: com semitom 13 o conjunto vira 0–14 contínuo, então **todos** os intervalos ganham uma raiz e as escalas vão de 1–2 para 3. A nota dizia "M7/m7/P8 ganham uma raiz cada". Corrigido |
| low | `_recordVariant(loop.first)` regrava se `build()` recompuser | Verdadeiro no caminho de retry após falha de catálogo; custo é uma linha a mais no histórico. `patch` |
| false | Task 11 marcada `[x]` com o tracker em `in-progress` | A própria task diz "`in-progress` ao começar, `review` ao abrir o PR" — o estado atual é o correto para este momento |
| false | Goldens de `stableSeed` seriam reféns do PRNG do `dart:math` | Achado real quanto ao `Random`, mas o golden congelado de ordem foi produzido noutro processo e é o que a AC exige; o risco é de mudança de SDK, não desta story. Registrado como deferido |
| low | DAO alocado a cada chamada em vez de usar `db.recentVariantsDao` | Alocação trivial; sem dano nomeado. Rejeitado |
| low | `core.dart` exporta o DAO, cujo mixin expõe a tabela gerada | Enfraquecimento teórico do Rule 2; nenhum consumidor o alcança. Registrado como deferido |

Demais achados das lentes (falta de teste do `StateError` de `refsForVariant`, `assert` de bijeção no índice reverso, `switch` exaustivo em `Direction`, `assert` de `relationKey` casado em `questionFor`, semântica "39 registros ≠ 39 exercícios", `variantKey` divergente entre `questionFor` com e sem variante, newline final do schema dump, parâmetro sem tipo em `_userTables`) foram avaliados como `low` sem dano nomeado ou como pedidos de guarda para estado não demonstrado, e rejeitados conforme a regra de triagem.

## Design Notes

**O teto de variação, medido (2026-09-09)** contra as 14 notas isoladas (C4–C5 cromático + D5; falta Db5). Quantas raízes cada relação admite:

```
intervalos:  P1 14 · m2 12 · M2 12 · m3 11 · M3 10 · P4 9 · TT 8
             P5 7 · m6 6 · M6 5 · m7 4 · M7 3 · P8 2
escalas:     maior 1 (só C4) · menor 2 · dórica 2 · mixolídia 2
acordes:     0 (raiz colada no arquivo pré-renderizado)
```

O número cai conforme o intervalo cresce, porque o topo do inventário acaba. É o desenho do conjunto de amostras, não uma escolha de produto — e é por isso que a story aceita o teto em vez de prometer uniformidade.

**Por que transpor não custa arquivo.** O gate exige que `assets/audio/` seja exatamente o conjunto de tokens do catálogo. Como as 22 já são referenciadas, toda transposição dentro do inventário produz refs já legais. Sair do inventário é que seria erro — daí a raiz ser escolhida entre as que resolvem.

**Por que o `optionSeed` entra aqui.** `Object.hash(answer.id, variantKey, index)` com `variantKey` sendo enum: `hashCode` de enum é de identidade e re-sorteado por isolate, então a ordem muda a cada abertura enquanto os testes afirmam determinismo — eles só conferem que o *mesmo* seed dá a mesma ordem, o que qualquer fórmula satisfaz. O item deferido pediu para decidir junto desta story, que é a que precisa separar variação controlada de acidental.

## Verification

**Ambiente:** o shell não-interativo não carrega `~/.zshrc` — prefixar comandos Flutter/Dart com `export PATH="/home/clapthesun/development/flutter/bin:$PATH"`.

**Commands:**
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `dart run tool/check_deferred_owners.dart` -- exit 0
- `dart run tool/check_curriculum.dart` -- exit 0
- `flutter test` -- todos passam
- `bash tool/ci.sh` -- exit 0
