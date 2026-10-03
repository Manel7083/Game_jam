#!/usr/bin/env python3
"""
Wolf Down - gerador de trilha e efeitos da cinematica de abertura.
Gera 10 WAVs (um por plano, com a duracao exata de SHOT_DURATION) + thunder.wav.
Tudo e sintese procedural (numpy). Rode:  python3 gerar_audio.py [pasta_saida]
"""
import sys, os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1313)
OUT = sys.argv[1] if len(sys.argv) > 1 else "audio_cinematica"
os.makedirs(OUT, exist_ok=True)

DUR = [4.5, 5.0, 5.0, 5.5, 6.0, 5.5, 8.0, 8.0, 12.5, 7.5]
NAMES = ["shot_00_prologo", "shot_01_sepulturas", "shot_02_vilarejo", "shot_03_castelo",
         "shot_04_cripta", "shot_05_trono", "shot_06_cacador", "shot_07_olho_lobo",
         "shot_08_controles", "shot_09_final"]


# ------------------------------------------------------------------ utilidades
def tt(d): return np.arange(int(d * SR)) / SR
def midi(m): return 440.0 * 2 ** ((m - 69) / 12.0)
def noise(d): return rng.standard_normal(int(d * SR))


def lp(x, fc, n=2):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / np.sqrt(1 + (f / fc) ** (2 * n)), len(x))


def hp(x, fc, n=2):
    X = np.fft.rfft(x); f = np.maximum(np.fft.rfftfreq(len(x), 1 / SR), 1e-3)
    return np.fft.irfft(X / np.sqrt(1 + (fc / f) ** (2 * n)), len(x))


def bp(x, lo, hi): return hp(lp(x, hi), lo)
def norm(x): return x / (np.max(np.abs(x)) + 1e-9)


def env_ar(n, a, r):
    t = np.arange(n) / SR
    e = np.ones(n)
    if a > 0: e = np.minimum(1.0, t / a)
    if r > 0: e = e * np.clip((n / SR - t) / r, 0, 1)
    return np.sin(e * np.pi / 2)  # curva suave


def place(tr, sig, t0, gain=1.0, pan=0.0):
    s = int(t0 * SR)
    if s >= len(tr) or s < 0: return
    sig = np.asarray(sig, dtype=float)
    if sig.ndim == 1:
        l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
        sig = np.stack([sig * l, sig * r], 1)
    e = min(len(tr), s + len(sig))
    tr[s:e] += gain * sig[:e - s]


def rev(tr, decay=2.5, wet=0.3, damp=5000, pre=0.02):
    n_ir = int(min(decay * 1.3, 4.5) * SR)
    t = np.arange(n_ir) / SR
    out = np.zeros_like(tr)
    for ch in range(2):
        ir = lp(rng.standard_normal(n_ir) * np.exp(-t * 6.9 / decay), damp, 2)
        ir = np.concatenate([np.zeros(int(pre * SR)), ir])
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        n = len(tr) + len(ir)
        N = 1 << (n - 1).bit_length()
        c = np.fft.irfft(np.fft.rfft(tr[:, ch], N) * np.fft.rfft(ir, N), N)
        out[:, ch] = c[:len(tr)]
    return tr + wet * out


def fade(tr, fi, fo):
    n = len(tr)
    a = int(fi * SR); b = int(fo * SR)
    if a: tr[:a] *= (0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a))[:, None]
    if b: tr[-b:] *= (0.5 + 0.5 * np.cos(np.pi * np.arange(b) / b))[:, None]
    return tr


def master(tr, fi=0.4, fo=0.7):
    tr = fade(tr, fi, fo)
    ref = np.percentile(np.abs(tr), 99.7) + 1e-9
    tr = np.tanh(tr / ref * 0.85)          # limitador suave (sem saturar o corpo do som)
    tr = tr / (np.max(np.abs(tr)) + 1e-9) * 0.85
    return tr


def save(name, tr):
    pcm = (np.clip(tr, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", name, "%.2fs" % (len(tr) / SR), "pico=%.2f" % np.max(np.abs(tr)))


# ------------------------------------------------------------------ instrumentos
def voice(f, d, a=0.3, r=0.4, vib=0.0, vr=5.5, bright=2200, det=(0.0,), gain=1.0, kind="saw"):
    n = int(d * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for dt in det:
        ff = f * (1 + dt)
        ph = 2 * np.pi * ff * t
        if vib:
            ph = ph - (ff * vib / vr) * np.cos(2 * np.pi * vr * t + rng.uniform(0, 6.28)) * 2 * np.pi
        nh = int(max(1, min(26, 9000 / ff)))
        if kind == "saw":
            out += sum(np.sin(k * ph) / k for k in range(1, nh + 1))
        elif kind == "square":
            out += sum(np.sin(k * ph) / k for k in range(1, nh + 1, 2))
        else:
            out += np.sin(ph) + 0.25 * np.sin(2 * ph)
    out = lp(out / len(det), bright) * env_ar(n, a, r) * gain
    return out


FORM = {"a": [(800, 1.0, 130), (1150, 0.5, 140), (2900, 0.15, 220)],
        "o": [(450, 1.0, 90), (800, 0.35, 110), (2830, 0.1, 220)],
        "u": [(325, 1.0, 80), (700, 0.2, 100), (2700, 0.05, 220)]}


def choir(f, d, a=1.0, r=1.0, vowel="a", voices=3, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for _ in range(voices):
        ff = f * (1 + rng.uniform(-0.007, 0.007))
        vr = rng.uniform(4.6, 5.8)
        ph = 2 * np.pi * ff * t - (ff * 0.005 / vr) * 2 * np.pi * np.cos(2 * np.pi * vr * t + rng.uniform(0, 6.28))
        for k in range(1, int(min(40, 5200 / ff)) + 1):
            fk = k * ff
            amp = 0.12 / k
            for (fc, a_, bw) in FORM[vowel]:
                amp += a_ * np.exp(-((fk - fc) / bw) ** 2) / (k ** 0.4)
            out += amp * np.sin(k * ph + rng.uniform(0, 6.28))
    out += 0.05 * lp(hp(noise(d), 600), 3500)
    return out / voices * env_ar(n, a, r) * gain * 0.45


def organ(f, d, a=0.15, r=0.5, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    out = sum(am * np.sin(2 * np.pi * f * m * t) for m, am in
              [(1, 1.0), (2, 0.7), (3, 0.5), (4, 0.4), (6, 0.2), (8, 0.15)] if f * m < 9000)
    out = out * (1 + 0.04 * np.sin(2 * np.pi * 5.8 * t))
    return lp(out, 3200) * env_ar(n, a, r) * gain * 0.35


def brass(f, d, a=0.12, r=0.3, gain=1.0):
    n = int(d * SR)
    s = voice(f, d, a=0.001, r=0.001, bright=6000, det=(-0.003, 0.003), kind="saw")
    low = lp(s, 500); hi = lp(s, 3200)
    t = np.arange(n) / SR
    mix = np.clip(t / (a * 2.2), 0, 1) ** 1.5
    return (low * (1 - mix) + hi * mix) * env_ar(n, a, r) * gain * 0.9


def bell(f, d, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    parts = [(0.5, 1.0, 1.0), (1, 0.8, 0.9), (1.2, 0.6, 0.7), (1.5, 0.4, 0.5),
             (2.0, 0.5, 0.45), (2.5, 0.25, 0.3), (3.0, 0.2, 0.25), (4.1, 0.12, 0.15)]
    s = sum(a * np.sin(2 * np.pi * f * r_ * t + rng.uniform(0, 6)) * np.exp(-t / (d * df * 0.4)) for r_, a, df in parts)
    s += 0.5 * hp(noise(d), 1500) * np.exp(-t / 0.01)
    return norm(s) * gain * np.minimum(1, t / 0.003)


def celesta(f, d=1.6, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9) + 0.4 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.45)
         + 0.15 * np.sin(8 * np.pi * f * t) * np.exp(-t / 0.2) + 0.1 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.08))
    return s * np.minimum(1, t / 0.003) * gain * 0.6


def pluck(f, d=1.6, decay=0.996, gain=1.0):
    N = int(SR / f); n = int(d * SR)
    b = lp(rng.uniform(-1, 1, N), 6000, 1)
    out = np.zeros(n)
    for k in range(0, n, N):
        m = min(N, n - k); out[k:k + m] = b[:m]
        b = decay * 0.5 * (b + np.roll(b, -1))
    return lp(out, 4500) * gain * 0.9 * env_ar(n, 0.002, 0.15)


def kick(f0=140, f1=45, d=0.6, decay=0.16, gain=1.0):
    t = tt(d)
    f = f1 + (f0 - f1) * np.exp(-t / 0.045)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t / decay)
    s += 0.25 * hp(noise(d), 800) * np.exp(-t / 0.01)
    return s * gain


def sub_hit(d=3.0, gain=1.0):
    t = tt(d)
    s = kick(90, 30, d, 0.7)
    s += 0.7 * lp(noise(d), 260, 3) * np.exp(-t / 0.9)
    s += 0.3 * hp(noise(d), 1200) * np.exp(-t / 0.05)
    return norm(s) * gain


def taiko(gain=1.0):
    d = 0.9; t = tt(d)
    s = kick(130, 55, d, 0.30) + 0.3 * bp(noise(d), 200, 1500) * np.exp(-t / 0.08)
    return norm(s) * gain


def heartbeat(gain=1.0):
    s = np.zeros(int(0.8 * SR))
    s[:int(0.45 * SR)] += kick(80, 40, 0.45, 0.10)
    d2 = kick(72, 38, 0.4, 0.09) * 0.65
    o = int(0.30 * SR); s[o:o + len(d2)] += d2
    return lp(s, 400) * gain


def thunder(d=4.5, seed=0):
    r_ = np.random.default_rng(seed + 11)
    nz = lambda dd: r_.standard_normal(int(dd * SR))
    t = tt(d)
    crack = hp(nz(d), 1800) * np.exp(-t / 0.05) * 0.9
    mod = 0.65 + 0.35 * norm(lp(nz(d), 3))
    rumble = lp(nz(d), 170, 3) * (1 - np.exp(-t / 0.15)) * np.exp(-t / 1.7) * mod * 3.0
    mid = lp(nz(d), 600, 2) * np.exp(-t / 1.2) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.7 * t) ** 2) * 0.6
    sub = np.sin(2 * np.pi * 38 * t) * np.exp(-t / 1.4) * (1 - np.exp(-t / 0.1))
    return norm(crack + rumble + mid + 0.8 * sub)


def stereo_thunder(d=4.5):
    return np.stack([thunder(d, 1), thunder(d, 2)], 1)


def rain(d, gain=1.0):
    outs = []
    for _ in range(2):
        n = noise(d)
        outs.append(hp(lp(n, 9500), 1400) * 0.7 + lp(noise(d), 450) * 0.25)
    return np.stack(outs, 1) * gain * 0.35


def wind(d, level=1.0, whistle=0.4):
    t = tt(d)
    outs = []
    for c in range(2):
        ph = rng.uniform(0, 6.28)
        body = lp(noise(d), 520, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.17 * t + ph)) ** 1.3
        f = 620 + 140 * np.sin(2 * np.pi * 0.23 * t + ph) + 60 * norm(lp(noise(d), 1.5))
        wh = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t + ph + 1)) ** 3
        outs.append(norm(body) + whistle * 0.12 * wh + 0.15 * lp(noise(d), 2500) * (0.3 + 0.7 * np.sin(2 * np.pi * 0.2 * t + ph) ** 2))
    return np.stack(outs, 1) * level * 0.5


def fire(d, gain=1.0):
    t = tt(d)
    roar = lp(noise(d), 900) * (0.55 + 0.45 * norm(lp(noise(d), 6)))
    tr = np.zeros((int(d * SR), 2))
    place(tr, roar * 0.35, 0, 1, 0)
    for _ in range(int(d * 16)):
        t0 = rng.uniform(0, d - 0.08)
        L = int(rng.uniform(0.01, 0.05) * SR)
        click = np.diff(rng.standard_normal(L + 1)) * np.exp(-np.arange(L) / (SR * rng.uniform(0.004, 0.012)))
        place(tr, click, t0, rng.uniform(0.2, 1.0) * 0.8, rng.uniform(-0.9, 0.9))
    return tr * gain


def step(gain=1.0):
    d = 0.35; t = tt(d)
    thud = lp(noise(d), 250, 3) * np.exp(-t / 0.05) + 0.6 * np.sin(2 * np.pi * 70 * t) * np.exp(-t / 0.06)
    splash = hp(lp(noise(d), 6000), 1500) * np.exp(-t / 0.1) * 0.3
    sp = np.concatenate([np.zeros(int(0.02 * SR)), splash])[:len(t)]
    return (thud + sp) * gain


def flutter(d=0.6, gain=1.0):
    t = tt(d)
    s = bp(noise(d), 500, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)) * np.sin(np.pi * t / d) ** 2
    return s * gain


def chirp(gain=1.0):
    t = tt(0.07)
    f = 7200 - 2600 * t / 0.07
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.07) * gain * 0.4


def dirt(d=0.9, gain=1.0):
    t = tt(d)
    s = lp(noise(d), 1800) * (0.4 + 0.6 * np.abs(norm(lp(noise(d), 25)))) * np.sin(np.pi * np.minimum(1, t / d)) ** 0.7
    s += 0.5 * np.diff(noise(d), prepend=0) * (rng.random(len(t)) > 0.995) * np.exp(-t / 0.5)
    return s * gain


def stone_slide(d, gain=1.0):
    t = tt(d)
    rough = 0.5 + 0.5 * norm(lp(noise(d), 14))
    s = lp(noise(d), 700) * rough + 0.8 * lp(noise(d), 120, 3) + 0.15 * hp(noise(d), 2200) * rough
    return norm(s) * env_ar(len(t), 0.25, 0.25) * gain


def crash(d=1.2, gain=1.0):
    t = tt(d)
    s = hp(noise(d), 180) * np.exp(-t / 0.18)
    for _ in range(9):
        o = int(rng.uniform(0.03, 0.9) * SR)
        L = int(0.12 * SR)
        s[o:o + L] += 0.8 * bp(noise(0.12), 300, 3500)[:max(0, min(L, len(s) - o))] * np.exp(-np.arange(L)[:max(0, min(L, len(s) - o))] / (SR * 0.03))
    s += 1.4 * lp(noise(d), 250, 3) * np.exp(-t / 0.2)
    return norm(s) * gain


def growl(d, f0=62, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    f = f0 * (1 + 0.12 * np.sin(2 * np.pi * 2.2 * t) + 0.07 * norm(lp(noise(d), 20)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(np.sin(k * ph) / k for k in range(1, 18))
    s *= 0.55 + 0.45 * np.sin(2 * np.pi * (26 + 6 * np.sin(2 * np.pi * 0.7 * t)) * t)
    s = lp(s, 1100) + 0.4 * bp(noise(d), 150, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 27 * t))
    s = np.tanh(2.2 * norm(s))
    return s * env_ar(n, 0.25 * d, 0.3 * d) * gain


def howl(d=2.8, f0=360, peak=620, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR; u = t / d
    base = np.where(u < 0.35, f0 + (peak - f0) * (u / 0.35) ** 0.8,
                    np.where(u < 0.65, peak, peak - (peak - 0.75 * f0) * np.clip((u - 0.65) / 0.35, 0, 1) ** 1.3))
    f = base * (1 + 0.014 * np.sin(2 * np.pi * 5.2 * t) * np.clip(u * 3, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.28 * np.sin(3 * ph) + 0.14 * np.sin(4 * ph)
    s += 0.12 * bp(noise(d), 500, 2500) * env_ar(n, 0.3, 0.5)
    return norm(s) * env_ar(n, 0.35, 0.9) * gain * 0.7


def drip(f=1300, gain=1.0):
    t = tt(0.3)
    ff = f * (0.7 + 0.9 * (1 - np.exp(-t / 0.015)))
    return np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-t / 0.07) * gain * 0.6


def riser(d, f0, f1, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) + 0.6 * np.sin(ph * 1.06) + 0.5 * np.sin(ph * 1.5) + 0.3 * np.sin(ph * 2.02)
    s = norm(s) * 0.6 + 0.5 * hp(noise(d), 1500) * (t / d) ** 2
    return s * (t / d) ** 2.0 * env_ar(n, 0.05, 0.02) * gain


def sting(d=2.4, gain=1.0):
    t = tt(d)
    s = sum(np.sin(2 * np.pi * f * t * (1 + 0.1 * t)) for f in (1760, 1864, 2637, 2794)) * np.exp(-t / 0.9)
    s += sub_hit(d, 0.9)
    return norm(s) * gain


def whoosh(d=0.6, gain=1.0):
    t = tt(d)
    n1 = bp(noise(d), 300, 1500) * np.sin(np.pi * t / d) ** 2
    n2 = hp(noise(d), 2500) * np.sin(np.pi * np.clip(t / d, 0, 1) ** 1.6) ** 2
    return (n1 + 0.4 * n2) * gain


def magic(d, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * t + 0.8 * np.sin(2 * np.pi * 0.7 * t)) for f in (110, 164.8, 220, 331))
    s = s * (0.7 + 0.3 * np.sin(2 * np.pi * 1.6 * t)) * 0.3
    s += 0.05 * hp(noise(d), 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.6 * t))
    return s * gain


def energy_hum(d, gain=1.0):
    n = int(d * SR); t = np.arange(n) / SR
    s = lp(sum(np.sin(2 * np.pi * 300 * k * t) / k for k in range(1, 8)), 1500)
    s = s * (0.8 + 0.2 * np.sin(2 * np.pi * 2.4 * t)) * 0.4 + 0.04 * hp(noise(d), 5000)
    return s * gain * env_ar(n, 0.5, 0.5)


def blank(d): return np.zeros((int(d * SR), 2))


def beats(tr, start, times_period, gain=0.5):
    """times_period: lista de periodos sucessivos entre batimentos."""
    t0 = start
    for p in times_period:
        if t0 >= len(tr) / SR - 0.4: break
        place(tr, heartbeat(), t0, gain, 0)
        t0 += p


def chord(tr, notes, t0, d, kind="choir", vowel="a", gain=0.5, a=0.8, r=0.8):
    for m in notes:
        f = midi(m)
        if kind == "choir": s = choir(f, d, a, r, vowel, 3, 1.0)
        elif kind == "organ": s = organ(f, d, a, r, 1.0)
        else: s = voice(f, d, a, r, bright=900, det=(-0.004, 0.004), gain=0.5)
        place(tr, s, t0, gain / len(notes) * 2.2, rng.uniform(-0.4, 0.4))


# ------------------------------------------------------------------ cenas
def scene0():  # Prologo - noite, lua, castelo distante
    d = DUR[0]; tr = blank(d)
    place(tr, wind(d, 0.55), 0)
    chord(tr, [45, 52, 57], 0, d, "pad", gain=0.55, a=1.5, r=1.0)
    place(tr, sub_hit(2.5, 0.3), 0.1)
    for m, t0, g in [(69, 0.6, 1), (72, 1.0, .9), (76, 1.5, 1), (74, 2.1, .9), (72, 2.5, .8), (71, 3.0, .9), (69, 3.5, 1)]:
        place(tr, celesta(midi(m), 1.8, 0.5 * g), t0, 1, rng.uniform(-0.6, 0.6))
    place(tr, howl(2.4, 320, 470, 0.22), 1.4, 1, -0.3)
    for t0 in (1.2, 3.0): place(tr, flutter(0.6, 0.15), t0, 1, rng.uniform(-.8, .8))
    place(tr, chirp(0.3), 1.35, 1, 0.5); place(tr, chirp(0.3), 3.15, 1, -0.5)
    return master(rev(tr, 2.6, 0.45))


def scene1():  # Sepulturas - maos saem da terra
    d = DUR[1]; tr = blank(d)
    place(tr, wind(d, 0.5, 0.7), 0)
    chord(tr, [62, 65, 69], 0.3, 2.4, "choir", "u", 0.5, 1.0, 0.6)
    chord(tr, [58, 62, 65], 2.6, 2.4, "choir", "o", 0.5, 0.8, 1.0)
    place(tr, voice(midi(38), d, 1.0, 1.0, bright=300, gain=0.5), 0)
    place(tr, bell(midi(48), 4.0, 0.40), 0.4, 1, -0.2)
    place(tr, bell(midi(48), 2.0, 0.22), 2.9, 1, 0.3)
    for i, t0 in enumerate((1.0, 1.7, 2.4)):  # maos emergindo
        place(tr, dirt(1.0, 0.45), t0, 1, (i - 1) * 0.6)
        place(tr, growl(1.3, 75 + 12 * i, 0.22), t0 + 0.3, 1, (i - 1) * 0.6)
    for t0, m in [(0.8, 88), (1.6, 95), (2.2, 91), (3.1, 100), (3.8, 93), (4.3, 97)]:  # espiritos
        place(tr, celesta(midi(m), 1.5, 0.12), t0, 1, rng.uniform(-.9, .9))
    place(tr, voice(1760, d, 1.0, 1.0, bright=4000, kind="sine", gain=0.04), 0)
    return master(rev(tr, 3.0, 0.5))


def scene2():  # Vilarejo em chamas
    d = DUR[2]; tr = blank(d)
    place(tr, fire(d, 0.9), 0)
    place(tr, wind(d, 0.25), 0)
    place(tr, voice(midi(38), d, 0.6, 0.8, bright=500, det=(-0.003, 0.003), gain=0.45), 0)
    place(tr, voice(midi(45), d, 0.8, 0.8, bright=500, gain=0.25), 0)
    for m, t0, dd in [(74, 0.5, 1.3), (73, 1.8, 0.8), (69, 2.6, 1.0), (70, 3.6, 1.4)]:
        place(tr, voice(midi(m), dd + 0.3, 0.25, 0.4, vib=0.008, bright=3200, det=(-0.003, 0.003), gain=0.32), t0, 1, 0.25)
    for t0 in (0.2, 1.9, 3.6):  # sino dissonante
        place(tr, bell(midi(52), 3.5, 0.32), t0, 1, 0.5)
        place(tr, bell(midi(52) * 1.414, 3.0, 0.16), t0, 1, 0.5)
    place(tr, crash(1.3, 0.55), 1.0, 1, -0.3)
    place(tr, crash(1.0, 0.35), 3.0, 1, 0.4)
    place(tr, sub_hit(2.0, 0.4), 1.0)
    return master(rev(tr, 2.2, 0.32))


def scene3():  # Castelo ancestral
    d = DUR[3]; tr = blank(d)
    place(tr, wind(d, 0.65, 0.5), 0)
    chord(tr, [38, 45, 53], 0, 2.9, "organ", gain=0.55, a=1.2, r=0.4)
    chord(tr, [34, 41, 50], 2.8, 2.7, "organ", gain=0.55, a=0.3, r=1.0)
    for m, t0, dd in [(50, 0.5, 1.2), (53, 1.7, 1.0), (52, 2.6, 1.0), (46, 3.5, 1.8)]:  # motivo do Dracula
        place(tr, brass(midi(m), dd + 0.4, 0.2, 0.5, 0.55), t0, 1, -0.1)
    chord(tr, [62, 69, 74], 2.0, 3.5, "choir", "o", 0.45, 1.5, 1.0)
    for i in range(14):  # rolo de tímpano crescente
        place(tr, kick(80, 50, 0.4, 0.14, 0.15 + 0.06 * i), 3.6 + i * 0.12, 1, 0)
    for t0 in (0.5, 1.8, 3.1, 4.4):
        place(tr, flutter(0.7, 0.22), t0, 1, rng.uniform(-.8, .8))
        place(tr, chirp(0.3), t0 + 0.2, 1, rng.uniform(-.8, .8))
    place(tr, howl(2.0, 300, 430, 0.2), 4.0, 1, 0.4)
    place(tr, sub_hit(3.0, 0.4), 0.0)
    return master(rev(tr, 3.2, 0.5))


def scene4():  # Cripta - o sarcofago abre
    d = DUR[4]; tr = blank(d)
    place(tr, voice(midi(26), d, 1.5, 1.0, bright=220, det=(-0.002, 0.002), gain=0.7), 0)
    place(tr, fire(d, 0.3), 0, 1)
    place(tr, stone_slide(1.6, 0.6), 0.3, 1, 0.0)
    place(tr, sub_hit(3.0, 0.9), 1.75)                                       # tampa bate
    place(tr, crash(0.8, 0.25), 1.75)
    beats(tr, 1.9, [1.0, 0.95, 0.85, 0.75, 0.65, 0.6], 0.55)
    place(tr, riser(2.6, 150, 900, 0.5), 1.8)
    chord(tr, [50, 57, 62], 2.0, 3.5, "choir", "a", 0.55, 1.8, 0.8)
    for m, t0, dd in [(38, 2.3, 0.9), (41, 3.2, 0.9), (40, 4.1, 0.9)]:
        place(tr, brass(midi(m), dd + 0.4, 0.25, 0.4, 0.6), t0)
    t = tt(0.5); place(tr, bp(noise(0.5), 300, 2000) * np.sin(np.pi * t / 0.5) ** 2, 3.9, 0.3, -0.3)  # inspiracao
    place(tr, sting(2.4, 0.75), 4.4)                                          # olhos abrem
    place(tr, growl(1.4, 55, 0.4), 4.5)
    return master(rev(tr, 3.5, 0.5))


def scene5():  # Drácula desperto - trono, lua de sangue
    d = DUR[5]; tr = blank(d)
    chord(tr, [50, 57, 62, 65, 69], 0.2, 2.7, "choir", "a", 0.75, 0.8, 0.3)
    chord(tr, [46, 53, 58, 62, 65], 2.6, 2.9, "choir", "a", 0.75, 0.3, 1.0)
    chord(tr, [26, 38], 0, 2.9, "organ", gain=0.6, a=0.5, r=0.2)
    chord(tr, [22, 34], 2.7, 2.8, "organ", gain=0.6, a=0.3, r=0.9)
    place(tr, magic(d, 0.5), 0)
    place(tr, taiko(0.8), 0.3); place(tr, taiko(0.9), 2.7); place(tr, sub_hit(3.0, 0.5), 0.3)
    for m, t0, dd in [(62, 0.8, 0.9), (65, 1.7, 0.8), (64, 2.5, 0.8), (58, 3.3, 1.8)]:
        place(tr, brass(midi(m), dd + 0.3, 0.12, 0.4, 0.55), t0)
        place(tr, brass(midi(m - 12), dd + 0.3, 0.12, 0.4, 0.45), t0)
    place(tr, bell(midi(72), 4.5, 0.2), 1.0, 1, 0.2)
    for t0 in (0.6, 1.9, 3.2, 4.5):
        place(tr, flutter(0.7, 0.2), t0, 1, rng.uniform(-.8, .8))
    place(tr, growl(1.8, 52, 0.28), 3.5)
    for i in range(14): place(tr, kick(80, 50, 0.4, 0.14, 0.15 + 0.05 * i), 4.3 + i * 0.08, 1, 0)
    return master(rev(tr, 3.5, 0.5))


def scene6():  # O Cacador - chuva, passos, tema heroico
    d = DUR[6]; tr = blank(d)
    place(tr, rain(d, 1.0), 0)
    place(tr, wind(d, 0.3), 0)
    place(tr, voice(midi(33), d, 1.0, 0.8, bright=300, gain=0.45), 0)
    chord(tr, [57, 60, 64], 0.2, 3.5, "pad", gain=0.5, a=1.0, r=0.5)
    chord(tr, [53, 57, 60], 3.6, 3.5, "pad", gain=0.5, a=0.6, r=0.7)
    chord(tr, [57, 60, 64], 7.0, 1.0, "pad", gain=0.5, a=0.3, r=0.8)
    for bar, ch in enumerate([[45, 52, 57, 60, 64], [41, 48, 53, 57, 60]]):  # arpejo de violao
        for i, idx in enumerate([0, 1, 2, 3, 4, 3, 2, 1]):
            place(tr, pluck(midi(ch[idx]), 1.4, 0.995, 0.5), 0.5 + bar * 3.2 + i * 0.4, 1, -0.2 + 0.05 * i)
    for m, t0, dd in [(57, 0.4, 1.6), (60, 2.0, 1.0), (64, 3.0, 1.2), (62, 4.2, 0.8), (60, 5.0, 0.8), (57, 5.8, 2.2)]:
        place(tr, voice(midi(m), dd + 0.3, 0.25, 0.4, vib=0.006, bright=1800, det=(-0.002, 0.002), gain=0.55), t0, 1, 0.2)
    i = 0; t0 = 0.8
    while t0 < 7.0:  # passos na poca
        place(tr, step(0.3), t0, 1, -0.15 if i % 2 else 0.15)
        t0 += 0.52; i += 1
    place(tr, energy_hum(4.5, 0.12), 3.0, 1, 0.3)
    place(tr, howl(2.4, 300, 430, 0.18), 5.5, 1, -0.5)
    return master(rev(tr, 2.0, 0.28))


def scene7():  # Olho do Lobo - tensao
    d = DUR[7]; tr = blank(d)
    place(tr, wind(d, 0.35, 0.2), 0)
    place(tr, voice(midi(28), d, 2.0, 1.0, bright=200, det=(-0.003, 0.003), gain=0.7), 0)
    for m in (64, 65, 76):  # cordas tremolo dissonantes
        s = voice(midi(m), 6.0, 2.0, 1.0, bright=3500, det=(-0.004, 0.004), gain=0.5)
        s *= 0.65 + 0.35 * np.sin(2 * np.pi * 9 * tt(6.0))
        place(tr, s, 2.0, 0.2, rng.uniform(-0.5, 0.5))
    beats(tr, 0.3, [1.2, 1.2, 1.1, 1.0, 0.9, 0.85, 0.8, 0.8, 0.8, 0.8], 0.55)
    k = 0
    while 1.0 + k * 2.09 < d - 0.5:  # respiracao pesada
        tb = tt(1.6); s = bp(noise(1.6), 150, 1300) * np.sin(np.pi * tb / 1.6) ** 2
        place(tr, s, 1.0 + k * 2.09, 0.22 + 0.04 * k, 0); k += 1
    place(tr, riser(1.5, 200, 1500, 0.4), 0.8)                       # olhos acendem
    place(tr, sting(2.4, 0.6), 2.2)
    place(tr, growl(2.8, 58, 0.55), 2.6)
    place(tr, growl(1.3, 70, 0.55), 5.0)
    for t0, p in [(3.3, -0.7), (3.9, 0.7), (4.8, -0.7), (5.0, 0.7), (6.3, -0.7), (6.1, 0.7)]:
        place(tr, drip(1100 + rng.uniform(-200, 200), 0.35), t0, 1, p)
    place(tr, howl(2.4, 330, 520, 0.5), 5.6, 1, 0.0)
    return master(rev(tr, 3.5, 0.5))


def scene8():  # Controles - tema calmo, esperanca sombria
    d = DUR[8]; tr = blank(d)
    place(tr, wind(d, 0.15, 0.1), 0)
    chords = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]
    basses = [45, 41, 36, 43]
    arps = [[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62]]
    melody = [[(69, 0, 1.0), (72, 1.0, .8), (76, 1.8, .6), (74, 2.4, .8)],
              [(72, 0, 1.0), (69, 1.0, .8), (72, 1.8, .6), (77, 2.4, .8)],
              [(76, 0, 1.0), (72, 1.0, .8), (67, 1.8, .6), (72, 2.4, .8)],
              [(74, 0, 1.0), (71, 1.0, .8), (67, 1.8, .6), (71, 2.4, .9)]]
    for b in range(4):
        t0 = 0.4 + 3.2 * b
        chord(tr, chords[b], t0, 3.4, "pad", gain=0.45, a=0.6, r=0.6)
        place(tr, voice(midi(basses[b]), 3.3, 0.1, 0.5, bright=400, gain=0.5), t0)
        for i, idx in enumerate([0, 1, 2, 3, 4, 3, 2, 1]):
            place(tr, pluck(midi(arps[b][idx]), 1.2, 0.994, 0.35), t0 + i * 0.4, 1, -0.3 + 0.08 * i)
        for m, o, dd in melody[b]:
            place(tr, voice(midi(m), dd + 0.35, 0.15, 0.35, vib=0.005, bright=2400, kind="saw", gain=0.22), t0 + o, 1, 0.3)
        place(tr, kick(100, 48, 0.6, 0.2, 0.35), t0, 1, 0)
        place(tr, kick(100, 48, 0.5, 0.15, 0.18), t0 + 1.6, 1, 0)
    for i, t0 in enumerate((0.4, 0.9, 1.4)):  # cartoes entram
        place(tr, whoosh(0.55, 0.4), t0, 1, (-0.4, 0.4, 0)[i])
        place(tr, bell(midi(81 + 2 * i), 1.2, 0.18), t0 + 0.2, 1, (-0.4, 0.4, 0)[i])
    place(tr, sub_hit(2.0, 0.25), 0)
    return master(rev(tr, 2.0, 0.3), fi=0.5, fo=1.0)


def scene9():  # A cacada comeca - final epico
    d = DUR[9]; tr = blank(d)
    place(tr, riser(0.8, 120, 1200, 0.5), 0.0)
    place(tr, sub_hit(3.5, 1.0), 0.8)
    place(tr, bell(midi(45), 5.0, 0.45), 0.8, 1, -0.2)
    chord(tr, [38, 50, 57, 62, 65, 69], 0.8, 6.0, "choir", "a", 0.8, 0.4, 1.2)
    chord(tr, [26, 38], 0.8, 6.0, "organ", gain=0.7, a=0.1, r=1.2)
    for m, t0, dd in [(62, 1.0, 0.9), (65, 1.9, 0.9), (64, 2.8, 0.9), (58, 3.7, 1.6)]:
        for o, g in ((0, 0.6), (-12, 0.5)):
            place(tr, brass(midi(m + o), dd + 0.4, 0.1, 0.4, g), t0)
    t0 = 1.0; i = 0
    while t0 < 5.8:  # ostinato de tambor
        place(tr, taiko(0.45 if i % 2 else 0.7), t0, 1, 0)
        t0 += 0.45; i += 1
    place(tr, bell(midi(45), 3.5, 0.35), 4.2, 1, 0.2)
    place(tr, howl(2.2, 380, 700, 0.38), 5.2, 1, 0.0)
    for t0 in (0.8, 2.4, 4.0): place(tr, flutter(0.8, 0.25), t0, 1, rng.uniform(-.8, .8))
    for i in range(18): place(tr, kick(80, 50, 0.4, 0.14, 0.12 + 0.05 * i), 5.7 + i * 0.07, 1, 0)
    place(tr, sub_hit(2.0, 0.8), 6.9)
    return master(rev(tr, 3.5, 0.45), fi=0.1, fo=0.9)


if __name__ == "__main__":
    scenes = [scene0, scene1, scene2, scene3, scene4, scene5, scene6, scene7, scene8, scene9]
    for fn, name in zip(scenes, NAMES):
        save(name, fn())
    th = stereo_thunder(4.5)
    th = fade(th, 0.01, 1.2)
    th = th / np.max(np.abs(th)) * 0.9
    save("thunder", th)
