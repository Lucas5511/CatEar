# CatEar

App de treino de **ouvido relativo** — reconhecimento (e, a partir do Epic 3, produção vocal) de intervalos, acordes, escalas e cadências, sempre em contexto musical. Flutter, Android + iOS, **local-first e offline** (sem backend na v1).

> Estética de app de música, nunca de aula. Feedback de erro nomeia a confusão ("confundiu 3ª maior com 3ª menor"), nunca só "errado".

---

## Estado atual

**Epic 1 — Fundação técnica + primeiro loop de reconhecimento jogável** · em andamento (2 de 11 stories entregues).

| Story | Estado | O que entregou |
|---|---|---|
| **1.1 — App shell, tema, banco** | ✅ merged (PR #1, #2) | Projeto Flutter, 6 módulos por feature, tokens de design light/dark com contraste WCAG verificado por teste, `AppDatabase` Drift vazio com `MigrationStrategy` + snapshot de schema v1, `HomeShell` com `NavigationBar` de 4 abas, tela de Settings com seletor de tema, CI local + GitHub Actions, suíte E2E `integration_test` |
| **1.2 — Catálogo de currículo como dado** | ✅ merged (PR #3) | `assets/curriculum/catalog_v1.json` versionado (taxonomia completa da v1: 13 intervalos em 7 estágios, escalas, acordes, cadências), módulo `curriculo` com modelos de domínio puros + `CurriculoRepository`, e `tool/check_curriculum.dart` que valida a **invariante de fading** (o andaime de cor/timbre só desvanece) em build |
| 1.3 → 1.10 | ⏳ backlog | AudioService, amostras de áudio, exercícios de reconhecimento, feedback de erro, sessão de 10–15 min, anti-decoreba, nivelamento, Settings completo |

Rastreamento detalhado: [`_bmad-output/implementation-artifacts/sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml).
`flutter test` → **141 testes** · `integration_test/` → **8 testes E2E**.

---

## Stack (fixada pelo Epic 1)

- **Flutter 3.47.x** / Dart 3.13.x — projeto novo, sem template starter
- **Riverpod** (`flutter_riverpod` 3.4.2 + `riverpod_generator` — codegen) — gerência de estado
- **Drift** 2.34.3 — banco local SQLite com migrações desde o dia 1
- `record` 7.1.1 + `just_audio` 0.10.6 — no `pubspec` desde já, **ainda não usados** (entram nos Epics 1/3)
- `path_provider`, `sqlite3_flutter_libs`, `uuid`, `flutter_localizations` (pt-BR)

Código gerado (`*.g.dart`, `*.drift.dart`) é **git-ignorado** e regenerado no CI.

---

## Arquitetura

**Módulos por feature** — `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}`. Cada um tem `data/ domain/ presentation/` e expõe um único **barrel público** `<módulo>.dart` que só reexporta de `domain/` (+ o provider Riverpod, quando há). `data/` e `presentation/` de um módulo **nunca** são importados de fora dele — `tool/check_module_boundaries.dart` falha o CI se violado.

- **`core/`** — tokens de design, `ThemeData` claro/escuro, `CatText`, `AppDatabase` + `databaseProvider`. Modelos/tabelas gerados pelo Drift nunca cruzam a fronteira `data/ → domain/` nem saem de `core/`.
- **`lib/app/`** — o shell (`HomeShell`, `HomeScreen`, `SettingsScreen`, `DatabaseErrorScreen`) — preocupações de shell, não features.
- **Fluxo de mutação:** `UI → Riverpod Notifier → Repository (domain) → Drift DAO`. Leitura reativa: Drift stream → Repository → provider → UI. Nenhuma tela chama Drift direto.
- **Convenções:** IDs de entidade = `String` UUID v4 · datas ISO 8601 UTC no banco · erros de domínio como `sealed class ... implements Exception` por módulo, nunca exception genérica cruzando fronteira · estado assíncrono via `AsyncValue`.

### Estrutura de pastas

```
lib/
  app/            # shell: HomeShell, telas Home/Settings/erro
  core/           # tokens, tema, AppDatabase, databaseProvider
  curriculo/      # catálogo como dado: modelos, CurriculoRepository (Story 1.2)
  nivelamento/    # (vazio — Story 1.9)
  exercicios/     # (vazio — Stories 1.4+)
  progressao/     # telas placeholder de Skill Tree/Progresso (Epic 2)
  audio/          # (vazio — Story 1.3)
assets/
  curriculum/catalog_v1.json   # conteúdo pedagógico da v1
  fonts/                       # Fredoka (só para falas do mascote / telas de vitória)
tool/             # check_module_boundaries, check_app_id, check_curriculum, gen_contrast_audit, ci.sh
test/             # testes de widget/unit
integration_test/ # testes E2E (precisam de emulador/dispositivo)
drift_schemas/    # snapshots de schema do Drift
_bmad-output/     # artefatos BMad (planejamento + implementação) — ver abaixo
```

---

## Rodando o projeto

Requer **Flutter 3.47.x** no `PATH`.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # gera *.g.dart / *.drift.dart
flutter test                                                # 141 testes
dart run tool/ci.sh                                          # todos os gates de CI, exit agregado
```

`tool/ci.sh` roda, na ordem: `pub get` → `build_runner` → `drift_dev schema dump` → auditoria de contraste → `dart format --set-exit-if-changed` → `flutter analyze` → **fronteira de módulos** → **app id** → **currículo** (invariante de fading) → `flutter test`. O mesmo roda no GitHub Actions ([`.github/workflows/ci.yaml`](.github/workflows/ci.yaml)).

### App num emulador

O projeto tem só targets **android/ios** (web/desktop são vetados). Precisa de um emulador Android rodando ou um dispositivo:

```bash
flutter emulators --launch <id>
flutter run
flutter test integration_test        # E2E, com o emulador ligado
```

---

## Currículo como dado (Story 1.2)

O conteúdo pedagógico vive em [`assets/curriculum/catalog_v1.json`](assets/curriculum/catalog_v1.json), não em código — ajustar o currículo não exige recompilar. `CurriculoRepository.load()` devolve modelos de domínio puros e não promete a origem dos dados (porta aberta para OTA futuro).

`tool/check_curriculum.dart` roda no CI antes de `flutter test` e falha se:
- `order` dos estágios não for único e crescente;
- o `scaffoldIntensity` (andaime de cor) **subir** ao longo dos estágios;
- a "limpeza" do `timbreScaffold` **subir** (`clean` depois de `vibrato`);
- qualquer valor cair fora da taxonomia canônica (`ExerciseType`, `ErrorType`, ids dos catálogos).

A taxonomia canônica de teoria musical está em [`_bmad-output/planning-artifacts/curriculum/content-model.md`](_bmad-output/planning-artifacts/curriculum/content-model.md).

---

## Processo — BMad

O projeto usa o método **BMad** (skills em `.claude/skills/bmad-*`). Artefatos:

- **Planejamento** — [`_bmad-output/planning-artifacts/`](_bmad-output/planning-artifacts/): brief, PRD, arquitetura (ARCHITECTURE-SPINE), UX (DESIGN, EXPERIENCE), épicos e stories, modelo de conteúdo.
- **Implementação** — [`_bmad-output/implementation-artifacts/`](_bmad-output/implementation-artifacts/): uma **spec** por story (kernel congelado + Code Map + tasks + review order), `epic-1-context.md`, `sprint-status.yaml`, e [`deferred-work.md`](_bmad-output/implementation-artifacts/deferred-work.md) — trabalho conscientemente adiado.

Cada story passa por: spec → revisão adversarial (3 lentes) → implementação por subagente → step-04 review (3 lentes) → patches → merge.

---

## Trabalho pendente / decisões em aberto

Ver [`deferred-work.md`](_bmad-output/implementation-artifacts/deferred-work.md) para a lista completa. Destaques:

- **Reconciliar planejamento:** `epics.md` AC1 e `content-model.md` §8 ainda mostram `scaffoldIntensity` em `exercises[]`; a Story 1.2 moveu para o **estágio** (a AC do lint filtra "subsequência de estágios").
- **Revisão de UX:** o contraste da `border-hairline` (`#BA843E` claro / `#826C55` escuro) ficou mais forte que o DESIGN.md pretendia ao cumprir ≥3:1 — pendente com a UX.
- **Roteamento de navegação:** a Story 1.1 usa `IndexedStack` de placeholders; a escolha entre `go_router` e `Navigator` aninhado por aba fica para antes da Story 2.6.
- **CI:** sem smoke de build nativo (`flutter build apk`/`ios`); a suíte `integration_test` não roda no CI (precisa de emulador).

---

## Roadmap

- **Epic 1** (atual) — loop de reconhecimento jogável, sem voz. Stories 1.3–1.10.
- **Epic 2** — Progressão: skill tree, medidores de esforço/habilidade, dificuldade adaptativa, baseline do dia 1.
- **Epic 3** — Produção vocal: detecção de pitch, push-to-talk, módulo de Resolução ativo.
- **Epic 4** — Telemetria passiva de calibração.
