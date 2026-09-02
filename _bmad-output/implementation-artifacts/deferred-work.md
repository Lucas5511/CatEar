
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

## Deferred from: implementation of spec-1-2 (2026-09-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Enforcement de "estágio `resolution` inerte" no skill tree e na geração de sessão é das Stories 1.7 / 2.1. Nesta story os estágios `resolution` existem só como dado; o único sinal é a flag `requiresVoice: true` no domínio (`ResolutionExercise`). Não há consumidor que os oculte/desabilite ainda.
  evidence: `lib/curriculo/domain/curriculum.dart` — `ResolutionExercise.requiresVoice` sempre `true`; nenhum leitor em `nivelamento/` ou `exercicios/`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Manifesto de amostras de áudio da v1 = a união exata dos `audioSampleRefs` de `assets/curriculum/catalog_v1.json`. É a entrada de contrato da Story 1.3b (inclui as amostras dos estágios `resolution` — a 1.3b decide renderizar já ou adiar até o Epic 3).
  evidence: 14 tokens no v1 — `sax_c4, sax_db4, sax_d4, sax_eb4, sax_e4, sax_f4, sax_gb4, sax_g4, sax_ab4, sax_a4, sax_bb4, sax_b4, sax_c5, sax_d5` (raiz C4, topo até D5; sax alto sem vibrato como timbre padrão, cf. `epic-1-context.md`).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `epics.md` AC1 e `content-model.md` §8 põem `scaffoldIntensity` em `exercises[]`; esta spec moveu para o **estágio**. Os dois documentos de planejamento devem ser reconciliados com essa decisão (registrado na spec, Design Notes).
  evidence: `lib/curriculo/domain/curriculum.dart` — `Stage.scaffoldIntensity` / `Stage.timbreScaffold`; `content-model.md` §8 ainda mostra o campo em `exercises[]`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Seam de teste do `AssetBundle` ficou num arquivo próprio (`lib/curriculo/data/catalog_asset_bundle.dart`, com `catalogAssetBundleProvider` + `catalogAssetKey`) em vez de dentro de `curriculo_repository_impl.dart`, para manter o impl com um único símbolo público (`curriculoRepositoryProvider`) como a spec pede. Ainda em `data/` — não exportado pelo barrel, não importável de fora do módulo; testes fazem override do provider.
  evidence: `lib/curriculo/data/catalog_asset_bundle.dart`; `test/curriculum_catalog_test.dart` (`catalogAssetBundleProvider.overrideWithValue`).

## Deferred from: step-04 review de spec-1-2 (2026-09-02, review_loop 1)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Validação semântica de conteúdo musical no `check_curriculum` — `scaleCatalog[].steps` somar 12; `chordCatalog[].intervals` crescente e dentro da oitava; cardinalidade de `audioSampleRefs` por tipo (intervalo=2, tríade=3, escala=steps+1, cadência ~6). Fora do R1–R3 do frozen; adicionar quando o módulo `audio` (1.3) fixar a semântica das refs.
  evidence: `lib/curriculo/domain/curriculum_validation.dart` só checa tipo/formato, não faixa/soma.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `IntervalSpec.quality` e `intervalCatalog[].id` são strings livres não cross-checadas contra os 13 ids canônicos de intervalo — 3ª cópia da taxonomia (junto de `errorTypes[]` e do enum `ErrorType`). Um `IntervalId` enum unificaria; é mudança de schema (Ask First).
  evidence: `curriculum_validation.dart` `_validateCatalog` case `intervalCatalog` — só `_requireString(quality)`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `catalog_v1.json` não tem JSON Schema / `$schema` / cabeçalho de proveniência. Para "conteúdo editável sem recompilar", um editor de conteúdo não tem como validar uma edição sem rodar o toolchain Dart. Gerar um JSON Schema a partir de `curriculum_validation.dart` (ou à mão) num chore.
  evidence: schema existe só como Dart imperativo + prosa da spec.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: Estratégia de versionamento do asset (como chega o v2: arquivo novo + troca do `catalogAssetKey` vs. bump de `schemaVersion` in-place; expectativa de migração/compat) não documentada, apesar de `curriculo_repository.dart` anunciar "asset hoje, OTA depois".
  evidence: versão codificada no nome do arquivo e em `schemaVersion`, sem doc de transição.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-catalogo-de-curriculo-como-dado-com-invariante-de-fading.md`
  summary: `tool/ci.sh` não tem teste — a etapa `curriculum` antes de `test` pode ser removida/reordenada num edit futuro com todos os testes verdes (R1–R3 só vivem nesse gate). Sem precedente no repo de testar `ci.sh`.
  evidence: grep de `test/` por `ci.sh` não retorna nada.
