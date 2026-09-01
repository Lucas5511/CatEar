---
story: "3.1 — Spike de detecção de pitch (gate de risco)"
status: in-progress
phase: "pesquisa concluída — protótipo em dispositivo pendente (parte do usuário)"
created: 2026-09-01
---

# Spike 3.1 — Detecção de pitch para produção ativa

## Objetivo

Decidir uma abordagem de detecção de pitch que funcione em **iOS + Android** para avaliar
voz cantada pós-gravação (`AudioService.evaluatePitch()` → `Future<PitchEvaluationResult>`,
AD-3 — resultado único, não stream), com resolução em cents suficiente para a tolerância
da FR-3.

## Requisitos do contrato (da arquitetura)

| Restrição | Origem | Implicação |
|---|---|---|
| Resultado único pós-gravação, não stream | AD-3 | Não precisamos de análise em tempo real; analisamos 1 buffer depois do "soltar" |
| Voz monofônica (uma nota por vez) | FR-3, EXPERIENCE.md | Algoritmos monofônicos (YIN/MPM/autocorrelação) bastam; nada de polifonia |
| Push-to-talk, ~0,3–5 s de áudio | Story 1.7 / 3.2 | Janela de análise curta e delimitada |
| iOS + Android com paridade | NFR-4 | A solução tem que ser a mesma nas duas plataformas |
| Baixo custo de manutenção | Projeto hobby solo | Evitar duas bases nativas; evitar dependência abandonada como caminho crítico |
| `record` 7.1.1 já fixado para captura | Arquitetura, Stack | Ele entrega PCM `Float32`/`Int16` nas duas plataformas — a detecção opera sobre esse buffer |

## Levantamento de opções (pesquisa — 2026-09-01)

| Opção | O que é | iOS | Android | API | Manutenção | Veredito |
|---|---|---|---|---|---|---|
| **`pitch_detector_dart` 0.0.7** | Dart puro, porta do YIN do TarsosDSP | ✅ (Dart puro) | ✅ | one-shot sobre buffer | **Sem publicação há ~2 anos** — algoritmo estável, código pequeno | **Vendorizar/forkar** — melhor encaixe |
| **`fftea`** (+ autocorrelação/HPS própria) | Biblioteca FFT Dart puro, mantida (última ~2024) | ✅ | ✅ | você constrói o pitch por cima | Ativa o suficiente | **Fallback** se o YIN não der precisão |
| `flutter_detect_pitch` 0.0.1+1 | Plugin nativo (AVAudioEngine+Accelerate / AudioRecord) | ✅ | ⚠️ "detecção básica no Android" | **stream a cada ~100 ms** | 0.0.1, uploader não verificado, ~2 downloads, sem conversão para nota | **Rejeitar** — imaturo e API errada (stream, conflita com AD-3) |
| `flutter_pitch_detection` | Wrapper de TarsosDSP (Java) | ❌ | ✅ | stream | — | **Rejeitar** — sem iOS, quebra paridade |
| `flutter_fft` | Platform channel, FFT tempo real | ❌ Android-only | ✅ | stream | Focado em afinador de guitarra | **Rejeitar** — sem iOS |
| **`aubio` via `dart:ffi`** | Lib C madura (YIN/YINFFT), a melhor precisão | ✅ (compilar) | ✅ (compilar) | one-shot | `aubio` estável mas antiga; toolchain de build por plataforma | **Rejeitar para v1** — setup de FFI + cross-compile é peso demais para hobby solo; reconsiderar se YIN e fftea falharem |
| Platform channels próprios (AVAudioEngine + TarsosDSP/Oboe) | Duas implementações nativas | ✅ | ✅ | livre | Você mantém as duas | **Rejeitar para v1** — dobra a superfície de manutenção |

## Decisão recomendada

**Opção 1 — YIN em Dart puro, vendorizado.** Copiar/forkar `pitch_detector_dart` (ou
reimplementar YIN com interpolação parabólica, ~150–250 linhas) para dentro de
`lib/audio/`. Motivos:

- **Paridade grátis:** é só matemática sobre um `Float32List` — roda idêntico em iOS e Android, sem código nativo, sem cross-compile.
- **Encaixe exato no contrato:** análise única pós-gravação é o caso de uso natural do YIN; não precisamos de nada em tempo real.
- **Manutenção sob controle:** o pacote estar abandonado deixa de ser risco quando o código vive no nosso repo — o algoritmo YIN não "expira".
- **`record` já resolve a captura** nas duas plataformas; o YIN só consome o buffer que ele entrega.

**Fallback documentado:** se o YIN não atingir a precisão-alvo com voz cantada real
(vibrato, ar, oitava errada por detecção de sub-harmônico), trocar para
**`fftea` + autocorrelação/HPS** com detecção de oitava por consistência harmônica —
também Dart puro, também paridade grátis. `aubio`/FFI só entra se **ambos** falharem,
e aí a Story 3.1 dispara a contingência do PRD (Open Question 7 → **v1 sem produção ativa**).

## Nota sobre resolução em cents

- Em A3 (220 Hz), 1 cent ≈ 0,127 Hz. YIN com interpolação parabólica resolve < 5 cents num tom estável — folga larga para a tolerância provável da FR-3 (±50 cents para iniciantes).
- O problema real é **voz**, não resolução: vibrato de ±20–50 cents a ~5–6 Hz, ataque/decaimento instáveis, e detecção de oitava errada. Mitigação: descartar os primeiros/últimos ~150 ms do buffer e tomar a **mediana** do f0 na porção sustentada; validar oitava pela energia dos harmônicos.

## Protótipo — plano de execução (parte do usuário, ~1 semana time-boxed)

App Flutter descartável:

1. `record` captura 1–2 s ao soltar o botão (push-to-talk).
2. YIN vendorizado processa o buffer → f0 → nota + cents (descartar bordas, mediana da porção sustentada).
3. Tela mostra: nota detectada, desvio em cents, f0 bruto.

**Matriz de teste:**

| Eixo | Valores |
|---|---|
| Pessoas | 3–4 (vozes graves e agudas) |
| Alvos cantados | C3, E3, G3, C4 (e equivalentes na oitava de cada pessoa) |
| Ambiente | silêncio + ruído de fundo moderado (TV/conversa) |
| Dispositivos | ≥ 1 iPhone real **e** ≥ 1 Android real |

**Critérios de aprovação (go/no-go):**

- Erro absoluto **mediano** < 25 cents em notas sustentadas, no silêncio, nas duas plataformas.
- Ainda utilizável (erro mediano < 50 cents) com ruído moderado.
- Sem erro sistemático de oitava.
- Latência de análise < 300 ms para um buffer de 2 s.
- **Se não passar:** tentar o fallback `fftea`. Se o fallback também não passar dentro do time-box → contingência do PRD (v1 sem produção ativa).

## Estado deste spike

- [x] Levantamento de opções e decisão de abordagem (este documento)
- [x] Fallback definido
- [x] Plano de protótipo e critérios go/no-go
- [ ] Protótipo rodando em iPhone real — **pendente (usuário)**
- [ ] Protótipo rodando em Android real — **pendente (usuário)**
- [ ] Medições preenchidas e veredito final registrado abaixo

## Veredito final

_(preencher após o protótipo em dispositivo)_

| | |
|---|---|
| Abordagem aprovada | — |
| Erro mediano iOS / Android (silêncio) | — / — |
| Erro mediano com ruído | — |
| Tolerância da FR-3 adotada (cents) | — |
| Decisão | — |
