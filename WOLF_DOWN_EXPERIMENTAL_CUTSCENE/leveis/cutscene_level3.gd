class_name Level3EndingCinematic
extends Control

## Wolf Down - Cinemática final (pós-Drácula). 100% desenhada por código, sem PNG.
## Plano 1: Drácula racha por dentro e se desfaz em cinzas e morcegos.
## Plano 2: a maldição se quebra - a lua vermelha esfria e os morcegos fogem do castelo.
## Plano 3: o lobo ferido cai de joelhos e volta à forma de caçador.
## Plano 4: amanhecer - o caçador descansa encostado numa lápide. Fade para "FIM".
##
## Emite `finished` quando termina (ou quando o jogador pula com ESC).

signal finished

const DESIGN_H: float = 1080.0
const TYPE_SPEED: float = 0.027
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const MUSIC_PATH: String = "res://leveis/moonlight_hollow.wav"
const THUNDER_PATH: String = "res://audio/thunder.wav"
const WOLF_SOUND_PATH: String = "res://audio/shot_07_olho_lobo.wav"

const SHOT_DURATION: Array[float] = [12.0, 10.0, 13.0, 16.0]
const ZOOM_FROM: Array[float] = [1.00, 1.00, 1.00, 1.10]
const ZOOM_TO: Array[float] = [1.12, 1.06, 1.12, 1.00]
const PAN_TO: Array[Vector2] = [Vector2(0, -20), Vector2(0, 40), Vector2(60, -10), Vector2(-40, 0)]

const GROUND: float = 900.0

# Paleta do lobo (mesma da cinemática do nível 1) e do caçador.
const FUR_D: Color = Color(0.14, 0.065, 0.24)
const FUR_DD: Color = Color(0.06, 0.025, 0.11)
const BONE: Color = Color(0.86, 0.82, 0.74)
const WOUND: Color = Color(0.52, 0.03, 0.13)
const COAT: Color = Color(0.11, 0.095, 0.15)
const COAT_D: Color = Color(0.05, 0.043, 0.075)
const SKIN: Color = Color(0.58, 0.46, 0.43)

var _shot: int = 0
var _elapsed: float = 0.0
var _total: float = 0.0
var _typing_index: int = 0
var _typing_time: float = 0.0
var _finished: bool = false
var _fade_value: float = 0.0
var _scale: float = 1.0
var _vw: float = 1920.0
var _flash_now: float = 0.0
var _prev_flash: float = 0.0

var _glow_tex: GradientTexture2D
var _vignette_tex: GradientTexture2D
var _music: AudioStreamPlayer

var _title_label: Label
var _story_label: Label
var _hint_label: Label
var _progress_label: Label

var _story: Array[String] = [
	"O Conde Drácula cambaleia.\nO poder de séculos se rompe por dentro,\ne seu corpo começa a ruir.",
	"Com ele, desmorona a maldição que cobria a noite.\nOs morcegos fogem. A lua volta a ser apenas uma lua.",
	"Ferido e exausto, o lobo cai de joelhos.\nO fardo que ele carregava se desfaz aos poucos...\ne o lobo volta a ser um homem.",
	"A vingança foi cumprida.\nPela primeira vez em muito tempo, o caçador não precisa lutar.\nEle fecha os olhos... e finalmente descansa."
]

var _titles: Array[String] = [
	"O FIM DO CONDE",
	"A MALDIÇÃO SE QUEBRA",
	"O FARDO SE DESFAZ",
	"DESCANSO"
]


# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

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
	_flash_now = _flash_for_shot()

	var current_text: String = _story[_shot]
	if _elapsed > 0.5 and _typing_index < current_text.length():
		_typing_time += delta
		var steps: int = int(_typing_time / TYPE_SPEED)
		if steps > 0:
			_typing_time -= float(steps) * TYPE_SPEED
			_typing_index = mini(_typing_index + steps, current_text.length())
			_story_label.text = current_text.substr(0, _typing_index)

	var time_left: float = SHOT_DURATION[_shot] - _elapsed
	var txt_a: float = 1.0
	if _shot == _story.size() - 1:
		txt_a = clampf((time_left - 3.0) / 1.0, 0.0, 1.0)
	_story_label.modulate.a = txt_a
	_title_label.modulate.a = clampf((_elapsed - 0.5) / 0.7, 0.0, 1.0) * txt_a
	_hint_label.modulate.a = txt_a
	_progress_label.modulate.a = txt_a
	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]

	_update_fade()
	_check_thunder()
	queue_redraw()

	if _elapsed >= SHOT_DURATION[_shot]:
		_next_shot()


func _update_fade() -> void:
	var fade_in: float = clampf(_elapsed / 0.75, 0.0, 1.0)
	var time_left: float = SHOT_DURATION[_shot] - _elapsed
	var fade_len: float = 0.75
	if _shot == _story.size() - 1:
		fade_len = 2.5
	var fade_out: float = 0.0
	if time_left < fade_len:
		fade_out = clampf(1.0 - (time_left / fade_len), 0.0, 1.0)
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
	_prev_flash = 0.0
	_flash_now = 0.0
	_story_label.text = ""
	_title_label.text = _titles[_shot]
	_title_label.modulate.a = 0.0
	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	if _shot == 2:
		_play_one(WOLF_SOUND_PATH, -12.0)
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_story_label.visible = false
	_title_label.visible = false
	_hint_label.visible = false
	_progress_label.visible = false
	_fade_value = 1.0
	queue_redraw()
	if is_instance_valid(_music):
		create_tween().tween_property(_music, "volume_db", -60.0, 0.6)
	await get_tree().create_timer(0.7, true, false, true).timeout
	finished.emit()


# ==============================================================================
# RECURSOS, ÁUDIO E INTERFACE
# ==============================================================================

func _make_gradient(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _make_textures() -> void:
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = _make_gradient(
		[0.0, 0.2, 0.55, 1.0],
		[Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256

	_vignette_tex = GradientTexture2D.new()
	_vignette_tex.gradient = _make_gradient(
		[0.0, 0.5, 1.0],
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.92)])
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.5)
	_vignette_tex.fill_to = Vector2(1.0, 0.5)
	_vignette_tex.width = 256
	_vignette_tex.height = 256


func _style_label(label: Label, color: Color, outline: Color) -> void:
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))


func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.anchor_left = 0.05
	_title_label.anchor_right = 0.95
	_title_label.anchor_top = 0.10
	_title_label.anchor_bottom = 0.19
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_title_label, Color(0.90, 0.78, 1.0), Color(0.10, 0.02, 0.15))
	add_child(_title_label)

	_story_label = Label.new()
	_story_label.anchor_left = 0.08
	_story_label.anchor_right = 0.92
	_story_label.anchor_top = 0.66
	_story_label.anchor_bottom = 0.89
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_story_label, Color(0.97, 0.95, 1.0), Color(0.03, 0.01, 0.05))
	add_child(_story_label)

	_hint_label = Label.new()
	_hint_label.anchor_left = 0.04
	_hint_label.anchor_right = 0.70
	_hint_label.anchor_top = 0.93
	_hint_label.anchor_bottom = 0.985
	_style_label(_hint_label, Color(0.72, 0.67, 0.82, 0.85), Color(0, 0, 0, 0.8))
	_hint_label.text = "ENTER / CLIQUE — AVANÇAR     ESC — PULAR"
	add_child(_hint_label)

	_progress_label = Label.new()
	_progress_label.anchor_left = 0.80
	_progress_label.anchor_right = 0.96
	_progress_label.anchor_top = 0.93
	_progress_label.anchor_bottom = 0.985
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_progress_label, Color(0.72, 0.67, 0.82, 0.85), Color(0, 0, 0, 0.8))
	add_child(_progress_label)


func _apply_ui_scale() -> void:
	var k: float = clampf(get_viewport_rect().size.y / DESIGN_H, 0.70, 1.30)
	_title_label.add_theme_font_size_override("font_size", int(60.0 * k))
	_title_label.add_theme_constant_override("outline_size", int(11.0 * k))
	_title_label.add_theme_constant_override("shadow_offset_x", int(3.0 * k))
	_title_label.add_theme_constant_override("shadow_offset_y", int(3.0 * k))
	_story_label.add_theme_font_size_override("font_size", int(40.0 * k))
	_story_label.add_theme_constant_override("outline_size", int(9.0 * k))
	_story_label.add_theme_constant_override("shadow_offset_x", int(3.0 * k))
	_story_label.add_theme_constant_override("shadow_offset_y", int(3.0 * k))
	for label in [_hint_label, _progress_label]:
		label.add_theme_font_size_override("font_size", int(22.0 * k))
		label.add_theme_constant_override("outline_size", int(5.0 * k))


func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC_PATH)
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -10.0, 2.5)


func _play_one(path: String, vol: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _check_thunder() -> void:
	var f: float = _flash_now
	if _shot == 0 and f > 0.8 and _prev_flash <= 0.8:
		_play_one(THUNDER_PATH, -3.0)
	_prev_flash = f


# ==============================================================================
# CÂMERA, CLARÕES E TREMOR
# ==============================================================================

func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _hsh(v: float) -> float:
	return fposmod(sin(v * 12.9898 + 78.233) * 43758.5453, 1.0)


func _ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _flash_for_shot() -> float:
	var t: float = _elapsed
	match _shot:
		0:
			if t < 5.0:
				return 0.22 * maxf(0.0, sin(t * 17.0)) * _smooth((t - 1.5) / 3.0)
			return clampf(1.0 - (t - 5.0) / 1.0, 0.0, 1.0)
		2:
			return maxf(0.0, 1.0 - absf(t - 5.8) / 0.7) * 0.7
	return 0.0


func _camera_shake() -> Vector2:
	var amp: float = 0.0
	match _shot:
		0:
			if _elapsed < 5.0:
				amp = 2.0 + 10.0 * _smooth((_elapsed - 1.5) / 3.5)
			else:
				amp = 2.0 + 16.0 * clampf(1.0 - (_elapsed - 5.0) / 5.0, 0.0, 1.0)
		1:
			amp = 7.0 * clampf(1.0 - _elapsed / 5.0, 0.0, 1.0)
	return Vector2(sin(_total * 71.0), cos(_total * 63.0)) * amp


func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_scale = screen.y / DESIGN_H
	_vw = screen.x / _scale

	var p: float = clampf(_elapsed / SHOT_DURATION[_shot], 0.0, 1.0)
	var e: float = _smooth(p)
	var zoom: float = lerpf(ZOOM_FROM[_shot], ZOOM_TO[_shot], e)
	var pan: Vector2 = PAN_TO[_shot] * e
	var s: float = _scale * zoom
	var origin: Vector2 = screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + (pan + _camera_shake()) * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	match _shot:
		0:
			_scene_fall()
		1:
			_scene_curse()
		2:
			_scene_transform()
		_:
			_scene_rest()

	# --- Pós-processamento em coordenadas de tela ---
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var screen_rect := Rect2(Vector2.ZERO, screen)

	if _flash_now > 0.0:
		var tint: Color = Color(1.0, 0.82, 0.82) if _shot == 0 else Color(0.82, 0.72, 1.0)
		draw_rect(screen_rect, Color(tint.r, tint.g, tint.b, 0.55 * _flash_now))

	draw_texture_rect(_vignette_tex, screen_rect, false, Color(1, 1, 1, 0.95))

	var seed_v: float = float(int(_total * 24.0))
	for i in 60:
		var fi: float = float(i)
		var gx: float = _hsh(fi * 1.37 + seed_v) * screen.x
		var gy: float = _hsh(fi * 2.11 + seed_v * 1.7) * screen.y
		draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(1, 1, 1, 0.045) if i % 2 == 0 else Color(0, 0, 0, 0.10))

	# Escurece a parte de baixo para o texto ficar legível.
	var top_y: float = screen.y * 0.55
	var dk := Color(0.01, 0.005, 0.02, 0.88)
	var dk0 := Color(0.01, 0.005, 0.02, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, top_y), Vector2(screen.x, top_y), Vector2(screen.x, screen.y), Vector2(0, screen.y)]),
		PackedColorArray([dk0, dk0, dk, dk]))

	var bar_h: float = screen.y * 0.075 * _smooth(_total / 1.2)
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.96))
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color(0, 0, 0, 0.96))

	if _fade_value > 0.0:
		draw_rect(screen_rect, Color(0, 0, 0, _fade_value))

	# Cartela final sobre o preto.
	if _shot == _story.size() - 1 and not _finished:
		var tl: float = SHOT_DURATION[_shot] - _elapsed
		var ta: float = _smooth((2.2 - tl) / 1.0)
		if ta > 0.0:
			var fs: int = int(150.0 * _scale)
			var fs2: int = int(46.0 * _scale)
			draw_string(FONT_BOLD, Vector2(0.0, screen.y * 0.5), "FIM", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs, Color(0.95, 0.86, 1.0, ta))
			draw_string(FONT_BOLD, Vector2(0.0, screen.y * 0.5 + 90.0 * _scale), "A VINGANÇA FOI CUMPRIDA", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs2, Color(0.80, 0.70, 0.95, ta * 0.9))


# ==============================================================================
# PRIMITIVAS
# ==============================================================================

func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	var r: Rect2 = rect
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _glow(pos: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _glow_ellipse(pos: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, color)


func _xf(offsets: Array, base: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in offsets:
		out.append(base + (o as Vector2) * k)
	return out


func _pl(base: Vector2, k: float, offsets: Array, color: Color) -> void:
	draw_colored_polygon(_xf(offsets, base, k), color)


func _ln(a: Vector2, b: Vector2, base: Vector2, k: float, color: Color, width: float) -> void:
	draw_line(base + a * k, base + b * k, color, width * k, true)


func _limb_l(base: Vector2, s: float, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(base + a * s, base + b * s, col, w * s, true)
	draw_circle(base + a * s, w * 0.5 * s, col)
	draw_circle(base + b * s, w * 0.5 * s, col)


func _draw_stars(count: int, y_max: float, intensity: float) -> void:
	for i in count:
		var fi: float = float(i)
		var x: float = _hsh(fi * 1.37) * (_vw + 200.0) - 100.0
		var y: float = _hsh(fi * 2.71 + 5.0) * y_max
		var tw: float = 0.45 + 0.35 * sin(_total * (1.5 + _hsh(fi * 0.7) * 2.5) + fi)
		draw_circle(Vector2(x, y), 1.2 + _hsh(fi * 3.3) * 1.8, Color(0.85, 0.88, 1.0, tw * intensity))


func _draw_moon(pos: Vector2, radius: float, col: Color, glow_col: Color) -> void:
	_glow(pos, radius * 5.5, _ca(glow_col, 0.20))
	_glow(pos, radius * 2.8, _ca(glow_col, 0.38))
	draw_circle(pos, radius, col.darkened(0.22))
	draw_circle(pos + Vector2(-radius * 0.06, -radius * 0.05), radius * 0.93, col)
	for i in 7:
		var fi: float = float(i)
		var a: float = _hsh(fi * 4.3) * TAU
		var d: float = _hsh(fi * 1.9) * radius * 0.62
		draw_circle(pos + Vector2(cos(a), sin(a)) * d, radius * (0.07 + _hsh(fi * 8.1) * 0.12), Color(col.r * 0.72, col.g * 0.72, col.b * 0.78, 0.38))


func _clouds(y: float, col: Color, speed: float, count: int, seed_v: float) -> void:
	var span: float = _vw + 1400.0
	for i in count:
		var fi: float = float(i)
		var w: float = 650.0 + _hsh(fi + seed_v) * 550.0
		var x: float = fposmod(_hsh(fi * 1.9 + seed_v) * span + _total * speed, span) - 700.0
		var yy: float = y + (_hsh(fi * 4.1 + seed_v) - 0.5) * 170.0
		_glow_ellipse(Vector2(x, yy), w * 0.5, 60.0 + _hsh(fi * 7.7 + seed_v) * 50.0, col)


func _ridge(x: float, base: float, amp: float, sd: float) -> float:
	return base - amp * (0.55 + 0.25 * sin(x * 0.0042 + sd) + 0.14 * sin(x * 0.011 + sd * 2.3) + 0.06 * sin(x * 0.027 + sd * 4.1))


func _mountains(base: float, amp: float, col: Color, sd: float) -> void:
	var pts := PackedVector2Array()
	var x: float = -200.0
	while x <= _vw + 200.0:
		pts.append(Vector2(x, _ridge(x, base, amp, sd)))
		x += 40.0
	pts.append(Vector2(_vw + 200.0, 1500.0))
	pts.append(Vector2(-200.0, 1500.0))
	draw_colored_polygon(pts, col)


func _pine(x: float, base_y: float, h: float, col: Color) -> void:
	var sway: float = sin(_total * 0.7 + x * 0.01) * 3.0
	var tiers: int = 5
	for t in tiers:
		var f: float = float(t) / float(tiers)
		var apex := Vector2(x + sway * (1.0 - f), base_y - h + h * f * 0.78)
		var tier_h: float = h * 0.34
		var half_w: float = h * (0.10 + 0.085 * float(t + 1))
		draw_colored_polygon(PackedVector2Array([apex, Vector2(x + half_w, apex.y + tier_h), Vector2(x - half_w, apex.y + tier_h)]), col)
	draw_rect(Rect2(x - h * 0.02, base_y - h * 0.1, h * 0.04, h * 0.12), col)


func _pine_row(base_y: float, step: float, h_min: float, h_var: float, col: Color, sd: float) -> void:
	var x: float = -60.0
	var i: int = 0
	while x < _vw + 80.0:
		_pine(x + (_hsh(float(i) + sd) - 0.5) * step * 0.5, base_y, h_min + _hsh(float(i) * 2.3 + sd) * h_var, col)
		x += step
		i += 1


func _draw_mist(y: float, col: Color) -> void:
	for i in 12:
		var fi: float = float(i)
		var x: float = fposmod(fi * 240.0 + _total * 18.0, _vw + 400.0) - 200.0
		var yy: float = y + sin(_total * 0.5 + fi) * 18.0 + float(i % 3) * 14.0
		_glow_ellipse(Vector2(x, yy), 220.0, 28.0, col)


func _bat(pos: Vector2, s: float, phase: float, col: Color) -> void:
	var flap: float = sin(_total * 11.0 + phase)
	var wu: float = -26.0 * flap * s
	for side in [-1.0, 1.0]:
		var sd: float = side
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0.0, -4.0 * s),
			pos + Vector2(sd * 18.0 * s, -14.0 * s + wu * 0.5),
			pos + Vector2(sd * 50.0 * s, -6.0 * s + wu),
			pos + Vector2(sd * 40.0 * s, 8.0 * s + wu * 0.6),
			pos + Vector2(sd * 30.0 * s, 2.0 * s + wu * 0.35),
			pos + Vector2(sd * 22.0 * s, 12.0 * s + wu * 0.2),
			pos + Vector2(sd * 12.0 * s, 5.0 * s),
			pos + Vector2(0.0, 9.0 * s)]), col)
	draw_circle(pos + Vector2(0.0, 2.0 * s), 6.0 * s, col)


# ==============================================================================
# SALÃO DO TRONO (planos 1 e 3). k = 0: lua vermelha / k = 1: luar pálido
# ==============================================================================

func _ogive(cx: float, spring_y: float, hw: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a_apex: float = acos((hw - r) / r)
	var steps: int = 14
	for i in steps + 1:
		var a: float = lerpf(PI, a_apex, float(i) / float(steps))
		pts.append(Vector2(cx - hw + r + r * cos(a), spring_y - r * sin(a)))
	for i in range(1, steps + 1):
		var a2: float = lerpf(PI - a_apex, 0.0, float(i) / float(steps))
		pts.append(Vector2(cx + hw - r + r * cos(a2), spring_y - r * sin(a2)))
	return pts


func _hall(k: float) -> void:
	var cx: float = _vw * 0.5
	var floor_y: float = 900.0
	var hw: float = 300.0
	var spring: float = 430.0
	var arch: PackedVector2Array = _ogive(cx, spring, hw, hw * 1.2)

	var sky_top: Color = Color(0.10, 0.01, 0.03).lerp(Color(0.05, 0.07, 0.16), k)
	var sky_bot: Color = Color(0.40, 0.05, 0.08).lerp(Color(0.26, 0.30, 0.48), k)
	_vgrad(Rect2(cx - hw - 20.0, -100.0, hw * 2.0 + 40.0, floor_y + 100.0), sky_top, sky_bot)
	var moon_col: Color = Color(0.95, 0.16, 0.18).lerp(Color(0.88, 0.90, 0.98), k)
	var moon_glow: Color = Color(1.0, 0.10, 0.12).lerp(Color(0.55, 0.62, 0.95), k)
	_draw_moon(Vector2(cx, 470.0), 190.0, moon_col, moon_glow)

	var wall_c: Color = Color(0.012, 0.006, 0.014).lerp(Color(0.016, 0.018, 0.034), k)
	var wall := PackedVector2Array([
		Vector2(-500.0, 1500.0), Vector2(-500.0, -400.0), Vector2(_vw + 500.0, -400.0),
		Vector2(_vw + 500.0, 1500.0), Vector2(cx + hw, 1500.0)])
	for i in range(arch.size() - 1, -1, -1):
		wall.append(arch[i])
	wall.append(Vector2(cx - hw, 1500.0))
	draw_colored_polygon(wall, wall_c)
	var rim_c: Color = Color(1.0, 0.25, 0.30, 0.55).lerp(Color(0.60, 0.68, 1.0, 0.45), k)
	draw_polyline(arch, rim_c, 4.0, true)

	# Vitral (tracejado)
	for mx in [-0.5, 0.0, 0.5]:
		draw_line(Vector2(cx + mx * hw, spring - 130.0), Vector2(cx + mx * hw, floor_y), wall_c, 12.0)
	draw_line(Vector2(cx - hw, 640.0), Vector2(cx + hw, 640.0), wall_c, 12.0)
	draw_line(Vector2(cx - hw, 800.0), Vector2(cx + hw, 800.0), wall_c, 10.0)
	draw_arc(Vector2(cx, 260.0), 70.0, 0.0, TAU, 28, wall_c, 10.0)
	for i in 6:
		var a: float = float(i) * TAU / 6.0
		draw_line(Vector2(cx, 260.0), Vector2(cx, 260.0) + Vector2(cos(a), sin(a)) * 70.0, wall_c, 7.0)

	# Raios de luz da janela
	var beam: Color = Color(1.0, 0.1, 0.15).lerp(Color(0.60, 0.68, 1.0), k)
	for i in 4:
		var fi: float = float(i)
		var x0: float = cx - hw * 0.75 + fi * hw * 0.5
		draw_polygon(
			PackedVector2Array([Vector2(x0 - 30.0, 640.0), Vector2(x0 + 30.0, 640.0), Vector2(x0 + 260.0 + fi * 60.0, floor_y + 160.0), Vector2(x0 - 140.0 + fi * 60.0, floor_y + 160.0)]),
			PackedColorArray([_ca(beam, 0.10), _ca(beam, 0.10), _ca(beam, 0.0), _ca(beam, 0.0)]))

	# Chão e tapete
	_vgrad(Rect2(-400.0, floor_y, _vw + 800.0, 500.0), Color(0.035, 0.012, 0.02).lerp(Color(0.03, 0.035, 0.06), k), Color(0.008, 0.003, 0.006))
	_glow_ellipse(Vector2(cx, floor_y + 40.0), 520.0, 60.0, _ca(beam, 0.30))
	var carpet: Color = Color(0.30, 0.02, 0.05).lerp(Color(0.16, 0.05, 0.10), k)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 170.0, floor_y), Vector2(cx + 170.0, floor_y), Vector2(cx + 420.0, 1200.0), Vector2(cx - 420.0, 1200.0)]), carpet)
	draw_line(Vector2(cx - 170.0, floor_y), Vector2(cx - 420.0, 1200.0), Color(0.75, 0.50, 0.15, 0.45), 7.0)
	draw_line(Vector2(cx + 170.0, floor_y), Vector2(cx + 420.0, 1200.0), Color(0.75, 0.50, 0.15, 0.45), 7.0)

	# Braseiros laterais
	for sx in [cx - 520.0, cx + 520.0]:
		var fl: float = 0.8 + 0.2 * sin(_total * 9.0 + sx)
		_glow(Vector2(sx, floor_y - 240.0), 190.0, _ca(Color(1.0, 0.25, 0.2).lerp(Color(0.5, 0.6, 1.0), k), 0.30 * fl))
		draw_line(Vector2(sx, floor_y + 20.0), Vector2(sx, floor_y - 220.0), Color(0.03, 0.02, 0.03), 10.0)


# ==============================================================================
# PLANO 1: DRÁCULA SE DESTRÓI
# ==============================================================================

func _dracula(base: Vector2, k: float, cs: float, a: float, eye: float) -> void:
	if a <= 0.01:
		return
	var sil := Color(0.0, 0.0, 0.0, a)
	var rim := Color(1.0, 0.35, 0.35, 0.9 * a)
	_pl(base, k, [Vector2(0, 160), Vector2(-60, 130), Vector2(-120, 160), Vector2(-160 - cs, 30), Vector2(-220 - cs, -50), Vector2(-150, -130),
		Vector2(-40, -70), Vector2(40, -70), Vector2(150, -130), Vector2(220 + cs, -50), Vector2(160 + cs, 30), Vector2(120, 160), Vector2(60, 130)], sil)
	_pl(base, k, [Vector2(-30, -60), Vector2(30, -60), Vector2(15, 20), Vector2(-15, 20)], sil)
	_pl(base, k, [Vector2(-15, 20), Vector2(15, 20), Vector2(8, 140), Vector2(-8, 140)], sil)
	_ln(Vector2(-30, -50), Vector2(-100, -20), base, k, sil, 14.0)
	_ln(Vector2(30, -50), Vector2(100, -20), base, k, sil, 14.0)
	_pl(base, k, [Vector2(0, -60), Vector2(-40, -120), Vector2(40, -120)], sil)
	draw_circle(base + Vector2(0, -100) * k, 16.0 * k, sil)
	_pl(base, k, [Vector2(-15, -110), Vector2(15, -110), Vector2(25 + cs * 0.5, -60), Vector2(-25 - cs * 0.5, -60)], sil)
	draw_polyline(_xf([Vector2(-220 - cs, -50), Vector2(-150, -130), Vector2(-40, -70)], base, k), rim, 3.0, true)
	draw_polyline(_xf([Vector2(40, -70), Vector2(150, -130), Vector2(220 + cs, -50)], base, k), rim, 3.0, true)
	for side in [-1.0, 1.0]:
		var ep: Vector2 = base + Vector2(side * 6.0, -102.0) * k
		_glow(ep, 24.0 * eye, Color(1.0, 0.0, 0.1, 0.8 * a))
		draw_circle(ep, 3.0, Color(1.0, 0.4, 0.4, a))


func _crack_line(base: Vector2, k: float, pts: Array, progress: float, a: float) -> void:
	var n: int = pts.size() - 1
	for i in n:
		var seg: float = clampf(progress * float(n) - float(i), 0.0, 1.0)
		if seg <= 0.0:
			continue
		var p0: Vector2 = base + (pts[i] as Vector2) * k
		var p1: Vector2 = p0.lerp(base + (pts[i + 1] as Vector2) * k, seg)
		draw_line(p0, p1, Color(1.0, 0.15, 0.1, 0.55 * a), 12.0 * k, true)
		draw_line(p0, p1, Color(1.0, 0.85, 0.55, 0.95 * a), 4.0 * k, true)


func _scene_fall() -> void:
	var cx: float = _vw * 0.5
	var t: float = _elapsed
	_hall(0.0)

	var crack: float = _smooth((t - 1.0) / 3.8)
	var decay: float = _smooth((t - 5.0) / 4.5)
	var alive: float = 1.0 - decay
	var base := Vector2(cx, 640.0 + decay * 190.0 + sin(_total * 2.5) * 10.0 * alive)
	var k: float = 1.5 * (1.0 - 0.45 * decay)
	var jitter: Vector2 = Vector2(sin(_total * 63.0), cos(_total * 57.0)) * (1.0 + 7.0 * crack) * alive
	var cs: float = 20.0 + sin(_total * 1.5) * 10.0 + crack * 26.0 * sin(_total * 9.0)
	var chest: Vector2 = base + jitter + Vector2(0.0, -30.0) * k

	# Aura e raios de energia escapando de dentro
	_glow(chest, (260.0 + 320.0 * crack) * k * 0.8, Color(1.0, 0.10, 0.15, (0.20 + 0.40 * crack) * alive))
	for i in 14:
		var fi: float = float(i)
		var ang: float = fi * TAU / 14.0 + _total * 0.3
		var ln: float = (150.0 + 260.0 * _hsh(fi * 2.3)) * crack * alive * (0.7 + 0.3 * sin(_total * 12.0 + fi))
		draw_line(chest, chest + Vector2(cos(ang), sin(ang)) * ln, Color(1.0, 0.35, 0.30, 0.38 * alive), 4.0, true)

	var eye: float = 1.0 + 1.5 * crack
	_dracula(base + jitter, k, cs, alive, eye)

	# Rachaduras de luz percorrendo o corpo
	if alive > 0.05:
		var b: Vector2 = base + jitter
		_crack_line(b, k, [Vector2(0, -110), Vector2(-8, -80), Vector2(8, -50), Vector2(-6, -15), Vector2(6, 25), Vector2(-4, 70), Vector2(2, 130)], crack, alive)
		_crack_line(b, k, [Vector2(-10, -60), Vector2(-50, -40), Vector2(-70, -5), Vector2(-120, 30), Vector2(-150, 90)], clampf(crack * 1.2 - 0.2, 0.0, 1.0), alive)
		_crack_line(b, k, [Vector2(10, -55), Vector2(55, -45), Vector2(80, -10), Vector2(130, 20), Vector2(165, 80)], clampf(crack * 1.2 - 0.3, 0.0, 1.0), alive)
		_crack_line(b, k, [Vector2(-100, -90), Vector2(-150, -100), Vector2(-200, -60)], clampf(crack * 1.4 - 0.6, 0.0, 1.0), alive)
		_crack_line(b, k, [Vector2(100, -90), Vector2(150, -100), Vector2(200, -60)], clampf(crack * 1.4 - 0.6, 0.0, 1.0), alive)
		_glow(chest, 70.0 * k * crack, Color(1.0, 0.8, 0.5, 0.55 * crack * alive))

	# Cinzas e brasas saindo do corpo
	for i in 110:
		var fi2: float = float(i)
		var birth: float = 5.0 + _hsh(fi2 * 1.3) * 3.6
		var age: float = t - birth
		if age <= 0.0 or age > 4.0:
			continue
		var sx: float = (_hsh(fi2 * 2.1) - 0.5) * 300.0 * k * 0.7
		var sy: float = -_hsh(fi2 * 3.7) * 330.0 * k * 0.6 + 40.0
		var vx: float = (_hsh(fi2 * 5.3) - 0.5) * 220.0
		var vy: float = -(40.0 + _hsh(fi2 * 7.1) * 150.0)
		var pp: Vector2 = Vector2(cx, 760.0) + Vector2(sx + vx * age + sin(age * 3.0 + fi2) * 18.0, sy + vy * age + age * age * 34.0)
		var al: float = clampf(1.0 - age / 4.0, 0.0, 1.0)
		var hot: float = clampf(1.0 - age / 1.2, 0.0, 1.0)
		var col: Color = Color(0.45, 0.40, 0.45).lerp(Color(1.0, 0.3, 0.2), hot)
		draw_circle(pp, 2.0 + _hsh(fi2 * 9.1) * 4.0, Color(col.r, col.g, col.b, al))
		if hot > 0.2:
			_glow(pp, 16.0, Color(1.0, 0.25, 0.15, 0.3 * hot))

	# Morcegos escapando da explosão
	for i in 14:
		var fi3: float = float(i)
		var age2: float = t - (5.1 + _hsh(fi3 * 1.7) * 1.5)
		if age2 <= 0.0:
			continue
		var ang2: float = -PI * (0.08 + 0.84 * _hsh(fi3 * 3.1))
		var dist: float = age2 * (170.0 + 230.0 * _hsh(fi3 * 4.3))
		var bp: Vector2 = Vector2(cx, 700.0) + Vector2(cos(ang2), sin(ang2)) * dist
		_bat(bp, 0.55 + _hsh(fi3 * 5.7) * 0.7, fi3, Color(0.02, 0.0, 0.01, clampf(1.0 - age2 / 7.0, 0.0, 1.0)))

	# Montinho de cinzas no chão
	var pile: float = _smooth((t - 6.0) / 4.0)
	if pile > 0.0:
		var py: float = 935.0
		_glow_ellipse(Vector2(cx, py + 8.0), 270.0 * pile, 26.0 * pile, Color(0, 0, 0, 0.6))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 210.0 * pile, py + 10.0), Vector2(cx - 90.0 * pile, py - 30.0 * pile), Vector2(cx, py - 48.0 * pile),
			Vector2(cx + 100.0 * pile, py - 26.0 * pile), Vector2(cx + 220.0 * pile, py + 10.0)]), Color(0.16, 0.14, 0.17))
		_glow(Vector2(cx, py - 22.0), 130.0 * pile, Color(1.0, 0.2, 0.1, 0.26 * (1.0 - _smooth((t - 8.0) / 3.0))))


# ==============================================================================
# PLANO 2: A MALDIÇÃO SE QUEBRA (castelo por fora)
# ==============================================================================

func _win(pos: Vector2, w: float, h: float, lit: float, sd: float) -> void:
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h, w, h), Color(0.02, 0.012, 0.03))
	if lit > 0.02:
		var fl: float = 0.75 + 0.25 * sin(_total * 7.0 + sd * 5.0)
		draw_rect(Rect2(pos.x - w * 0.5 + 2.0, pos.y - h + 2.0, w - 4.0, h - 4.0), Color(1.0, 0.15, 0.18, 0.95 * fl * lit))
		_glow(pos + Vector2(0.0, -h * 0.5), maxf(w * 3.0, 14.0), Color(1.0, 0.15, 0.18, 0.30 * fl * lit))


func _castle(base: Vector2, s: float, lit: float) -> void:
	var cx: float = base.x
	var by: float = base.y
	var wall := Color(0.05, 0.038, 0.08)
	var roof := Color(0.028, 0.02, 0.05)
	var rim := Color(0.60, 0.55, 0.88, 0.45).lerp(Color(1.0, 0.25, 0.30, 0.6), lit)

	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 760.0 * s, 1500.0), Vector2(cx - 690.0 * s, by + 150.0 * s), Vector2(cx - 540.0 * s, by + 70.0 * s),
		Vector2(cx - 400.0 * s, by + 18.0 * s), Vector2(cx + 400.0 * s, by + 18.0 * s), Vector2(cx + 560.0 * s, by + 80.0 * s),
		Vector2(cx + 700.0 * s, by + 160.0 * s), Vector2(cx + 760.0 * s, 1500.0)]), Color(0.025, 0.02, 0.045))

	draw_rect(Rect2(cx - 400.0 * s, by - 170.0 * s, 800.0 * s, 190.0 * s), wall)
	for i in 22:
		draw_rect(Rect2(cx - 400.0 * s + float(i) * 38.0 * s, by - 196.0 * s, 22.0 * s, 28.0 * s), wall)

	var towers: Array = [[-340.0, 110.0, 330.0, 470.0], [340.0, 110.0, 330.0, 470.0], [-175.0, 92.0, 420.0, 570.0], [175.0, 92.0, 420.0, 570.0]]
	var idx: float = 0.0
	for tw in towers:
		var tx: float = tw[0]
		var w: float = tw[1] * s
		var th: float = tw[2] * s
		var ta: float = tw[3] * s
		var x: float = cx + tx * s
		draw_rect(Rect2(x - w * 0.5, by - th, w, th + 24.0 * s), wall)
		draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5 - 14.0 * s, by - th), Vector2(x, by - ta), Vector2(x + w * 0.5 + 14.0 * s, by - th)]), roof)
		draw_line(Vector2(x - w * 0.5, by - th), Vector2(x - w * 0.5, by), rim, 3.0 * s, true)
		_win(Vector2(x, by - th * 0.62), 16.0 * s, 38.0 * s, lit, idx)
		_win(Vector2(x, by - th * 0.30), 14.0 * s, 32.0 * s, lit, idx + 1.0)
		idx += 1.0

	draw_rect(Rect2(cx - 105.0 * s, by - 470.0 * s, 210.0 * s, 490.0 * s), wall.lightened(0.04))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 125.0 * s, by - 470.0 * s), Vector2(cx, by - 700.0 * s), Vector2(cx + 125.0 * s, by - 470.0 * s)]), roof)
	draw_line(Vector2(cx - 105.0 * s, by - 470.0 * s), Vector2(cx - 105.0 * s, by), rim, 3.0 * s, true)
	draw_line(Vector2(cx, by - 700.0 * s), Vector2(cx, by - 775.0 * s), roof, 4.0 * s)

	var rc := Vector2(cx, by - 360.0 * s)
	if lit > 0.02:
		_glow(rc, 120.0 * s, Color(1.0, 0.2, 0.2, 0.35 * lit))
	draw_circle(rc, 44.0 * s, Color(0.02, 0.012, 0.03))
	draw_circle(rc, 38.0 * s, Color(0.02, 0.012, 0.03).lerp(Color(1.0, 0.25, 0.22), lit))
	for i in 8:
		var a: float = float(i) * TAU / 8.0
		draw_line(rc, rc + Vector2(cos(a), sin(a)) * 38.0 * s, Color(0.02, 0.012, 0.03), 3.0 * s)

	for i in 8:
		if absf(float(i) - 3.5) < 1.0:
			continue
		_win(Vector2(cx - 300.0 * s + float(i) * 86.0 * s, by - 60.0 * s), 16.0 * s, 44.0 * s, lit, float(i) * 2.0)

	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 52.0 * s, by + 20.0 * s), Vector2(cx - 52.0 * s, by - 60.0 * s), Vector2(cx - 30.0 * s, by - 100.0 * s),
		Vector2(cx + 30.0 * s, by - 100.0 * s), Vector2(cx + 52.0 * s, by - 60.0 * s), Vector2(cx + 52.0 * s, by + 20.0 * s)]), Color(0.01, 0.006, 0.015))


func _scene_curse() -> void:
	var cx: float = _vw * 0.5
	var t: float = _elapsed
	var k: float = _smooth((t - 1.0) / 6.0)
	var lit: float = 1.0 - _smooth((t - 0.5) / 3.0)

	_vgrad(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0),
		Color(0.11, 0.01, 0.04).lerp(Color(0.05, 0.07, 0.17), k),
		Color(0.40, 0.05, 0.09).lerp(Color(0.30, 0.34, 0.54), k))
	_draw_stars(70, 560.0, k)
	_draw_moon(Vector2(cx + 380.0, 330.0), 150.0,
		Color(0.95, 0.16, 0.18).lerp(Color(0.90, 0.92, 1.0), k),
		Color(1.0, 0.10, 0.12).lerp(Color(0.55, 0.62, 0.95), k))
	_clouds(330.0, Color(0.10, 0.0, 0.02, 0.5).lerp(Color(0.12, 0.14, 0.26, 0.4), k), 16.0, 5, 3.0)
	_mountains(820.0, 160.0, Color(0.04, 0.03, 0.08), 3.3)

	# Pilar de luz vermelha sobre a torre central que se apaga
	var tower_top := Vector2(cx - 120.0, 880.0 - 700.0 * 0.9)
	if lit > 0.02:
		draw_polygon(
			PackedVector2Array([tower_top + Vector2(-40, 0), tower_top + Vector2(40, 0), tower_top + Vector2(160, -900), tower_top + Vector2(-160, -900)]),
			PackedColorArray([Color(1.0, 0.1, 0.15, 0.30 * lit), Color(1.0, 0.1, 0.15, 0.30 * lit), Color(1.0, 0.1, 0.15, 0.0), Color(1.0, 0.1, 0.15, 0.0)]))

	_castle(Vector2(cx - 120.0, 880.0), 0.9, lit)

	# Onda de choque quando a maldição se quebra
	var shock: float = clampf((t - 0.3) / 4.0, 0.0, 1.0)
	if shock > 0.0 and shock < 1.0:
		var ctr := Vector2(cx - 120.0, 520.0)
		draw_arc(ctr, shock * 1700.0, 0.0, TAU, 80, Color(1.0, 0.75, 0.75, 0.45 * (1.0 - shock)), 4.0 + 12.0 * (1.0 - shock), true)

	# Morcegos fugindo
	for i in 18:
		var fi: float = float(i)
		var age: float = t - (0.4 + _hsh(fi * 1.9) * 1.8)
		if age <= 0.0:
			continue
		var ang: float = -PI * (0.05 + 0.9 * _hsh(fi * 3.3))
		var dist: float = age * (120.0 + 260.0 * _hsh(fi * 4.1))
		_bat(Vector2(cx - 120.0, 420.0) + Vector2(cos(ang), sin(ang)) * dist, 0.5 + _hsh(fi * 6.3) * 0.7, fi, Color(0.01, 0.0, 0.01))

	_clouds(930.0, Color(0.45, 0.30, 0.50, 0.14), 14.0, 7, 12.0)
	_pine_row(990.0, 110.0, 380.0, 200.0, Color(0.006, 0.006, 0.014), 7.0)
	_draw_mist(1000.0, Color(0.55, 0.50, 0.75, 0.10))

	# Brasas subindo, perdendo o vermelho
	for i in 40:
		var fi2: float = float(i)
		var ph: float = fposmod(_total * (0.06 + _hsh(fi2) * 0.08) + _hsh(fi2 + 9.0), 1.0)
		var ex: float = fposmod(_hsh(fi2 + 1.0) * _vw + sin(_total * 0.7 + fi2) * 40.0, _vw)
		var ey: float = 1000.0 - ph * 800.0
		var ecol: Color = Color(1.0, 0.3, 0.2).lerp(Color(0.8, 0.85, 1.0), k)
		draw_circle(Vector2(ex, ey), 1.6 + _hsh(fi2 + 4.0) * 1.8, Color(ecol.r, ecol.g, ecol.b, sin(ph * PI) * 0.8))


# ==============================================================================
# PLANO 3: O LOBO VOLTA A SER CAÇADOR
# ==============================================================================

## Pose ajoelhada, de perfil, olhando para a direita. wolf = true: forma de lobo; false: caçador.
## tint (0..1) clareia o corpo em direção a um branco-roxo (usado na transformação).
func _kneel(base: Vector2, s: float, wolf: bool, tint: float, breath: float, eye: float) -> void:
	var flash_c := Color(0.85, 0.75, 1.0)
	var body_c: Color = (FUR_D if wolf else COAT).lerp(flash_c, tint)
	var dark_c: Color = (FUR_DD if wolf else COAT_D).lerp(flash_c, tint * 0.85)
	var rim_c: Color = (Color(0.72, 0.68, 1.0, 0.7) if wolf else Color(0.82, 0.80, 0.95, 0.55))
	var by := Vector2(0.0, breath)

	_glow_ellipse(base + Vector2(40.0, 8.0) * s, 300.0 * s, 32.0 * s, Color(0, 0, 0, 0.55))

	# Pernas (uma no chão, outra dobrada à frente) e braço de apoio
	_limb_l(base, s, Vector2(-90, -100), Vector2(-40, -30), 70.0, dark_c)
	_limb_l(base, s, Vector2(-40, -22), Vector2(-210, -22), 44.0, dark_c)
	_limb_l(base, s, Vector2(60, -110), Vector2(150, -62), 76.0, dark_c)
	_limb_l(base, s, Vector2(150, -62), Vector2(150, -10), 56.0, dark_c)
	_pl(base, s, [Vector2(120, -18), Vector2(232, -10), Vector2(242, 4), Vector2(115, 4)], dark_c)
	_limb_l(base, s, Vector2(60, -240) + by, Vector2(150, -130), 56.0, body_c)
	_limb_l(base, s, Vector2(150, -130), Vector2(205, -30), 46.0, body_c)

	# Tronco curvado
	var torso_src: Array = [Vector2(-110, -90), Vector2(-135, -190), Vector2(-90, -270), Vector2(-10, -320),
		Vector2(70, -325), Vector2(120, -285), Vector2(125, -210), Vector2(100, -140), Vector2(70, -90)]
	var torso: Array = []
	for pnt in torso_src:
		torso.append((pnt as Vector2) + by)
	_pl(base, s, torso, body_c)
	draw_polyline(_xf([Vector2(-135, -190) + by, Vector2(-90, -270) + by, Vector2(-10, -320) + by, Vector2(70, -325) + by], base, s), rim_c, 4.0 * s, true)

	# Sangue
	for i in 5:
		var fi: float = float(i)
		draw_circle(base + (Vector2(-40.0 + fi * 28.0, -210.0 + sin(fi * 1.7) * 18.0) + by) * s, (4.0 + _hsh(fi + 2.0) * 4.0) * s, Color(0.40, 0.03, 0.12, 0.8 * (1.0 - tint)))

	if wolf:
		# Tufos de pelo nas costas
		for i in 6:
			var u: float = float(i) / 5.0
			var tp: Vector2 = Vector2(-135.0, -190.0).lerp(Vector2(70.0, -325.0), u) + by
			_pl(base, s, [tp, tp + Vector2(-28, -6), tp + Vector2(-4, -36)], body_c)
		# Feridas
		_ln(Vector2(-60, -250) + by, Vector2(0, -190) + by, base, s, _ca(WOUND, 0.95), 8.0)
		_ln(Vector2(-40, -270) + by, Vector2(20, -214) + by, base, s, _ca(WOUND, 0.95), 7.0)
		var drip: float = fposmod(_total * 0.35, 1.0)
		_ln(Vector2(0, -190) + by, Vector2(0, -190 + 20 + 70 * drip) + by, base, s, Color(0.5, 0.03, 0.12, 0.8 * (1.0 - drip)), 4.0)
		# Garras na mão de apoio
		for i in 3:
			var cxo: float = float(i) * 20.0
			_pl(base, s, [Vector2(188 + cxo, -14), Vector2(214 + cxo, 10), Vector2(206 + cxo, -14)], BONE)
		# Cabeça de lobo, baixa
		var hp := Vector2(150, -285) + by
		_pl(base, s, [hp + Vector2(-48, -30), hp + Vector2(-54, -108), hp + Vector2(0, -50)], dark_c)
		_pl(base, s, [hp + Vector2(0, -50), hp + Vector2(30, -118), hp + Vector2(48, -44)], dark_c)
		draw_circle(base + hp * s, 56.0 * s, body_c)
		_pl(base, s, [hp + Vector2(30, -14), hp + Vector2(132, 30), hp + Vector2(124, 58), hp + Vector2(26, 46)], body_c)
		_pl(base, s, [hp + Vector2(120, 22), hp + Vector2(138, 28), hp + Vector2(128, 40)], dark_c)
		_ln(hp + Vector2(30, -14), hp + Vector2(132, 30), base, s, rim_c, 3.0)
		_ln(hp + Vector2(96, 54), hp + Vector2(108, 82), base, s, Color(0.5, 0.03, 0.12, 0.8), 5.0)
		# Olho amarelo que vai se apagando
		var ep: Vector2 = base + (hp + Vector2(52, -6)) * s
		var pulse: float = 0.7 + 0.2 * sin(_total * 4.0)
		_glow(ep, 70.0 * s, Color(1.0, 0.70, 0.10, 0.30 * pulse * eye))
		_glow(ep, 28.0 * s, Color(1.0, 0.90, 0.40, 0.65 * pulse * eye))
		_pl(base, s, [hp + Vector2(36, -12), hp + Vector2(70, -4), hp + Vector2(42, 4)], Color(0.45, 0.22, 0.05).lerp(Color(1.0, 0.92, 0.45), eye))
	else:
		# Mão com o revólver caído no chão
		draw_circle(base + Vector2(208, -22) * s, 24.0 * s, SKIN.darkened(0.35).lerp(flash_c, tint * 0.6))
		_pl(base, s, [Vector2(212, -34), Vector2(282, -44), Vector2(286, -28), Vector2(216, -14)], Color(0.18, 0.19, 0.24))
		# Ombro enfaixado
		_ln(Vector2(-10, -300) + by, Vector2(50, -262) + by, base, s, Color(0.82, 0.80, 0.74), 16.0)
		draw_circle(base + (Vector2(24, -282) + by) * s, 5.0 * s, Color(0.5, 0.05, 0.12))
		# Cabeça baixa, chapéu e cachecol
		var hp2 := Vector2(140, -292) + by
		_pl(base, s, [hp2 + Vector2(-40, 20), hp2 + Vector2(40, 24), hp2 + Vector2(50, 58), hp2 + Vector2(-30, 62)], Color(0.35, 0.06, 0.10).lerp(flash_c, tint * 0.6))
		draw_circle(base + (hp2 + Vector2(6, 8)) * s, 32.0 * s, SKIN.darkened(0.30).lerp(flash_c, tint * 0.6))
		_pl(base, s, [hp2 + Vector2(-64, -2), hp2 + Vector2(-42, -48), hp2 + Vector2(22, -56), hp2 + Vector2(52, -10), hp2 + Vector2(84, 0), hp2 + Vector2(-72, 6)], COAT_D.lerp(flash_c, tint * 0.8))
		draw_polyline(_xf([hp2 + Vector2(-42, -48), hp2 + Vector2(22, -56), hp2 + Vector2(52, -10), hp2 + Vector2(84, 0)], base, s), rim_c, 3.0 * s, true)


func _scene_transform() -> void:
	var cx: float = _vw * 0.5
	var t: float = _elapsed
	_hall(1.0)

	# Cinzas do Drácula ao longe, já frias
	var py: float = 945.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 300.0, py + 10.0), Vector2(cx + 380.0, py - 22.0), Vector2(cx + 450.0, py - 34.0),
		Vector2(cx + 520.0, py - 18.0), Vector2(cx + 590.0, py + 10.0)]), Color(0.13, 0.12, 0.15))

	var morph: float = _smooth((t - 3.5) / 4.5)
	var breath: float = sin(_total * 2.2) * (6.0 - 3.0 * morph)
	var base := Vector2(cx - 80.0, 930.0)

	# Facho de luar sobre o lobo
	draw_polygon(
		PackedVector2Array([Vector2(cx - 90.0, 640.0), Vector2(cx + 90.0, 640.0), Vector2(base.x + 260.0, 960.0), Vector2(base.x - 260.0, 960.0)]),
		PackedColorArray([Color(0.6, 0.66, 1.0, 0.09), Color(0.6, 0.66, 1.0, 0.09), Color(0.6, 0.66, 1.0, 0.03), Color(0.6, 0.66, 1.0, 0.03)]))

	# Aura roxa durante a transformação
	var aura: float = sin(clampf(morph, 0.0, 1.0) * PI)
	_glow(base + Vector2(30.0, -170.0), 380.0, Color(0.60, 0.30, 1.0, 0.38 * aura))

	# Troca de forma sob o clarão: lobo -> caçador
	if morph < 0.5:
		_kneel(base, 1.0, true, _smooth(morph * 2.0) * 0.9, breath, 1.0 - morph * 2.0)
	else:
		_kneel(base, 0.94, false, 0.9 * (1.0 - _smooth((morph - 0.5) * 2.0)), breath * 0.7, 0.0)

	# Partículas de energia subindo do corpo
	for i in 100:
		var fi: float = float(i)
		var age: float = t - (3.5 + _hsh(fi * 1.3) * 4.2)
		if age <= 0.0 or age > 3.0:
			continue
		var sx: float = -150.0 + _hsh(fi * 2.7) * 350.0
		var sy: float = -30.0 - _hsh(fi * 4.1) * 290.0
		var pp: Vector2 = base + Vector2(sx + sin(age * 2.0 + fi) * 24.0, sy - age * (70.0 + _hsh(fi * 6.1) * 120.0))
		var al: float = sin(clampf(age / 3.0, 0.0, 1.0) * PI)
		_glow(pp, 12.0 + _hsh(fi * 8.3) * 16.0, Color(0.70, 0.45, 1.0, 0.45 * al))
		draw_circle(pp, 2.0 + _hsh(fi * 9.9) * 2.0, Color(0.92, 0.85, 1.0, 0.85 * al))

	# Respiração em vapor depois que ele volta ao normal
	if morph > 0.9:
		for i in 4:
			var ph: float = fposmod(_total * 0.3 + float(i) / 4.0, 1.0)
			_glow(base + Vector2(250.0 + ph * 60.0, -250.0 - ph * 80.0), 14.0 + ph * 40.0, Color(0.75, 0.80, 1.0, 0.12 * (1.0 - ph)))

	_draw_mist(960.0, Color(0.35, 0.40, 0.65, 0.08))
	for i in 24:
		var fj: float = float(i)
		var ph2: float = fposmod(_total * (0.04 + _hsh(fj) * 0.05) + _hsh(fj + 2.0), 1.0)
		var dx: float = _hsh(fj + 4.0) * _vw + sin(_total * 0.6 + fj) * 24.0
		draw_circle(Vector2(dx, 1000.0 - ph2 * 900.0), 1.2 + _hsh(fj + 8.0) * 2.0, Color(0.75, 0.8, 1.0, 0.4 * sin(ph2 * PI)))


# ==============================================================================
# PLANO 4: AMANHECER E DESCANSO
# ==============================================================================

func _hunter_sit(base: Vector2, s: float, k: float, breath: float) -> void:
	var rim: Color = Color(0.80, 0.78, 0.95, 0.5).lerp(Color(1.0, 0.72, 0.45, 0.85), k)
	var by := Vector2(0.0, breath)

	_glow_ellipse(base + Vector2(40.0, 8.0) * s, 320.0 * s, 30.0 * s, Color(0, 0, 0, 0.5))

	# Lápide onde ele se apoia
	var stone_c: Color = Color(0.10, 0.10, 0.15).lerp(Color(0.30, 0.22, 0.25), k)
	_pl(base, s, [Vector2(-215, 0), Vector2(-215, -360), Vector2(-180, -410), Vector2(-120, -420), Vector2(-90, -390), Vector2(-90, 0)], stone_c)
	_ln(Vector2(-90, -390), Vector2(-90, 0), base, s, rim, 4.0)
	_ln(Vector2(-150, -380), Vector2(-150, -300), base, s, stone_c.darkened(0.4), 8.0)
	_ln(Vector2(-175, -350), Vector2(-125, -350), base, s, stone_c.darkened(0.4), 8.0)

	# Pernas esticadas e botas
	_pl(base, s, [Vector2(-60, -70), Vector2(120, -62), Vector2(230, -30), Vector2(236, 0), Vector2(-60, 0)], COAT_D)
	_pl(base, s, [Vector2(200, -42), Vector2(264, -26), Vector2(270, 0), Vector2(200, 0)], Color(0.05, 0.035, 0.03))
	_ln(Vector2(-60, -70), Vector2(120, -62), base, s, rim, 3.0)

	# Tronco, apoiado na pedra
	var torso: Array = [Vector2(-85, -40), Vector2(-92, -170) + by, Vector2(-62, -262) + by, Vector2(8, -290) + by,
		Vector2(56, -222) + by, Vector2(66, -120), Vector2(50, -45)]
	_pl(base, s, torso, COAT)
	draw_polyline(_xf([Vector2(56, -222) + by, Vector2(66, -120), Vector2(50, -45)], base, s), rim, 4.0 * s, true)
	# Cachecol e ombro enfaixado
	_pl(base, s, [Vector2(-52, -290) + by, Vector2(30, -296) + by, Vector2(50, -250) + by, Vector2(-50, -246) + by], Color(0.35, 0.06, 0.10))
	_ln(Vector2(-40, -210) + by, Vector2(10, -170) + by, base, s, Color(0.82, 0.80, 0.74), 14.0)

	# Braço descansando sobre o joelho, com o revólver
	_limb_l(base, s, Vector2(10, -240) + by, Vector2(110, -140), 50.0, COAT)
	_limb_l(base, s, Vector2(110, -140), Vector2(175, -80), 42.0, COAT)
	draw_circle(base + Vector2(182.0, -76.0) * s, 22.0 * s, SKIN.darkened(0.25))
	_pl(base, s, [Vector2(170, -92), Vector2(236, -104), Vector2(240, -90), Vector2(176, -76)], Color(0.20, 0.21, 0.27))
	_pl(base, s, [Vector2(172, -80), Vector2(190, -78), Vector2(182, -48), Vector2(164, -52)], Color(0.27, 0.10, 0.08))

	# Cabeça inclinada, chapéu sobre os olhos
	var hp := Vector2(-18, -318) + by
	draw_circle(base + (hp + Vector2(8, 10)) * s, 28.0 * s, SKIN.darkened(0.2).lerp(Color(0.85, 0.62, 0.50), k * 0.5))
	_pl(base, s, [hp + Vector2(-62, -4), hp + Vector2(-40, -46), hp + Vector2(18, -52), hp + Vector2(50, -10), hp + Vector2(78, 2), hp + Vector2(-70, 6)], Color(0.03, 0.025, 0.045))
	draw_polyline(_xf([hp + Vector2(-40, -46), hp + Vector2(18, -52), hp + Vector2(50, -10), hp + Vector2(78, 2)], base, s), rim, 3.0 * s, true)


func _scene_rest() -> void:
	var cx: float = _vw * 0.5
	var t: float = _elapsed
	var k: float = _smooth(t / (SHOT_DURATION[3] - 3.0))

	_vgrad(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0),
		Color(0.04, 0.05, 0.14).lerp(Color(0.24, 0.30, 0.56), k),
		Color(0.16, 0.12, 0.26).lerp(Color(1.0, 0.62, 0.35), k))
	_draw_stars(70, 520.0, 1.0 - k)

	# Sol nascendo atrás das montanhas
	var sun := Vector2(cx + 360.0, lerpf(1060.0, 740.0, k))
	_glow(sun, 900.0, Color(1.0, 0.55, 0.30, 0.20 * k))
	_glow(sun, 420.0, Color(1.0, 0.75, 0.40, 0.42 * k))
	draw_circle(sun, 95.0, Color(1.0, 0.88, 0.60, clampf(k * 1.4, 0.0, 1.0)))
	for i in 7:
		var fi: float = float(i)
		var a: float = -PI * (0.12 + 0.76 * fi / 6.0) + sin(_total * 0.3 + fi) * 0.01
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([sun + n * 6.0, sun - n * 6.0, sun + d * 1600.0 - n * 90.0, sun + d * 1600.0 + n * 90.0]), Color(1.0, 0.75, 0.45, 0.05 * k))

	_clouds(380.0, Color(0.20, 0.16, 0.34, 0.35).lerp(Color(1.0, 0.60, 0.50, 0.30), k), 10.0, 6, 5.0)
	_mountains(760.0, 190.0, Color(0.05, 0.04, 0.10).lerp(Color(0.22, 0.11, 0.22), k), 1.7)
	# Castelo ao longe, agora apagado
	_castle(Vector2(cx - 470.0, 745.0), 0.26, 0.0)
	_mountains(840.0, 130.0, Color(0.04, 0.03, 0.08).lerp(Color(0.14, 0.08, 0.16), k), 4.2)
	_pine_row(870.0, 80.0, 220.0, 140.0, Color(0.025, 0.018, 0.045).lerp(Color(0.08, 0.05, 0.10), k), 1.0)

	# Chão
	_vgrad(Rect2(-200.0, 850.0, _vw + 400.0, 420.0), Color(0.05, 0.05, 0.09).lerp(Color(0.20, 0.12, 0.15), k), Color(0.01, 0.01, 0.02))
	_glow_ellipse(Vector2(sun.x, 880.0), 520.0, 40.0, Color(1.0, 0.6, 0.3, 0.22 * k))

	# Lápides ao fundo
	for i in 7:
		var fi2: float = float(i)
		var tx: float = _vw * (0.06 + 0.14 * fi2) + (_hsh(fi2) - 0.5) * 50.0
		if absf(tx - (cx - 80.0)) < 260.0:
			continue
		var th: float = 60.0 + _hsh(fi2 + 3.0) * 50.0
		var tc: Color = Color(0.06, 0.06, 0.10).lerp(Color(0.24, 0.16, 0.20), k)
		draw_rect(Rect2(tx - 22.0, 880.0 - th, 44.0, th), tc)
		draw_circle(Vector2(tx, 880.0 - th), 22.0, tc)

	_hunter_sit(Vector2(cx - 80.0, 940.0), 1.2, k, sin(_total * 1.4) * 3.0)

	_draw_mist(960.0, Color(1.0, 0.70, 0.55, 0.10 * k).lerp(Color(0.35, 0.40, 0.65, 0.08), 1.0 - k))

	# Pássaros cruzando o céu no fim
	var bird_a: float = _smooth((k - 0.55) / 0.3)
	if bird_a > 0.0:
		for i in 6:
			var fb: float = float(i)
			var bx: float = fposmod(_total * 55.0 + fb * 260.0, _vw + 300.0) - 150.0
			var byy: float = 330.0 + fb * 38.0 + sin(_total * 1.3 + fb) * 20.0
			var fl: float = sin(_total * 9.0 + fb) * 9.0
			draw_polyline(PackedVector2Array([Vector2(bx - 16.0, byy + fl), Vector2(bx, byy), Vector2(bx + 16.0, byy + fl)]), Color(0.10, 0.06, 0.12, bird_a), 3.0, true)

	# Poeira dourada na luz
	for i in 30:
		var fj: float = float(i)
		var ph: float = fposmod(_total * (0.03 + _hsh(fj) * 0.04) + _hsh(fj + 2.0), 1.0)
		var dx: float = _hsh(fj + 4.0) * _vw + sin(_total * 0.5 + fj) * 24.0
		draw_circle(Vector2(dx, 1000.0 - ph * 900.0), 1.2 + _hsh(fj + 8.0) * 2.0, Color(1.0, 0.85, 0.6, 0.45 * sin(ph * PI) * k))
