# Spine Pair Review — Perfect Ear

## Overall verdict

Solid hobby-scope spine pair: shape fit, component coverage, and flow coverage are all strong, and the three UJs map cleanly onto the three Key Flows with named protagonist, numbered steps, a climax beat, and edge cases. The real gaps are (1) two MUST-level PRD features — FR-14 (color-only consonance/dissonance scaffolding) and FR-15 (Módulo de Resolução) — are entirely absent from both spines, and (2) the Accessibility Floor makes two promises the rest of the doc doesn't keep: it points to `DESIGN.md` for contrast targets that were never written, and it promises a non-vocal alternative "when technically viable" while FR-3 makes vocal production mandatory for exactly the two flows (onboarding, Resolução) where that alternative would matter most. Given hobby scope, none of this blocks moving forward, but FR-14/FR-15 and the contrast/voice-alternative conflict are worth a fast pass before a downstream consumer (architecture or dev) builds against this spine.

## 1. Flow coverage (EXPERIENCE.md) — adequate

PRD § 2.3 defines UJ-1, UJ-2, UJ-3 (Marina persona) plus an FR-7 edge case. EXPERIENCE.md Key Flows 1–3 map onto these 1:1, each with a named protagonist, numbered steps, a climax beat (called out explicitly), and a failure/edge path. Strong as far as it goes.

### Findings
- **critical** FR-14 (Andaime de cor para consonância/dissonância, PRD §4.6) and FR-15 (Módulo de Resolução, PRD §4.7) — both MUST-level functional requirements — have no Key Flow, no IA surface entry, and no mention anywhere in either spine (EXPERIENCE.md § Information Architecture, § Key Flows). *Fix:* add FR-14's color-fading rule to Skill Tree node behavior (State Patterns) and DESIGN.md Colors, and add FR-15's Resolução module as either a Skill Tree node type or a Key Flow variant.
- **medium** Settings surface (IA table row) has zero coverage in State Patterns, Component Patterns, or Key Flows — it exists only as a one-line `[ASSUMPTION]` in the IA table (EXPERIENCE.md L26). *Fix:* either explicitly scope Settings out of this spine version with a note, or give it minimal state coverage (empty/default state at least).

## 2. Token completeness (DESIGN.md) — thin

Frontmatter defines 17 color tokens with hex values, which is good baseline discipline. But the dark-mode pairing is incomplete, and there's a direct contradiction between the frontmatter and the prose.

### Findings
- **critical** `accent-soft`, `effort-track`, and `skill-track` have no `-dark` counterparts in frontmatter (DESIGN.md L8–24), even though § Brand & Style commits to "modo escuro replica o mesmo aconchego em tons mais profundos" — dark mode is an explicit requirement, not an omittable platform default. *Fix:* add `accent-soft-dark`, `effort-track-dark`, `skill-track-dark`.
- **critical** Frontmatter sets `accent: '#FFC067'` and `accent-dark: '#FFC067'` — identical values, no dark differentiation — but § Colors prose (DESIGN.md L61) states "Laranja Pastel / Accent (`#F4A261` claro / `#F7B685` escuro)", a completely different pair of hex values that doesn't match the frontmatter at all. *Fix:* reconcile — pick one source of truth (frontmatter, since it's what downstream tooling parses) and make the prose match it.
- **high** No contrast targets stated for load-bearing combinations (ink-primary/ink-secondary on surface-base, text on accent button backgrounds), despite the pastel/low-saturation direction being an explicit design goal that makes contrast failure more likely than in a high-saturation palette. EXPERIENCE.md's Accessibility Floor (L74) explicitly defers contrast to DESIGN.md ("Contraste visual vive em `DESIGN.md`") — that promise currently resolves to nothing. *Fix:* state minimum contrast ratios (e.g. WCAG AA 4.5:1 body text) for at least ink-primary/ink-secondary on surface-base and text-on-accent, in both light and dark.

## 3. Component coverage (both spines) — strong

Five components (mascot-bubble, progress-meter, exercise card, skill tree node, baseline comparison card) appear with matching names in both DESIGN.md § Components (visual) and EXPERIENCE.md § Component Patterns (behavioral). No orphans in either direction.

### Findings
None.

## 4. State coverage (EXPERIENCE.md) — thin

### Findings
- **high** No offline/connectivity-loss state anywhere, for an app whose core loop depends on streamed audio and (likely) server-side voice scoring. *Fix:* add an offline state at minimum for Sessão de Exercício (can exercises queue/cache, or does the session block?).
- **medium** No cold-load/empty state defined for Skill Tree or Progresso beyond the one edge case buried in Flow 3 ("se não houver melhora mensurável ainda..."). *Fix:* promote that into the State Patterns table so it's discoverable without reading the flow narrative.
- **medium** Settings has no state coverage at all (see also Finding under Flow coverage).

## 5. Visual reference coverage — strong (N/A)

`imports/`, `mockups/`, `wireframes/` are all empty or absent under this UX folder — there is nothing to link, so this is not a gap. Both spines are honest about this via `[NOTE FOR UX]` / `[ASSUMPTION]` markers (DESIGN.md L52, L68; EXPERIENCE.md L87) rather than inventing references.

### Findings
None.

## 6. Bloat & overspecification — strong

DESIGN.md's § Brand & Style carries editorial voice (permitted for DESIGN.md) but ties every sentence to an actual decision (anti-reference, mascot role, palette rationale) rather than decorative narrative. EXPERIENCE.md stays table-first and doesn't restate PRD content beyond what's needed to anchor flows. No pixel-specs duplicating tokens, no dense prose where a table would work.

### Findings
None.

## 7. Inheritance discipline — thin

### Findings
- **high** EXPERIENCE.md § Accessibility Floor states "Contraste visual vive em `DESIGN.md`" but DESIGN.md defines no contrast rules — a broken cross-reference (see also Finding 2). *Fix:* same fix as Token completeness #3, plus consider phrasing the Accessibility Floor pointer as a `{DESIGN.md.contrast}`-style explicit reference once that section exists, so it's mechanically checkable.
- **low** UJ-1/UJ-2/UJ-3 are referenced by content match (Marina, same beats) but Key Flow headers use "Flow 1/2/3" rather than the PRD's own "UJ-1/UJ-2/UJ-3" labels — harmless for a human reader but slightly weakens machine traceability between the two documents. *Fix:* optional — append "(UJ-1)" etc. to each Key Flow heading.

## 8. Shape fit — strong

DESIGN.md follows the canonical section order exactly (Brand & Style → Colors → Typography → Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts). EXPERIENCE.md has all required defaults (Foundation, IA, Voice and Tone, Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, Key Flows) plus a justified Inspiration & Anti-patterns section (rejects are documented in PRD/brief). No Responsive section — defensible, this is a single mobile surface with platform-native breakpoint handling, not a multi-surface product.

### Findings
None.

---

## 9. Accessibility deep-dive

Scope: consumer mobile app, voice capture as a core mechanic, hobby project — calibrated to "don't ship an accessibility trap," not enterprise/legal compliance.

### Findings

- **high** Voice-alternative promise conflicts with a MUST requirement. EXPERIENCE.md Accessibility Floor (L78) says "Captura vocal tem alternativa não-vocal disponível sempre que tecnicamente viável" — but PRD FR-3 states production vocal is *obrigatória* (mandatory) for the leveling test (FR-1) and the Resolução module (FR-15), with no fallback. The Floor's own hedge ("sempre que tecnicamente viável") papers over a real conflict rather than resolving it: for those two flows, no non-vocal path is architecturally possible under current FRs, so a user who cannot or will not use voice is fully blocked from onboarding. *Fix:* either scope FR-1/FR-15 down to accept a non-vocal recognition-only path as a degraded-but-passable route (as the "sem microfone concedido" state already does for onboarding, EXPERIENCE.md L61), or explicitly accept and document that full participation requires voice — don't leave it as an unstated contradiction between two documents.

- **critical** FR-14's color-only signal has no non-color fallback anywhere in either spine. PRD FR-14 ties consonance/dissonance directly to color as the primary cue in early curriculum stages. Neither DESIGN.md nor EXPERIENCE.md mentions any redundant encoding (icon, pattern, label, shape) for users with color vision deficiency — and since this is untouched by either file (see Flow coverage finding #1), it's currently guaranteed to ship color-only if built as-is. *Fix:* when FR-14 is added to the spine, specify a non-color cue (e.g. icon or motion) that fades in step with the color, not instead of it.

- **medium** Progress meter pair (Esforço = `effort-track` orange, Habilidade = `skill-track` green) and Skill Tree node states (bloqueado/disponível/completo/em reforço) both rely on color as the primary state signal in their DESIGN.md descriptions, with no explicit statement that text labels or icon/shape differences accompany the color. This is very likely fine in practice (a progress meter pair without labels would be confusing to everyone, not just color-blind users), but the spine doesn't say so, so it's not verifiable by a downstream builder. *Fix:* add one line to each component's behavioral spec confirming label/icon redundancy alongside color.

- **medium** Push-to-talk (segurar para gravar, soltar para enviar) is the sole vocal-capture interaction primitive (EXPERIENCE.md L68), with no alternative for users who have difficulty sustaining a hold gesture (tremor, limited dexterity, one-handed use while commuting — a stated usage context, "sessões de 10-15 min" daily). *Fix:* consider a tap-to-start/tap-to-stop alternative alongside or instead of hold-to-record, or note this as a deliberately deferred decision.

- **low** Contrast risk from the pastel direction is plausible but unverified: `ink-secondary` (`#8A7A6B`) and especially `ink-disabled` (`#C9BDAF`) on `surface-base` (`#FFF7EE`) are both warm-on-warm low-contrast pairings by design intent ("evitando... contraste duro"). Without stated contrast targets (see Token completeness #3), there's a real risk the comfortable/soft aesthetic silently fails WCAG AA for secondary text. *Fix:* run the actual hex pairs through a contrast checker once finalized; ink-disabled in particular should be checked against its actual use (likely non-critical/decorative text only, in which case a lower bar is fine — but that exemption should be stated, not assumed).

- **Adequate as scoped:** VoiceOver/TalkBack labeling, numeric announcement for progress meters, dynamic type honoring via tokens, ≥44pt/48dp touch targets, and unlimited-replay audio (EXPERIENCE.md § Accessibility Floor, L76–80) are all reasonable, concretely stated commitments for a hobby-scope app. No changes needed there.

## Mechanical notes

- Frontmatter/prose mismatch on `accent` hex (see Token completeness #2) is the one hard inconsistency found; no broken Mermaid, no dangling `{path.to.token}` references, no component-name mismatches between the two files.
- `sources` frontmatter in EXPERIENCE.md resolves correctly to the PRD and brief; UJ content (not literal IDs) is faithfully carried into Key Flows.
- No mockups/wireframes/imports exist, so no orphaned visual references to flag.
