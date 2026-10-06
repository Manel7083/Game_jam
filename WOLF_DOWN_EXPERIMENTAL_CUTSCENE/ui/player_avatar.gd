extends Control
## Retrato animado do lobo (jogador) para o menu de pausa.
## Desenhado por código (sem imagem): respira, pisca, olhos amarelos pulsando,
## cicatrizes e brasas subindo. Roda mesmo com o jogo pausado.

const FUR_D := Color(0.14, 0.065, 0.24)
const FUR_DD := Color(0.06, 0.025, 0.11)
const BONE := Color(0.86, 0.82, 0.74)
const WOUND := Color(0.55, 0.04, 0.14)

var _t: float = 0.0
var _glow_tex: GradientTexture2D
var _frame: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(260, 330)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256

	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0, 0, 0, 0)
	_frame.set_border_width_all(3)
	_frame.border_color = UIKit.GOLD_D
	_frame.set_corner_radius_all(6)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _hash(v: float) -> float:
	return fposmod(sin(v * 12.9898 + 78.233) * 43758.5453, 1.0)


func _glow(pos: Vector2, radius: float, col: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


func _poly(pts: Array, c: Vector2, s: float, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p as Vector2) * s)
	draw_colored_polygon(out, col)


## Polígono simétrico: `right` começa e termina no eixo (x = 0).
func _sym(right: Array, c: Vector2, s: float, col: Color) -> void:
	var full: Array = right.duplicate()
	for i in range(right.size() - 2, 0, -1):
		full.append(Vector2(-(right[i] as Vector2).x, (right[i] as Vector2).y))
	_poly(full, c, s, col)


func _line(a: Vector2, b: Vector2, c: Vector2, s: float, col: Color, w: float) -> void:
	draw_line(c + a * s, c + b * s, col, w * s, true)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# Fundo: céu noturno com lua atrás da cabeça
	var top := Color(0.03, 0.035, 0.10)
	var bot := Color(0.17, 0.07, 0.21)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, bot, bot]))
	_glow(Vector2(w * 0.5, h * 0.40), w * 0.95, Color(0.40, 0.46, 0.95, 0.30))
	draw_circle(Vector2(w * 0.5, h * 0.36), w * 0.26, Color(0.80, 0.84, 1.0, 0.10))
	for i in 14:
		var fi: float = float(i)
		var sx: float = _hash(fi * 1.7) * w
		var sy: float = _hash(fi * 2.9 + 3.0) * h * 0.5
		var tw: float = 0.35 + 0.35 * sin(_t * 2.0 + fi)
		draw_circle(Vector2(sx, sy), 1.2 + _hash(fi) * 1.2, Color(0.8, 0.85, 1.0, tw))

	# Cabeça (respirando)
	var s: float = 0.74 * (1.0 + 0.012 * sin(_t * 2.2))
	var c := Vector2(w * 0.5, h * 0.50 + sin(_t * 2.2) * 3.0)

	# Juba / ombros
	_sym([Vector2(0, 58), Vector2(60, 50), Vector2(108, 40), Vector2(142, 100), Vector2(172, 190), Vector2(0, 190)], c, s, FUR_D)
	for sd in [-1.0, 1.0]:
		var k: float = sd
		_poly([Vector2(k * 105, 40), Vector2(k * 158, 64), Vector2(k * 136, 104)], c, s, FUR_D)
		_poly([Vector2(k * 130, 96), Vector2(k * 184, 130), Vector2(k * 150, 160)], c, s, FUR_D)
	_poly([Vector2(-60, 120), Vector2(0, 100), Vector2(60, 120), Vector2(80, 190), Vector2(-80, 190)], c, s, Color(0.24, 0.12, 0.38, 0.8))

	# Orelhas
	for sd in [-1.0, 1.0]:
		var k2: float = sd
		_poly([Vector2(k2 * 92, -62), Vector2(k2 * 128, -190), Vector2(k2 * 34, -108)], c, s, FUR_D)
		_poly([Vector2(k2 * 90, -86), Vector2(k2 * 114, -160), Vector2(k2 * 56, -106)], c, s, Color(0.42, 0.14, 0.30, 0.95))
		_line(Vector2(k2 * 124, -180), Vector2(k2 * 134, -204), c, s, FUR_D, 6.0)

	# Crânio
	var skull: Array = [Vector2(0, -122), Vector2(52, -114), Vector2(88, -86), Vector2(102, -44),
		Vector2(112, -4), Vector2(96, 38), Vector2(72, 78), Vector2(40, 112), Vector2(0, 130)]
	_sym(skull, c, s, FUR_D)
	# Luz da lua à direita, sombra à esquerda
	_poly([Vector2(6, -118), Vector2(52, -110), Vector2(88, -84), Vector2(100, -44), Vector2(108, -6), Vector2(80, -8), Vector2(46, -60)], c, s, Color(0.34, 0.20, 0.52, 0.9))
	_poly([Vector2(-10, -70), Vector2(-60, -60), Vector2(-100, -40), Vector2(-96, -12), Vector2(-20, -20)], c, s, Color(0.08, 0.03, 0.14, 0.9))
	for i in 34:
		var fi2: float = float(i)
		var u: float = _hash(fi2 * 3.3 + 2.0) * 2.0 - 1.0
		var v: float = _hash(fi2 * 1.9 + 7.0)
		var a := Vector2(u * 100.0 * (0.5 + 0.5 * v), lerpf(-100.0, 100.0, v))
		var d := Vector2(u * 0.35, 1.0).normalized() * (12.0 + _hash(fi2) * 10.0)
		_line(a, a + d, c, s, Color(0.62, 0.52, 0.92, 0.22) if u > 0.0 else Color(0.02, 0.0, 0.05, 0.4), 2.5)

	# Focinho
	_sym([Vector2(0, -2), Vector2(30, 4), Vector2(50, 60), Vector2(38, 108), Vector2(0, 122)], c, s, Color(0.40, 0.28, 0.60))
	_poly([Vector2(6, 2), Vector2(30, 4), Vector2(50, 60), Vector2(38, 108), Vector2(24, 112), Vector2(24, 40)], c, s, Color(0.54, 0.42, 0.78, 0.5))

	# Sobrancelhas pesadas
	for sd in [-1.0, 1.0]:
		var k3: float = sd
		_poly([Vector2(k3 * 106, -38), Vector2(k3 * 58, -54), Vector2(k3 * 12, -30), Vector2(k3 * 20, -6), Vector2(k3 * 66, -14), Vector2(k3 * 102, -6)], c, s, Color(0.04, 0.015, 0.08, 0.96))

	# Nariz e boca
	_sym([Vector2(0, 52), Vector2(20, 52), Vector2(12, 74), Vector2(0, 82)], c, s, Color(0.04, 0.02, 0.07))
	_poly([Vector2(-12, 56), Vector2(2, 56), Vector2(-2, 62), Vector2(-10, 64)], c, s, Color(0.7, 0.65, 0.9, 0.5))
	var mouth := Color(0.03, 0.01, 0.05)
	for sd in [-1.0, 1.0]:
		var k4: float = sd
		var pts := PackedVector2Array([c + Vector2(0, 82) * s, c + Vector2(0, 98) * s, c + Vector2(k4 * 26, 106) * s, c + Vector2(k4 * 56, 102) * s])
		draw_polyline(pts, mouth, 4.0 * s, true)
		_poly([Vector2(k4 * 20, 104), Vector2(k4 * 32, 104), Vector2(k4 * 26, 124)], c, s, BONE)

	# Cicatrizes
	for i in 3:
		var o: float = float(i) * 14.0
		_line(Vector2(-104 + o, -22 + i), Vector2(-68 + o, 56 + i * 2), c, s, WOUND, 6.0)
		_line(Vector2(-102 + o, -22 + i), Vector2(-66 + o, 56 + i * 2), c, s, Color(0.9, 0.25, 0.3, 0.45), 2.0)
	for i in 2:
		var o2: float = float(i) * 14.0
		_line(Vector2(88 + o2, 0), Vector2(68 + o2, 52), c, s, WOUND, 6.0)
	var drip: float = fposmod(_t * 0.35, 1.0)
	_line(Vector2(-68, 56), Vector2(-68, 56 + 16 + 40 * drip), c, s, Color(0.55, 0.04, 0.14, 0.85 * (1.0 - drip)), 4.0)

	# Contorno de luz da lua
	var rim := PackedVector2Array()
	for p in [Vector2(0, -122), Vector2(52, -114), Vector2(88, -86), Vector2(102, -44), Vector2(112, -4)]:
		rim.append(c + (p as Vector2) * s)
	draw_polyline(rim, Color(0.74, 0.70, 1.0, 0.6), 3.0, true)

	# Olhos amarelos (pulsam e piscam)
	var pulse: float = 0.65 + 0.18 * sin(_t * 3.6)
	var ph: float = fposmod(_t, 4.3)
	var open: float = 1.0
	if ph > 4.1:
		open = clampf(absf(ph - 4.2) / 0.1, 0.12, 1.0)
	for sd in [-1.0, 1.0]:
		var k5: float = sd
		var ec: Vector2 = c + Vector2(k5 * 52, -9) * s
		_glow(ec, 80.0 * s, Color(1.0, 0.70, 0.08, 0.28 * pulse))
		_glow(ec, 38.0 * s, Color(1.0, 0.85, 0.15, 0.55 * pulse))
		var eye: Array = []
		for p in [Vector2(k5 * 20, -6), Vector2(k5 * 52, -24), Vector2(k5 * 84, -8), Vector2(k5 * 52, 6)]:
			var pp: Vector2 = p
			eye.append(Vector2(pp.x, -9.0 + (pp.y + 9.0) * open))
		_poly(eye, c, s, Color(1.0, 0.93, 0.40))
		_poly([Vector2(k5 * 52, -9 - 9 * open), Vector2(k5 * 55, -9), Vector2(k5 * 52, -9 + 9 * open), Vector2(k5 * 49, -9)], c, s, Color(0.06, 0.0, 0.0))

	# Vapor da respiração
	for i in 4:
		var f: float = fposmod(_t * 0.4 + float(i) / 4.0, 1.0)
		_glow(c + Vector2(sin(float(i) * 2.0) * 16.0, 120.0 - f * 70.0) * s, (10.0 + f * 34.0) * s, Color(0.75, 0.8, 1.0, 0.13 * (1.0 - f)))

	# Brasas subindo
	for i in 12:
		var fj: float = float(i)
		var e: float = fposmod(_t * (0.08 + _hash(fj) * 0.08) + _hash(fj + 4.0), 1.0)
		var ex: float = _hash(fj + 1.0) * w + sin(_t + fj) * 8.0
		var ey: float = h - e * h * 0.9
		draw_circle(Vector2(ex, ey), 1.4 + _hash(fj + 6.0) * 1.4, Color(1.0, 0.6, 0.2, sin(e * PI) * 0.7))

	# Moldura
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_border_width_all(1)
	inner.border_color = Color(1.0, 0.82, 0.45, 0.25)
	inner.set_corner_radius_all(4)
	draw_style_box(inner, Rect2(Vector2(6, 6), size - Vector2(12, 12)))
