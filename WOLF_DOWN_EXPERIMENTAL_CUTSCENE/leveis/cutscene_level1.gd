class_name Level1AftermathCinematic
extends Control

## Wolf Down - Cinemática pós Level 1 (100% desenhada por código, sem PNG).
## Plano 1: campo de batalha, Lobsome caído de joelhos sob o luar.
## Plano 2: Lobsome se levanta (como o Drácula saindo da tumba) e os olhos acendem.
## Plano 3: close do velho .38 na garra ferida.
## Plano 4: silhueta uivando para a lua, com o cemitério esperando ao longe.

const DESIGN_H: float = 1080.0
const TYPE_SPEED: float = 0.025
const NEXT_LEVEL_INDEX: int = 2
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const MUSIC_PATH: String = "res://leveis/moonlight_hollow.wav"
const WOLF_SOUND_PATH: String = "res://audio/shot_07_olho_lobo.wav"

const SHOT_DURATION: Array[float] = [6.5, 7.5, 6.5, 8.0]
const ZOOM_FROM: Array[float] = [1.00, 1.02, 1.00, 1.12]
const ZOOM_TO: Array[float] = [1.10, 1.16, 1.15, 1.00]
const PAN_TO: Array[Vector2] = [Vector2(0, -10), Vector2(0, 60), Vector2(-70, 10), Vector2(0, 0)]

const GROUND: float = 900.0
const HEAD_SCALE: float = 1.28

# Paleta do Lobsome (pelo roxo, olhos amarelos).
const FUR: Color = Color(0.30, 0.15, 0.46)
const FUR_D: Color = Color(0.14, 0.065, 0.24)
const FUR_DD: Color = Color(0.06, 0.025, 0.11)
const BONE: Color = Color(0.86, 0.82, 0.74)
const WOUND: Color = Color(0.52, 0.03, 0.13, 0.95)
const WOUND_L: Color = Color(0.88, 0.22, 0.28, 0.55)
const RIM: Color = Color(0.72, 0.68, 1.0)

var _shot: int = 0
var _elapsed: float = 0.0
var _total: float = 0.0
var _typing_index: int = 0
var _typing_time: float = 0.0
var _finished: bool = false
var _fade_value: float = 0.0
var _scale: float = 1.0
var _vw: float = 1920.0

# Transformações locais usadas para desenhar o lobo (corpo e cabeça).
var _wb: Vector2 = Vector2.ZERO
var _ws: float = 1.0
var _hc: Vector2 = Vector2.ZERO
var _hr: float = 0.0

var _glow_tex: GradientTexture2D
var _vignette_tex: GradientTexture2D
var _music: AudioStreamPlayer
var _wolf_sound: AudioStreamPlayer

var _title_label: Label
var _story_label: Label
var _hint_label: Label
var _progress_label: Label

var _story: Array[String] = [
	"A batalha terminou.\nMas Lobsome não saiu ileso.",
	"Sob a luz fria da lua, seus pelos roxos estavam manchados de sangue.\nSeus olhos ainda ardiam em amarelo.",
	"Ele olha para o velho .38.\nAs criaturas estão ficando mais fortes... e essa arma já não parece suficiente.",
	"Lobsome entende o que precisa fazer:\nmelhorar seu .38 antes do próximo confronto.\n\nO cemitério espera."
]

var _titles: Array[String] = [
	"DEPOIS DA BATALHA",
	"O LOBO FERIDO",
	"UM .38 JÁ NÃO BASTA",
	"A PRÓXIMA CAÇADA"
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_textures()
	_build_ui()
	_apply_ui_scale()
	_reset_shot()
	_start_music()
	resized.connect(_apply_ui_scale)
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_total += delta

	var current_text: String = _story[_shot]
	if _typing_index < current_text.length():
		_typing_time += delta
		var steps: int = int(_typing_time / TYPE_SPEED)
		if steps > 0:
			_typing_time -= float(steps) * TYPE_SPEED
			_typing_index = mini(_typing_index + steps, current_text.length())
			_story_label.text = current_text.substr(0, _typing_index)

	_title_label.modulate.a = clampf((_elapsed - 0.5) / 0.7, 0.0, 1.0)
	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	_update_fade()
	queue_redraw()

	if _elapsed >= SHOT_DURATION[_shot]:
		_next_shot()


func _update_fade() -> void:
	var fade_in := clampf(_elapsed / 0.75, 0.0, 1.0)
	var time_left := SHOT_DURATION[_shot] - _elapsed
	var fade_out := 0.0
	if time_left < 0.75:
		fade_out = clampf(1.0 - time_left / 0.75, 0.0, 1.0)
	_fade_value = maxf(1.0 - fade_in, fade_out)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_accept"):
		_next_shot()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_finish()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		_next_shot()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_finish()
		get_viewport().set_input_as_handled()


func _next_shot() -> void:
	if _typing_index < _story[_shot].length():
		_typing_index = _story[_shot].length()
		_story_label.text = _story[_shot]
		return
	if _shot >= _story.size() - 1:
		_finish()
		return
	_shot += 1
	_reset_shot()


func _reset_shot() -> void:
	_elapsed = 0.0
	_typing_time = 0.0
	_typing_index = 0
	_story_label.text = ""
	_title_label.text = _titles[_shot]
	_title_label.modulate.a = 0.0
	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	_play_shot_sound()
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_fade_value = 0.0
	if is_instance_valid(_music):
		create_tween().tween_property(_music, "volume_db", -60.0, 0.55)
	if is_instance_valid(_wolf_sound):
		create_tween().tween_property(_wolf_sound, "volume_db", -60.0, 0.25)
	await get_tree().create_timer(0.75, true, false, true).timeout
	GameManager.load_level(NEXT_LEVEL_INDEX)


func _make_gradient(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _make_textures() -> void:
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = _make_gradient(
		[0.0, 0.18, 0.52, 1.0],
		[Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.48), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.0)]
	)
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256

	_vignette_tex = GradientTexture2D.new()
	_vignette_tex.gradient = _make_gradient(
		[0.0, 0.52, 1.0],
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.94)]
	)
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.5)
	_vignette_tex.fill_to = Vector2(1.0, 0.5)
	_vignette_tex.width = 256
	_vignette_tex.height = 256


func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.anchor_left = 0.05
	_title_label.anchor_right = 0.95
	_title_label.anchor_top = 0.09
	_title_label.anchor_bottom = 0.18
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(0.88, 0.77, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.09, 0.015, 0.13))
	_title_label.add_theme_constant_override("outline_size", 10)
	add_child(_title_label)

	_story_label = Label.new()
	_story_label.anchor_left = 0.10
	_story_label.anchor_right = 0.90
	_story_label.anchor_top = 0.66
	_story_label.anchor_bottom = 0.89
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.add_theme_font_override("font", FONT_BOLD)
	_story_label.add_theme_font_size_override("font_size", 34)
	_story_label.add_theme_color_override("font_color", Color(0.96, 0.94, 1.0))
	_story_label.add_theme_color_override("font_outline_color", Color(0.025, 0.01, 0.04))
	_story_label.add_theme_constant_override("outline_size", 8)
	add_child(_story_label)

	_hint_label = Label.new()
	_hint_label.anchor_left = 0.1
	_hint_label.anchor_right = 0.9
	_hint_label.anchor_top = 0.94
	_hint_label.anchor_bottom = 0.985
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "ENTER / CLIQUE — AVANÇAR     ESC — PULAR"
	_hint_label.add_theme_font_override("font", FONT_BOLD)
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.67, 0.82, 0.85))
	add_child(_hint_label)

	_progress_label = Label.new()
	_progress_label.anchor_left = 0.82
	_progress_label.anchor_right = 0.95
	_progress_label.anchor_top = 0.94
	_progress_label.anchor_bottom = 0.985
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_font_override("font", FONT_BOLD)
	_progress_label.add_theme_font_size_override("font_size", 20)
	_progress_label.add_theme_color_override("font_color", Color(0.72, 0.67, 0.82, 0.85))
	add_child(_progress_label)


func _apply_ui_scale() -> void:
	var factor := clampf(get_viewport_rect().size.y / 1080.0, 0.70, 1.30)
	_title_label.add_theme_font_size_override("font_size", int(56.0 * factor))
	_story_label.add_theme_font_size_override("font_size", int(34.0 * factor))
	_hint_label.add_theme_font_size_override("font_size", int(20.0 * factor))
	_progress_label.add_theme_font_size_override("font_size", int(20.0 * factor))


func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC_PATH)
	_music.volume_db = -15.0
	add_child(_music)
	_music.play()


func _play_shot_sound() -> void:
	# O uivo/olho do lobo toca quando os olhos acendem (plano 2).
	if _shot != 1 or not ResourceLoader.exists(WOLF_SOUND_PATH):
		return
	if is_instance_valid(_wolf_sound):
		_wolf_sound.queue_free()
	_wolf_sound = AudioStreamPlayer.new()
	_wolf_sound.stream = load(WOLF_SOUND_PATH)
	_wolf_sound.volume_db = -8.0
	add_child(_wolf_sound)
	_wolf_sound.play()


# ----------------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------------

func _smooth(t: float) -> float:
	var v := clampf(t, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


func _hsh(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


func _ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


func _concat(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(a)
	out.append_array(b)
	return out


func _at(pos: Vector2, sc: float, x: float, y: float) -> Vector2:
	return pos + Vector2(x, y) * sc


func _glow(pos: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _glow_ellipse(pos: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, color)


func _poly(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)


func _draw_vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var steps := 18
	for i in steps:
		var t := (float(i) + 1.0) / float(steps)
		var y0 := lerpf(rect.position.y, rect.end.y, float(i) / float(steps))
		var y1 := lerpf(rect.position.y, rect.end.y, t)
		draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0 + 1.0), top.lerp(bottom, t))


# ----------------------------------------------------------------------------
# Câmera / composição final
# ----------------------------------------------------------------------------

func _draw() -> void:
	var screen := get_viewport_rect().size
	_scale = screen.y / DESIGN_H
	_vw = screen.x / _scale

	var p := clampf(_elapsed / SHOT_DURATION[_shot], 0.0, 1.0)
	var e := _smooth(p)
	var zoom := lerpf(ZOOM_FROM[_shot], ZOOM_TO[_shot], e)
	var sway := Vector2(sin(_total * 0.7) * 4.0, cos(_total * 0.9) * 3.0)
	var pan := PAN_TO[_shot] * e + sway
	var s := _scale * zoom
	var origin := screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + pan * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	match _shot:
		0:
			_scene_wide()
		1:
			_scene_rise()
		2:
			_scene_gun()
		_:
			_scene_howl()

	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color.WHITE)

	# Grão de filme sutil.
	var seed_v: float = float(int(_total * 24.0))
	for i in 70:
		var fi := float(i)
		var gx := _hsh(fi * 1.37 + seed_v) * screen.x
		var gy := _hsh(fi * 2.11 + seed_v * 1.7) * screen.y
		var bright: bool = i % 2 == 0
		draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(1, 1, 1, 0.05) if bright else Color(0, 0, 0, 0.10))

	var bar_k := _smooth(_total / 1.2)
	var bar_h := screen.y * 0.075 * bar_k
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.95))
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color(0, 0, 0, 0.95))

	if _fade_value > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, _fade_value))


# ----------------------------------------------------------------------------
# Os quatro planos
# ----------------------------------------------------------------------------

func _scene_wide() -> void:
	var cx := _vw * 0.5
	_bg(Vector2(_vw * 0.74, 235.0), 105.0, true, false)
	var eye := 0.12 + 0.06 * sin(_total * 1.6)
	_wolf_front(Vector2(cx - 20.0, 905.0), 0.78, 0.0, eye, 0.0, 0.0)
	# O velho .38 caído no chão, com um brilho discreto.
	_gun(Vector2(cx + 380.0, 928.0), 0.22, 1.0)
	_draw_mist(930.0, 0.05)
	_draw_embers(26)


func _scene_rise() -> void:
	var cx := _vw * 0.5
	var dur: float = SHOT_DURATION[1]
	var rise := _smooth((_elapsed - 0.7) / (dur - 2.4))
	var eye := _smooth((_elapsed - 1.4) / 1.8)
	var flash := maxf(0.0, 1.0 - absf(_elapsed - 2.6) / 0.45)
	_bg(Vector2(_vw * 0.74, 235.0), 105.0, true, false)
	# Facho de luar caindo sobre o lobo enquanto ele se ergue.
	var beam := 0.85 + 0.15 * sin(_total * 0.9)
	_poly(PackedVector2Array([
		Vector2(_vw * 0.74 - 70.0, 300.0), Vector2(_vw * 0.74 + 70.0, 300.0),
		Vector2(cx + 330.0, 940.0), Vector2(cx - 330.0, 940.0)
	]), Color(0.60, 0.66, 1.0, 0.05 * beam))
	_glow_ellipse(Vector2(cx, 560.0), 430.0, 380.0, Color(0.42, 0.46, 0.95, 0.16 * beam))
	_wolf_front(Vector2(cx, 935.0), 0.70, rise, eye, flash, 0.35 * eye)
	_draw_mist(945.0, 0.05)
	_draw_embers(34)


func _scene_gun() -> void:
	_draw_vertical_gradient(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0), Color(0.01, 0.012, 0.03), Color(0.06, 0.04, 0.11))
	_glow(Vector2(_vw * 0.80, 140.0), 760.0, Color(0.40, 0.45, 0.90, 0.22))
	# Bokeh de luar ao fundo, fora de foco.
	for i in 14:
		var fi := float(i)
		var bx := fposmod(_hsh(fi + 1.0) * _vw + sin(_total * 0.2 + fi) * 30.0, _vw)
		var by := 120.0 + _hsh(fi + 7.0) * 820.0
		var br := 36.0 + _hsh(fi + 3.0) * 70.0
		_glow(Vector2(bx, by), br, Color(0.45, 0.52, 1.0, 0.035 + 0.03 * _hsh(fi + 5.0)))
	_paw_gun(Vector2(_vw * 0.47, 440.0), 1.35)
	# Poeira / cinzas flutuando na luz.
	for i in 40:
		var fi2 := float(i)
		var ph := fposmod(_total * (0.03 + _hsh(fi2) * 0.05) + _hsh(fi2 + 2.0), 1.0)
		var dx := _hsh(fi2 + 4.0) * _vw + sin(_total * 0.6 + fi2) * 24.0
		var dy := 1000.0 - ph * 980.0
		draw_circle(Vector2(dx, dy), 1.2 + _hsh(fi2 + 8.0) * 2.0, Color(0.75, 0.8, 1.0, 0.45 * sin(ph * PI)))
	_draw_mist(1010.0, 0.06)


func _scene_howl() -> void:
	var cx := _vw * 0.5
	var howl := _smooth(_elapsed / 2.8)
	_bg(Vector2(cx + 220.0, 360.0), 250.0, false, true)
	_wolf_howl(Vector2(cx + 40.0, 905.0), 0.9, _total, howl)
	_draw_mist(935.0, 0.05)
	_draw_embers(18)


# ----------------------------------------------------------------------------
# Cenário
# ----------------------------------------------------------------------------

func _bg(moon: Vector2, moon_r: float, aftermath: bool, with_cemetery: bool) -> void:
	var vw := _vw
	var cx := vw * 0.5
	_draw_vertical_gradient(Rect2(-400.0, -300.0, vw + 800.0, 1500.0), Color(0.006, 0.008, 0.022), Color(0.075, 0.045, 0.13))
	_glow(moon, moon_r * 7.0, Color(0.30, 0.36, 0.85, 0.14))
	_draw_stars(90)
	_draw_moon(moon, moon_r)
	_draw_god_rays(moon, 0.85 + 0.15 * sin(_total * 0.9))
	_draw_clouds(310.0, Color(0.12, 0.10, 0.19, 0.22), 12.0, 5, 1.7)
	_draw_mountains(720.0, 170.0, Color(0.02, 0.018, 0.045))
	_draw_pines(855.0, Color(0.008, 0.009, 0.018), 260.0, 0.0)
	if with_cemetery:
		_draw_cemetery(Vector2(vw * 0.20, 800.0), 0.8)
	_draw_dead_tree(vw * 0.12, GROUND - 30.0, 520.0, Color(0.004, 0.004, 0.010), 1)
	_draw_dead_tree(vw * 0.90, GROUND - 20.0, 600.0, Color(0.004, 0.004, 0.010), 2)
	_draw_pines(975.0, Color(0.004, 0.004, 0.010), 360.0, 30.0)

	# Chão molhado com reflexo da lua.
	_draw_vertical_gradient(Rect2(-200.0, 845.0, vw + 400.0, 380.0), Color(0.045, 0.045, 0.095), Color(0.004, 0.004, 0.012))
	_glow_ellipse(Vector2(moon.x * 0.6 + vw * 0.2, GROUND + 22.0), 360.0, 26.0, Color(0.55, 0.60, 1.0, 0.16))
	_glow_ellipse(Vector2(cx, GROUND + 12.0), 430.0, 55.0, Color(0.30, 0.28, 0.58, 0.20))

	if aftermath:
		_draw_fire(Vector2(vw * 0.20, GROUND - 8.0), 70.0)
		_draw_fire(Vector2(vw * 0.82, GROUND - 4.0), 54.0)
		_draw_fallen(Vector2(vw * 0.32, GROUND + 16.0), 0.9, 1.0)
		_draw_fallen(Vector2(vw * 0.70, GROUND + 30.0), 1.1, -1.0)
		# Poça de sangue e respingos perto do lobo.
		_glow_ellipse(Vector2(cx - 40.0, GROUND + 34.0), 240.0, 22.0, Color(0.45, 0.02, 0.08, 0.34))
		for i in 9:
			var fi := float(i)
			var bx := cx - 260.0 + fi * 62.0 + sin(fi * 4.3) * 20.0
			var by := GROUND + 14.0 + absf(sin(fi * 1.7)) * 28.0
			draw_circle(Vector2(bx, by), 3.0 + fi * 0.35, Color(0.40, 0.02, 0.10, 0.44))


func _draw_stars(count: int) -> void:
	for i in count:
		var fi := float(i)
		var x := fposmod(fi * 287.0 + 80.0, _vw)
		var y := 90.0 + fposmod(fi * 149.0, 560.0)
		var tw := 0.30 + 0.35 * (0.5 + 0.5 * sin(_total * 2.1 + fi))
		draw_circle(Vector2(x, y), 1.5 + float(i % 3) * 0.5, Color(0.70, 0.75, 1.0, tw))


func _draw_moon(pos: Vector2, radius: float) -> void:
	for k in 4:
		_glow(pos, radius * (2.2 + float(k) * 1.5), Color(0.55, 0.60, 1.0, 0.07))
	draw_circle(pos, radius * 1.06, Color(0.75, 0.78, 1.0, 0.25))
	draw_circle(pos, radius, Color(0.89, 0.90, 1.0, 0.97))
	for i in 8:
		var fi := float(i)
		var crater := pos + Vector2(cos(fi * 2.2), sin(fi * 1.8)) * radius * (0.2 + fi * 0.06)
		draw_circle(crater, radius * 0.07 + fi * 2.2, Color(0.68, 0.70, 0.82, 0.17))


func _draw_god_rays(moon: Vector2, pulse: float) -> void:
	for i in 7:
		var fi := float(i)
		var a := PI * (0.18 + 0.095 * fi) + sin(_total * 0.3 + fi) * 0.01
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var w := 20.0 + float(i % 3) * 16.0
		_poly(PackedVector2Array([
			moon + n * 6.0, moon - n * 6.0,
			moon + d * 1500.0 - n * w * 3.0, moon + d * 1500.0 + n * w * 3.0
		]), Color(0.60, 0.66, 1.0, 0.025 * pulse))


func _draw_clouds(y: float, col: Color, speed: float, count: int, seed_v: float) -> void:
	for i in count:
		var fi := float(i)
		var x := fposmod(fi * 410.0 + _total * speed + seed_v * 93.0, _vw + 500.0) - 250.0
		var cy := y + sin(_total * 0.25 + fi) * 14.0
		for j in 4:
			var fj := float(j)
			draw_circle(Vector2(x + (fj - 1.5) * 90.0, cy + sin(fj) * 12.0), 70.0 + fj * 18.0, col)


func _draw_mountains(base_y: float, amp: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var x := -200.0
	while x <= _vw + 200.0:
		pts.append(Vector2(x, base_y - absf(sin(x * 0.0027)) * amp - sin(x * 0.006) * 30.0))
		x += 35.0
	var ridge := pts.duplicate()
	pts.append(Vector2(_vw + 300.0, 1200.0))
	pts.append(Vector2(-300.0, 1200.0))
	draw_colored_polygon(pts, col)
	draw_polyline(ridge, Color(0.45, 0.50, 0.90, 0.16), 3.0, true)


func _draw_pines(base_y: float, col: Color, max_h: float, off: float) -> void:
	var x := -30.0 + off
	var i := 0
	while x < _vw + 60.0:
		var h := max_h * (0.55 + 0.45 * fposmod(float(i) * 1.71, 1.0))
		var w := h * 0.34
		draw_rect(Rect2(x - h * 0.018, base_y - h * 0.08, h * 0.036, h * 0.18), col)
		for t in 5:
			var top := Vector2(x, base_y - h + float(t) * h * 0.16)
			var half := w * (0.28 + float(t) * 0.12)
			_poly(PackedVector2Array([top, Vector2(x + half, top.y + h * 0.23), Vector2(x - half, top.y + h * 0.23)]), col)
		x += 78.0
		i += 1


func _draw_dead_tree(x: float, base_y: float, h: float, col: Color, sd: int) -> void:
	_poly(PackedVector2Array([
		Vector2(x - h * 0.045, base_y), Vector2(x + h * 0.045, base_y),
		Vector2(x + h * 0.02, base_y - h), Vector2(x - h * 0.02, base_y - h)
	]), col)
	for i in 8:
		var fi := float(i)
		var t := 0.28 + 0.085 * fi
		var side: float = 1.0 if (i + sd) % 2 == 0 else -1.0
		var st := Vector2(x, base_y - h * t)
		var ln := h * (0.38 - 0.035 * fi)
		var en := st + Vector2(side * ln, -ln * (0.45 + 0.2 * _hsh(fi + float(sd))))
		draw_line(st, en, col, maxf(3.0, h * 0.028 * (1.0 - t * 0.6)), true)
		var sub := st.lerp(en, 0.6)
		draw_line(sub, sub + Vector2(side * ln * 0.35, -ln * 0.45), col, maxf(2.0, h * 0.014), true)
		draw_line(sub, sub + Vector2(side * ln * 0.30, ln * 0.18), col, maxf(2.0, h * 0.010), true)


func _draw_mist(y: float, a: float) -> void:
	for i in 12:
		var fi := float(i)
		var x := fposmod(fi * 240.0 + _total * 18.0, _vw + 400.0) - 200.0
		var yy := y + sin(_total * 0.5 + fi) * 18.0 + float(i % 3) * 14.0
		_glow_ellipse(Vector2(x, yy), 220.0, 28.0, Color(0.35, 0.39, 0.63, a))


func _draw_fire(pos: Vector2, size_v: float) -> void:
	var t := _total
	_glow(pos + Vector2(0, -size_v * 0.5), size_v * 3.2, Color(1.0, 0.45, 0.10, 0.14 + 0.04 * sin(t * 9.0)))
	for i in 5:
		var fi := float(i)
		var w := size_v * (0.30 - 0.04 * fi)
		var h := size_v * (0.95 - 0.12 * fi) * (0.85 + 0.15 * sin(t * 8.0 + fi * 2.0))
		var sway := sin(t * 5.0 + fi) * size_v * 0.08
		var ox := (fi - 2.0) * size_v * 0.12
		var col := Color(1.0, 0.35 + 0.15 * fi, 0.06, 0.85)
		if i >= 3:
			col = Color(1.0, 0.85, 0.35, 0.9)
		_poly(PackedVector2Array([
			pos + Vector2(ox - w, 0), pos + Vector2(ox - w * 0.6, -h * 0.5), pos + Vector2(ox + sway, -h),
			pos + Vector2(ox + w * 0.6, -h * 0.5), pos + Vector2(ox + w, 0), pos + Vector2(ox, size_v * 0.1)
		]), col)


func _draw_embers(n: int) -> void:
	for i in n:
		var fi := float(i)
		var ph := fposmod(_total * (0.05 + _hsh(fi) * 0.08) + _hsh(fi + 9.0), 1.0)
		var x := fposmod(_hsh(fi + 1.0) * _vw + sin(_total * 0.7 + fi) * 40.0, _vw)
		var y := GROUND + 60.0 - ph * 700.0
		var a := sin(ph * PI) * 0.8
		draw_circle(Vector2(x, y), 1.6 + _hsh(fi + 4.0) * 1.8, Color(1.0, 0.5 + 0.3 * _hsh(fi), 0.15, a))


func _draw_fallen(pos: Vector2, sc: float, flip: float) -> void:
	var dk := Color(0.012, 0.010, 0.022)
	var body := PackedVector2Array([
		_at(pos, sc, -130.0 * flip, 0.0), _at(pos, sc, -110.0 * flip, -38.0), _at(pos, sc, -30.0 * flip, -48.0),
		_at(pos, sc, 60.0 * flip, -40.0), _at(pos, sc, 120.0 * flip, -18.0), _at(pos, sc, 150.0 * flip, 0.0)
	])
	draw_colored_polygon(body, dk)
	draw_circle(_at(pos, sc, -140.0 * flip, -22.0), 30.0 * sc, dk)
	var hand := _at(pos, sc, -72.0 * flip, -120.0)
	draw_line(_at(pos, sc, -40.0 * flip, -40.0), hand, dk, 15.0 * sc, true)
	for k in 3:
		draw_line(hand, _at(pos, sc, (-72.0 + float(k - 1) * 20.0) * flip, -150.0), dk, 5.0 * sc, true)
	draw_polyline(PackedVector2Array([body[1], body[2], body[3], body[4]]), Color(0.45, 0.50, 0.95, 0.22), 3.0, true)


func _draw_cemetery(pos: Vector2, s: float) -> void:
	var dk := Color(0.004, 0.005, 0.014)
	var pulse := 0.8 + 0.2 * sin(_total * 1.3)
	_glow_ellipse(_at(pos, s, 0.0, -120.0), 620.0 * s, 200.0 * s, Color(0.30, 0.80, 0.55, 0.10 * pulse))
	# Colina
	var hill := PackedVector2Array()
	var x := -460.0
	while x <= 460.0:
		hill.append(_at(pos, s, x, -sin((x + 460.0) / 920.0 * PI) * 95.0))
		x += 40.0
	var crest := hill.duplicate()
	hill.append(_at(pos, s, 460.0, 260.0))
	hill.append(_at(pos, s, -460.0, 260.0))
	draw_colored_polygon(hill, dk)
	draw_polyline(crest, Color(0.50, 0.90, 0.70, 0.14), 3.0, true)
	# Capela com janela acesa
	draw_rect(Rect2(_at(pos, s, 250.0, -210.0), Vector2(110.0, 150.0) * s), dk)
	_poly(PackedVector2Array([_at(pos, s, 238.0, -208.0), _at(pos, s, 305.0, -300.0), _at(pos, s, 372.0, -208.0)]), dk)
	draw_rect(Rect2(_at(pos, s, 300.0, -340.0), Vector2(10.0, 50.0) * s), dk)
	draw_rect(Rect2(_at(pos, s, 288.0, -326.0), Vector2(34.0, 9.0) * s), dk)
	_glow(_at(pos, s, 305.0, -150.0), 60.0 * s, Color(0.6, 1.0, 0.6, 0.45 * pulse))
	draw_rect(Rect2(_at(pos, s, 293.0, -168.0), Vector2(24.0, 38.0) * s), Color(0.75, 1.0, 0.65, 0.8 * pulse))
	# Portão de ferro
	for gi in 2:
		var sx: float = -130.0 if gi == 0 else 130.0
		draw_rect(Rect2(_at(pos, s, sx - 12.0, -230.0), Vector2(24.0, 250.0) * s), dk)
		_poly(PackedVector2Array([_at(pos, s, sx - 18.0, -230.0), _at(pos, s, sx, -262.0), _at(pos, s, sx + 18.0, -230.0)]), dk)
		draw_circle(_at(pos, s, sx, -270.0), 9.0 * s, dk)
	draw_arc(_at(pos, s, 0.0, -215.0), 130.0 * s, PI, TAU, 24, dk, 9.0 * s, true)
	for k in range(-6, 7):
		var gx := float(k) * 19.5
		draw_line(_at(pos, s, gx, -130.0), _at(pos, s, gx, 10.0), dk, 5.0 * s, true)
		_poly(PackedVector2Array([_at(pos, s, gx - 6.0, -130.0), _at(pos, s, gx, -150.0), _at(pos, s, gx + 6.0, -130.0)]), dk)
	draw_line(_at(pos, s, -130.0, -60.0), _at(pos, s, 130.0, -60.0), dk, 6.0 * s, true)
	draw_rect(Rect2(_at(pos, s, -8.0, -345.0), Vector2(16.0, 70.0) * s), dk)
	draw_rect(Rect2(_at(pos, s, -30.0, -320.0), Vector2(60.0, 14.0) * s), dk)
	# Cruzes e lápides
	var crosses: Array[Vector3] = [Vector3(-330, -52, 80), Vector3(-260, -26, 60), Vector3(-400, -30, 66), Vector3(210, -6, 70), Vector3(-190, 8, 50)]
	for c in crosses:
		draw_rect(Rect2(_at(pos, s, c.x - 5.0, c.y - c.z), Vector2(10.0, c.z) * s), dk)
		draw_rect(Rect2(_at(pos, s, c.x - 20.0, c.y - c.z * 0.8), Vector2(40.0, 9.0) * s), dk)
	var stones: Array[Vector2] = [Vector2(-300, 10), Vector2(-230, 20), Vector2(180, 16), Vector2(330, -4)]
	for st in stones:
		draw_rect(Rect2(_at(pos, s, st.x - 22.0, st.y - 46.0), Vector2(44.0, 46.0) * s), dk)
		draw_circle(_at(pos, s, st.x, st.y - 46.0), 22.0 * s, dk)


# ----------------------------------------------------------------------------
# Lobsome (frente) — corpo e cabeça desenhados por polígonos
# ----------------------------------------------------------------------------

func _w(p: Vector2) -> Vector2:
	return _wb + p * _ws


func _h(p: Vector2) -> Vector2:
	return _hc + p.rotated(_hr) * (_ws * HEAD_SCALE)


func _pw(pts: PackedVector2Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_w(p))
	draw_colored_polygon(out, col)


func _ph(pts: PackedVector2Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_h(p))
	draw_colored_polygon(out, col)


func _lw(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(_w(a), _w(b), col, w * _ws, true)


func _lh(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(_h(a), _h(b), col, w * _ws * HEAD_SCALE, true)


func _polyline_h(pts: PackedVector2Array, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_h(p))
	draw_polyline(out, col, w * _ws * HEAD_SCALE, true)


func _limb(a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_pw(PackedVector2Array([a + n * (w0 * 0.5), b + n * (w1 * 0.5), b - n * (w1 * 0.5), a - n * (w0 * 0.5)]), col)
	draw_circle(_w(a), w0 * 0.5 * _ws, col)
	draw_circle(_w(b), w1 * 0.5 * _ws, col)


func _claws(p: Vector2, dirv: Vector2, spread: float, n: int, length: float, col: Color) -> void:
	var d: Vector2 = dirv.normalized()
	var nrm := Vector2(-d.y, d.x)
	for i in n:
		var o: float = (float(i) - float(n - 1) * 0.5) * spread
		var b: Vector2 = p + nrm * o
		var tip: Vector2 = b + d * length + nrm * (o * 0.25)
		var half: Vector2 = nrm * 5.0
		_pw(PackedVector2Array([b - half, tip, b + half]), col)


## rise: 0 = caído de joelhos, 1 = em pé. eye: 0..1 brilho dos olhos. flash: clarão do acender.
func _wolf_front(base: Vector2, sc: float, rise: float, eye: float, flash: float, snarl: float) -> void:
	_wb = base
	_ws = sc
	var t: float = _total
	var r: float = clampf(rise, 0.0, 1.0)
	var breath: float = sin(t * 2.4) * (7.0 - 3.0 * r)
	var hip_y: float = -lerpf(95.0, 330.0, r)
	var sh_y: float = -lerpf(285.0, 655.0, r) + breath
	var sw: float = lerpf(225.0, 205.0, r)
	var lit := Color(0.70, 0.66, 1.0, 0.28)

	_glow_ellipse(_w(Vector2(0, 6)), 300.0 * sc, 46.0 * sc, Color(0, 0, 0, 0.55))

	# Pernas
	for si in 2:
		var sd: float = -1.0 if si == 0 else 1.0
		var hip := Vector2(sd * 80.0, hip_y + 10.0)
		var knee := Vector2(sd * lerpf(165.0, 92.0, r), -lerpf(14.0, 175.0, r))
		var foot := Vector2(sd * lerpf(118.0, 100.0, r), -4.0)
		_limb(hip, knee, lerpf(130.0, 128.0, r), 96.0, FUR_DD)
		_limb(knee, foot, 86.0, 70.0, FUR_DD)
		if sd > 0.0:
			draw_line(_w(hip + Vector2(60, 0)), _w(knee + Vector2(46, 0)), lit, 5.0 * sc, true)
			draw_line(_w(knee + Vector2(40, 0)), _w(foot + Vector2(34, 0)), lit, 5.0 * sc, true)
		_pw(PackedVector2Array([
			Vector2(foot.x - sd * 50.0, foot.y - 18.0), Vector2(foot.x + sd * 56.0, foot.y - 10.0),
			Vector2(foot.x + sd * 66.0, foot.y + 8.0), Vector2(foot.x - sd * 44.0, foot.y + 8.0)
		]), FUR_DD)
		_claws(Vector2(foot.x + sd * 56.0, foot.y), Vector2(sd * 0.6, 0.6), 17.0, 3, 26.0, BONE)

	# Tronco com pelos serrilhados
	var left := PackedVector2Array([
		Vector2(-72.0, sh_y - 34.0), Vector2(-sw * 0.8, sh_y - 14.0),
		Vector2(-sw, sh_y + 18.0), Vector2(-sw - 14.0, sh_y + 56.0)
	])
	for i in range(1, 7):
		var tt: float = float(i) / 6.0
		var y: float = lerpf(sh_y + 56.0, hip_y, tt)
		var x: float = -lerpf(sw - 6.0, 96.0, tt) - (14.0 if i % 2 == 1 else 0.0)
		left.append(Vector2(x, y))
	left.append(Vector2(-90.0, hip_y + 22.0))
	var torso := _concat(left, _mirror(left))
	_pw(torso, FUR_D)
	var span: float = hip_y - sh_y
	_pw(PackedVector2Array([
		Vector2(0, sh_y - 10.0), Vector2(-80, sh_y + 40.0), Vector2(-96, sh_y + 130.0),
		Vector2(-60, sh_y + span * 0.55), Vector2(0, sh_y + span * 0.78), Vector2(60, sh_y + span * 0.55),
		Vector2(96, sh_y + 130.0), Vector2(80, sh_y + 40.0)
	]), Color(0.24, 0.12, 0.38, 0.9))
	for i in 70:
		var fi := float(i)
		var u: float = _hsh(fi * 1.7 + 1.0) * 2.0 - 1.0
		var v: float = _hsh(fi * 2.9 + 5.0)
		var a := Vector2(u * sw * 0.78 * (0.7 + 0.3 * v), lerpf(sh_y + 20.0, hip_y - 10.0, v))
		var b := a + Vector2(u * 10.0, 26.0 + _hsh(fi) * 18.0)
		_lw(a, b, Color(0.58, 0.46, 0.85, 0.20) if u > 0.0 else Color(0.03, 0.01, 0.06, 0.35), 3.0)
	var rp := PackedVector2Array()
	for i in range(left.size() + 2, left.size() * 2 - 1):
		rp.append(_w(torso[i]))
	draw_polyline(rp, Color(0.70, 0.66, 1.0, 0.50), 5.0 * sc, true)

	# Braços e garras
	for si in 2:
		var sd2: float = -1.0 if si == 0 else 1.0
		var sh := Vector2(sd2 * (sw - 28.0), sh_y + 44.0)
		var hand := Vector2(sd2 * lerpf(sw + 32.0, sw + 52.0, _smooth(r)), lerpf(-14.0, hip_y + 70.0, _smooth(r)))
		var elbow := Vector2(sd2 * lerpf(sw + 105.0, sw + 85.0, r), sh_y * 0.55)
		_limb(sh, elbow, 92.0, 72.0, FUR_D)
		_limb(elbow, hand, 70.0, 62.0, FUR_D)
		for k in 3:
			var q: Vector2 = elbow.lerp(hand, 0.25 + 0.2 * float(k))
			_pw(PackedVector2Array([q + Vector2(sd2 * 36.0, -6.0), q + Vector2(sd2 * 62.0, 22.0), q + Vector2(sd2 * 30.0, 24.0)]), FUR_D)
		draw_circle(_w(hand), 40.0 * sc, FUR_D)
		_claws(hand + Vector2(0, 18), Vector2(sd2 * 0.15, 1.0), 22.0, 4, 34.0, BONE)
		if sd2 > 0.0:
			draw_line(_w(sh + Vector2(26, 0)), _w(elbow + Vector2(30, 0)), Color(0.7, 0.66, 1.0, 0.4), 5.0 * sc, true)
			draw_line(_w(elbow + Vector2(28, 0)), _w(hand + Vector2(26, 0)), Color(0.7, 0.66, 1.0, 0.4), 5.0 * sc, true)

	# Juba / trapézio atrás da cabeça
	var head_pos := _w(Vector2(lerpf(26.0, 0.0, r), sh_y - lerpf(88.0, 160.0, r)))
	var mane := PackedVector2Array()
	for i in 15:
		var ang: float = PI * (1.0 + float(i) / 14.0)
		var rad: float = (150.0 if i % 2 == 0 else 118.0) * sc * HEAD_SCALE
		mane.append(head_pos + Vector2(cos(ang) * rad * 1.15, sin(ang) * rad * 0.95 + 40.0 * sc))
	var mane_poly := PackedVector2Array()
	mane_poly.append_array(mane)
	mane_poly.append(_w(Vector2(sw * 0.95, sh_y + 40.0)))
	mane_poly.append(_w(Vector2(-sw * 0.95, sh_y + 40.0)))
	draw_colored_polygon(mane_poly, FUR_D)
	var mane_rim := PackedVector2Array()
	for i in range(8, 15):
		mane_rim.append(mane[i])
	draw_polyline(mane_rim, Color(0.72, 0.68, 1.0, 0.40), 4.0 * sc, true)

	# Cabeça
	_hc = head_pos
	_hr = lerpf(0.26, 0.0, r) + sin(t * 0.8) * 0.012
	_draw_head(eye, flash, snarl, t)

	# Ombros cobrem o queixo enquanto ele está caído
	if r < 0.7:
		var a2: float = 1.0 - _smooth(r / 0.7)
		_pw(PackedVector2Array([
			Vector2(-sw - 10.0, sh_y + 60.0), Vector2(-sw * 0.75, sh_y - 24.0), Vector2(-70.0, sh_y - 34.0),
			Vector2(0.0, sh_y - 26.0), Vector2(70.0, sh_y - 34.0), Vector2(sw * 0.75, sh_y - 24.0), Vector2(sw + 10.0, sh_y + 60.0)
		]), _ca(FUR_D, 0.96 * a2))
		var rim_pts := PackedVector2Array()
		for i in 9:
			var hx: float = lerpf(-sw * 0.8, sw * 0.8, float(i) / 8.0)
			_pw(PackedVector2Array([Vector2(hx - 20.0, sh_y - 14.0), Vector2(hx, sh_y - 46.0 - float(i % 2) * 12.0), Vector2(hx + 20.0, sh_y - 14.0)]), _ca(FUR_D, a2))
			rim_pts.append(_w(Vector2(hx, sh_y - 34.0 - float(i % 2) * 10.0)))
		draw_polyline(rim_pts, Color(0.70, 0.66, 1.0, 0.45 * a2), 4.0 * sc, true)

	# Sangue no peito
	for i in 6:
		var fi2 := float(i)
		var q2 := Vector2((fi2 - 2.5) * 30.0, sh_y + 130.0 + sin(fi2 * 1.5 + t) * 6.0 + _hsh(fi2) * 30.0)
		draw_circle(_w(q2), (5.0 + _hsh(fi2 + 3.0) * 5.0) * sc, Color(0.36, 0.03, 0.12, 0.70))

	# Vapor da respiração no ar frio
	var breath_k: float = clampf(eye * 1.5 + 0.25, 0.0, 1.0)
	for i in 5:
		var ph: float = fposmod(t * 0.35 + float(i) / 5.0, 1.0)
		var vp: Vector2 = _h(Vector2(0, 92)) + Vector2(sin(float(i) * 2.0) * 20.0 * ph, -ph * 80.0 * sc)
		draw_circle(vp, (10.0 + ph * 50.0) * sc, Color(0.75, 0.80, 1.0, 0.14 * (1.0 - ph) * breath_k))


func _draw_head(eye: float, flash: float, snarl: float, t: float) -> void:
	var k: float = _ws * HEAD_SCALE
	var half := PackedVector2Array([
		Vector2(-40, -104), Vector2(-78, -88), Vector2(-104, -58), Vector2(-118, -30), Vector2(-146, -6),
		Vector2(-122, 14), Vector2(-142, 46), Vector2(-108, 58), Vector2(-114, 94), Vector2(-70, 100),
		Vector2(-46, 124), Vector2(-18, 134)
	])
	var skull := PackedVector2Array([Vector2(0, -108)])
	skull.append_array(half)
	skull.append(Vector2(0, 140))
	skull.append_array(_mirror(half))

	# Orelhas
	for si in 2:
		var sd: float = -1.0 if si == 0 else 1.0
		_ph(PackedVector2Array([Vector2(sd * 98, -66), Vector2(sd * 158, -212), Vector2(sd * 44, -104)]), FUR_D)
		_ph(PackedVector2Array([Vector2(sd * 96, -86), Vector2(sd * 136, -178), Vector2(sd * 62, -104)]), Color(0.42, 0.14, 0.30, 0.95))
		_lh(Vector2(sd * 150, -206), Vector2(sd * 160, -232), FUR_D, 6.0)
	_ph(skull, FUR_D)

	# Luz da lua vindo da direita / sombra na esquerda
	_ph(PackedVector2Array([Vector2(10, -104), Vector2(60, -96), Vector2(104, -62), Vector2(120, -28), Vector2(90, -20), Vector2(40, -60)]), Color(0.34, 0.20, 0.52, 0.9))
	_ph(PackedVector2Array([Vector2(-30, -70), Vector2(-64, -60), Vector2(-100, -40), Vector2(-96, -18), Vector2(-20, -22)]), Color(0.10, 0.04, 0.17, 0.9))
	for i in 46:
		var fi := float(i)
		var u: float = _hsh(fi * 3.3 + 2.0) * 2.0 - 1.0
		var v: float = _hsh(fi * 1.9 + 7.0)
		var a := Vector2(u * 108.0 * (0.5 + 0.5 * v), lerpf(-96.0, 110.0, v))
		var d: Vector2 = Vector2(u * 0.35, 1.0).normalized() * (14.0 + _hsh(fi) * 12.0)
		_lh(a, a + d, Color(0.6, 0.5, 0.9, 0.20) if u > 0.0 else Color(0.02, 0.0, 0.05, 0.4), 2.5)

	# Focinho, sobrancelhas, nariz e boca
	_ph(PackedVector2Array([Vector2(-26, -22), Vector2(26, -22), Vector2(56, 34), Vector2(52, 86), Vector2(0, 106), Vector2(-52, 86), Vector2(-56, 34)]), Color(0.40, 0.28, 0.60))
	_ph(PackedVector2Array([Vector2(8, -22), Vector2(26, -22), Vector2(56, 34), Vector2(52, 86), Vector2(30, 96), Vector2(30, 20)]), Color(0.52, 0.40, 0.76, 0.55))
	for si in 2:
		var sd2: float = -1.0 if si == 0 else 1.0
		_ph(PackedVector2Array([
			Vector2(sd2 * 112, -44), Vector2(sd2 * 60, -58), Vector2(sd2 * 14, -34),
			Vector2(sd2 * 24, -12), Vector2(sd2 * 70, -20), Vector2(sd2 * 108, -12)
		]), Color(0.04, 0.015, 0.08, 0.95))
	_ph(PackedVector2Array([Vector2(-26, 30), Vector2(26, 30), Vector2(20, 52), Vector2(0, 62), Vector2(-20, 52)]), Color(0.04, 0.02, 0.07))
	_ph(PackedVector2Array([Vector2(-16, 34), Vector2(4, 34), Vector2(-2, 40), Vector2(-14, 42)]), Color(0.65, 0.60, 0.85, 0.5))
	var mouth := Color(0.03, 0.01, 0.05)
	_polyline_h(PackedVector2Array([Vector2(0, 62), Vector2(0, 78), Vector2(-24, 86), Vector2(-52, 84)]), mouth, 4.0)
	_polyline_h(PackedVector2Array([Vector2(0, 78), Vector2(24, 86), Vector2(52, 84)]), mouth, 4.0)
	if snarl > 0.0:
		for si in 2:
			var fx: float = -22.0 if si == 0 else 22.0
			_ph(PackedVector2Array([Vector2(fx - 8.0, 84), Vector2(fx + 8.0, 84), Vector2(fx, 84.0 + 22.0 * snarl)]), BONE)

	# Feridas
	for i in 3:
		var fi2 := float(i)
		var o: float = fi2 * 14.0
		var wa := Vector2(-108.0 + o, -14.0 + fi2)
		var wb := Vector2(-76.0 + o, 58.0 + fi2 * 2.0)
		_lh(wa, wb, WOUND, 6.0)
		_lh(wa + Vector2(2, 0), wb + Vector2(2, 0), WOUND_L, 2.0)
		var drip: float = fposmod(t * 0.30 + fi2 * 0.37, 1.0)
		_lh(wb, wb + Vector2(0, 14.0 + 38.0 * drip), _ca(WOUND, 0.85 * (1.0 - drip)), 3.5)
	for i in 2:
		var o2: float = float(i) * 14.0
		_lh(Vector2(86.0 + o2, -2), Vector2(66.0 + o2, 50), WOUND, 6.0)
		_lh(Vector2(88.0 + o2, -2), Vector2(68.0 + o2, 50), WOUND_L, 2.0)
	_lh(Vector2(26, -52), Vector2(66, -30), WOUND, 6.0)
	_lh(Vector2(66, -30), Vector2(74, 6), Color(0.40, 0.02, 0.10, 0.75), 3.5)
	for i in 7:
		var fi3 := float(i)
		var bq := Vector2(-30.0 + fi3 * 10.0, 92.0 + sin(fi3 * 2.3) * 6.0)
		draw_circle(_h(bq), (2.5 + fposmod(fi3 * 1.7, 2.5)) * k, Color(0.40, 0.03, 0.12, 0.80))

	# Contorno iluminado pela lua
	_polyline_h(PackedVector2Array([
		Vector2(0, -108), Vector2(40, -104), Vector2(78, -88), Vector2(104, -58), Vector2(118, -30), Vector2(146, -6)
	]), Color(0.72, 0.68, 1.0, 0.55), 4.0)

	# Olhos amarelos incandescentes
	var pulse: float = 0.62 + 0.16 * sin(t * 4.2)
	var dim := Color(0.45, 0.22, 0.05)
	var core := Color(1.0, 0.90, 0.35)
	var eye_col: Color = dim.lerp(core, eye)
	for si in 2:
		var sd3: float = -1.0 if si == 0 else 1.0
		_ph(PackedVector2Array([Vector2(sd3 * 86, -38), Vector2(sd3 * 55, -30), Vector2(sd3 * 24, -4), Vector2(sd3 * 56, -12)]), eye_col)
		var ec: Vector2 = _h(Vector2(sd3 * 54.0, -19.0))
		_glow(ec, 95.0 * k, Color(1.0, 0.70, 0.08, 0.26 * pulse * eye))
		_glow(ec, 46.0 * k, Color(1.0, 0.82, 0.12, 0.50 * pulse * eye))
		_glow(ec, 20.0 * k, Color(1.0, 0.95, 0.45, 0.55 * pulse * eye))
		if flash > 0.0:
			_glow(ec, 260.0 * k, Color(1.0, 0.85, 0.30, 0.30 * flash))


# ----------------------------------------------------------------------------
# .38 e garra
# ----------------------------------------------------------------------------

func _gun(pos: Vector2, sc: float, alpha: float) -> void:
	var t := _total
	var a := alpha
	var steel := Color(0.19, 0.20, 0.25, a)
	var hi := Color(0.62, 0.66, 0.78, 0.9 * a)
	var dark := Color(0.035, 0.025, 0.05, a)
	var wood := Color(0.27, 0.10, 0.08, a)

	_glow(pos, 300.0 * sc, Color(0.65, 0.72, 1.0, 0.07 * a))

	# Cano, massa de mira e ressalto inferior
	_poly(PackedVector2Array([_at(pos, sc, -340.0, -34.0), _at(pos, sc, -60.0, -40.0), _at(pos, sc, -60.0, 14.0), _at(pos, sc, -340.0, 6.0)]), steel)
	_poly(PackedVector2Array([_at(pos, sc, -340.0, -34.0), _at(pos, sc, -60.0, -40.0), _at(pos, sc, -60.0, -30.0), _at(pos, sc, -340.0, -26.0)]), hi)
	_poly(PackedVector2Array([_at(pos, sc, -338.0, -34.0), _at(pos, sc, -326.0, -52.0), _at(pos, sc, -312.0, -34.0)]), steel)
	_poly(PackedVector2Array([_at(pos, sc, -340.0, 6.0), _at(pos, sc, -60.0, 14.0), _at(pos, sc, -60.0, 28.0), _at(pos, sc, -300.0, 22.0)]), Color(0.12, 0.12, 0.16, a))
	draw_rect(Rect2(_at(pos, sc, -352.0, -38.0), Vector2(16.0, 48.0) * sc), dark)

	# Armação
	var frame := PackedVector2Array([
		_at(pos, sc, -70.0, -50.0), _at(pos, sc, 100.0, -54.0), _at(pos, sc, 138.0, -24.0), _at(pos, sc, 132.0, 48.0),
		_at(pos, sc, 70.0, 66.0), _at(pos, sc, -30.0, 36.0), _at(pos, sc, -70.0, 16.0)
	])
	_poly(frame, steel)
	draw_polyline(PackedVector2Array([_at(pos, sc, -70.0, -50.0), _at(pos, sc, 100.0, -54.0), _at(pos, sc, 138.0, -24.0)]), hi, 3.0 * sc, true)

	# Tambor com estrias
	_poly(PackedVector2Array([
		_at(pos, sc, -64.0, -58.0), _at(pos, sc, 40.0, -58.0), _at(pos, sc, 46.0, -40.0), _at(pos, sc, 46.0, 24.0),
		_at(pos, sc, 40.0, 40.0), _at(pos, sc, -64.0, 40.0), _at(pos, sc, -70.0, 24.0), _at(pos, sc, -70.0, -40.0)
	]), Color(0.23, 0.24, 0.30, a))
	for i in 5:
		var gx: float = -50.0 + float(i) * 21.0
		draw_line(_at(pos, sc, gx, -54.0), _at(pos, sc, gx, 36.0), dark, 5.0 * sc, true)
	draw_line(_at(pos, sc, -66.0, -44.0), _at(pos, sc, 42.0, -44.0), hi, 3.0 * sc, true)

	# Cão, guarda-mato e gatilho
	_poly(PackedVector2Array([_at(pos, sc, 100.0, -54.0), _at(pos, sc, 160.0, -92.0), _at(pos, sc, 176.0, -74.0), _at(pos, sc, 136.0, -36.0)]), Color(0.14, 0.14, 0.18, a))
	draw_arc(_at(pos, sc, 70.0, 56.0), 52.0 * sc, 0.0, PI, 18, Color(0.15, 0.15, 0.20, a), 9.0 * sc, true)
	draw_line(_at(pos, sc, 60.0, 40.0), _at(pos, sc, 52.0, 78.0), dark, 8.0 * sc, true)

	# Cabo de madeira gasto
	_poly(PackedVector2Array([
		_at(pos, sc, 96.0, 36.0), _at(pos, sc, 168.0, 30.0), _at(pos, sc, 212.0, 150.0),
		_at(pos, sc, 206.0, 238.0), _at(pos, sc, 118.0, 244.0), _at(pos, sc, 98.0, 120.0)
	]), wood)
	for i in 6:
		var fi := float(i)
		draw_line(_at(pos, sc, 112.0 + fi * 14.0, 60.0 + fi * 8.0), _at(pos, sc, 120.0 + fi * 14.0, 226.0), Color(0.12, 0.04, 0.04, 0.55 * a), 3.0 * sc, true)
	draw_line(_at(pos, sc, 168.0, 30.0), _at(pos, sc, 212.0, 150.0), Color(0.80, 0.40, 0.30, 0.35 * a), 3.0 * sc, true)

	# Arranhões de uso e gravação
	for i in 7:
		var fi2 := float(i)
		var sx: float = -300.0 + fi2 * 60.0 + _hsh(fi2) * 30.0
		draw_line(_at(pos, sc, sx, -24.0 + _hsh(fi2 + 2.0) * 18.0), _at(pos, sc, sx + 26.0 + _hsh(fi2) * 20.0, -18.0 + _hsh(fi2 + 5.0) * 20.0), Color(0.75, 0.78, 0.90, 0.25 * a), 2.0 * sc, true)
	draw_line(_at(pos, sc, -200.0, -6.0), _at(pos, sc, -120.0, -4.0), Color(0.90, 0.80, 0.50, 0.35 * a), 3.0 * sc, true)

	# Brilho percorrendo o cano
	var gl: float = fposmod(t * 0.22, 1.6) - 0.3
	var gx2: float = lerpf(-330.0, -80.0, clampf(gl, 0.0, 1.0))
	var ga: float = sin(clampf(gl, 0.0, 1.0) * PI)
	_glow_ellipse(_at(pos, sc, gx2, -30.0), 50.0 * sc, 12.0 * sc, Color(0.90, 0.95, 1.0, 0.55 * ga * a))


func _paw_gun(pos: Vector2, sc: float) -> void:
	var t := _total
	_gun(pos, sc, 1.0)
	var pf := Color(0.26, 0.12, 0.40)
	var pd := Color(0.14, 0.065, 0.24)

	# Antebraço saindo do quadro
	var a0 := _at(pos, sc, 290.0, 200.0)
	var b0 := _at(pos, sc, 760.0, 470.0)
	var d: Vector2 = (b0 - a0).normalized()
	var n := Vector2(-d.y, d.x)
	_poly(PackedVector2Array([a0 + n * 95.0 * sc, b0 + n * 150.0 * sc, b0 - n * 150.0 * sc, a0 - n * 95.0 * sc]), pd)
	for i in 7:
		var fi := float(i)
		var q: Vector2 = a0.lerp(b0, 0.12 + fi * 0.12)
		var off: Vector2 = n * (100.0 + fi * 8.0) * sc
		_poly(PackedVector2Array([q + off, q + off + d * 40.0 * sc + n * 34.0 * sc, q + d * 60.0 * sc + n * (96.0 + fi * 8.0) * sc]), pd)
	draw_polyline(PackedVector2Array([a0 + n * 95.0 * sc, b0 + n * 150.0 * sc]), Color(0.72, 0.68, 1.0, 0.35), 5.0 * sc, true)

	# Palma e pelos do pulso
	_poly(PackedVector2Array([
		_at(pos, sc, 150.0, 10.0), _at(pos, sc, 270.0, 40.0), _at(pos, sc, 330.0, 150.0),
		_at(pos, sc, 300.0, 300.0), _at(pos, sc, 210.0, 360.0), _at(pos, sc, 130.0, 300.0), _at(pos, sc, 190.0, 130.0)
	]), pd)
	_poly(PackedVector2Array([
		_at(pos, sc, 170.0, 40.0), _at(pos, sc, 262.0, 64.0), _at(pos, sc, 310.0, 160.0),
		_at(pos, sc, 290.0, 290.0), _at(pos, sc, 250.0, 300.0), _at(pos, sc, 250.0, 150.0)
	]), Color(0.20, 0.10, 0.32, 0.9))
	for i in 8:
		var wy: float = 60.0 + float(i) * 34.0
		_poly(PackedVector2Array([_at(pos, sc, 300.0, wy), _at(pos, sc, 352.0, wy + 14.0), _at(pos, sc, 304.0, wy + 34.0)]), pd)

	# Dedos envolvendo o cabo, com garras
	for i in 3:
		var fy: float = 96.0 + float(i) * 58.0
		var fa := _at(pos, sc, 205.0, fy + 10.0)
		var fb := _at(pos, sc, 92.0, fy + 22.0)
		draw_line(fa, fb, pf, 44.0 * sc, true)
		draw_circle(fb, 22.0 * sc, pf)
		draw_circle(fa, 22.0 * sc, pf)
		draw_line(fa + Vector2(0, -14.0 * sc), fb + Vector2(0, -14.0 * sc), Color(0.62, 0.50, 0.90, 0.5), 4.0 * sc, true)
		_poly(PackedVector2Array([fb + Vector2(-14.0, -8.0) * sc, fb + Vector2(-48.0, 26.0) * sc, fb + Vector2(-4.0, 12.0) * sc]), BONE)
	# Indicador no guarda-mato
	var ia := _at(pos, sc, 190.0, 30.0)
	var ib := _at(pos, sc, 70.0, 50.0)
	draw_line(ia, ib, pf, 38.0 * sc, true)
	draw_circle(ib, 19.0 * sc, pf)
	_poly(PackedVector2Array([ib + Vector2(-12.0, -6.0) * sc, ib + Vector2(-42.0, 24.0) * sc, ib + Vector2(-2.0, 10.0) * sc]), BONE)
	# Polegar sobre a armação
	var ta := _at(pos, sc, 190.0, -10.0)
	var tb := _at(pos, sc, 40.0, -66.0)
	draw_line(ta, tb, pf, 40.0 * sc, true)
	draw_circle(tb, 20.0 * sc, pf)
	_poly(PackedVector2Array([tb + Vector2(-6.0, -14.0) * sc, tb + Vector2(-40.0, -4.0) * sc, tb + Vector2(-6.0, 10.0) * sc]), BONE)

	# Sangue escorrendo dos nós dos dedos
	for i in 3:
		var fi2 := float(i)
		var ph: float = fposmod(t * 0.35 + fi2 * 0.33, 1.0)
		var dp := _at(pos, sc, 120.0 + fi2 * 26.0, 230.0)
		draw_line(dp, dp + Vector2(0, (10.0 + 60.0 * ph) * sc), Color(0.50, 0.03, 0.12, 0.85 * (1.0 - ph)), 4.0 * sc, true)
	for i in 6:
		var fi3 := float(i)
		draw_circle(_at(pos, sc, 120.0 + fi3 * 24.0, 150.0 + fi3 * 10.0 + _hsh(fi3) * 30.0), (3.0 + _hsh(fi3 + 2.0) * 3.0) * sc, Color(0.45, 0.03, 0.12, 0.8))
	draw_polyline(PackedVector2Array([_at(pos, sc, 270.0, 40.0), _at(pos, sc, 330.0, 150.0), _at(pos, sc, 300.0, 300.0)]), Color(0.72, 0.68, 1.0, 0.55), 5.0 * sc, true)


# ----------------------------------------------------------------------------
# Lobsome uivando (silhueta de perfil contra a lua)
# ----------------------------------------------------------------------------

func _hh(pivot: Vector2, tilt: float, sc: float, x: float, y: float) -> Vector2:
	return pivot + Vector2(x, y).rotated(tilt) * sc * 1.4


func _jw(pivot: Vector2, tilt: float, sc: float, jaw: float, x: float, y: float) -> Vector2:
	var q: Vector2 = Vector2(x - 60.0, y - 2.0).rotated(jaw) + Vector2(60.0, 2.0)
	return _hh(pivot, tilt, sc, q.x, q.y)


func _wolf_howl(base: Vector2, sc: float, t: float, howl: float) -> void:
	var sil := Color(0.012, 0.006, 0.024)
	var rim := Color(0.72, 0.68, 1.0, 0.60)
	var fang := Color(0.80, 0.78, 0.86, 0.9)

	var body_local := [
		Vector2(-75, 0), Vector2(-95, -70), Vector2(-115, -165), Vector2(-95, -260), Vector2(-105, -350),
		Vector2(-85, -440), Vector2(-45, -530), Vector2(0, -590), Vector2(30, -625), Vector2(60, -650),
		Vector2(115, -600), Vector2(130, -540), Vector2(125, -470), Vector2(95, -390), Vector2(70, -330),
		Vector2(55, -270), Vector2(90, -200), Vector2(55, -110), Vector2(65, -40), Vector2(125, -8), Vector2(125, 0)
	]
	var body := PackedVector2Array()
	for bp in body_local:
		body.append(_at(base, sc, bp.x, bp.y))
	draw_colored_polygon(body, sil)
	var back_rim := PackedVector2Array()
	for i in range(2, 11):
		back_rim.append(body[i])
	draw_polyline(back_rim, rim, 4.0 * sc, true)

	# Tufos de pelo nas costas e cauda
	var tufts := [Vector2(-85, -440), Vector2(-60, -490), Vector2(-30, -545), Vector2(5, -598), Vector2(40, -628)]
	for tp in tufts:
		_poly(PackedVector2Array([_at(base, sc, tp.x, tp.y), _at(base, sc, tp.x - 34.0, tp.y - 8.0), _at(base, sc, tp.x - 6.0, tp.y - 36.0)]), sil)
	_poly(PackedVector2Array([
		_at(base, sc, -100.0, -350.0), _at(base, sc, -170.0, -340.0), _at(base, sc, -215.0, -280.0), _at(base, sc, -200.0, -215.0),
		_at(base, sc, -185.0, -285.0), _at(base, sc, -140.0, -312.0), _at(base, sc, -100.0, -290.0)
	]), sil)

	# Braço pendendo (a garra segura o .38)
	var sh := _at(base, sc, 55.0, -560.0)
	var el := _at(base, sc, 100.0, -440.0)
	var hd := _at(base, sc, 115.0, -330.0)
	draw_line(sh, el, sil, 64.0 * sc, true)
	draw_line(el, hd, sil, 52.0 * sc, true)
	draw_circle(hd, 30.0 * sc, sil)
	draw_polyline(PackedVector2Array([sh + Vector2(26, -8) * sc, el + Vector2(30, 0) * sc, hd + Vector2(28, 0) * sc]), rim, 3.0 * sc, true)
	for i in 3:
		var fo: float = float(i) * 14.0
		_poly(PackedVector2Array([hd + Vector2(-14.0 + fo, 22.0) * sc, hd + Vector2(-8.0 + fo, 60.0) * sc, hd + Vector2(-2.0 + fo, 22.0) * sc]), sil)

	# Cabeça inclinada para trás, mandíbula se abrindo
	var pivot := _at(base, sc, 70.0, -640.0)
	var tilt: float = -lerpf(0.35, 0.95, howl)
	var jaw: float = lerpf(0.0, 0.62, howl)
	draw_colored_polygon(PackedVector2Array([
		_hh(pivot, tilt, sc, -60.0, -45.0), _hh(pivot, tilt, sc, 60.0, 2.0),
		_hh(pivot, tilt, sc, 30.0, 56.0), _hh(pivot, tilt, sc, -45.0, 60.0)
	]), sil)
	var upper := PackedVector2Array([
		_hh(pivot, tilt, sc, -60.0, -45.0), _hh(pivot, tilt, sc, 0.0, -58.0), _hh(pivot, tilt, sc, 60.0, -48.0),
		_hh(pivot, tilt, sc, 110.0, -34.0), _hh(pivot, tilt, sc, 152.0, -26.0), _hh(pivot, tilt, sc, 150.0, -14.0),
		_hh(pivot, tilt, sc, 60.0, 2.0)
	])
	draw_colored_polygon(upper, sil)
	draw_colored_polygon(PackedVector2Array([
		_jw(pivot, tilt, sc, jaw, 60.0, 2.0), _jw(pivot, tilt, sc, jaw, 138.0, 10.0), _jw(pivot, tilt, sc, jaw, 142.0, 34.0),
		_jw(pivot, tilt, sc, jaw, 110.0, 48.0), _jw(pivot, tilt, sc, jaw, 30.0, 56.0)
	]), sil)
	draw_colored_polygon(PackedVector2Array([
		_hh(pivot, tilt, sc, -30.0, -52.0), _hh(pivot, tilt, sc, -84.0, -128.0), _hh(pivot, tilt, sc, -4.0, -62.0)
	]), sil)
	draw_colored_polygon(PackedVector2Array([_hh(pivot, tilt, sc, 120.0, -10.0), _hh(pivot, tilt, sc, 128.0, 18.0), _hh(pivot, tilt, sc, 134.0, -10.0)]), fang)
	draw_colored_polygon(PackedVector2Array([_jw(pivot, tilt, sc, jaw, 120.0, 12.0), _jw(pivot, tilt, sc, jaw, 126.0, -8.0), _jw(pivot, tilt, sc, jaw, 134.0, 12.0)]), fang)
	draw_polyline(PackedVector2Array([
		_hh(pivot, tilt, sc, -60.0, -45.0), _hh(pivot, tilt, sc, 0.0, -58.0), _hh(pivot, tilt, sc, 60.0, -48.0),
		_hh(pivot, tilt, sc, 110.0, -34.0), _hh(pivot, tilt, sc, 152.0, -26.0)
	]), rim, 4.0 * sc, true)

	# Olho amarelo aceso
	var eye_p := _hh(pivot, tilt, sc, 70.0, -24.0)
	_glow(eye_p, 60.0 * sc, Color(1.0, 0.70, 0.10, 0.35))
	_glow(eye_p, 26.0 * sc, Color(1.0, 0.90, 0.40, 0.70))
	draw_colored_polygon(PackedVector2Array([
		_hh(pivot, tilt, sc, 56.0, -30.0), _hh(pivot, tilt, sc, 86.0, -24.0), _hh(pivot, tilt, sc, 60.0, -16.0)
	]), Color(1.0, 0.95, 0.50))

	# Vapor do uivo subindo em direção à lua
	for i in 6:
		var fi := float(i)
		var ph: float = fposmod(t * 0.35 + fi / 6.0, 1.0)
		var vp: Vector2 = _hh(pivot, tilt, sc, 150.0, -10.0) + Vector2(cos(tilt) * ph * 260.0 + sin(fi) * 14.0, sin(tilt) * ph * 260.0 - ph * 60.0) * sc * 0.9
		draw_circle(vp, (14.0 + ph * 60.0) * sc, Color(0.75, 0.80, 1.0, 0.16 * (1.0 - ph) * howl))
