---
name: CatEar
status: final
sources:
  - "../../prds/prd-CatEar-2026-08-26/prd.md"
  - "../../briefs/brief-CatEar-2026-08-26/brief.md"
updated: 2026-08-26
---

# CatEar — Experience Spine

## Foundation

App mobile, iOS + Android com paridade [ASSUMPTION: paridade completa entre plataformas assumida por padrão; usuário não especificou diferença]. Nenhum design system nomeado — herda convenções nativas de plataforma para navegação, gestos de sistema, dynamic type. `DESIGN.md` é a referência de identidade visual; esta spine é a experiência. Modo claro é o padrão (tom pastel laranja quente); modo escuro replica o mesmo aconchego em tons mais profundos.

## Information Architecture

| Surface | Alcançada a partir de | Propósito |
|---|---|---|
| Onboarding / Nivelamento | Primeiro abrir do app | Calibra nível de partida via reconhecimento + produção vocal (PRD FR-1) |
| Home | Abertura do app (autenticado) | Ponto de entrada diário — CTA de sessão, resumo rápido dos medidores |
| Sessão de Exercício | Home → "Praticar" | Loop de exercícios de reconhecimento/produção ativa, com variações geradas por sessão (FR-2, FR-3, FR-4, FR-6), scaffold de cor com fading (FR-14) e módulo de Resolução nos estágios iniciais (FR-15) |
| Resumo de Sessão | Fim da Sessão de Exercício | Celebração do mascote + atualização dos dois medidores (FR-9, FR-10, FR-11) |
| Skill Tree | Tab bar | Mapa de progressão visível (FR-8) |
| Progresso | Tab bar | Medidores + comparação com baseline do dia 1 (FR-12, FR-13) |
| Settings | Home (ícone) | [ASSUMPTION] conta, preferências de áudio/microfone, tema — não detalhado no PRD |

Bottom tab bar: Home / Skill Tree / Progresso / Settings. Sem drawer. Modal (ex: explicação de erro) empilha só um nível.

## Voice and Tone

Microcopy. Voz de marca e postura estética vivem em `DESIGN.md`.

| Do | Don't |
|---|---|
| "Quase lá — você confundiu 3ª maior com 3ª menor." | "Errado." |
| "Você praticou hoje. Isso conta." (mensagem de Esforço mesmo em dia ruim) | "Sua performance caiu." (sem contexto/acolhimento) |
| Frases curtas, tom de professor gentil (via mascote) | Jargão técnico de teoria musical sem explicação |
| Confiança tranquila — o app não precisa se vender ("você já consegue perceber isso") | Hype de marketing, promessas exageradas de domínio instantâneo |
| "Terças menores: 2,1s → 1,4s. Você está mais rápido." | "Progress: -0.7s" (número seco sem narrativa) |

## Component Patterns

Comportamental. Especificação visual vive em `DESIGN.md.Components`.

| Component | Uso | Regras comportamentais |
|---|---|---|
| Mascot bubble | Nivelamento, feedback de erro, Resumo de Sessão | Aparece só nesses momentos; nunca durante o áudio do exercício em si. |
| Progress meter (par) | Home, Resumo de Sessão, Progresso | Esforço e Habilidade sempre renderizados juntos, nunca um sem o outro. |
| Exercise card | Sessão de Exercício | Um exercício por tela; player de áudio + área de resposta (múltipla escolha ou captura vocal). |
| Skill tree node | Skill Tree | Estados: bloqueado / disponível / completo / em reforço. Nó "em reforço" nunca é um estado de bloqueio — sempre navegável. |
| Skill tree capstone node | Skill Tree, topo da árvore | [NOTE FOR UX] Placeholder visual para Audiação como meta final nomeada (visão pós-v1 do Brief/PRD §8 Roadmap) — nó presente mas marcado "em breve", nunca navegável na v1. Reforça a jornada de longo prazo sem prometer o que ainda não existe. |
| Baseline comparison card | Progresso | Dois valores lado a lado (baseline dia 1 vs. atual) + diferença destacada. |
| Scaffold cue | Sessão de Exercício, estágios iniciais do currículo | Badge cor + ícone + rótulo de texto para consonância/dissonância (FR-14). Presença e intensidade diminuem por estágio até sumir nos avançados — nunca cor isolada como único sinal. |
| Resolução module card | Sessão de Exercício, estágios iniciais | Exercício dedicado a tensão → alívio (cadência), antecede exercícios de composição posteriores (FR-15). |

## State Patterns

| Estado | Superfície | Tratamento |
|---|---|---|
| Primeiro uso | App aberto sem conta | Abre direto no Nivelamento — sem tela de login prévia bloqueando a primeira vitória. [ASSUMPTION: autenticação, se houver, ocorre depois do nivelamento, não antes] |
| Resposta correta | Sessão de Exercício | Feedback visual + sonoro positivo imediato, mascote não aparece (fluxo não interrompe o ritmo da sessão). |
| Resposta incorreta | Sessão de Exercício | Mascote explica o erro (FR-4) num bubble curto, sem tela cheia de bloqueio. |
| Sessão travada em reforço (mesmo erro repetido) | Sessão de Exercício → Progressão Adaptativa | Desvia para exercícios de reforço relacionados (FR-7); nunca uma tela "bloqueado". |
| Sem microfone concedido | Nivelamento / Exercícios de produção vocal | Nivelamento e módulo de Resolução (FR-1, FR-15) exigem produção vocal por decisão de PRD; sem permissão de microfone, o mascote explica que essas etapas específicas precisam de voz e oferece reabrir a permissão — não avança em modo só-reconhecimento para essas duas etapas. Demais exercícios do treino núcleo seguem com produção vocal opcional. |
| Nenhuma variação nova disponível (repetição) | Sessão de Exercício | Sistema evita repetir exercício idêntico dentro da janela de sessões recentes (FR-6); [ASSUMPTION] tratamento de fallback quando o banco de variações se esgota fica para design técnico. |
| Sessão ultrapassando 15 min | Sessão de Exercício | Sem mecânica de recompensa por sessão mais longa (FR-5); ao se aproximar do tempo alvo, o app oferece encerrar com o progresso já contabilizado, sem culpa por não continuar. |
| Offline / sem conexão | Sessão de Exercício | Áudio pré-renderizado já baixado permite continuar a sessão; progresso sincroniza ao voltar a conexão. [ASSUMPTION] estratégia de download prévio de amostras de áudio fica para design técnico. |
| Dia ruim (Habilidade caiu) | Home, Resumo de Sessão | Medidor de Esforço em destaque, mensagem reforça constância, nunca trata queda como falha. |
| Vitória de marco (ex: fim do nivelamento, novo nó do skill tree) | Resumo de Sessão / Skill Tree | Mascote celebra explicitamente — a "vitória genuína" central do produto. |

## Interaction Primitives

- Tap para responder exercícios de múltipla escolha.
- Push-to-talk (segurar para gravar, soltar para enviar) é o mecanismo de captura de resposta vocal.
- Swipe não usado para navegação primária dentro da sessão (evita saída acidental no meio do exercício).
- **Banido:** paywall interrompendo o fluxo de sessão, notificações de streak agressivas/culpa por dia perdido (alinhado à decisão do PRD de não punir regressão), texturas ou ícones de partitura tradicional.

## Accessibility Floor

Comportamental. Contraste visual vive em `DESIGN.md`.

- VoiceOver / TalkBack: todo elemento interativo rotulado com papel + estado; medidores anunciam valores numéricos, não só posição visual da barra.
- Dynamic type honrado via tokens de `DESIGN.md`; nenhum controle trunca no tamanho máximo de acessibilidade.
- Captura vocal tem alternativa não-vocal disponível no treino núcleo (FR-3 é opcional ali); Nivelamento e Resolução exigem voz por decisão de produto (FR-1, FR-15, ver State Patterns) — [NOTE FOR UX] essa é uma barreira de acessibilidade real para quem não pode/quer usar voz, e o PRD não previu exceção; vale revisitar com o autor do PRD antes da arquitetura.
- Scaffold de cor (FR-14) nunca é o único sinal — sempre acompanhado de ícone/texto (ver `DESIGN.md.Components`), para não depender de percepção de cor.
- Contraste mínimo AA (4.5:1 para texto normal, 3:1 para texto grande/elementos gráficos) exigido em todos os pares de token de `DESIGN.md`, inclusive `effort-track`/`skill-track`/`scaffold-*` contra `surface-base`/`surface-base-dark` — [NOTE FOR UX] paleta pastel precisa de checagem de contraste real antes de produção, tons muito claros podem não passar em AA.
- Alvos de toque ≥ 44pt (iOS) / 48dp (Android).
- Áudio de exercício sempre acompanhado de opção de replay — sem limite arbitrário de repetições que penalize quem precisa de mais tempo de escuta.

## Inspiration & Anti-patterns

- **Rejeitado — visual de apps tradicionais de treino de ouvido:** telas densas, ícones técnicos de partitura, paleta fria corporativa. CatEar vai na direção oposta — quente, redondo, com mascote.
- **Rejeitado — punição por streak perdida:** alinhado à decisão do PRD (Medidor de Esforço nunca cai); nenhuma mecânica de culpa por dia não jogado.
- **Lifted from Duolingo:** estrutura de sessão curta diária + skill tree visível como mapa de progressão — mas sem a pressão agressiva de streak.
- [NOTE FOR UX] Usuário optou por não trazer referências visuais externas específicas neste momento (paleta ainda não decidida em hex, mascote sem referência de ilustração) — sinalizado como assumption em `DESIGN.md`, não inventado aqui.
- **Deferido — surpresas/aleatoriedade estilo "loot" de dungeon crawler:** ideia do brainstorming original, mantida em `prd.md` §8 Roadmap (Post-v1) como visão de retenção futura. Não faz parte da v1 — sinalizada aqui apenas para não ser reintroduzida sem querer numa v2 sem revisitar a fundamentação pedagógica primeiro.

## Key Flows

### Flow 1 — Primeira sessão (Marina, 27 anos, abre o app pela primeira vez)

1. Marina abre o app e cai direto no Nivelamento — sem tela de login bloqueando.
2. Faz exercícios de reconhecimento e, em seguida, é convidada a cantar de volta um intervalo simples.
3. Ao acertar, o mascote gatinho aparece com uma mensagem calorosa de boas-vindas + celebração.
4. **Climax:** tela de Resumo mostra seu nível de partida atribuído e a mensagem "Essa foi sua primeira vitória" — prova imediata de que ela consegue.
5. É direcionada à Home, com CTA para a sessão do dia seguinte.

Edge case: se Marina não conceder acesso ao microfone, o nivelamento segue só com reconhecimento, e o mascote explica gentilmente que ela pode ativar a voz depois.

### Flow 2 — Sessão diária com erro (Marina, dia 5, sessão de 12 minutos)

1. Marina abre o app, toca "Praticar" na Home.
2. Sessão de Exercício apresenta uma sequência de intervalos em contexto musical.
3. Ela erra um exercício — confundiu 3ª maior com 3ª menor.
4. O mascote aparece num bubble curto explicando a confusão especificamente (FR-4), sem tela de bloqueio.
5. Ela continua a sessão; ao final, chega no Resumo.
6. **Climax:** os dois medidores atualizam — Esforço sobe (ela completou a sessão), Habilidade reflete a performance real do dia, ambos visíveis lado a lado, sem julgamento sobre o erro.

### Flow 3 — Prova de progresso (Marina, semana 3, abre a aba Progresso)

1. Marina toca a aba Progresso.
2. Vê o Baseline comparison card: tempo de reação em terças menores, dia 1 vs. hoje.
3. **Climax:** o card mostra "2,1s → 1,4s — você está mais rápido", com destaque visual na melhora — vitória mensurável e inegável, mesmo que ontem tenha sido um dia ruim.

Edge case: se não houver melhora mensurável ainda (usuário muito recente), o card mostra a baseline registrada com mensagem de que a comparação aparece a partir da segunda sessão. [ASSUMPTION: prazo exato de quando a comparação passa a ser mostrada, a definir.]

### Flow 4 — Primeira Resolução (Marina, estágio inicial do skill tree)

1. Marina chega a um nó do skill tree marcado com o Resolução module card.
2. Abre um exercício dedicado: ouve uma progressão que cria tensão, depois a resolução (cadência).
3. É convidada a cantar de volta a nota de resolução — produção vocal obrigatória aqui (FR-15).
4. **Climax:** o mascote reforça a sensação ("Sentiu aquele alívio? Isso é resolução.") — a ponte entre percepção intuitiva e composição, sem nomear teoria formal antes de sentir o efeito.
5. O nó do skill tree marca esse conceito como trabalhado, disponível para reforço futuro.

Edge case: sem microfone concedido, o mascote explica que essa etapa específica precisa de voz e oferece reabrir a permissão (ver State Patterns) — não há atalho de reconhecimento passivo para este módulo.
