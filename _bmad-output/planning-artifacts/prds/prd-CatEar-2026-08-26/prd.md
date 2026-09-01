---
title: CatEar
created: 2026-08-26
updated: 2026-09-01
status: final
---

# PRD: CatEar
*Working title — confirm.*

## 0. Document Purpose

Este PRD detalha o produto CatEar (app mobile de treino de ouvido relativo estilo Duolingo) para orientar o próprio criador na implementação — é um projeto pessoal/hobby, então serve como referência de escopo e decisões, não como documento formal multi-stakeholder. Constrói sobre o [Product Brief](../briefs/brief-Perfect%20Ear-2026-08-26/brief.md), que não é duplicado aqui. Vocabulário fica ancorado no Glossário (§3); features agrupam FRs numerados globalmente; assumptions ficam marcadas inline e indexadas em §10.

## 1. Vision

CatEar é um app mobile que ensina ouvido relativo (intervalos, acordes, escalas) e teoria musical associada sem exigir instrumento, no espírito Duolingo: sessões curtas e diárias, progressão adaptativa, gamificação de verdade — mas fundamentado em como o ouvido musical realmente se desenvolve, não em bipes e múltipla escolha decorada.

O produto existe porque quase todo mundo curte música, mas quase ninguém treina o ouvido — não por falta de interesse real, e sim porque o tema é percebido como "matemática", intimidando quem só curte música casualmente. CatEar ataca essa percepção com um invólucro de produto tão bom quanto os melhores apps de hábito do mercado, aplicado a um currículo com fundamento pedagógico sério: áudio de timbre real em contexto musical, produção ativa (cantar de volta), repetição espaçada, e prova concreta de progresso a cada sessão.

Em poucas semanas de uso, a meta é que a pessoa perceba — quase sem querer — que consegue reconhecer intervalos, acordes e escalas de ouvido, e eventualmente tire uma música sozinha, sem sentir que "estudou teoria" no processo.

O diferencial de CatEar não é tecnologia proprietária — é executar bem a combinação de fundamentação pedagógica correta com produto/gamificação de qualidade, algo que nenhum concorrente atual do nicho faz junto. Se existir um moat, é ter feito isso com excelência antes de outros perceberem a oportunidade — não uma barreira técnica fabricada.

### 1.1 Aesthetic and Tone

A interface deve soar e parecer um app de música, nunca uma aula — linguagem e estética evitam qualquer referência a "matemática" ou notação acadêmica pesada. Isso é parte do trabalho de tornar o tema acessível ao público casual descrito em §2, e vale como diretriz para toda a experiência (textos, telas de erro, onboarding), não só para o currículo.

## 2. Target User

### 2.1 Jobs To Be Done

- Tirar uma música de ouvido sem depender de cifra pronta.
- Jamar com amigos sem travar.
- Compor música própria.
- Se sentir músico de verdade — validação pessoal.
- [ASSUMPTION] Como projeto hobby, também serve como a ferramenta que o próprio criador queria ter tido — validar se isso importa para o escopo de alguma forma.

### 2.2 Non-Users (v1)

- Quem quer treinar técnica de instrumento (execução, dedilhado) — fora de escopo; o foco é 100% percepção auditiva.
- Quem já tem ouvido absoluto desenvolvido ou busca treino de ouvido absoluto.
- Professores de música buscando ferramenta de apoio a alunos — não é o público v1 (secundário, arquivado para revisão futura conforme o Brief).

### 2.3 Key User Journeys

Como app consumer mobile com jornada central de UX, mas escopo hobby, uso o formato leve (frase única) para as jornadas centrais:

- **UJ-1.** Marina, 27 anos, canta em banda amadora mas nunca estudou teoria, abre o app pela primeira vez, faz o teste de nivelamento (ouvindo e cantando de volta), recebe um nível de partida e sua primeira "vitória genuína" — reconhecer um intervalo simples corretamente — antes de fechar o app na primeira sessão.
- **UJ-2.** Marina volta no dia seguinte, faz uma sessão de 10-15 min de treino de intervalos, erra uma questão e recebe explicação do que confundiu (não um "errado" seco), e ao final vê os dois medidores (Habilidade e Esforço) atualizados, com Esforço subindo mesmo tendo errado algumas.
- **UJ-3.** Depois de duas semanas, Marina abre a tela de progresso e vê seu tempo de reação em terças menores comparado à baseline do dia 1 — prova concreta de que está melhor do que quando começou, mesmo tendo tido um dia ruim recentemente.

**Edge case (UJ-2):** se Marina errar repetidamente o mesmo tipo de intervalo, a progressão adaptativa desvia para uma rota de reforço em vez de bloquear o avanço com uma parede rígida.

## 3. Glossary

- **Ouvido Relativo** — capacidade de reconhecer intervalos, acordes e escalas pela relação entre notas, não por afinação absoluta. Foco central do produto.
- **Intervalo** — distância entre duas notas musicais (ex: 3ª maior, 5ª justa). Unidade básica de exercício.
- **Nivelamento** — teste inicial que calibra o nível de partida do usuário, combinando reconhecimento e produção vocal (ver Produção Ativa).
- **Produção Ativa** — modalidade de exercício em que o usuário canta de volta o que ouviu, em vez de apenas reconhecer por múltipla escolha.
- **Medidor de Habilidade** — indicador de performance atual, ruidoso por natureza (pode cair em um dia ruim, reflete a realidade do desempenho).
- **Medidor de Esforço** — indicador monotônico (só cresce) que credita constância — ter aparecido e praticado — independente da performance do dia.
- **Baseline Dia 1** — registro de performance da primeira sessão do usuário, usado como referência de comparação para provar progresso ao longo do tempo.
- **Andaime (Scaffold)** — qualquer muleta associativa (cor, mnemônico) usada temporariamente para facilitar reconhecimento, sempre com fading progressivo — nunca permanente.
- **Resolução** — conceito de tensão → alívio (cadência) ensinado cedo no currículo como ponte entre percepção intuitiva e composição.
- **Progressão Adaptativa** — sistema de dificuldade que se ajusta dinamicamente à performance do usuário, com rotas de reforço em vez de paredes de bloqueio.
- **Skill Tree** — mapa visual de progressão que mostra onde o usuário está e o que vem a seguir.

## 4. Features

### 4.1 Nivelamento Inicial

**Descrição:** Primeira experiência do usuário no app. Testa reconhecimento e Produção Ativa (cantar de volta) desde o início, calibrando o nível de partida e já entregando a primeira vitória genuína. Realiza UJ-1.

**Functional Requirements:**

#### FR-1: Teste de nivelamento com produção ativa

O sistema deve apresentar ao usuário uma sequência curta [ASSUMPTION: número exato de exercícios a definir em design de currículo] de exercícios de reconhecimento e produção vocal de intervalos, calibrando um nível de partida. Realiza UJ-1.

**Consequences (testable):**
- O nivelamento inclui pelo menos um exercício de reconhecimento (múltipla escolha) e um de produção vocal (cantar de volta).
- Ao final do nivelamento, o usuário recebe um nível de partida atribuído e uma primeira vitória (acerto reconhecido explicitamente).
- [ASSUMPTION] O nivelamento pede acesso ao microfone logo no onboarding — aceitando o atrito descrito no Brief em troca de calibrar produção ativa desde o início.

**Out of Scope:**
- Nivelamento de leitura de partitura ou ritmo (fora do escopo do produto).

### 4.2 Treino de Ouvido (Núcleo)

**Descrição:** O loop diário central do produto — exercícios de intervalos, acordes e escalas, com áudio de timbre real em contexto musical, feedback explicativo em todo erro, e sessões desenhadas para 10-15 minutos. Realiza UJ-2.

**Functional Requirements:**

#### FR-2: Exercícios de reconhecimento de intervalos, acordes e escalas

O usuário pode praticar exercícios de reconhecimento auditivo de intervalos, acordes e escalas, apresentados com áudio de timbre real (não sintético) em contexto musical (melodia ou progressão) [ASSUMPTION: duração exata do trecho a definir em design de currículo], não como notas isoladas. Realiza UJ-2.

**Consequences (testable):**
- Todo áudio de exercício usa amostras de instrumento real pré-renderizadas, nunca síntese em tempo real.
- Cada exercício apresenta o intervalo/acorde/escala dentro de um trecho musical curto (melodia ou progressão), não como par de notas isoladas em silêncio.

#### FR-3: Produção ativa em exercícios

O usuário pode responder a um exercício cantando de volta o que ouviu. No nivelamento (FR-1) e nos exercícios do módulo de Resolução (FR-15) a produção vocal é obrigatória; nos demais exercícios do treino núcleo funciona como modalidade alternativa ao reconhecimento por múltipla escolha [ASSUMPTION: regra exata de quando é obrigatória vs. opcional a refinar em design de currículo]. Realiza UJ-2.

**Consequences (testable):**
- O app captura e avalia a resposta vocal do usuário, comparando com a nota/intervalo esperado.
- [ASSUMPTION] A avaliação de afinação vocal tem tolerância definida em fase de design técnico — não detalhada aqui.

#### FR-4: Feedback explicativo em erro

Quando o usuário erra um exercício, o sistema explica a natureza do erro (ex: "confundiu 3ª maior com 3ª menor"), não apenas indica "errado". Realiza UJ-2.

**Consequences (testable):**
- Toda resposta incorreta é acompanhada de uma explicação nomeando o conceito confundido.
- Nenhuma tela de erro mostra apenas "errado"/"incorreto" sem explicação.

#### FR-5: Sessões curtas diárias

O sistema estrutura o conteúdo em sessões de 10-15 minutos, adequadas para repetição espaçada diária. Realiza UJ-2.

**Consequences (testable):**
- Uma sessão completa (do início ao resumo final) dura entre 10 e 15 minutos em uso típico.
- O app não força ou incentiva sessões maratona (sem mecânicas que recompensem sessões muito mais longas que o padrão).

#### FR-6: Geração de variações (anti-decoreba)

O sistema gera variações dos exercícios em vez de repetir sempre o mesmo conjunto fixo de exemplos, para forçar reconhecimento de padrão real em vez de memorização.

**Consequences (testable):**
- Nenhum exercício específico se repete de forma idêntica (mesmo áudio, mesma pergunta) dentro de uma janela razoável de sessões consecutivas. [ASSUMPTION] Janela exata a definir em design técnico.

**Feature-specific NFRs:**
- Áudio deve ser pré-renderizado e testado, não gerado por síntese em runtime — mitigação de risco de qualidade sonora identificado no Brief.

### 4.3 Progressão Adaptativa e Skill Tree

**Descrição:** Sistema de dificuldade dinâmica sem paredes de bloqueio, com um mapa visual de progressão (skill tree) sempre visível. Realiza UJ-2, UJ-3.

**Functional Requirements:**

#### FR-7: Dificuldade adaptativa sem paredes de bloqueio

O sistema ajusta a dificuldade dos exercícios dinamicamente com base na performance do usuário, desviando para rotas de reforço em vez de bloquear o avanço quando o usuário está com dificuldade.

**Consequences (testable):**
- Um usuário que erra repetidamente um tipo de exercício é direcionado a exercícios de reforço relacionados, nunca a uma tela de "bloqueado, não pode avançar".
- Não existe nenhum ponto do currículo v1 sem rota de saída disponível.

#### FR-8: Skill tree visível

O usuário pode visualizar, a qualquer momento, um mapa de progressão mostrando onde está e o que vem a seguir.

**Consequences (testable):**
- Uma tela dedicada mostra o mapa de progressão, acessível a partir da navegação principal.

### 4.4 Medidores de Retenção

**Descrição:** Dois indicadores de progresso sempre exibidos juntos — Habilidade (ruidoso, reflete performance real) e Esforço (monotônico, credita constância) — com Esforço pesando mais na recompensa, para que um dia ruim de ouvido nunca apague o senso de progresso. Realiza UJ-2.

**Functional Requirements:**

#### FR-9: Medidor de Habilidade

O sistema calcula e exibe um Medidor de Habilidade que reflete a performance real e recente do usuário, podendo cair.

**Consequences (testable):**
- O valor do Medidor de Habilidade pode diminuir entre duas sessões consecutivas quando a performance piora.

#### FR-10: Medidor de Esforço

O sistema calcula e exibe um Medidor de Esforço que só cresce, creditando a constância de ter praticado, independente da performance.

**Consequences (testable):**
- O valor do Medidor de Esforço nunca diminui entre sessões — apenas mantém ou aumenta.
- Toda sessão completada (independente de acertos) incrementa o Medidor de Esforço.

#### FR-11: Recompensa ponderada por esforço

O sistema de recompensa (pontos, mensagens de reforço positivo, etc.) pesa mais o Medidor de Esforço do que ganhos de performance pura.

**Consequences (testable):**
- Uma sessão com baixa performance mas completada integralmente gera recompensa positiva visível ao usuário.

### 4.5 Prova de Progresso vs. Dia 1

**Descrição:** Mecanismo concreto de comparação entre a performance atual e a baseline da primeira sessão, como vitória mensurável e inegável. Realiza UJ-3.

**Functional Requirements:**

#### FR-12: Registro de baseline do dia 1

O sistema registra as métricas de performance (ex: tempo de reação, acurácia por tipo de intervalo) da primeira sessão completa do usuário como baseline.

**Consequences (testable):**
- A baseline é registrada uma única vez, na **primeira Sessão de Exercício concluída** após o nivelamento (não no nivelamento em si), e nunca sobrescrita.
- Se essa primeira sessão for abandonada, o registro é adiado até haver uma sessão concluída — a baseline nunca é feita de dados parciais.

#### FR-13: Comparação de progresso vs. baseline

O usuário pode visualizar uma comparação entre sua performance atual e a baseline do dia 1 (ex: "tempo de reação em terças menores caiu de 2,1s para 1,4s").

**Consequences (testable):**
- Uma tela de progresso mostra ao menos uma métrica comparada entre a baseline e o desempenho recente, com valores numéricos visíveis.

### 4.6 Andaimes Temporários (Fading Scaffolds)

**Descrição:** Recursos associativos (cor para consonância/dissonância, mnemônicos) usados como apoio inicial, sempre com desvanecimento progressivo — nunca permanentes.

**Functional Requirements:**

#### FR-14: Andaime de cor para consonância/dissonância com fading

O sistema associa uma cor à sensação de consonância/dissonância nos primeiros estágios do currículo, reduzindo progressivamente essa pista visual conforme o usuário avança.

**Consequences (testable):**
- A intensidade/presença da pista de cor diminui mensuravelmente entre os estágios iniciais e os avançados do currículo.
- Em nenhum estágio avançado do skill tree a pista de cor permanece na intensidade original.

**Notes:** [NOTE FOR PM] O ritmo exato de fading (quantos estágios, que curva) é uma decisão de design de currículo a refinar — não bloqueia o PRD, mas merece atenção na arquitetura de conteúdo.

### 4.7 Conceito de Resolução

**Descrição:** Introdução do conceito de tensão → alívio (cadência) cedo no currículo, como ponte entre percepção intuitiva e a primeira composição do usuário.

**Functional Requirements:**

#### FR-15: Módulo de Resolução no currículo inicial

O currículo inclui, nos estágios iniciais, exercícios dedicados ao reconhecimento do conceito de Resolução (tensão → alívio).

**Consequences (testable):**
- Existe pelo menos um conjunto de exercícios rotulado como trabalhando Resolução, posicionado nos primeiros estágios do skill tree (não nos avançados).

### 4.8 Telemetria de Calibração (interna)

**Descrição:** Coleta passiva e estritamente local de sinais de uso (taxa de erro por tipo de exercício, tempo de reação, pontos de abandono de sessão) para o criador calibrar se a baseline e a curva da progressão adaptativa estão punitivas ou fáceis demais. Não é feature visível ao usuário, roda atrás de uma flag de compilação (para permitir builds sem coleta) e o app funciona idêntico com ela desligada. Nenhum dado sai do dispositivo na v1. Corresponde ao módulo passivo de Telemetria da arquitetura (AD-6). **Confirmada no escopo da v1** (decisão de produto, 2026-09-01).

**Functional Requirements:**

#### FR-16: Registro local de sinais de calibração

O sistema pode registrar, localmente, eventos estruturados derivados das sessões (tipo de exercício, acerto/erro, tipo de erro, tempo de reação, conclusão ou abandono de sessão) para análise posterior pelo próprio criador.

**Consequences (testable):**
- Com a telemetria desligada, nenhum evento é gravado e o comportamento do app é idêntico.
- Os eventos registrados nunca são transmitidos para fora do dispositivo na v1.
- A telemetria apenas consome dados já produzidos pelas sessões — não altera Medidores, Skill Tree, Baseline ou dificuldade adaptativa.

## 5. Non-Goals (Explicit)

- O produto não ensina técnica de instrumento (dedilhado, postura, execução) — o foco é 100% percepção auditiva e teoria associada.
- O produto não cobre leitura de partitura na v1.
- O produto não cobre ritmo complexo/poliritmo na v1.
- O produto não trata audiação como módulo dedicado na v1 (permanece visão de longo prazo).
- O produto não inclui mecânicas de surpresa/aleatoriedade estilo "loot" de dungeon crawler na v1.
- O produto não envia dados de uso para servidores externos na v1 — qualquer telemetria é estritamente local (ver §4.8).
- O produto não atualiza o currículo remotamente (OTA) na v1 — o catálogo de conteúdo é embarcado no app e só muda com uma nova versão publicada. Decisão de produto confirmada (2026-09-01); a arquitetura (AD-4) mantém a porta aberta para OTA em v2 sem redesenho.

## 6. MVP Scope

### 6.1 In Scope

- Treino de ouvido relativo: intervalos, acordes e escalas, sem instrumento (FR-2).
- Áudio de timbre real em contexto musical (FR-2).
- Sessões curtas diárias, 10-15 min (FR-5).
- Teste de nivelamento com produção ativa (FR-1).
- Progressão adaptativa sem paredes (FR-7), com skill tree visível (FR-8).
- Dois medidores de retenção, esforço pesando mais (FR-9, FR-10, FR-11).
- Prova de progresso vs. baseline do dia 1 (FR-12, FR-13).
- Feedback explicativo em todo erro (FR-4).
- Andaime de cor com fading (FR-14).
- Conceito de Resolução cedo no currículo (FR-15).
- Produção vocal no nivelamento e nos exercícios (FR-1, FR-3).
- Telemetria local de calibração, atrás de flag de compilação (FR-16).

### 6.2 Out of Scope for MVP

- Matriz morfológica completa (registro/tessitura, articulação, densidade timbrística) como exercícios avançados — deferido a v2. [NOTE FOR PM] Ideia forte do brainstorming (combinação inédita registro x densidade), vale revisitar cedo em v2.
- Rotas remediais explícitas (além do desvio básico da progressão adaptativa) — deferido a v2.
- Surpresas/aleatoriedade estilo dungeon crawler — arquivado no brainstorming, não aprofundado.
- Leitura de partitura, ritmo complexo/poliritmo, audiação como módulo dedicado — visão de longo prazo, fora da v1.
- Monetização — [ASSUMPTION] projeto hobby, sem modelo de monetização definido para v1; app tratado como gratuito/pessoal até decisão em contrário.
- Analytics/telemetria remota e atualização de currículo via OTA — deferidos; a arquitetura (catálogo como dado, AD-4; módulo de Telemetria passivo, AD-6) deixa a porta aberta sem redesenho. Ver §5 e §9.

## 7. Success Metrics

Como projeto hobby, o critério de sucesso é qualitativo e pessoal, não quantitativo de negócio:

**Primary**
- **SM-1**: Uso semanal sustentado — o próprio criador (ou early testers) usa o app pelo menos algumas vezes por semana, sem abandono após o primeiro mês. Valida FR-5, FR-9, FR-10.
- **SM-2**: Progresso percebido — o usuário consegue apontar, usando a tela de progresso, uma melhora concreta vs. a baseline do dia 1. Valida FR-12, FR-13.

**Secondary**
- **SM-3**: Ausência de erro de conteúdo — nenhum caso relatado de áudio ou explicação teórica incorreta. Valida FR-2, FR-4.
- **SM-4**: Transferência pra vida real — o usuário relata ter tirado uma música de ouvido ou jamado sem travar, atribuindo isso ao app. Sinal qualitativo, herdado do Brief como critério de sucesso central do produto. Valida FR-2, FR-3, FR-15.

**Counter-metrics (não otimizar)**
- **SM-C1**: Tempo de sessão não deve crescer indefinidamente como proxy de engajamento — sessões maratona indicam falha do design de repetição espaçada, não sucesso. Contrabalança SM-1.

## 8. Roadmap (Post-v1)

*Itens deferidos com intenção de retomar — distintos dos Non-Goals (§5), que são decisões de não construir. Herdado da Visão do Brief.*

- **Audiação como capstone**: capacidade de ouvir música na mente sem som físico presente, como meta final nomeada / topo do skill tree — visão de longo prazo, não módulo dedicado na v1.
- **Cobertura ampla de currículo**: leitura de partitura, ritmo complexo/poliritmo — expansão de escopo pra além de ouvido relativo puro.
- **Elementos de surpresa/descoberta**: timbres desbloqueáveis, desafios raros — para aprofundar retenção sem comprometer a fundamentação pedagógica (arquivado no brainstorming original, não aprofundado ainda).
- **Expansão de público**: de "curioso casual com medo de teoria" para músicos de qualquer nível mantendo o ouvido afiado.
- **Currículo dinâmico (OTA)**: atualizar catálogos de conteúdo (ex: padrões de três notas por corda, arpejos, intervalos avançados) buscando um arquivo hospedado remotamente, com cache local e fallback embarcado — evoluir a pedagogia sem republicar nas lojas.
- **Telemetria remota / analytics de produto**: enviar os sinais de calibração locais (§4.8) para um backend, para calibrar a curva com dados de vários usuários (depende de backend/conta, também v2).

## 9. Open Questions

1. Qual a curva exata de fading do andaime de cor (FR-14) — quantos estágios, que critério de progresso dispara a redução?
2. Qual tolerância de afinação vocal será usada na avaliação de produção ativa (FR-3)?
3. Haverá modelo de monetização em algum momento futuro, ou o projeto permanece gratuito/pessoal indefinidamente?
4. Existe visão de plataforma além de mobile nativo (ex: web companion) no roadmap de médio prazo?
### Resolvidas (2026-09-01)

5. ~~OTA de currículo na v1?~~ **Não** — catálogo embarcado; OTA é v2 (AD-4 mantém a porta aberta). Ver §5.
6. ~~Telemetria local (§4.8, FR-16) na v1?~~ **Sim** — confirmada no escopo da v1 (Epic 4). A flag de compilação permite builds sem coleta.
7. ~~Contingência se o spike de detecção de pitch falhar?~~ **v1 sem produção ativa** — FR-1, FR-3 e FR-15 reduzidas a reconhecimento, módulo de Resolução vira exercício passivo, Stories 3.2–3.6 cortadas. Epics 1 e 2 já entregam um app completo de treino de ouvido. Só-Android e adiar-a-v1 foram descartadas.

## 10. Assumptions Index

- §2.1 — JTBD inclui a motivação pessoal do criador como hobby, sem validação externa de mercado. Vale validar se há gatilho de mercado adicional a considerar (herdado do Brief, não resolvido lá também).
- §4.1 FR-1 — Nivelamento pede acesso a microfone já no onboarding, aceitando o atrito.
- §4.1 FR-1 — Número exato de exercícios no nivelamento a definir em design de currículo.
- §4.2 FR-2 — Duração exata do trecho musical de contexto a definir em design de currículo.
- §4.2 FR-3 — Tolerância de avaliação de afinação vocal fica para design técnico.
- §4.2 FR-3 — Regra exata de quando produção vocal é obrigatória vs. opcional a refinar em design de currículo.
- §4.2 FR-6 — Janela exata de não-repetição de exercícios fica para design técnico.
- §6.2 — Sem modelo de monetização definido para v1; tratado como gratuito/pessoal.
- §5 / §4.8 — Telemetria estritamente local, confirmada na v1; envio remoto de analytics deferido a v2.
- §5 — Atualização remota de currículo (OTA) fora da v1; catálogo embarcado (decisão confirmada).
