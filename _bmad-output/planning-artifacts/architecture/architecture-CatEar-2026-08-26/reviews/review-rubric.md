# Rubric Walker Review — ARCHITECTURE-SPINE.md (Perfect Ear)

**Verdict:** Solid, appropriately-scaled spine for a v1 hobby project — the module boundaries, single-writer rule, and data-driven curriculum are the right calls — but two real gaps should be closed before handoff: AD-2's event contract covers only Exercícios, leaving Nivelamento's write path to Progressão unspecified, and none of the "no direct import / no direct DB access" Rules name an enforcement mechanism, so they're conventions a future-you can silently violate.

## Critical

None. Nothing here would let a build proceed on a false premise or corrupt data silently.

## High

1. **AD-2 leaves Nivelamento's contribution path unspecified.** AD-2 binds "Baseline Dia 1" and names Progressão the sole writer, and the dependency diagram shows `Nivelamento --> Progressao`. But the Rule only defines an explicit event contract (`SessionResultReported`) for the Exercícios → Progressão path. It says nothing about how Nivelamento's baseline-test results reach Progressão. Left as-is, whoever builds Nivelamento has to invent a mechanism — direct write, ad hoc method call, or a second event type — and nothing in the spine forces it to be a reported-event pattern instead of a shortcut through Progressão's internals. This is exactly the kind of two-modules-built-independently divergence AD-2 exists to prevent, and it's the one path the Rule doesn't actually close.
   - *Fix:* extend AD-2's Rule with a second event, e.g. `BaselineCompletedReported`, analogous to `SessionResultReported`, so both producer modules have a named contract.

2. **No enforcement mechanism named for any "don't import/access directly" Rule.** AD-1 ("nenhum módulo importa a camada `presentation/` de outro"), AD-3 ("nenhum outro módulo importa esses pacotes diretamente"), and AD-5 ("nenhuma tela chama Drift diretamente") are all phrased as prohibitions on imports/calls. In a single Flutter package, nothing at the language or build level stops any of these — they're discipline-only conventions unless backed by a lint rule, an architecture test, or a package-boundary split (e.g. melos + separate packages, or a `custom_lint`/`import_lint` rule checked in CI or pre-commit). For a solo hobby project this may be an acceptable trade against tooling overhead, but as written the Rules are not self-enforcing, and the checklist calls for "enforceable." Recommend at minimum one line either committing to a lint rule (there are off-the-shelf Dart import-boundary lints) or explicitly deferring enforcement tooling as a conscious decision rather than silence.

## Medium

3. **Deployment/environments dimension is thin relative to what the checklist expects at this altitude.** Deferred does address distribution (App Store/Play Store) and flags app id/icons/signing as "configure early," which is good. But it says nothing about build flavors/environments (e.g., dev vs. release config, whether a debug-only "dev mode" surface is needed for testing exercises without full curriculum), which is a sub-dimension of the same operational envelope the gate specifically calls out. Given the project is solo/hobby and backend-free, this is a small gap, not a critical one — but a one-line Deferred/open-question entry ("build flavors/dev-vs-release config: not decided, revisit alongside store distribution") would close it rather than leaving it silently unaddressed.

4. **Stack table mixes a verified-pinned entry with unverified placeholders inline, slightly obscuring the caveat.** Flutter is pinned with a date ("3.44.0, mai/2026"); Riverpod/Drift/record/just_audio are "atual estável — confirmar" and pitch detection is explicitly unfixed. This is honestly disclosed and mirrored in Deferred's closing bullet, so it's not a real violation of "verified-current" — the spine is transparent about what's asserted vs. pinned. Flagged only because the table's phrasing ("confirmar versão exata") could be tightened to explicitly say "not verified in this pass" so a reader skimming just the table (not Deferred) doesn't mistake it for a checked-current claim.

## Low / Other

- The two dependency-graph diagrams (state-flow and module-dependency) are a nice touch beyond what's required and make AD-5 and the module graph concrete — no action needed.
- Curriculum-as-data (AD-4) and Audio-behind-interface (AD-3) both correctly anticipate the two named Deferred risk areas (pitch-detection swap, future OTA), so Deferred and the ADs are mutually reinforcing rather than contradicting — good sign the divergence analysis was done holistically.
- No parent spine is inherited (`binds: []`) and no brownfield codebase exists yet, so those two checklist dimensions are vacuously satisfied — correctly not addressed.
- Testes automatizados and Observabilidade are both deferred with a stated reason (no code yet / no usage-metrics need in v1) rather than silently omitted — meets the "decided/deferred/open, not silent" bar.

## Summary Table

| # | Finding | Severity | Disposition |
|---|---|---|---|
| 1 | AD-2 has no event contract for Nivelamento → Progressão (Baseline Dia 1) | High | Fix — extend AD-2 Rule |
| 2 | No enforcement mechanism for import/access-boundary Rules (AD-1, AD-3, AD-5) | High | Discuss / defer explicitly |
| 3 | Deployment/environments (build flavors, dev vs release) not covered in Deferred | Medium | Autofix — one Deferred line |
| 4 | Stack table phrasing on unverified deps could be crisper | Low | Optional polish |
