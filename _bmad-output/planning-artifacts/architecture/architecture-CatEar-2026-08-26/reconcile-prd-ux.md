---
name: 'Reconcile PRD/UX vs Architecture Spine'
purpose: audit
scope: 'ARCHITECTURE-SPINE.md vs prd.md + EXPERIENCE.md'
created: '2026-09-01'
status: draft
---

# Reconciliation: PRD + EXPERIENCE.md vs ARCHITECTURE-SPINE.md

## Method

Checked every PRD FR (FR-1 to FR-15) and every EXPERIENCE.md surface, component, state, and flow against the spine's five modules (Nivelamento, Exercícios, Progressão, Áudio, Currículo) and its Deferred list. Looked specifically for silent drops, contradictions, and "quiet requirements" (tone/constraint items an AD structure tends to lose).

## FR Coverage Table

| FR | Requirement | Spine home | Verdict |
|---|---|---|---|
| FR-1 | Nivelamento com produção ativa | Nivelamento + AD-3 (Áudio) | OK |
| FR-2 | Reconhecimento intervalos/acordes/escalas, áudio real em contexto | Exercícios + AD-4 (Currículo) | OK |
| FR-3 | Produção ativa em exercícios | Exercícios + AD-3 | OK |
| FR-4 | Feedback explicativo em erro | Exercícios | Present but shallow — see Gap 6 |
| FR-5 | Sessões curtas 10-15min | Exercícios | OK (no AD needed, it's UX pacing) |
| FR-6 | Geração de variações / anti-decoreba | Exercícios + Currículo | **Gap 5 — no writer owns "recent variations" state** |
| FR-7 | Dificuldade adaptativa sem paredes | Progressão (AD-2 binds "dificuldade adaptativa") | OK |
| FR-8 | Skill tree visível | Progressão (node state) | Partial — see Gap 3 |
| FR-9/10 | Medidor Habilidade / Esforço | AD-2 explicit | OK |
| FR-11 | Recompensa ponderada por esforço | Progressão (implied, not explicit) | OK, minor — no AD names "reward calc" owner but low risk |
| FR-12/13 | Baseline Dia 1 + comparação | AD-2 explicit | OK |
| FR-14 | Andaime de cor com fading | AD-4 explicit | Partial — see Gap 4 (curve not enforced) |
| FR-15 | Módulo de Resolução | AD-4 explicit (bound) | OK |

All 15 FRs have *a* named home. No FR is silently dropped outright. The gaps below are about coherence/completeness of that home, not absence.

## EXPERIENCE.md Coverage

All 7 IA surfaces (Onboarding/Nivelamento, Home, Sessão de Exercício, Resumo de Sessão, Skill Tree, Progresso, Settings) map cleanly onto the five modules, except Settings, which has no explicit home (reasonable to assume `core/`, but the spine never says so — low-risk, not listed as a gap below since Settings content is itself an ASSUMPTION in EXPERIENCE.md).

All 4 Key Flows trace through modules without contradiction *except* where flagged below (mic-mandatory, offline).

## Gaps Found

### Gap 1 — Offline state contradicts "no backend in v1"

EXPERIENCE.md's State Patterns table says: *"Offline / sem conexão → Áudio pré-renderizado já baixado permite continuar a sessão; progresso sincroniza ao voltar a conexão."* This assumes (a) a pre-download strategy for audio assets and (b) something to sync *to* when connectivity returns.

The spine's scope is explicitly "v1 local-first sem backend," and its own Deferred list defers "Backend/conta/sincronização em nuvem" to v2. There is nothing to sync to in v1 — all data lives in local SQLite via Drift (AD-5). The spine never resolves this: it doesn't correct/soften the EXPERIENCE.md language (e.g., "sync" should just mean "nothing to sync, state is already local"), and it doesn't address the audio pre-download/bundling question at all (assets are described as bundled app assets in Structural Seed, `assets/audio/`, which actually *does* answer "offline" implicitly — samples ship with the app, no download needed — but the spine never connects this to the EXPERIENCE.md offline state or flags that "sincroniza ao voltar a conexão" is a stale/inapplicable phrase for v1).

**Recommendation:** Add a line to AD-4 or a new note clarifying that v1 audio is fully bundled (no download, no offline edge case for audio), and flag the EXPERIENCE.md "sincroniza ao voltar a conexão" phrasing as inapplicable to v1 scope (everything is already local — there's no reconnection step).

### Gap 2 — Microphone-mandatory-in-onboarding conflict never reaches the spine

EXPERIENCE.md raises this explicitly and urgently, twice:
- State Patterns: mic denial in Nivelamento/Resolução blocks progression on those two steps specifically (no fallback), while core training makes voice optional.
- Accessibility Floor: *"essa é uma barreira de acessibilidade real para quem não pode/quer usar voz, e o PRD não previu exceção; vale revisitar com o autor do PRD antes da arquitetura."*

This is a direct request from the UX artifact to the architecture step to resolve or at least register this tension. The spine does not mention it anywhere — not in AD-1/AD-3 (Áudio interface), not in Deferred, not as an open question carried forward. AD-3 defines `AudioService` purely as a technical seam (swap pitch-detection libs); it says nothing about permission-denied states or an accessibility exception path, even though this is exactly the kind of cross-module behavioral contract (Nivelamento + Áudio + a currículo-level "is voice mandatory for this exercise" flag) that belongs in an architecture spine.

**Recommendation:** Either add an AD (or an explicit Deferred entry with reason: "accessibility exception for mandatory-voice steps — open PRD question, not resolved before build") so the decision isn't silently lost between PRD and code.

### Gap 3 — Skill tree capstone placeholder has no data-model owner

EXPERIENCE.md's Component Patterns table specifies a **v1-built UI element** — the "Skill tree capstone node" — as a permanent placeholder ("em breve", never navigable) representing the post-v1 Audiação capstone. This is not deferred functionality; the node itself ships in v1.

AD-2 binds "Skill Tree (estado dos nós)" to Progressão as single-writer, but never enumerates node states. EXPERIENCE.md lists node states as: bloqueado / disponível / completo / em reforço, **plus** the capstone's own non-interactive "em breve" state, which is explicitly *not* the same as "bloqueado" (a locked node is expected to become unlockable; the capstone is permanently inert in v1). The spine's Deferred list mentions neither the capstone node nor Audiação at all, even though the PRD (§8 Roadmap) and EXPERIENCE.md both call it out by name.

**Recommendation:** Add the capstone placeholder to Deferred (reason: "Audiação capstone node is v1 UI-only, non-functional; data model for real capstone completion criteria deferred with Audiação itself"), and have AD-2 or AD-4 note that node-state enum must include this special non-interactive state so Progressão/Currículo don't each invent their own representation.

### Gap 4 — AD-4's fading "curve" is unenforced, not just present

FR-14's testable consequence is explicit: *"Em nenhum estágio avançado do skill tree a pista de cor permanece na intensidade original"* — i.e., a monotonic (or at least net-decreasing) fade across stages, not merely "a field exists per stage."

AD-4 binds "andaime de cor (FR-14) e sua curva de fading" and describes the schema as: `estágio → exercícios → tipo → referências de áudio → presença/intensidade do scaffold de cor`. This gives each stage an independent intensity value but states no invariant that the sequence of values across stages must trend downward. As written, nothing prevents a curriculum author from authoring a JSON catalog where stage 5's scaffold intensity is higher than stage 2's — which would violate FR-14 silently, at data-authoring time, with no structural or validation guard catching it. The PRD itself (§4.6 Notes) flags the exact curve/rhythm as an open design question, and open Question #1 (§9) repeats it — the spine had a specific mandate to close the loop on *how the curve is guaranteed*, and it only closes the "where does the data live" half.

**Recommendation:** AD-4 should add either a validation rule (curriculum catalog load-time check: intensity must be non-increasing across stage order) or explicitly note this is a content-authoring responsibility with no code-level guarantee — currently it's neither stated nor guarded, just implied.

### Gap 5 — FR-6 anti-repeat "recent variations" state has no declared owner

FR-6 requires that no exercise repeats identically "dentro de uma janela razoável de sessões consecutivas." This requires persisted state — which variations/exercises were recently shown — that must be readable across sessions (the window spans multiple sessions, not just one).

AD-2's single-writer list (Medidor de Habilidade, Medidor de Esforço, Skill Tree nodes, Baseline, dificuldade adaptativa) does not include "recently shown exercise variations." It's ambiguous whether this belongs to Progressão (cross-session state, fits AD-2's pattern) or Exercícios (since it's about exercise generation, arguably Exercícios' own concern) or Currículo (since it's about which catalog entries were drawn). Given AD-2 exists specifically to prevent two modules writing the same fact with different logic, this is exactly the kind of state the spine should have named a single writer for and didn't.

**Recommendation:** Add "histórico de variações recentes" (or similar) to AD-2's binds list with an explicit owner (most natural fit: Exercícios, since it consumes Currículo's catalog and needs this state to pick the next exercise — but Progressão is also defensible if it should survive app reinstall/relate to adaptive difficulty). Either choice is fine; leaving it unstated is the actual gap.

## Minor/Non-blocking Observations (not counted as gaps above)

- FR-4's explanation content (e.g., "confundiu 3ª maior com 3ª menor") is pedagogical content — arguably belongs in the Currículo catalog (AD-4) rather than hardcoded in Exercícios, but AD-4's schema list doesn't mention error-explanation text as a catalog field. Low risk, easy to fix later, not flagged as a full gap since FR-4 nominally has a home.
- Settings surface (EXPERIENCE.md IA table) has no explicit module home; reasonable to assume `core/`, but the spine never states it.
- FR-11 (reward weighting toward Esforço) has no explicit AD naming a calculation owner; implied to live in Progressão given AD-2, but not stated as directly as FR-9/10.

## Summary

No FR or EXPERIENCE.md surface is silently dropped outright — every one traces to a module. The five gaps above are about **coherence and completeness** of that mapping: two are quiet requirements the spine drops entirely (mic-mandatory accessibility conflict, offline/sync phrasing mismatch with the no-backend scope), two are structural/data-ownership gaps AD-2/AD-4 should but don't close (fade curve enforcement, recent-variations single-writer), and one is a v1-shipping UI element (skill tree capstone) missing from both the Deferred list and the node-state model.
