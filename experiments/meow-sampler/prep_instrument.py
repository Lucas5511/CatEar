#!/usr/bin/env python3
"""
Prepara uma pasta de samples de instrumento para os exercícios:
mono, normalizado, duração alvo (recorta com fade ou estica), nomes canônicos.

Uso:
    python prep_instrument.py "/home/clapthesun/Downloads/AltoSax.NoVib.ff.stereo" \\
        --name sax --dur 2.5

Saída: out/<name>/<name>_<nota>.wav   (ex: out/sax/sax_c4.wav)
"""
import argparse
import re
from pathlib import Path

import numpy as np
import soundfile as sf

NOTE_NAMES = ["c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"]
FLAT_IN = {"db": "cs", "eb": "ds", "gb": "fs", "ab": "gs", "bb": "as"}


def parse_note(token):
    m = re.match(r"^([A-Ga-g][b#]?)(-?\d+)$", token)
    if not m:
        return None
    pc, octv = m.group(1).lower().replace("#", "s"), int(m.group(2))
    pc = FLAT_IN.get(pc, pc)
    if pc not in NOTE_NAMES:
        return None
    return f"{pc}{octv}"


def shape(y, sr, target_dur, fade=0.03):
    cur = len(y) / sr
    if target_dur and cur > target_dur + 0.05:
        y = y[:int(target_dur * sr)]                       # recorta
    elif target_dur and cur < target_dur - 0.05:
        try:
            import pyrubberband as pyrb
            y = pyrb.time_stretch(y, sr, cur / target_dur)  # estica
        except Exception:
            pass
    n = int(fade * sr)
    y = np.asarray(y, dtype=np.float32).copy()
    if len(y) > 2 * n and n > 0:
        y[:n] *= np.linspace(0, 1, n)
        y[-n:] *= np.linspace(1, 0, n)
    peak = float(np.max(np.abs(y))) or 1.0
    return y * (0.9 / peak)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("directory")
    ap.add_argument("--name", required=True, help="prefixo/pasta de saída (ex: sax, flute)")
    ap.add_argument("--pattern", default=r"[._]([A-G][b#]?[0-9])[._]",
                    help="regex com 1 grupo capturando a nota no nome do arquivo")
    ap.add_argument("--dur", type=float, default=2.5, help="duração alvo em s (0 = manter original)")
    ap.add_argument("--ext", default=".aif,.aiff,.wav,.flac,.mp3")
    ap.add_argument("--outdir", default="out")
    args = ap.parse_args()

    exts = tuple(args.ext.split(","))
    src = Path(args.directory)
    rx = re.compile(args.pattern)
    outdir = Path(args.outdir) / args.name
    outdir.mkdir(parents=True, exist_ok=True)
    for old in outdir.glob(f"{args.name}_*.wav"):
        old.unlink()

    done = []
    for f in sorted(x for x in src.iterdir() if x.suffix.lower() in exts):
        m = rx.search(f.name)
        if not m:
            continue
        note = parse_note(m.group(1))
        if not note:
            continue
        y, sr = sf.read(f)
        if y.ndim > 1:
            y = y.mean(axis=1)
        y = shape(y.astype(np.float32), sr, args.dur if args.dur > 0 else None)
        sf.write(outdir / f"{args.name}_{note}.wav", y, sr, subtype="PCM_16")
        done.append(note)

    print(f"{len(done)} notas -> {outdir}/   ({done[0]}..{done[-1]})" if done else "nenhuma nota casou o pattern")


if __name__ == "__main__":
    main()
