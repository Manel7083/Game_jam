import numpy as np, scipy.signal as ss, wave, os, sys

SR = 44100
rng = np.random.default_rng(1313)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio", "dracula")  # requer numpy e scipy
os.makedirs(OUT, exist_ok=True)


# ----------------------------------------------------------------- helpers
def tt(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def noise(d):
    return rng.normal(size=int(d * SR))


def lp(x, f, order=2):
    return ss.sosfilt(ss.butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return ss.sosfilt(ss.butter(order, f, btype="high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return ss.sosfilt(ss.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def svf_bandpass(x, fc, q, sr=SR):
    """Filtro de estado variavel (Chamberlin), freq de corte variavel no tempo, ganho de pico ~1."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    f = (2 * np.sin(np.pi * np.minimum(fc, sr * 0.2) / sr)).tolist()
    xl = x.tolist()
    qq = 1.0 / q
    low = band = 0.0
    out = [0.0] * len(xl)
    for i in range(len(xl)):
        low += f[i] * band
        high = xl[i] - low - qq * band
        band += f[i] * high
        out[i] = band * qq
    return np.array(out)


def swept_noise(d, f0, f1, q=3.0):
    t = tt(d)
    fc = f0 * (f1 / f0) ** (t / d)
    return svf_bandpass(noise(d), fc, q)


def sweep(f0, f1, d, curve="exp"):
    t = tt(d)
    f = f0 * (f1 / f0) ** (t / d) if curve == "exp" else f0 + (f1 - f0) * t / d
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def decay(d, tau, attack=0.002):
    t = tt(d)
    return np.exp(-t / tau) * (1 - np.exp(-t / max(attack, 1e-4)))


def place(buf, x, start):
    i = int(start * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf) and j > i:
        buf[i:j] += x[: j - i]


def fades(x, a=0.003, b=0.015):
    x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    x[:na] *= np.linspace(0, 1, na)
    x[-nb:] *= np.linspace(1, 0, nb)
    return x


def reverb(x, rt=1.5, wet=0.25, damp=3500, stereo=False, predelay=0.012):
    n = int(rt * SR * 1.1)
    t = np.arange(n) / SR
    sos = ss.butter(2, damp, fs=SR, output="sos")

    def ir():
        r = rng.normal(size=n) * np.exp(-6.9 * t / rt)
        r = ss.sosfilt(sos, r)
        r[: int(predelay * SR)] = 0
        return r / (np.sqrt(np.sum(r ** 2)) + 1e-9)

    dry = np.concatenate([x, np.zeros(n)])
    if stereo:
        L = ss.fftconvolve(x, ir())
        R = ss.fftconvolve(x, ir())
        L = np.pad(L, (0, len(dry) - len(L)))[: len(dry)]
        R = np.pad(R, (0, len(dry) - len(R)))[: len(dry)]
        return np.stack([dry + wet * L * 3, dry + wet * R * 3], axis=1)
    w = ss.fftconvolve(x, ir())
    w = np.pad(w, (0, len(dry) - len(w)))[: len(dry)]
    return dry + wet * w * 3


def trim_tail(x, thresh=0.02):
    a = np.abs(x if x.ndim == 1 else x.max(axis=1))
    idx = np.where(a > thresh * a.max())[0]
    return x[: idx[-1] + 1] if len(idx) else x


def save(name, x, peak=0.89):
    x = trim_tail(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    # fade final 20ms
    nb = int(0.02 * SR)
    ramp = np.linspace(1, 0, nb)
    if x.ndim == 1:
        x[-nb:] *= ramp
        x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    else:
        x[-nb:] *= ramp[:, None]
        x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))[:, None]
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name:26s} {len(x)/SR:5.2f}s  {'mono' if x.ndim==1 else 'stereo'}")
    return x


# ----------------------------------------------------------------- ataque 1: orbes
def orb_release(r=0.45):
    tr = tt(r)
    boom = sweep(1100, 90, r) * np.exp(-tr / 0.09)
    crack = hp(noise(r), 1500) * np.exp(-tr / 0.03) * 0.5
    swirl = swept_noise(r, 4000, 400, q=2) * np.exp(-tr / 0.12) * 0.7
    bell = np.sin(2 * np.pi * 520 * tr + 3 * np.sin(2 * np.pi * 520 * 1.41 * tr)) * np.exp(-tr / 0.1) * 0.25
    return boom * 0.9 + crack + swirl + bell


def snd_orbs_cast():
    d = 0.5
    t = tt(d)
    f = 160 * (720 / 160) ** ((t / d) ** 1.5)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = 0.5 * np.sin(ph) + 0.25 * np.sin(ph * 1.5 + 0.5 * np.sin(ph * 0.5)) + 0.2 * np.sin(ph * 2.01)
    trem = 1 - 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * (10 + 30 * t / d) * t))
    env = (t / d) ** 1.4
    sw = swept_noise(d, 300, 3500, q=4) * 0.6
    charge = (tone * trem * 0.7 + sw) * env
    buf = np.zeros(int(1.0 * SR))
    place(buf, charge, 0.0)
    place(buf, orb_release(), 0.5)
    return reverb(buf, rt=0.8, wet=0.18)


def snd_orbs_shot():
    buf = np.zeros(int(0.5 * SR))
    place(buf, orb_release(0.35) * 0.9, 0.0)
    return reverb(buf, rt=0.6, wet=0.15)


# ----------------------------------------------------------------- ataque 2: morcegos
def snd_bats():
    D = 2.0
    buf = np.zeros(int(D * SR))
    # 0-0.8: rugido baixo + chiado
    d = 0.8
    t = tt(d)
    f = 68 * (1 + 0.04 * np.sin(2 * np.pi * 5 * t))
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    growl = lp(saw, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t))
    growl = svf_bandpass(growl, 500 + 300 * np.sin(2 * np.pi * 2 * t), 2.5) * 2.0 + growl * 0.4
    hiss = bp(noise(d), 2200, 7000) * (0.4 + 0.6 * np.sin(np.pi * t / d))
    env = np.minimum(t / 0.1, 1) * np.where(t > 0.7, np.maximum(0, 1 - (t - 0.7) / 0.1), 1)
    place(buf, (growl * 0.8 + hiss * 0.6) * env, 0.0)
    # 0.8-2.0: enxame
    d2 = 1.2
    t2 = tt(d2)
    flut = bp(noise(d2), 250, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 15 * t2)) ** 1.5
    flut *= np.minimum(t2 / 0.05, 1) * np.exp(-t2 / 0.7)
    place(buf, flut * 1.1, 0.8)
    for k in range(75):
        s = 0.8 + rng.uniform(0, 1.1) ** 1.1
        dd = rng.uniform(0.03, 0.09)
        a, b = rng.uniform(3500, 8000), rng.uniform(3000, 9000)
        c = np.hanning(int(dd * SR)) * sweep(a, b, dd, "lin")
        place(buf, c * rng.uniform(0.15, 0.45) * np.exp(-(s - 0.8) / 0.9), s)
    # impacto do "estouro" de morcegos
    place(buf, hp(noise(0.25), 800) * decay(0.25, 0.05) * 0.7 + sweep(300, 60, 0.25) * decay(0.25, 0.08), 0.8)
    return reverb(buf, rt=1.0, wet=0.2)


# ----------------------------------------------------------------- ataque 3: teleporte
def sparkles(d, n, fmin=2000, fmax=6500, drop=True, gain=0.25):
    out = np.zeros(int(d * SR))
    for _ in range(n):
        s = rng.uniform(0, d * 0.85)
        f = rng.uniform(fmin, fmax)
        dd = rng.uniform(0.04, 0.12)
        p = sweep(f, f * (0.55 if drop else 1.5), dd) * decay(dd, dd * 0.35)
        place(out, p * rng.uniform(0.3, 1) * gain, s)
    return out


def snd_tp_out():
    d = 0.75
    t = tt(d)
    f = 1100 * (70 / 1100) ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.8 * np.sin(ph * 1.012)
    env = np.exp(-t / 0.33) * (1 - np.exp(-t / 0.01))
    x = tone * env * 0.5
    x += swept_noise(d, 5000, 200, q=2.5) * np.exp(-t / 0.3) * 0.9
    x += sparkles(d, 14) * np.exp(-t / 0.4)
    x += sweep(90, 35, d) * np.exp(-t / 0.25) * 0.5
    return reverb(x, rt=1.2, wet=0.22)


def snd_tp_in():
    d = 0.9
    buf = np.zeros(int(d * SR))
    r = 0.3
    t = tt(r)
    f = 80 * (1400 / 80) ** (t / r)
    ph = 2 * np.pi * np.cumsum(f) / SR
    rise = (np.sin(ph) + 0.4 * np.sin(2 * ph)) * (t / r) ** 2 * 0.5
    rise += swept_noise(r, 300, 6500, q=2.5) * (t / r) ** 2 * 0.9
    place(buf, rise, 0.0)
    th = 0.45
    tp = tt(th)
    thump = sweep(160, 42, th) * decay(th, 0.09) * 1.1
    click = hp(noise(th), 1200) * decay(th, 0.02) * 0.5
    place(buf, thump + click, r)
    place(buf, sparkles(0.5, 12, drop=True, gain=0.2) * np.exp(-tt(0.5) / 0.25), r + 0.02)
    return reverb(buf, rt=1.0, wet=0.2)


# ----------------------------------------------------------------- ataque 4: investida de morcego
def snd_bat_warn():
    d = 0.5
    t = tt(d)
    fc = 2200 * (5200 / 2200) ** (t / d)
    vib = 400 * np.sin(2 * np.pi * 28 * t) * (t / d)
    ph = 2 * np.pi * np.cumsum(fc + vib) / SR
    x = np.sin(ph + 1.5 * np.sin(ph * 0.5)) + 0.5 * np.sin(ph * 0.5)
    env = (t / d) ** 0.7 * np.where(t > d - 0.04, (d - t) / 0.04, 1)
    x = x * env * 0.6
    x += hp(noise(d), 4000) * env * 0.35
    x += bp(noise(d), 200, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t)) * env * 0.4
    return reverb(x, rt=0.5, wet=0.12)


def snd_bat_dash():
    d = 0.65
    t = tt(d)
    whoosh = swept_noise(d, 3500, 450, q=1.6) * (np.minimum(t / 0.06, 1) * np.exp(-t / 0.28)) * 1.3
    f = 6500 * (2200 / 6500) ** (t / d) + 250 * np.sin(2 * np.pi * 20 * t)
    scr = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22) * np.minimum(t / 0.02, 1) * 0.45
    flut = bp(noise(d), 250, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * t)) ** 1.5 * np.exp(-t / 0.3) * 0.9
    thump = sweep(180, 70, d) * decay(d, 0.05) * 0.4
    return reverb(whoosh + scr + flut + thump, rt=0.5, wet=0.1)


# ----------------------------------------------------------------- ataque 5: poças de sangue
def pop(f0, f1, dd, amp):
    return sweep(f0, f1, dd) * decay(dd, dd * 0.4, 0.001) * amp


def snd_pool_spawn():
    d = 0.6
    t = tt(d)
    buf = np.zeros(int(d * SR))
    gur = swept_noise(d, 180, 700, q=3) * (0.5 + 0.5 * np.sin(2 * np.pi * 8 * t + 1)) * np.sin(np.pi * t / d) ** 0.6
    place(buf, lp(gur, 900) * 1.4, 0)
    for _ in range(11):
        s = rng.uniform(0, 0.5)
        f = rng.uniform(160, 380)
        place(buf, pop(f, f * rng.uniform(2.0, 3.2), rng.uniform(0.035, 0.09), rng.uniform(0.3, 0.8)), s)
    place(buf, sweep(70, 45, d) * np.sin(np.pi * t / d) * 0.3, 0)
    return reverb(buf, rt=0.5, wet=0.1, damp=2500)


def snd_pool_burst():
    d = 0.8
    buf = np.zeros(int(d * SR))
    t = tt(d)
    place(buf, sweep(140, 42, 0.3) * decay(0.3, 0.08) * 1.2, 0)
    splash = bp(noise(d), 400, 5000) * decay(d, 0.12, 0.003)
    place(buf, splash * 1.0, 0)
    sq = lp(noise(0.3), 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * tt(0.3))) * decay(0.3, 0.12)
    place(buf, sq * 1.3, 0.02)
    for _ in range(16):
        s = rng.uniform(0.06, 0.6)
        f = rng.uniform(250, 700)
        place(buf, pop(f, f * 2.2, rng.uniform(0.02, 0.06), rng.uniform(0.15, 0.5)) * np.exp(-s / 0.35), s)
    return reverb(buf, rt=0.7, wet=0.15, damp=3000)


# ----------------------------------------------------------------- vozes / gritos
SRH = SR * 2  # sintetiza a 88.2k e reduz


def smooth(x, hz, sr):
    return ss.sosfiltfilt(ss.butter(2, hz, fs=sr, output="sos"), x)


def voice(dur, f0_keys, f0_vals, formants, vib=(6.2, 0.005, 0.03), jitter=0.012,
          am=None, asp=0.2, drive=3.0, env_pts=None, gains=(1.0, 0.8, 0.5, 0.25), bw=(90, 130, 220, 300)):
    n = int(dur * SRH)
    t = np.arange(n) / SRH
    f0 = np.interp(t, f0_keys, f0_vals)
    f0 = smooth(f0, 40, SRH)
    vr, vd0, vd1 = vib
    vd = vd0 + (vd1 - vd0) * np.clip(t / (dur * 0.7), 0, 1)
    jit = smooth(rng.normal(size=n), 25, SRH)
    jit = jit / (np.std(jit) + 1e-9) * jitter
    f = f0 * (1 + vd * np.sin(2 * np.pi * vr * t) + jit)
    ph = np.cumsum(f) / SRH
    src = 2 * (ph % 1) - 1
    src = ss.sosfilt(ss.butter(1, 6000, fs=SRH, output="sos"), src)
    asp_env = asp * (0.6 + 0.4 * np.clip(t / 0.3, 0, 1))
    src = src + rng.normal(size=n) * asp_env
    if am is not None:
        rate, depth = am
        src = src * (1 - depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t + 0.7 * np.sin(2 * np.pi * 3 * t))))
    out = np.zeros(n)
    keys = np.linspace(0, dur, len(formants[0][0]))
    for k, (fk_vals, _) in enumerate(formants):
        fc = np.interp(t, keys, fk_vals)
        q = np.mean(fk_vals) / bw[k]
        out += svf_bandpass(src, fc, q, SRH) * gains[k]
    out += src * 0.08
    if env_pts is None:
        env_pts = ([0, 0.04, dur * 0.8, dur], [0, 1, 1, 0])
    env = np.interp(t, *env_pts)
    env = env * (1 + 0.08 * np.sin(2 * np.pi * 9 * t))
    out = np.tanh(out * env * drive)
    out = ss.resample_poly(out, 1, 2)
    return out / (np.max(np.abs(out)) + 1e-9)


def formant_track(n, f1, f2, f3, f4):
    return [(np.array(f1, float), 0), (np.array(f2, float), 0), (np.array(f3, float), 0), (np.array(f4, float), 0)]


def snd_scream_p2():
    d = 2.2
    keys = [0, 0.12, 0.5, 1.4, 1.85, 2.2]
    vals = [330, 930, 1100, 1300, 900, 420]
    fm = formant_track(0,
                       [750, 450, 330, 600, 700, 800],
                       [1250, 1900, 2400, 1700, 1300, 1200],
                       [2700, 2900, 3100, 2900, 2700, 2600],
                       [3600, 3700, 3900, 3700, 3500, 3400])
    A = voice(d, keys, vals, fm, vib=(6.2, 0.005, 0.03), asp=0.25, drive=3.0)
    vals_b = [v * 1.0145 for v in vals]
    B = voice(d, keys, vals_b, fm, vib=(5.5, 0.006, 0.035), asp=0.3, drive=3.5)
    vals_c = [v * 1.414 * 0.5 for v in vals]  # tritono uma oitava abaixo
    C = voice(d, keys, vals_c, fm, vib=(4.5, 0.01, 0.05), asp=0.35, drive=4.0, am=(34, 0.6))
    n = min(len(A), len(B), len(C))
    x = A[:n] * 0.85 + B[:n] * 0.6 + C[:n] * 0.45
    t = tt(n / SR)[:n]
    x += hp(noise(n / SR), 3500)[:n] * np.interp(t, [0, 0.1, 1.6, 2.2], [0, 0.18, 0.25, 0]) * 0.5
    st = reverb(x, rt=2.0, wet=0.32, damp=4500, stereo=True)
    return st


def snd_scream_p3():
    d = 3.2
    # camada aguda: grito desesperado que despenca no final
    keys = [0, 0.15, 0.6, 1.5, 2.2, 2.8, 3.2]
    vals = [260, 800, 1050, 1450, 1150, 650, 220]
    fm = formant_track(0,
                       [800, 400, 320, 650, 750, 800, 650],
                       [1200, 2100, 2500, 1800, 1400, 1100, 1000],
                       [2700, 3000, 3200, 2900, 2700, 2600, 2500],
                       [3600, 3800, 4000, 3700, 3500, 3400, 3300])
    A = voice(d, keys, vals, fm, vib=(6.8, 0.01, 0.045), asp=0.35, drive=4.5, am=(52, 0.35))
    # camada grave: rugido demoniaco
    kb = [0, 0.1, 0.8, 1.7, 2.5, 3.2]
    vb = [85, 120, 160, 210, 120, 55]
    fb = formant_track(0,
                       [650, 700, 800, 750, 650, 550],
                       [950, 1000, 1100, 1250, 1000, 850],
                       [2400, 2500, 2600, 2600, 2400, 2300],
                       [3400, 3500, 3500, 3500, 3300, 3200])
    B = voice(d, kb, vb, fb, vib=(4.0, 0.02, 0.05), asp=0.45, drive=7.0, am=(46, 0.8),
              env_pts=([0, 0.05, 2.6, 3.2], [0, 1, 1, 0]))
    # camada dissonante (tritono) no meio
    vc = [v * 1.414 for v in vals]
    C = voice(d, keys, [v * 0.5 * 1.414 for v in vals], fm, vib=(5.0, 0.012, 0.05), asp=0.4, drive=5.0, am=(31, 0.6))
    n = min(len(A), len(B), len(C))
    t = tt(n / SR)[:n]
    x = A[:n] * 0.8 + B[:n] * 1.0 + C[:n] * 0.4
    # impacto inicial (sub-boom + estouro de ruido)
    boom = sweep(75, 32, 0.7)[:n] * decay(0.7, 0.2)
    pad = np.zeros(n)
    pad[: len(boom)] += boom * 0.9
    burst = hp(noise(0.5), 500) * decay(0.5, 0.08)
    pad[: len(burst)] += burst * 0.5
    x = x + pad
    x += hp(noise(n / SR), 3000)[:n] * np.interp(t, [0, 0.1, 2.5, 3.2], [0, 0.25, 0.3, 0]) * 0.5
    st = reverb(x, rt=2.8, wet=0.4, damp=4000, stereo=True)
    return st


def snd_scream_intro():
    d = 2.9
    # camada grave: rugido que abre a cena
    kb = [0, 0.12, 0.9, 1.6, 2.3, 2.9]
    vb = [70, 105, 150, 195, 125, 58]
    fb = formant_track(0,
                       [650, 700, 800, 760, 650, 550],
                       [950, 1000, 1100, 1250, 1000, 850],
                       [2400, 2500, 2600, 2600, 2400, 2300],
                       [3400, 3500, 3500, 3500, 3300, 3200])
    B = voice(d, kb, vb, fb, vib=(4.0, 0.02, 0.05), asp=0.45, drive=7.0, am=(42, 0.75),
              env_pts=([0, 0.06, 1.9, 2.9], [0, 1, 0.9, 0]))
    # camada aguda: o berro nasce de dentro do rugido e sobe
    ka = [0, 0.4, 0.8, 1.3, 2.0, 2.9]
    va = [300, 320, 900, 1400, 1000, 380]
    fa = formant_track(0,
                       [800, 700, 400, 320, 650, 750],
                       [1200, 1300, 2000, 2500, 1700, 1200],
                       [2700, 2800, 3000, 3200, 2900, 2700],
                       [3600, 3700, 3800, 4000, 3700, 3400])
    A = voice(d, ka, va, fa, vib=(6.6, 0.008, 0.045), asp=0.35, drive=4.5, am=(48, 0.3),
              env_pts=([0, 0.45, 1.0, 2.0, 2.9], [0, 0, 1, 1, 0]))
    C = voice(d, ka, [v * 0.5 * 1.414 for v in va], fa, vib=(5.0, 0.012, 0.05), asp=0.4, drive=5.0, am=(31, 0.6),
              env_pts=([0, 0.5, 1.1, 2.0, 2.9], [0, 0, 1, 1, 0]))
    n = min(len(A), len(B), len(C))
    t = tt(n / SR)[:n]
    x = B[:n] * 1.0 + A[:n] * 0.85 + C[:n] * 0.4
    pad = np.zeros(n)
    boom = sweep(80, 30, 0.8) * decay(0.8, 0.22)
    pad[: len(boom)] += boom * 0.9
    burst = hp(noise(0.4), 500) * decay(0.4, 0.07)
    pad[: len(burst)] += burst * 0.45
    x = x + pad
    x += hp(noise(n / SR), 3000)[:n] * np.interp(t, [0, 0.8, 1.5, 2.9], [0, 0.05, 0.28, 0]) * 0.5
    return reverb(x, rt=2.6, wet=0.38, damp=4000, stereo=True)


def make_hurt(f0_vals, f1, f2, asp, am, seed_off):
    d = 0.42
    keys = [0, 0.05, 0.2, d]
    fm = formant_track(0, f1, f2,
                       [2600, 2600, 2500, 2400],
                       [3500, 3500, 3400, 3300])
    V = voice(d, keys, f0_vals, fm, vib=(7.0, 0.01, 0.03), asp=asp, drive=4.0, am=am,
              env_pts=([0, 0.02, 0.15, d], [0, 1, 0.8, 0]))
    n = len(V)
    buf = np.zeros(n + int(0.15 * SR))
    place(buf, V * 0.9, 0.0)
    place(buf, sweep(220, 60, 0.15) * decay(0.15, 0.05) * 0.7, 0.0)
    place(buf, bp(noise(0.12), 500, 3500) * decay(0.12, 0.04) * 0.45, 0.0)
    for _ in range(3):
        st = rng.uniform(0.03, 0.2)
        f = rng.uniform(250, 600)
        place(buf, pop(f, f * 2.2, rng.uniform(0.02, 0.05), rng.uniform(0.15, 0.3)), st)
    return reverb(buf, rt=0.5, wet=0.12, damp=3000)


def snd_hurt_1():
    return make_hurt([180, 260, 190, 120], [700, 650, 600, 550], [1100, 1000, 950, 900], 0.3, (38, 0.5), 1)


def snd_hurt_2():
    return make_hurt([300, 480, 360, 220], [800, 750, 650, 600], [1300, 1250, 1100, 1000], 0.25, (30, 0.3), 2)


def snd_hurt_3():
    return make_hurt([150, 210, 170, 100], [650, 600, 560, 520], [950, 900, 880, 850], 0.6, (45, 0.7), 3)


if __name__ == "__main__":
    which = sys.argv[1:]
    table = {
        "drac_orbs_cast": snd_orbs_cast,
        "drac_orbs_shot": snd_orbs_shot,
        "drac_bats": snd_bats,
        "drac_teleport_out": snd_tp_out,
        "drac_teleport_in": snd_tp_in,
        "drac_bat_warn": snd_bat_warn,
        "drac_bat_dash": snd_bat_dash,
        "drac_pool_spawn": snd_pool_spawn,
        "drac_pool_burst": snd_pool_burst,
        "drac_scream_phase2": snd_scream_p2,
        "drac_scream_phase3": snd_scream_p3,
        "drac_scream_intro": snd_scream_intro,
        "drac_hurt_1": snd_hurt_1,
        "drac_hurt_2": snd_hurt_2,
        "drac_hurt_3": snd_hurt_3,
    }
    for name, fn in table.items():
        if which and name not in which:
            continue
        save(name, fn(), peak=0.93 if "scream" in name else 0.85)
