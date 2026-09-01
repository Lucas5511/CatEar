---
title: 'Story 1.1 — Abrir o app numa Home com navegação e tema'
type: 'feature'
created: '2026-09-01'
status: 'ready-for-dev'
review_loop_iteration: 1
baseline_commit: '6e3dbc7973338b3af15a16f96300ba531dd753d9'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O repositório não tem projeto Flutter. Nada pode ser construído até existir a fundação: estrutura de módulos por feature, tokens de design, banco local com migração, e uma Home navegável com a identidade visual do CatEar.

**Approach:** `flutter create` na raiz (`--org app`, projeto `catear`, plataformas android+ios). Montar `lib/<módulo>/{data,domain,presentation}` com barrels públicos e um check de fronteira de imports (via pacote `analyzer`) no CI. Em `core/`: tokens (paleta light+dark, raios, espaçamento, tipografia), `ThemeData` claro/escuro, e um `AppDatabase` Drift vazio com `MigrationStrategy` + snapshot de schema v1. O app abre num `HomeShell` com bottom `NavigationBar` de 4 abas (Home / Skill Tree / Progresso / Settings), cada uma uma tela placeholder. Contraste dos tokens é validado por teste (WCAG computado dos hex), não por documento à mão.

## Boundaries & Constraints

**Always:**
- Stack exata: Flutter 3.47.x, `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` (3.4.2), `drift` + `drift_dev` (2.34.3), `build_runner`, `path_provider`, `sqlite3_flutter_libs`, `uuid`, `flutter_localizations`. `record` (7.1.1) e `just_audio` (0.10.6) entram no `pubspec` mas não são usados nesta story (adiantam a resolução da stack fixa do Epic 1).
- Módulos: `lib/{core, nivelamento, exercicios, progressao, audio, curriculo}`. Cada um com `data/ domain/ presentation/` e um único barrel público `<módulo>.dart`. O barrel só reexporta de `domain/` (`presentation/` só quando expõe telas de rota). `data/`/`presentation/` de um módulo nunca são importados de fora dele.
- `core/` expõe apenas: tokens de design, `AppDatabase` (+ DAOs futuros), `databaseProvider`, `ThemeData`, `CatText`. Modelos/tabelas gerados pelo Drift nunca aparecem fora de `core/` nem cruzam `data/ → domain/`.
- Shell + telas Home e Settings vivem em `lib/app/` (são preocupações de shell, não features). As abas Skill Tree e Progresso apontam para telas placeholder em `progressao/presentation/` (a Skill Tree é da Progressão — AR-3).
- IDs de entidade = `String` UUID v4 (pacote `uuid`); datas ISO 8601 UTC no banco; erros de domínio como `sealed class`; estado assíncrono via `AsyncValue`.
- `NavigationBar` Material 3, sem `Drawer`. Modais empilham só um nível. `IndexedStack` das 4 telas (placeholders — a decisão de router/nav aninhada está deferida, ver Design Notes).
- Fonte de sistema para corpo/títulos/números. **Fredoka** (instâncias estáticas) só referenciável via `CatText.display`. `MediaQuery.textScaler` respeitado — nenhum texto ou alvo de toque quebra em `TextScaler.linear(2.0)`. Alvos de toque ≥ 48dp.
- Tema claro (creme pastel) é o default; `ThemeMode.system`.
- Todo par de token de cor passa contraste AA (4.5:1 texto normal, 3:1 texto grande / gráfico) contra `surface-base` e `surface-base-dark`, **verificado por `test/contrast_test.dart`** que computa o ratio dos hex. Hex reprovado é escurecido preservando a matiz; a mudança fica registrada.
- `app id = app.catear` (Android `applicationId` + iOS `PRODUCT_BUNDLE_IDENTIFIER`), verificado no CI. Nome de exibição = "CatEar".
- Trabalho na branch `feat/story-1.1-app-shell`. A saída crua do `flutter create` é seu próprio commit. Código gerado (`*.g.dart`, `*.drift.dart`) é git-ignorado e regenerado no CI.
- l10n: `flutter_localizations` + `supportedLocales: [Locale('pt','BR')]` + delegates globais. Extração de strings (gen-l10n/arb) fica para uma story posterior — nesta, textos placeholder podem ser literais.

**Ask First:**
- Flutter 3.47.x não disponível, ou as versões fixadas não co-resolvem (`flutter pub get` falha) → HALT.
- Qualquer desvio da estrutura de 6 módulos ou da stack fixada.
- Adotar `melos`/pacote-por-módulo, `custom_lint`, ou um router (`go_router`) em vez do que a spec descreve.
- Mudar a matiz de um token de cor (o escurecimento mínimo para passar AA não precisa perguntar).

**Never:**
- Ícone de app e splash customizados (a ilustração do mascote não existe — usar o placeholder do Flutter; chore posterior).
- Qualquer tela real de exercício/nivelamento/skill tree/progresso — só placeholders.
- Web/desktop. Tabelas Drift com colunas reais (a 1ª vem na Story 1.8). `record`/`just_audio`/detecção de pitch em uso.
- Síntese de áudio, lógica de currículo, event bus global, `custom_lint` plugin próprio, router.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Primeiro boot ok | App aberto, sem estado | `databaseProvider` resolve; `HomeShell` abre na aba Home; schema v1 criado em `getApplicationSupportDirectory()` | N/A |
| Falha ao abrir o DB | `path_provider` lança, ou arquivo corrompido/`schemaVersion` futuro | `databaseProvider` → `AsyncError`; `DatabaseErrorScreen` (ink-primary sobre surface-base, mensagem + "Tentar de novo") | Botão invalida `databaseProvider`; erro logado via `dart:developer` |
| Troca de aba | Tap num destino da `NavigationBar` | Tela via `IndexedStack`; aba fica selecionada; sem transição que permita swipe | N/A |
| Back do Android numa aba ≠ Home | Botão voltar do sistema com `index != 0` | Volta para a aba Home; não sai do app | `PopScope`: `canPop` só quando `index == 0` |
| Modo escuro do sistema | SO em dark no boot ou em runtime | Tema escuro (tons quentes) sem reiniciar | N/A |
| Texto em acessibilidade máxima | `TextScaler.linear(2.0)` | Nenhum rótulo trunca; nenhum `RenderFlex overflow`; alvos ≥ 48dp | N/A |
| Import proibido | Arquivo fora de `lib/<m>/` importa (ou reexporta) `<m>/data|presentation`, ou não-`core` referencia símbolo `*.drift.dart` | `check_module_boundaries.dart` falha o CI nomeando a linha | N/A |

</frozen-after-approval>

## Code Map

Greenfield. Arquivos a criar:

- `pubspec.yaml` -- deps da stack (pins exatos p/ os 4 nomeados; `^` p/ helpers) + assets Fredoka + `flutter_lints`
- `pubspec.lock` -- commitado
- `.gitignore` -- mesclar bloco Flutter no existente (não sobrescrever); adicionar `**/*.g.dart`, `**/*.drift.dart`
- `analysis_options.yaml` -- `include: package:flutter_lints/flutter.yaml`; excluir `**/*.g.dart`, `**/*.drift.dart`
- `lib/main.dart` -- `ProviderScope` + `CatEarApp`
- `lib/app/cat_ear_app.dart` -- `MaterialApp` (theme/darkTheme/themeMode.system, `supportedLocales`, `localizationsDelegates`), watch `databaseProvider`: loading→placeholder, error→`DatabaseErrorScreen`, data→`HomeShell`
- `lib/app/home_shell.dart` -- `Scaffold` + `NavigationBar` 4 abas, `IndexedStack`, `PopScope` do back
- `lib/app/database_error_screen.dart` -- tela de erro + retry
- `lib/app/home_screen.dart`, `lib/app/settings_screen.dart` -- placeholders (Settings: seletor de tema claro/escuro/sistema aplicado já; "Sobre" com versão; gancho "Microfone" ausente)
- `lib/core/core.dart` -- barrel: tokens, `CatText`, `appTheme`, `AppDatabase`, `databaseProvider`
- `lib/core/theme/tokens.dart` -- `CatColors` (light+dark, valores do DESIGN.md), `CatRadii` (sm 10/md 18/lg 28), `CatSpacing` (4/8/12/16/24/32)
- `lib/core/theme/typography.dart` -- `CatText`: estilos de sistema + `display` (Fredoka w500, `fontFamilyFallback: ['sans-serif']`)
- `lib/core/theme/app_theme.dart` -- `ThemeData appTheme(Brightness)` a partir dos tokens
- `lib/core/theme/wcag.dart` -- `contrastRatio(Color,Color)` (sRGB→linear, `(L1+.05)/(L2+.05)`)
- `lib/core/database/app_database.dart` -- `@DriftDatabase(tables: [])`, `schemaVersion => 1`, `MigrationStrategy(onCreate:.., onUpgrade:(m,f,t) async {}, beforeOpen:(d) => d.customStatement('PRAGMA foreign_keys = ON'))`
- `lib/core/database/database_provider.dart` -- `FutureProvider<AppDatabase>`: resolve path (`getApplicationSupportDirectory`, try/catch), abre, `ref.onDispose(db.close)`
- `lib/{nivelamento,exercicios,progressao,audio,curriculo}/<módulo>.dart` -- barrel: só um `///` doc comment + `library;` (sem código pendurado)
- `lib/{...}/{data,domain,presentation}/.gitkeep`
- `lib/progressao/presentation/skill_tree_placeholder_screen.dart`, `progress_placeholder_screen.dart` -- `SafeArea` + `Center(Text)` no token certo
- `assets/fonts/Fredoka-Regular.ttf` `-Medium.ttf` `-SemiBold.ttf` + `assets/fonts/OFL.txt` -- static instances de github.com/google/fonts (ofl/fredoka)
- `drift_schemas/catear_schema_v1.json` -- `dart run drift_dev schema dump`
- `tool/check_module_boundaries.dart` -- via pacote `analyzer`: para cada unit em `lib/`, resolve imports+exports (relativos→package), falha se um arquivo fora de `lib/<m>/` referencia `<m>/data/` ou `<m>/presentation/` (barrel isento só p/ reexport do próprio `domain/`); falha se arquivo fora de `lib/core/` referencia símbolo de `*.drift.dart`; falha se `lib/` tem 0 `.dart` ou algum não parseia
- `tool/check_app_id.dart` -- grep `app.catear` em `android/app/build.gradle*` e `ios/Runner.xcodeproj/project.pbxproj`; exit ≠ 0 se ausente
- `tool/gen_contrast_audit.dart` -- escreve `docs/design/contrast-audit.md` a partir de `CatColors` + `wcag.dart` (artefato, não fonte de verdade)
- `tool/ci.sh` -- roda cada etapa, agrega exit code
- `.github/workflows/ci.yaml` -- `subosito/flutter-action@v2` fixo `3.47.x` stable + cache; chama as etapas do `ci.sh`
- `test/contrast_test.dart` -- itera pares de token, computa ratio de `CatColors`, assert ≥ 4.5 (texto) / ≥ 3.0 (gráfico: `effort-track`/`skill-track`/`scaffold-*`/`border-hairline`)
- `test/theme_test.dart` -- `appTheme(light)` ≠ `appTheme(dark)` nas cores-chave; `textTheme.bodyMedium.fontFamily` **não** é Fredoka; `CatText.display.fontFamily` **é** Fredoka
- `test/home_shell_test.dart` -- pump `HomeShell`; tap cada destino → tela certa + `selectedIndex` atualiza; a árvore não contém `PageView`; `PopScope` volta p/ Home
- `test/accessibility_test.dart` -- pump `HomeShell` sob `TextScaler.linear(2.0)` → sem overflow; alvos da `NavigationBar` ≥ 48dp
- `test/database_test.dart` -- abre `AppDatabase(NativeDatabase.memory())` → `schemaVersion == 1`, `onCreate` roda sem erro
- `test/module_boundary_test.dart` -- fixtures (caso bom + caso ruim) por regra do script

## Tasks & Acceptance

**Execution:**
- [ ] `.` -- **Task 0**: `flutter --version` é 3.47.x? `flutter pub get` resolve os pins? Se não → HALT (Ask First) -- gate
- [ ] `.` -- `flutter create --org app --project-name catear --platforms=android,ios .`; **commitar a saída crua isolada**; mesclar `.gitignore` gerado no existente; manter nosso `analysis_options.yaml`; remover `README.md` e `test/widget_test.dart` gerados -- fundação
- [ ] `pubspec.yaml` + `.gitignore` -- deps fixadas + `path_provider` `sqlite3_flutter_libs` `uuid` `flutter_localizations`; `dev`: `drift_dev` `riverpod_generator` `build_runner` `analyzer` `flutter_lints`; assets Fredoka; ignorar código gerado -- stack
- [ ] `analysis_options.yaml` -- lints + exclude de gerados -- qualidade
- [ ] `lib/core/theme/tokens.dart` + `typography.dart` + `wcag.dart` + `app_theme.dart` -- tokens light+dark (DESIGN.md), raios, espaçamento, `CatText`, `contrastRatio`, `appTheme(Brightness)` -- UX-DR1/2/15
- [ ] `test/contrast_test.dart` + `tool/gen_contrast_audit.dart` -- teste de contraste dos pares; gerador do `docs/design/contrast-audit.md`; escurecer hex reprovados preservando matiz até o teste passar -- AC de contraste (alta)
- [ ] `lib/core/database/app_database.dart` + `database_provider.dart` -- `AppDatabase` sem tabelas, `schemaVersion 1`, `MigrationStrategy` (onCreate/onUpgrade vazio/beforeOpen FK on), `FutureProvider` com resolução de path protegida e `onDispose` -- migração desde já
- [ ] `drift_schemas/catear_schema_v1.json` -- `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/` -- baseline de migração
- [ ] `lib/core/core.dart` -- barrel -- superfície pública
- [ ] `lib/{nivelamento,exercicios,progressao,audio,curriculo}/` -- `data/ domain/ presentation/` + barrel doc-comment-only -- estrutura
- [ ] `lib/app/*` -- `CatEarApp` (MaterialApp + l10n + watch do `databaseProvider`), `HomeShell` (NavigationBar + IndexedStack + PopScope), `DatabaseErrorScreen`, `HomeScreen`, `SettingsScreen` -- boot + navegação
- [ ] `lib/progressao/presentation/*_placeholder_screen.dart` -- 2 telas placeholder (Skill Tree, Progresso) em `SafeArea` -- abas
- [ ] `lib/main.dart` -- `ProviderScope` → `CatEarApp` -- entrypoint
- [ ] `tool/check_module_boundaries.dart` (+ `analyzer`) + `tool/check_app_id.dart` -- checks de fronteira e de app id -- AD-1 / AR-12
- [ ] `tool/ci.sh` + `.github/workflows/ci.yaml` -- pub get → build_runner → `dart format --set-exit-if-changed` → analyze → check_module_boundaries → check_app_id → test; etapas independentes, exit agregado; Flutter fixo -- CI local desde o início
- [ ] `test/{theme,home_shell,accessibility,database,module_boundary}_test.dart` -- cobertura das ACs e das regras do script -- verificação

**Acceptance Criteria:**
- Given o app criado, when `flutter run` (SDK instalado), then abre no `HomeShell` aba Home tema claro pastel; alternar o SO p/ dark troca sem reiniciar.
- Given `flutter test`, then todos passam — incluindo contraste (ratios computados dos hex), dark ≠ light, fonte de corpo ≠ Fredoka, navegação por aba, sem `PageView`, sem overflow em `TextScaler(2.0)`, `AppDatabase` abre em v1.
- Given `dart run tool/ci.sh`, then todas as etapas rodam e o exit é 0; um import proibido plantado (incl. via `export` ou import relativo) faz `check_module_boundaries` falhar nomeando o arquivo.
- Given `flutter analyze`, then zero issues fora de gerados.
- Given falha ao abrir o DB, then `DatabaseErrorScreen` aparece com retry funcional; o app não trava em branco.
- Given `drift_schemas/`, then contém o snapshot v1.
- Given `applicationId` e `PRODUCT_BUNDLE_IDENTIFIER`, then ambos `app.catear` (o CI verifica).

## Spec Change Log

- **2026-09-01 (review_loop 1)** — bmad-code-review (no-spec, 3 camadas): 20 patches aplicados. Auditoria de contraste virou `test/contrast_test.dart` (era doc à mão — verificação falsa). Adicionados `home_shell_test`/`accessibility_test`/`database_test` + `theme_test` estendido (ACs visíveis não tinham teste no CI). l10n (`flutter_localizations` + pt_BR). Mapa aba↔módulo fixado (`lib/app/` + `progressao/presentation/`). Script de fronteira reforçado (pacote `analyzer`, `export`/relativos, símbolos Drift). Segurança de migração (`schema dump` + `database_test` + FK pragma). Código gerado git-ignorado + `build_runner` no CI. Passo a passo do `flutter create` em repo não-vazio. Caminho de erro do DB (`FutureProvider` + `DatabaseErrorScreen` + app support dir). `PopScope` do back do Android. Barrels doc-comment-only. Fredoka estático + OFL. CI resolvido (`tool/ci.sh` + workflow fixo). `uuid` dep. Task 0 de co-resolução. KEEP: estrutura de 6 módulos, stack fixa, `IndexedStack` de placeholders, script (não `custom_lint`).

## Design Notes

**Fronteira de módulos — script, não `custom_lint`:** AD-1 cita `implementation_imports` (só entre pacotes). Pacote-por-módulo (melos) é peso demais para arrancar o v1 solo. `tool/check_module_boundaries.dart` usando o pacote `analyzer` dá a garantia no CI. Migrar para `custom_lint`/melos → `deferred-work.md`.

**Roteamento de navegação — deferido:** a stack fixa não tem router. A Story 1.1 usa `IndexedStack` de placeholders. Antes da Story 2.6 (skill tree com conteúdo real), decidir entre `go_router StatefulShellRoute.indexedStack` e `Navigator` aninhado por aba — adicionar `go_router` é Ask First. Registrado em `deferred-work.md`.

**Contraste — fórmula:** relative luminance WCAG 2.x (canal sRGB `c/12.92` se ≤ 0.03928, senão `((c+0.055)/1.055)^2.4`; `L = 0.2126R + 0.7152G + 0.0722B`), ratio `(Lmax+0.05)/(Lmin+0.05)`. Texto grande = ≥ 18.66px bold ou ≥ 24px. Checagem preliminar sugere `ink-secondary` (#8A7A6B), `effort-track` (#E8A33D), `skill-track` (#7FB396) reprovando contra o creme — escurecer preservando a matiz quente; re-rodar a matriz inteira após cada mudança (fix de um par pode regredir outro).

**`record`/`just_audio` sem uso nesta story:** entram no `pubspec` agora para adiantar a resolução da stack fixa do Epic 1 e evitar surpresa de versão depois.

## Verification

**Commands:**
- `flutter --version` -- 3.47.x
- `flutter pub get` -- resolve; `pubspec.lock` gerado
- `dart run build_runner build --delete-conflicting-outputs` -- gera `*.g.dart`/`*.drift.dart`
- `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/` -- gera o snapshot v1
- `dart format --output=none --set-exit-if-changed .` -- sem diffs
- `flutter analyze` -- "No issues found!"
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `dart run tool/check_app_id.dart` -- exit 0
- `flutter test` -- todos passam
- `dart run tool/ci.sh` -- exit 0 (roda tudo acima na ordem, exit agregado)
- `flutter run` (com SDK) -- abre no `HomeShell`, 4 abas, tema segue o SO, back do Android volta p/ Home

**Manual checks:**
- `docs/design/contrast-audit.md` lista cada par com ratio e ação.
- `android/app/build.gradle*` e `ios/Runner.xcodeproj/project.pbxproj` contêm `app.catear`.
- Um commit isolado contém só a saída crua do `flutter create`.
