# PRD Quality Review — Perfect Ear

## Overall verdict

This is a well-formed PRD for what it is: a solo hobby project. The thesis is clear, the FRs are mostly testable, and scope-honesty machinery (Non-Goals, `[ASSUMPTION]` tags, `[NOTE FOR PM]`, Assumptions Index) is used correctly and consistently rather than as decoration. The main soft spots are a handful of undefined magnitudes inside otherwise-testable FRs (durations, counts) and a Vision paragraph that leans on category-generic language before it earns its specificity. Nothing here rises to critical for a hobby-scope document — this is buildable as-is.

## Decision-readiness — adequate

Trade-offs are named rather than smoothed: §4.1 explicitly accepts onboarding friction ("aceitando o atrito descrito no Brief") in exchange for calibrating produção ativa early; §6.2 defers the morphological matrix to v2 while flagging it as a strong brainstorming idea worth revisiting. The Open Questions in §8 are genuinely open — none is a rhetorical question with the answer already given in the surrounding prose. `[NOTE FOR PM]` appears at real tensions (§4.6 fading curve, §6.2 morphological matrix), not at safe checkpoints.

One place decision-readiness thins out: FR-3's vocal-response modality is described as "alternativa ou complemento" to multiple choice without saying which exercises require it versus offer it optionally — a decision that downstream design will have to make anyway, so it would cost little to state now.

### Findings
- **medium** Produção ativa's optionality left implicit (§4.2 FR-3) — "como alternativa ou complemento ao reconhecimento por múltipla escolha" doesn't say whether vocal response is mandatory for some exercise types or always optional. *Fix:* One sentence stating whether v1 makes vocal response mandatory anywhere, or purely optional throughout.

## Substance over theater — strong

No persona theater: a single named protagonist (Marina) carries all three UJs with continuity (day 1 → day 2 → two weeks later), which is the right density for a solo consumer app, not padding. No differentiation/competitor section bolted on for its own sake. The feature-specific NFR in §4.2 ("Áudio deve ser pré-renderizado e testado, não gerado por síntese em runtime") is concrete and tied to a named Brief risk, not boilerplate "must be performant/scalable" language.

The Vision (§1) is mostly earned — it names a specific mechanism (real-timbre audio in musical context, active production, spaced repetition, baseline proof) — but its opening framing ("sessões curtas e diárias, progressão adaptativa, gamificação de verdade") is stock Duolingo-clone language that could preface almost any habit app before the paragraph turns product-specific. Not a rewrite-worthy problem, just worth flagging as the one place the document reaches for a shared trope before it does its own work.

### Findings
- **low** Vision opening leans on category-generic phrasing (§1, first sentence) before differentiating. *Fix:* Optional — lead with the "matemática/intimidação" insight instead of the habit-app checklist, since that's the actual thesis.

## Strategic coherence — strong

The PRD has a clear, stated thesis: ear training is avoided not from disinterest but because it's perceived as "matemática" (§1), and the product's bet is a best-in-class habit-app wrapper around pedagogically serious content. Every major feature traces back to that bet — active production and real-timbre audio serve the "not decorated multiple choice" pedagogy claim; the two-meter system (§4.4) and baseline comparison (§4.5) serve the "prove progress without letting a bad day erase it" sub-thesis; fading scaffolds (§4.6) serve the "andaime, never permanent" pedagogy stance. Success Metrics (§7) are qualitative and self-referential (SM-1, SM-2) rather than vanity activity metrics — appropriate given the hobby framing — and a counter-metric (SM-C1) is present and correctly targets the failure mode (marathon sessions) rather than restating SM-1.

## Done-ness clarity — thin

Most FRs carry testable consequences and this is a genuine strength (e.g., FR-9/FR-10's monotonic-vs-noisy meter behavior is precisely falsifiable; FR-14's fading is measurable). But several FRs leave a magnitude undefined that a story-writer would need to invent:

- FR-1: "sequência curta de exercícios" — no count or bound.
- FR-2: "trecho musical curto" — no duration bound.
- FR-6: "janela razoável de sessões consecutivas" — flagged with `[ASSUMPTION]` as deferred to design, which is the right move, but it means FR-6's own consequence isn't yet independently testable without that follow-up decision.
- FR-13: "ao menos uma métrica comparada" — fine as a floor, but doesn't say which metric is guaranteed to exist for every user (what if a user's only weak spot doesn't map cleanly to a single reaction-time stat?).

This is a hobby PRD reviewed by its own author-as-engineer, so the bar is lower than a multi-team handoff — but since several of the undefined magnitudes are exactly the ones tagged `[ASSUMPTION] ... a definir em design técnico`, the PRD already knows where its own edges are. That's good scope-honesty practice; it just means done-ness clarity for those FRs is deliberately incomplete rather than accidentally so.

### Findings
- **medium** Undefined magnitudes in FR-1 ("sequência curta") and FR-2 ("trecho musical curto") have no `[ASSUMPTION]` tag or deferral note, unlike FR-6 and FR-3 which do. *Fix:* Either tag them as deferred-to-design like FR-3/FR-6, or give a rough bound (e.g., "3–6 exercícios") so the FR is self-testable.

## Scope honesty — strong

§5 Non-Goals is substantive and specific (no instrument technique, no sheet-reading, no complex rhythm, no audiation module, no loot-mechanic randomness) rather than a generic disclaimer. §6.2 correctly distinguishes "deferred with reasoning" (morphological matrix, remedial routes) from "archived, not pursued" (dungeon-crawler surprises) — that distinction is doing real work, not just listing everything left out. `[ASSUMPTION]` density (5 tags) against `[NOTE FOR PM]` (2) and Open Questions (4) is proportionate to a hobby-scope PRD — none of the open items are things a green-light-to-build enterprise PRD should have left unresolved, and this isn't that.

## Downstream usability — n/a (light touch, standalone document)

§0 states this PRD is not intended for multi-stakeholder downstream consumption, so this dimension matters less. Still, the mechanics check out: Glossary (§3) terms are used consistently (Medidor de Habilidade / Medidor de Esforço, Andaime, Resolução, Skill Tree all match their glossary form everywhere they're used in §4). FR IDs run 1–15 with no gaps or duplicates. UJ-1/2/3 each carry the named protagonist Marina inline rather than floating.

## Shape fit — strong

§2.3 explicitly names the shape decision — "escopo hobby, uso o formato leve (frase única) para as jornadas centrais" — and follows through: three single-paragraph UJs with one recurring protagonist, not an over-built persona matrix. Success Metrics are self-referential rather than forced into business-KPI shape. This is the correct calibration for a solo consumer hobby app and the PRD is self-aware about making that choice rather than defaulting into template rigor.

## Mechanical notes

- ID continuity: FR-1 through FR-15 contiguous, no gaps or duplicates. UJ-1–3, SM-1–3 + SM-C1, all referenced correctly from features/MVP scope sections.
- Assumptions Index (§9) roundtrip is clean: all 5 indexed entries (§2.1, §4.1 FR-1, §4.2 FR-3, §4.2 FR-6, §6.2) have a matching inline `[ASSUMPTION]` tag, and no inline `[ASSUMPTION]` tag is missing from the index.
- Glossary drift: none found — Portuguese/English mixed terms ("Skill Tree", "Andaime (Scaffold)") are used in their glossary form consistently in §4 and §6.
- Two FR-level magnitudes (FR-1, FR-2, noted above under Done-ness) are undefined without the deferral tag their siblings (FR-3, FR-6) use — worth aligning for consistency even though low-stakes here.
