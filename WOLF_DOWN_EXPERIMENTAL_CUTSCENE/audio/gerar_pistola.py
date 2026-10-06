#!/usr/bin/env python3
"""
Wolf Down - gerador do tiro da PISTOL padrao (bullet/pistol_shot.wav).
Sintese procedural (numpy): estalo seco e agudo + corpo curto + cauda rapida.
Bem diferente do .38 (gunshot_38.wav), que e grave e longo.
Rode:  python3 gerar_pistola.py [caminho_saida.wav]
"""
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(38)
OUT = sys.argv[1] if len(sys.argv) > 1 else "pistol_shot.wav"
DUR = 0.22
n = int(DUR * SR)
t = np.arange(n) / SR


def hp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * (1 - 1 / np.sqrt(1 + (f / fc) ** 4)), len(x))


def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / np.sqrt(1 + (f / fc) ** 4), len(x))


white = rng.standard_normal(n)

# 1) estalo: ruido agudo com ataque instantaneo e queda muito rapida
crack = hp(white, 1800) * np.exp(-t / 0.012)
# 2) corpo: seno que cai de 260Hz para 90Hz (o "pop" da pistola)
body = np.sin(2 * np.pi * np.cumsum(90 + 170 * np.exp(-t / 0.02)) / SR) * np.exp(-t / 0.045)
# 3) cauda: ruido medio filtrado, some rapido (sala pequena)
tail = lp(hp(rng.standard_normal(n), 400), 3500) * np.exp(-t / 0.06) * 0.35

x = 1.0 * crack + 0.9 * body + tail
x = np.tanh(1.6 * x) / np.tanh(1.6)          # saturacao leve, sem estourar
fade = int(0.012 * SR)                        # fade-out final: sem clique, sem loop
x[-fade:] *= np.linspace(1, 0, fade)
x = x / np.max(np.abs(x)) * 0.8              # pico em 80% (nada de clipping)

pcm = (x * 32767).astype("<i2")
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("ok:", OUT, "%.3fs" % DUR, "pico 80%")
