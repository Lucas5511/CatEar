# Epic 1 Context: Fundação técnica + primeiro loop de reconhecimento jogável

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este épico entrega um app de treino de ouvido jogável, sem a parte de voz. Ao final, a usuária abre o CatEar, faz um nivelamento só de reconhecimento (múltipla escolha), recebe um nível de partida com uma primeira vitória reconhecida, e pratica reconhecimento de intervalos, acordes e escalas em contexto musical (nunca notas isoladas), com áudio de timbre real, variações a cada sessão e feedback explicativo em cada erro, em sessões de 10–15 min. É o épico de fundação: estabelece a estrutura modular, os tokens de design, o banco Drift com migração, o catálogo de currículo como dado e a camada de áudio atrás de interface. Não depende de nada; os Epics 2, 3 e 4 dependem dele. A produção vocal (completa FR-1, FR-3, FR-15) chega no Epic 3 — até lá o produto é "completo para reconhecimento".

## Stories

- Story 1.1: Abrir o app numa Home com navegação e tema
- Story 1.2: Catálogo de currículo como dado, com invariante de fading validada
- Story 1.3: AudioService com reprodução e FakeAudioService
- Story 1.3b: Produção do conjunto de amostras de áudio da v1
- Story 1.4: Exercício de reconhecimento de intervalo em contexto musical
- Story 1.5: Exercícios de reconhecimento de acordes e escalas
- Story 1.6: Feedback explicativo em erro
- Story 1.7: Estrutura de sessão de 10–15 minutos
- Story 1.8: Geração de variações (anti-decoreba)
- Story 1.9: Nivelamento por reconhecimento
- Story 1.10: Tela de Settings

## Requirements & Constraints

- **Áudio real, sempre em contexto:** amostras de instrumento real pré-renderizadas e embarcadas no bundle, sem síntese em runtime, sem download remoto. O intervalo/acorde/escala aparece dentro de uma melodia ou progressão curta, nunca par de notas isoladas. Replay sem limite.
- **Sessão curta:** dimensionada para 10–15 min; ao aproximar do alvo, oferecer encerrar com progresso contabilizado, sem culpa; nada premia sessão maratona.
- **Anti-decoreba:** nenhum exercício idêntico (mesmo áudio + mesma pergunta) se repete dentro de uma janela contada por número de exercícios (não por sessão); pool esgotado → variação menos recentemente usada. N a calibrar, default documentado.
- **Feedback de erro:** nomear o conceito confundido via mascote; sem `errorType` casável → explicação acolhedora que ainda diz qual era o certo. Nunca só "errado", sem vermelho saturado.
- **Nivelamento:** primeiro uso cai direto nele, sem login. Primeiro exercício deliberadamente fácil. Sempre termina com momento positivo do mascote, mesmo com zero acertos (sem expor placar). Atribui e persiste um nível de partida consumido pelo Epic 2.
- **Local-first:** v1 sem backend, persistência local (SQLite via Drift), offline sempre. Paridade iOS + Android; app id, ícone e splash configurados cedo.
- **Acessibilidade (base):** todo interativo rotulado com papel + estado; alvos ≥44pt/48dp; dynamic type sem truncar; contraste AA em todos os pares de token — auditoria real da paleta na Story 1.1, hex ajustados onde reprovarem; nenhum épico seguinte prossegue sobre par reprovado.
- **Tom:** parece um app de música, nunca uma aula — sem "matemática" nem notação acadêmica, inclusive em telas de erro e onboarding.

## Technical Decisions

- **Stack fixa:** Flutter 3.47.x, Riverpod codegen 3.4.2, Drift 2.34.3, `just_audio` 0.10.6. `record` e lib de pitch só no Epic 3.
- **Módulos por feature (AD-1):** `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}`, cada um com `data/ domain/ presentation/` e um barrel público `{modulo}.dart`. `data/` e `presentation/` nunca importados de fora do módulo — comunicação só via `domain/` ou eventos. Lint `implementation_imports` (`custom_lint`/`import_lint`) no CI local desde o início, quebra o build se violada.
- **Fluxo de estado (AD-5):** `UI → Riverpod Notifier → Repository (domain) → Drift DAO`; leitura reativa Drift stream → Repository → provider → UI. Nenhuma tela toca Drift direto. `core/` expõe só o `Database` e DAOs; interfaces de repositório e modelos de domínio puros no `domain/`; classes geradas pelo Drift nunca cruzam `data/ → domain/`.
- **Migração Drift desde já:** `schemaVersion` explícito + `MigrationStrategy` com `onUpgrade` presente (pode ser vazio), para épicos seguintes adicionarem tabelas sem apagar o banco do usuário.
- **Currículo é dado (AD-4 / AR-8):** asset `assets/curriculum/catalog_v1.json` com schema fixo — **contrato autoritativo no bloco `<frozen-after-approval>` da spec da Story 1.2**; `content-model.md` tem a taxonomia musical. Pontos que outros módulos consomem: `scaffoldIntensity` e `timbreScaffold` (`clean|vibrato`) são por-estágio e opcionais (ausente ≠ 0.0); `exerciseType` = `interval|chord|scale|resolution`; `requiresVoice` true sse `resolution`. `ExerciseType` e `ErrorType` definidos **só** no módulo Currículo; `errorTypes[]` do JSON == conjunto exato do enum `ErrorType`. `CurriculoRepository.load()` retorna modelos de domínio puros, não promete a origem (porta para OTA v2).
- **Lint de conteúdo (`tool/check_curriculum.dart`) roda antes de qualquer build:** `order` único e estritamente crescente; `scaffoldIntensity` não-crescente na subsequência de estágios que o declaram; `timbreScaffold` nunca volta de `vibrato` para `clean`.
- **Catálogo v1:** 10 estágios — 7 de intervalo (13 intervalos), escalas (maior/menor natural), acordes (tríade maior/menor), resolução (V→I, IV→I). Exercícios `resolution` existem como dado mas ficam inertes no fluxo de reconhecimento até o Epic 3.
- **AudioService (AD-3 / AR-6):** interface única no `domain/` do módulo `audio`, só reprodução por referência de asset neste épico. Só `audio` importa `just_audio`. `FakeAudioService` obrigatório desde o dia zero — nenhum teste de Exercícios/Nivelamento/Progressão depende de hardware de áudio. Provider Riverpod injeta a implementação; testes recebem o fake.
- **Amostras (Story 1.3b):** cobrem cada `audioSampleRef` do catálogo; timbre real em contexto curto; formato/sample rate/loudness normalizados; licença rastreável. Transposição em runtime gera variação de tonalidade sem multiplicar amostras.
- **Eventos de domínio (AD-2 / AR-4):** `SessionResultReported` (Exercícios → Progressão): `sessionId` (UUID v4 na abertura), `attempts: List<ExerciseAttempt>` — uma entrada por tentativa (`exerciseType`, `wasCorrect`, `errorType?`, `reactionTimeMs`); agregação é da Progressão. Neste épico só é emitido/logado; consumidor entra no Epic 2. Sem event bus global — ingestão via método no `domain/` da Progressão chamado por provider Riverpod.
- **"Sessão concluída":** chegou ao fim da sequência **ou** aceitou o encerramento por tempo, com ≥1 exercício respondido. Sair antes é abandono → nenhum evento, tentativas descartadas para progressão.
- **Single-writer parcial (AD-2):** o histórico de variações recentes por tipo pertence à **Progressão**. A Story 1.8 cria a fatia mínima de `progressao/` (tabela + repositório de escrita); a Story 2.1 estende o mesmo módulo sem reescrita.
- **Convenções (AR-11):** IDs `String` UUID v4; datas ISO 8601 UTC no banco, conversão para local só na apresentação; erros de domínio como `sealed class` por módulo; estado assíncrono via `AsyncValue`.

## UX & Interaction Patterns

- **Tokens (`core/`, UX-DR1):** paleta completa light + dark (`surface-base/raised`, `ink-*`, `accent`, `accent-soft`, `effort-track`, `skill-track`, `scaffold-consonant/dissonant`, `border-hairline` + variantes `-dark`); raios `sm|md|lg` = 10/18/28px; espaçamento 4/8/12/16/24/32px. Hex iniciais no DESIGN.md (creme `#FFF7EE`, accent `#FFC067`) — proposta a validar na auditoria de contraste. `effort-track`/`skill-track` nunca usadas fora dos medidores.
- **Tipografia (UX-DR2):** corpo/títulos/números em fontes de sistema; **Fredoka** só para falas do mascote e telas de vitória.
- **Navegação (UX-DR3):** bottom tab bar de 4 abas — Home / Skill Tree / Progresso / Settings. Sem drawer. Modal empilha só um nível.
- **Modo escuro (UX-DR15):** mesmo aconchego (creme → tons profundos quentes), sombras quentes.
- **Exercise card (UX-DR6):** `surface-raised`, `rounded/md`, um exercício por tela, respiro generoso, player + resposta centralizados, replay sempre presente.
- **Mascot bubble (UX-DR4):** `rounded/lg`, fundo `accent-soft`, sombra quente acima do conteúdo. Só em: boas-vindas do nivelamento, feedback de erro, celebração, resumo de sessão. **Nunca** durante o áudio do exercício.
- **Estados (UX-DR12, parcial):** primeiro uso → nivelamento direto; correta → feedback visual+sonoro imediato, sem mascote; incorreta → mascote em bubble curto, sem tela cheia; sessão > 15 min → oferece encerrar sem culpa.
- **Primitivas (UX-DR13):** tap para múltipla escolha; swipe não é navegação primária na sessão. Banido: paywall na sessão, notificações agressivas de streak, texturas/ícones de partitura.
- **Microcopy (UX-DR14):** frases curtas, professor gentil via mascote; erro nomeia a confusão; sem hype.
- **Settings (Story 1.10):** tela funcional — tema (claro/escuro/sistema) aplicado na hora + "Sobre" com versão. Gancho reservado (ausente/desabilitado na v1) para o item de Microfone do Epic 3. Sem conta/login na v1.

## Cross-Story Dependencies

- 1.3b depende de 1.2 (o catálogo define quais `audioSampleRefs` existem).
- 1.4, 1.5, 1.7, 1.8, 1.9 dependem de 1.2 (catálogo), 1.3 (AudioService) e 1.3b (amostras).
- 1.6 depende de 1.2 (taxonomia de `ErrorType`) e da microcopy dos pares de confusão do modelo de conteúdo.
- 1.5 reusa o Exercise card e o fluxo de 1.4 — sem código específico por tipo, a diferença vem dos dados.
- 1.8 cria a fatia mínima de `progressao/`; a Story 2.1 (Epic 2) estende esse módulo.
- Saídas para outros épicos: `SessionResultReported` e o nível de partida (1.9) alimentam o Epic 2; o app jogável de reconhecimento é pré-requisito dos Epics 2, 3 e 4.
