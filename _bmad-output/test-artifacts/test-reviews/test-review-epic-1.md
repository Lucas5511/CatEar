---
scope: Epic 1 (Stories 1.1 + 1.2)
author: Murat (Test Architect)
date: 2026-09-02
baseline: master @ 4da41bb
suite: ~141 testes unit/widget (flutter test) + 8 E2E (integration_test/, fora do CI)
verdict: CONCERNS
---

# Test Review — Epic 1

Auditoria de qualidade da suíte contra a Definição de Pronto de testes (isolamento, asserções que podem falhar, flakiness, estrutura, nomenclatura). Complementa o [test-design](../test-design/test-design-epic-1.md).

## Veredito: **CONCERNS**

A suíte cumpre os critérios de aceitação das duas stories com testes reais de nível baixo — **não há AC sem cobertura, nenhum teste falhando, nenhum `skip`/`solo`/`only` commitado**. Mas há lacunas de **visibilidade** (sem cobertura medida) e **robustez** (asserções fracas, "E2E" que não toca hardware), e dois riscos de score 6 do épico sem mitigação (ver test-design).

---

## Pontos fortes (manter)

1. **Suíte da Story 1.2 é o modelo.** `curriculum_validation_test.dart` testa a validação compartilhada por **import direto** (49 casos); `check_curriculum_test.dart` fica com 6 smokes de subprocesso só para o contrato de exit-code. É exatamente a pirâmide certa.
2. **Fixtures sem vazamento.** `support/curriculum_fixtures.dart` faz deep-copy (`json.decode(json.encode(...))`) do catálogo real e aplica um `mutate` — cada fixture é independente. Bom e ruim por regra.
3. **Cleanup disciplinado.** `addTearDown` em todo lugar: `db.close`, `container.dispose`, restauração de `FlutterError.onError`.
4. **Bug de 1.1 corrigido e não regrediu.** `accessibility_test.dart:39-43` agora asserta que **nenhuma** exceção não-overflow foi engolida durante os pumps.
5. **Locators semânticos** no `integration_test` (`find.text`/`find.byType`), fluxos lineares, DB em memória via override do provider.
6. **`helper expectViolation`** em `curriculum_validation_test` — asserção parametrizada legível, com `reason` que despeja as violações reais no fail.

---

## Achados (corrigir)

### TQ-1 — `database_test.dart`: 1 teste para toda a fundação de banco, com asserção frágil
- `expect(fk.data.values.first, 1)` depende de ordem/nome de coluna do `PRAGMA foreign_keys` e do encoding bool→int do driver. Use `expect(fk.data['foreign_keys'], 1)`.
- O nome diz "runs onCreate" mas não há tabela — `createAll()` é no-op. O teste na verdade prova "abre + FK ligado". **Renomeie** para a verdade e **adicione**: `schemaVersion` bate com o snapshot em `drift_schemas/`; abrir duas vezes o mesmo arquivo não re-roda `onCreate`.
- Sem teste unitário do caminho de erro do `databaseProvider` (path lança / arquivo corrompido) — hoje só existe via `cat_ear_app_test` (widget). Adicionar um teste de `FutureProvider` que injeta um `getApplicationSupportDirectory` que lança.

### TQ-2 — `accessibility_test.dart`: teste de `DatabaseErrorScreen` é quase tautológico
- A tela virou `SingleChildScrollView` (patch da 1.1), então "não dá overflow vertical" passa trivialmente — um scroll view nunca transborda nessa direção. Fortaleça: asserte que o botão "Tentar de novo" continua `hitTestable` e que o texto do título está visível sob `TextScaler(2.0)`.
- Linha 65 usa `expect(errors.map((e) => e.toString()), isEmpty)` enquanto o teste irmão usa o padrão melhor (linha 37/43). Padronize.

### TQ-3 — Alvos de toque: seletor frágil
- `find.descendant(of: NavigationBar, matching: find.byType(GestureDetector))` + `findsNWidgets(4)` acopla o teste às entranhas do Material. Um bump do Flutter que reestruture o `NavigationBar` quebra sem regressão real. Prefira `find.byType(NavigationDestination)` para contar, e meça o alvo via o `Semantics`/`InkResponse` mais estável, ou aceite o acoplamento explicitamente num comentário.

### TQ-4 — `theme_test.dart`: dark mode verificado só por diferença
- `expect(light.colorScheme.surface, isNot(dark.colorScheme.surface))` passa com qualquer valor diferente. Só o **light** tem asserção de valor concreto (linha 16). Adicione as asserções de valor para os tokens dark-chave (`surfaceBaseDark`, `inkPrimaryDark`), senão um dark theme com cores erradas-mas-diferentes passa.

### TQ-5 — Sem medição de cobertura
- `flutter test --coverage` não roda no CI; não há `coverage/lcov.info`, nem threshold, nem relatório. Não dá para responder "o que não está testado". Estimativa por leitura: `lib/curriculo` ~95%, `lib/core/theme` ~90%, `lib/core/database` **~60%** (só happy path), `lib/app` ~80%.
- **Ação:** `flutter test --coverage` no CI + upload do `lcov.info` como artefato. Threshold **informativo** primeiro (sem gate), gate depois que a linha base estabilizar.

### TQ-6 — `integration_test` é um widget test grande, não um E2E de device
- Usa `databaseProvider.overrideWith` in-memory → nunca exercita `path_provider`/`sqlite3` reais nem o processo de app instalado. O nome "E2E" promete mais do que entrega.
- **Valor real que agrega** sobre `cat_ear_app_test`: `CatEarApp` real, sequência completa de navegação, `handlePopRoute`, `tester.view.physicalSize`. Mantenha, mas: (a) rode no CI com emulador (risco R3); (b) adicione **1** teste que use o `databaseProvider` **real** no emulador — é a única forma de pegar regressão no path do banco em device.

### TQ-7 — Sem golden/snapshot para a identidade visual
- O PRD pesa a estética ("creme pastel", dark quente). Hoje o tema é verificado só por igualdade de token — uma regressão no wiring do `ColorScheme`/`ThemeData` em `app_theme.dart` passa em tudo e renderiza errado.
- **Ação:** 1 golden por tela-chave × tema (Home, Settings, DatabaseErrorScreen), gerados numa imagem de CI fixada (`flutter test --update-goldens` só lá). Trade-off: manutenção + flakiness de rendering de fonte entre plataformas — por isso **imagem pinada**. P2, não urgente, mas barato agora que só há 3 telas.

### TQ-8 — Subprocessos de teste
- `module_boundary_test` (6) + `check_curriculum_test` (6) = 12 spawns de `dart run <script>` (recompila cada vez, ~1–3s). `check_curriculum` já foi reduzido no review da 1.2 — bom. Vigie: quando passar de ~15 subprocessos totais, mover a lógica pura para import direto e deixar 1 smoke por script.

### TQ-9 — Sem `tags` para execução seletiva
- Nenhum `@Tags` / `dart_test.yaml`. Quando a suíte crescer (Epics 2–4) não haverá como rodar "só rápidos" no pre-commit vs suíte completa no CI. Adicionar `dart_test.yaml` com `tags: {slow: {}, e2e: {}}` e marcar os subprocessos/integration como `slow`.

---

## Flakiness

Nenhuma fonte de flakiness detectada na suíte atual: sem `sleep`/`waitForTimeout` (só `pumpAndSettle`), sem dependência de relógio de parede, sem ordem entre testes. **Quando o `integration_test` entrar no CI com emulador**, é a fonte de flakiness mais provável do projeto — aplicar burn-in (rodar o job 3× num PR que toque `lib/app/` ou `integration_test/`) e quarentena no mesmo dia se piscar.

---

## Definição de Pronto — checklist

| Item | Status |
|---|---|
| Todo teste roda (sem `skip`/`solo`/`only`) | ✅ |
| Testes isolados (sem ordem, sem estado compartilhado) | ✅ |
| Sem asserção que não pode falhar | 🟡 TQ-2, TQ-4 (fracas, não impossíveis) |
| Cleanup de recursos | ✅ |
| Fixtures bom + ruim por regra | ✅ (1.2), 🟡 (1.1 — `database_test` fino) |
| Nomes descrevem o comportamento, não a implementação | 🟡 TQ-1 ("runs onCreate" engana) |
| Nível mais baixo possível | ✅ (1.2 exemplar), 🟡 (E2E supervaloriza — TQ-6) |
| Cobertura medida | ❌ TQ-5 |
| Flakiness controlada | ✅ hoje / ⚠️ com emulador |
