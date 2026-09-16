# CatEar

App de treino de **ouvido relativo** — reconhecimento (e, a partir do Epic 3, produção vocal) de intervalos, acordes, escalas e cadências, sempre em contexto musical. Flutter, Android + iOS, **local-first e offline** (sem backend na v1).

> Estética de app de música, nunca de aula. Feedback de erro nomeia a confusão ("confundiu 3ª maior com 3ª menor"), nunca só "errado".

---

## Estado atual

**Epic 1 — Fundação técnica + primeiro loop de reconhecimento jogável** · em andamento (**10 de 12 stories entregues**, última: 1.8b em 2026-09-15; 1.9 em review).

Hoje o app abre, no primeiro uso, direto no **nivelamento** (7 intervalos, primeira vitória celebrada pelo mascote, nível de partida persistido) e, nas seguintes, numa Home com 4 abas; o botão **Praticar** abre uma sessão de reconhecimento (intervalos, acordes e escalas em contexto musical, com áudio de sax real), cada erro é explicado por um balão do mascote nomeando a confusão, a sessão oferece encerrar aos ~12 min e nunca repete um exercício idêntico nas últimas 39 tentativas. Falta a tela de Settings completa (1.10).

| Story | Estado | O que entregou |
|---|---|---|
| **1.1 — App shell, tema, banco** | ✅ PR #1, #2 | Projeto Flutter, 6 módulos por feature, tokens light/dark com contraste WCAG verificado por teste, `AppDatabase` Drift com `MigrationStrategy` + snapshots de schema, `HomeShell` com 4 abas, Settings com seletor de tema, CI local + GitHub Actions |
| **1.2 — Catálogo de currículo como dado** | ✅ PR #3 | `assets/curriculum/catalog_v1.json` versionado, módulo `curriculo` com modelos puros + `CurriculoRepository`, `tool/check_curriculum.dart` valida a **invariante de fading** em build |
| **1.3 — AudioService + FakeAudioService** | ✅ | Interface `AudioService` no `domain/` de `audio`, implementação real sobre `just_audio` (só o módulo `audio` a importa), `FakeAudioService` em `lib/audio/testing.dart` para todo teste que não é on-device |
| **1.3b / 1.4b — Amostras de áudio da v1** | ✅ | 22 amostras de sax (notas isoladas C4–D5 + tríades maj/min/dim/aug) em `assets/audio/`, proveniência e receita em [`docs/audio/samples-v1.md`](docs/audio/samples-v1.md); teste garante paridade catálogo ↔ assets nos dois sentidos |
| **1.4 — Reconhecimento de intervalo** | ✅ | Exercise card, motif em contexto (nunca par de notas isolado), replay ilimitado, múltipla escolha, feedback positivo sem mascote, tempo de reação registrado |
| **1.5a / 1.5 — Acordes e escalas** | ✅ | Fluxo de prática **type-agnostic** (`ExerciseQuestion`/`AnswerOption`); a diferença entre tipos vem do catálogo, e a regra 6 do `check_module_boundaries` impede a apresentação de nomear tipos |
| **1.6 — Feedback explicativo em erro** | ✅ PR #28 | Balão do mascote inline nomeando a confusão com os `nameUi` do catálogo; `errorType` sempre da taxonomia canônica, `far-miss` quando não há confusão única |
| **1.7 — Sessão de 10–15 min** | ✅ PR #29, #30 | Sessão com `sessionId` UUID v4, oferta de encerrar ao atingir o alvo (sem culpa), definição de concluída vs. abandono, `SessionResultReported` emitido exatamente uma vez |
| **1.8 — Variações anti-decoreba** | ✅ PR #31 | Janela de 39 tentativas sem repetição idêntica, LRU quando o pool esgota, tabela `recent_variants` (schema v2) no módulo `progressao` como dono único (AD-2) |
| **1.8b — Costura do card de exercício** | ✅ PR #33 | `ExerciseCardFlow` dirigido por `onAnswer`/`onAdvance`, exportado pelo barrel como contrato de UI compartilhado; `PracticeController` e `PracticeScreen` separados do card, pré-requisito da 1.9 |
| **1.9 — Nivelamento por reconhecimento** | 🔍 em review (este PR) | Primeiro uso cai no nivelamento (gate por `placementProvider`); 7 intervalos ascendentes no `ExerciseCardFlow` com notifier próprio; nível de partida = 1º estágio errado, gravado na tabela `placements` (schema v3) pelo port `PlacementRepository` da Progressão; mascote celebra a primeira vitória (ou o primeiro passo, sem placar) |
| 1.10 — Tela de Settings | ⏳ a única restante | Tema + "Sobre" + gancho de microfone para o Epic 3 |

Rastreamento: [`sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml) · review de qualidade mais recente: [`quality-review-epic-1-2026-09-15.md`](_bmad-output/test-artifacts/quality-review-epic-1-2026-09-15.md) (gate **CONCERNS** — a 1.9 pode seguir; o fechamento do épico tem pendências listadas lá).

`flutter test` → **419 testes** · `integration_test/` → **23 testes E2E** on-device (rodam no CI em emulador Android).

---

## Stack (fixada pelo Epic 1)

- **Flutter 3.47.x** / Dart 3.13.x — projeto novo, sem template starter
- **Riverpod** (`flutter_riverpod` 3.4.2 + `riverpod_annotation` 4.0.6 / `riverpod_generator` — codegen) — gerência de estado
- **Drift** 2.34.3 — banco local SQLite; schema **v3** (`recent_variants`, `placements`), migrações testadas contra os snapshots de `drift_schemas/`
- **`just_audio`** 0.10.6 — reprodução das amostras embarcadas (em uso desde a 1.3)
- **`record`** 7.1.1 — no `pubspec` pelo pin do Epic 1, **ainda não usado** (entra no Epic 3)
- `clock` (relógio injetável da sessão), `uuid`, `path_provider`, `sqlite3_flutter_libs`, `flutter_localizations` (pt-BR)

Código gerado (`*.g.dart`, `*.drift.dart`) é **git-ignorado** e regenerado no CI.

---

## Arquitetura

**Módulos por feature** — `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}`. Cada um tem `data/ domain/ presentation/` e expõe um único **barrel público** `<módulo>.dart` que só reexporta de `domain/` (+ o provider Riverpod e, quando há, a tela de entrada). `data/` e `presentation/` de um módulo **nunca** são importados de fora dele — `tool/check_module_boundaries.dart` falha o CI se violado.

- **`core/`** — tokens de design, `ThemeData` claro/escuro, `CatText`, `AppDatabase` + DAOs + `databaseProvider`. Modelos/tabelas gerados pelo Drift nunca cruzam a fronteira `data/ → domain/` nem saem de `core/`.
- **`lib/app/`** — o shell (`HomeShell`, `HomeScreen`, `SettingsScreen`, `DatabaseErrorScreen`) — preocupações de shell, não features.
- **`audio/`** — `AudioService` (interface) + `_JustAudioService` (real) + `FakeAudioService` (`lib/audio/testing.dart`, importável só de `test/`). Só este módulo importa `just_audio`/`record`.
- **`exercicios/`** — o loop de prática: `ExerciseQuestion`/`AnswerOption` (type-agnostic), motifs, explicação de erro, `PracticeSession`/`SessionResultReported`, geração de variações; `PracticeScreen` é a tela de sessão, `PracticeController` o notifier e `ExerciseCardFlow` o card de um exercício (dirigido por `onAnswer`/`onAdvance`, reusável pelo Nivelamento) — serve intervalo, acorde e escala.
- **`progressao/`** — fatia mínima da AD-2: `VariantHistoryRepository` (histórico de variações) + placeholders de Skill Tree/Progresso. O Epic 2 estende este módulo.
- **Fluxo de mutação:** `UI → Riverpod Notifier → Repository (domain) → Drift DAO`. Leitura reativa: Drift stream → Repository → provider → UI. Nenhuma tela chama Drift direto.
- **Convenções:** IDs de entidade = `String` UUID v4 · datas ISO 8601 UTC no banco · erros de domínio como `sealed class ... implements Exception` por módulo, nunca exception genérica cruzando fronteira · estado assíncrono via `AsyncValue`.

### Regras que o CI aplica (`tool/`)

| Script | O que impede |
|---|---|
| `check_module_boundaries.dart` | 6 regras: reach-in em `data/`/`presentation/`, Drift fora de `core/`, `just_audio`/`record` fora de `audio/`, `testing/` importado de `lib/`, apresentação de `exercicios` nomeando tipos de exercício |
| `check_curriculum.dart` | `order` não único/crescente; `scaffoldIntensity` ou "limpeza" do `timbreScaffold` **subindo** ao longo dos estágios; valores fora da taxonomia |
| `check_app_id.dart` | `applicationId`/bundle id ≠ `app.catear` |
| `check_deferred_owners.dart` | item de `deferred-work.md` com `owner: dev da X` sobrevivendo à story X sem re-triagem |
| `gen_contrast_audit.dart` | regenera [`docs/design/contrast-audit.md`](docs/design/contrast-audit.md) |

### Estrutura de pastas

```
lib/
  app/            # shell: HomeShell, telas Home/Settings/erro
  core/           # tokens, tema, MascotBubble, AppDatabase (+ recent_variants, placements), databaseProvider
  curriculo/      # catálogo como dado: modelos, CurriculoRepository
  audio/          # AudioService, impl just_audio, testing/FakeAudioService
  exercicios/     # loop de prática: questão, motif, sessão, variações, explicação de erro, tela
  progressao/     # histórico de variações + nível de partida (AD-2) + placeholders de Skill Tree/Progresso
  nivelamento/    # nivelamento por reconhecimento: sequência fixa, regra do nível, notifier + tela
assets/
  audio/                       # 22 amostras de sax (.wav) — ver docs/audio/samples-v1.md
  curriculum/catalog_v1.json   # conteúdo pedagógico da v1
  fonts/                       # Fredoka (só para falas do mascote / telas de vitória)
tool/             # gates de CI (acima), ci.sh, setup.sh
test/             # unit/widget (419) — usa FakeAudioService e Drift em memória
integration_test/ # E2E on-device (23) — áudio real, Drift real, provider graph real
drift_schemas/    # snapshots de schema v1, v2, v3
docs/             # auditoria de contraste, proveniência das amostras
experiments/      # protótipos fora do app (meow-sampler)
_bmad-output/     # artefatos BMad (planejamento, implementação, qualidade)
```

---

## Setup de ambiente

```bash
bash tool/setup.sh          # verifica o toolchain e diz como corrigir cada gap
bash tool/setup.sh --fix    # + aceita licenças e instala os componentes do Android SDK que faltam
```

O que é preciso (o script confere tudo):

| Ferramenta | Versão | Notas |
|---|---|---|
| **Flutter** | **3.47.x** estável | Pin do Epic 1 (`AR-1`). Em CI: `subosito/flutter-action@v2` `flutter-version: 3.47.x`. |
| **Dart** | vem com o Flutter (3.13.x) | — |
| **JDK** | **17 ou mais recente** | Para builds Android. Sem JDK de sistema? Use o JBR do Android Studio: `export JAVA_HOME=/snap/android-studio/current/jbr`. Em CI: `actions/setup-java@v4` temurin 17. |
| **Android SDK** | platform 36 + build-tools 36 (compile/target); platform 35 + system-image `android-35;google_apis_playstore;x86_64` (emulador) | `ANDROID_SDK_ROOT` (default `~/Android/Sdk`). O NDK baixa sozinho no 1º `flutter build apk`. |
| **AVD** | qualquer API 35 | `flutter emulators --create --name pixel` — necessário só para os testes E2E. |

**Shells não-interativos** (hooks, CI local, alguns editores) podem não carregar o `PATH` do seu `.zshrc`/`.bashrc`. Nesses casos, exporte explicitamente:
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

## Rodando o projeto

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # gera *.g.dart / *.drift.dart (git-ignorados)
flutter test                                                # 419 testes unit/widget, ~1,5 min
dart run tool/ci.sh                                          # todos os gates de CI, exit agregado
```

`tool/ci.sh` roda, na ordem: `pub get` → `build_runner` → `drift_dev schema dump` → auditoria de contraste → `dart format --set-exit-if-changed` → `flutter analyze` → fronteira de módulos → app id → currículo → owners do deferred-work → `flutter test`.

### CI (GitHub Actions)

[`ci.yaml`](.github/workflows/ci.yaml) roda em todo PR e push em `master`, 4 jobs em paralelo (~7 min de parede):

| Job | O que prova | Tempo típico |
|---|---|---|
| `gates` | `tool/ci.sh` inteiro, incl. o harness de migração Drift (`test/migration_test.dart`) | ~5 min |
| `build-android` | `flutter build apk --debug` compila | ~4,5 min |
| `build-ios` | `flutter build ios --no-codesign` compila (só build smoke; nunca executa) | ~6 min |
| `e2e-android` | `integration_test/` em emulador API 35 (snapshot de AVD e Gradle em cache) | ~6,5 min |

[`e2e-burn-in.yaml`](.github/workflows/e2e-burn-in.yaml) (noturno + manual) mede a taxa de flake do `e2e-android` rodando a suíte N vezes num emulador quente, via [`tool/e2e_burn_in.sh`](tool/e2e_burn_in.sh). Ficou quebrado da criação até 2026-09-15 (o `android-emulator-runner` executa o `script` linha a linha; o loop precisa viver num arquivo) — a primeira tally válida ainda não foi lida. Alvo antes de tornar `e2e-android` status check obrigatório: 0 falhas em 10 iterações consecutivas.

### App num emulador / device

O projeto tem só targets **android/ios** (web/desktop são vetados). Precisa de um emulador Android **rodando** ou um dispositivo:

```bash
flutter emulators --launch pixel   # num terminal à parte, deixa vivo
flutter run
flutter test integration_test      # E2E — o `flutter test` normal NÃO roda isto
```

Não deixe o emulador como processo-filho do comando de teste — suba separado; se ele morre no build do Gradle o teste falha com `device not found`. 1ª execução baixa NDK/build-tools (~5–7 min), depois ~15–30s.

### Áudio

- **`just_audio`** toca as amostras de `assets/audio/` sem permissão extra (não há URL remota na v1). O `AudioSession` iOS foi configurado (item do `deferred-work.md`), mas o app **nunca foi executado num iPhone/simulador** — só compila no CI.
- **`record`** (captura vocal, Epic 3) exige `RECORD_AUDIO` no `AndroidManifest.xml` e `NSMicrophoneUsageDescription` no `Info.plist` — **ainda não declarados**.
- Testes em `test/` **nunca** dependem de hardware de áudio (`FakeAudioService`, `AR-7`). O que precisa de som real vive em `integration_test/`.
- Para adicionar uma amostra: seguir a receita em [`docs/audio/samples-v1.md`](docs/audio/samples-v1.md) **e** referenciá-la no catálogo — `audio_assets_bundle_test` reprova arquivo órfão em `assets/audio/`.

---

## Currículo como dado (Story 1.2)

O conteúdo pedagógico vive em [`assets/curriculum/catalog_v1.json`](assets/curriculum/catalog_v1.json), não em código — ajustar o currículo não exige recompilar. `CurriculoRepository.load()` devolve modelos de domínio puros e não promete a origem dos dados (porta aberta para OTA futuro).

`tool/check_curriculum.dart` roda no CI antes de `flutter test` e falha se:
- `order` dos estágios não for único e crescente;
- o `scaffoldIntensity` (andaime de cor) **subir** ao longo dos estágios;
- a "limpeza" do `timbreScaffold` **subir** (`clean` depois de `vibrato`);
- qualquer valor cair fora da taxonomia canônica (`ExerciseType`, `ErrorType`, ids dos catálogos).

A taxonomia canônica de teoria musical está em [`content-model.md`](_bmad-output/planning-artifacts/curriculum/content-model.md).

---

## Processo — BMad

O projeto usa o método **BMad** (skills em `.claude/skills/bmad-*`). Artefatos:

- **Planejamento** — [`_bmad-output/planning-artifacts/`](_bmad-output/planning-artifacts/): brief, PRD, arquitetura (ARCHITECTURE-SPINE), UX (DESIGN, EXPERIENCE), épicos e stories, modelo de conteúdo.
- **Implementação** — [`_bmad-output/implementation-artifacts/`](_bmad-output/implementation-artifacts/): uma **spec** por story (kernel congelado + Code Map + tasks + review order), `epic-1-context.md`, `sprint-status.yaml`, retros, e [`deferred-work.md`](_bmad-output/implementation-artifacts/deferred-work.md) — trabalho conscientemente adiado, com triagem de owner forçada pelo CI.
- **Qualidade** — [`_bmad-output/test-artifacts/`](_bmad-output/test-artifacts/): test design do épico, matrizes de rastreabilidade, gates por story, test reviews, charters exploratórios e o quality review mais recente.

Cada story passa por: spec → revisão adversarial (3 lentes) → implementação → code review (3 lentes) → patches → merge. Geração de E2E faz parte do DoD da story.

---

## Trabalho pendente / decisões em aberto

Lista completa em [`deferred-work.md`](_bmad-output/implementation-artifacts/deferred-work.md) e no [quality review](_bmad-output/test-artifacts/quality-review-epic-1-2026-09-15.md). Destaques:

- **Burn-in do E2E** consertado em 2026-09-15, ainda sem tally lida — disparar manualmente (`workflow_dispatch`, `iterations=3`) e ler o número antes de tornar `e2e-android` obrigatório.
- **iOS nunca executado** — só build smoke; NFR-4 (paridade) sem evidência.
- **Roteamento de navegação:** a Story 1.1 usa `IndexedStack` de placeholders; a escolha entre `go_router` e `Navigator` aninhado por aba fica para antes da Story 2.6.
- **`main()` sem handler global de erro** (R10 do test-design), **cobertura não medida** (R6).
- **Uma amostra nova (`sax_db5`)** destravaria a variação da escala maior (hoje presa em C4) — medido na 1.8, decisão adiada.
- **`epic-1-context.md` desatualizado** — recompilar sem perder as tags AD-*/AR-*/FR-* que o código cita por id.

---

## Roadmap

- **Epic 1** (atual) — loop de reconhecimento jogável, sem voz. Faltam 1.9 e 1.10.
- **Epic 2** — Progressão: skill tree, medidores de esforço/habilidade, dificuldade adaptativa, baseline do dia 1.
- **Epic 3** — Produção vocal: detecção de pitch (spike 3.1 em andamento), push-to-talk, módulo de Resolução ativo.
- **Epic 4** — Telemetria passiva de calibração.
