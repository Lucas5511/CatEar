---
title: "Reconciliation: Brief vs PRD — Perfect Ear"
created: 2026-09-01
---

# Reconciliação: Brief → PRD (Perfect Ear)

Comparação item a item entre `brief.md` (2026-08-26) e `prd.md` (2026-08-26), com foco em ideias substantivas, decisões, nuances qualitativas (tom/voz/sensação) e itens de escopo — verificando sobrevivência em substância, não em texto literal.

Legenda: ✅ preservado | ⚠️ parcialmente preservado / diluído | ❌ ausente

## Executive Summary

- ✅ Definição central ("Duolingo do ouvido musical", intervalos/acordes/escalas, sem instrumento, transferência para vida real) — PRD §1.
- ⚠️ Framing competitivo explícito ("apps pequenos, tecnicamente rasos, gamificação fraca, paywalls agressivos") — a causa raiz (percepção de "matemática") sobrevive em §1, mas a descrição do estado atual do mercado concorrente é diluída/implícita.
- ✅ Os quatro princípios biológico-cognitivos (timbre real, produção ativa, repetição espaçada, vitória mensurável) — presentes em substância no §1 e nas features, embora não sejam nomeados explicitamente como "princípios biológico-cognitivos" (framing/rótulo perdido, conteúdo preservado).
- ❌/⚠️ **[ASSUMPTION] "porquê agora"** — motivação pessoal do criador como hobby, com nota para validar gatilho de mercado adicional. PRD §2.1 preserva a motivação pessoal como assumption, mas **não carrega a sugestão específica de validar um "gatilho de mercado adicional"** (ex: crescimento de apps de ouvido musical, tendência de aprendizado autodidata) — essa parte da assumption foi descartada, não indexada em §9.

## The Problem

- ✅ Todos os 8 modos de falha das alternativas existentes (áudio artificial, aprendizado passivo, feedback vazio, decoreba, progressão sem mapa, paredes rígidas, recompensa desalinhada, interface/gamificação rasas) mapeiam para features/FRs específicos no PRD (FR-2, FR-3, FR-4, FR-6, FR-7, FR-8, FR-9/10/11).
- ⚠️ O "custo do status quo" (pessoas desistem cedo por tédio/frustração/barreira acadêmica e nunca destravam tocar de ouvido/compor/sentir-se músico) — presente em espírito no Vision (§1) e JTBD (§2.1), mas não como afirmação explícita de custo/urgência.

## The Solution

- ✅ Áudio real pré-renderizado em contexto — FR-2, NFR em §4.2.
- ✅ Produção ativa desde o início, inclusive no nivelamento — FR-1, FR-3.
- ✅ Sessões curtas diárias 10-15min — FR-5.
- ✅ Feedback explicativo — FR-4.
- ✅ Progressão adaptativa sem paredes — FR-7.
- ✅ Dois medidores de retenção, esforço pesando mais — FR-9/10/11.
- ✅ Prova de progresso vs. dia 1 — FR-12/13.
- ✅ Andaimes temporários com fading, nunca permanentes — FR-14, Glossário.
- ✅ Conceito de "resolução" — FR-15.
- ❌ **"Design simples e amigável, evitando linguagem ou estética 'de matemática'"** — esta é uma diretriz de tom/UX explícita no Brief ("a interface carrega boa parte do trabalho de tornar o tema acessível"). No PRD, a ideia de combater a percepção "matemática" aparece apenas na narrativa do Vision (§1), mas **não vira um requisito, NFR ou nota de design explícita** — nenhuma feature ou FR menciona diretrizes de linguagem/estética a evitar. É exatamente o tipo de nuance qualitativa que uma estrutura de FRs tende a descartar, e foi descartada aqui.

## What Makes This Different

- ⚠️ A reflexão do diferencial ("não há moat técnico a fabricar — o moat, se existir, é ter feito isso bem, com excelência e cuidado pedagógico, antes de outros perceberem a oportunidade") é uma peça central de raciocínio estratégico no Brief. No PRD §1 sobrevive apenas de forma resumida ("Perfect Ear ataca essa percepção com um invólucro de produto tão bom quanto os melhores apps de hábito do mercado") — a **argumentação explícita sobre ausência de moat técnico e a natureza do moat real (excelência de execução antes da concorrência perceber a oportunidade) não aparece no PRD**. Isso é "why this matters" framing que se perdeu.

## Who This Serves

- ✅ JTBDs (tirar música de ouvido, jamar, compor, se sentir músico de verdade) — PRD §2.1, idênticos.
- ✅ Definição de sucesso do usuário (percepção sem esforço consciente em semanas, tirar música sem perceber que "estudou teoria") — PRD §1 vision, final parágrafo.
- ✅ Assumption de ausência de usuário secundário (professores) — PRD §2.2, com referência explícita ao Brief.

## Success Criteria

- ✅ Retenção de constância — SM-1.
- ✅ Progresso mensurável vs. baseline — SM-2.
- ✅ Vitória genuína já na primeira sessão — coberto por FR-1/UJ-1, não como success metric formal mas presente na feature.
- ✅ Tolerância zero a erro de conteúdo/pedagogia — SM-3.
- ❌ **Sinal qualitativo: "usuários relatam ter tirado uma música de ouvido ou jamado sem travar, atribuindo isso ao app"** — este critério de sucesso explícito do Brief **não aparece em nenhuma métrica do PRD (§7 Success Metrics)**. As métricas do PRD (SM-1, SM-2, SM-3, SM-C1) cobrem uso, progresso mensurável e ausência de erro, mas nenhuma cobre o sinal qualitativo de transferência real para a vida do usuário (tirar música/jamar), que era um critério de sucesso nomeado no Brief.

## Scope (V1 Must/Should/Could + Fora de escopo)

- ✅ Todos os itens "Must Have" do Brief mapeiam para features/FRs do PRD §6.1.
- ✅ Todos os "Should Have" (skill tree, andaime de cor, resolução, produção vocal) mapeiam para PRD §6.1 (dentro do MVP, não como "should" separado — o PRD colapsa must+should em um único MVP scope, mas o conteúdo está presente).
- ✅ "Could Have" (matriz morfológica, rotas remediais explícitas) — PRD §6.2, corretamente deferidos a v2, inclusive com nota preservando o valor da "combinação inédita registro x densidade" do brainstorming.
- ✅ Itens fora de escopo (loot/surpresas, partitura, ritmo complexo, audiação como módulo, técnica de instrumento) — todos em PRD §5 Non-Goals.

## Vision (seção final do Brief — visão de 2-3 anos)

- ❌ **Esta é a maior lacuna estrutural.** O Brief tem uma seção "Vision" dedicada com conteúdo substantivo de longo prazo:
  - Currículo amplo pós-v1 (leitura de partitura, ritmo complexo, audiação como "capstone" nomeado — meta final, topo do skill tree);
  - Elementos de surpresa/descoberta (timbres desbloqueáveis, desafios raros) para aprofundar retenção sem comprometer a fundamentação pedagógica — **note que isso reaparece no Brief como visão de longo prazo, distinto de "fora do escopo" — é uma ideia arquivada para o futuro, não descartada**;
  - Expansão do público-alvo além do "curioso casual" para músicos de qualquer nível;
  - Reafirmação da premissa fiel ("o alvo é sempre a percepção direta do som, nunca uma cadeia de atalhos mentais").

  No PRD, esse conteúdo é fragmentado e empobrecido: audiação/partitura/ritmo aparecem apenas como Non-Goals (§5) e MVP Out-of-Scope (§6.2), e o "loot"/surpresas aparece como não aprofundado ("arquivado no brainstorming, não aprofundado" — §6.2), **quando na verdade o Brief os trata como visão de longo prazo intencional, não como ideia descartada**. O PRD não tem nenhuma seção equivalente a "Vision" de longo prazo — perde-se especificamente:
  - O conceito nomeado de "capstone" (audiação como meta final/topo do skill tree);
  - A ideia de timbres desbloqueáveis/desafios raros como mecanismo de retenção de longo prazo (tratada como descartada, não como visão futura);
  - A expansão de público para "músicos de qualquer nível";
  - A reafirmação da premissa filosófica final.

## Outras observações

- ✅ Glossário do PRD (§3) é fiel e até mais preciso que as definições do Brief.
- ✅ Key User Journeys (UJ-1/2/3) do PRD são uma boa síntese fiel do Problem+Solution do Brief, incluindo o edge case da rota de reforço.
- ✅ Open Questions (§8) do PRD capturam bem as lacunas técnicas remanescentes (fading curve, tolerância vocal, monetização, plataforma).

## Resumo dos gaps materiais

1. **Diretriz de tom/estética "evitar linguagem de matemática"** — presente como ideia central de UX no Brief, ausente como requisito/nota no PRD.
2. **Sinal de sucesso qualitativo (relatos de transferência real — tirar música/jamar)** — critério de sucesso nomeado no Brief, ausente das Success Metrics do PRD.
3. **Seção de Vision de longo prazo (2-3 anos)** — ausente no PRD; conteúdo do Brief (capstone de audiação, timbres desbloqueáveis/desafios raros como visão futura, expansão de público) foi rebaixado a Non-Goals/Out-of-Scope, perdendo a distinção entre "fora do v1, mas visão futura pretendida" e "arquivado/descartado".
4. **Argumentação do moat/diferencial** ("sem moat técnico, moat é excelência de execução antes da concorrência perceber") — diluída a uma frase genérica no PRD, perdendo o raciocínio estratégico explícito.
5. **Parte da assumption sobre "porquê agora"** (sugestão de validar gatilho de mercado adicional) não foi carregada para o Assumptions Index do PRD.
