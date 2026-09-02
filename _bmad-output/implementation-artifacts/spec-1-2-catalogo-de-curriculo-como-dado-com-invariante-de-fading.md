---
title: 'Story 1.2 — Catálogo de currículo como dado, com invariante de fading validada'
type: 'feature'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 1
baseline_commit: '4d44aa67a4a655666f1614a2c4141c587d8ea4b2'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/curriculum/content-model.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-1-abrir-o-app-numa-home-com-navegacao-e-tema.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O conteúdo pedagógico do CatEar não existe e precisa ser **dado versionado**, não código Dart — ajustar o currículo não pode exigir recompilar. A invariante de fading (o andaime de cor/timbre só desvanece) precisa ser garantida em build, não por revisão manual.

**Approach:** Um asset `assets/curriculum/catalog_v1.json` de schema fixo, lido pelo módulo `curriculo` via `CurriculoRepository` que devolve modelos de domínio puros e não promete a origem dos dados. Um `tool/check_curriculum.dart` roda no `ci.sh` antes de `flutter test` e falha se qualquer regra for violada. Catálogo v1 = taxonomia completa do `content-model.md` §7.

## Boundaries & Constraints

**Always:**
- Continuidade da Story 1.1: `flutter_riverpod` 3.4.2 + `riverpod_generator` ^4.0.6 (codegen git-ignorado, regenerado no CI), `flutter_lints`. Convenções do épico: IDs `String`; erros de domínio como `sealed class` que `implements Exception`, nunca exception genérica cruzando fronteira; estado assíncrono via `AsyncValue`.
- Estrutura: `lib/curriculo/{data,domain,presentation}` + barrel `curriculo.dart`. O barrel reexporta **só** de `domain/` **mais** o arquivo do provider (ver abaixo). Nenhuma tela, e nenhum outro módulo, lê o asset ou toca em `data/`. `presentation/` fica só com `.gitkeep`.
- **Modelos de domínio** (`lib/curriculo/domain/`, data classes puras com `==`/`hashCode`, zero anotação de ORM):
  - `Curriculum { int schemaVersion; List<Stage> stages; Set<ErrorType> errorTypes }`
  - `Stage { String stageId; int order; double? scaffoldIntensity; TimbreScaffold? timbreScaffold; List<Exercise> exercises }`
  - `sealed class Exercise { List<String> audioSampleRefs; bool requiresVoice }` com subtipos `IntervalExercise(IntervalSpec interval, Direction direction)`, `ScaleExercise(ScaleSpec scale, Direction direction)`, `ChordExercise(ChordSpec chord)`, `ResolutionExercise(CadenceSpec cadence)`. `requiresVoice` é `true` **somente** em `ResolutionExercise`.
  - `IntervalSpec { String id; int semitones; String nameUi; String abbr; String quality }` · `ChordSpec { String id; String nameUi; List<int> intervals; int inversion }` · `ScaleSpec { String id; String nameUi; List<int> steps }` · `CadenceSpec { String id; String nameUi; List<String> degrees }`
  - Enums definidos **exclusivamente aqui**: `ExerciseType { interval, chord, scale, resolution }`, `Direction { asc, desc }`, `TimbreScaffold { clean, vibrato }`, `ErrorType` (os ids da §8 do content-model: 13 intervalos + `major`/`minor`/`diminished`/`augmented` + `octave-error` + `far-miss`). Cada enum tem um parser `fromJson(String)` que lança `CurriculumError.unknownValue(field, value)` — **nunca** fallback silencioso.
- **Schema do JSON** (`catalog_v1.json`): objeto no topo com `schemaVersion` (int, == 1 no v1), `stages` (lista não-vazia), `intervalCatalog`/`chordCatalog`/`scaleCatalog`/`cadenceCatalog` (listas de objetos com os campos dos `*Spec` acima; ids únicos dentro de cada lista), `errorTypes` (lista de strings). Cada `stage`: `stageId` (kebab-case, único), `order` (int), `scaffoldIntensity` (float 0.0–1.0, **opcional**, por-estágio; `1.0` = andaime de cor cheio, `0.0` = nenhum; ausente = "não aplicável", **excluído** da subsequência da invariante — ≠ `0.0`), `timbreScaffold` (`"clean"|"vibrato"`, opcional, por-estágio), `exercises` (lista não-vazia). Cada `exercise`: `exerciseType`, o campo de id conforme o tipo (`interval` → id de `intervalCatalog`; `chordQuality` → `chordCatalog`; `scaleType` → `scaleCatalog`; `cadence` → `cadenceCatalog`), `direction` (`"asc"|"desc"` — **obrigatório** em `interval` e `scale`, **proibido** em `chord` e `resolution`), `audioSampleRefs` (lista não-vazia de tokens `^[a-z0-9_]+$`, para todo tipo), `requiresVoice` (bool — presente e `true` **se e somente se** `exerciseType == "resolution"`; omitido nos demais).
- **`CurriculoRepository`** (interface abstrata em `domain/`, `Future<Curriculum> load()`). A implementação vive em `lib/curriculo/data/curriculo_repository_impl.dart` como classe **library-private** (`_AssetCurriculoRepository`), recebendo um `AssetBundle` injetável (default `rootBundle`) — esse é o seam de teste. O **único** símbolo público desse arquivo é `curriculoRepositoryProvider` (`@riverpod`), reexportado pelo barrel.
- **`load()` valida e falha com `CurriculumError`** (subtipos `AssetNotFound`, `MalformedCatalog`, `UnknownValue`): raiz não-objeto / JSON ilegível / asset ausente; `schemaVersion` ausente/≠1/não-int; `stages` ou `errorTypes` ausente/vazio/tipo errado; `stageId` duplicado; `order` ausente/não-int; `scaffoldIntensity` fora de 0.0–1.0 ou `NaN`; `direction` presente/ausente contra a regra do tipo; `requiresVoice` violando a bicondicional; `audioSampleRefs` vazio/fora do formato/não-lista; id de exercício não presente no `*Catalog` correspondente; `errorTypes` (do JSON) ≠ conjunto exato dos valores de `ErrorType`; entrada de `*Catalog` com campo ausente/tipo errado. `load()` **não** valida monotonicidade de `order` nem as invariantes de fading — isso é responsabilidade do `check_curriculum` (gate de build).
- **`tool/check_curriculum.dart`** (estilo `tool/check_module_boundaries.dart`; lê o JSON como arquivo; etapa no `tool/ci.sh` **imediatamente antes** de `flutter test`; exit ≠ 0). Valida **tudo que `load()` valida** MAIS: (R1) `order` estritamente crescente e único na lista de `stages`; (R2) na subsequência de estágios **com** `scaffoldIntensity`, ordenada por `order`, cada valor `<=` o anterior; (R3) idem para "limpeza" de `timbreScaffold` (`clean` nunca depois de `vibrato`). Mensagem de erro nomeia o `stageId` quando a violação é de estágio; quando não (entrada de catálogo, `errorTypes`, schema), nomeia `<catalogo>[<índice>]` ou o caminho do campo.
- **Catálogo v1 = content-model §7 na íntegra, exatamente 10 estágios** num único `order` 1..10: 7 estágios de intervalo cobrindo os 13 intervalos (asc; `desc` a partir do estágio 2 — cada direção é um `exercise`), `s-escalas` (major + natural_minor, asc + desc = 4 exercícios), `s-acordes` (major + minor = 2), `s-resolucao` (authentic + plagal = 2, todos `ResolutionExercise` com `requiresVoice: true`). A posição relativa dos blocos não-intervalo no `order` é decisão de conteúdo (sugestão content-model §7: resolução cedo, acordes após estágio 2, escalas após 3). Os `*Catalog` trazem os campos dos `*Spec` para todo id usado; `chordCatalog[].inversion` == 0 no v1.

**Ask First:**
- Tabela Drift, dependência nova, `custom_lint`/pacote-por-módulo.
- Qualquer campo de schema além dos listados aqui; mover `scaffoldIntensity`/`timbreScaffold` para por-exercício.
- Alterar os ids de `ExerciseType`/`ErrorType` ou a taxonomia da §8.
- Escopar a invariante de fading por-`exerciseType` em vez de global.

**Never:**
- Renderizar exercício/tela/skill tree ou tocar áudio — só dado + repositório + lint.
- Estágios `resolution` visíveis no skill tree ou na geração de sessão (a inércia é a flag `requiresVoice` no domínio; não há consumidor nesta story — o enforcement é das Stories 1.7/2.1, ver Design Notes).
- Produzir ou verificar existência de arquivos de áudio. Conteúdo pós-v1 (modos, 7ªs, `diminished`/`augmented`, inversões ≠ 0, cadências `half`/`deceptive`, intervalos compostos). Anotação de ORM nos modelos. Event bus global.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Carga ok | `catalog_v1.json` válido | `load()` → `Curriculum` com 10 estágios; `direction`/`scaffoldIntensity`/`timbreScaffold`/`requiresVoice` mapeados nos modelos; ids resolvidos contra os `*Catalog` | N/A |
| Asset ausente / JSON ilegível / raiz não-objeto | bundle sem a chave, ou `"{ not json"`, ou `[]` no topo | `load()` completa com `CurriculumError.assetNotFound` ou `.malformedCatalog(path)` | erro de domínio (`implements Exception`), nunca `FormatException`/`TypeError` cruzando a fronteira |
| `schemaVersion` incompatível | ausente, `2`, ou `"1"` | `load()` → `CurriculumError.malformedCatalog('schemaVersion')` | idem |
| Valor fora da taxonomia | `exerciseType`/`interval`/`direction`/`timbreScaffold`/`errorTypes[i]` desconhecido | `load()` → `CurriculumError.unknownValue` nomeando o campo | idem — nunca fallback para um valor default |
| Estrutura malformada | `stages: []`; `stage.exercises: []`; `stageId` duplicado; `order` não-int; `scaffoldIntensity: 1.5`/`NaN`; `audioSampleRefs: []`/`"Piano C4"`/string única; entrada de `*Catalog` sem `nameUi` | `load()` **e** `check_curriculum` → erro nomeando o alvo | falha o `ci.sh`; `load()` idem em runtime |
| `requiresVoice` mal-usado | `resolution` sem `requiresVoice`; ou `interval` com `requiresVoice: true` | `load()` **e** `check_curriculum` → erro (bicondicional violada) | idem |
| `direction` mal-posicionado | `chord` com `direction`; `interval` sem | `load()` **e** `check_curriculum` → erro | idem |
| `order` não-monotônico | `[1,3,2]` (únicos, não crescentes) ou `[1,2,2]` (duplicado); array em ordem ≠ `order` | `check_curriculum` R1 → exit ≠ 0 nomeando os `stageId` | build falha antes de `flutter test` |
| Fading de cor sobe | subsequência filtrada por `order` com `scaffoldIntensity` crescente; ou estágio sem o campo no meio (deve ser ignorado, não tratado como 0.0) | `check_curriculum` R2 → exit ≠ 0 nomeando os dois estágios; catálogo com "buraco" válido → exit 0 | idem |
| Fading de timbre sobe | estágio `clean` depois de um `vibrato` na ordem por `order` | `check_curriculum` R3 → exit ≠ 0 | idem |
| `errorTypes[]` fora de sincronia | falta um id de `ErrorType`, ou tem um a mais | `load()` **e** `check_curriculum` → erro nomeando o(s) id(s) | idem |
| id de exercício órfão | `chordQuality: "sus4"` sem entrada em `chordCatalog` | `load()` **e** `check_curriculum` → erro nomeando `stageId` + id | idem |

</frozen-after-approval>

## Code Map

Estado atual:
- `lib/curriculo/curriculo.dart` -- barrel doc-comment-only (Story 1.1); reescrever
- `lib/curriculo/{data,domain}/.gitkeep` -- substituídos por código; `presentation/.gitkeep` fica
- `lib/core/database/app_database.dart` -- `@DriftDatabase(tables: [])` vazio; **não mexer** (1ª tabela é a Story 1.8)
- `tool/check_module_boundaries.dart:1-14` -- Regra 1 já bloqueia arquivos **fora** de `lib/curriculo/` de tocar `curriculo/data/`; o barrel está dentro, então exportar `data/curriculo_repository_impl.dart` do barrel é permitido pela ferramenta atual — **sem mudança na ferramenta** (é extensão consciente da convenção "barrel só domain/" da Story 1.1, ver Design Notes)
- `tool/ci.sh:30` -- etapa `test` é a última; inserir `curriculum` imediatamente antes
- `.github/workflows/ci.yaml` -- só chama `bash tool/ci.sh`; sem mudança
- `pubspec.yaml:47` -- seção `flutter:`; adicionar `assets: [assets/curriculum/catalog_v1.json]`
- `test/module_boundary_test.dart:25-96` -- padrão de fixtures temp-dir + `Process.run` bom/ruim a espelhar em `check_curriculum_test.dart`
- `test/database_test.dart` -- padrão de seam por injeção (`NativeDatabase.memory()`); o análogo aqui é `AssetBundle` injetável
- `content-model.md` §1–§8 -- taxonomia, ids e forma JSON (fonte de verdade do conteúdo)

Arquivos a criar:
- `assets/curriculum/catalog_v1.json` -- catálogo v1 completo (§7), 10 estágios
- `lib/curriculo/domain/enums.dart` -- `ExerciseType`, `ErrorType`, `Direction`, `TimbreScaffold` + `fromJson` c/ `unknownValue`
- `lib/curriculo/domain/catalogs.dart` -- `IntervalSpec`, `ChordSpec`, `ScaleSpec`, `CadenceSpec`
- `lib/curriculo/domain/curriculum.dart` -- `Curriculum`, `Stage`, `sealed class Exercise` + 4 subtipos
- `lib/curriculo/domain/curriculo_repository.dart` -- interface + `sealed class CurriculumError implements Exception` (`AssetNotFound`, `MalformedCatalog(path)`, `UnknownValue(field, value)`)
- `lib/curriculo/data/curriculo_repository_impl.dart` -- `_AssetCurriculoRepository` (library-private, `AssetBundle` injetável, `dart:convert`, todas as validações de `load()`) + `curriculoRepositoryProvider` (`@riverpod`, único símbolo público)
- `lib/curriculo/curriculo.dart` -- barrel: reexporta `domain/` + `curriculoRepositoryProvider`
- `lib/curriculo/domain/curriculum_validation.dart` -- funções de validação **compartilhadas** por `load()` e `check_curriculum` (evita duas fontes de verdade); operam sobre `Map<String,dynamic>` cru, devolvem lista de violações `(path, message)`
- `tool/check_curriculum.dart` -- lê o JSON, chama a validação compartilhada + R1/R2/R3, imprime violações, exit agregado
- `test/curriculum_catalog_test.dart` -- `load()` via `AssetBundle` de teste: (a) sobre o `catalog_v1.json` real — contagens estruturais (10 estágios; todo id de cada `*Catalog` é referenciado por ≥1 exercício; todo id do content-model §1/§3/§4/§5 aparece), `direction.desc` presente do estágio 2, `scaffoldIntensity`/`timbreScaffold` carregados nos modelos, `ResolutionExercise` sempre `requiresVoice`, nenhum outro subtipo com `requiresVoice`; (b) sobre fixtures ruins em memória — um caso por subtipo de `CurriculumError` e por regra de `load()`
- `test/check_curriculum_test.dart` -- fixture boa (com "buraco" de `scaffoldIntensity` e array fora de ordem de `order`) → exit 0; ≥1 fixture ruim **por regra e por sub-checagem**: R1 dup `[1,2,2]` + R1 não-monotônico `[1,3,2]`, R2 crescente, R3 crescente, id órfão em cada um dos 4 `*Catalog`, `errorTypes` faltando/sobrando id, `audioSampleRefs` `[]` + regex, `resolution` sem flag, `interval` com flag, `direction` em `chord`, `schemaVersion` errado → cada uma exit ≠ 0 nomeando o alvo

## Tasks & Acceptance

**Execution:**
- [x] `lib/curriculo/domain/enums.dart` + `catalogs.dart` + `curriculum.dart` -- enums (parse c/ `unknownValue`), `*Spec`, `sealed class Exercise` + subtipos
- [x] `lib/curriculo/domain/curriculo_repository.dart` + `curriculum_validation.dart` -- interface `load()`, `sealed class CurriculumError implements Exception` (em `curriculum_error.dart`, reexportado), validação compartilhada `Map → List<CurriculumViolation>`
- [x] `assets/curriculum/catalog_v1.json` + `pubspec.yaml` -- catálogo v1 (content-model §7, 10 estágios) + registro do asset
- [x] `lib/curriculo/data/curriculo_repository_impl.dart` -- `_AssetCurriculoRepository` (`AssetBundle` injetável via `catalog_asset_bundle.dart`) + `curriculoRepositoryProvider` (`@riverpod`); `load()` roda a validação compartilhada e mapeia p/ domínio, senão lança `CurriculumError`
- [x] `lib/curriculo/curriculo.dart` -- barrel: `domain/` + o provider
- [x] `tool/check_curriculum.dart` + `tool/ci.sh` -- validação compartilhada + R1/R2/R3; etapa imediatamente antes de `test`; exit agregado nomeando alvos
- [x] `test/curriculum_catalog_test.dart` + `test/check_curriculum_test.dart` -- cobertura do `load()` (asset real + fixtures ruins por erro) e do script (fixture boa + fixture ruim por regra/sub-checagem)
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- anexado: (1) enforcement de "resolution inerte" no skill tree/geração de sessão é das Stories 1.7/2.1; (2) manifesto de `audioSampleRefs` a produzir é entrada da Story 1.3b

**Acceptance Criteria:**
- Given o asset `catalog_v1.json`, when `CurriculoRepository.load()`, then devolve `Curriculum` com modelos de domínio puros (nenhum tipo Drift/ORM), 10 estágios cobrindo os 13 intervalos, 2 escalas, 2 acordes e 2 cadências; todo `ResolutionExercise` tem `requiresVoice: true` e nenhum outro subtipo tem.
- Given `flutter test`, then todos passam — incluindo o round-trip do catálogo real, um caso por subtipo de `CurriculumError`, e uma fixture ruim por regra/sub-checagem do `check_curriculum` (≥14).
- Given `dart run tool/check_curriculum.dart`, then exit 0 no catálogo v1; e exit ≠ 0 nomeando o alvo para: `order` `[1,3,2]`, `scaffoldIntensity` crescente na subsequência, `resolution` sem `requiresVoice`, `interval` com `requiresVoice`, id de exercício órfão, `errorTypes[]` fora de sincronia com o enum.
- Given um `catalog_v1.json` cujo array de `stages` está numa ordem diferente da de `order`, mas com `order` único/crescente e fading não-crescente, then `check_curriculum` exit 0 (a ferramenta ordena por `order` antes de R1–R3).
- Given `dart run tool/ci.sh`, then a etapa `curriculum` roda imediatamente antes de `test` e um catálogo ruim plantado faz o `ci.sh` exit ≠ 0.
- Given `dart run tool/check_module_boundaries.dart` e `flutter analyze`, then exit 0 / zero issues — `_AssetCurriculoRepository` não é símbolo público, o barrel expõe só domínio + o provider.
- Given `git status`, then `lib/curriculo/presentation/` segue só com `.gitkeep`.

## Design Notes

**`scaffoldIntensity`/`timbreScaffold` por estágio — renegociação de `epics.md` AC1 e content-model §8:** ambos põem `scaffoldIntensity` em `exercises[]`. Esta spec move para o **estágio** porque a própria AC do lint (`epics.md` linha 160, `epic-1-context.md` linha 46) filtra a subsequência **de estágios** — por-exercício torna a invariante ambígua ("qual exercício do estágio conta?"). Ao aprovar esta spec, `epics.md` AC1 e content-model §8 devem ser reconciliados com esta decisão. Voltar para por-exercício é Ask First.

**Validação compartilhada:** `load()` (runtime) e `check_curriculum` (build) usariam duas cópias das mesmas regras e divergiriam. `curriculum_validation.dart` é a fonte única: recebe o `Map` decodificado, devolve `List<(path, message)>`. `load()` lança `CurriculumError` na primeira; `check_curriculum` imprime todas e agrega o exit. As invariantes R1–R3 (ordenação e fading) são só do `check_curriculum` — são invariantes de **conteúdo** garantidas em build; um asset corrompido em runtime já é barrado pelas regras estruturais/de segurança.

**`audioSampleRefs` são tokens opacos:** um token denota "uma amostra pré-renderizada do timbre padrão"; o significado concreto (qual nota/frase) é resolvido pelo módulo `audio` nas Stories 1.3/1.3b. **Contrato para a 1.3b:** a união de todos os `audioSampleRefs` do `catalog_v1.json` é o manifesto exato de amostras que a 1.3b deve satisfazer (inclui as dos estágios `resolution` — a 1.3b decide renderizar já ou adiar até o Epic 3). Registrado em `deferred-work.md`.

**Contagens nos testes são tripwire, não acoplamento:** a taxonomia v1 é congelada (`Ask First` para mudar ids). Os testes verificam **cobertura estrutural** (todo id de catálogo é usado; todo id do content-model aparece), não números mágicos soltos — assim editar `nameUi` ou reordenar estágios não quebra teste, mas perder um intervalo quebra.

**`nameUi` fica no asset:** são conteúdo, não chrome — ficam fora do pipeline de gen-l10n futuro. Se o CatEar localizar, o catálogo ganha uma dimensão de locale (pós-v1).

**Sem tabela Drift:** o catálogo é asset read-only mapeado a cada `load()`. A 1ª tabela é a Story 1.8.

## Spec Change Log

- **2026-09-02 (review_loop 1)** — step-04 review (3 lentes), 10 patches aplicados: (1) `load()` embrulha o passo de mapeamento em `try/catch` → `MalformedCatalog('<root>', 'internal: …')`, nenhum `TypeError`/`CastError` cru cruza a fronteira; (2) leitura do bundle separa `FlutterError` (→ `AssetNotFound`) de qualquer outra falha (→ `MalformedCatalog`); (3) **R1 relaxado** — `order` único **e** estritamente crescente após ordenar por `order`, **sem exigência de densidade** (`[1,3,5]` passa; só duplicata falha); (4) `Curriculum.stages` sempre devolvido ordenado por `order`; (5) cobertura da I/O Matrix completada (`schemaVersion` string/ausente, `stages`/`errorTypes` chave ausente, raiz escalar, campos de `*Catalog` com tipo errado/ausente); (6) smoke tests de exit-code do gate (arquivo ausente → 2, JSON ilegível → 1); (7) testes de "todo id de `*Catalog` referenciado" + "todo id do content-model presente"; (8) teste de superfície do barrel + `export` redundante de `curriculum_error.dart` removido; (9) parsing de enum padronizado (`X.fromJson` + `on CurriculumError`) em `curriculum_validation.dart`; (10) helpers de teste extraídos p/ `test/support/curriculum_fixtures.dart`, R1–R3 e validação estrutural testados por import direto (`test/curriculum_validation_test.dart`), `check_curriculum_test.dart` reduzido a ~6 smokes. `checkFadingAndOrder` movido p/ `curriculum_validation.dart` (função exportada, chamada só pelo gate). `stageId`s de intervalo renomeados p/ slugs sem número (`s-consonancias`, `s-tercas`, …). CI: OK (141 testes).

## Verification

**Commands:**
- `flutter pub get` -- resolve; asset registrado
- `dart run build_runner build --delete-conflicting-outputs` -- gera o provider `.g.dart`
- `dart format --output=none --set-exit-if-changed .` -- sem diffs
- `flutter analyze` -- "No issues found!"
- `dart run tool/check_curriculum.dart` -- exit 0 no catálogo v1
- `dart run tool/check_module_boundaries.dart` -- exit 0
- `flutter test` -- todos passam
- `dart run tool/ci.sh` -- exit 0, com `curriculum` imediatamente antes de `test`

## Suggested Review Order

**Contrato do módulo (entrada)**

- Ponto de entrada: a porta `load()` que não promete a origem dos dados (asset hoje, OTA depois).
  [`curriculo_repository.dart:15`](../../lib/curriculo/domain/curriculo_repository.dart#L15)
- Superfície pública: o barrel expõe só `domain/` + o provider (nada de `data/`).
  [`curriculo.dart:8`](../../lib/curriculo/curriculo.dart#L8)

**Modelos de domínio (puros, sem ORM)**

- `sealed class Exercise` + 4 subtipos; `requiresVoice: true` só em `ResolutionExercise`.
  [`curriculum.dart:87`](../../lib/curriculo/domain/curriculum.dart#L87)
- `Curriculum`/`Stage` — `scaffoldIntensity`/`timbreScaffold` por-estágio, opcionais.
  [`curriculum.dart:14`](../../lib/curriculo/domain/curriculum.dart#L14)
- Enums da taxonomia definidos só aqui; `fromJson` lança `unknownValue`, nunca fallback.
  [`enums.dart:12`](../../lib/curriculo/domain/enums.dart#L12)

**Validação — fonte única (o coração da story)**

- `validateCatalogStructure` — tudo que `load()` e o gate checam (schema, `*Catalog`, cada stage/exercise, bicondicional de `requiresVoice`, `direction` por tipo, `errorTypes` == enum).
  [`curriculum_validation.dart:82`](../../lib/curriculo/domain/curriculum_validation.dart#L82)
- `checkFadingAndOrder` — R1 (`order` único + crescente após sort), R2/R3 (fading só desvanece). **Só o gate chama.**
  [`curriculum_validation.dart:538`](../../lib/curriculo/domain/curriculum_validation.dart#L538)

**Implementação e gate de build**

- `_AssetCurriculoRepository.load()` — lê o bundle (`FlutterError`→`AssetNotFound`, resto→`MalformedCatalog`), valida, mapeia num `try/catch` que impede `TypeError` cru de vazar; devolve `stages` ordenado por `order`.
  [`curriculo_repository_impl.dart:36`](../../lib/curriculo/data/curriculo_repository_impl.dart#L36)
- Seam de teste: `AssetBundle` injetável.
  [`catalog_asset_bundle.dart:3`](../../lib/curriculo/data/catalog_asset_bundle.dart#L3)
- `tool/check_curriculum.dart` — validação compartilhada + R1–R3; etapa no `ci.sh` antes de `test`.
  [`check_curriculum.dart:21`](../../tool/check_curriculum.dart#L21) · [`ci.sh:30`](../../tool/ci.sh#L30)

**Conteúdo**

- `catalog_v1.json` — content-model §7, 10 estágios, `order` 1..10, `scaffoldIntensity` 1.0→0.0, `timbre` clean×7→vibrato×3.
  [`catalog_v1.json:1`](../../assets/curriculum/catalog_v1.json#L1)
- `pubspec.yaml` — asset registrado.
  [`pubspec.yaml:50`](../../pubspec.yaml#L50)

**Testes (suporte)**

- `load()` sobre o asset real + ~25 fixtures de erro + cobertura de órfãos/ids do content-model.
  [`curriculum_catalog_test.dart:18`](../../test/curriculum_catalog_test.dart#L18)
- R1–R3 e validação estrutural por import direto (barato).
  [`curriculum_validation_test.dart:11`](../../test/curriculum_validation_test.dart#L11)
- Gate por subprocesso: fixture boa + exit-codes 1/2 (~6 smokes).
  [`check_curriculum_test.dart:12`](../../test/check_curriculum_test.dart#L12)
