---
status: final
updated: 2026-09-01
stepsCompleted: [step-01, step-02, step-03, step-04]
inputDocuments:
  - "_bmad-output/planning-artifacts/prds/prd-CatEar-2026-08-26/prd.md"
  - "_bmad-output/planning-artifacts/architecture/architecture-CatEar-2026-08-26/ARCHITECTURE-SPINE.md"
  - "_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/DESIGN.md"
  - "_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/EXPERIENCE.md"
---

# CatEar - Epic Breakdown

## Overview

Este documento decompõe os requisitos do PRD, da UX Design Spine (DESIGN.md + EXPERIENCE.md) e da Architecture Spine do CatEar em stories implementáveis. Projeto hobby/solo, app mobile Flutter, v1 local-first sem backend.

## Requirements Inventory

### Functional Requirements

- **FR-1:** Teste de nivelamento com produção ativa — sequência curta de exercícios de reconhecimento + produção vocal de intervalos, atribuindo um nível de partida e entregando a primeira vitória genuína. (UJ-1)
- **FR-2:** Exercícios de reconhecimento de intervalos, acordes e escalas, com áudio de timbre real (amostras pré-renderizadas) em contexto musical (melodia/progressão), nunca notas isoladas. (UJ-2)
- **FR-3:** Produção ativa em exercícios — responder cantando de volta; obrigatória no nivelamento (FR-1) e no módulo de Resolução (FR-15), opcional no treino núcleo.
- **FR-4:** Feedback explicativo em erro — nomear o conceito confundido (ex: "confundiu 3ª maior com 3ª menor"), nunca só "errado".
- **FR-5:** Sessões curtas diárias — conteúdo estruturado em sessões de 10–15 min; sem mecânica que recompense sessão maratona.
- **FR-6:** Geração de variações (anti-decoreba) — variações dos exercícios em vez de conjunto fixo; sem repetição idêntica dentro de janela de sessões recentes.
- **FR-7:** Dificuldade adaptativa sem paredes de bloqueio — ajuste dinâmico; desvio para rota de reforço em vez de tela "bloqueado".
- **FR-8:** Skill tree visível — mapa de progressão acessível a qualquer momento pela navegação principal.
- **FR-9:** Medidor de Habilidade — reflete performance real e recente; pode cair.
- **FR-10:** Medidor de Esforço — monotônico (só cresce); toda sessão completada o incrementa.
- **FR-11:** Recompensa ponderada por esforço — sistema de recompensa pesa mais o Esforço; sessão de baixa performance mas completa gera recompensa positiva visível.
- **FR-12:** Registro de baseline do dia 1 — métricas da primeira sessão pós-nivelamento, registradas uma única vez, nunca sobrescritas.
- **FR-13:** Comparação de progresso vs. baseline — tela mostra ≥1 métrica comparada (baseline vs. recente) com valores numéricos.
- **FR-14:** Andaime de cor para consonância/dissonância com fading — pista de cor nos estágios iniciais, reduzida progressivamente, nunca na intensidade original nos avançados.
- **FR-15:** Módulo de Resolução no currículo inicial — exercícios dedicados a tensão → alívio (cadência) nos primeiros estágios do skill tree.
- **FR-16:** Registro local de sinais de calibração (telemetria) — eventos estruturados de sessão gravados localmente, atrás de flag; com flag desligada nenhum evento é gravado e o app se comporta igual; nada é transmitido para fora do dispositivo na v1; não altera medidores/skill tree/baseline/dificuldade. *(opcional na v1 — ver Open Question 6 do PRD)*

### NonFunctional Requirements

- **NFR-1 (Qualidade de áudio):** Todo áudio de exercício usa amostras de instrumento real pré-renderizadas e testadas — nunca síntese em runtime.
- **NFR-2 (Tom & estética):** A interface soa e parece um app de música, nunca uma aula — linguagem e visual evitam referência a "matemática" ou notação acadêmica pesada (PRD §1.1). Aplica-se a textos, telas de erro, onboarding.
- **NFR-3 (Local-first):** v1 sem backend; toda persistência é local (SQLite via Drift), sempre disponível offline.
- **NFR-4 (Paridade de plataforma):** iOS + Android com paridade completa de funcionalidade.
- **NFR-5 (Acessibilidade):** VoiceOver/TalkBack — todo elemento interativo rotulado com papel + estado; medidores anunciam valores numéricos. Dynamic type honrado sem truncar no tamanho máximo. Contraste mínimo AA (4.5:1 texto normal, 3:1 texto grande/gráfico) em todos os pares de token. Alvos de toque ≥ 44pt (iOS) / 48dp (Android). Scaffold de cor nunca é o único sinal. Replay de áudio sem limite arbitrário.
- **NFR-6 (Privacidade da telemetria):** Sinais de calibração (FR-16) ficam estritamente no dispositivo na v1 — nenhum envio remoto.
- **NFR-7 (Sem OTA na v1):** Catálogo de currículo é embarcado no app; muda só com nova versão publicada. *(decisão de produto a confirmar — Open Question 5 do PRD)*
- **NFR-8 (Barreira de acessibilidade conhecida e aceita):** Nivelamento e Resolução exigem produção vocal sem fallback não-vocal na v1 — quem não pode/quer usar voz fica bloqueado nessas duas etapas. Risco conhecido e aceito, a revisitar.

### Additional Requirements

*(da Architecture Spine — CatEar-2026-08-26)*

- **AR-1 (Greenfield / setup):** App Flutter novo, sem template starter nomeado. Stack fixada: Flutter 3.47.x, Riverpod (codegen) 3.4.2, Drift 2.34.3, `record` 7.1.1, `just_audio` 0.10.6. Biblioteca de detecção de pitch **NÃO fixada** — spike técnico obrigatório (nenhuma opção madura no ecossistema Flutter; `flutter_pitch_detection` é Android-only, gap de cobertura iOS) antes de comprometer a implementação de produção vocal de produção.
- **AR-2 (Módulos por feature — AD-1):** Estrutura `lib/{core, nivelamento, exercicios, progressao, audio, curriculo, telemetria}`, cada módulo com `data/ domain/ presentation/`. Cada módulo expõe um único barrel público (`{modulo}.dart`); `data/` e `presentation/` nunca importados fora do módulo. Regra de lint `implementation_imports` (`custom_lint`/`import_lint`) configurada no CI local desde o início.
- **AR-3 (Single-writer — AD-2):** O módulo **Progressão** é o único autorizado a escrever Medidor de Habilidade, Medidor de Esforço, estado dos nós do Skill Tree (enum `bloqueado | disponível | completo | em_reforço | capstone_futuro` — nó de Audiação nasce fixo em `capstone_futuro`), Baseline, decisão de dificuldade adaptativa e histórico de variações recentes por tipo de exercício. Demais módulos só leem via `domain/` do Progressão.
- **AR-4 (Eventos de domínio tipados — AD-2):** `SessionResultReported` (Exercícios → Progressão): `sessionId: String`, `attempts: List<ExerciseAttempt>` (uma entrada por tentativa; agregação é da Progressão), `ExerciseAttempt = { exerciseType: ExerciseType, wasCorrect: bool, errorType: ErrorType?, reactionTimeMs: int }`. `BaselineRecorded` (Exercícios → Progressão): emitido uma única vez, pela **primeira Sessão de Exercício concluída** após o nivelamento (não pelo módulo Nivelamento); a Progressão rejeita um segundo. Transporte: método de ingestão no `domain/` da Progressão chamado via provider Riverpod — sem event bus global.
- **AR-5 (Dificuldade como snapshot — AD-2):** O Exercícios lê a dificuldade adaptativa como snapshot fixado no início da sessão (a Progressão calcula e fixa ao abrir a Sessão de Exercício), não como stream reativo.
- **AR-6 (AudioService — AD-3):** Toda reprodução, gravação e avaliação de afinação passa por uma interface única `AudioService` (`domain/` do módulo Áudio). `just_audio`, `record` e a lib de pitch são detalhes de implementação; nenhum outro módulo os importa. Captura vocal = push-to-talk (grava enquanto segura, avalia ao soltar). `AudioService.evaluatePitch()` retorna `Future<PitchEvaluationResult>` (resultado único pós-gravação), não `Stream`. `PitchEvaluationResult = { detectedNote: String?, centsOffFromExpected: int?, withinTolerance: bool }`.
- **AR-7 (Fakes de áudio — AD-3):** `FakeAudioService` (reprodução, gravação e `evaluatePitch`) implementado desde o dia zero, permitindo construir e testar a lógica de dificuldade adaptativa e de fluxo de exercício injetando frequências/resultados falsos, sem microfone físico. Nenhum teste de Exercícios/Nivelamento/Progressão depende de hardware de áudio real.
- **AR-8 (Currículo é dado — AD-4):** O módulo Currículo expõe o conteúdo como catálogo JSON versionado (asset embarcado), schema fixo (`stages[].exercises[]` com `exerciseType`, `audioSampleRefs`, `scaffoldIntensity`; `errorTypes[]` como taxonomia canônica). `ExerciseType` e `ErrorType` são definidos **só** no Currículo. Invariante de fading: `scaffoldIntensity` não-crescente ao longo dos estágios que usam scaffold de cor — validado por teste/lint de conteúdo **antes de qualquer build**. `CurriculoRepository.load()` não promete origem (porta aberta para OTA futuro).
- **AR-9 (Fluxo de mutação — AD-5):** Toda mutação segue `UI → Riverpod Notifier → Repository (domain) → Drift DAO`. Leitura reativa: Drift stream → Repository → Riverpod provider → UI. Nenhuma tela chama Drift diretamente. Classes/tabelas geradas pelo Drift nunca cruzam a fronteira `data/ → domain/`; `core/` expõe só o `Database` e DAOs, interfaces de repositório e modelos de domínio puros vivem no `domain/` de cada módulo.
- **AR-10 (Telemetria passiva — AD-6):** O módulo `telemetria/` só escuta eventos de domínio existentes e só lê via `domain/` de outros módulos; é dono exclusivo de uma única tabela nova `telemetry_events` (append-only, local, segue AD-5). Opcional atrás de flag de compilação; app idêntico com ele desligado.
- **AR-11 (Convenções):** IDs de entidade como `String` (UUID v4). Datas em ISO 8601 UTC no banco, conversão para local só na apresentação. Erros de domínio como `sealed class` por módulo, nunca exceptions genéricas cruzando fronteira. Estado assíncrono via `AsyncValue` do Riverpod em toda a árvore de providers.
- **AR-12 (Distribuição):** App id, ícones, splash e assinatura configurados cedo para não exigir retrabalho na publicação. Build flavors (dev/release) adiados. Builds locais/debug no início.

### UX Design Requirements

*(de DESIGN.md + EXPERIENCE.md — ux-CatEar-2026-08-26)*

- **UX-DR1 (Design tokens):** Implementar em `core/` a paleta completa light + dark como tokens: `surface-base/raised`, `ink-primary/secondary/disabled`, `accent`, `accent-soft`, `effort-track`, `skill-track`, `scaffold-consonant/dissonant`, `border-hairline` (+ variantes `-dark`); raios `rounded/sm` 10px, `md` 18px, `lg` 28px; escala de espaçamento 4/8/12/16/24/32px.
- **UX-DR2 (Tipografia):** Fonte de display **Fredoka** reservada exclusivamente a falas do mascote e telas de vitória/marco. Corpo, títulos e números usam fontes de sistema (iOS Title 2/Body/Footnote · Android Headline Small/Body Large/Body Small). Dynamic type respeitado em todos os níveis.
- **UX-DR3 (Navegação):** Bottom tab bar com 4 abas: Home / Skill Tree / Progresso / Settings. Sem drawer. Modal (ex: explicação de erro) empilha só um nível.
- **UX-DR4 (Mascot bubble):** Balão de fala do gatinho, `rounded/lg`, fundo `accent-soft` com borda `accent-soft`, sombra quente flutuando acima do conteúdo. Aparece só em: boas-vindas do nivelamento, feedback de erro explicativo, celebração de vitória, resumo de sessão. **Nunca** durante o áudio do exercício.
- **UX-DR5 (Progress meter — par):** Duas barras — Esforço (`effort-track`, sempre cheia/crescente) e Habilidade (`skill-track`, oscila). Sempre exibidas juntas, nunca uma sem a outra. Usadas em Home, Resumo de Sessão e Progresso. Cores `effort-track`/`skill-track` nunca reutilizadas em outro contexto.
- **UX-DR6 (Exercise card):** `surface-raised`, `rounded/md`, um exercício por tela, centraliza player de áudio + área de resposta (múltipla escolha ou captura vocal). Respiro generoso, nunca densidade de formulário. Botão de replay de áudio sempre presente, sem limite.
- **UX-DR7 (Skill tree node):** Badge (`rounded/sm`, não círculo perfeito) por estágio do currículo; estados visuais: bloqueado / disponível / completo / em reforço. "Em reforço" nunca é estado de bloqueio — sempre navegável.
- **UX-DR8 (Skill tree capstone node):** Nó de Audiação no topo da árvore, presente mas marcado "em breve", nunca navegável na v1.
- **UX-DR9 (Baseline comparison card):** Card com dois números lado a lado (baseline dia 1 vs. atual) + diferença/seta destacada em `skill-track` quando houve melhora. Narrativa nos números ("2,1s → 1,4s — você está mais rápido"), nunca número seco.
- **UX-DR10 (Scaffold cue):** Badge pequeno (`rounded/sm`) = cor (`scaffold-consonant`/`scaffold-dissonant`) + ícone/símbolo distinto + rótulo curto de texto. Intensidade visual (opacidade, presença do rótulo) diminui progressivamente pelos estágios até sumir nos avançados (FR-14). Nunca cor isolada como único sinal.
- **UX-DR11 (Resolução module card):** Card de exercício dedicado a tensão → alívio, marcado como tal, posicionado nos estágios iniciais do skill tree.
- **UX-DR12 (State patterns):** Primeiro uso abre direto no Nivelamento (sem login prévio). Resposta correta: feedback visual+sonoro imediato, sem mascote. Resposta incorreta: mascote explica num bubble curto, sem tela cheia. Sessão travada em reforço: desvia, nunca tela "bloqueado". Sem microfone: mascote explica que Nivelamento/Resolução precisam de voz e oferece reabrir permissão; demais exercícios seguem com voz opcional. Sessão passando de 15 min: oferece encerrar com progresso contabilizado, sem culpa. Dia ruim (Habilidade caiu): Esforço em destaque, mensagem reforça constância.
- **UX-DR13 (Interaction primitives):** Tap para múltipla escolha. Push-to-talk (segurar para gravar, soltar para enviar) para resposta vocal. Swipe não usado para navegação primária dentro da sessão (evita saída acidental). Banido: paywall interrompendo sessão, notificações de streak agressivas/culpa, texturas/ícones de partitura tradicional.
- **UX-DR14 (Microcopy / voz e tom):** Frases curtas, tom de professor gentil via mascote. Feedback de erro nomeia a confusão, nunca "errado" seco. Sem vermelho saturado para erro. Mensagem de Esforço acolhe em dia ruim ("Você praticou hoje. Isso conta."). Sem hype de marketing.
- **UX-DR15 (Modo escuro):** Replica o mesmo aconchego (creme → tons profundos quentes), não um tema "frio" à parte. Sombras quentes, não cinza frio.
- **UX-DR16 (Checagem de contraste da paleta):** A paleta pastel (hex ainda a validar) precisa de auditoria de contraste AA real antes de produção — inclusive `effort-track`/`skill-track`/`scaffold-*` contra `surface-base`/`surface-base-dark`.

### FR Coverage Map

- **FR-1:** Epic 1 (porção de reconhecimento) + Epic 3 (porção de produção vocal) — teste de nivelamento
- **FR-2:** Epic 1 — exercícios de reconhecimento de intervalos/acordes/escalas com áudio real em contexto
- **FR-3:** Epic 3 — produção ativa (cantar de volta)
- **FR-4:** Epic 1 — feedback explicativo em erro
- **FR-5:** Epic 1 — sessões curtas de 10–15 min
- **FR-6:** Epic 1 — geração de variações (anti-decoreba)
- **FR-7:** Epic 2 — dificuldade adaptativa sem paredes de bloqueio
- **FR-8:** Epic 2 — skill tree visível
- **FR-9:** Epic 2 — Medidor de Habilidade
- **FR-10:** Epic 2 — Medidor de Esforço
- **FR-11:** Epic 2 — recompensa ponderada por esforço
- **FR-12:** Epic 2 — registro de baseline do dia 1
- **FR-13:** Epic 2 — comparação de progresso vs. baseline
- **FR-14:** Epic 2 — andaime de cor com fading *(o lint da invariante de fading do conteúdo, AR-8, já começa no Epic 1)*
- **FR-15:** Epic 3 — módulo de Resolução (voz obrigatória)
- **FR-16:** Epic 4 — registro local de sinais de calibração

## Epic List

*Índice. Meta completa, mapeamento de requisitos e dependências ficam na seção de cada épico abaixo.*

1. **Epic 1 — Fundação técnica + primeiro loop de reconhecimento jogável** — FR-1 (reconhecimento), FR-2, FR-4, FR-5, FR-6
2. **Epic 2 — Progressão, medidores e prova de progresso** — FR-7 a FR-14 · depende do Epic 1
3. **Epic 3 — Produção ativa (voz)** — FR-1 (voz), FR-3, FR-15 · depende dos Epics 1 e 2 · abre com spike de risco
4. **Epic 4 — Telemetria de calibração** — FR-16 · depende dos Epics 1 e 2 · **confirmada na v1** (OQ 6 do PRD, decidida)

**Faseamento da FR-1:** o nivelamento nasce só-reconhecimento no Epic 1 e só satisfaz a consequência testável completa da FR-1 (reconhecimento **e** produção vocal) ao fim do Epic 3. Enquanto o Epic 3 não fecha, o produto é "completo para reconhecimento", não "v1 completa".

---

## Epic 1: Fundação técnica + primeiro loop de reconhecimento jogável

Ao fim deste épico o usuário abre o app, faz um nivelamento de reconhecimento, recebe um nível de partida com uma primeira vitória reconhecida, e pratica reconhecimento de intervalos, acordes e escalas em contexto musical, com variações a cada sessão e feedback explicativo em cada erro, em sessões de 10–15 min. É um app de treino de ouvido jogável, sem a parte de voz.

**FRs cobertas:** FR-1 (reconhecimento), FR-2, FR-4, FR-5, FR-6
**Requisitos de arquitetura:** AR-1, AR-2, AR-3 (fatia do histórico de variações — ver Story 1.8), AR-6 (apenas reprodução), AR-7, AR-8, AR-9, AR-11, AR-12
**Requisitos de UX:** UX-DR1, UX-DR2, UX-DR3, UX-DR6, UX-DR12 (parcial), UX-DR13, UX-DR14, UX-DR15, UX-DR16
**NFRs:** NFR-1, NFR-2, NFR-3, NFR-4, NFR-5 (base)
**Depende de:** nada — é o épico de fundação.

### Story 1.1: Abrir o app numa Home com navegação e tema

As a usuária,
I want abrir o CatEar e ver uma Home com a navegação principal e a identidade visual do app,
So that eu tenha um ponto de partida claro e o app pareça um app de música, não uma ferramenta técnica.

**Acceptance Criteria:**

- **Given** um projeto Flutter novo na versão da stack (Flutter 3.47.x, Riverpod codegen 3.4.2, Drift 2.34.3), **when** o app é construído, **then** existe a estrutura `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}`, cada módulo com `data/ domain/ presentation/` e um único barrel público `{modulo}.dart`.
- **Given** a regra de lint `implementation_imports` (`custom_lint`/`import_lint`) configurada no CI local, **when** um módulo importa `data/` ou `presentation/` de outro módulo, **then** o build falha.
- `core/` expõe os tokens de design como paleta completa light + dark (`surface-*`, `ink-*`, `accent`, `accent-soft`, `effort-track`, `skill-track`, `scaffold-*`, `border-hairline`), raios `rounded/sm|md|lg` (10/18/28px) e escala de espaçamento 4/8/12/16/24/32px (UX-DR1).
- `core/` inicializa o `Database` Drift e expõe apenas o `Database` e DAOs; modelos gerados pelo Drift não vazam para `domain/` (AR-9).
- O app abre numa Home com bottom tab bar de 4 abas — Home / Skill Tree / Progresso / Settings — sem drawer; modal empilha só um nível (UX-DR3).
- Tema claro pastel laranja é o padrão; modo escuro replica o mesmo aconchego em tons profundos, não um tema frio à parte (UX-DR15).
- Fonte de sistema para corpo/títulos/números; **Fredoka** disponível mas reservada a falas do mascote e telas de vitória; dynamic type respeitado (UX-DR2).
- App id, ícone e splash configurados; app roda em iOS e Android com paridade (AR-12, NFR-4).
- **Migração de schema Drift** estabelecida desde já: `schemaVersion` explícito e um `MigrationStrategy` com `onUpgrade` presente (mesmo que vazio na v1), para que os épicos seguintes adicionem tabelas sem apagar o banco local do usuário.
- **Auditoria de contraste da paleta (UX-DR16):** todos os pares de token de cor (texto sobre superfície, e `effort-track`/`skill-track`/`scaffold-*` sobre `surface-base`/`surface-base-dark`) verificados em AA (4.5:1 texto normal, 3:1 texto grande/gráfico); hex ajustados onde reprovarem. Nenhum épico seguinte prossegue sobre pares reprovados. [ASSUMPTION] os hex do DESIGN.md são proposta inicial — esta auditoria pode alterá-los.

### Story 1.2: Catálogo de currículo como dado, com invariante de fading validada

As a criador,
I want o conteúdo pedagógico como catálogo JSON embarcado lido por um repositório,
So that ajustar o currículo não exija mudar código Dart.

**Acceptance Criteria:**

> **Contrato autoritativo:** `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md` (bloco `<frozen-after-approval>`). Os critérios abaixo foram refinados durante a implementação da Story 1.2 — a mudança principal: **`scaffoldIntensity` e `timbreScaffold` são por-estágio, não por-exercício** (a própria AC do lint filtra a "subsequência de estágios").

- Existe um asset JSON de currículo (`assets/curriculum/catalog_v1.json`) com schema fixo: `schemaVersion` (int) no topo; `stages[]` com `stageId`, `order` (int), `scaffoldIntensity` (float 0.0–1.0, **opcional, por-estágio**), `timbreScaffold` (`clean | vibrato`, opcional, por-estágio), `exercises[]`; cada `exercise` com `exerciseType` (`interval | chord | scale | resolution`), o id do tipo (`interval`/`chordQuality`/`scaleType`/`cadence`), `direction` (`asc | desc` — obrigatório em `interval`/`scale`, proibido em `chord`/`resolution`), `audioSampleRefs[]` (tokens `^[a-z0-9_]+$`), `requiresVoice` (bool — `true` sse e somente se `resolution`); mais `intervalCatalog`/`chordCatalog`/`scaleCatalog`/`cadenceCatalog` e `errorTypes[]` (taxonomia canônica, AR-8).
- `CurriculoRepository.load()` retorna modelos de domínio puros (`sealed class Exercise` + subtipos, sem anotação de ORM) e não promete a origem dos dados (porta aberta para OTA futuro).
- `ExerciseType` e `ErrorType` (e `Direction`, `TimbreScaffold`) são definidos **somente** no módulo Currículo; nenhum outro módulo inventa um valor fora dessa lista. `errorTypes[]` do JSON == conjunto exato dos valores do enum `ErrorType`.
- **Given** o catálogo v1, **when** `tool/check_curriculum.dart` roda antes do build, **then** ele falha se, na subsequência filtrada dos **estágios** que declaram `scaffoldIntensity` (ignorando os que não declaram — ausente ≠ 0.0), ordenada por `order` crescente, algum `scaffoldIntensity` for maior que o do estágio anterior. Mesma invariante não-crescente para "limpeza" de `timbreScaffold` (`clean` nunca depois de `vibrato`).
- O mesmo lint falha se `order` tiver valores duplicados ou não for estritamente crescente (após ordenar os estágios por `order` — o array pode estar em qualquer ordem).
- O catálogo v1 cobre a taxonomia completa do `content-model.md` §7: 10 estágios num `order` 1..10 — 7 de intervalo (13 intervalos), `s-escalas`, `s-acordes`, `s-resolucao` (os dados; o exercício de voz vem no Epic 3).
- **Exercícios de `resolution` carregam `requiresVoice: true`** no domínio; o enforcement de "oculto/inerte no skill tree e na geração de sessão" é das Stories 1.7/2.1 (registrado em `deferred-work.md`) — o fluxo de reconhecimento (Stories 1.4/1.5) nunca tenta renderizá-los.

### Story 1.3: AudioService com reprodução e FakeAudioService

As a criador,
I want uma interface `AudioService` que reproduza amostras pré-renderizadas, com uma implementação real e um fake,
So that exercícios toquem áudio sem acoplar à biblioteca e os testes rodem sem hardware.

**Acceptance Criteria:**

- `AudioService` vive no `domain/` do módulo `audio`; expõe reprodução de uma amostra por referência de asset.
- A implementação real usa `just_audio`; **apenas** o módulo `audio` importa `just_audio` (AR-6).
- Todo áudio de exercício usa amostras de instrumento real pré-renderizadas em `assets/audio/` — nunca síntese em runtime (NFR-1).
- **Todas as amostras da v1 são empacotadas no bundle do app** — não há download remoto de áudio na v1 (local-first). Onde `EXPERIENCE.md` fala em "áudio já baixado", entende-se "já embarcado". *(atualizar `EXPERIENCE.md` para remover a ambiguidade)*
- `FakeAudioService` implementa a mesma interface, registra as chamadas e simula reprodução sem tocar áudio real (AR-7).
- Um provider Riverpod injeta a implementação; testes recebem o fake.

### Story 1.3b: Produção do conjunto de amostras de áudio da v1

As a criador,
I want um conjunto de amostras de instrumento real pré-renderizadas cobrindo o currículo v1,
So that os exercícios tenham áudio para tocar.

**Acceptance Criteria:**

- Existe um conjunto de arquivos de áudio em `assets/audio/` cobrindo cada `audioSampleRef` referenciado pelo catálogo v1 (Story 1.2).
- Cada amostra é de timbre de instrumento real (gravada ou renderizada de biblioteca de samples licenciada), em contexto musical curto — nunca nota isolada sintetizada (FR-2, NFR-1).
- Formato, taxa de amostragem e loudness normalizados de forma consistente entre amostras. [ASSUMPTION] parâmetros exatos definidos aqui.
- A origem/licença de cada amostra é rastreável (nota de licenciamento no repo).
- **Depende de:** Story 1.2 (o catálogo define quais refs existem).

### Story 1.4: Exercício de reconhecimento de intervalo em contexto musical

As a usuária,
I want ouvir um trecho musical curto contendo um intervalo e escolher qual é,
So that eu treine reconhecimento auditivo real em vez de decorar bipes.

**Acceptance Criteria:**

- O exercício é apresentado num Exercise card (`surface-raised`, `rounded/md`, um exercício por tela, respiro generoso) (UX-DR6).
- **Given** um exercício de intervalo, **when** ele é apresentado, **then** o intervalo aparece dentro de uma melodia ou progressão curta, nunca como par de notas isoladas em silêncio (FR-2).
- O player tem botão de replay sem limite de repetições (NFR-5).
- A resposta é por tap em múltipla escolha (UX-DR13).
- **Given** uma resposta correta, **when** o usuário responde, **then** há feedback visual + sonoro positivo imediato e o mascote **não** aparece (não interrompe o ritmo) (UX-DR12).
- O tempo de reação da tentativa é registrado.

### Story 1.5: Exercícios de reconhecimento de acordes e escalas

As a usuária,
I want exercícios de reconhecimento de acordes e de escalas no mesmo formato dos de intervalo,
So that o treino cubra os três tipos de conteúdo do produto.

**Acceptance Criteria:**

- Exercícios de tipo `chord` e `scale` renderizam no mesmo Exercise card e fluxo da Story 1.4.
- O áudio é apresentado em contexto musical, não como bloco isolado.
- Nenhum código específico por tipo de exercício no fluxo de apresentação — a diferença vem dos dados do catálogo (FR-2, AR-8).

### Story 1.6: Feedback explicativo em erro

As a usuária,
I want que ao errar o app me diga o que eu confundi,
So that o erro vire aprendizado e não só punição.

**Acceptance Criteria:**

- **Given** uma resposta incorreta, **when** o usuário responde, **then** um mascot bubble (`rounded/lg`, fundo `accent-soft`, sombra quente acima do conteúdo) aparece com uma explicação que nomeia o conceito confundido (ex: "Quase lá — você confundiu 3ª maior com 3ª menor") (FR-4, UX-DR4).
- O `errorType` da tentativa vem da taxonomia canônica do Currículo, nunca string livre (AR-4, AR-8).
- **Given** uma resposta errada que não casa com nenhum `errorType` do catálogo (`errorType == null`), **when** o feedback é exibido, **then** o mascote usa uma explicação genérica-mas-acolhedora que ainda nomeia o que era o certo (ex: "A resposta era 5ª justa — ouça de novo o salto entre as notas"), nunca só "errado".
- Nenhuma tela de erro mostra apenas "errado"/"incorreto" sem explicação; sem vermelho saturado (UX-DR14).
- O modal de explicação empilha só um nível.

### Story 1.7: Estrutura de sessão de 10–15 minutos

As a usuária,
I want que os exercícios venham organizados numa sessão curta com início, sequência e fim,
So that eu pratique em blocos diários sustentáveis.

**Acceptance Criteria:**

- Uma Sessão de Exercício monta uma sequência a partir do catálogo dimensionada para 10–15 min de uso típico (FR-5).
- **Given** a sessão se aproximando do tempo alvo, **when** o limite se aproxima, **then** o app oferece encerrar com o progresso já contabilizado, sem culpa por não continuar (UX-DR12).
- Não há mecânica que recompense sessões muito mais longas que o padrão.
- Swipe não é usado para navegação primária dentro da sessão (evita saída acidental) (UX-DR13).
- **`sessionId` é um UUID v4 gerado na abertura da sessão** (AR-11).
- **Definição de "sessão concluída":** a sessão conta como concluída quando o usuário chega ao fim da sequência **ou** aceita o encerramento oferecido ao atingir o tempo alvo, tendo respondido **ao menos um** exercício. Sair antes disso (fechar o app, voltar) é **abandono**.
- **Given** uma sessão concluída, **when** ela termina, **then** ela emite `SessionResultReported` uma única vez, com `sessionId` e `attempts` (uma entrada por tentativa: `exerciseType`, `wasCorrect`, `errorType?`, `reactionTimeMs`) — nesta fase o evento é apenas emitido/logado; o consumidor entra no Epic 2 (AR-4).
- **Given** uma sessão abandonada, **when** o usuário sai, **then** nenhum `SessionResultReported` é emitido (as tentativas já feitas são descartadas para fins de progressão; a telemetria do Epic 4, se ligada, registra o abandono separadamente).

### Story 1.8: Geração de variações (anti-decoreba)

As a usuária,
I want que a sessão gere variações dos exercícios em vez de repetir o mesmo conjunto fixo,
So that eu reconheça padrão real e não memorize áudios específicos.

**Acceptance Criteria:**

- **Given** as últimas N tentativas registradas (janela por contagem de exercícios, não por sessão — para não penalizar quem faz várias sessões no mesmo dia), **when** exercícios são gerados, **then** nenhum exercício se repete de forma idêntica (mesmo áudio + mesma pergunta) dentro dessa janela (FR-6). [ASSUMPTION] valor de N a calibrar; padrão inicial documentado na implementação.
- A variação usa parâmetros do catálogo, não conteúdo hardcoded na lógica.
- **Given** o pool de variações de um tipo/estágio se esgotou dentro da janela, **when** um novo exercício é necessário, **then** o gerador escolhe a variação **menos recentemente usada** (permite repetição controlada) em vez de travar ou repetir a última — comportamento explícito, não indefinido.
- **Propriedade do histórico:** a tabela de histórico de variações recentes é a que a arquitetura (AD-2) atribui ao módulo **Progressão** como dono único. Esta story cria a fatia mínima de `progressao/` para isso — tabela + repositório de escrita — e escreve por ele. O Epic 2 (Story 2.1) estende o mesmo módulo com o resto do estado; não há reescrita.

### Story 1.9: Nivelamento por reconhecimento

As a usuária de primeira viagem,
I want fazer um teste inicial de reconhecimento e receber um nível de partida com uma primeira vitória reconhecida,
So that eu comece no ponto certo e sinta desde já que consigo.

**Acceptance Criteria:**

- **Given** o primeiro uso do app, **when** ele abre, **then** cai direto no Nivelamento, sem tela de login prévia bloqueando (UX-DR12).
- O nivelamento apresenta uma sequência curta de exercícios de reconhecimento (múltipla escolha) [ASSUMPTION: número exato em design de currículo].
- **O primeiro exercício do nivelamento é deliberadamente fácil** (intervalo muito contrastante, ex: uníssono vs. oitava) para maximizar a chance de um acerto logo no início.
- **Given** o fim do nivelamento com **ao menos um acerto**, **when** ele termina, **then** o mascote celebra explicitamente essa primeira vitória.
- **Given** o fim do nivelamento com **zero acertos**, **when** ele termina, **then** o mascote celebra a conclusão em si e o começo da jornada ("Você deu o primeiro passo — é daqui que a gente parte"), sem expor o placar — nunca deixa o usuário sem um momento positivo.
- **Given** o fim do nivelamento, **when** ele termina, **then** um nível de partida é atribuído e persistido, consumido pelo Epic 2 (Story 2.1) para definir a disponibilidade inicial dos nós do skill tree.
- Após o nivelamento o usuário chega à Home com CTA para a sessão do dia seguinte.
- **Nota de faseamento:** a porção de produção vocal do nivelamento (exigida por FR-1) é adicionada no Epic 3.

### Story 1.10: Tela de Settings

As a usuária,
I want uma tela de Settings acessível pela tab bar,
So that eu possa ajustar o tema e, mais tarde, as permissões de áudio.

**Acceptance Criteria:**

- A aba Settings da tab bar (UX-DR3) abre uma tela funcional (não placeholder).
- Contém, na v1 do Epic 1: seleção de tema (claro / escuro / seguir o sistema) aplicada imediatamente; uma seção "Sobre" com versão do app.
- **Gancho para o Epic 3:** a tela reserva um item de "Microfone" que, quando o Epic 3 existir, mostra o estado da permissão e leva às configurações do sistema. No Epic 1 esse item pode estar ausente ou desabilitado.
- [ASSUMPTION] Conta/login não existe na v1 (PRD); nenhuma seção de conta.

---

## Epic 2: Progressão, medidores e prova de progresso

Ao fim deste épico o usuário vê progresso real: skill tree sempre visível com estados de nó (mais o capstone de Audiação "em breve"), os dois medidores sempre juntos, recompensa que pesa o esforço, comparação numérica com a baseline do dia 1, e dificuldade que se adapta e desvia para reforço em vez de travar.

**FRs cobertas:** FR-7, FR-8, FR-9, FR-10, FR-11, FR-12, FR-13, FR-14
**Requisitos de arquitetura:** AR-3, AR-4, AR-5, AR-9
**Requisitos de UX:** UX-DR4, UX-DR5, UX-DR7, UX-DR8, UX-DR9, UX-DR10, UX-DR11 (card visual), UX-DR12 (dia ruim, reforço)
**NFRs:** NFR-5 (medidores anunciam valores numéricos)
**Depende de:** Epic 1 (o loop de sessão precisa existir para emitir `SessionResultReported`; a primeira Sessão de Exercício concluída para emitir `BaselineRecorded`).

### Story 2.1: Módulo Progressão como dono único de estado + ingestão de eventos

As a criador,
I want o módulo Progressão com as tabelas dos medidores/skill tree/baseline/histórico e um método de ingestão de `SessionResultReported`,
So that haja um único escritor desses dados e Exercícios não os grave direto.

**Acceptance Criteria:**

- A Progressão expõe `ingest(SessionResultReported)` no seu `domain/`, chamado pelo emissor via provider Riverpod — sem event bus global (AR-4).
- Esta story **estende** o módulo `progressao/` iniciado na Story 1.8 (histórico de variações), não o cria do zero.
- As tabelas Drift de Medidor de Habilidade, Medidor de Esforço, estado dos nós do Skill Tree (enum `bloqueado | disponível | completo | em_reforço | capstone_futuro`), Baseline, decisão de dificuldade adaptativa e histórico de variações recentes são criadas **somente** neste módulo (AR-3).
- **Given** qualquer outra feature, **when** ela precisa desses dados, **then** ela só lê via `domain/` da Progressão, nunca escreve.
- A agregação das `attempts` por sessão acontece na Progressão, não no emissor.
- **Given** um `SessionResultReported` cujo `sessionId` já foi ingerido, **when** ele chega de novo (retry, recuperação de crash), **then** a Progressão o ignora — a ingestão é idempotente por `sessionId`.
- **Given** o nível de partida atribuído no Nivelamento (Story 1.9), **when** a Progressão é inicializada para o usuário, **then** ela usa esse nível para marcar como `disponível` os nós do skill tree correspondentes (em vez de deixar só o primeiro nó disponível).
- Toda mutação segue `UI → Riverpod Notifier → Repository → Drift DAO`; leitura reativa via stream; modelos Drift não cruzam `data/ → domain/` (AR-9).

### Story 2.2: Medidor de Esforço (monotônico)

As a usuária,
I want um Medidor de Esforço que só cresce a cada sessão completada,
So that minha constância seja reconhecida mesmo num dia ruim.

**Acceptance Criteria:**

- **Given** um `SessionResultReported` recebido (sessão concluída conforme a definição da Story 1.7), **when** a Progressão o ingere, **then** o Medidor de Esforço é incrementado (FR-10). Sessões abandonadas não geram evento e não creditam Esforço.
- **Given** duas sessões consecutivas, **when** comparadas, **then** o valor do Esforço nunca diminui — apenas mantém ou aumenta.
- Renderizado com a cor `effort-track`; VoiceOver/TalkBack anuncia o valor numérico, não só a posição da barra (NFR-5).

### Story 2.3: Medidor de Habilidade e par sempre-junto

As a usuária,
I want um Medidor de Habilidade que reflete minha performance recente e pode cair, sempre ao lado do Esforço,
So that eu veja minha realidade sem que um dia ruim apague o senso de progresso.

**Acceptance Criteria:**

- A Habilidade é calculada sobre uma janela das sessões mais recentes (FR-9). [ASSUMPTION] tamanho da janela a calibrar.
- **Given** um usuário sem sessões dentro da janela (novo, ou retornando após longa ausência), **when** a Home/Progresso renderiza, **then** o medidor mostra o último valor conhecido marcado como "em pausa"/desatualizado (não zera, não mente como se fosse atual); a próxima sessão o recalcula.
- **Given** uma piora de performance, **when** duas sessões consecutivas são comparadas, **then** o valor do Medidor de Habilidade pode diminuir.
- **Given** qualquer superfície que mostre um medidor (Home, Resumo de Sessão, Progresso), **when** ela renderiza, **then** Esforço e Habilidade aparecem **sempre juntos**, nunca um sem o outro (UX-DR5).
- Habilidade usa `skill-track`; as cores `effort-track`/`skill-track` não são reutilizadas em nenhum outro contexto.
- Anúncio de valor numérico via leitor de tela (NFR-5).

### Story 2.4: Tela de Resumo de Sessão

As a usuária,
I want ao fim da sessão ver um resumo com o mascote e os dois medidores atualizados,
So that cada sessão termine com prova visível de progresso.

**Acceptance Criteria:**

- O Resumo aparece ao fim da Sessão de Exercício; um mascot bubble celebra.
- O par de medidores mostra o resultado da sessão.
- **Given** um dia em que a Habilidade caiu, **when** o Resumo é exibido, **then** o Medidor de Esforço fica em destaque e a mensagem reforça a constância ("Você praticou hoje. Isso conta."), nunca tratando a queda como falha (UX-DR12, UX-DR14).
- **Given** uma vitória de marco (fim do nivelamento, novo nó do skill tree), **when** ela ocorre, **then** o mascote celebra explicitamente.

### Story 2.5: Recompensa ponderada por esforço

As a usuária,
I want que a recompensa pese mais o Esforço do que a performance pura,
So that completar a sessão sempre valha a pena.

**Acceptance Criteria:**

- **Given** uma sessão de baixa performance mas completada integralmente, **when** a recompensa é calculada, **then** o usuário recebe uma recompensa positiva visível (FR-11).
- A ponderação favorece o Medidor de Esforço sobre ganhos de performance pura.
- Nenhuma mecânica de culpa por dia perdido ou streak agressiva (UX-DR13).

### Story 2.6: Skill tree visível com estados de nó

As a usuária,
I want uma aba Skill Tree que mostra onde estou e o que vem a seguir,
So that eu tenha um mapa do meu progresso.

**Acceptance Criteria:**

- Uma aba dedicada na tab bar mostra o mapa de progressão (FR-8).
- Cada nó é um badge (`rounded/sm`, não círculo perfeito) com estado visual `bloqueado | disponível | completo | em_reforço` (UX-DR7).
- **Given** um nó em estado `em_reforço`, **when** o usuário o toca, **then** ele é navegável — nunca é um estado de bloqueio.
- A ordem dos estágios vem do campo `order` do catálogo, cuja unicidade e monotonicidade já são garantidas pelo lint de conteúdo (Story 1.2).
- **Given** o nível de partida do Nivelamento, **when** a árvore é renderizada pela primeira vez, **then** os nós até esse nível aparecem como `disponível`/`completo` conforme a Progressão (Story 2.1), não todos `bloqueado`.
- A Progressão é o único módulo que escreve o estado dos nós.

### Story 2.7: Nó-capstone de Audiação (placeholder)

As a usuária,
I want ver no topo da árvore um nó de Audiação marcado "em breve",
So that eu perceba a jornada de longo prazo sem que ele prometa algo que ainda não existe.

**Acceptance Criteria:**

- O nó capstone está presente no topo da árvore, em estado `capstone_futuro` fixo (UX-DR8).
- **Given** a v1, **when** o usuário tenta abrir o nó, **then** ele não é navegável e mostra o rótulo "em breve".

### Story 2.8: Dificuldade adaptativa sem paredes, com rota de reforço

As a usuária que erra repetidamente um tipo de exercício,
I want ser direcionada a exercícios de reforço relacionados em vez de uma tela de bloqueio,
So that eu nunca fique presa sem saída.

**Acceptance Criteria:**

- **Given** erros repetidos **no mesmo tipo** de exercício, **when** o padrão é detectado, **then** a sessão desvia para exercícios de reforço relacionados a esse tipo e o nó entra em estado `em_reforço` (FR-7).
- **Given** uma taxa de erro alta **espalhada por vários tipos** dentro da mesma sessão (dificuldade agregada, não localizada), **when** o padrão é detectado, **then** a Progressão reduz o nível de dificuldade do snapshot da próxima sessão — também sem parede de bloqueio.
- **Given** qualquer ponto do currículo v1, **when** o usuário está nele, **then** existe uma rota de saída — nunca uma tela "bloqueado, não pode avançar".
- **Given** o início de uma Sessão de Exercício, **when** ela abre, **then** a Progressão calcula e **fixa** o nível de dificuldade como snapshot; o Exercícios lê esse snapshot e a dificuldade não muda no meio da sessão (AR-5).
- **Given** um usuário sem histórico de progressão (primeira sessão pós-nivelamento), **when** o snapshot é calculado, **then** o nível de dificuldade inicial deriva do nível de partida do Nivelamento (Story 1.9); na ausência de qualquer dado, usa um default explícito documentado (nível mais baixo do estágio disponível).

### Story 2.9: Registro da baseline do dia 1

As a usuária,
I want que minha primeira sessão de treino completa seja registrada como referência permanente,
So that eu possa comparar meu progresso com ela depois.

**Acceptance Criteria:**

- **Given** a **primeira Sessão de Exercício concluída** (não o Nivelamento em si; "concluída" conforme a definição da Story 1.7), **when** ela termina, **then** o módulo Exercícios emite `BaselineRecorded` com o mesmo shape de `attempts` do `SessionResultReported` (AR-4).
- **Given** que a primeira sessão pós-nivelamento foi **abandonada** (sem evento), **when** o usuário conclui uma sessão mais tarde, **then** é essa a que vira baseline — o registro é adiado até haver uma sessão concluída, nunca feito de dados parciais.
- **Given** um `BaselineRecorded` já registrado para o usuário, **when** um segundo chega, **then** a Progressão o rejeita — a baseline nunca é sobrescrita (FR-12).
- A mesma sessão emite **tanto** `SessionResultReported` **quanto** `BaselineRecorded` na primeira vez; a Progressão trata os dois (ingestão normal + gravação da baseline).

### Story 2.10: Tela de comparação de progresso vs. baseline

As a usuária,
I want ver na aba Progresso uma comparação numérica entre hoje e o dia 1,
So that eu tenha prova concreta e inegável de que melhorei.

**Acceptance Criteria:**

- **Given** ao menos duas sessões, **when** o usuário abre a aba Progresso, **then** um Baseline comparison card mostra ≥1 métrica (ex: tempo de reação em terças menores) com baseline e valor atual lado a lado, valores numéricos visíveis, e a diferença destacada em `skill-track` quando houve melhora (FR-13, UX-DR9).
- A apresentação usa narrativa nos números ("Terças menores: 2,1s → 1,4s. Você está mais rápido."), nunca número seco (UX-DR14).
- **Given** que a métrica atual está **igual ou pior** que a baseline, **when** o card é exibido, **then** ele não fica em branco nem pune: mostra a comparação de forma neutra e reancora no Esforço/constância ("Ainda estabilizando — e você apareceu N dias"), alinhado ao tom de não tratar regressão como falha (UX-DR14).
- **Given** que nenhuma métrica tem amostras suficientes na baseline **ou** no recente para uma comparação estável, **when** o card é exibido, **then** ele mostra a baseline registrada com a mensagem de que a comparação aparece quando houver dados suficientes. [ASSUMPTION] número mínimo de amostras por métrica a definir.
- **Given** um usuário muito recente (só a baseline registrada), **when** ele abre a aba, **then** o card mostra a baseline com a mensagem de que a comparação aparece a partir da segunda sessão. [ASSUMPTION] prazo exato a definir.

### Story 2.11: Andaime de cor para consonância/dissonância com fading

As a usuária iniciante,
I want uma pista de cor + ícone + texto para consonância/dissonância nos primeiros estágios, que some conforme eu avanço,
So that eu tenha apoio no começo sem depender dele para sempre.

**Acceptance Criteria:**

- O Scaffold cue é um badge (`rounded/sm`) combinando cor (`scaffold-consonant`/`scaffold-dissonant`) + ícone/símbolo distinto + rótulo curto de texto — **nunca** cor isolada como único sinal (FR-14, NFR-5, UX-DR10).
- **Given** estágios iniciais vs. avançados, **when** comparados, **then** a intensidade/presença da pista diminui mensuravelmente; em nenhum estágio avançado a pista permanece na intensidade original.
- A curva de fading vem do `scaffoldIntensity` do catálogo (invariante já validada na Story 1.2).

---

## Epic 3: Produção ativa (voz)

Ao fim deste épico o usuário canta de volta o que ouviu — no nivelamento, como modalidade opcional no núcleo, e obrigatoriamente no módulo de Resolução — com captura push-to-talk, avaliação de afinação pós-gravação, e tratamento gentil quando não há microfone.

**FRs cobertas:** FR-1 (produção vocal), FR-3, FR-15
**Requisitos de arquitetura:** AR-6 (gravação + `evaluatePitch`)
**Requisitos de UX:** UX-DR11 (exercício de voz), UX-DR12 (sem microfone), UX-DR13 (push-to-talk)
**NFRs:** NFR-8 (barreira de acessibilidade conhecida e aceita)
**Fronteira de risco:** começa com o spike de detecção de pitch (sem opção madura no ecossistema Flutter, gap de cobertura iOS). O resultado pode mudar a abordagem de captura/avaliação — por isso a voz fica isolada aqui, atrás de `AudioService`, sem afetar Epics 1 e 2. **Se o spike falhar, a contingência decidida é v1 sem produção ativa** (Stories 3.2–3.6 cortadas, Resolução vira exercício passivo) — PRD Open Question 7.
**Depende de:** Epic 1 (Exercise card, `AudioService`, nivelamento), Epic 2 (Resolução é um nó do skill tree; resultados vocais alimentam `SessionResultReported`).

### Story 3.1: Spike de detecção de pitch (gate de risco)

As a criador,
I want validar tecnicamente uma abordagem de detecção de pitch que funcione em iOS e Android,
So that o risco conhecido não descarrile o épico depois de investimento.

**Acceptance Criteria:**

- Um protótipo avalia a frequência fundamental de **voz cantada real** (com vibrato, ar, harmônicos), não apenas tom puro sintetizado.
- O protótipo roda e é medido num iPhone real **e** num Android real.
- A resolução em cents é suficiente para a tolerância que a FR-3 vai exigir.
- A decisão é documentada (Dart puro / FFI `aubio` / `fftea` + mapeamento / platform channels) com trade-offs de precisão, latência e manutenção.
- O spike é **time-boxed** [ASSUMPTION: ~1 semana de trabalho] — passado o limite sem uma abordagem viável, vale como "não passou".
- **Given** que nenhuma abordagem passe nos critérios, **when** o spike encerra, **then** aplica-se a contingência já decidida (PRD Open Question 7): **v1 sem produção ativa** — FR-1/FR-3/FR-15 reduzidas a reconhecimento, o módulo de Resolução vira exercício passivo (ouvir a cadência e reconhecer a resolução por múltipla escolha), e as Stories 3.2–3.6 são cortadas do escopo da v1. Epics 1 e 2 já entregam um app completo de treino de ouvido.
- Não entrega funcionalidade de usuário — é um gate.

### Story 3.2: AudioService — gravação push-to-talk e evaluatePitch

As a criador,
I want a interface `AudioService` estendida com gravação push-to-talk e `evaluatePitch()` usando a abordagem do spike,
So that exercícios capturem e avaliem voz sem acoplar à biblioteca.

**Acceptance Criteria:**

- **Given** o mecanismo push-to-talk, **when** o usuário segura o botão, **then** a gravação acontece; **when** solta, **then** a avaliação roda (AR-6).
- `AudioService.evaluatePitch()` retorna `Future<PitchEvaluationResult>` (`detectedNote: String?`, `centsOffFromExpected: int?`, `withinTolerance: bool`) — resultado único pós-gravação, **não** um `Stream`.
- **Given** o botão solto antes de uma duração mínima [ASSUMPTION: ~300 ms] ou uma gravação sem sinal de voz detectável, **when** a avaliação roda, **then** `evaluatePitch()` retorna `detectedNote == null` e o exercício trata como "não ouvi" (ver Story 3.3), não como erro.
- **Given** o botão segurado além de uma duração máxima [ASSUMPTION: ~5 s], **when** o máximo é atingido, **then** a gravação encerra sozinha e a avaliação roda com o que foi capturado.
- **apenas** o módulo `audio` importa `record` e a biblioteca de pitch escolhida.
- `FakeAudioService` ganha `evaluatePitch` configurável, permitindo injetar frequências/resultados falsos nos testes (AR-7).
- [ASSUMPTION] A tolerância de afinação em cents é definida nesta story.

### Story 3.3: Produção ativa como modalidade em exercícios do núcleo

As a usuária,
I want poder responder um exercício do treino cantando de volta em vez de múltipla escolha,
So that eu pratique produção, não só reconhecimento.

**Acceptance Criteria:**

- No Exercise card, exercícios do treino núcleo oferecem a modalidade de captura vocal via push-to-talk (FR-3).
- **Given** uma resposta vocal, **when** o usuário canta, **then** o app captura e avalia contra a nota/intervalo esperado usando `evaluatePitch()`.
- **Given** `detectedNote == null` (gravação curta demais, silêncio, ruído), **when** o resultado volta, **then** o exercício mostra "não consegui te ouvir — tenta de novo" e **não conta como tentativa** (não registra `wasCorrect: false`, não penaliza); o usuário pode regravar.
- A produção vocal é **opcional** no núcleo — a alternativa não-vocal (múltipla escolha) continua disponível (NFR-5).
- A tentativa vocal (com resultado válido) alimenta o `SessionResultReported` como qualquer outra tentativa.

### Story 3.4: Nivelamento com porção de produção vocal

As a usuária de primeira viagem,
I want que o nivelamento também me peça para cantar de volta um intervalo simples,
So that meu nível de partida considere produção desde o início.

**Acceptance Criteria:**

- O nivelamento passa a incluir ≥1 exercício de produção vocal além dos de reconhecimento — completando a FR-1.
- **Given** o onboarding, **when** o nivelamento chega à parte vocal, **then** o app pede acesso ao microfone.
- **Given** microfone não concedido, **when** o usuário chega à parte vocal, **then** aplica-se a Story 3.6.

### Story 3.5: Módulo de Resolução (tensão → alívio) com voz obrigatória

As a usuária,
I want um exercício dedicado nos estágios iniciais onde ouço uma progressão que cria tensão e canto a nota de resolução,
So that eu sinta o conceito antes de nomeá-lo, como ponte para a composição.

**Acceptance Criteria:**

- Existe um Resolução module card num nó dos estágios iniciais do skill tree (FR-15, UX-DR11).
- **Given** o exercício, **when** ele roda, **then** o usuário ouve uma progressão que cria tensão seguida da resolução (cadência) e é convidado a **cantar** a nota de resolução — produção vocal **obrigatória**, sem atalho de reconhecimento passivo.
- **Given** um acerto, **when** o usuário resolve, **then** o mascote reforça a sensação ("Sentiu aquele alívio? Isso é resolução.").
- Os estágios de `exerciseType: resolution`, que ficavam inertes desde a Story 1.2, passam a ser **ativados** (flag de capacidade satisfeita) e aparecem no skill tree e na geração de sessão.
- O nó do skill tree marca o conceito como trabalhado, disponível para reforço futuro.

### Story 3.6: Tratamento de microfone não concedido

As a usuária que não concedeu o microfone,
I want que o app explique gentilmente onde a voz é necessária e me deixe reabrir a permissão,
So that eu entenda o bloqueio sem me sentir punida.

**Acceptance Criteria:**

- **Given** sem permissão de microfone, **when** o usuário chega ao Nivelamento (parte vocal) ou ao módulo de Resolução, **then** o mascote explica que essas etapas específicas precisam de voz e oferece reabrir a permissão; o app **não** avança em modo só-reconhecimento nessas duas etapas (UX-DR12, NFR-8).
- **Given** sem permissão de microfone, **when** o usuário faz exercícios do treino núcleo, **then** a modalidade vocal fica indisponível silenciosamente e o núcleo segue com múltipla escolha.
- **Given** a permissão concedida enquanto o usuário está numa etapa vocal bloqueada (voltou das configurações do sistema), **when** o app reassume o foco, **then** a etapa destrava sem exigir reiniciar o nivelamento ou o exercício.
- **Given** a permissão revogada pelo sistema entre sessões (nivelamento vocal já concluído antes), **when** o usuário volta a uma etapa que exige voz, **then** o mesmo tratamento da primeira AC se aplica — o app detecta na entrada da etapa, não assume que "já foi concedida uma vez".
- A permissão de microfone também é acessível/reabrível a partir de Settings.
- A barreira de acessibilidade é documentada como conhecida e aceita na v1 (NFR-8).

---

## Epic 4: Telemetria de calibração

Ao fim deste épico o criador consegue inspecionar localmente sinais de uso para calibrar a baseline e a curva da progressão. Módulo passivo, atrás de flag, nada sai do dispositivo.

**FRs cobertas:** FR-16
**Requisitos de arquitetura:** AR-10
**NFRs:** NFR-6
**Depende de:** Epic 1 e Epic 2 (escuta os eventos que eles emitem).
**Status:** confirmado na v1 (Open Question 6 do PRD, decidida). A flag de compilação continua existindo para poder rodar builds sem coleta.

### Story 4.1: Módulo Telemetria passivo com tabela própria e flag

As a criador,
I want um módulo `telemetria/` atrás de uma flag de compilação, dono exclusivo da tabela `telemetry_events`,
So that eu possa ligar a coleta local sem afetar o resto do app.

**Acceptance Criteria:**

- Uma flag de compilação controla o módulo.
- **Given** a flag desligada, **when** o app roda, **then** nada é gravado e o comportamento do app é idêntico ao de sem o módulo (AR-10).
- `telemetry_events` é append-only, local, e segue o fluxo `UI/serviço → Repository → Drift DAO` (AD-5).
- A tabela `telemetry_events` **existe no schema independentemente da flag** (criada pela migração do Drift); a flag controla apenas se algo é **escrito** nela — assim ligar/desligar entre builds não exige migração nem deixa tabela órfã.
- **Given** a flag ligada e depois desligada, **when** o app roda de novo, **then** os dados já gravados permanecem (o criador ainda pode exportá-los); nada novo é escrito.
- **Given** qualquer outra feature, **when** ela roda, **then** ela não escreve em `telemetry_events`; e o módulo Telemetria não escreve em nenhuma outra tabela.

### Story 4.2: Captura de sinais de calibração a partir dos eventos de domínio

As a criador,
I want que a telemetria escute `SessionResultReported` e `BaselineRecorded` e registre eventos estruturados,
So that eu possa analisar depois se a baseline e a curva estão calibradas.

**Acceptance Criteria:**

- **Given** um `SessionResultReported` ou `BaselineRecorded` emitido, **when** a telemetria está ligada, **then** ela registra um evento estruturado por tentativa com schema fixo: `{ eventId (UUID v4), occurredAt (ISO 8601 UTC), sessionId, exerciseType, wasCorrect, errorType?, reactionTimeMs, difficultyLevel, isBaseline }` (FR-16).
- Além disso, registra um evento por sessão: `{ eventId, occurredAt, sessionId, outcome (concluída | abandonada), attemptsCount, durationMs }` — o abandono vem da própria Telemetria observando o ciclo de vida da sessão, já que sessão abandonada não emite `SessionResultReported`.
- A telemetria só consome eventos já emitidos e leituras via `domain/` de outras features — **não** altera Medidores, Skill Tree, Baseline ou dificuldade adaptativa.
- **Given** a v1, **when** eventos são registrados, **then** eles nunca são transmitidos para fora do dispositivo (NFR-6).
- Existe um meio simples de inspeção local dos dados pelo criador (ex: export para arquivo em build de debug).
