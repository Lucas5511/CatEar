
## Deferred from: code review of spec-1-1 (2026-09-01)

- Escolha de roteamento de navegação (go_router `StatefulShellRoute.indexedStack` vs `Navigator` aninhado por aba). A Story 1.1 usa `IndexedStack` de placeholders. Revisitar antes da Story 2.6 (skill tree), quando as abas ganham conteúdo real e a regra "modal empilha só um nível" começa a importar. Adicionar `go_router` à stack é decisão de arquitetura (Ask First).
- Migrar a fronteira de módulos de script para `custom_lint` ou pacote-por-módulo (melos), quando o projeto justificar.

## Deferred from: step-04 review de spec-1-1 (2026-09-01, review_loop 1)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Contraste só é verificado contra `surface-base`/`-dark`; pares sobre `surface-raised` (divisor/hairline em card ~2.6:1) e pares `onX` (onPrimary em accent, onError, label da NavigationBar) não têm teste.
  evidence: `test/contrast_test.dart` itera só os dois backgrounds base; `dividerTheme`/`cardTheme` usam `borderHairline` sobre `surfaceRaised` (#FFFFFF), abaixo de 3:1.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `tool/ci.sh` regenera `drift_schemas/` e `docs/design/contrast-audit.md` mas não roda `git diff --exit-code` depois — drift de arquivos derivados passa despercebido.
  evidence: Nenhuma etapa do `ci.sh` compara a saída regenerada com a versão commitada.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `tool/gen_contrast_audit.dart` duplica a matemática WCAG de `wcag.dart` e recopia toda a paleta em `_tokens` em vez de importar `CatColors`.
  evidence: Comentário no próprio arquivo admite "Keep them in sync".
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: CI não tem smoke de build de plataforma (`flutter build apk`/`ios`); o shell pode falhar a compilação nativa com CI verde.
  evidence: `ci.sh` para em `flutter test`; só roda em `ubuntu-latest`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `test/database_test.dart` usa `NativeDatabase.memory()` sob `flutter test`, que depende de `libsqlite3` do sistema no runner; sem passo `apt-get` nem dep `sqlite3`.
  evidence: `sqlite3_flutter_libs` empacota a lib só no app, não na VM de teste.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `check_module_boundaries.dart` não força acesso barrel-only a `domain/`, não checa direção de camada (core importando feature) nem import relativo que escapa de `lib/`.
  evidence: Rule 1 cobre só `data/` e `presentation/`; `_resolveTarget` não sinaliza alvo `../..`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Sem infra de extração de l10n (arb/AppLocalizations); strings pt_BR inline nos widgets (a spec já adia isso, mas fica registrado).
  evidence: Delegates e `supportedLocales` configurados, mas nenhum `l10n.yaml`/`.arb`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: `main()` não instala handler global de erro (`FlutterError.onError`/`PlatformDispatcher.onError`/zona guardada); único log é `developer.log` dentro do provider do DB.
  evidence: `lib/main.dart` só chama `runApp`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md`
  summary: Contraste da hairline pós-ajuste (#BA843E light / #826C55 dark) ficou muito mais forte que o DESIGN.md pretendia — pendente de revisão com a UX (Sally).
  evidence: Cumprir ≥3:1 como borda não-textual (WCAG 1.4.11) empurrou o hex bem além de uma hairline típica.
