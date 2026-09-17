---
title: 'Story 1.10 — Tela de Settings'
type: 'feature'
created: '2026-09-16'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'dcadfb096583e6468404dc198513766334839a8c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A aba "Ajustes" já tem seletor de tema e um "Sobre", mas a versão é uma constante `'1.0.0'` em `settings_screen.dart` (mente no primeiro bump do `pubspec`), o tema escolhido **não sobrevive** a uma reabertura do app (`ThemeModeController` nunca persistiu — nota da 1.1), e não existe o gancho de "Microfone" que o Epic 3 vai preencher (AC da story).

**Approach:** Tornar a tela a Settings final do Epic 1: tema persistido localmente e restaurado no boot, "Sobre" com a versão real do build, item "Microfone" presente e desabilitado com explicação curta, tudo acessível e no tom do produto. Sem conta/login.

## Boundaries & Constraints

**Always:**

- **Tema aplicado na hora e persistido (decisão humana, 2026-09-16: persistir agora, via Drift).** Escolher claro/escuro/sistema muda o `MaterialApp` no mesmo frame (como hoje) **e** é restaurado no próximo boot antes do primeiro frame com conteúdo (sem "piscar" do tema errado: o boot screen já espera o banco; a preferência é lida no mesmo gate). Persistência **via Drift** (AD-5, sem plugin novo): tabela `preferences` chave/valor em `core/` (schema **v4**), migração 3→4 com dados sobrevivendo, snapshots e `migration_test` estendidos. Dono: `lib/app/` lê/escreve por um repositório em `core/` (preferência de shell, não de feature).
- **Versão real (decisão humana, 2026-09-16: `package_info_plus`).** "Sobre" mostra `version+build` do `pubspec.yaml` (`1.0.0+1` → "1.0.0 (1)"), obtida em runtime por `package_info_plus` (dependência nova, pin exato no `pubspec`; único ponto de uso em `lib/app/`).
- **Item "Microfone" desabilitado** (`ListTile` `enabled: false`, ícone de microfone, subtítulo "Chega com a produção vocal" ou similar no tom do produto) — sem permissão pedida, sem link para configurações do sistema no Epic 1. `Semantics` anuncia como desabilitado.
- **A11y e tom:** rótulos com papel+estado em cada interativo; `TextScaler(2.0)` sem overflow; alvos ≥ 48 dp; microcopy curta, sem jargão (UX-DR14). Estrutura: seções "Tema", "Microfone", "Sobre".
- **Testes existentes continuam verdes** sem asserção alterada (`cat_ear_app_test`, `home_shell_test`, E2E "changing the theme in Settings" e "system dark mode"). O harness ganha o que a persistência exigir (DB em memória já existe em todos).

**Never:**

- Conta/login/perfil. Pedir microfone ou importar `record`/`permission_handler`. Tocar em `nivelamento/`, `exercicios/`, `progressao/`. Notificações, streak, paywall (banidos por UX-DR13).
- `shared_preferences` — a persistência é Drift (AD-5).
- Os dois itens do `deferred-work.md` que citam a 1.10 (`_RetryView` compartilhado; retry automático do Riverpod nos providers antigos) **ficam fora** — são entregáveis independentes; tratar numa chore após o épico.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Escolher "Escuro" | tap no rádio | tema escuro no mesmo frame; linha `preferences(theme_mode=dark)` gravada | gravação falha → tema muda mesmo assim, erro logado |
| Reabrir com "Escuro" salvo | boot, `preferences` tem `theme_mode=dark` | primeiro frame com conteúdo já escuro; rádio "Escuro" marcado | N/A |
| Reabrir sem preferência | `preferences` vazia / valor desconhecido | `ThemeMode.system` (como hoje) | valor inválido → `system`, logado |
| "Seguir o sistema" + SO escuro | rádio `system`, `platformBrightness = dark` | escuro, sem reiniciar (comportamento atual) | N/A |
| Versão | `pubspec` `1.0.0+1` | "Sobre → Versão 1.0.0 (1)" | `package_info_plus` falha → "—", logado, tela não quebra |
| Microfone | item na tela | desabilitado, com subtítulo; tap não faz nada; leitor de tela anuncia desabilitado | N/A |
| `TextScaler(2.0)` | toda a tela | sem overflow; rádios e tiles ≥ 48 dp | N/A |
| Migração 3→4 | banco v3 com `placements`/`recent_variants` | linhas sobrevivem; `preferences` criada vazia | `migration_test` |

</frozen-after-approval>

## Code Map

- `lib/app/settings_screen.dart` -- tela atual: `RadioGroup<ThemeMode>` + "Sobre" com `_version = '1.0.0'`; base a estender (seções, Microfone, versão real).
- `lib/app/theme_mode_controller.dart:6-17` -- `Notifier<ThemeMode>` com `build() => system`, `set()`; passa a ler a preferência (via repositório) e a gravar em `set()`.
- `lib/app/cat_ear_app.dart:17-40` -- `databaseProvider` → `_EntryGate` → `placementProvider`; a preferência de tema precisa estar resolvida antes do primeiro frame com conteúdo (ler no mesmo `when` do gate ou um `FutureProvider` que o `MaterialApp` espera junto com o banco).
- `lib/core/database/placements.dart`, `app_database.dart` -- **modelo** de tabela + DAO + `onUpgrade if (from < 3)`; `Preferences` + `if (from < 4)`; `schemaVersion => 4`.
- `drift_schemas/`, `test/generated/migrations/`, `test/migration_test.dart:133-183` -- dump, `schema generate`, casos 3→4 / 1→4 com sobrevivência.
- `lib/progressao/data/placement_repository_impl.dart` -- **modelo** de repositório sobre `databaseProvider.future` + `@Riverpod(retry: _noRetry)`; o repositório de preferências segue igual, mas vive em `core/` (não é feature).
- `lib/core/core.dart` -- barrel; exportar o DAO/repositório de preferências.
- `pubspec.yaml:5` -- `version: 1.0.0+1`; `package_info_plus` entra em `dependencies` com pin exato.
- `test/cat_ear_app_test.dart:116` ("picking Escuro switches brightness live"), `test/home_shell_test.dart`, `integration_test/catear_e2e_test.dart:261-290` (tema em Settings, dark do sistema) -- não mudam asserção; harness já usa Drift em memória.
- `test/progressao/placement_test.dart` -- **modelo** de teste do repositório (clock, banco indisponível).
- `test/accessibility_test.dart` -- padrão para `TextScaler(2.0)` e ≥ 48 dp.
- `tool/check_module_boundaries.dart` Regra 2 -- `lib/app/` não importa Drift direto: passa pelo `core.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/database/preferences.dart` + `app_database.dart` -- tabela `Preferences(key PK, value)` + DAO `get(key)`/`put(key, value)`; `schemaVersion => 4`; `onUpgrade if (from < 4)` -- schema
- [x] `drift_schemas/`, `test/generated/migrations/`, `test/migration_test.dart` -- dump, snapshot v4, casos 3→4 e 1→4 -- trip-wire
- [x] `lib/core/preferences/theme_preference_repository.dart` + barrel -- `ThemePreferenceRepository{read() → ThemeMode?, write(ThemeMode)}` sobre `databaseProvider.future`, `@Riverpod(retry: _noRetry)`; valor desconhecido → `null` + log -- persistência
- [x] `lib/app/theme_mode_controller.dart` -- vira `AsyncNotifier`/lê a preferência no `build`, `set()` grava (falha logada, estado muda) -- restaurar no boot
- [x] `lib/app/cat_ear_app.dart` -- `MaterialApp.themeMode` espera a preferência junto com o banco (boot screen cobre); sem frame com tema errado -- gate
- [x] `pubspec.yaml` + `lib/app/settings_screen.dart` -- `package_info_plus` pinado; seções Tema / Microfone (desabilitado) / Sobre (versão real, "—" em falha); `Semantics` -- tela
- [x] `test/app/settings_screen_test.dart`, `test/core/theme_preference_test.dart`, `test/cat_ear_app_test.dart` -- as linhas da matriz: persistência (gravação, restauração, valor inválido, falha), versão (ok/falha), microfone desabilitado, a11y 2.0 + 48 dp, primeiro frame já no tema salvo -- testes
- [x] `README.md`, `sprint-status.yaml` -- docs

**Acceptance Criteria:**
- Given o tema "Escuro" escolhido, when o app é fechado e reaberto (mesmo banco), then o primeiro frame com conteúdo já é escuro e o rádio "Escuro" está marcado.
- Given `pubspec.yaml` `version: X+Y`, when a tela "Sobre" abre, then mostra "X (Y)" sem constante em código.
- Given a tela de Settings, when lida por leitor de tela, then cada rádio anuncia papel+estado e "Microfone" anuncia desabilitado.
- Given `dart run tool/ci.sh`, when roda, then exit 0; nenhuma asserção existente muda.

## Implementation Notes

**Schema v4 — `preferences(key PK, value)`** (`lib/core/database/preferences.dart`). Key/value, not a column per preference, so Epic 3's playback volume costs no migration. `PreferencesDao.get/put` hand back plain strings; `put` is an upsert, so one preference is always one row. `onUpgrade` gained `if (from < 4) createTable(preferences)`; `migration_test` gained 3→4, 1→4, a survival case (a v3 install keeps its `recent_variants` and its `placements`) and the v4 table list.

**`ThemePreferenceRepository` lives in `core/preferences/`, not in a module.** Shape copied from `placement_repository_impl.dart` (library-private impl over `databaseProvider.future`, `@Riverpod(retry: _noRetry)`), but the theme is a shell concern and `lib/app/` is its only reader and writer. The on-disk value is a stable token (`light|dark|system`), never the enum index or `name`: an unknown token reads as `null` + a log, which the app renders as "follow the system".

**`storedThemeModeProvider` never errors.** What guarantees that is the `try/catch` inside it: a preference that cannot be read is logged and degrades to `null`, so the provider can never enter an error state and never hold the app on the boot screen or route it to `DatabaseErrorScreen` (that screen stays owned by `databaseProvider`). `@Riverpod(retry: _noRetry)` is kept as defence in depth — if a later edit lets an exception through, the default ~38 s of backoff must not come back with it — and its doc now says so instead of claiming the credit.

**`ThemeModeController` stayed a synchronous `Notifier`.** `MaterialApp.themeMode` needs a value on *every* frame, including the boot frames before the database is open, so an `AsyncNotifier` would have meant a nullable theme at the root. `build()` instead watches `storedThemeModeProvider` (`system` while in flight, the stored value once it lands) and `CatEarApp` waits on the same provider before it shows any *content*. Side effect: `test('themeModeProvider defaults to system')` kept its assertion untouched.

**One source of truth after a write (review P1).** Because `build()` re-derives from `storedThemeModeProvider`, anything that recomputes the notifier — `DatabaseErrorScreen`'s retry invalidates `databaseProvider`, and every provider below it follows — would hand back whatever that provider was holding from before the write. `set()` therefore invalidates `storedThemeModeProvider` after a *successful* write, and leaves it alone after a failed one (the in-memory choice stands for the session; the next boot reads whatever did survive).

**The gate waits for a first value, not for "not loading" (review P1).** `data:` keys on `isLoading && !hasValue`. A re-read keeps its previous value, and swapping the shell for the boot screen then would throw away the first-use gate's decision and the selected tab for a value about to come back the same. Two tests in `cat_ear_app_test` pin this: one completes the theme read by hand with the database and the level already resolved (deleting the branch turns it red — the other boot tests only pass by incidental query ordering), the other invalidates `databaseProvider` mid-session and walks the frames.

**`themeAnimationDuration: Duration.zero`, everywhere.** Unplanned: `MaterialApp` cross-fades between colour schemes over 200 ms, so even with the gate correct the first content frame was a *light* frame turning dark — the flash the AC forbids. Kept for the manual switch too (human decision, 2026-09-17): the frozen block's "muda o `MaterialApp` no mesmo frame (como hoje)" is read literally, no cross-fade at all. The frame-by-frame test fails again if the duration comes back.

**Version.** `lib/app/app_version.dart` is the single point of use of `package_info_plus` (pinned `10.2.1`, like every runtime dependency since the Epic 1 stack was fixed; it brings `http` and `win32` into the lock file). It formats `version (build)`, drops an empty build number, and returns `'—'` (`unknownAppVersion`) both on failure and on a lookup that succeeds with an empty version — succeeding with nothing to say is the same fact as failing. The Settings row renders blank while the read is in flight and `'—'` only on error, so the first frames no longer claim the version is unreadable. `test/app/app_version_test.dart` reads `version:` out of `pubspec.yaml` (with an `orElse` that fails readably) so a bump moves the expectation instead of breaking it; the no-mock failure case lives in `app_version_missing_platform_test.dart`, a file of its own, because `PackageInfo`'s static cache has no reset and a randomised order would otherwise flip it into the mocked path.

**E2E: no new journey, one new assertion.** `Verification` pins `integration_test` at 23, so the existing 4-tab shell journey — which already opens "Ajustes" — grew an assertion that the "Versão" row is not `unknownAppVersion` and does match `version (build)`. That is the only place `package_info_plus` reaches the platform: every widget test injects the value through `setMockInitialValues`, which answers from a static before the channel is touched, so a plugin that silently stopped resolving would otherwise ship with CI green.

**Surface kept narrow.** `core.dart` exports the repository port, not `PreferencesDao` and not the `theme_mode` key: the DAO's own doc calls itself the only door into the table, and an exported key is an invitation to a second writer. Tests reach the table as `db.preferencesDao` with a local `_themeModeKey` constant.

**Test harnesses made honest.** `home_shell_test` and `accessibility_test` build Settings eagerly through `HomeShell`'s `IndexedStack`, so both now get an in-memory `databaseProvider` and a `PackageInfo` mock instead of passing because the missing platform channels throw and the failures are swallowed — `accessibility_test` asserts that no non-overflow error escapes, which was true by accident.

## Spec Change Log

## Review Triage Log

Passo 4, iteração 0 (2026-09-17). BH = blind hunter · EC = edge-case hunter · VG = verification-gap.

| # | Achado | Veredito | Evidência | Rota |
|---|---|---|---|---|
| BH1 / EC2 | Duas fontes de verdade: `set()` grava mas não invalida `storedThemeModeProvider`; `build()` re-deriva do disco e reverte a escolha num rebuild | high | Verificado em `theme_mode_controller.dart` (`build()` = `ref.watch(storedThemeModeProvider).value ?? system`) + caminho de rebuild real: `onRetry` do gate (`cat_ear_app.dart:47`) invalida `databaseProvider` → cascateia. Pior no caso que o código tolera de propósito (gravação falhou) | patch (P1) |
| EC3 | Gate usa `storedTheme.isLoading` sem `hasValue`: um refresh mid-session troca o shell pelo boot screen e perde `_levelled` + aba selecionada | high | Verificado `cat_ear_app.dart:51-52`; qualquer invalidação de `databaseProvider` recoloca o provider em loading **segurando** valor | patch (P1, mesmo ponto) |
| VG1 | O gate anti-flash não é pinado: removendo o branch inteiro os 12 testes de `cat_ear_app_test` passam (a proteção real vira a ordem incidental de duas queries) | medium | Pré-verificado por mutação (VG). O `themeAnimationDuration: Duration.zero` **é** pinado (mutação falha) | patch (P2) |
| VG2 | `package_info_plus` nunca executa de verdade: todo teste verde injeta pelo `setMockInitialValues` (estático lido antes do canal); nenhum E2E olha a linha Versão | medium | Pré-verificado (VG) lendo o pacote (`package_info_plus.dart:77-80,188-199`); grep em `integration_test/` por "Versão"/"Sobre" não retorna nada. Degradação silenciosa para "—" passaria com CI verde | patch (P3) — estende a jornada existente que já abre Ajustes, mantém 23 |
| BH5 / VG-outros | `home_shell_test` e `accessibility_test` passaram a alcançar o `databaseProvider` real (sem override) e só ficam verdes porque a falta do canal `path_provider` lança e o erro é engolido | medium | Verificado: nenhum dos dois tem override; `SettingsScreen` está no `IndexedStack` eager do `HomeShell`. `accessibility_test:41-43` asserta que nenhum erro não-overflow escapa — verde por acidente | patch (P4) |
| EC4 | Linha Versão mapeia `loading` e `error` para o mesmo "—" (`maybeWhen`/`orElse`) | low | Verificado `settings_screen.dart:82-86`; primeiros frames afirmam "ilegível" enquanto só carrega | patch (P5) |
| EC1 | `PackageInfo` com `version` vazia → linha vazia ou " (1)" em vez de "—" | low | Verificado `app_version.dart:22-24`; guarda de uma linha | patch (P5) |
| BH4 | Branch `build.isEmpty → info.version` sem teste | low | Verificado; é o formato "versão sem build" | patch (P5, junto) |
| BH2 / EC6 | `app_version_test` diz "um bump move a expectativa" e na linha seguinte fixa `'1.0.0 (1)'` | medium | Verificado: a asserção anterior já compara com o valor lido do `pubspec`; a literal só transforma um bump em teste vermelho | patch (P6) |
| BH3 | Dependência de ordem no `app_version_test` (cache estático do `PackageInfo` sem reset) presa por comentário | medium | Verificado no pacote; `--test-randomize-ordering-seed` ou um caso inserido acima inverte silenciosamente | patch (P6, mesmo arquivo) |
| EC5 | `app_version_test` lê `pubspec.yaml` sem `orElse`/diagnóstico | low | Verificado; falha vira `StateError` cru | patch (P6) |
| BH10 | Baselines de contagem divergem dentro do diff: README 419→454, spec diz "427 antes" e "427 + novos" | low | Verificado: o número certo antes era 427 (README estava desatualizado desde a 1.9) | patch (P7) |
| BH11 | README conta story em review como entregue ("12 de 12"), invertendo a convenção da 1.9 ("10 de 12 … 1.9 em review") | low | Verificado `README.md:11` + `sprint-status.yaml` = `review` | patch (P7) |
| BH12 | Teste de 48 dp mede 5 linhas sem rolar, enquanto o teste de overflow logo acima rola -400 px | low | Verificado `settings_screen_test.dart`; depende da superfície 800×600 construir tudo | patch (P8) |
| BH13 | `late AppDatabase db` atribuído dentro do override; nos casos `failing: true` nunca é atribuído | low | Verificado `theme_preference_test.dart`; erro vira `LateInitializationError` ilegível | patch (P8) |
| BH9 / EC-flash | `themeAnimationDuration: Duration.zero` é global: tira o cross-fade também da troca manual; `_BootScreen` ainda renderiza sob `system` | medium | Verificado. Desvio do bloco congelado ("como hoje" incluía o fade) — **decisão do humano**, não do review | surfaceado ao humano (P9 condicional) |
| BH6 / EC9 | `core.dart` exporta `PreferencesDao` enquanto a doc diz "única porta"; sem regra de fronteira | low | Verdadeiro; nada fora de `core/` nomeia o tipo hoje (testes usam `db.preferencesDao`) | patch (P10) — suavizar a doc ou remover o export |
| BH7 | `themeModePreferenceKey` exportado no barrel por conveniência de teste | low | Verdadeiro; convite a um segundo escritor | patch (P10, junto) |
| BH8 | Cap de 256 chars no `value` sem justificativa e sem teste; com `set()` engolindo falhas, o primeiro valor maior falha invisível | low | Verificado no schema dumpado. A 1.10 só grava tokens de ≤ 6 chars; o risco é do próximo inquilino | defer |
| VG-outros | `@Riverpod(retry: _noRetry)` em `storedThemeMode` é inerte (o `try/catch` já impede estado de erro) | low | Verificado; a doc atribui ao annotation uma proteção que vem do `catch` | patch (P10, doc) |
| BH14 | Justificativa do pin no `pubspec` é non sequitur; transitivas novas (`http`, `win32`) não documentadas | low | Verificado no `pubspec.lock` | patch (P7, junto com docs) |
| EC7 | AC "nenhuma asserção existente muda" vs `database_test` v3→v4 | low | Contradição interna da AC (a própria AC exige schema v4); mesmo caso da 1.9. Corrigir = editar o spec desta build | rejeitado — surfaceado |
| EC8 | "preferência quebrada nunca segura o app no boot" vs `isLoading` sem timeout | low | O `catch` garante que a leitura resolve; um hang de Drift seguraria o app com ou sem esta story | rejeitado |
| BH-E2E | A jornada E2E foi recusada "porque mudaria a contagem" — argumento ruim; a AC de restart não tem prova on-device (E2E usa DB em memória) | medium | Verdadeiro quanto ao argumento. A prova de restart com banco **em disco** exigiria reabrir o app no device — fora do que `integration_test` faz hoje; o que dá para provar (versão real) vira P3 | patch parcial (P3) + defer do restante |

## Design Notes

Preferências em `core/`, não num módulo: tema é preocupação de shell (`lib/app/`), e `lib/app/` já é o único consumidor de `core/` fora dos módulos. Uma tabela k/v genérica evita uma migração por preferência futura (ex.: volume, no Epic 3), sem virar um catch-all — só `lib/app/` escreve nela.

## Verification

**Run 2026-09-17 (this implementation):** `bash tool/ci.sh` → `CI: OK`. `flutter test` → **458 passed, 0 failed** (baseline before this story: **427**; the README's "419" was stale by two stories and is corrected to 458). `drift_dev schema dump` + `generate` → versions [1,2,3,4]. `flutter build apk --debug` → exit 0. `flutter test integration_test` **not run** (no emulator in this environment) — the new "Sobre → Versão" assertion in the shell journey is unverified until `e2e-android` runs.


**Commands:**
- `bash tool/ci.sh` -- expected: `CI: OK`; 458 testes (427 antes da story + 31 novos), 0 falhas
- `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/ && dart run drift_dev schema generate drift_schemas/ test/generated/migrations/` -- expected: `versions [1,2,3,4]`
- `flutter test integration_test` em emulador (ou `e2e-android` do PR) -- expected: 23 passed
