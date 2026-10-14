"""Sintetizador e composições da trilha sonora de Infinity Mujo - A Fuga.

Gera loops sem emenda (o rabo do reverb/ecos é dobrado para o início).
Uso: python3 music.py <pasta_saida_wav>
"""
import numpy as np
import sys, os, wave

SR = 44100
rng = np.random.default_rng(1234)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a, d, s, r, hold):
    """Envelope ADSR em amostras; hold = duração da nota (s)."""
    t = np.arange(n) / SR
    e = np.ones(n) * s
    if a > 0:
        e = np.where(t < a, t / a, e)
    dec = (t >= a) & (t < a + d)
    e = np.where(dec, 1.0 - (1.0 - s) * (t - a) / max(d, 1e-6), e)
    rel = t >= hold
    e = np.where(rel, e * np.exp(-(t - hold) / max(r, 1e-3) * 3.0), e)
    return e


# ------------------------------------------------------------ instrumentos

def piano(f, dur, vel=1.0):
    t = tt(dur + 1.2)
    decay = np.exp(-t * (1.6 + f / 900.0))
    s = (np.sin(2 * np.pi * f * t)
         + 0.45 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
         + 0.2 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 5)
         + 0.08 * np.sin(2 * np.pi * 4.01 * f * t) * np.exp(-t * 7))
    a = np.minimum(t / 0.004, 1.0)
    rel = np.where(t > dur, np.exp(-(t - dur) * 6.0), 1.0)
    return s * decay * a * rel * vel * 0.35


def epiano(f, dur, vel=1.0):
    """Rhodes (FM)."""
    t = tt(dur + 1.0)
    idx = 1.6 * np.exp(-t * 4.0) + 0.25
    mod = np.sin(2 * np.pi * f * t) * idx
    s = np.sin(2 * np.pi * f * t + mod) * (1 + 0.08 * np.sin(2 * np.pi * 4.5 * t))
    e = np.minimum(t / 0.006, 1.0) * np.exp(-t * 1.1) * np.where(t > dur, np.exp(-(t - dur) * 5.0), 1.0)
    return s * e * vel * 0.32


def bell(f, dur, vel=1.0):
    t = tt(dur + 2.5)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * (2.2 * np.exp(-t * 2.5))
    s = np.sin(2 * np.pi * f * t + mod)
    e = np.minimum(t / 0.003, 1.0) * np.exp(-t * 1.3)
    return s * e * vel * 0.22


def pluck(f, dur, vel=1.0, bright=1.0):
    t = tt(dur + 0.8)
    s = np.zeros_like(t)
    for h in range(1, 9):
        s += np.sin(2 * np.pi * f * h * t) / h * np.exp(-t * (3 + h * 2.5 / bright))
    e = np.minimum(t / 0.002, 1.0) * np.where(t > dur, np.exp(-(t - dur) * 8.0), 1.0)
    return s * e * vel * 0.3


def saw_pad(f, dur, vel=1.0, harm=7, attack=1.2, release=1.6):
    t = tt(dur + release)
    s = np.zeros_like(t)
    for det in (-0.12, 0.0, 0.11):
        ff = f * 2 ** (det / 12.0)
        ph = rng.uniform(0, 2 * np.pi)
        for h in range(1, harm + 1):
            s += np.sin(2 * np.pi * ff * h * t + ph * h) / h
    e = np.minimum(t / attack, 1.0) * np.where(t > dur, np.exp(-(t - dur) / release * 3.0), 1.0)
    return s * e * vel * 0.06


def soft_pad(f, dur, vel=1.0, attack=1.5, release=2.5):
    """Pad de seno/triângulo, bem macio."""
    t = tt(dur + release)
    s = np.zeros_like(t)
    for det in (-0.07, 0.07):
        ff = f * 2 ** (det / 12.0)
        s += np.sin(2 * np.pi * ff * t) + 0.12 * np.sin(2 * np.pi * 3 * ff * t) + 0.04 * np.sin(2 * np.pi * 5 * ff * t)
    e = np.minimum(t / attack, 1.0) * np.where(t > dur, np.exp(-(t - dur) / release * 3.0), 1.0)
    return s * e * vel * 0.09


def bass(f, dur, vel=1.0):
    t = tt(dur + 0.3)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    s = np.tanh(s * 1.3)
    e = np.minimum(t / 0.01, 1.0) * np.exp(-t * 0.6) * np.where(t > dur, np.exp(-(t - dur) * 12.0), 1.0)
    return s * e * vel * 0.32


def pulse_bass(f, dur, vel=1.0):
    t = tt(dur + 0.1)
    s = np.zeros_like(t)
    for h in (1, 3, 5, 7):
        s += np.sin(2 * np.pi * f * h * t) / h * np.exp(-t * h * 4)
    e = np.minimum(t / 0.004, 1.0) * np.exp(-t * 5) * np.where(t > dur, np.exp(-(t - dur) * 30.0), 1.0)
    return s * e * vel * 0.4


def lead(f, dur, vel=1.0):
    """Lead suave (quadrada filtrada) com vibrato tardio."""
    t = tt(dur + 0.6)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(t / 0.6, 1.0)
    s = np.zeros_like(t)
    for h in (1, 3, 5):
        s += np.sin(2 * np.pi * f * h * t * vib) / (h * h)
    e = np.minimum(t / 0.03, 1.0) * (0.75 + 0.25 * np.exp(-t * 3)) * np.where(t > dur, np.exp(-(t - dur) * 7.0), 1.0)
    return s * e * vel * 0.18


def kick(vel=1.0):
    t = tt(0.45)
    f = 45 + 80 * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vel * 0.55


def snare(vel=1.0, tone=190.0):
    t = tt(0.25)
    n = rng.uniform(-1, 1, len(t))
    n = n - np.concatenate([[0], n[:-1]]) * 0.6
    return (n * np.exp(-t * 22) * 0.5 + np.sin(2 * np.pi * tone * t) * np.exp(-t * 30) * 0.4) * vel * 0.35


def hat(vel=1.0, length=0.05):
    t = tt(length + 0.05)
    n = rng.uniform(-1, 1, len(t))
    n = np.diff(np.concatenate([[0], n]))
    return n * np.exp(-t / length * 4) * vel * 0.12


def crackle(seconds, density=7.0):
    out = np.zeros(int(seconds * SR))
    count = int(seconds * density)
    pos = rng.integers(0, len(out) - 50, count)
    for p in pos:
        out[p:p + 30] += rng.uniform(-1, 1, 30) * np.exp(-np.arange(30) / 6.0) * rng.uniform(0.02, 0.08)
    out += rng.normal(0, 0.003, len(out))
    return out


# ------------------------------------------------------------ mixagem

class Mix:
    def __init__(self, seconds, tail=4.0):
        self.length = int(seconds * SR)
        n = self.length + int(tail * SR)
        self.dry = np.zeros((2, n))
        self.wet = np.zeros((2, n))
        self.delay = np.zeros((2, n))

    def add(self, sig, at, pan=0.0, rev=0.3, dly=0.0):
        i = int(at * SR)
        if i >= self.dry.shape[1]:
            return
        sig = sig[: self.dry.shape[1] - i]
        l = np.cos((pan + 1) * np.pi / 4)
        r = np.sin((pan + 1) * np.pi / 4)
        for ch, g in ((0, l), (1, r)):
            self.dry[ch, i:i + len(sig)] += sig * g
            self.wet[ch, i:i + len(sig)] += sig * g * rev
            self.delay[ch, i:i + len(sig)] += sig * g * dly

    def render(self, delay_time, feedback=0.4, reverb_decay=2.4, wet_gain=1.0):
        n = self.dry.shape[1]
        out = self.dry.copy()
        # eco pingue-pongue (taps somados)
        d = int(delay_time * SR)
        if d > 0 and np.any(self.delay):
            g = 1.0
            for k in range(1, 7):
                g *= feedback
                src = self.delay[0] + self.delay[1]
                ch = k % 2
                shifted = np.zeros(n)
                shifted[d * k:] = src[: n - d * k] * g
                shifted = _lowpass(shifted, 0.25)
                out[ch] += shifted * 0.6
                self.wet[ch] += shifted * 0.3
        # reverb por convolução com resposta sintética
        ir_len = int(reverb_decay * 1.5 * SR)
        t = np.arange(ir_len) / SR
        for ch in range(2):
            ir = rng.normal(0, 1, ir_len) * np.exp(-t * 6.9 / reverb_decay)
            ir = _lowpass(ir, 0.35)
            ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
            ir /= np.sqrt(np.sum(ir ** 2))
            m = n + ir_len
            size = 1 << int(np.ceil(np.log2(m)))
            conv = np.fft.irfft(np.fft.rfft(self.wet[ch], size) * np.fft.rfft(ir, size), size)[:m]
            # dobra a cauda do reverb para o começo (loop sem emenda)
            full = np.zeros(m)
            full[:n] += out[ch]
            full += conv * 0.5 * wet_gain
            out_ch = full[: self.length].copy()
            tail = full[self.length:]
            for k in range(0, len(tail), self.length):
                chunk = tail[k:k + self.length]
                out_ch[: len(chunk)] += chunk
            if ch == 0:
                res = np.zeros((2, self.length))
            res[ch] = out_ch
        # master: compressão leve e normalização
        res = np.tanh(res * 1.1) / np.tanh(1.1)
        peak = np.max(np.abs(res))
        res = res / peak * 0.85
        return res


def _lowpass(x, amount):
    """Passa-baixas suave no domínio da frequência (amount 0..1 = fração do espectro)."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(n)))
    X = np.fft.rfft(x, size)
    f = np.linspace(0, 1, len(X))
    X *= 1.0 / (1.0 + (f / amount) ** 4)
    return np.fft.irfft(X, size)[:n]


def write_wav(path, data):
    d = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    inter = np.empty(d.shape[1] * 2, dtype=np.int16)
    inter[0::2] = d[0]
    inter[1::2] = d[1]
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(inter.tobytes())


# ------------------------------------------------------------ utilidades de composição

def arp(mix, start, beat, chord, pattern, steps_per_beat, beats, inst, vel, pan_swing=0.25, rev=0.3, dly=0.0, octave=0):
    step = beat / steps_per_beat
    notes = [n + 12 * octave for n in chord] + [n + 12 + 12 * octave for n in chord]
    for i in range(int(beats * steps_per_beat)):
        n = notes[pattern[i % len(pattern)] % len(notes)]
        v = vel * (1.0 if i % steps_per_beat == 0 else 0.75) * rng.uniform(0.9, 1.05)
        mix.add(inst(midi(n), step * 1.6, v), start + i * step, pan=pan_swing * np.sin(i * 0.9), rev=rev, dly=dly)


def melody(mix, start, beat, phrase, inst, vel=1.0, pan=0.0, rev=0.35, dly=0.0, transpose=0):
    for bar, b, m, d in phrase:
        mix.add(inst(midi(m + transpose), d * beat, vel * rng.uniform(0.92, 1.0)), start + (bar * 4 + b) * beat, pan=pan, rev=rev, dly=dly)


def phrase_from(bars):
    out = []
    for bi, notes in enumerate(bars):
        for b, m, d in notes:
            out.append((bi, b, m, d))
    return out


# ------------------------------------------------------------ faixas

def track_menu():
    bpm = 72; beat = 60 / bpm; bars = 8
    mix = Mix(bars * 4 * beat)
    prog = [(45, [57, 60, 64, 67]), (41, [53, 57, 60, 64]), (48, [52, 55, 60, 62]), (43, [55, 59, 62, 64])]
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        mix.add(piano(midi(root), 3.6 * beat, 0.7), t0, -0.2, rev=0.4)
        arp(mix, t0, beat, ch, [0, 2, 1, 3, 2, 4, 3, 1], 2, 4, piano, 0.42, rev=0.45)
    mel = phrase_from([
        [(0, 76, 2), (2, 74, 1), (3, 72, 1)], [(0, 72, 2), (2, 69, 2)],
        [(0, 67, 1), (1, 72, 1), (2, 74, 2)], [(0, 71, 4)],
        [(0, 76, 2), (2, 77, 1), (3, 76, 1)], [(0, 72, 3), (3, 74, 1)],
        [(0, 72, 1), (1, 71, 1), (2, 67, 2)], [(0, 69, 4)]])
    melody(mix, 0, beat, mel, piano, 0.75, 0.1, rev=0.45)
    return mix.render(beat * 0.75, 0.3, 2.8)


def track_city():
    """Fase 1 - Primeiros Passos: piano em arpejos, Lá menor, 92 bpm."""
    bpm = 92; beat = 60 / bpm; bars = 32
    mix = Mix(bars * 4 * beat)
    prog = [(45, [57, 60, 64, 67]), (41, [53, 57, 60, 64]), (48, [52, 55, 60, 62]), (43, [55, 59, 62, 64])]
    pat = [0, 1, 2, 3, 4, 3, 2, 1]
    mel = phrase_from([
        [(0, 76, 1.5), (1.5, 74, 0.5), (2, 72, 1), (3, 71, 1)], [(0, 72, 1.5), (1.5, 69, 2.5)],
        [(0, 67, 1), (1, 72, 1), (2, 74, 1), (3, 76, 1)], [(0, 74, 3), (3, 71, 1)],
        [(0, 76, 1.5), (1.5, 77, 0.5), (2, 76, 1), (3, 74, 1)], [(0, 72, 1), (1, 74, 0.5), (1.5, 72, 0.5), (2, 69, 2)],
        [(0, 67, 1.5), (1.5, 69, 0.5), (2, 72, 1), (3, 71, 1)], [(0, 69, 4)]])
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        mix.add(bass(midi(root - 12 if root > 44 else root), 3.8 * beat, 0.8), t0, 0.0, rev=0.1)
        mix.add(soft_pad(midi(ch[0]), 4 * beat, 0.6), t0, -0.3, rev=0.5)
        mix.add(soft_pad(midi(ch[2]), 4 * beat, 0.5), t0, 0.3, rev=0.5)
        arp(mix, t0, beat, ch, pat, 2, 4, piano, 0.38 if bar >= 8 else 0.45, rev=0.35)
        if 8 <= bar < 24:
            for b in range(4):
                if b in (0,):
                    mix.add(kick(0.55), t0 + b * beat, 0, rev=0.05)
                if b == 2:
                    mix.add(kick(0.4), t0 + (b + 0.5) * beat, 0, rev=0.05)
                if b in (1, 3):
                    mix.add(snare(0.35, 240), t0 + b * beat, 0.1, rev=0.25)
                for h in range(2):
                    mix.add(hat(0.5 if h == 0 else 0.3), t0 + (b + h * 0.5) * beat, 0.35, rev=0.1)
    melody(mix, 8 * 4 * beat, beat, mel, piano, 0.8, 0.1, rev=0.4)
    melody(mix, 16 * 4 * beat, beat, mel, piano, 0.8, 0.1, rev=0.4)
    melody(mix, 24 * 4 * beat, beat, mel, bell, 0.6, -0.2, rev=0.5, transpose=12)
    return mix.render(beat * 0.75, 0.3, 2.4)


def track_metro():
    """Fase 2 - Meia-Noite: Rhodes lo-fi, Ré menor, 78 bpm."""
    bpm = 78; beat = 60 / bpm; bars = 24
    mix = Mix(bars * 4 * beat)
    prog = [(38, [53, 57, 60, 64]), (34, [53, 57, 58, 62]), (43, [53, 58, 62, 65]), (45, [52, 55, 57, 61])]
    cr = crackle(bars * 4 * beat)
    mix.add(cr * 0.6, 0, -0.2, rev=0.0)
    mix.add(cr[::-1] * 0.6, 0, 0.2, rev=0.0)
    mel = phrase_from([
        [(0, 74, 1), (1.5, 77, 1), (3, 81, 1)], [(0, 79, 2), (2.5, 77, 1.5)],
        [(0, 74, 1), (1, 77, 1), (2, 74, 0.5), (2.5, 72, 1.5)], [(0, 76, 3), (3, 73, 1)],
        [(0, 81, 1.5), (1.5, 79, 0.5), (2, 77, 2)], [(0, 74, 4)],
        [(0, 77, 1), (1, 79, 1), (2, 77, 1), (3, 74, 1)], [(0, 76, 2), (2, 73, 2)]])
    swing = 0.58
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        mix.add(bass(midi(root), 3.5 * beat, 0.9), t0, 0, rev=0.05)
        for hit, dur in ((0, 1.4), (1.5, 0.8), (2.5, 1.4)):
            for k, n in enumerate(ch):
                mix.add(epiano(midi(n), dur * beat, 0.5 if hit == 0 else 0.38), t0 + hit * beat + k * 0.012, -0.25 + k * 0.17, rev=0.3)
        if 4 <= bar < 20:
            mix.add(kick(0.6), t0, 0, rev=0.02)
            mix.add(kick(0.4), t0 + 1.75 * beat, 0, rev=0.02)
            mix.add(kick(0.5), t0 + 2.5 * beat, 0, rev=0.02)
            mix.add(snare(0.45, 180), t0 + beat, 0.05, rev=0.2)
            mix.add(snare(0.45, 180), t0 + 3 * beat, 0.05, rev=0.2)
            for b in range(4):
                mix.add(hat(0.45, 0.04), t0 + b * beat, 0.3, rev=0.05)
                mix.add(hat(0.3, 0.04), t0 + (b + swing) * beat, 0.3, rev=0.05)
    for start_bar in (4, 12):
        melody(mix, start_bar * 4 * beat, beat, mel, bell, 0.7, 0.2, rev=0.45, dly=0.5)
    return mix.render(beat * 0.75, 0.42, 2.0)


def track_bunker():
    """Fase 3 - Concreto: pulso contido, Mi menor, 96 bpm."""
    bpm = 96; beat = 60 / bpm; bars = 32
    mix = Mix(bars * 4 * beat)
    prog = [(40, [55, 59, 62, 66]), (36, [55, 59, 60, 64]), (45, [55, 57, 60, 64]), (47, [54, 57, 59, 64])]
    motif = phrase_from([
        [(0, 71, 0.5), (0.5, 67, 0.5), (1, 66, 1), (2.5, 64, 1.5)], [(0, 67, 0.5), (0.5, 64, 0.5), (1, 67, 1), (2.5, 71, 1.5)],
        [(0, 72, 0.5), (0.5, 69, 0.5), (1, 67, 1), (2.5, 64, 1.5)], [(0, 66, 2), (2, 63, 2)],
        [(0, 76, 0.5), (0.5, 71, 0.5), (1, 74, 1), (2.5, 71, 1.5)], [(0, 67, 0.5), (0.5, 64, 0.5), (1, 67, 1), (2.5, 71, 1.5)],
        [(0, 72, 1), (1, 71, 1), (2, 69, 2)], [(0, 71, 4)]])
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        for k, n in enumerate(ch):
            mix.add(saw_pad(midi(n), 4 * beat, 0.55, harm=5, attack=0.8), t0, -0.4 + k * 0.27, rev=0.5)
        for e in range(8):
            v = 0.75 if e % 2 == 0 else 0.5
            mix.add(pulse_bass(midi(root - 12 if root > 41 else root), 0.4 * beat, v), t0 + e * 0.5 * beat, 0, rev=0.05)
        if 8 <= bar < 28:
            for b in range(4):
                mix.add(kick(0.45), t0 + b * beat, 0, rev=0.03)
            for s in range(16):
                mix.add(hat(0.35 if s % 4 == 2 else 0.18, 0.025), t0 + s * 0.25 * beat, 0.4 if s % 2 else -0.4, rev=0.05)
        if bar % 2 == 1:
            mix.add(bell(midi(83), 0.5 * beat, 0.25), t0 + 3.5 * beat, 0.5, rev=0.6, dly=0.6)
    for start_bar in (8, 16, 24):
        melody(mix, start_bar * 4 * beat, beat, motif, lambda f, d, v: pluck(f, d, v, 0.7), 0.75, -0.1, rev=0.3, dly=0.45)
    return mix.render(beat * 0.75, 0.4, 2.6)


def track_neon():
    """Fase 4 - Neon: synthwave tranquilo, Fá lídio, 100 bpm."""
    bpm = 100; beat = 60 / bpm; bars = 32
    mix = Mix(bars * 4 * beat)
    prog = [(41, [57, 60, 64, 67]), (41, [55, 59, 62, 67]), (40, [55, 59, 62, 64]), (45, [55, 60, 64, 67])]
    pat = [0, 2, 1, 3, 2, 4, 3, 5, 4, 2, 3, 1, 2, 0, 1, 3]
    mel = phrase_from([
        [(0, 72, 1), (1, 76, 1), (2, 79, 1.5), (3.5, 81, 0.5)], [(0, 83, 2), (2, 79, 2)],
        [(0, 79, 1), (1, 76, 1), (2, 74, 1), (3, 76, 1)], [(0, 72, 3), (3, 74, 1)],
        [(0, 76, 1), (1, 79, 1), (2, 84, 1.5), (3.5, 83, 0.5)], [(0, 79, 2), (2, 74, 2)],
        [(0, 76, 1), (1, 74, 1), (2, 71, 1), (3, 72, 1)], [(0, 69, 4)]])
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        for k, n in enumerate(ch):
            mix.add(saw_pad(midi(n), 4 * beat, 0.6, harm=6, attack=0.5), t0, -0.5 + k * 0.33, rev=0.45)
        arp(mix, t0, beat, ch, pat, 4, 4, lambda f, d, v: pluck(f, d, v, 1.4), 0.32, pan_swing=0.6, rev=0.25, dly=0.5, octave=1)
        if bar >= 8:
            for e in range(4):
                mix.add(bass(midi(root - 12 if root > 40 else root), 0.9 * beat, 0.75), t0 + e * beat, 0, rev=0.03)
        if 8 <= bar < 28:
            mix.add(kick(0.55), t0, 0, rev=0.03)
            mix.add(kick(0.45), t0 + 2 * beat, 0, rev=0.03)
            mix.add(snare(0.4, 220), t0 + beat, 0, rev=0.35)
            mix.add(snare(0.4, 220), t0 + 3 * beat, 0, rev=0.35)
            for b in range(4):
                mix.add(hat(0.35, 0.05), t0 + (b + 0.5) * beat, 0.3, rev=0.1)
    for start_bar in (8, 16):
        melody(mix, start_bar * 4 * beat, beat, mel, lead, 0.85, 0.0, rev=0.4, dly=0.35)
    melody(mix, 24 * 4 * beat, beat, mel, bell, 0.5, 0.2, rev=0.5, dly=0.4)
    return mix.render(beat * 0.75, 0.45, 2.6)


def track_space():
    """Fase 5 - Gravidade Zero: ambiente flutuante, Mi bemol maior, 68 bpm."""
    bpm = 68; beat = 60 / bpm; bars = 16
    mix = Mix(bars * 4 * beat, tail=6.0)
    prog = [(39, [55, 58, 62, 65]), (36, [51, 55, 58, 62]), (44, [55, 58, 60, 63]), (46, [53, 58, 60, 63])]
    penta = [63, 65, 67, 70, 72, 75, 77, 79, 82, 84]
    piano_mel = phrase_from([
        [(0, 70, 2), (2, 75, 2)], [(0, 74, 4)], [(0, 72, 2), (2, 70, 2)], [(0, 65, 4)],
        [(0, 70, 2), (2, 77, 2)], [(0, 75, 3), (3, 74, 1)], [(0, 72, 2), (2, 75, 2)], [(0, 70, 4)]])
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        mix.add(soft_pad(midi(root), 4 * beat, 0.9, attack=2.0, release=3.0), t0, 0, rev=0.4)
        for k, n in enumerate(ch):
            mix.add(soft_pad(midi(n), 4 * beat, 0.65, attack=2.0, release=3.0), t0, -0.6 + k * 0.4, rev=0.7)
        for k in range(3):
            if rng.uniform() < 0.8:
                n = int(rng.choice(penta))
                mix.add(bell(midi(n), 2 * beat, rng.uniform(0.35, 0.6)), t0 + rng.choice([0, 1, 1.5, 2, 2.5, 3]) * beat, rng.uniform(-0.7, 0.7), rev=0.8, dly=0.5)
        mix.add(kick(0.25), t0, 0, rev=0.2)
    melody(mix, 4 * 4 * beat, beat, piano_mel, piano, 0.6, 0.1, rev=0.7)
    return mix.render(beat * 1.5, 0.5, 4.0, wet_gain=1.3)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    tracks = {"menu": track_menu, "fase1_cidade": track_city, "fase2_metro": track_metro,
              "fase3_bunker": track_bunker, "fase4_neon": track_neon, "fase5_espaco": track_space}
    only = sys.argv[2:] or list(tracks)
    for name in only:
        data = tracks[name]()
        write_wav(os.path.join(out, name + ".wav"), data)
        print(name, "%.1fs" % (data.shape[1] / SR))
