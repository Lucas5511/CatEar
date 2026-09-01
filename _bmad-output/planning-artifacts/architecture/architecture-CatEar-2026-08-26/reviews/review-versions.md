# Review — Stack Versions & Named Technology Decisions (ARCHITECTURE-SPINE.md)

Date checked: 2026-09-01 (via live web search / pub.dev / docs.flutter.dev)

## Verdict

**Mostly sound, with one real inaccuracy and several unverified "confirm later" placeholders that are honest but do leave claims unconfirmed.** The spine already flags version pinning as deferred (line 129), which is the right posture — the issue found here is Flutter's own line saying "stable, mai/2026" is stale relative to what's actually current now.

## Findings

### 1. Flutter — spine says `3.44.0 (stable, mai/2026)` — OUTDATED, not wrong-at-the-time
- Confirmed 3.44.0 was a real stable release, dated ~May 18, 2026, with hotfixes through 3.44.6/3.44.7 (github.com/flutter/flutter issues #186410, #189142, #187786, #187098).
- However, as of now (Sept 2026), Flutter has moved past this: docs.flutter.dev's own release-notes page banner states **"Flutter 3.47 is here"** — i.e. current stable is 3.47.x, not 3.44.0.
- **Flag**: the spine's stated version is ~2 releases behind current stable. Not a fabrication (3.44.0 genuinely existed), but it will be stale by the time implementation starts. Given the spine itself defers exact pinning to "start of implementation" (line 129), this is low-severity — but the specific version number in the Stack table row should either be removed/generalized or re-checked immediately before coding, since it currently reads as a confirmed fact rather than a snapshot.

### 2. Riverpod — spine says "atual estável — confirmar versão exata"
- Confirmed current: **riverpod 3.4.2** (flutter_riverpod tracks same major/minor line), published ~34 days before check.
- Package exists, fits stated purpose (state management / codegen), actively maintained.
- Spine's hedge is appropriate and consistent with what's found — no false claim, just correctly deferred.

### 3. Drift — spine says "atual estável — SQL tipado sobre SQLite"
- Confirmed current: **drift 2.34.3**, published ~35 days before check.
- Still exists, still fits purpose (typed SQL/reactive persistence over SQLite for Dart/Flutter). Description matches ("reactive, typesafe persistence library").
- No discrepancy.

### 4. record — spine says "atual estável — captura de áudio/voz"
- Confirmed current: **record 7.1.1**, published ~2 months before check.
- Package exists, purpose matches (microphone capture to file/stream, multi-codec).
- No discrepancy.

### 5. just_audio — spine says "atual estável — reprodução de amostras reais"
- Confirmed current: **just_audio 0.10.6**, published ~2 months before check.
- Strong health signals: 4.1k likes, 150 pub points, 1.03M weekly downloads, Flutter Favorite, verified publisher (ryanheise.com). Purpose matches (audio playback).
- No discrepancy — this is the healthiest dependency in the stack.

### 6. Pitch detection library — spine explicitly leaves this **unfixed** (Deferred section), calling `pitch_detector_dart` and `flutter_pitch_detection` "niche," not "abandoned"
- Checked `pitch_detector_dart`: latest version 0.0.7, published **~2 years ago**, 25 likes, 160 pub points. This is consistent with "niche" — it is not actively developed, though not explicitly marked discontinued/abandoned on pub.dev either. The spine's characterization ("nenhuma opção madura padrão de mercado," "de nicho") is accurate and appropriately cautious — it does NOT claim abandonment, which matches what was found (no formal abandonment flag, but stale/low-engagement).
- Checked `flutter_pitch_detection`: last published ~May 2025 (per earlier search), Android-only (no iOS support per package description) — this is a meaningful additional caveat not mentioned in the spine. Worth noting for whoever runs the deferred spike: this specific candidate lacks iOS support, which matters for a mobile app that presumably targets both platforms.
- No false claims here; the spine correctly avoids asserting a specific pitch library "still exists and is well-maintained" and instead defers the decision — this is the right call given the actual state of the ecosystem.

## Summary Table

| Item | Spine claim | Verified current state | Status |
|---|---|---|---|
| Flutter | 3.44.0 stable, mai/2026 | Was real; current stable now 3.47.x | Stale — update or generalize before coding |
| Riverpod | "atual estável" (unpinned) | 3.4.2, active | Accurate hedge, confirmed healthy |
| Drift | "atual estável" (unpinned) | 2.34.3, active | Accurate hedge, confirmed healthy |
| record | "atual estável" (unpinned) | 7.1.1, active | Accurate hedge, confirmed healthy |
| just_audio | "atual estável" (unpinned) | 0.10.6, active, Flutter Favorite | Accurate hedge, confirmed healthy |
| pitch detection | correctly deferred, called "niche" | pitch_detector_dart stale (2yr, 0.0.7); flutter_pitch_detection Android-only | Accurate; add iOS-gap caveat |

## Recommendations
1. Either drop the specific "3.44.0 (stable, mai/2026)" figure from the Stack table and replace with the same "atual estável — confirmar no início da implementação" hedge used for the other four rows (for consistency and to avoid a stale fact reading as current), or explicitly timestamp it as "confirmed 2026-09-01: current stable is 3.47.x" if the intent is to track it.
2. When the pitch-detection spike (Deferred section) is picked up, explicitly check platform coverage (iOS vs Android) for each candidate — `flutter_pitch_detection` is Android-only, which is a hard blocker if iOS is in scope for v1 or v2.
3. No changes needed to AD-1 through AD-5 or the module architecture itself — this review only covered the Stack table and named-technology claims, per scope.
