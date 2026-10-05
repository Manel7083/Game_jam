#!/usr/bin/env python3
"""
Wolf Down - sons da cutscene do menu (transformação do caçador + uivo).
Reaproveita os instrumentos do gerar_audio.py (mesma pasta), então o timbre combina
com o resto do jogo. Rode:  python3 gerar_audio_menu.py
Gera: menu_transform.wav e menu_howl.wav (na mesma pasta).
"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], HERE]          # gerar_audio.py grava em sys.argv[1]
sys.path.insert(0, HERE)
import gerar_audio as g


def transform():
    d = 6.5
    tr = g.blank(d)
    # batimentos cardíacos acelerando
    t0, gap, i = 0.2, 0.9, 0
    while t0 < 3.5:
        g.place(tr, g.heartbeat(0.45 + 0.45 * min(i / 6.0, 1.0)), t0, 1, 0.0)
        t0 += gap
        gap = max(0.32, gap * 0.82)
        i += 1
    g.place(tr, g.growl(3.4, 52, 0.55), 0.6, 1, 0.0)          # rosnado subindo
    g.place(tr, g.riser(3.0, 90, 1400, 0.55), 0.6, 1, 0.0)    # tensão
    for t0 in (1.1, 1.7, 2.2, 2.6, 2.95, 3.2):                # ossos estalando
        g.place(tr, g.crash(0.8, 0.35), t0, 1, float(g.rng.uniform(-0.7, 0.7)))
    g.place(tr, g.sub_hit(3.0, 1.0), 3.6, 1, 0.0)             # a transformação (clarão)
    g.place(tr, g.sting(2.4, 0.7), 3.6, 1, 0.0)
    g.place(tr, g.growl(2.2, 70, 0.5), 3.7, 1, 0.0)
    return g.master(g.rev(tr, 3.0, 0.35), fi=0.05, fo=0.8)


def howl_sfx():
    d = 6.0
    tr = g.blank(d)
    g.place(tr, g.howl(4.0, 330, 650, 1.0), 0.0, 1, 0.0)
    g.place(tr, g.howl(3.2, 300, 560, 0.35), 0.5, 1, 0.5)     # eco
    g.place(tr, g.bell(g.midi(45), 4.0, 0.3), 0.0, 1, -0.2)
    return g.master(g.rev(tr, 3.5, 0.5), fi=0.2, fo=1.2)


if __name__ == "__main__":
    g.save("menu_transform", transform())
    g.save("menu_howl", howl_sfx())
