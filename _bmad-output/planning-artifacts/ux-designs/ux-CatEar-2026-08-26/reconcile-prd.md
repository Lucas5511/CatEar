# Reconciliation: PRD vs. UX Spines (DESIGN.md / EXPERIENCE.md)

Date: 2026-09-01
Scope: cross-check every PRD FR/feature/decision against DESIGN.md and EXPERIENCE.md for a coherent surface/flow/behavior counterpart.

## Method

Walked all 15 FRs (§4 of prd.md) plus the three qualitative concepts the task called out by name (esforço pesa mais, sem paredes, andaime com fading), and matched each against IA table, Component Patterns, State Patterns, Interaction Primitives, and Key Flows in EXPERIENCE.md, cross-referencing DESIGN.md for visual-only decisions.

## FR-by-FR Coverage

| FR | PRD decision | UX counterpart | Status |
|---|---|---|---|
| FR-1 | Nivelamento test, recognition + vocal production, mic requested at onboarding | IA row "Onboarding/Nivelamento", Flow 1, State Pattern "Primeiro uso" | Covered |
| FR-2 | Recognition exercises, real-timbre audio in musical context | IA row "Sessão de Exercício", Exercise card component | Covered |
| FR-3 | Vocal production, mandatory in Nivelamento (FR-1) and Resolução (FR-15), optional elsewhere | Push-to-talk primitive, Exercise card ("captura vocal") | Partially covered — see Gap 1 (contradiction) |
| FR-4 | Explanatory feedback on error, never bare "errado" | Voice/Tone table, State Pattern "Resposta incorreta", Flow 2 step 4 | Covered |
| FR-5 | 10–15 min sessions, no marathon incentive | Referenced in IA row purpose text; "Banido" list bans paywall/streak-guilt but doesn't explicitly ban marathon-session incentives | Weak/implicit — see Gap 2 |
| FR-6 | Exercise variation generation (anti-decoreba, no identical repeats in a window) | No mention anywhere in DESIGN.md or EXPERIENCE.md | Gap — see Gap 3 |
| FR-7 | Adaptive difficulty, reinforcement routes, no hard walls | State Pattern "Sessão travada em reforço", Skill tree node states | Covered |
| FR-8 | Skill tree always accessible | IA row "Skill Tree" (tab bar) | Covered |
| FR-9 | Skill/Habilidade meter, noisy, can drop | Progress meter component, State Pattern "Dia ruim" | Covered |
| FR-10 | Effort/Esforço meter, monotonic | Progress meter component, colors reserved in DESIGN.md | Covered |
| FR-11 | Reward weighted toward effort over raw performance | Voice/Tone row ("Você praticou hoje. Isso conta."), State Pattern "Dia ruim" | Covered qualitatively — no explicit reward/points mechanic shown (PRD says "pontos, mensagens de reforço positivo, etc." — UX only shows the message half) — minor, not flagged as material gap |
| FR-12 | Day-1 baseline recorded once, never overwritten | Baseline comparison card, Flow 3 | Covered |
| FR-13 | Progress vs. baseline comparison screen | IA row "Progresso", Flow 3, edge case for early users | Covered |
| FR-14 | Color scaffold for consonance/dissonance with progressive fading, never permanent | No mention in DESIGN.md Components or EXPERIENCE.md Component/State Patterns | Gap — see Gap 4 |
| FR-15 | Resolução module (tensão→alívio) early in curriculum, mandatory vocal production | Not in IA table, not in Skill tree node description, not in Key Flows | Gap — see Gap 5 |

## Gaps and Contradictions

**Gap 1 — Contradiction: FR-3 mandatory voice in Nivelamento vs. EXPERIENCE's no-mic fallback.**
PRD FR-3 states production vocal is *obrigatória* (mandatory, not optional) in the Nivelamento (FR-1) and in the Resolução module (FR-15). EXPERIENCE.md's State Pattern "Sem microfone concedido" and Flow 1's edge case both say the nivelamento simply "segue só com reconhecimento" (proceeds recognition-only) if the mic isn't granted — i.e., the UX spine treats vocal production as skippable exactly where the PRD says it must not be. This isn't flagged as an open question in either doc; it reads as an unreconciled contradiction. (EXPERIENCE.md's own Accessibility Floor section half-notices this: "produção ativa é MUST no PRD, mas acessibilidade... precisa de rota alternativa" — but doesn't resolve it, and the state pattern for Nivelamento specifically states the fallback as if already decided.)

**Gap 2 — FR-5 "no marathon session" constraint not behaviorally represented.**
PRD FR-5 / SM-C1 explicitly says the app must not incentivize marathon sessions (no mechanics rewarding much-longer-than-standard sessions). EXPERIENCE.md's "Banido" list bans paywall interruption and aggressive streak-guilt notifications, but says nothing about capping/discouraging extended sessions or rejecting "bonus round" style mechanics. This qualitative guardrail has no behavioral counterpart to hold future design against.

**Gap 3 — FR-6 (anti-decoreba variation generation) has no UX surface at all.**
Neither DESIGN.md nor EXPERIENCE.md mentions exercise variation/non-repetition. This is a content-generation requirement more than a UI concern, but it typically surfaces behaviorally (e.g., "why does this feel different each time," progress feedback tied to pattern recognition vs. memorization). No flow, state, or copy references it. Likely fine to leave to curriculum design docs, but worth an explicit note rather than silence, since it's an FR in MVP scope (§6.1).

**Gap 4 — FR-14 (fading color scaffold) is entirely absent from both UX docs.**
This is the clearest gap of the set. FR-14 is an MVP-scope FR (§6.1) with testable consequences (fading intensity must measurably decrease across skill-tree stages). Neither DESIGN.md's Components section nor EXPERIENCE.md's Component/State Patterns describe how the color cue attaches to an exercise card, how/when it fades, or what "advanced stage, no color cue" looks like. Given "andaime com fading" was named explicitly as a concept that should show up behaviorally, this is a genuine miss — the skill-tree node states (bloqueado/disponível/completo/em reforço) don't include any per-stage visual-scaffold-intensity dimension.

**Gap 5 — FR-15 (Módulo de Resolução) is missing from the IA and Key Flows.**
The Resolução module is in MVP scope (§6.1, FR-15) and is called out as mandatory-vocal (FR-3). It doesn't appear in EXPERIENCE.md's Information Architecture table, isn't named in Skill Tree's node description, and has no Key Flow. Given it's described in the PRD as "ponte entre percepção intuitiva e composição" and positioned early in the curriculum, its complete absence from the UX spine — not even a one-line IA row — is a real coverage hole, distinct from Gap 4 in that it's a full feature/module, not just a visual treatment.

## Qualitative Framing Check (as specifically requested)

- **"Esforço pesa mais" (effort-weighted retention):** Represented behaviorally — Voice/Tone table, State Pattern "Dia ruim", Flow 2's climax all consistently avoid treating a skill dip as failure and foreground effort language. Coverage is good.
- **"Sem paredes" (adaptive progression, no hard walls):** Represented behaviorally — State Pattern "Sessão travada em reforço" and Skill tree node's explicit rule ("em reforço" never = blocked) match FR-7 closely. Coverage is good.
- **"Andaime com fading" (scaffold concept):** Not represented at all — see Gap 4 above. This is the one of the three named concepts that did not make it into either spine.

## Summary

- 10 of 15 FRs have clear, coherent surface/flow/behavior counterparts.
- 1 direct contradiction (Gap 1: FR-3 mandatory-vocal vs. no-mic fallback in Nivelamento).
- 3 FRs with no UX representation at all (FR-6 variation generation, FR-14 fading scaffold, FR-15 Resolução module).
- 1 weakly-represented guardrail (FR-5's anti-marathon-session constraint).
- Of the three qualitative concepts named in the task, two (esforço pesa mais, sem paredes) are well represented; the fading scaffold concept is not represented at all.
