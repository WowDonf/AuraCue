#!/usr/bin/env python3
"""Generate CueSense's bundled cue sounds.

Synthesizes a small palette of short, perceptually-distinct tones and writes
them as .mp3 into ../Sounds. Stdlib only for synthesis (wave + math); ffmpeg
on PATH is required for the WAV -> MP3 step (WoW's PlaySoundFile takes .mp3 or
.ogg, not .wav; mp3 via libmp3lame is the most broadly available encoder).

The point of the palette is *distinctness*: a blind / low-vision player keys
different auras to different tones, so each one must be easy to tell apart by
ear — different pitch contour (rising / falling / flat), count (single /
double / triple), and register (high / low).

Re-run after editing the TONES table:  python3 tools/make_sounds.py
"""

import math
import os
import shutil
import struct
import subprocess
import tempfile
import wave

RATE = 44100
AMP = 0.55          # peak amplitude (0..1); leaves headroom, no clipping

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "Sounds"))

# Each tone is a list of notes: (frequency_hz, duration_s, gap_after_s).
# A frequency of 0 means a rest. Two-element notes default the gap to 0.
TONES = {
    "rise":   [(523.25, 0.10, 0.02), (659.25, 0.14, 0.0)],   # C5 -> E5, ascending
    "fall":   [(659.25, 0.10, 0.02), (523.25, 0.16, 0.0)],   # E5 -> C5, descending
    "ping":   [(880.00, 0.16, 0.0)],                          # single clear high
    "beep":   [(440.00, 0.16, 0.0)],                          # single mid
    "double": [(880.00, 0.07, 0.05), (880.00, 0.07, 0.0)],    # two quick highs
    "triple": [(659.25, 0.06, 0.05), (659.25, 0.06, 0.05), (659.25, 0.06, 0.0)],
    "chirp":  [("sweep", 600.0, 1200.0, 0.18)],               # upward glissando
    "thud":   [(180.00, 0.16, 0.0)],                          # low short
}


def envelope(i, n):
    """Attack/decay envelope to avoid clicks. ~4ms attack, smooth release."""
    attack = max(1, int(0.004 * RATE))
    if i < attack:
        return i / attack
    # Exponential-ish decay over the remainder.
    t = (i - attack) / max(1, (n - attack))
    return (1.0 - t) ** 1.5


def render_note(note):
    samples = []
    if note[0] == "sweep":
        _, f0, f1, dur = note
        n = int(dur * RATE)
        phase = 0.0
        for i in range(n):
            f = f0 + (f1 - f0) * (i / n)
            phase += 2 * math.pi * f / RATE
            s = math.sin(phase) + 0.25 * math.sin(2 * phase)
            samples.append(s / 1.25 * AMP * envelope(i, n))
        return samples, 0.0
    freq, dur = note[0], note[1]
    gap = note[2] if len(note) > 2 else 0.0
    n = int(dur * RATE)
    for i in range(n):
        t = i / RATE
        if freq <= 0:
            samples.append(0.0)
            continue
        # Fundamental plus a light 2nd harmonic for a softer timbre.
        s = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * 2 * freq * t)
        samples.append(s / 1.25 * AMP * envelope(i, n))
    return samples, gap


def render_tone(notes):
    out = []
    for note in notes:
        s, gap = render_note(note)
        out.extend(s)
        out.extend([0.0] * int(gap * RATE))
    return out


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))


def main():
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg not found on PATH (needed for WAV -> OGG).")
    os.makedirs(OUT, exist_ok=True)
    for key, notes in TONES.items():
        samples = render_tone(notes)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
            wav_path = tf.name
        try:
            write_wav(wav_path, samples)
            mp3_path = os.path.join(OUT, key + ".mp3")
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                 "-c:a", "libmp3lame", "-q:a", "4", mp3_path],
                check=True,
            )
            print("wrote", os.path.relpath(mp3_path, os.path.join(HERE, "..")))
        finally:
            os.remove(wav_path)


if __name__ == "__main__":
    main()
