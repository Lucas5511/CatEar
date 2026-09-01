#!/usr/bin/env python3
"""
Pega UM miado e gera um conjunto cromático de amostras afinadas (um WAV por nota).

Uso típico:
    python render_meows.py kitty_meow.wav
    python render_meows.py kitty_meow.wav --low c3 --high c5
    python render_meows.py kitty_meow.wav --start 0.4 --end 1.1

Saída: out/meow/meow_<nota>.wav  (ex: meow_c4.wav, meow_cs4.wav)

Sem librosa. Só numpy + soundfile. O pitch-shift usa o binário `rubberband`
(preserva formante); sem ele, cai num resample simples (fica "chipmunk", mas roda).

  Debian/Ubuntu:  sudo apt install rubberband-cli libsndfile1
  macOS:          brew install rubberband
"""
import argparse
import re
from pathlib import Path

import numpy as np
import soundfile as sf

NOTE_NAMES = ["c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"]


def midi_to_name(m: int) -> str:
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def name_to_midi(s: str) -> int:
    m = re.match(r"^([a-g]s?)(-?\d+)$", s.strip().lower())
    if not m:
        raise ValueError(f"nota inválida: {s!r} (use algo como c3, cs4, ds5)")
    return NOTE_NAMES.index(m.group(1)) + (int(m.group(2)) + 1) * 12


def midi_to_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def hz_to_midi(hz: float) -> float:
    return 69 + 12 * np.log2(hz / 440)


# ---------- detecção de pitch (autocorrelação, numpy puro) ----------

def f0_of_frame(x, sr, fmin=150.0, fmax=1600.0):
    x = x - np.mean(x)
    if np.max(np.abs(x)) < 1e-4:          # silêncio
        return None
    corr = np.correlate(x, x, mode="full")[len(x) - 1:]
    lag_min, lag_max = int(sr / fmax), int(sr / fmin)
    seg = corr[lag_min:lag_max]
    if len(seg) < 2 or seg.max() <= 0:
        return None
    lag = lag_min + int(np.argmax(seg))
    if 0 < lag < len(corr) - 1:           # interpolação parabólica
        a, b, c = corr[lag - 1], corr[lag], corr[lag + 1]
        denom = a - 2 * b + c
        if denom != 0:
            shift = 0.5 * (a - c) / denom
            if abs(shift) < 1:
                lag = lag + shift
    return sr / lag if lag > 0 else None


def track_f0(y, sr, frame=2048, hop=512):
    f0s, times = [], []
    for i in range(0, max(1, len(y) - frame), hop):
        f = f0_of_frame(y[i:i + frame], sr)
        f0s.append(f if f else np.nan)
        times.append((i + frame / 2) / sr)
    return np.array(f0s, dtype=float), np.array(times, dtype=float)


def detect_base_midi(y, sr):
    f0, _ = track_f0(y, sr)
    f0 = f0[~np.isnan(f0)]
    if len(f0) == 0:
        raise RuntimeError("não consegui detectar o pitch base — passe --start/--end para um trecho com nota clara")
    med = float(np.median(f0))
    return med, hz_to_midi(med)


def pick_stable_segment(y, sr, min_dur=0.30):
    """Maior trecho onde o pitch fica dentro de +-80 cents da mediana."""
    f0, times = track_f0(y, sr)
    valid = ~np.isnan(f0)
    if valid.sum() < 3:
        return y
    med = np.nanmedian(f0)
    with np.errstate(invalid="ignore", divide="ignore"):
        cents = 1200 * np.log2(np.where(f0 > 0, f0, np.nan) / med)
    stable = valid & (f0 > 0) & (np.abs(cents) < 80)

    best_i = best_len = cur_i = cur_len = 0
    for i, s in enumerate(stable):
        if s:
            cur_i = cur_i if cur_len else i
            cur_len += 1
            if cur_len > best_len:
                best_len, best_i = cur_len, cur_i
        else:
            cur_len = 0

    if best_len < 2:
        return y
    t0, t1 = times[best_i], times[min(best_i + best_len, len(times) - 1)]
    if t1 - t0 < min_dur:
        return y
    return y[int(t0 * sr):int(t1 * sr)]


# ---------- pitch shift ----------

def pitch_shift(y, sr, semitones):
    try:
        import pyrubberband as pyrb
        return pyrb.pitch_shift(y, sr, semitones, rbargs={"--formant": ""})
    except Exception:
        ratio = 2 ** (semitones / 12)          # resample simples (muda duração)
        n = max(1, int(len(y) / ratio))
        idx = np.linspace(0, len(y) - 1, n)
        return np.interp(idx, np.arange(len(y)), y).astype(np.float32)


def stretch_to(y, sr, target_dur):
    """Estica o áudio para target_dur segundos sem mudar o pitch (rubberband)."""
    cur = len(y) / sr
    if abs(cur - target_dur) < 0.02:
        return y
    try:
        import pyrubberband as pyrb
        return pyrb.time_stretch(y, sr, cur / target_dur, rbargs={"--formant": ""})
    except Exception:
        raise SystemExit(
            "--dur precisa do binário `rubberband` (sudo apt install rubberband-cli).\n"
            "Sem ele o esticamento mudaria o pitch."
        )


def apply_env(y, sr, fade=0.015):
    n = int(fade * sr)
    y = np.asarray(y, dtype=np.float32).copy()
    if len(y) > 2 * n and n > 0:
        y[:n] *= np.linspace(0, 1, n)
        y[-n:] *= np.linspace(1, 0, n)
    peak = float(np.max(np.abs(y))) or 1.0
    return y * (0.9 / peak)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="miado de origem (WAV/FLAC/OGG — MP3 não; converta antes)")
    ap.add_argument("-o", "--outdir", default="out/meow")
    ap.add_argument("--low", help="nota mais grave (ex: c3). padrão: base -12 st")
    ap.add_argument("--high", help="nota mais aguda (ex: c5). padrão: base +12 st")
    ap.add_argument("--start", type=float, help="segundo inicial do trecho a usar")
    ap.add_argument("--end", type=float, help="segundo final do trecho a usar")
    ap.add_argument("--no-auto-trim", action="store_true", help="não recortar o trecho estável automaticamente")
    ap.add_argument("--dur", type=float, help="esticar cada nota para esta duração em segundos (ex: 2.5). precisa de rubberband")
    args = ap.parse_args()

    y, sr = sf.read(args.source)
    if y.ndim > 1:
        y = y.mean(axis=1)
    y = y.astype(np.float32)

    if args.start is not None or args.end is not None:
        s0 = int((args.start or 0) * sr)
        s1 = int(args.end * sr) if args.end else len(y)
        y = y[s0:s1]
    elif not args.no_auto_trim:
        y = pick_stable_segment(y, sr)

    base_hz, base_midi = detect_base_midi(y, sr)
    base_round = int(round(base_midi))
    print(f"trecho usado: {len(y)/sr:.2f} s @ {sr} Hz")
    print(f"pitch base:   {base_hz:.1f} Hz  (~{midi_to_name(base_round)}, midi {base_midi:.2f})")

    if args.dur:
        y = stretch_to(y, sr, args.dur)
        print(f"esticado para: {len(y)/sr:.2f} s")
    print()

    lo = name_to_midi(args.low) if args.low else base_round - 12
    hi = name_to_midi(args.high) if args.high else base_round + 12

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    for old in outdir.glob("meow_*.wav"):      # limpa range anterior
        old.unlink()

    for m in range(lo, hi + 1):
        semis = m - base_midi
        out = apply_env(pitch_shift(y, sr, semis), sr)
        sf.write(outdir / f"meow_{midi_to_name(m)}.wav", out, sr, subtype="PCM_16")
        warn = "   <- shift > 1 oitava, qualidade cai" if abs(semis) > 12 else ""
        print(f"  {midi_to_name(m):4s}  {midi_to_hz(m):6.1f} Hz  ({semis:+5.1f} st){warn}")

    print(f"\n{hi - lo + 1} amostras -> {outdir}/")


if __name__ == "__main__":
    main()
