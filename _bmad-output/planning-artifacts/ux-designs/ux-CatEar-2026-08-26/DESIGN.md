---
name: CatEar
status: final
created: 2026-08-26
updated: 2026-08-26
description: App mobile de ouvido relativo estilo Duolingo, mascote gatinho, tom pastel laranja confortável, fugindo da estética acadêmica/matemática dos apps de treino de ouvido tradicionais.
colors:
  surface-base: '#FFF7EE'
  surface-raised: '#FFFFFF'
  ink-primary: '#3A2E22'
  ink-secondary: '#8A7A6B'
  ink-disabled: '#C9BDAF'
  accent: '#FFC067'
  accent-soft: '#FBD9B8'
  effort-track: '#E8A33D'
  skill-track: '#7FB396'
  scaffold-consonant: '#7FB396'
  scaffold-dissonant: '#E07856'
  border-hairline: '#F0E3D2'
  surface-base-dark: '#2B241D'
  surface-raised-dark: '#352C23'
  ink-primary-dark: '#F5EBDD'
  ink-secondary-dark: '#C4B3A0'
  ink-disabled-dark: '#6E6255'
  accent-dark: '#FFC067'
  accent-soft-dark: '#5A4633'
  effort-track-dark: '#F2B85C'
  skill-track-dark: '#9BCBAE'
  scaffold-consonant-dark: '#9BCBAE'
  scaffold-dissonant-dark: '#EB9878'
  border-hairline-dark: '#463A2E'
typography:
  display:
    note: 'Fredoka — usada só no mascote falando e em telas de vitória — nunca no corpo do app.'
  title:
    note: 'Platform native — iOS Title 2 · Android Headline Small'
  body:
    note: 'Platform native — iOS Body · Android Body Large'
  meta:
    note: 'Platform native — iOS Footnote · Android Body Small'
rounded:
  sm: 10px
  md: 18px
  lg: 28px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
components:
  mascot-bubble: 'Balão de fala do mascote gatinho, canto arredondado lg, sempre em surface-raised com borda accent-soft.'
  progress-meter: 'Par de barras (Habilidade + Esforço), ver Components abaixo.'
---

## Brand & Style

CatEar existe pra fazer o oposto do que os apps de treino de ouvido tradicionais fazem. [NOTE FOR UX] Sem uma lista nomeada de apps concorrentes pra citar por nome — a diretriz do usuário foi "os apps tradicionais do mercado" como anti-referência genérica: telas densas de tabela, ícones técnicos de partitura, paletas frias cinza/azul corporativo, sensação de ferramenta de laboratório. CatEar vai na direção oposta: quente, redondo, brincalhão — mais "app de bichinho de estimação" do que "software educacional".

O mascote é um gatinho professor gentil, num estilo cartunesco vetorial flat com contornos grossos (não realista, não pixel-art) — no espírito dos mascotes de apps de hábito consumer. Ele está presente nos momentos de feedback (acerto, erro, vitória, resumo de sessão), não como navegação constante — guia emocional, não chrome de interface.

A paleta é pastel laranja, desenhada pra ser confortável aos olhos em uso diário (sessões de 10-15 min), evitando saturação agressiva ou contraste duro. Modo escuro replica o mesmo aconchego em tons mais profundos, não um tema "frio" à parte.

## Colors

- **Base Creme (`#FFF7EE`)** é o fundo primário em modo claro — quente, não branco puro, reduz cansaço visual em sessões diárias.
- **Laranja Pastel / Accent (`#FFC067`)** é a cor de ação primária — botões de "praticar", CTA de sessão, destaque do mascote. Usada com moderação, nunca como fundo de tela inteira.
- **Accent Soft (`#FBD9B8`)** para fundos suaves de destaque (balão do mascote, card de vitória) — nunca para texto.
- **Effort Track (`#E8A33D`)** e **Skill Track (`#7FB396`)** são as duas únicas cores reservadas exclusivamente aos dois medidores de retenção (§ Component Patterns em EXPERIENCE.md) — nunca reutilizadas em outro contexto, pra manter a leitura visual inequívoca entre Esforço e Habilidade.
- **Scaffold Consonant (`#7FB396`) / Scaffold Dissonant (`#E07856`)** são o andaime de cor do FR-14 (consonância/dissonância) — sempre acompanhadas de um ícone/rótulo não-visual (ver Components), nunca cor isolada como único sinal, pra não criar barreira de acessibilidade a daltonismo.
- **Ink Primary (`#3A2E22`)** é o texto principal — marrom quente escuro, não preto puro, mantendo a paleta aconchegante mesmo no texto.

Evitar: vermelho puro/saturado para erro (feedback de erro é gentil, ver Do's and Don'ts), azul corporativo/cinza técnico, qualquer textura que remeta a partitura ou pauta musical, gradientes néon.

[ASSUMPTION] Paleta completa (hex exatos) é uma primeira proposta a validar visualmente — o usuário confirmou a direção "pastel laranja confortável" mas não os valores hex específicos.

## Typography

Convenções de plataforma como base: iOS Title 2 / Body / Footnote; Android Headline Small / Body Large / Body Small. Dynamic type respeitado em todos os níveis.

**Fredoka** é a fonte de display, reservada exclusivamente para falas do mascote e telas de vitória/marco — nunca para corpo de texto ou dados (números de progresso usam a fonte de sistema, para legibilidade e para não competir com o tom brincalhão do mascote).

## Layout & Spacing

Escala: 4 / 8 / 12 / 16 / 24 / 32px. Telas de exercício priorizam respiro generoso — um foco por tela (o áudio, a pergunta, a resposta), nunca densidade de formulário.

Margens mobile seguem convenção de plataforma (iOS 16pt, Android 16dp). Navegação de coluna única; nenhuma tabela densa de dados — mesmo a tela de progresso usa cards e gráficos simples, não planilhas.

## Elevation & Depth

Elevação sutil e quente — cards (`surface-raised`) se destacam do fundo (`surface-base`) com sombra leve e quente (não cinza fria), reforçando a sensação tátil/brinquedo em vez de "painel de admin". O balão de fala do mascote sempre flutua visualmente acima do conteúdo com leve sombra.

## Shapes

`rounded/sm` (10px) para inputs e badges pequenos. `rounded/md` (18px) para cards de exercício e botões primários. `rounded/lg` (28px) reservado ao balão de fala do mascote e ao card de vitória de fim de sessão — o elemento mais "redondo" da tela reforça onde a emoção está.

Nada de cantos retos ou aparência de tabela/planilha — isso é o oposto do tom que o produto busca.

## Components

- **Mascot bubble** — Balão de fala do gatinho professor, `rounded/lg`, fundo `accent-soft`, aparece em: boas-vindas do nivelamento, feedback de erro explicativo, celebração de vitória, resumo de sessão. Nunca aparece durante o exercício em si (não distrai da escuta).
- **Progress meter (par)** — Duas barras lado a lado ou empilhadas: Esforço (`effort-track`, sempre cheia/crescente) e Habilidade (`skill-track`, pode oscilar). Sempre exibidas juntas, nunca uma sem a outra — reforça a decisão de produto do PRD (FR-9, FR-10, FR-11).
- **Exercise card** — `surface-raised`, `rounded/md`, centraliza o player de áudio e a área de resposta (múltipla escolha ou captura vocal). Um exercício por tela.
- **Skill tree node** — Nó circular pequeno (`rounded/sm` aplicado a um badge, não um círculo perfeito — ver Do's/Don'ts) representando um estágio do currículo; estado visual: bloqueado/disponível/completo/em reforço.
- **Baseline comparison card** — Card simples com dois números lado a lado (baseline dia 1 vs. atual) e uma seta ou diferença destacada em `skill-track` quando houve melhora.
- **Scaffold cue (consonância/dissonância)** — Badge pequeno (`rounded/sm`) combinando cor (`scaffold-consonant`/`scaffold-dissonant`) + ícone/símbolo distinto (não só cor) + rótulo curto de texto. A intensidade visual do badge (opacidade, presença do rótulo de texto) diminui progressivamente pelos estágios do skill tree — fading scaffold do FR-14 — até desaparecer nos estágios avançados.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Paleta quente pastel, contraste suave | Cinza corporativo / azul técnico dos apps tradicionais |
| Mascote gatinho como voz emocional nos momentos certos | Mascote como chrome de navegação constante |
| Feedback de erro gentil, explicativo, sem vermelho saturado | Vermelho de alerta agressivo, "X" duro |
| Um foco por tela nos exercícios | Telas densas tipo formulário/planilha |
| Cores dos medidores (Esforço/Habilidade) exclusivas a eles | Reusar `effort-track`/`skill-track` em outros elementos |
| Cantos arredondados e sombras quentes | Ícones ou texturas de partitura/pauta musical |
