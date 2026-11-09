#!/usr/bin/env python3
"""Synthesizes the duck voices of Quacktaclysm (original sounds, no third-party samples).

Standard library only. A raspy harmonic source with a gliding pitch goes through three nasal
formant resonators, so each "quack" is generated, not recorded. Writes 16-bit mono WAV files to
game/frontend/audio/sfx/ducks/. Run again after changing a voice:
    python3 tools/gen_quacks.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "game" / "frontend" / "audio" / "sfx" / "ducks"

# Nasal "a" formants of a duck call: (centre Hz, bandwidth Hz, gain).
FORMANTS = [(950.0, 260.0, 1.0), (1650.0, 320.0, 0.75), (2900.0, 500.0, 0.35)]


def resonator(signal, freq, bw, gain):
    """Two-pole band-pass resonator (classic formant filter)."""
    r = math.exp(-math.pi * bw / RATE)
    c = 2.0 * r * math.cos(2.0 * math.pi * freq / RATE)
    out, y1, y2 = [], 0.0, 0.0
    norm = (1.0 - r * r) * 0.5
    for x in signal:
        y = norm * x + c * y1 - r * r * y2
        y2, y1 = y1, y
        out.append(y * gain)
    return out


def quack(duration, f_start, f_peak, f_end, rasp=0.5, rasp_hz=45.0, noise=0.08, harmonics=24,
          attack=0.012, release=0.06, seed=0):
    rng = random.Random(seed)
    n = int(duration * RATE)
    src, phase, rasp_phase = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        # Pitch: quick rise to the peak, then a glide down (the "ack" of the quack).
        if t < 0.18:
            f0 = f_start + (f_peak - f_start) * (t / 0.18)
        else:
            f0 = f_peak + (f_end - f_peak) * ((t - 0.18) / 0.82) ** 1.3
        f0 *= 1.0 + 0.012 * math.sin(2.0 * math.pi * 7.0 * i / RATE)
        phase += f0 / RATE
        rasp_phase += rasp_hz / RATE
        s = 0.0
        for h in range(1, harmonics + 1):
            if f0 * h > RATE * 0.45:
                break
            s += math.sin(2.0 * math.pi * h * phase) / h
        # Rasp: amplitude flutter that gives the duck its buzz.
        s *= 1.0 - rasp * (0.5 + 0.5 * math.sin(2.0 * math.pi * rasp_phase))
        s += noise * (rng.random() * 2.0 - 1.0)
        src.append(s)
    mixed = [0.0] * n
    for freq, bw, gain in FORMANTS:
        for i, y in enumerate(resonator(src, freq, bw, gain)):
            mixed[i] += y
    a, rl = int(attack * RATE), int(release * RATE)
    for i in range(n):
        env = min(1.0, i / max(a, 1)) * min(1.0, (n - i) / max(rl, 1))
        mixed[i] *= env
    peak = max(abs(v) for v in mixed) or 1.0
    return [v / peak * 0.85 for v in mixed]


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples))
    print("wrote", OUT / name)


VOICES = {
    # Ordinary ducks (enemies) when they attack.
    "quack_1.wav": dict(duration=0.20, f_start=330, f_peak=440, f_end=300, seed=1),
    "quack_2.wav": dict(duration=0.17, f_start=360, f_peak=480, f_end=320, rasp=0.6, seed=2),
    "quack_3.wav": dict(duration=0.24, f_start=300, f_peak=410, f_end=260, rasp=0.45, seed=3),
    # The hero: brighter and shorter.
    "quack_hero.wav": dict(duration=0.15, f_start=420, f_peak=560, f_end=430, rasp=0.35, seed=4),
    # Hurt: a sharp, high squawk.
    "quack_hurt.wav": dict(duration=0.13, f_start=560, f_peak=760, f_end=520, rasp=0.7, rasp_hz=60, noise=0.15, seed=5),
    # Death: a long falling quack that runs out of air.
    "quack_die.wav": dict(duration=0.65, f_start=480, f_peak=560, f_end=150, rasp=0.65, rasp_hz=35, noise=0.12, release=0.25, seed=6),
    # Bosses: big, low and very raspy.
    "quack_boss.wav": dict(duration=0.42, f_start=170, f_peak=240, f_end=140, rasp=0.75, rasp_hz=28, noise=0.1, harmonics=40, seed=7),
    "quack_boss_die.wav": dict(duration=1.1, f_start=230, f_peak=280, f_end=80, rasp=0.8, rasp_hz=22, noise=0.14, harmonics=40, release=0.45, seed=8),
}


if __name__ == "__main__":
    for file_name, params in VOICES.items():
        write(file_name, quack(**params))
