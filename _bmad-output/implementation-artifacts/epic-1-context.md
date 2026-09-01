# Epic 1 Context: Fundação técnica + primeiro loop de reconhecimento jogável

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este épico entrega um app de treino de ouvido jogável — sem a parte de voz. Ao final, a usuária abre o CatEar numa Home com identidade visual de app de música, faz um teste de nivelamento só de reconhecimento (múltipla escolha) que atribui um nível de partida e garante uma primeira vitória reconhecida, e depois pratica reconhecimento de intervalos, acordes e escalas apresentados sempre em contexto musical (melodia/progressão curta, nunca notas isoladas) com timbre de instrumento real pré-renderizado. As sessões duram 10–15 min, geram variações a cada vez (anti-decoreba) e dão feedback explicativo em cada erro (nomeiam a confusão, nunca só "errado"). É também o épico de fundação: define a estrutura de módulos, os tokens de design, o banco local com migrações, o catálogo de currículo como dado versionado com invariante de fading validada em build, a interface de áudio com fake, e o evento de resultado de sessão que os Epics 2 e 4 vão consumir.

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

- **Áudio sempre real e sempre em contexto:** todo áudio de exercício vem de amostras de instrumento real pré-renderizadas e testadas — nunca síntese em runtime. O intervalo/acorde/escala aparece dentro de uma frase ou progressão curta, nunca como par de notas isoladas em silêncio. Botão de replay sempre presente, sem limite de repetições.
- **Local-first, offline sempre:** v1 sem backend. Toda persistência é local (SQLite via Drift). Todas as amostras de áudio são empacotadas no bundle do app — não há download remoto na v1.
- **Feedback de erro é aprendizado:** ao errar, nomear o conceito confundido ("confundiu 3ª maior com 3ª menor"). Nunca só "errado"/"incorreto"; sem vermelho saturado. Quando a resposta errada não casa com nenhum tipo de erro conhecido, ainda assim nomear qual era a resposta certa de forma acolhedora.
- **Sessões curtas:** conteúdo dimensionado para 10–15 min de uso típico. Ao se aproximar do tempo alvo, oferecer encerrar com progresso contabilizado, sem culpa. Nenhuma mecânica que recompense sessão maratona.
- **Anti-decoreba:** exercícios são gerados como variações a partir de parâmetros do catálogo (incl. transposição de tonalidade em runtime), nunca conteúdo hardcoded. Nenhum exercício se repete de forma idêntica (mesmo áudio + mesma pergunta) dentro de uma janela das últimas N tentativas (janela por contagem de exercícios, não por sessão). Pool esgotado → escolher a variação menos recentemente usada, nunca travar.
- **Primeira vitória garantida no nivelamento:** primeiro exercício deliberadamente fácil (ex: uníssono vs. oitava). Com ≥1 acerto, o mascote celebra essa vitória; com zero acertos, celebra a conclusão e o início da jornada sem expor o placar. Sempre há um momento positivo ao final.
- **Tom e estética:** a interface soa e parece um app de música, nunca uma aula. Textos, telas de erro e onboarding evitam "matemática" e notação acadêmica pesada.
- **Acessibilidade (base):** todo elemento interativo rotulado com papel + estado; alvos de toque ≥ 44pt iOS / 48dp Android; dynamic type honrado sem truncar no tamanho máximo; contraste AA em todos os pares de token; scaffold de cor nunca é o único sinal; replay de áudio sem limite arbitrário.
- **Paridade iOS + Android** completa de funcionalidade.
- **Sem produção vocal neste épico:** a porção vocal do nivelamento (exigida pela consequência completa da FR-1) e o exercício ativo de Resolução chegam no Epic 3. Estágios de currículo do tipo `resolution` já existem como dado, mas ficam ocultos/inertes no skill tree e na geração de sessão até lá.

## Technical Decisions

- **Stack fixada:** Flutter 3.47.x, Riverpod (codegen) 3.4.2, Drift 2.34.3, `record` 7.1.1, `just_audio` 0.10.6. Projeto Flutter novo, sem template starter. A biblioteca de detecção de pitch NÃO é fixada aqui (spike do Epic 3).
- **Módulos por feature:** `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}` (telemetria entra no Epic 4). Cada módulo tem `data/ domain/ presentation/` e expõe um único barrel público `{modulo}.dart`. `data/` e `presentation/` nunca são importados de fora do módulo — regra de lint `implementation_imports` (`custom_lint`/`import_lint`) no CI local desde o início; o build falha se violada.
- **`core/`:** inicializa o `Database` Drift e expõe apenas `Database` + DAOs. Modelos/tabelas gerados pelo Drift nunca cruzam a fronteira `data/ → domain/`. Interfaces de repositório e modelos de domínio puros vivem no `domain/` de cada módulo. `core/` também hospeda os tokens de design.
- **Tokens de design (`core/`):** paleta completa light + dark — `surface-base/raised`, `ink-primary/secondary/disabled`, `accent`, `accent-soft`, `effort-track`, `skill-track`, `scaffold-consonant/dissonant`, `border-hairline` (+ variantes `-dark`); raios `rounded/sm` 10px, `md` 18px, `lg` 28px; espaçamento 4/8/12/16/24/32px. Os hex do DESIGN.md são proposta inicial — a Story 1.1 faz auditoria de contraste AA real (inclusive `effort-track`/`skill-track`/`scaffold-*` sobre `surface-base`/`surface-base-dark`) e ajusta os hex onde reprovarem; nenhum épico seguinte prossegue sobre pares reprovados. As cores `effort-track`/`skill-track` são reservadas e nunca reutilizadas em outro contexto.
- **Migração de schema Drift desde já:** `schemaVersion` explícito e um `MigrationStrategy` com `onUpgrade` presente (mesmo vazio na v1), para que Epics seguintes adicionem tabelas sem apagar o banco local do usuário.
- **Fluxo de mutação (AD-5):** `UI → Riverpod Notifier → Repository (domain) → Drift DAO`. Leitura reativa: Drift stream → Repository → Riverpod provider → UI. Nenhuma tela chama Drift diretamente.
- **Convenções:** IDs de entidade como `String` (UUID v4). Datas em ISO 8601 UTC no banco, conversão para local só na apresentação. Erros de domínio como `sealed class` por módulo, nunca exceptions genéricas cruzando fronteira. Estado assíncrono via `AsyncValue` do Riverpod.
- **Currículo é dado (AR-8):** o módulo Currículo expõe o conteúdo como catálogo JSON versionado (asset embarcado), schema fixo. Estrutura: `stages[]` com `stageId`, `order` (int estritamente crescente e único), `exercises[]` com `exerciseType` (`interval | chord | scale | resolution`), `audioSampleRefs[]`, `scaffoldIntensity` (float 0.0–1.0 quando aplicável); `errorTypes[]` como taxonomia canônica. `ExerciseType` e `ErrorType` são definidos SOMENTE no módulo Currículo — nenhum outro módulo inventa valores. `CurriculoRepository.load()` retorna modelos de domínio puros e não promete a origem dos dados (porta aberta para OTA futuro).
- **Lint de conteúdo antes de qualquer build:** falha se, na subsequência filtrada dos estágios que usam scaffold de cor (ignorando os sem `scaffoldIntensity`), ordenada por `order` crescente, algum `scaffoldIntensity` for maior que o do estágio anterior. Também falha se `order` tiver duplicatas ou não for estritamente crescente. (Andaime de timbre `timbreScaffold: clean | vibrato`, se adotado, segue a mesma invariante não-crescente em "limpeza".)
- **Taxonomia musical do catálogo v1** (fonte: modelo de conteúdo da curadoria):
  - **Intervalos (13, em 7 estágios):** E1 uníssono/8ªJ/5ªJ; E2 3ªM vs 3ªm (asc+desc a partir daqui); E3 2ªM vs 2ªm; E4 4ªJ; E5 6ªM vs 6ªm; E6 7ªM vs 7ªm; E7 trítono. `direction: asc | desc` é campo, não tipo separado.
  - **Escalas v1:** maior (Jônio) e menor natural (Eólio), uma oitava, asc + desc.
  - **Acordes v1:** tríade maior e tríade menor, posição fundamental (schema já prevê `inversion: 0|1|2` para pós-v1).
  - **Resolução (dado no Epic 1, ativa no Epic 3):** cadência `authentic` (V→I) como núcleo, `plagal` (IV→I) como contraste; `ii→V→I` como extensão.
  - **`errorTypes` canônica:** os 13 ids de intervalo (`P1,m2,M2,m3,M3,P4,TT,P5,m6,M6,m7,M7,P8`), qualidades de acorde (`major,minor,diminished,augmented`), mais `octave-error` e `far-miss` (fallback da Story 1.6). Para acordes/escalas o `errorType` é o id da qualidade escolhida por engano.
  - Sugestão de esquema JSON estende AR-8 com `intervalCatalog`, `chordCatalog`, `scaleCatalog`, `cadenceCatalog` além de `stages[]` e `errorTypes[]`.
  - **Microcopy dos pares de confusão** (Story 1.6) vem da taxonomia: 3ªM↔3ªm, 4ªJ↔5ªJ, 6ªM↔6ªm, 7ªM↔7ªm, 2ªM↔2ªm, trítono↔4ª/5ª, erro de oitava. Graus de escala (tônica, supertônica, mediante, subdominante, dominante, submediante, sensível/subtônica) para feedback do tipo "você cantou a mediante, o alvo era a dominante".
- **AudioService (AR-6, só reprodução neste épico):** interface única no `domain/` do módulo `audio`, reproduz uma amostra por referência de asset. Implementação real usa `just_audio`; APENAS o módulo `audio` importa `just_audio`. Um provider Riverpod injeta a implementação.
- **FakeAudioService (AR-7) desde o dia zero:** mesma interface, registra chamadas, simula reprodução sem áudio real. Nenhum teste de Exercícios/Nivelamento/Progressão depende de hardware de áudio.
- **Amostras de áudio da v1 (Story 1.3b):** abordagem recomendada — conjunto de ~33–37 notas cromáticas isoladas de um instrumento real; o app monta intervalos/acordes/escalas e faz transposição de tonalidade em runtime (menos assets, mais variação). WAV mono, 44,1 kHz, loudness normalizado entre amostras. Timbre do protótipo: **sax alto (University of Iowa MIS), faixa D3–Ab5**, versão sem vibrato como timbre padrão e com vibrato como variação avançada; flauta (Philharmonia, C4–C6) como 2º timbre. Registro dos exercícios: raízes C4–C5, topo de intervalos até ~C6. Sax e flauta são monofônicos → acordes e cadências exigem empilhar 3 amostras (ou, no lançamento, migrar para piano polifônico VSCO2 CE / SoundFont CC0). Cada `audioSampleRef` do catálogo precisa de um arquivo correspondente; origem/licença de cada amostra rastreável no repo (`ATTRIBUTIONS.md` para CC-BY). Licença Philharmonia tem risco comercial ("não vender/distribuir as amostras as is") — ok para protótipo, trocar por fonte CC0 antes de lançamento comercial. O miado de gato fica só na camada do mascote (agudo, curto), nunca como timbre de exercício.
- **Evento de domínio `SessionResultReported` (AR-4):** emitido pelo módulo Exercícios ao concluir uma sessão, uma única vez, com `sessionId: String` (UUID v4 gerado na abertura) e `attempts: List<ExerciseAttempt>` — uma entrada por tentativa, `ExerciseAttempt = { exerciseType, wasCorrect, errorType?, reactionTimeMs }`. Agregação é responsabilidade da Progressão (Epic 2). Neste épico o evento é apenas emitido/logado; ainda não há consumidor. Transporte: método de ingestão no `domain/` da Progressão via provider Riverpod — sem event bus global.
- **Definição de "sessão concluída":** chegou ao fim da sequência OU aceitou o encerramento oferecido no tempo alvo, tendo respondido ≥1 exercício. Sair antes (fechar app, voltar) é abandono → nenhum `SessionResultReported`, tentativas descartadas para fins de progressão.
- **Fatia mínima de `progressao/` neste épico (Story 1.8):** apenas a tabela + repositório de escrita do histórico de variações recentes por tipo de exercício, do qual a Progressão é dona única (AD-2). O Epic 2 estende o mesmo módulo com o resto do estado — sem reescrita.
- **Distribuição (AR-12):** app id, ícone e splash configurados cedo. Build flavors (dev/release) adiados; builds locais/debug no início.

## UX & Interaction Patterns

- **Navegação:** bottom tab bar com 4 abas — Home / Skill Tree / Progresso / Settings. Sem drawer. Modal (ex: explicação de erro) empilha só um nível.
- **Tipografia:** fontes de sistema para corpo, títulos e números (iOS Title 2/Body/Footnote · Android Headline Small/Body Large/Body Small). Fonte de display **Fredoka** disponível mas reservada exclusivamente a falas do mascote e telas de vitória/marco. Dynamic type respeitado em todos os níveis.
- **Tema:** claro pastel laranja (creme) é o padrão. Modo escuro replica o mesmo aconchego em tons profundos quentes e sombras quentes — não um tema "frio" à parte.
- **Exercise card (UX-DR6):** `surface-raised`, `rounded/md`, um exercício por tela, respiro generoso (nunca densidade de formulário), centraliza player de áudio + área de resposta. Botão de replay sempre visível, sem limite. Mesmo card e fluxo para `interval`, `chord` e `scale` — sem código específico por tipo na apresentação; a diferença vem dos dados do catálogo.
- **Mascot bubble (UX-DR4):** balão `rounded/lg`, fundo e borda `accent-soft`, sombra quente flutuando acima do conteúdo. Neste épico aparece só em: boas-vindas do nivelamento, feedback de erro explicativo, celebração de vitória do nivelamento. NUNCA durante o áudio do exercício.
- **Resposta correta:** feedback visual + sonoro positivo imediato, sem mascote (não interrompe o ritmo).
- **Resposta incorreta:** mascote explica num bubble curto, sem tela cheia. Modal empilha só um nível.
- **Primeiro uso:** abre direto no Nivelamento, sem login/tela prévia bloqueando. Após o nivelamento, chega à Home com CTA para a sessão do dia seguinte.
- **Sessão passando de ~15 min:** oferece encerrar com progresso contabilizado, sem culpa.
- **Interaction primitives (UX-DR13):** tap para múltipla escolha. Swipe NÃO é usado para navegação primária dentro da sessão (evita saída acidental). Push-to-talk é do Epic 3. Banido: paywall interrompendo sessão, notificações de streak agressivas/culpa, texturas/ícones de partitura tradicional.
- **Microcopy / voz e tom (UX-DR14):** frases curtas, tom de professor gentil via mascote. Feedback de erro nomeia a confusão, nunca "errado" seco. Sem hype de marketing.
- **Tela de Settings (Story 1.10):** funcional, não placeholder. Contém seleção de tema (claro / escuro / seguir sistema) aplicada imediatamente e seção "Sobre" com versão do app. Gancho reservado (ausente ou desabilitado na v1) para o item "Microfone" do Epic 3. Sem seção de conta/login (não existe na v1).

## Cross-Story Dependencies

- **Story 1.1** é a base de todas as outras (estrutura de módulos, tokens, Database Drift, navegação). A auditoria de contraste da paleta nela é bloqueante para o trabalho visual dos Epics seguintes.
- **Story 1.3b depende de Story 1.2:** o catálogo define quais `audioSampleRef` existem antes de as amostras serem produzidas.
- **Stories 1.4/1.5 dependem de 1.2, 1.3 e 1.3b:** precisam do catálogo, da interface de áudio e das amostras. 1.5 reusa integralmente o card e o fluxo da 1.4.
- **Story 1.6 depende de 1.4/1.5** (existe um exercício para errar) e consome a taxonomia de `errorType` da 1.2.
- **Story 1.7 depende de 1.4/1.5** (precisa de exercícios para sequenciar) e define a emissão de `SessionResultReported`.
- **Story 1.8 depende de 1.7** (janela sobre tentativas registradas) e cria a fatia mínima de `progressao/`.
- **Story 1.9 (Nivelamento) depende de 1.4** (formato de exercício de reconhecimento) e produz o nível de partida persistido.
- **Para o Epic 2:** o nível de partida da Story 1.9 alimenta a disponibilidade inicial dos nós do skill tree (Story 2.1). `SessionResultReported` (Story 1.7) é ingerido pela Progressão. A primeira Sessão de Exercício concluída após o nivelamento é a que emitirá `BaselineRecorded` (implementado no Epic 2, mas a definição de "sessão concluída" da Story 1.7 é o gatilho). O módulo `progressao/` iniciado na Story 1.8 é estendido, não reescrito.
- **Para o Epic 3:** o `AudioService` (Story 1.3) é estendido com gravação e `evaluatePitch`. Os estágios `resolution` do catálogo (Story 1.2), marcados com flag de capacidade (ex: `requiresVoice: true`) e inertes, são ativados. O item "Microfone" reservado em Settings (Story 1.10) é preenchido. O nivelamento (Story 1.9) ganha a porção vocal.
- **Para o Epic 4:** a telemetria escuta o `SessionResultReported` emitido pela Story 1.7 e observa o ciclo de vida da sessão (incl. abandono).
