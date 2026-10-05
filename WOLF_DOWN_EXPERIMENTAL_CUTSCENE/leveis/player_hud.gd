class_name PlayerHUD
extends Control

## Wolf Down - HUD do jogador (v2).
## Desenhada 100% em código (_draw), no mesmo estilo da cinemática: fonte Mountains of Christmas
## com contorno escuro, vermelho-sangue, dourado e roxo. Lê os dados direto do Global.Player,
## então não depende de sinais do GameManager.
##
## É criada automaticamente pelo inteface.gd (CanvasLayer da HUD) - não precisa adicionar na cena.

const FONT: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const DESIGN_H: float = 720.0

@export var ui_scale_mult: float = 0.8
@export var margin: Vector2 = Vector2(28.0, 22.0)
@export var anchor_bottom_left: bool = true   # true = canto inferior esquerdo (onde ficava a HUD antiga)
const HUD_H: float = 164.0

# Paleta (a mesma da cinemática)
const GOLD := Color(1.0, 0.82, 0.45)
const BLOOD_TOP := Color(1.0, 0.30, 0.24)
const BLOOD_BOT := Color(0.55, 0.03, 0.08)
const BRASS := Color(0.78, 0.58, 0.22)
const SILVER_TOP := Color(0.90, 0.98, 1.0)
const SILVER_BOT := Color(0.35, 0.66, 0.92)
const VIOLET_TOP := Color(0.82, 0.50, 1.0)
const VIOLET_BOT := Color(0.38, 0.12, 0.72)
const OUTLINE := Color(0.08, 0.0, 0.10)

const BAR_X: float = 62.0
const AMMO_CELLS: int = 20

var _glow_tex: GradientTexture2D
var _frame_red: StyleBoxFlat
var _frame_brass: StyleBoxFlat
var _frame_violet: StyleBoxFlat
var _key_style: StyleBoxFlat

var _t: float = 0.0
var _hp_shown: float = 5.0
var _hp_ghost: float = 5.0
var _hurt_flash: float = 0.0
var _ammo_shown: float = 100.0
var _ammo_prev: float = 100.0
var _shot_flash: float = 0.0
var _regen: float = 0.0
var _dash_shown: float = 1.0
var _dash_ready_flash: float = 0.0
var _was_ready: bool = true

# valores do frame atual
var _hp: float = 5.0
var _hp_max: float = 5.0
var _ammo: float = 100.0
var _ammo_max: float = 100.0
var _dash_p: float = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_assets()


func _make_assets() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128

	_frame_red = _mk_frame(Color(0.07, 0.01, 0.03, 0.92), Color(0.85, 0.20, 0.30, 0.95), 8)
	_frame_brass = _mk_frame(Color(0.05, 0.04, 0.06, 0.92), BRASS, 6)
	_frame_violet = _mk_frame(Color(0.05, 0.02, 0.10, 0.92), Color(0.62, 0.34, 0.90, 0.95), 8)

	_key_style = _mk_frame(Color(0.13, 0.10, 0.19, 1.0), Color(0.60, 0.50, 0.80, 1.0), 5)
	_key_style.border_width_bottom = 5


func _mk_frame(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(3)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 8
	return s


# ==============================================================================
# DADOS
# ==============================================================================

func _process(delta: float) -> void:
	var p = Global.Player
	if not is_instance_valid(p):
		visible = false
		return
	visible = true
	_t += delta

	_hp = float(p.health)
	_hp_max = float(GameManager.player_max_hp)
	_ammo = float(p.ammo)
	_ammo_max = maxf(float(p.max_ammo), 1.0)
	if p.dash_cooldown_left <= 0.0:
		_dash_p = 1.0
	else:
		_dash_p = clampf(1.0 - p.dash_cooldown_left / p.DASH_COOLDOWN, 0.0, 1.0)

	# Vida: barra principal cai rápido, o "fantasma" claro demora a acompanhar
	if _hp < _hp_shown - 0.01:
		_hurt_flash = 1.0
	_hp_shown = move_toward(_hp_shown, _hp, delta * 8.0)
	if _hp_ghost > _hp_shown:
		_hp_ghost = move_toward(_hp_ghost, _hp_shown, delta * 1.1)
	else:
		_hp_ghost = _hp_shown
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)

	# Munição: clarão ao atirar, brilho de "recarregando" enquanto regenera
	if _ammo < _ammo_prev - 0.01:
		_shot_flash = 1.0
		_regen = 0.0
	elif _ammo > _ammo_prev + 0.01:
		_regen = minf(_regen + delta * 4.0, 1.0)
	else:
		_regen = maxf(_regen - delta * 3.0, 0.0)
	if _ammo >= _ammo_max - 0.01:
		_regen = 0.0
	_ammo_prev = _ammo
	_ammo_shown = lerpf(_ammo_shown, _ammo, clampf(delta * 14.0, 0.0, 1.0))
	_shot_flash = maxf(_shot_flash - delta * 5.0, 0.0)

	# Dash
	_dash_shown = lerpf(_dash_shown, _dash_p, clampf(delta * 20.0, 0.0, 1.0))
	var is_ready: bool = _dash_p >= 1.0
	if is_ready and not _was_ready:
		_dash_ready_flash = 1.0
	_was_ready = is_ready
	_dash_ready_flash = maxf(_dash_ready_flash - delta * 3.0, 0.0)

	queue_redraw()


# ==============================================================================
# PRIMITIVAS
# ==============================================================================

func _txt(pos: Vector2, text: String, fsize: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	draw_string_outline(FONT, pos, text, align, w, fsize, 7, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, col.a))
	draw_string(FONT, pos, text, align, w, fsize, col)


func _glow(pos: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, col)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _heart(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n: int = 28
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var sa: float = sin(a)
		var x: float = 16.0 * sa * sa * sa
		var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * (r / 17.0))
	draw_colored_polygon(pts, col)


## Corner "pontuda" (formato de projétil) para as células de munição.
func _cell(r: Rect2, frac: float, top: Color, bottom: Color) -> void:
	var w: float = r.size.x * frac
	if w < 1.5:
		return
	var tip: float = minf(7.0, w * 0.6)
	var x: float = r.position.x
	var y: float = r.position.y
	var h: float = r.size.y
	var mid: Color = top.lerp(bottom, 0.5)
	draw_polygon(
		PackedVector2Array([Vector2(x, y), Vector2(x + w - tip, y), Vector2(x + w, y + h * 0.5), Vector2(x + w - tip, y + h), Vector2(x, y + h)]),
		PackedColorArray([top, top, mid, bottom, bottom]))


# ==============================================================================
# DESENHO
# ==============================================================================

func _draw() -> void:
	var s: float = size.y / DESIGN_H * ui_scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var o: Vector2 = margin
	if anchor_bottom_left:
		o.y = size.y / s - margin.y - HUD_H
	_draw_health(o)
	_draw_ammo(o + Vector2(0.0, 70.0))
	_draw_dash(o + Vector2(0.0, 126.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_health(o: Vector2) -> void:
	var low: bool = _hp <= 1.0 and _hp > 0.0
	var beat: float = 1.0 + 0.10 * maxf(sin(_t * (9.0 if low else 3.2)), 0.0)

	# Ícone: coração pulsante
	var hc: Vector2 = o + Vector2(26.0, 24.0)
	_glow(hc, 46.0, 46.0, Color(1.0, 0.1, 0.15, 0.30 + 0.25 * _hurt_flash + (0.2 if low else 0.0)))
	_heart(hc + Vector2(2.0, 2.0), 22.0 * beat, Color(0.0, 0.0, 0.0, 0.5))
	_heart(hc, 21.0 * beat, Color(0.12, 0.0, 0.03))
	_heart(hc, 18.0 * beat, Color(0.92, 0.12, 0.20).lerp(Color.WHITE, _hurt_flash * 0.7))
	_heart(hc + Vector2(-3.0, -3.0), 7.0 * beat, Color(1.0, 0.7, 0.7, 0.35))

	# Moldura
	var bar := Rect2(o.x + BAR_X, o.y + 6.0, 330.0, 36.0)
	if low:
		_glow(bar.get_center(), 240.0, 50.0, Color(1.0, 0.05, 0.1, 0.12 + 0.12 * sin(_t * 9.0)))
	draw_style_box(_frame_red, bar.grow(4.0))
	var inner := Rect2(bar.position + Vector2(5.0, 5.0), bar.size - Vector2(10.0, 10.0))
	draw_rect(inner, Color(0.16, 0.02, 0.05))

	# Segmentos: um por ponto de vida
	var n: int = maxi(int(_hp_max), 1)
	var gap: float = 5.0
	var sw: float = (inner.size.x - gap * float(n - 1)) / float(n)
	for i in n:
		var sx: float = inner.position.x + float(i) * (sw + gap)
		var seg := Rect2(sx, inner.position.y, sw, inner.size.y)
		draw_rect(seg, Color(0.24, 0.04, 0.08))
		var gf: float = clampf(_hp_ghost - float(i), 0.0, 1.0)
		var f: float = clampf(_hp_shown - float(i), 0.0, 1.0)
		if gf > f:
			draw_rect(Rect2(seg.position, Vector2(seg.size.x * gf, seg.size.y)), Color(1.0, 0.88, 0.72, 0.85))
		if f > 0.0:
			var fr := Rect2(seg.position, Vector2(seg.size.x * f, seg.size.y))
			_vgrad(fr, BLOOD_TOP.lerp(Color.WHITE, _hurt_flash * 0.6), BLOOD_BOT)
			draw_rect(Rect2(fr.position + Vector2(0.0, 2.0), Vector2(fr.size.x, 3.0)), Color(1, 1, 1, 0.22))
			# gota de sangue pingando no segmento cheio
			if f >= 1.0:
				var dp: float = fposmod(_t * 0.35 + float(i) * 0.31, 1.0)
				if dp > 0.7:
					var k: float = (dp - 0.7) / 0.3
					draw_circle(Vector2(fr.position.x + fr.size.x * 0.5, fr.end.y + k * 10.0), 2.2 * (1.0 - k), Color(0.8, 0.05, 0.1, 0.9 * (1.0 - k)))

	# Contador
	_txt(Vector2(bar.end.x + 18.0, bar.position.y + 29.0), "%d/%d" % [int(ceilf(_hp)), int(_hp_max)], 30, GOLD)


func _draw_ammo(o: Vector2) -> void:
	var low: bool = _ammo / _ammo_max < 0.25
	var warn: float = 0.5 + 0.5 * sin(_t * 10.0)

	# Ícone: bala de prata
	var ic: Vector2 = o + Vector2(26.0, 28.0)
	_glow(ic, 38.0, 38.0, Color(0.4, 0.75, 1.0, 0.22 + 0.25 * _shot_flash))
	draw_rect(Rect2(ic.x - 8.0, ic.y - 2.0, 16.0, 22.0), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(ic.x - 7.0, ic.y - 4.0, 14.0, 22.0), BRASS)
	draw_rect(Rect2(ic.x - 7.0, ic.y + 12.0, 14.0, 3.0), Color(0.45, 0.30, 0.10))
	draw_rect(Rect2(ic.x - 4.0, ic.y - 4.0, 3.0, 22.0), Color(1, 1, 1, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(ic.x - 7.0, ic.y - 4.0), Vector2(ic.x, ic.y - 22.0), Vector2(ic.x + 7.0, ic.y - 4.0)]), SILVER_TOP.lerp(SILVER_BOT, 0.35))

	# Moldura de latão com rebites
	var bar := Rect2(o.x + BAR_X, o.y + 8.0, 330.0, 28.0)
	draw_style_box(_frame_brass, bar.grow(4.0))
	var inner := Rect2(bar.position + Vector2(5.0, 5.0), bar.size - Vector2(10.0, 10.0))
	draw_rect(inner, Color(0.03, 0.04, 0.07))
	for rv in [bar.position + Vector2(-1.0, -1.0), Vector2(bar.end.x + 1.0, bar.position.y - 1.0), Vector2(bar.position.x - 1.0, bar.end.y + 1.0), bar.end + Vector2(1.0, 1.0)]:
		draw_circle(rv, 2.6, BRASS.lightened(0.25))

	# Células em formato de projétil
	var gap: float = 3.0
	var cw: float = (inner.size.x - gap * float(AMMO_CELLS - 1)) / float(AMMO_CELLS)
	var level: float = _ammo_shown / _ammo_max * float(AMMO_CELLS)
	var tip_pos := Vector2(inner.position.x, inner.get_center().y)
	for i in AMMO_CELLS:
		var cx: float = inner.position.x + float(i) * (cw + gap)
		var cell := Rect2(cx, inner.position.y, cw, inner.size.y)
		_cell(cell, 1.0, Color(0.08, 0.09, 0.13), Color(0.05, 0.05, 0.08))
		var f: float = clampf(level - float(i), 0.0, 1.0)
		if f <= 0.0:
			continue
		var top: Color = SILVER_TOP
		var bot: Color = SILVER_BOT
		if low:
			top = Color(1.0, 0.55, 0.35).lerp(Color(1.0, 0.9, 0.8), warn * 0.5)
			bot = Color(0.75, 0.10, 0.10)
		# varredura de brilho enquanto regenera
		var sweep: float = maxf(sin(_t * 9.0 - float(i) * 0.55), 0.0) * _regen
		top = top.lerp(Color.WHITE, clampf(sweep * 0.8 + _shot_flash * 0.7, 0.0, 1.0))
		bot = bot.lerp(Color(0.8, 0.95, 1.0), clampf(sweep * 0.5 + _shot_flash * 0.4, 0.0, 1.0))
		_cell(cell, f, top, bot)
		tip_pos = Vector2(cx + cw * f, inner.get_center().y)
	# brilho elétrico na ponta do nível atual
	if level > 0.05:
		var gcol := Color(1.0, 0.45, 0.3, 0.45) if low else Color(0.5, 0.85, 1.0, 0.40)
		_glow(tip_pos, 26.0, 20.0, Color(gcol.r, gcol.g, gcol.b, gcol.a + 0.3 * _shot_flash))

	# Número
	var num_col: Color = Color(1.0, 0.45, 0.35) if low else Color(0.85, 0.95, 1.0)
	_txt(Vector2(bar.end.x + 18.0, bar.position.y + 24.0), "%d" % int(ceilf(_ammo)), 28, num_col)
	if _regen > 0.1:
		_txt(Vector2(bar.end.x + 70.0, bar.position.y + 22.0), "recarregando", 18, Color(0.6, 0.85, 1.0, 0.45 + 0.4 * _regen))
	elif low and _ammo > 0.0:
		_txt(Vector2(bar.end.x + 70.0, bar.position.y + 22.0), "pouca prata!", 18, Color(1.0, 0.45, 0.35, 0.5 + 0.5 * warn))


func _draw_dash(o: Vector2) -> void:
	var is_ready: bool = _dash_p >= 1.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)

	# Ícone: setas duplas
	var ic: Vector2 = o + Vector2(26.0, 18.0)
	_glow(ic, 36.0, 36.0, Color(0.65, 0.30, 1.0, (0.20 + 0.20 * pulse) if is_ready else 0.08))
	var ic_col: Color = VIOLET_TOP if is_ready else Color(0.45, 0.30, 0.65)
	for j in 2:
		var dx: float = float(j) * 12.0 - 8.0
		draw_polyline(PackedVector2Array([ic + Vector2(dx - 6.0, -12.0), ic + Vector2(dx + 6.0, 0.0), ic + Vector2(dx - 6.0, 12.0)]), Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.9), 8.0, true)
		draw_polyline(PackedVector2Array([ic + Vector2(dx - 6.0, -12.0), ic + Vector2(dx + 6.0, 0.0), ic + Vector2(dx - 6.0, 12.0)]), ic_col, 4.0, true)

	# Moldura roxa (barra mais fina)
	var bar := Rect2(o.x + BAR_X, o.y + 6.0, 250.0, 20.0)
	if is_ready:
		_glow(bar.get_center(), 190.0, 34.0, Color(0.6, 0.25, 1.0, 0.16 + 0.14 * pulse + 0.4 * _dash_ready_flash))
	draw_style_box(_frame_violet, bar.grow(4.0))
	var inner := Rect2(bar.position + Vector2(4.0, 4.0), bar.size - Vector2(8.0, 8.0))
	draw_rect(inner, Color(0.10, 0.04, 0.18))

	if _dash_shown > 0.0:
		var fr := Rect2(inner.position, Vector2(inner.size.x * _dash_shown, inner.size.y))
		var top: Color = VIOLET_TOP if is_ready else VIOLET_TOP.darkened(0.30)
		var bot: Color = VIOLET_BOT if is_ready else VIOLET_BOT.darkened(0.15)
		top = top.lerp(Color.WHITE, _dash_ready_flash * 0.8)
		_vgrad(fr, top, bot)
		draw_rect(Rect2(fr.position + Vector2(0.0, 1.0), Vector2(fr.size.x, 2.0)), Color(1, 1, 1, 0.28))
		# faixa de energia deslizando enquanto carrega
		if not is_ready:
			var sx: float = fr.position.x + fposmod(_t * 60.0, maxf(fr.size.x, 1.0))
			draw_rect(Rect2(sx, fr.position.y, 8.0, fr.size.y).intersection(fr), Color(1, 1, 1, 0.18))
			_glow(Vector2(fr.end.x, fr.get_center().y), 16.0, 16.0, Color(0.8, 0.5, 1.0, 0.45))

	# Marcadores a cada 25%
	for q in 3:
		var qx: float = inner.position.x + inner.size.x * 0.25 * float(q + 1)
		draw_line(Vector2(qx, inner.position.y), Vector2(qx, inner.end.y), Color(0.0, 0.0, 0.0, 0.35), 2.0)

	# Texto + tecla
	var key := Rect2(bar.end.x + 20.0, bar.position.y - 5.0, 76.0, 30.0)
	draw_style_box(_key_style, key)
	_txt(Vector2(key.position.x, key.position.y + 22.0), "SHIFT", 18, Color(1, 1, 1, 0.9 if is_ready else 0.5), HORIZONTAL_ALIGNMENT_CENTER, key.size.x)
	if is_ready:
		_txt(Vector2(key.end.x + 14.0, bar.position.y + 17.0), "pronto", 20, Color(0.85, 0.60, 1.0, 0.7 + 0.3 * pulse))
