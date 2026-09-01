#!/usr/bin/env python3
"""
Gera um "miado" sintético (glissando + harmônicos + vibrato) para testar a
pipeline sem precisar baixar nada. Útil também como sinal de teste conhecido
para o spike 3.1 (você sabe a frequência exata).

Uso:
    python synth_meow.py                       # ~E5, glissando leve, 1.2 s
    python synth_meow.py --hz 523 --out c5.wav # tom fixo em C5 (sem glissando)
    python synth_meow.py --hz 440 --glide 0    # A4 puro-ish, para checar o detector
"""
import argparse
import numpy as np
import soundfile as sf


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="synth_meow.wav")
    ap.add_argument("--hz", type=float, default=660.0, help="frequência central (Hz)")
    ap.add_argument("--dur", type=float, default=1.2)
    ap.add_argument("--sr", type=int, default=44100)
    ap.add_argument("--glide", type=float, default=0.6, help="amplitude do glissando em semitons (0 = tom fixo)")
    ap.add_argument("--vibrato", type=float, default=0.25, help="profundidade do vibrato em semitons")
    args = ap.parse_args()

    t = np.linspace(0, args.dur, int(args.sr * args.dur), endpoint=False)
    # contorno de pitch: sobe e desce (miado) + vibrato
    glide = args.glide * np.sin(np.pi * t / args.dur)          # 0 -> pico -> 0
    vib = args.vibrato * np.sin(2 * np.pi * 5.5 * t)
    f = args.hz * 2 ** ((glide + vib) / 12)
    phase = 2 * np.pi * np.cumsum(f) / args.sr

    # harmônicos com decaimento (voz/miado tem formante, isto é uma aproximação grosseira)
    y = sum(amp * np.sin(k * phase) for k, amp in [(1, 1.0), (2, 0.5), (3, 0.33), (4, 0.15), (5, 0.08)])

    # envelope: ataque rápido, sustain, decaimento
    env = np.ones_like(t)
    a, d = int(0.04 * args.sr), int(0.15 * args.sr)
    env[:a] = np.linspace(0, 1, a)
    env[-d:] = np.linspace(1, 0, d)
    y = (y * env).astype(np.float32)
    y *= 0.9 / (np.max(np.abs(y)) or 1.0)

    sf.write(args.out, y, args.sr, subtype="PCM_16")
    print(f"{args.out}  ({args.dur}s @ {args.sr} Hz, centro {args.hz:.1f} Hz)")


if __name__ == "__main__":
    main()
