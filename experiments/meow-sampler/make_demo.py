#!/usr/bin/env python3
"""
Monta demos audíveis a partir das amostras geradas por render_meows.py:
intervalos, acordes e uma escala — para você ouvir o resultado sem abrir o Flutter.

Uso:
    python make_demo.py                 # raiz c4
    python make_demo.py --root a3
    python make_demo.py --samples out/meow --out out/demos

Saída: out/demos/demo_*.wav
"""
import argparse
import re
from pathlib import Path

import numpy as np
import soundfile as sf

NOTE_NAMES = ["c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"]
PREFIX = "meow_"


def name_to_midi(s: str) -> int:
    m = re.match(r"^([a-g]s?)(-?\d+)$", s.strip().lower())
    if not m:
        raise ValueError(f"nota inválida: {s!r}")
    return NOTE_NAMES.index(m.group(1)) + (int(m.group(2)) + 1) * 12


def midi_to_name(m: int) -> str:
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def load_note(sample_dir: Path, midi: int):
    p = sample_dir / f"{PREFIX}{midi_to_name(midi)}.wav"
    if not p.exists():
        raise SystemExit(f"faltando: {p}  (precisa da nota {midi_to_name(midi)} no set)")
    y, sr = sf.read(p)
    if y.ndim > 1:
        y = y.mean(axis=1)
    return y.astype(np.float32), sr


def pad_to(y, n):
    return y[:n] if len(y) >= n else np.concatenate([y, np.zeros(n - len(y), dtype=np.float32)])


def seq(samples, sr, gap=0.18):
    g = np.zeros(int(gap * sr), dtype=np.float32)
    parts = []
    for y in samples:
        parts += [y, g]
    return np.concatenate(parts)


def chord(samples):
    n = max(len(y) for y in samples)
    mix = sum(pad_to(y, n) for y in samples)
    return (mix / (np.max(np.abs(mix)) or 1.0) * 0.9).astype(np.float32)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--samples", default="out/meow")
    ap.add_argument("--out", default="out/demos")
    ap.add_argument("--root", default="c4")
    ap.add_argument("--prefix", default="meow_", help="prefixo dos arquivos (ex: sax_, flute_)")
    args = ap.parse_args()

    global PREFIX
    PREFIX = args.prefix
    sample_dir = Path(args.samples)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    root = name_to_midi(args.root)
    _, sr = load_note(sample_dir, root)

    def n(semi):
        return load_note(sample_dir, root + semi)[0]

    demos = {
        "intervalo_terca_maior": seq([n(0), n(4)], sr),
        "intervalo_terca_menor": seq([n(0), n(3)], sr),
        "intervalo_quinta_justa": seq([n(0), n(7)], sr),
        "intervalo_oitava": seq([n(0), n(12)], sr),
        "acorde_maior": chord([n(0), n(4), n(7)]),
        "acorde_menor": chord([n(0), n(3), n(7)]),
        "acorde_maior_arpejo": seq([n(0), n(4), n(7), n(12)], sr, gap=0.10),
        "escala_maior": seq([n(s) for s in (0, 2, 4, 5, 7, 9, 11, 12)], sr, gap=0.12),
        "cadencia_resolucao": seq([chord([n(5), n(9), n(12)]), chord([n(7), n(11), n(14)]), chord([n(0), n(4), n(7)])], sr, gap=0.05),
    }

    for name, audio in demos.items():
        p = out / f"demo_{name}.wav"
        sf.write(p, audio, sr, subtype="PCM_16")
        print(f"  {p}")

    print(f"\n{len(demos)} demos -> {out}/   (raiz {args.root})")


if __name__ == "__main__":
    main()
