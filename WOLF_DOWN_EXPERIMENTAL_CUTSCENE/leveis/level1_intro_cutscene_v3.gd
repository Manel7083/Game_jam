extends "res://leveis/level1_intro_cutscene.gd"
## Wolf Down - CUTSCENE DE ABERTURA DA FASE 1  [v4 - lobo esguio estilo sprite + facadas]
##
## Este arquivo ESTENDE level1_intro_cutscene.gd (que continua intacto) e só sobrescreve:
##   - _ic_wolf          : o lobo, redesenhado como o sprite de referência: lobisomem ESGUIO e atlético,
##                         em pé, cabeça canina de focinho fino e orelhas pontudas, tronco estreito com
##                         peitoral/abdômen marcados, membros longos e finos, mãos com garras pequenas e
##                         cauda grande e volumosa. Pelagem quase PRETA (silhueta) com luz fria de lua só nos contornos,
##                         olhos dourados incandescentes (mantidos para a cena).
##   - _ic_raised_arm    : braço do .38 com a mesma paleta.
##   - _nw_fx            : efeitos do lobo (as arranhadas viraram FACADAS).
##   - _ic_make_slash    : som do golpe agora é lâmina (shing + estocada).
##
## As facadas usam os mesmos tempos T_SLASH1 / T_SLASH2: o lobo puxa o braço para trás com a faca,
## dá o bote para a frente (corpo avança) e crava a lâmina; a faca fica ensanguentada e some
## logo antes de ele erguer o .38.

# ---- paleta: silhueta quase preta; a luz vem só de P_RIM (contornos) e dos olhos ----
const P_LIGHT := Color(0.085, 0.052, 0.105)
const P_MAIN := Color(0.030, 0.019, 0.044)
const P_MID := Color(0.021, 0.012, 0.032)
const P_DARK := Color(0.012, 0.007, 0.021)
const P_DEEP := Color(0.005, 0.003, 0.011)
const P_EAR := Color(0.055, 0.022, 0.050)
const P_RIM := Color(0.74, 0.64, 0.98, 0.85)
const MOUTH_IN := Color(0.03, 0.01, 0.05)
const GUM := Color(0.52, 0.035, 0.08)
const STEEL := Color(0.19, 0.20, 0.25)
const BLADE := Color(0.74, 0.78, 0.90)
const GRIP := Color(0.27, 0.10, 0.08)

# Estado da faca (preenchido por _ic_wolf, lido pelos efeitos).
var _nw_tip: Vector2 = Vector2.ZERO      # ponta da lâmina (coordenadas de desenho)
var _nw_kdir: Vector2 = Vector2.RIGHT    # direção da lâmina (coordenadas de desenho)
var _nw_kn: float = 0.0                  # visibilidade da faca (0..1)


# ----------------------------------------------------------------------------
# Som: lâmina cortando o ar + estocada
# ----------------------------------------------------------------------------

func _ic_make_slash() -> AudioStreamWAV:
	var rate: int = 44100
	var dur: float = 0.55
	var n: int = int(float(rate) * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp: float = 0.0
	var lp2: float = 0.0
	var hit_t: float = 0.14
	for i in n:
		var tt: float = float(i) / float(rate)
		var noise: float = rng.randf_range(-1.0, 1.0)
		# "swoosh" curto do braço cortando o ar
		var k: float = clampf(tt / 0.18, 0.0, 1.0)
		lp = lerpf(lp, noise, lerpf(0.10, 0.65, k))
		var swoosh: float = lp * sin(PI * k) * 1.1 * (1.0 if tt < 0.18 else 0.0)
		# "shing" metálico da lâmina
		var ring: float = (sin(TAU * 3100.0 * tt) + 0.6 * sin(TAU * 4700.0 * tt) + 0.4 * sin(TAU * 6200.0 * tt)) * exp(-tt * 16.0) * 0.22
		# estocada: baque grave + estalo úmido
		var s: float = swoosh + ring
		if tt >= hit_t:
			var h: float = tt - hit_t
			lp2 = lerpf(lp2, noise, 0.12)
			s += lp2 * exp(-h * 26.0) * 1.5
			s += sin(TAU * 78.0 * h) * exp(-h * 20.0) * 0.8
			s += noise * exp(-h * 95.0) * 0.30
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# ----------------------------------------------------------------------------
# Helpers do lobo (coordenadas locais -> _nw / _nh herdados)
# ----------------------------------------------------------------------------

func _wv_claws(p: Vector2, dirv: Vector2, n: int, spread: float, length: float) -> void:
	var d: Vector2 = dirv.normalized()
	var nrm := Vector2(-d.y, d.x)
	for i in n:
		var o: float = (float(i) - float(n - 1) * 0.5) * spread
		var b: Vector2 = p + nrm * o
		var tip: Vector2 = b + d * length + nrm * (o * 0.15)
		var half: Vector2 = nrm * 3.0
		_nw_poly([b - half, tip, b + half], BONE)


## Perna esguia: coxa, canela e pé com 3 dedos.
func _wv_leg(hip: Vector2, knee: Vector2, ankle: Vector2, toe: Vector2, col: Color, lit_on: bool) -> void:
	var sc: float = _nw_sc
	_nw_limb(hip, knee, 50.0, col)
	_nw_limb(knee, ankle, 34.0, col)
	_nw_limb(ankle, toe, 24.0, col)
	# pé alongado
	_nw_poly([toe + Vector2(-30.0, -12.0), toe + Vector2(16.0, -9.0), toe + Vector2(30.0, 5.0), toe + Vector2(-28.0, 7.0)], col)
	if lit_on:
		draw_line(_nw(hip + Vector2(22.0, -4.0)), _nw(knee + Vector2(17.0, -2.0)), P_RIM, 4.0 * sc, true)
		draw_line(_nw(knee + Vector2(13.0, 0.0)), _nw(ankle + Vector2(10.0, 0.0)), P_RIM, 3.5 * sc, true)
	_wv_claws(toe + Vector2(18.0, 2.0), Vector2(1.0, 0.25), 3, 9.0, 18.0)


func _wv_hline(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(_nw(_nh(a)), _nw(_nh(b)), col, w * _nw_sc, true)


func _wv_hpl(pts: Array, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_nw(_nh(q as Vector2)))
	draw_polyline(out, col, w * _nw_sc, true)


func _wv_rj(v: Vector2, hinge: Vector2, ang: float) -> Vector2:
	return (v - hinge).rotated(ang) + hinge


## Faca de caça. wr = pulso (local), dir = direção da lâmina (local), a = visibilidade, blood = sangue na lâmina.
func _wv_knife(wr: Vector2, dir: Vector2, a: float, blood: float) -> void:
	if a <= 0.01:
		return
	var sc: float = _nw_sc
	var n := Vector2(-dir.y, dir.x)
	var g0: Vector2 = wr - dir * 24.0
	var g1: Vector2 = wr + dir * 32.0
	var blade_len: float = 185.0
	var b0: Vector2 = g1 + dir * 8.0
	var tip: Vector2 = g1 + dir * blade_len

	# cabo de couro/madeira + pomo
	_nw_poly([g0 + n * 9.0, g1 + n * 9.0, g1 - n * 9.0, g0 - n * 9.0], Color(GRIP, a))
	draw_circle(_nw(g0), 11.0 * sc, Color(STEEL, a))
	# guarda
	_nw_poly([g1 + n * 28.0 - dir * 4.0, g1 + n * 28.0 + dir * 8.0, g1 - n * 28.0 + dir * 8.0, g1 - n * 28.0 - dir * 4.0], Color(STEEL, a))
	# lâmina
	_nw_poly([
		b0 + n * 14.0,
		g1 + dir * 160.0 + n * 10.0,
		tip,
		g1 + dir * 120.0 - n * 18.0,
		b0 - n * 14.0,
	], Color(BLADE, a))
	# canal central escuro + brilho no dorso
	draw_line(_nw(b0 + dir * 6.0), _nw(tip - dir * 22.0), Color(0.35, 0.38, 0.48, 0.8 * a), 3.0 * sc, true)
	draw_line(_nw(b0 + n * 11.0), _nw(g1 + dir * 160.0 + n * 8.0), Color(1.0, 1.0, 1.0, 0.85 * a), 3.0 * sc, true)
	# sangue escorrendo da ponta
	if blood > 0.01:
		_nw_poly([tip, tip - dir * 80.0 * blood + n * 9.0, tip - dir * 70.0 * blood - n * 14.0], Color(WOUND.r, WOUND.g, WOUND.b, 0.95 * a))
	# brilho frio da lua correndo pela lâmina
	var gl: float = 0.5 + 0.5 * sin(_total * 7.0)
	_glow(_nw(tip - dir * 40.0), 34.0 * sc, Color(0.80, 0.86, 1.0, 0.22 * a * gl))

	_nw_tip = _nw(tip)
	_nw_kdir = Vector2(dir.x * _nw_f, dir.y).normalized()
	_nw_kn = a


# ----------------------------------------------------------------------------
# O LOBO (perfil) - esguio, estilo do sprite de referência
# ----------------------------------------------------------------------------

func _ic_wolf(base: Vector2, sc: float, t: float) -> void:
	var f: float = _nw_face(t)
	if absf(f) < 0.08:
		f = 0.08 if f >= 0.0 else -0.08
	_nw_base = base
	_nw_sc = sc
	_nw_f = f
	_nw_kn = 0.0

	var d: float = t - T_SWAP
	var up: float = _smooth((d - 0.9) / 1.0)
	var crouch: float = 1.0 - up
	var heave: float = sin(t * 8.0) * (0.35 + 0.65 * crouch)
	var roar: float = _nw_roar(t)
	var stare: float = _smooth((t - T_STARE) / 1.2)
	var gun_r: float = _nw_gun(t)
	var kick: float = exp(-(t - T_SHOT) / 0.2) if t >= T_SHOT else 0.0
	var s1: Vector2 = _nw_slash(t, T_SLASH1)
	var s2: Vector2 = _nw_slash(t, T_SLASH2)
	var wind: float = clampf(s1.x + s2.x, 0.0, 1.0)
	var strike: float = clampf(s1.y + s2.y, 0.0, 1.0)

	# ---------------------------------------------------------------------
	# ANATOMIA (mesmas âncoras da animação anterior)
	# ---------------------------------------------------------------------
	var hip := Vector2(-18.0, lerpf(-305.0, -175.0, crouch) + heave * 2.0)
	var pelvis := Vector2(14.0, lerpf(-330.0, -190.0, crouch) + heave * 2.5)
	var sho := Vector2(lerpf(66.0, 142.0, crouch), lerpf(-585.0, -315.0, crouch) + heave * 5.0)
	sho += Vector2(42.0 * roar + 54.0 * strike - 22.0 * wind - 14.0 * kick, 20.0 * roar + 16.0 * strike)
	_nw_S = sho
	var rib: Vector2 = pelvis.lerp(sho, 0.48)

	var thigh_front := Vector2(92.0, lerpf(-165.0, -110.0, crouch))
	var shin_front := Vector2(-18.0, lerpf(-72.0, -34.0, crouch))
	var foot_front := Vector2(70.0, 0.0)
	var thigh_back := Vector2(-76.0, lerpf(-145.0, -104.0, crouch))
	var shin_back := Vector2(-72.0, lerpf(-62.0, -30.0, crouch))
	var foot_back := Vector2(-48.0, 0.0)

	var jaw_open: float = roar * (0.88 + 0.08 * sin(t * 34.0)) + 0.28 * stare + 0.52 * strike + 0.10 * crouch * (0.5 + 0.5 * sin(t * 8.0))
	jaw_open = clampf(jaw_open, 0.0, 1.1)
	_nw_hd = sho + Vector2(lerpf(52.0, 50.0, crouch) + 18.0 * roar + 10.0 * strike, lerpf(-84.0, -16.0, crouch) + 12.0 * roar + 28.0 * stare)
	_nw_ha = lerpf(0.04, 0.36, crouch) - 0.40 * roar + 0.20 * stare - 0.10 * wind

	# Sombra no chão.
	_glow_ellipse(base + Vector2(18.0, 24.0) * sc, 200.0 * sc, 20.0 * sc, Color(0, 0, 0, 0.72))
	_glow_ellipse(base + Vector2(22.0, 8.0) * sc, 130.0 * sc, 12.0 * sc, Color(0.22, 0.03, 0.30, 0.16))

	# ---------------------------------------------------------------------
	# MEMBROS DE TRÁS
	# ---------------------------------------------------------------------
	_wv_leg(hip + Vector2(-22.0, 10.0), thigh_back + Vector2(-44.0, 8.0), shin_back + Vector2(-26.0, 0.0), foot_back, P_DARK, false)

	var far_el: Vector2 = sho + Vector2(-12.0, 140.0)
	var far_wr: Vector2 = sho + Vector2(lerpf(-30.0, 40.0, crouch), lerpf(300.0, 266.0, crouch))
	_nw_limb(sho + Vector2(-12.0, -2.0), far_el, 40.0, P_DARK)
	_nw_limb(far_el, far_wr, 31.0, P_DARK)
	draw_circle(_nw(far_wr), 19.0 * sc, P_DARK)
	_wv_claws(far_wr + Vector2(6.0, 10.0), Vector2(0.3, 1.0), 3, 10.0, 16.0)

	# Cauda grande e volumosa (camada de sombra + camada principal + penachos na ponta).
	var tail0: Vector2 = hip + Vector2(-44.0, 22.0)
	var tail_w: Array = [30.0, 42.0, 54.0, 58.0, 52.0, 42.0, 30.0]
	var tail_pts: Array = []
	var tprev: Vector2 = tail0
	for i in 7:
		var fi: float = float(i + 1)
		var tp: Vector2 = tail0 + Vector2(-27.0 * fi, 15.0 * fi - 2.0 * fi * fi + sin(t * 2.4 + fi * 0.7) * (3.0 + fi * 1.4))
		_nw_limb(tprev + Vector2(0.0, 8.0), tp + Vector2(0.0, 8.0), float(tail_w[i]), P_DEEP)
		tail_pts.append(tp)
		tprev = tp
	tprev = tail0
	for i in 7:
		var tq: Vector2 = tail_pts[i]
		_nw_limb(tprev, tq, float(tail_w[i]) - 6.0, P_MID if i % 2 == 0 else P_MAIN)
		tprev = tq
	var tl: Vector2 = tail_pts[6]
	for i in 4:
		var fk: float = float(i)
		_nw_poly([tl + Vector2(-8.0, -20.0 + fk * 12.0), tl + Vector2(-58.0 - fk * 6.0, -26.0 + fk * 20.0), tl + Vector2(-6.0, -4.0 + fk * 12.0)], P_MID if i % 2 == 0 else P_MAIN)
	var tail_hi := PackedVector2Array()
	for i in 6:
		var th: Vector2 = tail_pts[i]
		tail_hi.append(_nw(th + Vector2(0.0, -float(tail_w[i]) * 0.38)))
	draw_polyline(tail_hi, Color(P_RIM.r, P_RIM.g, P_RIM.b, 0.55), 4.0 * sc, true)

	# ---------------------------------------------------------------------
	# TRONCO ESTREITO: contorno escuro, corpo, sombra das costas, peitoral e abdômen
	# ---------------------------------------------------------------------
	_nw_poly([
		hip + Vector2(-48.0, 40.0),
		pelvis + Vector2(-46.0, -12.0),
		rib + Vector2(-58.0, -26.0),
		sho + Vector2(-58.0, -30.0),
		sho + Vector2(-10.0, -64.0),
		sho + Vector2(46.0, -42.0),
		sho + Vector2(60.0, 8.0),
		rib + Vector2(44.0, 48.0),
		pelvis + Vector2(34.0, 62.0),
		hip + Vector2(30.0, 52.0),
	], P_DARK)
	_nw_poly([
		pelvis + Vector2(-36.0, 8.0),
		rib + Vector2(-48.0, -18.0),
		sho + Vector2(-46.0, -22.0),
		sho + Vector2(30.0, -26.0),
		rib + Vector2(36.0, 40.0),
		pelvis + Vector2(24.0, 50.0),
	], P_MAIN)
	_nw_poly([
		pelvis + Vector2(-36.0, 8.0),
		rib + Vector2(-48.0, -18.0),
		sho + Vector2(-46.0, -22.0),
		sho + Vector2(-8.0, -30.0),
		rib + Vector2(-6.0, 20.0),
		pelvis + Vector2(-4.0, 40.0),
	], P_MID)
	# peitoral iluminado
	_nw_poly([sho + Vector2(2.0, -14.0), sho + Vector2(44.0, 0.0), rib + Vector2(32.0, 34.0), rib + Vector2(6.0, 28.0)], Color(P_LIGHT.r, P_LIGHT.g, P_LIGHT.b, 0.9))
	# linha do esterno e abdômen marcado
	draw_line(_nw(sho + Vector2(14.0, 6.0)), _nw(pelvis + Vector2(8.0, 36.0)), Color(P_DEEP.r, P_DEEP.g, P_DEEP.b, 0.55), 3.0 * sc, true)
	for i in 3:
		var ay: float = 6.0 + float(i) * 16.0
		var ap0: Vector2 = rib + Vector2(10.0, ay)
		draw_line(_nw(ap0), _nw(ap0 + Vector2(22.0, 4.0)), Color(P_DEEP.r, P_DEEP.g, P_DEEP.b, 0.45), 3.0 * sc, true)
	# ombro (deltoide) arredondado
	draw_circle(_nw(sho + Vector2(4.0, -4.0)), 30.0 * sc, P_MAIN)
	draw_arc(_nw(sho + Vector2(4.0, -4.0)), 30.0 * sc, -2.4, -0.6, 12, P_RIM, 3.5 * sc, true)

	# pelos curtos na linha das costas
	var back: Array = [hip + Vector2(-46.0, 34.0), rib + Vector2(-58.0, -24.0), sho + Vector2(-58.0, -28.0), sho + Vector2(-10.0, -62.0)]
	for i in 14:
		var fi4: float = float(i)
		var sg: float = fi4 / 13.0 * 3.0
		var idx: int = mini(int(sg), 2)
		var lt: float = sg - float(idx)
		var a_pt: Vector2 = back[idx]
		var b_pt: Vector2 = back[idx + 1]
		var bp: Vector2 = a_pt.lerp(b_pt, lt)
		var tg: Vector2 = (b_pt - a_pt).normalized()
		var nrm := Vector2(tg.y, -tg.x)
		var ln: float = (12.0 + 14.0 * _hsh(fi4 * 3.7)) * (1.0 + 0.8 * roar + 0.5 * strike + 0.2 * crouch)
		_nw_poly([bp - tg * 7.0, bp + nrm * ln + tg * 5.0, bp + tg * 7.0], P_DARK if i % 2 == 0 else P_MID)

	# contorno frio da lua no peito e na barriga
	draw_polyline(PackedVector2Array([
		_nw(sho + Vector2(-8.0, -64.0)),
		_nw(sho + Vector2(46.0, -42.0)),
		_nw(sho + Vector2(60.0, 8.0)),
		_nw(rib + Vector2(44.0, 48.0)),
		_nw(pelvis + Vector2(34.0, 62.0))
	]), P_RIM, 4.0 * sc, true)

	# ---------------------------------------------------------------------
	# PERNA DA FRENTE
	# ---------------------------------------------------------------------
	_wv_leg(pelvis + Vector2(26.0, 6.0), thigh_front, shin_front, foot_front, P_MAIN, true)

	# ---------------------------------------------------------------------
	# PESCOÇO + gola de pelos curta
	# ---------------------------------------------------------------------
	_nw_limb(sho + Vector2(8.0, -30.0), _nw_hd + Vector2(-14.0, 20.0), 62.0, P_MAIN)
	var m0: Vector2 = _nw_hd + Vector2(-44.0, -30.0)
	var m1: Vector2 = sho + Vector2(-62.0, -26.0)
	var mtg: Vector2 = (m1 - m0).normalized()
	var mnr := Vector2(-mtg.y, mtg.x)
	for i in 6:
		var fm: float = float(i)
		var bpm: Vector2 = m0.lerp(m1, fm / 5.0)
		var mlen: float = (20.0 + 16.0 * _hsh(fm * 2.7 + 4.0)) * (1.0 + 0.7 * roar + 0.4 * strike + 0.2 * crouch)
		_nw_poly([bpm - mtg * 9.0, bpm + mnr * mlen + mtg * 4.0, bpm + mtg * 9.0], P_DARK if i % 2 == 0 else P_MID)

	# ---------------------------------------------------------------------
	# CABEÇA (focinho fino, orelhas pontudas)
	# ---------------------------------------------------------------------
	var ear_push: float = 14.0 * roar
	# orelhas
	_nw_hpoly([Vector2(-34.0, -30.0), Vector2(-52.0 - ear_push, -106.0), Vector2(0.0, -58.0)], P_DARK)
	_nw_hpoly([Vector2(-30.0, -38.0), Vector2(-44.0 - ear_push, -88.0), Vector2(-8.0, -56.0)], P_EAR)
	_nw_hpoly([Vector2(6.0, -50.0), Vector2(26.0 - ear_push, -112.0), Vector2(46.0, -42.0)], P_MAIN)
	_nw_hpoly([Vector2(12.0, -54.0), Vector2(26.0 - ear_push, -96.0), Vector2(38.0, -46.0)], P_EAR)
	# tufos de pelo atrás do crânio (como no sprite)
	_nw_hpoly([Vector2(-40.0, -12.0), Vector2(-82.0, -8.0), Vector2(-40.0, 8.0)], P_DARK)
	_nw_hpoly([Vector2(-38.0, 8.0), Vector2(-76.0, 22.0), Vector2(-32.0, 26.0)], P_MID)
	_nw_hpoly([Vector2(-30.0, -34.0), Vector2(-68.0, -38.0), Vector2(-36.0, -16.0)], P_MID)
	# crânio
	_nw_hpoly([Vector2(-46.0, 10.0), Vector2(-36.0, -42.0), Vector2(-4.0, -62.0), Vector2(30.0, -54.0), Vector2(52.0, -22.0), Vector2(50.0, 26.0), Vector2(10.0, 44.0), Vector2(-26.0, 34.0)], P_MAIN)
	# sombra atrás e luz na frente
	_nw_hpoly([Vector2(-44.0, 8.0), Vector2(-36.0, -38.0), Vector2(-12.0, -30.0), Vector2(-14.0, 20.0)], P_MID)
	_nw_hpoly([Vector2(8.0, -58.0), Vector2(40.0, -46.0), Vector2(52.0, -22.0), Vector2(48.0, 6.0), Vector2(24.0, -8.0)], Color(P_LIGHT.r, P_LIGHT.g, P_LIGHT.b, 0.85))

	# mandíbula inferior (gira na dobradiça) + interior da boca + dentes
	var hinge := Vector2(20.0, 18.0)
	var ja: float = jaw_open * 0.80
	var jaw_src: Array = [Vector2(20.0, 18.0), Vector2(100.0, 20.0), Vector2(108.0, 33.0), Vector2(84.0, 46.0), Vector2(26.0, 40.0), Vector2(-6.0, 30.0)]
	var jaw_out: Array = []
	for jp in jaw_src:
		jaw_out.append(_wv_rj(jp as Vector2, hinge, ja))
	if jaw_open > 0.03:
		_nw_hpoly([hinge, Vector2(108.0, 18.0), _wv_rj(Vector2(102.0, 20.0), hinge, ja)], MOUTH_IN)
		_nw_hpoly([hinge + Vector2(8.0, 2.0), Vector2(94.0, 19.0), _wv_rj(Vector2(88.0, 20.0), hinge, ja)], GUM)
	_nw_hpoly(jaw_out, P_MID)
	var tooth_h: float = 9.0 + 11.0 * clampf(jaw_open, 0.0, 1.0)
	for i in 4:
		var lx: float = 52.0 + float(i) * 12.0
		_nw_hpoly([_wv_rj(Vector2(lx, 20.0), hinge, ja), _wv_rj(Vector2(lx + 6.0, 20.0), hinge, ja), _wv_rj(Vector2(lx + 3.0, 20.0 - tooth_h), hinge, ja)], BONE)

	# focinho longo e fino + nariz
	_nw_hpoly([Vector2(26.0, -24.0), Vector2(76.0, -20.0), Vector2(120.0, -4.0), Vector2(130.0, 10.0), Vector2(102.0, 22.0), Vector2(30.0, 20.0)], P_LIGHT)
	_nw_hpoly([Vector2(30.0, -22.0), Vector2(76.0, -18.0), Vector2(118.0, -4.0), Vector2(100.0, 0.0), Vector2(60.0, -6.0), Vector2(34.0, -6.0)], Color(0.11, 0.07, 0.15, 0.7))
	_nw_hpoly([Vector2(116.0, -8.0), Vector2(134.0, -2.0), Vector2(128.0, 12.0), Vector2(112.0, 10.0)], P_DEEP)
	_nw_hpoly([Vector2(118.0, -6.0), Vector2(128.0, -2.0), Vector2(124.0, 2.0), Vector2(118.0, 2.0)], Color(0.65, 0.55, 0.75, 0.5))
	# presas de cima
	var fang_h: float = 6.0 + 16.0 * clampf(jaw_open, 0.0, 1.0)
	for i in 3:
		var ux: float = 72.0 + float(i) * 12.0
		_nw_hpoly([Vector2(ux, 21.0), Vector2(ux + 7.0, 21.0), Vector2(ux + 3.0, 21.0 + fang_h + (4.0 if i % 2 == 0 else 0.0))], BONE)

	# olho dourado incandescente (pequeno e inclinado, com a testa franzida)
	var es: float = 1.0 + 0.55 * roar + 1.15 * stare
	var pulse: float = 0.62 + 0.16 * sin(t * 4.2)
	var eye_p: Vector2 = _nw(_nh(Vector2(42.0, -12.0)))
	_nw_hpoly([Vector2(26.0, -24.0), Vector2(60.0, -16.0), Vector2(42.0, -2.0), Vector2(28.0, -8.0)], Color(1.0, 0.90, 0.35))
	_wv_hline(Vector2(36.0, -12.0), Vector2(52.0, -10.0), Color(0.035, 0.0, 0.0), 4.0)
	_nw_hpoly([Vector2(18.0, -38.0), Vector2(64.0, -32.0), Vector2(62.0, -22.0), Vector2(26.0, -17.0)], P_DEEP)
	_glow(eye_p, 70.0 * sc * es, Color(1.0, 0.70, 0.08, 0.22 * pulse + 0.08))
	_glow(eye_p, 34.0 * sc * es, Color(1.0, 0.82, 0.12, 0.48 * pulse))
	_glow(eye_p, 14.0 * sc * es, Color(1.0, 0.95, 0.45, 0.55 * pulse + 0.15))

	# contorno de luz no crânio e no focinho
	_wv_hpl([Vector2(-36.0, -42.0), Vector2(-4.0, -62.0), Vector2(30.0, -54.0), Vector2(52.0, -22.0)], P_RIM, 3.5)
	_wv_hpl([Vector2(26.0, -24.0), Vector2(76.0, -20.0), Vector2(120.0, -4.0), Vector2(130.0, 10.0)], P_RIM, 3.0)

	# ---------------------------------------------------------------------
	# BRAÇO LIVRE (segura a FACA): comprido e fino, mão com dedos
	# ---------------------------------------------------------------------
	if gun_r < 0.03:
		var sh2: Vector2 = sho + Vector2(8.0, -8.0)
		var hang_el: Vector2 = sho + Vector2(lerpf(50.0, 40.0, crouch), 150.0)
		var hang_wr: Vector2 = sho + Vector2(lerpf(30.0, 96.0, crouch), lerpf(312.0, 276.0, crouch))
		hang_el += Vector2(56.0, -34.0) * roar
		hang_wr += Vector2(100.0, -134.0) * roar
		var wind_el: Vector2 = sho + Vector2(-30.0, 72.0)
		var wind_wr: Vector2 = sho + Vector2(-62.0, -8.0)
		var str_el: Vector2 = sho + Vector2(130.0, 56.0)
		var str_wr: Vector2 = sho + Vector2(252.0, 96.0)
		var el: Vector2 = hang_el.lerp(wind_el, wind).lerp(str_el, strike)
		var wr: Vector2 = hang_wr.lerp(wind_wr, wind).lerp(str_wr, strike)
		_nw_limb(sh2, el, 46.0, P_MAIN)
		_nw_limb(el, wr, 36.0, P_MAIN)
		var ad: Vector2 = (wr - el).normalized()
		var ap := Vector2(-ad.y, ad.x)
		# antebraço musculoso (volume) e pelos curtos
		_nw_poly([el.lerp(wr, 0.15) + ap * 22.0, el.lerp(wr, 0.5) + ap * 26.0, el.lerp(wr, 0.85) + ap * 16.0, el.lerp(wr, 0.85) - ap * 14.0, el.lerp(wr, 0.15) - ap * 20.0], P_MAIN)
		for i in 2:
			var q: Vector2 = el.lerp(wr, 0.35 + 0.28 * float(i))
			_nw_poly([q + ap * 20.0 + ad * 6.0, q + ap * 38.0 - ad * 16.0, q + ap * 18.0 - ad * 20.0], P_MID)
		draw_polyline(PackedVector2Array([_nw(sh2 + Vector2(20.0, -6.0)), _nw(el + Vector2(16.0, -2.0)), _nw(wr + Vector2(12.0, -3.0))]), P_RIM, 3.5 * sc, true)
		draw_circle(_nw(wr), 22.0 * sc, P_MAIN)

		var kn_a: float = _smooth((t - (T_ROAR + 0.55)) / 0.25) * (1.0 - _smooth((t - (T_SLASH2 + 0.35)) / 0.2))
		if kn_a > 0.01:
			var carry_dir := Vector2(0.62, -0.78)
			var wind_dir := Vector2(0.82, -0.55)
			var thrust_dir := Vector2(1.0, 0.24)
			var kd: Vector2 = carry_dir.lerp(wind_dir, wind).lerp(thrust_dir, clampf(strike * 1.5, 0.0, 1.0)).normalized()
			var blood: float = 0.0
			if t >= T_SLASH1 + 0.05:
				blood += 0.55
			if t >= T_SLASH2 + 0.05:
				blood += 0.45
			_wv_knife(wr, kd, kn_a, blood)
			# dedos fechados em volta do cabo
			for i in 3:
				var fp: Vector2 = wr + ad * (6.0 + float(i) * 5.0) + ap * (float(i) - 1.0) * 6.0
				draw_circle(_nw(fp), 10.0 * sc, P_MAIN)
		else:
			_wv_claws(wr + ad * 14.0, ad, 3, 10.0, 22.0)

	# feixe sutil dos olhos durante o rugido / encarada
	var beam: float = clampf(roar + stare, 0.0, 1.0)
	if beam > 0.02:
		var bd := Vector2(_nw_f * cos(_nw_ha), sin(_nw_ha))
		draw_line(eye_p, eye_p + bd * (210.0 + 430.0 * stare) * sc, Color(1.0, 0.82, 0.22, 0.18 * beam), 8.0 * sc, true)
		draw_line(eye_p, eye_p + bd * (130.0 + 250.0 * stare) * sc, Color(1.0, 0.96, 0.62, 0.42 * beam), 2.5 * sc, true)


## Braço que segura o .38: sobe, atira para cima (com coice) e desce.
func _ic_raised_arm(t: float) -> void:
	var sc: float = _nw_sc
	var r: float = _nw_gun(t)
	if r <= 0.01:
		return
	var kick: float = 0.0
	if t >= T_SHOT:
		kick = exp(-(t - T_SHOT) / 0.18)
	var sh: Vector2 = _nw(_nw_S + Vector2(8.0, -8.0))
	var el: Vector2 = _nw(_nw_S + Vector2(lerpf(45.0, 120.0, r), lerpf(120.0, -80.0, r) + 30.0 * kick))
	var hd: Vector2 = _nw(_nw_S + Vector2(lerpf(60.0, 160.0, r), lerpf(230.0, -230.0, r) + 55.0 * kick))
	draw_line(sh, el, P_MAIN, 46.0 * sc, true)
	draw_line(el, hd, P_MAIN, 36.0 * sc, true)
	draw_circle(sh, 26.0 * sc, P_MAIN)
	draw_circle(hd, 22.0 * sc, P_MAIN)
	var fd: Vector2 = (hd - el).normalized()
	var fn := Vector2(-fd.y, fd.x)
	for i in 2:
		var q: Vector2 = el.lerp(hd, 0.3 + 0.3 * float(i))
		draw_colored_polygon(PackedVector2Array([q + fn * 20.0 * sc, q + fn * 38.0 * sc - fd * 16.0 * sc, q + fn * 18.0 * sc - fd * 20.0 * sc]), P_MID)
	draw_polyline(PackedVector2Array([sh + Vector2(20.0, -6.0) * sc, el + Vector2(18.0, 0.0) * sc, hd + Vector2(16.0, 0.0) * sc]), P_RIM, 3.5 * sc, true)

	# O .38 apontado para o céu (o coice o inclina para trás).
	var u: Vector2 = Vector2(0.16, -1.0).normalized().rotated(-0.25 * kick)
	var nrm := Vector2(-u.y, u.x)
	var gp: Vector2 = hd + u * 8.0 * sc
	var barrel_end: Vector2 = gp + u * 150.0 * sc
	draw_line(gp - u * 12.0 * sc, barrel_end, Color(0.19, 0.20, 0.25), 16.0 * sc, true)
	draw_circle(gp + u * 40.0 * sc, 24.0 * sc, Color(0.23, 0.24, 0.30))
	draw_line(gp + nrm * 6.0 * sc + u * 40.0 * sc, barrel_end + nrm * 6.0 * sc, Color(0.62, 0.66, 0.78, 0.8), 3.0 * sc, true)
	draw_colored_polygon(PackedVector2Array([gp - u * 6.0 * sc - nrm * 8.0 * sc, gp - u * 30.0 * sc - nrm * 24.0 * sc, gp - u * 2.0 * sc - nrm * 14.0 * sc]), Color(0.14, 0.14, 0.18))
	for i in 3:
		var fp: Vector2 = gp - u * (6.0 + float(i) * 12.0) + nrm * 12.0 * sc
		draw_circle(fp, 11.0 * sc, P_MAIN)
	if t >= T_SHOT and t < T_SHOT + 1.8:
		_ic_muzzle_fx(barrel_end + u * 6.0 * sc, u, t - T_SHOT, sc)


# ----------------------------------------------------------------------------
# Efeitos do lobo: respiração, ondas do rugido e as FACADAS
# ----------------------------------------------------------------------------

func _nw_fx(t: float) -> void:
	var sc: float = _nw_sc
	var mouth: Vector2 = _nw(_nh(Vector2(112.0, 12.0)))
	if t > T_SWAP + 0.5:
		for i in 6:
			var age: float = fposmod(t * 0.8 + float(i) / 6.0, 1.0)
			var pp: Vector2 = mouth + Vector2(_nw_f * age * 110.0, -age * 70.0 + 10.0) * sc
			draw_circle(pp, (8.0 + age * 30.0) * sc, Color(0.80, 0.82, 0.95, 0.16 * (1.0 - age)))
	var d: float = t - T_ROAR
	if d >= 0.0 and d < 1.6:
		var dirv := Vector2(_nw_f * cos(_nw_ha), sin(_nw_ha))
		var ang: float = dirv.angle()
		for i in 5:
			var dd: float = d - float(i) * 0.15
			if dd <= 0.0:
				continue
			var a: float = clampf(1.0 - dd / 1.1, 0.0, 1.0)
			var c: Vector2 = mouth + dirv * dd * 520.0 * sc
			draw_arc(c, (50.0 + dd * 420.0) * sc, ang - 0.6, ang + 0.6, 24, Color(1.0, 0.85, 0.75, 0.5 * a), 7.0 * a + 2.0, true)
		var ga: float = clampf(1.0 - d / 1.4, 0.0, 1.0)
		_glow_ellipse(_nw_base + Vector2(0.0, 22.0), 300.0 + d * 900.0, 34.0, Color(0.75, 0.35, 0.95, 0.28 * ga))
	_nw_stab_fx(t, T_SLASH1)
	_nw_stab_fx(t, T_SLASH2)


## Rastro da estocada + impacto (faíscas, brilho e respingos). Usa a ponta da lâmina atual.
func _nw_stab_fx(t: float, tk: float) -> void:
	var d: float = t - tk
	if d < -0.05 or d > 0.5 or _nw_kn < 0.05:
		return
	var sc: float = _nw_sc
	var u: Vector2 = _nw_kdir
	var tip: Vector2 = _nw_tip
	var nrm := Vector2(-u.y, u.x)

	# rastro de movimento atrás da lâmina
	var reveal: float = _smooth((d + 0.05) / 0.10)
	var fade: float = 1.0 - _smooth(d / 0.40)
	var trail: float = 320.0 * sc * reveal
	for i in 3:
		var off: Vector2 = nrm * (float(i) - 1.0) * 9.0 * sc
		draw_line(tip - u * trail + off, tip + off * 0.3, Color(0.80, 0.50, 1.0, 0.22 * fade), (14.0 - 4.0 * float(i)) * sc, true)
		draw_line(tip - u * trail * 0.8 + off, tip + off * 0.3, Color(1.0, 0.95, 0.85, 0.80 * fade), (4.0 - 1.2 * float(i)) * sc + 1.0, true)

	# impacto: clarão, raios e respingos
	if d >= 0.0:
		var k: float = clampf(1.0 - d / 0.32, 0.0, 1.0)
		_glow(tip, (170.0 * k + 30.0) * sc, Color(1.0, 0.35, 0.35, 0.55 * k))
		_glow(tip, 70.0 * sc, Color(1.0, 1.0, 0.9, 0.80 * k))
		for i in 10:
			var fi: float = float(i)
			var ang: float = TAU * fi / 10.0 + _hsh(fi * 1.9) * 0.4
			var r0: float = (20.0 + d * 600.0) * sc
			var r1: float = r0 + (40.0 + 90.0 * _hsh(fi * 3.1)) * sc * k
			var dv: Vector2 = Vector2.from_angle(ang)
			draw_line(tip + dv * r0, tip + dv * r1, Color(1.0, 0.55, 0.50, 0.9 * k), 4.0 * sc * k + 1.0, true)
		for i in 9:
			var fj: float = float(i)
			var angj: float = TAU * _hsh(fj * 2.3 + 1.0)
			var spj: float = 160.0 + 420.0 * _hsh(fj * 5.7)
			var pj: Vector2 = tip + Vector2.from_angle(angj) * spj * d * sc + Vector2(0.0, 520.0 * d * d)
			draw_circle(pj, (2.5 + 4.0 * _hsh(fj * 8.3)) * sc, Color(0.50, 1.0, 0.60, 0.9 * k))
