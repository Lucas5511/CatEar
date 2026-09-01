#!/usr/bin/env python3
"""
Verifica o pitch real de amostras de instrumento contra o nome do arquivo.
Detecta transposição (offset constante de semitons).

Uso:
    python verify_pitch.py "/caminho/AltoSax.NoVib.ff.stereo"
    python verify_pitch.py <dir> --pattern 'AltoSax\\.NoVib\\.ff\\.([A-G][b#]?[0-9])\\.'
"""
import argparse
import re
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FLAT = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}


def name_to_midi(s):
    s = s.strip()
    m = re.match(r"^([A-Ga-g][b#]?)(-?\d+)$", s)
    if not m:
        return None
    pc, octv = m.group(1), int(m.group(2))
    pc = pc[0].upper() + pc[1:]
    pc = FLAT.get(pc, pc)
    if pc not in NOTE_NAMES:
        return None
    return NOTE_NAMES.index(pc) + (octv + 1) * 12


def midi_to_name(m):
    m = int(round(m))
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def f0_autocorr(x, sr, fmin=60.0, fmax=1800.0):
    x = x - np.mean(x)
    if np.max(np.abs(x)) < 1e-4:
        return None
    corr = np.correlate(x, x, mode="full")[len(x) - 1:]
    lo, hi = int(sr / fmax), int(sr / fmin)
    seg = corr[lo:hi]
    if len(seg) < 2 or seg.max() <= 0:
        return None
    lag = lo + int(np.argmax(seg))
    if 0 < lag < len(corr) - 1:
        a, b, c = corr[lag - 1], corr[lag], corr[lag + 1]
        d = a - 2 * b + c
        if d != 0:
            sh = 0.5 * (a - c) / d
            if abs(sh) < 1:
                lag += sh
    return sr / lag if lag > 0 else None


def detect_note(path):
    y, sr = sf.read(path)
    if y.ndim > 1:
        y = y.mean(axis=1)
    y = y.astype(np.float64)
    # analisa a porção central sustentada (pula ataque/decaimento)
    n = len(y)
    core = y[int(n * 0.25):int(n * 0.70)]
    frame, hop = 4096, 1024
    f0s = []
    for i in range(0, max(1, len(core) - frame), hop):
        f = f0_autocorr(core[i:i + frame], sr)
        if f:
            f0s.append(f)
    if not f0s:
        return None, None
    f0 = float(np.median(f0s))
    midi = 69 + 12 * np.log2(f0 / 440)
    return f0, midi


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("directory")
    ap.add_argument("--pattern", default=r"\.([A-G][b#]?[0-9])\.",
                    help="regex com 1 grupo capturando a nota do nome do arquivo")
    ap.add_argument("--ext", default=".aif,.aiff,.wav,.flac,.mp3")
    args = ap.parse_args()

    exts = tuple(args.ext.split(","))
    d = Path(args.directory)
    files = sorted(f for f in d.iterdir() if f.suffix.lower() in exts)
    if not files:
        sys.exit(f"nenhum arquivo {exts} em {d}")

    rx = re.compile(args.pattern)
    rows, offsets = [], []
    for f in files:
        m = rx.search(f.name)
        if not m:
            continue
        named = name_to_midi(m.group(1))
        f0, det_midi = detect_note(f)
        if named is None or det_midi is None:
            rows.append((f.name, m.group(1), "?", "?", "?"))
            continue
        off = det_midi - named
        offsets.append(round(off))
        rows.append((f.name, midi_to_name(named), f"{f0:6.1f}Hz",
                     midi_to_name(det_midi), f"{off:+.2f}"))

    w = max(len(r[0]) for r in rows)
    print(f"{'arquivo':<{w}}  {'nome':>5}  {'f0 real':>9}  {'soa':>5}  {'offset(st)':>10}")
    print("-" * (w + 40))
    for r in rows:
        print(f"{r[0]:<{w}}  {r[1]:>5}  {r[2]:>9}  {r[3]:>5}  {r[4]:>10}")

    if offsets:
        vals, counts = np.unique(offsets, return_counts=True)
        mode = int(vals[np.argmax(counts)])
        agree = counts.max()
        print("\n--- diagnóstico ---")
        print(f"offset mais comum: {mode:+d} semitons  ({agree}/{len(offsets)} arquivos)")
        if mode == 0 and agree / len(offsets) > 0.8:
            print("=> nomes JÁ estão em pitch soante. Nada a renomear.")
        elif agree / len(offsets) > 0.8:
            direction = "abaixo" if mode < 0 else "acima"
            iv = {2: "2ªM", 3: "3ªm", 4: "3ªM", 9: "6ªM", 12: "8ª"}.get(abs(mode), f"{abs(mode)}st")
            print(f"=> nomes estão em pitch ESCRITO. Soam {abs(mode)} st {direction} ({iv}).")
            print(f"   Renomear cada arquivo pela nota soante (somar {mode:+d} ao nome).")
        else:
            print("=> offsets inconsistentes — inspecionar arquivo a arquivo (ataque ruidoso? oitava errada?).")


if __name__ == "__main__":
    main()
