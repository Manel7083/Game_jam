class_name Level3IntroCinematic
extends Control
## Wolf Down - Cutscene de abertura do Nível 3 (arena do Drácula)  ·  versão cinematográfica.
##
## Estrutura (3 planos, ~16 s):
##   0  Exterior: tempestade, lua de sangue, o castelo e o caçador subindo a estrada
##   1  O portão se abre sozinho (raios de luz, névoa, passos sincronizados)
##   2  Salão do trono: o Conde ergue a cabeça e fala com o caçador; fade para a luta
##
## Arte 100% procedural em _draw(), num canvas virtual de 1920x1080 que escala para qualquer
## resolução. Nenhum asset de imagem é necessário. Os sons são opcionais: se os .wav não
## existirem, a cutscene toca em silêncio.
##
## Uso (ver level_3.gd): Level3IntroCinematic.new(), adicionar a um CanvasLayer e esperar o
## sinal `finished`. Qualquer tecla / clique / botão do controle pula (após 0,8 s).

signal finished

const S_EXTERIOR: int = 0
const S_GATE: int = 1
const S_THRONE: int = 2

const DESIGN_H: float = 1080.0
const PAD: float = 360.0
const BAR_H: float = 76.0
const TYPE_SPEED: float = 0.032
const SKIP_LOCK: float = 0.8
const AUDIO_DIR: String = "res://audio/"

const GOLD: Color = Color(1.0, 0.82, 0.45)
const BLOOD: Color = Color(0.85, 0.12, 0.16)
const DRAC_COL: Color = Color(1.0, 0.36, 0.42)
const FUR: Color = Color(0.22, 0.10, 0.30)
const FUR_LIGHT: Color = Color(0.36, 0.19, 0.46)

const SFX_FILES: Dictionary = {
	"gate": "l3_intro_gate.wav",
	"beat": "l3_intro_heartbeat.wav",
	"fury": "l3_intro_fury.wav",
	"howl": "l3_intro_howl.wav",
	"thunder": "thunder.wav",
	"wind": "l3_intro_wind.wav",
	"step": "l3_intro_step.wav",
	"rumble": "l3_intro_rumble.wav",
	"impact": "l3_intro_impact.wav",
}
const SFX_VOLUME: Dictionary = {
	"gate": -3.0, "beat": -2.0, "fury": -4.0, "howl": -2.0, "thunder": -6.0,
	"wind": -8.0, "step": -9.0, "rumble": -5.0, "impact": -2.0,
}

const SHOT_DURATION: Array[float] = [5.0, 4.6, 6.4]
const FADE_IN: Array[float] = [1.2, 0.35, 0.0]
const FADE_OUT: Array[float] = [0.35, 0.35, 0.9]
const ZOOM_FROM: Array[float] = [1.00, 1.00, 1.00]
const ZOOM_TO: Array[float] = [1.14, 1.16, 1.14]
const PAN_TO: Array[Vector2] = [Vector2(0, 30), Vector2(0, 40), Vector2(0, 30)]

const TITLES: Array[String] = [
	"O CASTELO DO DRÁCULA", "", "O SALÃO DO TRONO",
]

# Legendas: plano -> [[início, fim, quem fala ("" = narração), texto], ...]
const LINES: Dictionary = {
	0: [[1.2, 4.8, "", "Depois de tantas noites de caçada,\no Lobo chegou ao fim do caminho."]],
	1: [[0.8, 4.3, "", "Os portões do castelo se abriram diante dele,\ncomo se o próprio Conde o convidasse a entrar."]],
	2: [[1.4, 5.7, "DRÁCULA", "Eu o esperava, caçador.\nDemorou mais do que eu imaginava."]],
}

# Eventos por plano: [tempo no plano, tipo, intensidade, (som)]
# tipos: kick (tranco de câmera) | flash (clarão + trovão) | bolt (raio) | sfx (toca um som)
const EVENTS: Dictionary = {
	0: [[0.0, "sfx", 0.0, "wind"], [1.4, "bolt", 0.8], [3.6, "bolt", 1.0]],
	1: [
		[0.0, "sfx", 0.0, "gate"], [0.6, "sfx", 0.0, "step"], [1.2, "sfx", 0.0, "step"],
		[1.8, "sfx", 0.0, "step"], [2.4, "sfx", 0.0, "step"], [3.0, "sfx", 0.0, "step"],
		[3.6, "sfx", 0.0, "step"], [0.8, "kick", 0.5],
	],
	2: [[0.0, "sfx", 0.0, "rumble"], [3.0, "kick", 0.5]],
}

var _shot: int = 0
var _elapsed: float = 0.0
var _total: float = 0.0
var _scale: float = 1.0
var _vw: float = 1920.0
var _fade: float = 1.0
var _flash: float = 0.0
var _kick: float = 0.0
var _bars: float = 0.0
var _bolt: float = 0.0
var _bolt_seed: float = 1.0
var _talk: float = 0.0
var _line_idx: int = -1
var _beat_next: float = 0.5
var _beat_times: Array[float] = []
var _fired: Dictionary = {}
var _finishing: bool = false
var _finish_t: float = 0.0
var _done: bool = false
var _last_size: Vector2 = Vector2.ZERO

var _glow_tex: GradientTexture2D
var _vignette_tex: GradientTexture2D
var _blood_tex: GradientTexture2D
var _sfx_players: Dictionary = {}

var _title_label: Label
var _speaker_label: Label
var _story_label: Label
var _hint_label: Label


# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make_textures()
	_build_ui()
	_load_audio()
	_begin_shot()
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	_total += delta
	if size != _last_size:
		_last_size = size
		_layout()
	_scale = size.y / DESIGN_H
	_vw = size.x / maxf(_scale, 0.001)
	_bars = BAR_H * _smooth(_total / 1.1)

	if _finishing:
		_finish_t += delta
		if _finish_t >= 0.35:
			_emit_finished()
			return
	else:
		_elapsed += delta
		if _elapsed >= SHOT_DURATION[_shot]:
			if _shot < SHOT_DURATION.size() - 1:
				_shot += 1
				_begin_shot()
			else:
				_finishing = true

	_flash = maxf(_flash - delta * 2.6, 0.0)
	_kick = maxf(_kick - delta * 2.2, 0.0)
	_bolt = maxf(_bolt - delta * 3.2, 0.0)
	_run_events()
	_update_fade()
	_update_text()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed: bool = false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	# Consome a tecla (inclusive Esc) para o menu de pause não abrir por cima da cutscene.
	get_viewport().set_input_as_handled()
	if _total >= SKIP_LOCK and not _finishing:
		_finishing = true
		_finish_t = 0.0


func _emit_finished() -> void:
	if _done:
		return
	_done = true
	for key in _sfx_players.keys():
		var p: Variant = _sfx_players[key]
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
	finished.emit()


func _begin_shot() -> void:
	_elapsed = 0.0
	_beat_times.clear()
	_beat_next = 0.5
	_line_idx = -1
	_story_label.text = ""
	_speaker_label.text = ""
	var ttl: String = TITLES[_shot]
	_title_label.text = ttl
	_title_label.visible = ttl != ""


func _run_events() -> void:
	if _finishing:
		return
	var evs: Array = EVENTS.get(_shot, [])
	for i in evs.size():
		var key: int = _shot * 100 + i
		if _fired.has(key):
			continue
		var ev: Array = evs[i]
		var at_t: float = ev[0]
		if _elapsed < at_t:
			continue
		_fired[key] = true
		var kind: String = ev[1]
		var amt: float = ev[2]
		match kind:
			"flash":
				_flash = maxf(_flash, amt)
				_kick = maxf(_kick, amt)
				_sfx("thunder")
			"bolt":
				_bolt = 1.0
				_bolt_seed = float(_shot) * 17.0 + float(i) * 3.3 + 1.0
				_flash = maxf(_flash, amt * 0.7)
				_kick = maxf(_kick, amt * 0.8)
				_sfx("thunder")
			"sfx":
				_sfx(String(ev[3]))
			_:
				_kick = maxf(_kick, amt)


func _update_fade() -> void:
	var dur: float = SHOT_DURATION[_shot]
	var in_len: float = FADE_IN[_shot]
	var out_len: float = FADE_OUT[_shot]
	var f_in: float = 0.0
	if in_len > 0.0:
		f_in = 1.0 - clampf(_elapsed / in_len, 0.0, 1.0)
	var f_out: float = 0.0
	if out_len > 0.0:
		f_out = clampf((_elapsed - (dur - out_len)) / out_len, 0.0, 1.0)
	_fade = maxf(f_in, f_out)
	if _finishing:
		_fade = maxf(_fade, clampf(_finish_t / 0.35, 0.0, 1.0))


func _update_text() -> void:
	var dur: float = SHOT_DURATION[_shot]
	var vis: float = 1.0 - _fade
	var lines: Array = LINES.get(_shot, [])

	# legenda ativa neste instante
	var idx: int = -1
	for i in lines.size():
		var ln: Array = lines[i]
		if _elapsed >= float(ln[0]) and _elapsed < float(ln[1]):
			idx = i
	if idx != _line_idx:
		_line_idx = idx
		if idx >= 0:
			var cur: Array = lines[idx]
			var who: String = String(cur[2])
			_story_label.text = String(cur[3])
			_story_label.visible_characters = 0
			_speaker_label.text = who
			_speaker_label.visible = who != ""
		else:
			_story_label.text = ""
			_speaker_label.text = ""

	var talk_target: float = 0.0
	if _line_idx >= 0:
		var ln2: Array = lines[_line_idx]
		var local: float = _elapsed - float(ln2[0])
		var shown: int = int(local / TYPE_SPEED)
		_story_label.visible_characters = shown
		var a: float = clampf(local / 0.25, 0.0, 1.0)
		a *= 1.0 - clampf((_elapsed - (float(ln2[1]) - 0.4)) / 0.4, 0.0, 1.0)
		_story_label.modulate.a = a * vis
		_speaker_label.modulate.a = a * vis
		if String(ln2[2]) != "" and shown < _story_label.text.length():
			talk_target = 0.25 + 0.75 * absf(sin(_total * 12.0 + sin(_total * 3.1) * 2.0))
	else:
		_story_label.modulate.a = 0.0
		_speaker_label.modulate.a = 0.0
	_talk = lerpf(_talk, talk_target, 0.4)

	var title_out: float = 1.0 - clampf((_elapsed - (dur - 0.7)) / 0.5, 0.0, 1.0)
	_title_label.modulate.a = title_out * clampf((_elapsed - 0.5) / 0.7, 0.0, 1.0) * vis
	var hint_a: float = 0.7 if _total < 8.0 else 0.35
	_hint_label.modulate.a = hint_a * vis * clampf((_total - 0.8) / 0.6, 0.0, 1.0)


# ==============================================================================
# RECURSOS, INTERFACE E ÁUDIO
# ==============================================================================

func _make_textures() -> void:
	_glow_tex = _radial([0.0, 0.35, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	_vignette_tex = _radial([0.0, 0.5, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.9)])
	_blood_tex = _radial([0.0, 0.45, 1.0], [Color(0.8, 0.0, 0.05, 0), Color(0.8, 0.0, 0.05, 0), Color(0.8, 0.0, 0.05, 0.85)])


func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _build_ui() -> void:
	_title_label = UIKit.make_label("", 36, GOLD)
	_speaker_label = UIKit.make_label("", 28, Color.WHITE)
	_speaker_label.self_modulate = DRAC_COL
	_story_label = UIKit.make_label("", 36, UIKit.TEXT)
	_hint_label = UIKit.make_label("QUALQUER TECLA  -  PULAR", 20, UIKit.TEXT_DIM)
	for l in [_title_label, _speaker_label, _story_label, _hint_label]:
		add_child(l)
	_speaker_label.visible = false
	_layout()


func _layout() -> void:
	var s: float = maxf(size.y / DESIGN_H, 0.1)
	_fit(_title_label, 36, 0.0, 104.0, 60.0, s)
	_fit(_speaker_label, 28, 1.0, -300.0, 46.0, s)
	_fit(_story_label, 36, 1.0, -252.0, 150.0, s)
	_fit(_hint_label, 20, 1.0, -62.0, 30.0, s)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.offset_right = -40.0 * s


func _fit(label: Label, font_px: int, anchor_y: float, top_px: float, h_px: float, s: float) -> void:
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = anchor_y
	label.anchor_bottom = anchor_y
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = top_px * s
	label.offset_bottom = (top_px + h_px) * s
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if label.label_settings != null:
		label.label_settings.font_size = maxi(int(round(float(font_px) * s)), 8)


func _load_audio() -> void:
	var bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for key in SFX_FILES.keys():
		var path: String = AUDIO_DIR + String(SFX_FILES[key])
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = bus
		p.volume_db = float(SFX_VOLUME.get(key, 0.0))
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players[String(key)] = p


func _sfx(key: String) -> void:
	var p: Variant = _sfx_players.get(key)
	if p is AudioStreamPlayer:
		(p as AudioStreamPlayer).play()


# ==============================================================================
# UTILIDADES DE DESENHO
# ==============================================================================

func _smooth(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _rnd(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 78.233) * 43758.5453, 1.0)


func _flick(sd: float, speed: float = 9.0) -> float:
	return 0.82 + 0.12 * sin(_total * speed + sd * 6.1) + 0.06 * sin(_total * speed * 2.3 + sd * 3.7)


func _shake_offset(_u: float) -> Vector2:
	var amp: float = 0.4 + _kick * 14.0
	var drift := Vector2(sin(_total * 0.7) * 5.0, cos(_total * 0.55) * 4.0)
	return Vector2(sin(_total * 61.0), sin(_total * 77.0 + 2.0)) * amp + drift


func _xf(pts: PackedVector2Array, base: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(base + p * k)
	return out


func _xfr(pts: PackedVector2Array, base: Vector2, k: float, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: float = cos(ang)
	var sn: float = sin(ang)
	for p in pts:
		out.append(base + Vector2(p.x * c - p.y * sn, p.x * sn + p.y * c) * k)
	return out


func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _glow(pos: Vector2, radius: float, col: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## Arco gótico (ogiva equilátera). Base em base_y, início da curva em spring_y.
func _arch_points(cx: float, base_y: float, spring_y: float, hw: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(cx - hw, base_y))
	pts.append(Vector2(cx - hw, spring_y))
	var steps: int = 14
	var max_a: float = deg_to_rad(60.0)
	for i in range(1, steps + 1):
		var a: float = max_a * float(i) / float(steps)
		pts.append(Vector2(cx + hw - 2.0 * hw * cos(a), spring_y - 2.0 * hw * sin(a)))
	for i in range(steps - 1, -1, -1):
		var a2: float = max_a * float(i) / float(steps)
		pts.append(Vector2(cx - hw + 2.0 * hw * cos(a2), spring_y - 2.0 * hw * sin(a2)))
	pts.append(Vector2(cx + hw, base_y))
	return pts


func _flame(pos: Vector2, s: float, outer: Color, inner: Color, sd: float) -> void:
	var f: float = _flick(sd, 11.0)
	_glow(pos + Vector2(0, -s * 0.6), s * 4.4 * f, Color(outer.r, outer.g, outer.b, 0.36 * f))
	var sway: float = sin(_total * 7.0 + sd * 2.0) * 0.12
	var o := PackedVector2Array([
		Vector2(-0.45, 0.0), Vector2(-0.40, -0.55), Vector2(-0.12 + sway, -1.0),
		Vector2(sway * 2.0, -1.45 * f), Vector2(0.18 + sway, -0.95), Vector2(0.42, -0.5), Vector2(0.45, 0.0)])
	draw_colored_polygon(_xf(o, pos, s), outer)
	var i := PackedVector2Array([
		Vector2(-0.22, 0.0), Vector2(-0.20, -0.4), Vector2(0.0, -0.85 * f), Vector2(0.2, -0.4), Vector2(0.22, 0.0)])
	draw_colored_polygon(_xf(i, pos, s), inner)


func _bat(pos: Vector2, s: float, phase: float, col: Color) -> void:
	var flap: float = sin(phase)
	for i in 2:
		var sx: float = -1.0 + 2.0 * float(i)
		var t1 := PackedVector2Array([Vector2(0, 0), Vector2(sx * 1.3, -0.3 - 0.9 * flap), Vector2(sx * 0.7, 0.35)])
		var t2 := PackedVector2Array([Vector2(0, -0.1), Vector2(sx * 0.5, -0.55 - 0.45 * flap), Vector2(sx * 1.3, -0.3 - 0.9 * flap)])
		draw_colored_polygon(_xf(t1, pos, s), col)
		draw_colored_polygon(_xf(t2, pos, s), col)
	_ellipse(pos, s * 0.16, s * 0.28, col)


func _embers(count: int, x0: float, x1: float, y_base: float, rise: float, col: Color) -> void:
	for i in count:
		var fi: float = float(i)
		var life: float = fposmod(_total * rise * (0.4 + _rnd(fi + 3.0)) + _rnd(fi) * 900.0, 900.0)
		var p: float = life / 900.0
		var x: float = lerpf(x0, x1, _rnd(fi + 11.0)) + sin(_total * 1.3 + fi) * 24.0
		var a: float = sin(p * PI) * 0.8
		draw_circle(Vector2(x, y_base - life), 1.8 + 2.4 * _rnd(fi + 21.0), Color(col.r, col.g, col.b, a))


## Partículas de poeira flutuando no ar (dá profundidade e "vida" ao plano).
func _dust(count: int, x0: float, x1: float, y0: float, y1: float, col: Color) -> void:
	for i in count:
		var fi: float = float(i)
		var px: float = lerpf(x0, x1, fposmod(_rnd(fi) + _total * 0.004 * (0.3 + _rnd(fi + 5.0)), 1.0))
		var py: float = lerpf(y0, y1, fposmod(_rnd(fi + 9.0) - _total * 0.002 * (0.3 + _rnd(fi + 2.0)), 1.0))
		py += sin(_total * 0.8 + fi) * 14.0
		var a: float = (0.12 + 0.35 * _rnd(fi + 3.0)) * (0.5 + 0.5 * sin(_total * 1.5 + fi))
		draw_circle(Vector2(px, py), 1.2 + 1.8 * _rnd(fi + 7.0), Color(col.r, col.g, col.b, a))


## Feixes de luz (god rays) saindo de um ponto.
func _rays(origin: Vector2, a0: float, a1: float, length: float, count: int, col: Color, sd: float) -> void:
	for i in count:
		var fi: float = float(i)
		var a: float = lerpf(a0, a1, (fi + _rnd(fi + sd)) / float(count))
		var w: float = deg_to_rad(1.2 + 2.2 * _rnd(fi + sd + 20.0))
		var k: float = 0.55 + 0.45 * sin(_total * 0.7 + fi * 1.7 + sd)
		var p1: Vector2 = origin + Vector2(cos(a - w), sin(a - w)) * length
		var p2: Vector2 = origin + Vector2(cos(a + w), sin(a + w)) * length
		var c0 := Color(col.r, col.g, col.b, col.a * k)
		var c1 := Color(col.r, col.g, col.b, 0.0)
		draw_polygon(PackedVector2Array([origin, p1, p2]), PackedColorArray([c0, c1, c1]))


## Faixas de névoa / nuvens que derivam lateralmente.
func _fog_layer(y: float, h: float, col: Color, speed: float, count: int, sd: float) -> void:
	var span: float = _vw + 1000.0
	for i in count:
		var fi: float = float(i) + sd
		var x: float = fposmod(float(i) * span / float(count) + _total * speed * (0.7 + _rnd(fi)), span) - 500.0
		var w: float = 900.0 + 600.0 * _rnd(fi + 3.0)
		var yy: float = y + sin(_total * 0.35 + fi) * 18.0 + (_rnd(fi + 8.0) - 0.5) * h * 0.6
		draw_texture_rect(_glow_tex, Rect2(x - w * 0.5, yy - h * 0.5, w, h), false, col)


## Granulação de filme (muda a 24 quadros por segundo).
func _grain() -> void:
	var frame: float = floorf(_total * 24.0)
	for i in 110:
		var fi: float = float(i)
		var gx: float = _rnd(fi * 3.17 + frame * 7.31) * _vw
		var gy: float = _rnd(fi * 5.51 + frame * 1.93 + 9.0) * DESIGN_H
		var ga: float = 0.04 + 0.07 * _rnd(fi + frame)
		draw_rect(Rect2(gx, gy, 2.5, 2.5), Color(1.0, 1.0, 1.0, ga))


func _stars(count: int, sd: float, y_max: float) -> void:
	for i in count:
		var fi: float = float(i) + sd
		var sp := Vector2(_rnd(fi) * (_vw + 200.0) - 100.0, _rnd(fi + 50.0) * y_max)
		var a: float = 0.25 + 0.55 * _rnd(fi + 90.0) * (0.6 + 0.4 * sin(_total * (1.0 + _rnd(fi)) * 2.0 + fi))
		draw_circle(sp, 0.9 + 1.3 * _rnd(fi + 7.0), Color(1.0, 0.85, 0.85, a))


func _rain(count: int, alpha: float) -> void:
	for i in count:
		var fi: float = float(i)
		var ry: float = fposmod(_rnd(fi + 3.0) * (DESIGN_H + 300.0) + _total * (1500.0 + 500.0 * _rnd(fi + 5.0)), DESIGN_H + 300.0) - 150.0
		var rx: float = _rnd(fi) * (_vw + 500.0) - 250.0 - ry * 0.12
		draw_line(Vector2(rx, ry), Vector2(rx - 9.0, ry + 40.0), Color(0.75, 0.78, 0.95, alpha), 1.6)


func _ridge(base_y: float, amp: float, sd: float, col: Color, shift: float) -> void:
	var pts := PackedVector2Array()
	var x: float = -PAD - 80.0
	while x <= _vw + PAD + 80.0:
		var xx: float = x + shift
		var h: float = amp * (0.55 + 0.30 * sin(xx * 0.0042 + sd) + 0.15 * sin(xx * 0.0131 + sd * 2.3))
		pts.append(Vector2(x, base_y - h))
		x += 60.0
	pts.append(Vector2(_vw + PAD + 80.0, DESIGN_H + PAD))
	pts.append(Vector2(-PAD - 80.0, DESIGN_H + PAD))
	draw_colored_polygon(pts, col)


func _branch(p: Vector2, ang: float, length: float, w: float, depth: int, col: Color, sd: float) -> void:
	if depth <= 0 or length < 6.0:
		return
	var sway: float = sin(_total * 0.8 + sd + float(depth)) * 0.03
	var e: Vector2 = p + Vector2(cos(ang + sway), sin(ang + sway)) * length
	draw_line(p, e, col, w)
	_branch(e, ang - 0.46 + 0.25 * (_rnd(sd + float(depth)) - 0.5), length * 0.72, w * 0.7, depth - 1, col, sd * 1.3 + 1.0)
	_branch(e, ang + 0.40 + 0.25 * (_rnd(sd + float(depth) * 2.0) - 0.5), length * 0.70, w * 0.7, depth - 1, col, sd * 1.7 + 2.0)


func _bolt_draw() -> void:
	if _bolt <= 0.01:
		return
	var x: float = _vw * 0.5 + (_rnd(_bolt_seed) - 0.5) * 900.0
	var pts := PackedVector2Array()
	var y: float = -40.0
	while y < 720.0:
		pts.append(Vector2(x, y))
		x += (_rnd(_bolt_seed + y) - 0.5) * 130.0
		y += 70.0 + 50.0 * _rnd(_bolt_seed + y * 2.0)
	pts.append(Vector2(x, 740.0))
	draw_polyline(pts, Color(0.75, 0.70, 1.0, _bolt * 0.35), 18.0)
	draw_polyline(pts, Color(0.95, 0.92, 1.0, _bolt), 5.0)


func _chandelier(pos: Vector2, k: float, sd: float) -> void:
	var metal := Color(0.45, 0.30, 0.14)
	draw_line(Vector2(pos.x, -PAD), pos, Color(0.03, 0.015, 0.04), 5.0 * k)
	var ring: Vector2 = pos + Vector2(sin(_total * 0.9 + sd) * 6.0 * k, 0.0)
	draw_arc(ring + Vector2(0.0, 24.0 * k), 90.0 * k, 0.0, PI, 24, metal, 7.0 * k)
	draw_line(ring + Vector2(-90.0 * k, 24.0 * k), ring + Vector2(90.0 * k, 24.0 * k), metal, 6.0 * k)
	for i in 5:
		var fx: float = ring.x + (-80.0 + 40.0 * float(i)) * k
		var fy: float = ring.y + 24.0 * k
		draw_rect(Rect2(fx - 4.0 * k, fy - 22.0 * k, 8.0 * k, 22.0 * k), Color(0.85, 0.80, 0.70))
		_flame(Vector2(fx, fy - 22.0 * k), 9.0 * k, Color(1.0, 0.55, 0.2), Color(1.0, 0.9, 0.5), sd + float(i))


func _castle(cx: float, by: float, k: float, col: Color) -> void:
	var wall_h: float = 150.0 * k
	draw_rect(Rect2(cx - 560.0 * k, by - wall_h, 1120.0 * k, wall_h + 6.0), col)
	for i in 22:
		draw_rect(Rect2(cx - 560.0 * k + float(i) * 52.0 * k, by - wall_h - 26.0 * k, 30.0 * k, 26.0 * k), col)
	# torres: [deslocamento x, largura, altura, altura do telhado]
	var towers: Array = [
		[-470.0, 110.0, 380.0, 170.0], [-300.0, 84.0, 300.0, 130.0],
		[-120.0, 120.0, 470.0, 200.0], [100.0, 150.0, 640.0, 270.0],
		[300.0, 90.0, 340.0, 140.0], [480.0, 120.0, 420.0, 180.0]]
	for i in towers.size():
		var tw: Array = towers[i]
		var tx: float = cx + float(tw[0]) * k
		var w: float = float(tw[1]) * k
		var h: float = float(tw[2]) * k
		var rh: float = float(tw[3]) * k
		draw_rect(Rect2(tx - w * 0.5, by - h, w, h), col)
		draw_rect(Rect2(tx - w * 0.5 - 10.0 * k, by - h - 14.0 * k, w + 20.0 * k, 18.0 * k), col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - w * 0.5 - 16.0 * k, by - h), Vector2(tx + w * 0.5 + 16.0 * k, by - h),
			Vector2(tx, by - h - rh)]), col)
		draw_line(Vector2(tx, by - h - rh), Vector2(tx, by - h - rh - 46.0 * k), col, 4.0 * k)
		var f: float = _flick(float(i), 5.0 + float(i))
		var wy: float = by - h * 0.62
		_glow(Vector2(tx, wy + 17.0 * k), 70.0 * k, Color(1.0, 0.5, 0.2, 0.20 * f))
		draw_rect(Rect2(tx - 7.0 * k, wy, 14.0 * k, 34.0 * k), Color(1.0, 0.62, 0.22, 0.85 * f))
		if h > 420.0 * k:
			draw_rect(Rect2(tx - 7.0 * k, by - h * 0.86, 14.0 * k, 34.0 * k), Color(1.0, 0.55, 0.22, 0.7 * f))
	# portão iluminado
	_glow(Vector2(cx, by - 60.0 * k), 170.0 * k, Color(1.0, 0.35, 0.2, 0.30))
	draw_colored_polygon(_arch_points(cx, by, by - 70.0 * k, 50.0 * k), Color(1.0, 0.42, 0.2, 0.85))


## Caçador (a Lenda) visto de costas: capa longa e chapéu. Silhueta de uma cor só.
func _hunter_back(base: Vector2, k: float, col: Color) -> void:
	var sway: float = sin(_total * 2.0) * 9.0
	var cape := PackedVector2Array([
		Vector2(-62, -300), Vector2(62, -300), Vector2(78, -230), Vector2(112, -120),
		Vector2(134 + sway, -8), Vector2(66, 2), Vector2(0, -6), Vector2(-66, 2),
		Vector2(-134 + sway, -8), Vector2(-112, -120), Vector2(-78, -230)])
	draw_colored_polygon(_xf(cape, base, k), col)
	_ellipse(base + Vector2(0, -336) * k, 30.0 * k, 33.0 * k, col)
	_ellipse(base + Vector2(0, -356) * k, 74.0 * k, 12.0 * k, col)
	var crown := PackedVector2Array([Vector2(-36, -358), Vector2(-30, -424), Vector2(30, -424), Vector2(36, -358)])
	draw_colored_polygon(_xf(crown, base, k), col)
	if col.a > 0.9:
		# dobras da capa e faixa do chapéu (só na silhueta principal)
		var fold := Color(0.07, 0.04, 0.10)
		for i in 3:
			var fx: float = -42.0 + 42.0 * float(i)
			draw_line(base + Vector2(fx, -280.0) * k, base + Vector2(fx * 2.2 + sway * 0.8, -16.0) * k, fold, 3.0 * k)
		draw_rect(Rect2(base + Vector2(-35, -382) * k, Vector2(70, 14) * k), Color(0.30, 0.04, 0.08))


# ==============================================================================
# DESENHO PRINCIPAL
# ==============================================================================

func _draw() -> void:
	var s: float = _scale
	if s <= 0.0:
		return
	var dur: float = SHOT_DURATION[_shot]
	var u: float = clampf(_elapsed / dur, 0.0, 1.0)
	var z: float = lerpf(ZOOM_FROM[_shot], ZOOM_TO[_shot], _smooth(u))
	var pan: Vector2 = PAN_TO[_shot] * _smooth(u)
	var center := Vector2(_vw * 0.5, DESIGN_H * 0.5)
	var origin: Vector2 = size * 0.5 - center * (z * s) + (pan + _shake_offset(u)) * s

	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	draw_set_transform(origin, 0.0, Vector2(z * s, z * s))
	match _shot:
		S_EXTERIOR:
			_scene_exterior(u)
		S_GATE:
			_scene_gate(u)
		S_THRONE:
			_scene_throne(u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	_draw_overlay(u)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_overlay(_u: float) -> void:
	var w: float = _vw
	var full := Rect2(0.0, 0.0, w, DESIGN_H)
	draw_texture_rect(_vignette_tex, full, false, Color(1, 1, 1, 0.95))
	_vgrad(Rect2(0.0, DESIGN_H - 380.0, w, 380.0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8))
	_grain()
	draw_rect(Rect2(0.0, 0.0, w, _bars), Color.BLACK)
	draw_rect(Rect2(0.0, DESIGN_H - _bars, w, _bars), Color.BLACK)
	if _flash > 0.01:
		draw_rect(full, Color(1.0, 0.92, 0.88, clampf(_flash, 0.0, 1.0)))
	if _fade > 0.001:
		draw_rect(full, Color(0, 0, 0, clampf(_fade, 0.0, 1.0)))


# ==============================================================================
# PLANO 0 - EXTERIOR: A TEMPESTADE E O CASTELO
# ==============================================================================

func _scene_exterior(u: float) -> void:
	var cx: float = _vw * 0.5
	var t: float = _smooth(u)
	_vgrad(Rect2(-PAD, -PAD, _vw + PAD * 2.0, DESIGN_H + PAD * 2.0), Color(0.015, 0.008, 0.045), Color(0.24, 0.045, 0.10))
	_stars(80, 11.0, 620.0)

	# lua de sangue
	var moon := Vector2(cx - 460.0 - t * 30.0, 270.0)
	_glow(moon, 620.0, Color(1.0, 0.16, 0.20, 0.30))
	draw_circle(moon, 150.0, Color(0.92, 0.20, 0.24))
	draw_circle(moon + Vector2(-34.0, -30.0), 112.0, Color(1.0, 0.36, 0.34, 0.55))
	draw_circle(moon + Vector2(50.0, 40.0), 26.0, Color(0.55, 0.06, 0.12, 0.5))
	draw_circle(moon + Vector2(-60.0, 50.0), 18.0, Color(0.55, 0.06, 0.12, 0.5))
	draw_circle(moon + Vector2(20.0, -70.0), 14.0, Color(0.55, 0.06, 0.12, 0.5))
	if _bolt > 0.01:
		draw_rect(Rect2(-PAD, -PAD, _vw + PAD * 2.0, 1100.0), Color(0.55, 0.45, 0.85, 0.28 * _bolt))

	# nuvens passando na frente da lua e o raio
	_fog_layer(250.0, 190.0, Color(0.04, 0.01, 0.06, 0.70), 12.0, 6, 3.0)
	_fog_layer(430.0, 230.0, Color(0.10, 0.02, 0.09, 0.45), 20.0, 5, 8.0)
	_bolt_draw()

	# morros distantes, o castelo e o penhasco (paralaxe)
	_ridge(760.0, 260.0, 1.0, Color(0.09, 0.02, 0.09), -t * 40.0)
	_ridge(820.0, 200.0, 4.0, Color(0.06, 0.015, 0.07), -t * 90.0)
	var kx: float = cx + 140.0 - t * 40.0
	_glow(Vector2(kx, 560.0), 520.0, Color(1.0, 0.20, 0.25, 0.10))
	_castle(kx, 790.0, 0.82, Color(0.02, 0.008, 0.03))
	_fog_layer(790.0, 170.0, Color(0.35, 0.08, 0.18, 0.35), 18.0, 4, 5.0)
	_ridge(900.0, 130.0, 7.0, Color(0.012, 0.006, 0.02), -t * 160.0)

	# a estrada até o portão
	var top_c := Color(0.05, 0.02, 0.06)
	var bot_c := Color(0.17, 0.05, 0.10)
	draw_polygon(PackedVector2Array([
		Vector2(kx - 24.0, 800.0), Vector2(kx + 24.0, 800.0),
		Vector2(kx + 260.0, DESIGN_H + PAD), Vector2(kx - 170.0, DESIGN_H + PAD)]),
		PackedColorArray([top_c, top_c, bot_c, bot_c]))

	# o caçador sobe a estrada
	var hy: float = lerpf(1120.0, 885.0, t)
	var hk: float = 0.20 + (hy - 880.0) / 240.0 * 0.40
	var hx: float = kx + (hy - 800.0) / 640.0 * 45.0
	var hb := Vector2(hx, hy + absf(sin(_total * 3.0)) * 3.0 * hk)
	_hunter_back(hb + Vector2(0.0, -2.0 * hk), hk, Color(1.0, 0.25, 0.35, 0.40))
	_hunter_back(hb, hk, Color(0.012, 0.008, 0.02))

	# árvores mortas em primeiro plano
	var tree := Color(0.008, 0.004, 0.014)
	_branch(Vector2(cx - 740.0, 1180.0), -PI * 0.5 + 0.10, 270.0, 24.0, 6, tree, 2.0)
	_branch(Vector2(cx + 780.0, 1180.0), -PI * 0.5 - 0.12, 240.0, 22.0, 6, tree, 5.0)

	# morcegos cruzando a lua
	for i in 5:
		var fi: float = float(i)
		var bx: float = fposmod(_total * (70.0 + 25.0 * fi) + fi * 400.0, _vw + 400.0) - 200.0
		var by: float = 200.0 + 70.0 * sin(_total * 1.1 + fi * 1.7) + 40.0 * fi
		_bat(Vector2(bx, by), 20.0 + 4.0 * fi, _total * 13.0 + fi * 2.0, Color(0.01, 0.005, 0.02))

	_fog_layer(980.0, 220.0, Color(0.25, 0.06, 0.14, 0.24), 30.0, 4, 11.0)
	_rain(130, 0.20)


# ==============================================================================
# PLANO 1 - O PORTÃO SE ABRE
# ==============================================================================

func _scene_gate(u: float) -> void:
	var cx: float = _vw * 0.5
	var open: float = _smooth((u - 0.10) / 0.62)
	var hw: float = 250.0
	var base_y: float = 800.0
	var spring_y: float = 470.0

	_vgrad(Rect2(-PAD, -PAD, _vw + PAD * 2.0, base_y + PAD), Color(0.03, 0.02, 0.055), Color(0.075, 0.04, 0.10))
	# juntas da parede de pedra
	var joint := Color(0, 0, 0, 0.30)
	var row: int = 0
	var y: float = -60.0
	while y < base_y:
		draw_line(Vector2(-PAD, y), Vector2(_vw + PAD, y), joint, 3.0)
		var x: float = -PAD + (70.0 if row % 2 == 0 else 0.0)
		while x < _vw + PAD:
			draw_line(Vector2(x, y), Vector2(x, y + 70.0), joint, 3.0)
			x += 140.0
		y += 70.0
		row += 1

	# moldura e arco do portão
	draw_colored_polygon(_arch_points(cx, base_y, spring_y, hw + 46.0), Color(0.12, 0.08, 0.16))
	draw_colored_polygon(_arch_points(cx, base_y, spring_y, hw), Color(0.015, 0.008, 0.025))
	# rosácea no tímpano
	var rose := Vector2(cx, spring_y - hw * 0.95)
	var rr: float = hw * 0.50
	_glow(rose, 300.0, Color(0.7, 0.3, 1.0, 0.25 + 0.30 * open))
	draw_circle(rose, rr, Color(0.22, 0.08, 0.34))
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + 0.2
		draw_line(rose, rose + Vector2(cos(a), sin(a)) * rr, Color(0.03, 0.01, 0.05), 7.0)
	draw_arc(rose, rr, 0.0, TAU, 48, Color(0.04, 0.015, 0.06), 9.0)
	draw_circle(rose, rr * 0.22, Color(0.04, 0.015, 0.06))

	# abertura iluminada entre as folhas
	var gap: float = hw * open * 0.92
	if gap > 2.0:
		_vgrad(Rect2(cx - gap, spring_y, gap * 2.0, base_y - spring_y), Color(0.30, 0.04, 0.12), Color(0.95, 0.30, 0.38))
		_glow(Vector2(cx, base_y - 120.0), 380.0 * open, Color(1.0, 0.35, 0.40, 0.45))
	# folhas da porta
	var leaf_col := Color(0.09, 0.055, 0.075)
	var iron := Color(0.03, 0.02, 0.04)
	for i in 2:
		var sx: float = -1.0 + 2.0 * float(i)
		var x0: float = cx + sx * gap
		var x1: float = cx + sx * hw
		var r := Rect2(minf(x0, x1), spring_y, absf(x1 - x0), base_y - spring_y)
		draw_rect(r, leaf_col)
		for j in range(1, 6):
			var px: float = lerpf(x0, x1, float(j) / 6.0)
			draw_line(Vector2(px, spring_y), Vector2(px, base_y), Color(0, 0, 0, 0.4), 3.0)
		draw_rect(Rect2(r.position.x, spring_y + 90.0, r.size.x, 22.0), iron)
		draw_rect(Rect2(r.position.x, spring_y + 250.0, r.size.x, 22.0), iron)
		draw_arc(Vector2(cx + sx * (gap + 44.0), 650.0), 22.0, 0.0, TAU, 20, Color(0.55, 0.40, 0.20), 5.0)
		draw_line(Vector2(x0, spring_y), Vector2(x0, base_y), Color(0.9, 0.35, 0.4, 0.35 * open), 4.0)

	# chão
	_vgrad(Rect2(-PAD, base_y, _vw + PAD * 2.0, DESIGN_H - base_y + PAD), Color(0.06, 0.035, 0.08), Color(0.015, 0.01, 0.03))
	for k in range(-5, 6):
		draw_line(Vector2(cx + float(k) * 60.0, base_y), Vector2(cx + float(k) * 300.0, DESIGN_H + PAD), Color(0, 0, 0, 0.35), 3.0)
	for j in range(1, 6):
		var yy: float = base_y + 18.0 * float(j * j)
		draw_line(Vector2(-PAD, yy), Vector2(_vw + PAD, yy), Color(0, 0, 0, 0.30), 3.0)
	if open > 0.02:
		var spill := PackedVector2Array([
			Vector2(cx - gap, base_y), Vector2(cx + gap, base_y),
			Vector2(cx + gap * 3.4, DESIGN_H + PAD), Vector2(cx - gap * 3.4, DESIGN_H + PAD)])
		var ca := Color(1.0, 0.25, 0.32, 0.50 * open)
		var cb := Color(1.0, 0.25, 0.32, 0.04 * open)
		draw_polygon(spill, PackedColorArray([ca, ca, cb, cb]))
	# tapete
	var carpet := PackedVector2Array([
		Vector2(cx - 80.0, base_y), Vector2(cx + 80.0, base_y),
		Vector2(cx + 260.0, DESIGN_H + PAD), Vector2(cx - 260.0, DESIGN_H + PAD)])
	draw_colored_polygon(carpet, Color(0.30 + 0.25 * open, 0.03, 0.08 + 0.04 * open))
	draw_line(Vector2(cx - 80.0, base_y), Vector2(cx - 260.0, DESIGN_H + PAD), Color(0.8, 0.55, 0.2, 0.7), 4.0)
	draw_line(Vector2(cx + 80.0, base_y), Vector2(cx + 260.0, DESIGN_H + PAD), Color(0.8, 0.55, 0.2, 0.7), 4.0)

	# luz vazando pela fresta: feixes e névoa rasteira
	if open > 0.02:
		_rays(Vector2(cx, base_y - 150.0), deg_to_rad(62.0), deg_to_rad(118.0), 1000.0, 10, Color(1.0, 0.35, 0.40, 0.11 * open), 1.0)
	_fog_layer(base_y + 50.0, 130.0, Color(0.9, 0.30, 0.40, 0.05 + 0.10 * open), 25.0, 4, 1.0)

	# pilares e tochas
	for i in 2:
		var sx2: float = -1.0 + 2.0 * float(i)
		draw_rect(Rect2(cx + sx2 * 470.0 - 38.0, -PAD, 76.0, base_y + PAD), Color(0.045, 0.03, 0.065))
		draw_rect(Rect2(cx + sx2 * 810.0 - 60.0, -PAD, 120.0, DESIGN_H + PAD * 2.0), Color(0.035, 0.022, 0.05))
		var tp := Vector2(cx + sx2 * 424.0, 500.0)
		draw_rect(Rect2(tp.x - 7.0, tp.y, 14.0, 34.0), Color(0.02, 0.01, 0.03))
		_flame(tp, 30.0, Color(1.0, 0.50, 0.16), Color(1.0, 0.86, 0.45), float(i))
		var tp2 := Vector2(cx + sx2 * 742.0, 560.0)
		draw_rect(Rect2(tp2.x - 9.0, tp2.y, 18.0, 40.0), Color(0.02, 0.01, 0.03))
		_flame(tp2, 40.0, Color(1.0, 0.50, 0.16), Color(1.0, 0.86, 0.45), float(i) + 5.0)

	_embers(26, 0.0, _vw, 1100.0, 40.0, Color(1.0, 0.55, 0.25))
	_dust(30, 0.0, _vw, 200.0, 1000.0, Color(1.0, 0.6, 0.5))

	# o caçador (a Lenda) caminha em direção ao portão, no ritmo dos passos
	var t: float = _smooth(u)
	var bob: float = absf(sin(_elapsed * PI / 0.6)) * 8.0
	var hb := Vector2(cx, lerpf(1130.0, 1010.0, t) - bob)
	var hk: float = lerpf(1.45, 1.0, t)
	_hunter_back(hb + Vector2(0.0, -4.0 * hk), hk, Color(1.0, 0.25, 0.35, 0.55))
	_hunter_back(hb, hk, Color(0.012, 0.008, 0.02))


# ==============================================================================
# CENÁRIO DO SALÃO DO TRONO (planos 2 e 6)
# ==============================================================================

func _throne_backdrop(cx: float, alert: float) -> void:
	_vgrad(Rect2(-PAD, -PAD, _vw + PAD * 2.0, 700.0 + PAD), Color(0.035, 0.012, 0.06), Color(0.11, 0.025, 0.11))

	# janela gótica com a lua de sangue
	var win: PackedVector2Array = _arch_points(cx, 640.0, 470.0, 250.0)
	draw_colored_polygon(win, Color(0.42, 0.025, 0.09))
	_glow(Vector2(cx, 310.0), 540.0, Color(1.0, 0.18, 0.22, 0.30))
	draw_circle(Vector2(cx, 310.0), 150.0, Color(0.95, 0.22, 0.26))
	draw_circle(Vector2(cx - 30.0, 280.0), 110.0, Color(1.0, 0.38, 0.38, 0.55))
	var mull := Color(0.03, 0.01, 0.04)
	draw_line(Vector2(cx, 60.0), Vector2(cx, 640.0), mull, 12.0)
	draw_line(Vector2(cx - 125.0, 145.0), Vector2(cx - 125.0, 640.0), mull, 8.0)
	draw_line(Vector2(cx + 125.0, 145.0), Vector2(cx + 125.0, 640.0), mull, 8.0)
	for yy in [335.0, 450.0, 560.0]:
		draw_line(Vector2(cx - 230.0, yy), Vector2(cx + 230.0, yy), mull, 8.0)
	var closed := PackedVector2Array(win)
	closed.append(win[0])
	draw_polyline(closed, Color(0.02, 0.008, 0.03), 16.0)

	# estandartes
	for i in 2:
		var sx: float = -1.0 + 2.0 * float(i)
		var bx: float = cx + sx * 370.0
		draw_rect(Rect2(bx - 34.0, 110.0, 68.0, 330.0), Color(0.30, 0.03, 0.09))
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 34.0, 440.0), Vector2(bx + 34.0, 440.0), Vector2(bx, 482.0)]), Color(0.30, 0.03, 0.09))
		draw_colored_polygon(PackedVector2Array([Vector2(bx, 200.0), Vector2(bx + 18.0, 240.0), Vector2(bx, 280.0), Vector2(bx - 18.0, 240.0)]), Color(0.85, 0.60, 0.20, 0.85))

	# lustres
	_chandelier(Vector2(cx - 560.0, 130.0), 1.0, 1.0)
	_chandelier(Vector2(cx + 560.0, 130.0), 1.0, 4.0)

	# piso
	_vgrad(Rect2(-PAD, 640.0, _vw + PAD * 2.0, DESIGN_H - 640.0 + PAD), Color(0.09, 0.03, 0.09), Color(0.015, 0.008, 0.03))
	draw_rect(Rect2(cx - 260.0, 626.0, 520.0, 22.0), Color(0.07, 0.035, 0.09))
	draw_rect(Rect2(cx - 210.0, 600.0, 420.0, 26.0), Color(0.10, 0.05, 0.12))
	var carpet := PackedVector2Array([
		Vector2(cx - 70.0, 648.0), Vector2(cx + 70.0, 648.0),
		Vector2(cx + 360.0, DESIGN_H + PAD), Vector2(cx - 360.0, DESIGN_H + PAD)])
	draw_colored_polygon(carpet, Color(0.40, 0.035, 0.10))
	draw_line(Vector2(cx - 70.0, 648.0), Vector2(cx - 360.0, DESIGN_H + PAD), Color(0.8, 0.55, 0.2, 0.7), 4.0)
	draw_line(Vector2(cx + 70.0, 648.0), Vector2(cx + 360.0, DESIGN_H + PAD), Color(0.8, 0.55, 0.2, 0.7), 4.0)
	# luz da lua atravessando a janela até o piso
	_rays(Vector2(cx, 340.0), deg_to_rad(62.0), deg_to_rad(118.0), 1000.0, 9, Color(1.0, 0.22, 0.28, 0.085), 3.0)

	# trono e o Conde (a cabeça se ergue conforme ele "desperta")
	var lift: float = -14.0 * alert
	_glow(Vector2(cx, 430.0), 340.0, Color(1.0, 0.10, 0.15, 0.18 + 0.10 * alert))
	var dk := Color(0.015, 0.008, 0.025)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 110.0, 610.0), Vector2(cx - 92.0, 330.0), Vector2(cx, 250.0), Vector2(cx + 92.0, 330.0), Vector2(cx + 110.0, 610.0)]), Color(0.05, 0.025, 0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 70.0, 440.0), Vector2(cx - 215.0, 610.0), Vector2(cx - 60.0, 610.0)]), dk)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 70.0, 440.0), Vector2(cx + 215.0, 610.0), Vector2(cx + 60.0, 610.0)]), dk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 70.0, 610.0), Vector2(cx - 62.0, 445.0), Vector2(cx - 24.0, 418.0 + lift * 0.5),
		Vector2(cx + 24.0, 418.0 + lift * 0.5), Vector2(cx + 62.0, 445.0), Vector2(cx + 70.0, 610.0)]), dk)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 30.0, 420.0 + lift * 0.5), Vector2(cx - 72.0, 355.0 + lift), Vector2(cx - 20.0, 392.0 + lift)]), dk)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 30.0, 420.0 + lift * 0.5), Vector2(cx + 72.0, 355.0 + lift), Vector2(cx + 20.0, 392.0 + lift)]), dk)
	_ellipse(Vector2(cx, 382.0 + lift), 30.0, 38.0, Color(0.62, 0.52, 0.60))
	_ellipse(Vector2(cx, 360.0 + lift), 33.0, 26.0, dk)
	var eye_a: float = 0.20 + 0.80 * alert
	for i in 2:
		var ex: float = cx - 12.0 + 24.0 * float(i)
		_glow(Vector2(ex, 384.0 + lift), 26.0 + 30.0 * alert, Color(1.0, 0.10, 0.15, (0.55 + 0.35 * alert) * eye_a))
		draw_circle(Vector2(ex, 384.0 + lift), 3.5, Color(1.0, 0.55, 0.45, eye_a))

	# pilares com tochas
	for i in 2:
		var sx2: float = -1.0 + 2.0 * float(i)
		draw_rect(Rect2(cx + sx2 * 780.0 - 60.0, -PAD, 120.0, DESIGN_H + PAD * 2.0), Color(0.04, 0.025, 0.06))
		var tp := Vector2(cx + sx2 * 706.0, 520.0)
		draw_rect(Rect2(tp.x - 8.0, tp.y, 16.0, 36.0), Color(0.02, 0.01, 0.03))
		_flame(tp, 34.0, Color(1.0, 0.50, 0.16), Color(1.0, 0.86, 0.45), float(i) + 2.0)

	# braseiros violeta (iguais aos da arena)
	var bpos: Array[Vector2] = [Vector2(cx - 300.0, 740.0), Vector2(cx + 300.0, 740.0), Vector2(cx - 570.0, 900.0), Vector2(cx + 570.0, 900.0)]
	var bsc: Array[float] = [0.8, 0.8, 1.3, 1.3]
	for i in 4:
		var bp: Vector2 = bpos[i]
		var bk: float = bsc[i]
		draw_rect(Rect2(bp.x - 14.0 * bk, bp.y, 28.0 * bk, 70.0 * bk), Color(0.07, 0.04, 0.09))
		draw_colored_polygon(_xf(PackedVector2Array([Vector2(-32, 0), Vector2(32, 0), Vector2(20, -24), Vector2(-20, -24)]), bp, bk), Color(0.09, 0.05, 0.12))
		_glow(bp + Vector2(0.0, 40.0 * bk), 280.0 * bk, Color(0.6, 0.25, 0.95, 0.16))
		_flame(bp + Vector2(0.0, -22.0 * bk), 40.0 * bk, Color(0.62, 0.26, 0.96), Color(0.95, 0.80, 1.0), float(i) + 9.0)

	_embers(22, 0.0, _vw, 1100.0, 30.0, Color(0.75, 0.40, 1.0))
	_dust(30, 0.0, _vw, 150.0, 1000.0, Color(1.0, 0.55, 0.50))


# ==============================================================================
# PLANO 2 - O CONDE ESPERA NO TRONO
# ==============================================================================

func _scene_throne(u: float) -> void:
	var cx: float = _vw * 0.5
	var alert: float = _smooth((u - 0.30) / 0.35)
	_throne_backdrop(cx, alert)

	var bat_col := Color(0.01, 0.005, 0.02)
	for i in 3:
		var fi: float = float(i)
		var bx: float = fposmod(_total * (90.0 + 30.0 * fi) + fi * 500.0, _vw + 400.0) - 200.0
		var by: float = 240.0 + 70.0 * sin(_total * 1.3 + fi) + 45.0 * fi
		_bat(Vector2(bx, by), 28.0, _total * 14.0 + fi * 2.0, bat_col)

	# o caçador, de costas, em primeiro plano (respirando)
	var hb := Vector2(cx - 640.0, 1250.0 + sin(_total * 1.6) * 4.0)
	_hunter_back(hb + Vector2(0.0, -8.0), 2.1, Color(1.0, 0.25, 0.35, 0.45))
	_hunter_back(hb, 2.1, Color(0.01, 0.006, 0.016))
