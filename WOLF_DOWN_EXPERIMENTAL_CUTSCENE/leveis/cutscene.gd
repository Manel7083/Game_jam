class_name OpeningCinematic
extends Control

## Wolf Down - Cinemática de abertura (v2).
## Arte 100% procedural em _draw(), num canvas virtual de 1920x1080 que escala para qualquer
## resolução. Câmera (zoom/pan), tremor, relâmpagos, névoa e brilhos suaves usam texturas
## radiais geradas em código - nenhum asset novo é necessário.

const DESIGN_H: float = 1080.0
const TYPE_SPEED: float = 0.028
const NEXT_LEVEL_INDEX: int = 1 # 0 = Tutorial, 1 = Level 1 (a cena de controles já ensina o básico)
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const MUSIC_PATH: String = "res://leveis/moonlight_hollow.wav"
const AUDIO_DIR: String = "res://audio/"
const THUNDER_PATH: String = "res://audio/thunder.wav"
const SHOT_AUDIO: Array[String] = [
	"shot_00_prologo.wav",
	"shot_01_sepulturas.wav",
	"shot_02_vilarejo.wav",
	"shot_03_castelo.wav",
	"shot_04_cripta.wav",
	"shot_05_trono.wav",
	"shot_06_cacador.wav",
	"shot_07_olho_lobo.wav",
	"shot_08_controles.wav",
	"shot_09_final.wav"
]

var _shot_player: AudioStreamPlayer
var _prev_flash: float = 0.0
var _thunder_cd: float = 0.0
@export var force_fullscreen: bool = true
@export var play_music: bool = true

const SHOT_DURATION: Array[float] = [
	6, # 0 - Prólogo
	12.5, # 1 - Sepulturas
	12.5, # 2 - Vilarejo
	12.5, # 3 - Castelo
	12.5, # 4 - Despertar do Drácula
	12.5, # 5 - Drácula Despertado
	12.5, # 6 - O Caçador
	12.5, # 7 - Olho do Lobo
	12.5, # 8 - Controles
	12.5  # 9 - Título Final
]

# Câmera por plano: zoom inicial/final e deslocamento final (em px do canvas virtual).
const ZOOM_FROM: Array[float] = [1.00, 1.00, 1.00, 1.00, 1.12, 1.00, 1.00, 1.00, 1.00, 1.00]
const ZOOM_TO: Array[float] = [1.12, 1.07, 1.08, 1.18, 1.00, 1.10, 1.07, 1.06, 1.00, 1.08]
const PAN_TO: Array[Vector2] = [
	Vector2(-60, 10), Vector2(50, 0), Vector2(-70, 0), Vector2(0, 70), Vector2(0, 0),
	Vector2(0, -20), Vector2(120, 0), Vector2(0, -10), Vector2(0, 0), Vector2(0, 40)
]

var _shot: int = 0
var _elapsed: float = 0.0
var _total: float = 0.0
var _typing_index: int = 0
var _typing_time: float = 0.0
var _finished: bool = false
var _fade_value: float = 0.0

var _scale: float = 1.0 # tela -> canvas virtual
var _vw: float = 1920.0 # largura do canvas virtual
var _flash_now: float = 0.0

var _glow_tex: GradientTexture2D
var _vignette_tex: GradientTexture2D
var _card_style: StyleBoxFlat
var _key_style: StyleBoxFlat
var _key_hi_style: StyleBoxFlat

var _story: Array[String] = [
	"Por séculos, o vilarejo viveu sob o peso de um nome esquecido.",
	"Então as sepulturas se abriram.\nOs mortos retornaram, e a noite aprendeu a caçar novamente.",
	"O vilarejo caiu em silêncio.\nPortas foram destruídas. Sangue manchou as ruas.\nNinguém sabia de onde as criaturas vinham.",
	"No centro da maldição ergue-se um castelo ancestral.\nAlgo em seu interior despertou.",
	"Sepultado sob a pedra e a escuridão,\nDrácula abre seus olhos mais uma vez.\nO selo foi quebrado.",
	"Ele se lembra do gosto do sangue.\nEle se lembra do medo.\nE ele se lembra do caçador.",
	"Um homem adentra a terra amaldiçoada.\nSem exército. Sem testemunhas.\nApenas uma arma... e um motivo para sobreviver.",
	"Ele não é qualquer caçador.\nNa escuridao iluminado por um lindo luar.\nQue se Desperta seu olhar dourado",
	"GUIAS DE SOBREVIVÊNCIA E CONTROLES",
	"O castelo está à espera.\nDrácula está acordado.\n\nE a caçada começa..."
]

var _titles: Array[String] = [
	"WOLF DOWN — PRÓLOGO",
	"AS SEPULTURAS LEMBRAM",
	"VILAREJO DE SANGUE",
	"O CASTELO DESPERTA",
	"O REI ADORMECIDO",
	"A ESCURIDÃO RETORNA",
	"O CAÇADOR",
	"SEU FARDO DESPERTA AO SENTIR O SANGUE",
	"COMO SOBREVIVER",
	"A CAÇADA COMEÇA"
]

var _story_label: Label
var _title_label: Label
var _hint_label: Label
var _progress_label: Label
var _music: AudioStreamPlayer


# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if force_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_make_textures()
	_make_styles()
	_build_ui()
	_reset_shot()
	resized.connect(_apply_ui_scale)
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_total += delta
	_update_thunder(delta)

	var current_text: String = _story[_shot]
	if _elapsed > 0.5 and _typing_index < current_text.length():
		_typing_time += delta
		var steps: int = int(_typing_time / TYPE_SPEED)
		if steps > 0:
			_typing_time -= float(steps) * TYPE_SPEED
			_typing_index = mini(_typing_index + steps, current_text.length())
			_story_label.text = current_text.substr(0, _typing_index)

	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	_update_fade()
	queue_redraw()

	if _elapsed >= SHOT_DURATION[_shot]:
		_next_shot()


func _update_fade() -> void:
	var fade_in: float = clampf(_elapsed / 0.75, 0.0, 1.0)
	var time_left: float = SHOT_DURATION[_shot] - _elapsed
	var fade_out: float = 0.0
	if time_left < 0.75:
		fade_out = clampf(1.0 - (time_left / 0.75), 0.0, 1.0)
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
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
	if _shot == 8:
		_typing_index = _story[_shot].length()
	_title_label.text = _titles[_shot]
	_title_label.visible = (_shot != 8 and _shot != 9)
	_story_label.visible = (_shot != 8)
	_hint_label.visible = true
	_progress_label.visible = true
	_play_shot_audio()
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_hint_label.visible = false
	_progress_label.visible = false
	_story_label.visible = false
	_title_label.visible = false
	_fade_value = 1.0
	queue_redraw()
	for p in [_shot_player, _music]:
		if is_instance_valid(p):
			create_tween().tween_property(p, "volume_db", -60.0, 0.6)
	await get_tree().create_timer(0.7, true, false, true).timeout
	GameManager.load_level(NEXT_LEVEL_INDEX)


# ==============================================================================
# RECURSOS E INTERFACE
# ==============================================================================

func _make_gradient(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _make_textures() -> void:
	# Brilho radial suave: usado em luas, chamas, janelas, névoa e olhos.
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = _make_gradient(
		[0.0, 0.2, 0.55, 1.0],
		[Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256

	# Vinheta: bordas escuras.
	_vignette_tex = GradientTexture2D.new()
	_vignette_tex.gradient = _make_gradient(
		[0.0, 0.5, 1.0],
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.92)])
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.5)
	_vignette_tex.fill_to = Vector2(1.0, 0.5)
	_vignette_tex.width = 256
	_vignette_tex.height = 256


func _make_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.05, 0.03, 0.09, 0.9)
	_card_style.set_border_width_all(3)
	_card_style.border_color = Color(0.55, 0.30, 0.75, 0.9)
	_card_style.set_corner_radius_all(20)
	_card_style.shadow_color = Color(0, 0, 0, 0.6)
	_card_style.shadow_size = 22

	_key_style = StyleBoxFlat.new()
	_key_style.bg_color = Color(0.13, 0.10, 0.19, 1.0)
	_key_style.set_border_width_all(3)
	_key_style.border_color = Color(0.60, 0.50, 0.80, 1.0)
	_key_style.set_corner_radius_all(10)
	_key_style.border_width_bottom = 8

	_key_hi_style = _key_style.duplicate() as StyleBoxFlat
	_key_hi_style.bg_color = Color(0.45, 0.12, 0.22, 1.0)
	_key_hi_style.border_color = Color(1.0, 0.45, 0.50, 1.0)


func _start_music() -> void:
	if not play_music or not ResourceLoader.exists(MUSIC_PATH):
		return
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC_PATH)
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -8.0, 3.0)


func _style_label(label: Label, color: Color, outline: Color) -> void:
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))


func _build_ui() -> void:
	_story_label = Label.new()
	_story_label.anchor_left = 0.08
	_story_label.anchor_right = 0.92
	_story_label.anchor_top = 0.62
	_story_label.anchor_bottom = 0.88
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_story_label, Color(0.97, 0.95, 0.99), Color(0.04, 0.02, 0.07, 0.95))
	add_child(_story_label)

	_title_label = Label.new()
	_title_label.anchor_left = 0.05
	_title_label.anchor_right = 0.95
	_title_label.anchor_top = 0.10
	_title_label.anchor_bottom = 0.20
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_title_label, Color(0.90, 0.72, 1.0), Color(0.12, 0.03, 0.18, 1.0))
	add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.anchor_left = 0.80
	_progress_label.anchor_right = 0.96
	_progress_label.anchor_top = 0.925
	_progress_label.anchor_bottom = 0.975
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_progress_label, Color(0.72, 0.66, 0.82, 0.85), Color(0, 0, 0, 0.8))
	add_child(_progress_label)

	_hint_label = Label.new()
	_hint_label.anchor_left = 0.04
	_hint_label.anchor_right = 0.70
	_hint_label.anchor_top = 0.925
	_hint_label.anchor_bottom = 0.975
	_style_label(_hint_label, Color(0.72, 0.66, 0.82, 0.85), Color(0, 0, 0, 0.8))
	_hint_label.text = "ENTER / ESPAÇO / CLIQUE — Continuar   |   ESC — Pular"
	add_child(_hint_label)

	_apply_ui_scale()


func _apply_ui_scale() -> void:
	var k: float = maxf(get_viewport_rect().size.y / DESIGN_H, 0.7)
	_story_label.add_theme_font_size_override("font_size", int(46.0 * k))
	_story_label.add_theme_constant_override("outline_size", int(10.0 * k))
	_story_label.add_theme_constant_override("shadow_offset_x", int(3.0 * k))
	_story_label.add_theme_constant_override("shadow_offset_y", int(3.0 * k))
	_title_label.add_theme_font_size_override("font_size", int(64.0 * k))
	_title_label.add_theme_constant_override("outline_size", int(12.0 * k))
	_title_label.add_theme_constant_override("shadow_offset_x", int(4.0 * k))
	_title_label.add_theme_constant_override("shadow_offset_y", int(4.0 * k))
	for label in [_hint_label, _progress_label]:
		label.add_theme_font_size_override("font_size", int(24.0 * k))
		label.add_theme_constant_override("outline_size", int(5.0 * k))


# ==============================================================================
# RENDERIZAÇÃO PRINCIPAL
# ==============================================================================

func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Pseudo-aleatório determinístico (0..1) para posicionar estrelas, árvores, etc.
func _h(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 78.233) * 43758.5453, 1.0)


## Pulso de relâmpago com clarão duplo. period: segundos entre raios.
func _flash(period: float, offset: float) -> float:
	var ph: float = fposmod(_total + offset, period)
	if ph < 0.10:
		return 1.0 - ph * 4.0
	if ph > 0.16 and ph < 0.32:
		return 0.7 * (1.0 - (ph - 0.16) / 0.16)
	return 0.0


func _lightning_for_shot() -> float:
	match _shot:
		2: return _flash(7.0, 2.0) * 0.6
		3: return _flash(6.5, 1.8)
		6: return _flash(5.0, 1.0)
		9: return _flash(3.4, 0.6)
	return 0.0


func _camera_shake() -> Vector2:
	var amp: float = 0.0
	match _shot:
		4:
			amp = 14.0 * maxf(0.0, 1.0 - absf(_elapsed - 1.8) * 3.0) + 3.0 * _smooth((_elapsed - 1.6) / 3.0)
		7:
			amp = 2.5 * clampf((_elapsed - 2.2) / 1.0, 0.0, 1.0)
		9:
			amp = 7.0 * _flash_now
	return Vector2(sin(_total * 71.0), cos(_total * 63.0)) * amp


func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_scale = screen.y / DESIGN_H
	_vw = screen.x / _scale
	_flash_now = _lightning_for_shot()

	var p: float = clampf(_elapsed / SHOT_DURATION[_shot], 0.0, 1.0)
	var e: float = _smooth(p)
	var zoom: float = lerpf(ZOOM_FROM[_shot], ZOOM_TO[_shot], e)
	var pan: Vector2 = PAN_TO[_shot] * e
	var s: float = _scale * zoom
	var origin: Vector2 = screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + (pan + _camera_shake()) * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	match _shot:
		0: _scene_prologue()
		1: _scene_graves()
		2: _scene_village()
		3: _scene_castle()
		4: _scene_crypt()
		5: _scene_throne()
		6: _scene_hunter()
		7: _scene_wolf_eye()
		8: _scene_controls()
		9: _scene_final()

	# --- Pós-processamento em coordenadas de tela ---
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var screen_rect := Rect2(Vector2.ZERO, screen)

	if _flash_now > 0.0:
		var tint: Color = Color(1.0, 0.18, 0.22) if _shot == 9 else Color(0.75, 0.82, 1.0)
		draw_rect(screen_rect, Color(tint.r, tint.g, tint.b, 0.30 * _flash_now))

	draw_texture_rect(_vignette_tex, screen_rect, false, Color(1, 1, 1, 0.95))

	for i in 50:
		draw_rect(Rect2(randf() * screen.x, randf() * screen.y, 2.0, 2.0), Color(1, 1, 1, 0.035))

	if _shot != 8:
		var top_y: float = screen.y * 0.52
		draw_polygon(
			PackedVector2Array([Vector2(0, top_y), Vector2(screen.x, top_y), Vector2(screen.x, screen.y), Vector2(0, screen.y)]),
			PackedColorArray([Color(0.01, 0.005, 0.02, 0.0), Color(0.01, 0.005, 0.02, 0.0), Color(0.01, 0.005, 0.02, 0.9), Color(0.01, 0.005, 0.02, 0.9)]))

	var bar_h: float = screen.y * 0.085 * _smooth(_total / 1.2)
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color.BLACK)
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color.BLACK)

	if _shot != 8 and _shot != 9:
		_draw_ornament(screen)

	if _fade_value > 0.0:
		draw_rect(screen_rect, Color(0, 0, 0, _fade_value))


func _draw_ornament(screen: Vector2) -> void:
	var y: float = screen.y * 0.205
	var cx: float = screen.x * 0.5
	var half: float = screen.x * 0.12
	var col := Color(0.75, 0.55, 0.95, 0.65)
	draw_line(Vector2(cx - half, y), Vector2(cx - 14.0, y), col, 2.0, true)
	draw_line(Vector2(cx + 14.0, y), Vector2(cx + half, y), col, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 8.0), Vector2(cx + 8.0, y), Vector2(cx, y + 8.0), Vector2(cx - 8.0, y)]), col)


# ==============================================================================
# PRIMITIVAS COMPARTILHADAS
# ==============================================================================

func _vgrad(rect: Rect2, top: Color, bottom: Color) -> void:
	var r: Rect2 = rect
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _sky(top: Color, bottom: Color) -> void:
	_vgrad(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0), top, bottom)


func _glow(pos: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _glow_ellipse(pos: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, color)


func _xf(offsets: Array, base: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in offsets:
		out.append(base + (o as Vector2) * k)
	return out


func _poly(offsets: Array, base: Vector2, k: float, color: Color) -> void:
	draw_colored_polygon(_xf(offsets, base, k), color)


func _ln(a: Vector2, b: Vector2, base: Vector2, k: float, color: Color, width: float) -> void:
	draw_line(base + a * k, base + b * k, color, width * k, true)


func _stars(count: int, y_max: float, intensity: float = 1.0) -> void:
	for i in count:
		var fi: float = float(i)
		var x: float = _h(fi * 1.37) * (_vw + 200.0) - 100.0
		var y: float = _h(fi * 2.71 + 5.0) * y_max
		var tw: float = 0.45 + 0.35 * sin(_total * (1.5 + _h(fi * 0.7) * 2.5) + fi)
		var r: float = 1.2 + _h(fi * 3.3) * 1.8
		draw_circle(Vector2(x, y), r, Color(0.85, 0.88, 1.0, tw * intensity))
		if r > 2.5:
			_glow(Vector2(x, y), r * 6.0, Color(0.7, 0.8, 1.0, 0.25 * tw * intensity))


func _moon(pos: Vector2, radius: float, col: Color, glow_col: Color) -> void:
	_glow(pos, radius * 5.5, Color(glow_col.r, glow_col.g, glow_col.b, 0.20))
	_glow(pos, radius * 2.8, Color(glow_col.r, glow_col.g, glow_col.b, 0.38))
	draw_circle(pos, radius, col.darkened(0.22))
	draw_circle(pos + Vector2(-radius * 0.06, -radius * 0.05), radius * 0.93, col)
	for i in 7:
		var fi: float = float(i)
		var a: float = _h(fi * 4.3) * TAU
		var d: float = _h(fi * 1.9) * radius * 0.62
		draw_circle(pos + Vector2(cos(a), sin(a)) * d, radius * (0.07 + _h(fi * 8.1) * 0.12), Color(col.r * 0.72, col.g * 0.72, col.b * 0.78, 0.38))


## Nuvens e bancos de névoa: elipses suaves à deriva.
func _clouds(y: float, col: Color, speed: float, count: int, seed_v: float) -> void:
	var span: float = _vw + 1400.0
	for i in count:
		var fi: float = float(i)
		var w: float = 650.0 + _h(fi + seed_v) * 550.0
		var x: float = fposmod(_h(fi * 1.9 + seed_v) * span + _total * speed, span) - 700.0
		var yy: float = y + (_h(fi * 4.1 + seed_v) - 0.5) * 170.0
		_glow_ellipse(Vector2(x, yy), w * 0.5, 60.0 + _h(fi * 7.7 + seed_v) * 50.0, col)


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
		_pine(x + (_h(float(i) + sd) - 0.5) * step * 0.5, base_y, h_min + _h(float(i) * 2.3 + sd) * h_var, col)
		x += step
		i += 1


func _branch(p: Vector2, ang: float, length: float, width: float, depth: int, col: Color, sd: float) -> void:
	var a: float = ang + sin(_total * 0.6 + sd + float(depth)) * 0.025
	var q: Vector2 = p + Vector2(cos(a), sin(a)) * length
	draw_line(p, q, col, width, true)
	if depth <= 0:
		return
	var spread: float = 0.40 + _h(sd + float(depth)) * 0.35
	_branch(q, a - spread, length * (0.70 + _h(sd * 2.0 + float(depth)) * 0.10), width * 0.68, depth - 1, col, sd * 1.7 + 1.0)
	_branch(q, a + spread * 0.9, length * (0.66 + _h(sd * 3.0 + float(depth)) * 0.10), width * 0.68, depth - 1, col, sd * 2.3 + 2.0)
	if depth > 2 and _h(sd + 3.0 + float(depth)) > 0.45:
		_branch(q, a + (_h(sd + 9.0) - 0.5) * 0.4, length * 0.6, width * 0.55, depth - 2, col, sd * 3.1 + 5.0)


func _dead_tree(base: Vector2, h: float, col: Color, sd: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-h * 0.05, 0.0), base + Vector2(-h * 0.025, -h * 0.35),
		base + Vector2(h * 0.025, -h * 0.35), base + Vector2(h * 0.055, 0.0)]), col)
	_branch(base + Vector2(0.0, -h * 0.33), -PI * 0.5, h * 0.24, h * 0.032, 6, col, sd)


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
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-5.0 * s, -3.0 * s), pos + Vector2(-4.0 * s, -12.0 * s), pos + Vector2(-1.0 * s, -4.0 * s)]), col)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(5.0 * s, -3.0 * s), pos + Vector2(4.0 * s, -12.0 * s), pos + Vector2(1.0 * s, -4.0 * s)]), col)


func _bats_across(count: int, y_min: float, y_range: float, col: Color) -> void:
	var span: float = _vw + 400.0
	for i in count:
		var fi: float = float(i)
		var bx: float = fposmod(_total * (70.0 + _h(fi) * 60.0) + fi * 311.0, span) - 200.0
		var by: float = y_min + _h(fi * 3.0) * y_range + sin(_total * 1.6 + fi) * 30.0
		_bat(Vector2(bx, by), 0.6 + _h(fi * 7.0) * 0.8, fi * 1.7, col)


func _flames(pos: Vector2, s: float, intensity: float = 1.0) -> void:
	_glow(pos + Vector2(0.0, -30.0 * s), 150.0 * s, Color(1.0, 0.45, 0.10, 0.35 * intensity))
	for i in 12:
		var fi: float = float(i)
		var age: float = fposmod(_total * 1.4 + _h(fi * 3.1), 1.0)
		var x: float = pos.x + (_h(fi * 5.3) - 0.5) * 36.0 * s * (1.0 - age) + sin(_total * 6.0 + fi) * 4.0 * s * age
		var y: float = pos.y - age * 95.0 * s
		var r: float = (16.0 - 12.0 * age) * s
		draw_circle(Vector2(x, y), r, Color(1.0, maxf(0.85 - 0.6 * age, 0.0), maxf(0.2 - 0.15 * age, 0.0), (1.0 - age) * 0.9 * intensity))


func _embers(count: int, x0: float, x1: float, y_base: float, rise: float, col: Color) -> void:
	for i in count:
		var fi: float = float(i)
		var age: float = fposmod(_total * 0.18 + _h(fi * 1.7), 1.0)
		var x: float = lerpf(x0, x1, _h(fi * 2.9)) + sin(_total * 1.5 + fi) * 30.0
		var y: float = y_base - age * rise
		var tw: float = 0.5 + 0.5 * sin(_total * 8.0 + fi)
		draw_circle(Vector2(x, y), 2.0 + _h(fi * 4.4) * 2.5, Color(col.r, col.g, col.b, col.a * (1.0 - age) * tw))


func _rain(count: int, alpha: float) -> void:
	for i in count:
		var fi: float = float(i)
		var x: float = fposmod(_h(fi * 1.3) * (_vw + 400.0) - _total * 260.0, _vw + 400.0) - 200.0
		var y: float = fposmod(_h(fi * 2.9) * 1300.0 + _total * 1500.0, 1300.0) - 100.0
		draw_line(Vector2(x, y), Vector2(x - 14.0, y + 46.0), Color(0.7, 0.78, 1.0, alpha * (0.4 + _h(fi * 5.1) * 0.6)), 2.0)


func _bolt(x: float, y0: float, y1: float, sd: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var t: float = float(i) / 9.0
		pts.append(Vector2(x + (_h(sd + float(i)) - 0.5) * 100.0 * sin(t * PI), lerpf(y0, y1, t)))
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.30), 18.0, true)
	draw_polyline(pts, col, 4.0, true)


# ==============================================================================
# CENAS 0-3: PRÓLOGO, SEPULTURAS, VILAREJO, CASTELO
# ==============================================================================

func _scene_prologue() -> void:
	_sky(Color(0.012, 0.008, 0.035), Color(0.22, 0.09, 0.24))
	_glow_ellipse(Vector2(_vw * 0.5, 830.0), _vw * 0.75, 280.0, Color(0.55, 0.18, 0.38, 0.30))
	_stars(90, 640.0)
	_moon(Vector2(_vw * 0.74, 300.0), 115.0, Color(0.88, 0.88, 0.98), Color(0.55, 0.55, 0.90))
	_clouds(310.0, Color(0.03, 0.02, 0.06, 0.55), 14.0, 5, 1.0)
	_mountains(740.0, 200.0, Color(0.06, 0.04, 0.11), 1.7)
	var cx: float = _vw * 0.27
	_castle(Vector2(cx, _ridge(cx, 740.0, 200.0, 1.7) + 8.0), 0.2, false, false)
	_clouds(790.0, Color(0.35, 0.20, 0.45, 0.12), 10.0, 6, 3.0)
	_mountains(830.0, 140.0, Color(0.04, 0.03, 0.075), 4.2)
	_pine_row(860.0, 74.0, 230.0, 150.0, Color(0.025, 0.018, 0.045), 1.0)
	_clouds(880.0, Color(0.30, 0.22, 0.42, 0.10), 18.0, 6, 5.0)
	_pine_row(960.0, 120.0, 380.0, 200.0, Color(0.012, 0.009, 0.025), 7.0)
	_vgrad(Rect2(-400.0, 940.0, _vw + 800.0, 600.0), Color(0.012, 0.009, 0.025), Color(0.004, 0.003, 0.01))
	_bats_across(8, 160.0, 380.0, Color(0.015, 0.01, 0.03))
	_clouds(1000.0, Color(0.25, 0.20, 0.35, 0.10), 22.0, 5, 9.0)


func _tomb(x: float, y: float, s: float, col: Color, rim: Color, kind: int) -> void:
	var w: float = 76.0 * s
	var h: float = 120.0 * s
	_glow_ellipse(Vector2(x, y), w * 0.9, 16.0 * s, Color(0, 0, 0, 0.55))
	match kind:
		0:
			var pts := PackedVector2Array()
			pts.append(Vector2(x - w * 0.5, y))
			pts.append(Vector2(x - w * 0.5, y - h * 0.7))
			for i in 9:
				var a: float = PI + PI * float(i) / 8.0
				pts.append(Vector2(x + cos(a) * w * 0.5, y - h * 0.7 + sin(a) * w * 0.5))
			pts.append(Vector2(x + w * 0.5, y))
			draw_colored_polygon(pts, col)
			draw_polyline(pts.slice(1, 7), rim, 2.5 * s, true)
			draw_line(Vector2(x, y - h * 0.82), Vector2(x, y - h * 0.45), Color(rim.r, rim.g, rim.b, rim.a * 0.5), 3.0 * s)
			draw_line(Vector2(x - w * 0.18, y - h * 0.72), Vector2(x + w * 0.18, y - h * 0.72), Color(rim.r, rim.g, rim.b, rim.a * 0.5), 3.0 * s)
		1:
			draw_rect(Rect2(x - w * 0.09, y - h * 1.1, w * 0.18, h * 1.1), col)
			draw_rect(Rect2(x - w * 0.36, y - h * 0.86, w * 0.72, w * 0.17), col)
			draw_line(Vector2(x - w * 0.09, y - h * 1.1), Vector2(x - w * 0.09, y), rim, 2.0 * s)
		_:
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - w * 0.4, y), Vector2(x - w * 0.26, y - h * 0.95), Vector2(x, y - h * 1.12),
				Vector2(x + w * 0.26, y - h * 0.95), Vector2(x + w * 0.4, y)]), col)
			draw_line(Vector2(x - w * 0.26, y - h * 0.95), Vector2(x, y - h * 1.12), rim, 2.5 * s, true)


func _zombie_hand(x: float, y: float, rise: float, col: Color, rim: Color) -> void:
	if rise <= 0.0:
		return
	var h: float = 130.0 * rise
	var wrist := Vector2(x + sin(_total * 1.4 + x) * 6.0, y - h)
	_glow_ellipse(Vector2(x, y), 50.0, 14.0, Color(0, 0, 0, 0.6))
	draw_line(Vector2(x, y), wrist, col, 18.0, true)
	draw_line(Vector2(x - 8.0, y), wrist + Vector2(-8.0, 0.0), rim, 2.0, true)
	for i in 4:
		var a: float = -PI * 0.5 + (float(i) - 1.5) * 0.36 + sin(_total * 2.0 + float(i) + x) * 0.12
		draw_line(wrist, wrist + Vector2(cos(a), sin(a)) * 46.0, col, 8.0, true)


func _scene_graves() -> void:
	_sky(Color(0.01, 0.012, 0.04), Color(0.10, 0.09, 0.18))
	_stars(70, 560.0)
	_moon(Vector2(_vw * 0.24, 270.0), 100.0, Color(0.80, 0.82, 0.95), Color(0.45, 0.55, 0.95))
	_clouds(250.0, Color(0.02, 0.02, 0.05, 0.5), 9.0, 4, 8.0)
	_mountains(700.0, 120.0, Color(0.05, 0.05, 0.10), 6.3)
	_vgrad(Rect2(-400.0, 790.0, _vw + 800.0, 700.0), Color(0.035, 0.04, 0.075), Color(0.008, 0.008, 0.02))

	# Cerca de ferro ao fundo
	var iron := Color(0.03, 0.03, 0.06)
	var fy: float = 790.0
	var fx: float = -40.0
	while fx < _vw + 60.0:
		draw_line(Vector2(fx, fy), Vector2(fx, fy - 72.0), iron, 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 6.0, fy - 72.0), Vector2(fx, fy - 96.0), Vector2(fx + 6.0, fy - 72.0)]), iron)
		fx += 36.0
	draw_line(Vector2(-40.0, fy - 52.0), Vector2(_vw + 60.0, fy - 52.0), iron, 4.0)
	draw_line(Vector2(-40.0, fy - 16.0), Vector2(_vw + 60.0, fy - 16.0), iron, 4.0)

	_dead_tree(Vector2(_vw * 0.62, 800.0), 400.0, Color(0.02, 0.02, 0.045), 1.3)
	_clouds(820.0, Color(0.32, 0.36, 0.62, 0.14), 12.0, 7, 2.0)

	# Três fileiras de lápides, de longe para perto
	for row in 3:
		var y: float = [835.0, 910.0, 1030.0][row]
		var sc: float = [0.55, 0.85, 1.25][row]
		var shade: float = [0.10, 0.065, 0.035][row]
		var count: int = [12, 9, 6][row]
		for i in count:
			var fi: float = float(i) + float(row) * 20.0
			var x: float = 90.0 + (float(i) + 0.5) * ((_vw - 180.0) / float(count)) + (_h(fi) - 0.5) * 50.0
			_tomb(x, y, sc * (0.85 + _h(fi * 3.0) * 0.3), Color(shade, shade * 1.05, shade * 1.7), Color(0.55, 0.62, 0.9, 0.5 - 0.12 * float(row)), int(_h(fi * 5.0) * 3.0))
		if row < 2:
			_clouds(y + 20.0, Color(0.30, 0.34, 0.60, 0.12), 8.0 + 4.0 * float(row), 6, 4.0 + float(row))

	# Mãos de mortos-vivos emergindo
	for i in 3:
		var hx: float = _vw * (0.30 + 0.18 * float(i)) + sin(float(i) * 2.0) * 60.0
		var rise: float = _smooth((_elapsed - 1.0 - float(i) * 0.7) / 1.6)
		_zombie_hand(hx, 960.0 + float(i) * 18.0, rise, Color(0.01, 0.012, 0.025), Color(0.45, 0.55, 0.8, 0.5))

	# Árvores de moldura
	_dead_tree(Vector2(_vw * 0.93, 1060.0), 760.0, Color(0.006, 0.006, 0.014), 2.1)
	_dead_tree(Vector2(_vw * 0.03, 1060.0), 600.0, Color(0.006, 0.006, 0.014), 4.7)

	# Espíritos subindo
	for i in 9:
		var fi: float = float(i)
		var age: float = fposmod(_total * 0.12 + _h(fi * 2.1), 1.0)
		var wx: float = _vw * (0.1 + 0.8 * _h(fi * 3.7)) + sin(_total * 0.9 + fi) * 40.0
		var wy: float = 980.0 - age * 520.0
		_glow(Vector2(wx, wy), 46.0 + 20.0 * age, Color(0.45, 0.65, 1.0, 0.30 * sin(age * PI)))


func _house(x: float, base: float, w: float, h: float, roof_h: float, wall: Color, roof: Color, sd: float, lit: bool, burning: bool) -> void:
	_glow_ellipse(Vector2(x + w * 0.5, base), w * 0.8, 20.0, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(x, base - h, w, h), wall)
	var apex_x: float = x + w * 0.5 + (_h(sd) - 0.5) * 36.0
	draw_colored_polygon(PackedVector2Array([Vector2(x - 20.0, base - h), Vector2(apex_x, base - h - roof_h), Vector2(x + w + 20.0, base - h)]), roof)
	draw_rect(Rect2(x + w * 0.68, base - h - roof_h * 0.75, 24.0, roof_h * 0.55), roof)
	draw_line(Vector2(x, base - h), Vector2(x, base), Color(0.55, 0.45, 0.65, 0.30), 3.0)
	for i in 2:
		var wx: float = x + w * (0.18 + 0.46 * float(i))
		var wy: float = base - h * 0.70
		var ww: float = w * 0.20
		var wh: float = h * 0.24
		draw_rect(Rect2(wx, wy, ww, wh), Color(0.01, 0.008, 0.02))
		if lit or burning:
			var fl: float = 0.65 + 0.35 * sin(_total * 9.0 + sd * 3.0 + float(i) * 2.0)
			var c := Color(1.0, 0.30, 0.08, 0.95 * fl) if burning else Color(1.0, 0.58, 0.18, 0.90 * fl)
			draw_rect(Rect2(wx + 4.0, wy + 4.0, ww - 8.0, wh - 8.0), c)
			_glow(Vector2(wx + ww * 0.5, wy + wh * 0.5), ww * 3.0, Color(c.r, c.g * 0.8, c.b, 0.30 * fl))
		else:
			draw_line(Vector2(wx, wy), Vector2(wx + ww, wy + wh), Color(0.16, 0.12, 0.22), 3.0)
			draw_line(Vector2(wx + ww, wy), Vector2(wx + ww * 0.3, wy + wh * 0.8), Color(0.16, 0.12, 0.22), 3.0)
	draw_rect(Rect2(x + w * 0.42, base - h * 0.36, w * 0.16, h * 0.36), Color(0.015, 0.01, 0.025))
	if burning:
		_flames(Vector2(apex_x, base - h - roof_h * 0.2), 2.2, 1.0)
		_flames(Vector2(x + w * 0.22, base - h * 0.55), 1.4, 0.8)


func _church(x: float, base: float, s: float, col: Color) -> void:
	draw_rect(Rect2(x - 150.0 * s, base - 190.0 * s, 300.0 * s, 190.0 * s), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 170.0 * s, base - 190.0 * s), Vector2(x, base - 300.0 * s), Vector2(x + 170.0 * s, base - 190.0 * s)]), col)
	draw_rect(Rect2(x - 40.0 * s, base - 430.0 * s, 80.0 * s, 440.0 * s), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 54.0 * s, base - 430.0 * s), Vector2(x, base - 590.0 * s), Vector2(x + 54.0 * s, base - 430.0 * s)]), col)
	draw_line(Vector2(x, base - 590.0 * s), Vector2(x, base - 650.0 * s), col, 5.0 * s)
	draw_line(Vector2(x - 20.0 * s, base - 630.0 * s), Vector2(x + 20.0 * s, base - 630.0 * s), col, 5.0 * s)
	var fl: float = 0.7 + 0.3 * sin(_total * 3.0)
	_glow(Vector2(x, base - 360.0 * s), 70.0 * s, Color(0.9, 0.5, 0.2, 0.35 * fl))
	draw_circle(Vector2(x, base - 360.0 * s), 18.0 * s, Color(1.0, 0.6, 0.2, 0.9 * fl))


func _scene_village() -> void:
	_sky(Color(0.05, 0.012, 0.05), Color(0.34, 0.09, 0.10))
	_glow_ellipse(Vector2(_vw * 0.45, 820.0), _vw * 0.7, 340.0, Color(1.0, 0.35, 0.10, 0.28))
	_stars(40, 420.0, 0.6)
	_moon(Vector2(_vw * 0.16, 250.0), 72.0, Color(0.92, 0.58, 0.55), Color(0.9, 0.25, 0.25))
	_clouds(340.0, Color(0.25, 0.04, 0.08, 0.5), 11.0, 5, 11.0)
	_mountains(800.0, 110.0, Color(0.07, 0.03, 0.07), 2.6)
	_church(_vw * 0.84, 800.0, 1.25, Color(0.04, 0.02, 0.05))
	_vgrad(Rect2(-400.0, 790.0, _vw + 800.0, 700.0), Color(0.12, 0.06, 0.07), Color(0.02, 0.01, 0.02))

	var xs: Array[float] = [0.05, 0.25, 0.46, 0.66]
	var ws: Array[float] = [300.0, 340.0, 360.0, 300.0]
	var hs: Array[float] = [190.0, 230.0, 250.0, 200.0]
	for i in 4:
		var wall := Color(0.055, 0.03, 0.065)
		var roof := Color(0.03, 0.015, 0.04)
		_house(_vw * xs[i], 840.0, ws[i], hs[i], 120.0 + 20.0 * float(i % 2), wall, roof, float(i) * 3.7, i == 1, i == 2)

	# Fumaça do incêndio
	var fire_x: float = _vw * 0.46 + 180.0
	for i in 9:
		var fi: float = float(i)
		var age: float = fposmod(_total * 0.16 + fi * 0.11, 1.0)
		_glow(Vector2(fire_x + age * 150.0 + sin(_total + fi) * 30.0, 520.0 - age * 460.0), 70.0 + age * 140.0, Color(0.04, 0.02, 0.03, 0.55 * (1.0 - age)))

	# Rua: poças de sangue e reflexo do fogo
	_glow_ellipse(Vector2(fire_x, 960.0), 520.0, 70.0, Color(1.0, 0.40, 0.12, 0.26))
	for i in 6:
		var fi: float = float(i)
		_glow_ellipse(Vector2(_vw * (0.12 + 0.15 * fi), 930.0 + _h(fi * 5.0) * 120.0), 60.0 + _h(fi) * 80.0, 16.0 + _h(fi * 2.0) * 10.0, Color(0.35, 0.02, 0.04, 0.75))

	# Cerca quebrada
	var fx: float = 0.0
	var k: int = 0
	while fx < _vw:
		if _h(float(k) * 1.9) > 0.22:
			var lean: float = (_h(float(k) * 3.1) - 0.5) * 0.5
			var top := Vector2(fx + lean * 90.0, 1005.0 - 90.0 - _h(float(k)) * 40.0)
			draw_line(Vector2(fx, 1005.0), top, Color(0.02, 0.01, 0.025), 14.0, true)
		fx += 74.0
		k += 1
	draw_line(Vector2(0.0, 960.0), Vector2(_vw * 0.55, 945.0), Color(0.02, 0.01, 0.025), 8.0, true)

	# Poste com lampião balançando
	var lx: float = _vw * 0.92
	var sway: float = sin(_total * 1.7) * 14.0
	draw_line(Vector2(lx, 1040.0), Vector2(lx, 600.0), Color(0.015, 0.01, 0.02), 10.0)
	draw_line(Vector2(lx, 610.0), Vector2(lx - 80.0, 610.0), Color(0.015, 0.01, 0.02), 8.0)
	draw_line(Vector2(lx - 80.0, 610.0), Vector2(lx - 80.0 + sway, 670.0), Color(0.015, 0.01, 0.02), 3.0)
	_glow(Vector2(lx - 80.0 + sway, 685.0), 130.0, Color(1.0, 0.6, 0.2, 0.40))
	draw_rect(Rect2(lx - 92.0 + sway, 668.0, 24.0, 34.0), Color(1.0, 0.75, 0.3, 0.95))

	_embers(46, _vw * 0.30, _vw * 0.75, 700.0, 620.0, Color(1.0, 0.55, 0.15, 1.0))
	_clouds(960.0, Color(0.50, 0.20, 0.20, 0.10), 14.0, 5, 6.0)


func _scene_castle() -> void:
	_sky(Color(0.03, 0.02, 0.09), Color(0.16, 0.08, 0.22))
	_stars(80, 560.0)
	var moon := Vector2(_vw * 0.5, 360.0)
	_moon(moon, 165.0, Color(0.92, 0.90, 1.0), Color(0.60, 0.50, 1.0))
	_clouds(330.0, Color(0.03, 0.02, 0.07, 0.6), 16.0, 5, 3.0)
	_mountains(820.0, 160.0, Color(0.04, 0.03, 0.08), 3.3)
	_castle(Vector2(_vw * 0.5, 880.0), 1.0, false, true)
	# Morcegos orbitando a torre
	for i in 11:
		var fi: float = float(i)
		var a: float = _total * (0.5 + _h(fi) * 0.4) + fi * 0.9
		var c := Vector2(_vw * 0.5, 330.0)
		_bat(c + Vector2(cos(a) * (360.0 + _h(fi * 2.0) * 220.0), sin(a) * (110.0 + _h(fi * 4.0) * 80.0)), 0.55 + _h(fi * 5.0) * 0.6, fi, Color(0.01, 0.005, 0.02))
	_clouds(930.0, Color(0.45, 0.38, 0.65, 0.14), 14.0, 7, 12.0)
	_dead_tree(Vector2(_vw * 0.06, 1100.0), 700.0, Color(0.005, 0.004, 0.012), 6.1)
	_dead_tree(Vector2(_vw * 0.95, 1100.0), 620.0, Color(0.005, 0.004, 0.012), 8.4)
	if _flash_now > 0.4:
		_bolt(_vw * (0.12 + 0.76 * _h(floorf((_total + 1.8) / 6.5))), -50.0, 700.0, floorf((_total + 1.8) / 6.5), Color(0.85, 0.88, 1.0))


# ==============================================================================
# O CASTELO (reutilizado nos planos 0, 3 e 9)
# ==============================================================================

func _lit_window(pos: Vector2, w: float, h: float, lamp: Color, sd: float, s: float) -> void:
	var fl: float = 0.75 + 0.25 * sin(_total * 7.0 + sd * 5.0)
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h, w, h), Color(0.02, 0.012, 0.03))
	draw_rect(Rect2(pos.x - w * 0.5 + 2.0 * s, pos.y - h + 2.0 * s, w - 4.0 * s, h - 4.0 * s), Color(lamp.r, lamp.g, lamp.b, 0.95 * fl))
	_glow(pos + Vector2(0.0, -h * 0.5), maxf(w * 3.0, 14.0), Color(lamp.r, lamp.g, lamp.b, 0.30 * fl))


func _tower(x: float, by: float, w: float, top_h: float, apex_h: float, s: float, wall: Color, roof: Color, rim: Color, lamp: Color, sd: float) -> void:
	draw_rect(Rect2(x - w * 0.5, by - top_h * s, w, top_h * s + 24.0 * s), wall)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - w * 0.5 - 14.0 * s, by - top_h * s), Vector2(x, by - apex_h * s), Vector2(x + w * 0.5 + 14.0 * s, by - top_h * s)]), roof)
	draw_line(Vector2(x - w * 0.5, by - top_h * s), Vector2(x - w * 0.5, by), rim, 3.0 * s, true)
	draw_line(Vector2(x - w * 0.5 - 14.0 * s, by - top_h * s), Vector2(x, by - apex_h * s), rim, 2.5 * s, true)
	_lit_window(Vector2(x, by - top_h * s * 0.62), 16.0 * s, 38.0 * s, lamp, sd, s)
	_lit_window(Vector2(x, by - top_h * s * 0.30), 14.0 * s, 32.0 * s, lamp, sd + 1.0, s)


func _castle(base: Vector2, s: float, awake: bool, cliff: bool) -> void:
	var cx: float = base.x
	var by: float = base.y
	var wall := Color(0.05, 0.038, 0.08)
	var roof := Color(0.028, 0.02, 0.05)
	var rim := Color(1.0, 0.25, 0.30, 0.65) if awake else Color(0.60, 0.55, 0.88, 0.55)
	var lamp := Color(1.0, 0.14, 0.16) if awake else Color(1.0, 0.66, 0.28)
	var lamp2 := Color(1.0, 0.30, 0.20) if awake else Color(0.65, 0.35, 0.95)

	if cliff:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 760.0 * s, 1500.0), Vector2(cx - 690.0 * s, by + 150.0 * s), Vector2(cx - 540.0 * s, by + 70.0 * s),
			Vector2(cx - 400.0 * s, by + 18.0 * s), Vector2(cx + 400.0 * s, by + 18.0 * s), Vector2(cx + 560.0 * s, by + 80.0 * s),
			Vector2(cx + 700.0 * s, by + 160.0 * s), Vector2(cx + 760.0 * s, 1500.0)]), Color(0.025, 0.02, 0.045))

	# Muralha com ameias
	draw_rect(Rect2(cx - 400.0 * s, by - 170.0 * s, 800.0 * s, 190.0 * s), wall)
	for i in 22:
		draw_rect(Rect2(cx - 400.0 * s + float(i) * 38.0 * s, by - 196.0 * s, 22.0 * s, 28.0 * s), wall)
	draw_line(Vector2(cx - 400.0 * s, by - 170.0 * s), Vector2(cx + 400.0 * s, by - 170.0 * s), Color(rim.r, rim.g, rim.b, 0.25), 2.0 * s)

	# Torres: [deslocamento_x, largura, altura_corpo, altura_ponta]
	var towers: Array = [[-340.0, 110.0, 330.0, 470.0], [340.0, 110.0, 330.0, 470.0], [-175.0, 92.0, 420.0, 570.0], [175.0, 92.0, 420.0, 570.0]]
	var idx: float = 0.0
	for t in towers:
		var tx: float = t[0]
		var tw: float = t[1]
		var th: float = t[2]
		var ta: float = t[3]
		_tower(cx + tx * s, by, tw * s, th, ta, s, wall, roof, rim, lamp if int(idx) % 2 == 0 else lamp2, idx)
		idx += 1.0

	# Torre central (keep) com agulha e bandeira
	draw_rect(Rect2(cx - 105.0 * s, by - 470.0 * s, 210.0 * s, 490.0 * s), wall.lightened(0.04))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 125.0 * s, by - 470.0 * s), Vector2(cx, by - 700.0 * s), Vector2(cx + 125.0 * s, by - 470.0 * s)]), roof)
	draw_line(Vector2(cx - 105.0 * s, by - 470.0 * s), Vector2(cx - 105.0 * s, by), rim, 3.0 * s, true)
	draw_line(Vector2(cx - 125.0 * s, by - 470.0 * s), Vector2(cx, by - 700.0 * s), rim, 2.5 * s, true)
	draw_line(Vector2(cx, by - 700.0 * s), Vector2(cx, by - 775.0 * s), roof, 4.0 * s)
	var wave: float = sin(_total * 3.0) * 6.0 * s
	draw_colored_polygon(PackedVector2Array([Vector2(cx, by - 775.0 * s), Vector2(cx + 38.0 * s, by - 762.0 * s + wave), Vector2(cx, by - 750.0 * s)]), Color(0.5, 0.05, 0.1))

	# Janela-rosácea
	var rc := Vector2(cx, by - 360.0 * s)
	_glow(rc, 120.0 * s, Color(lamp2.r, lamp2.g, lamp2.b, 0.35))
	draw_circle(rc, 44.0 * s, Color(0.02, 0.012, 0.03))
	draw_circle(rc, 38.0 * s, Color(lamp2.r, lamp2.g, lamp2.b, 0.95))
	for i in 8:
		var a: float = float(i) * TAU / 8.0
		draw_line(rc, rc + Vector2(cos(a), sin(a)) * 38.0 * s, Color(0.02, 0.012, 0.03), 3.0 * s)
	draw_arc(rc, 20.0 * s, 0.0, TAU, 20, Color(0.02, 0.012, 0.03), 3.0 * s)

	# Janelas da muralha
	for i in 8:
		if absf(float(i) - 3.5) < 1.0:
			continue
		_lit_window(Vector2(cx - 300.0 * s + float(i) * 86.0 * s, by - 60.0 * s), 16.0 * s, 44.0 * s, lamp if i % 2 == 0 else lamp2, float(i) * 2.0, s)

	# Portão
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 52.0 * s, by + 20.0 * s), Vector2(cx - 52.0 * s, by - 60.0 * s), Vector2(cx - 30.0 * s, by - 100.0 * s),
		Vector2(cx + 30.0 * s, by - 100.0 * s), Vector2(cx + 52.0 * s, by - 60.0 * s), Vector2(cx + 52.0 * s, by + 20.0 * s)]), Color(0.01, 0.006, 0.015))
	_glow_ellipse(Vector2(cx, by + 10.0 * s), 70.0 * s, 16.0 * s, Color(lamp.r, lamp.g, lamp.b, 0.35))


# ==============================================================================
# CENAS 4-7: CRIPTA, TRONO, CAÇADOR, OLHO DO LOBO
# ==============================================================================

func _slab(origin: Vector2, w: float, h: float, ang: float, col: Color) -> void:
	var t := Transform2D(ang, Vector2.ONE, 0.0, origin)
	draw_colored_polygon(PackedVector2Array([t * Vector2(0, 0), t * Vector2(w, 0), t * Vector2(w, h), t * Vector2(0, h)]), col)
	draw_line(t * Vector2(0, 0), t * Vector2(w, 0), Color(0.9, 0.3, 0.4, 0.35), 3.0, true)


func _scene_crypt() -> void:
	var floor_y: float = 900.0
	_vgrad(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0), Color(0.012, 0.008, 0.02), Color(0.045, 0.025, 0.05))

	# Pilares e arcos góticos
	var cols: int = 6
	var gap: float = (_vw + 200.0) / float(cols)
	for i in cols + 1:
		var px: float = -100.0 + float(i) * gap
		_vgrad(Rect2(px - 55.0, -300.0, 110.0, floor_y + 300.0), Color(0.03, 0.022, 0.04), Color(0.075, 0.05, 0.08))
		draw_line(Vector2(px - 55.0, 0.0), Vector2(px - 55.0, floor_y), Color(0.45, 0.25, 0.35, 0.25), 3.0)
		if i < cols:
			draw_arc(Vector2(px + gap * 0.5, 120.0), gap * 0.5 - 55.0, PI, TAU, 28, Color(0.025, 0.018, 0.035), 46.0)

	# Chão com perspectiva
	_vgrad(Rect2(-400.0, floor_y, _vw + 800.0, 500.0), Color(0.06, 0.04, 0.07), Color(0.015, 0.01, 0.02))
	for i in 7:
		var ly: float = floor_y + pow(float(i) / 6.0, 1.7) * 220.0 + 10.0
		draw_line(Vector2(-200.0, ly), Vector2(_vw + 200.0, ly), Color(0.0, 0.0, 0.0, 0.5), 3.0)

	# Tochas
	for tx in [_vw * 0.07, _vw * 0.93]:
		draw_rect(Rect2(tx - 8.0, 400.0, 16.0, 80.0), Color(0.08, 0.07, 0.08))
		draw_rect(Rect2(tx - 24.0, 392.0, 48.0, 14.0), Color(0.10, 0.08, 0.09))
		_flames(Vector2(tx, 392.0), 1.5, 1.0)

	# Sarcófago
	var cw: float = _vw * 0.50
	var cx0: float = _vw * 0.24
	var top: float = floor_y - 240.0
	var open: float = _smooth((_elapsed - 0.3) / 1.5)
	var rise: float = _smooth((_elapsed - 1.7) / 3.0)
	var eyes: float = _smooth((_elapsed - 4.4) / 0.6)

	# Luz profana saindo da tumba
	var pulse: float = 0.8 + 0.2 * sin(_total * 4.0)
	var gx: float = cx0 + cw * 0.22
	for i in 5:
		var fi: float = float(i)
		var spread: float = 60.0 + fi * 55.0
		var lean: float = (fi - 2.0) * 90.0
		var a: float = 0.20 * open * pulse * (1.0 - fi * 0.12)
		draw_polygon(
			PackedVector2Array([Vector2(gx - 40.0, top), Vector2(gx + 40.0, top), Vector2(gx + lean + spread, -100.0), Vector2(gx + lean - spread, -100.0)]),
			PackedColorArray([Color(1.0, 0.1, 0.2, a), Color(1.0, 0.1, 0.2, a), Color(1.0, 0.1, 0.2, 0.0), Color(1.0, 0.1, 0.2, 0.0)]))
	_glow_ellipse(Vector2(gx, top), 420.0, 160.0, Color(1.0, 0.05, 0.15, 0.55 * open * pulse))

	# Drácula (perfil) erguendo-se por trás do sarcófago
	if open > 0.4:
		var base := Vector2(gx + 20.0, top + 90.0 + (1.0 - rise) * 330.0 + sin(_total * 2.0) * 4.0)
		_dracula_profile(base, 2.0, eyes)

	# Corpo do sarcófago (cobre a parte de baixo de Drácula)
	var stone := Color(0.085, 0.07, 0.10)
	var dark := Color(0.045, 0.035, 0.055)
	draw_rect(Rect2(cx0, top, cw, 240.0), stone)
	draw_rect(Rect2(cx0 - 14.0, top - 8.0, cw + 28.0, 22.0), dark)
	draw_rect(Rect2(cx0 - 14.0, floor_y - 26.0, cw + 28.0, 26.0), dark)
	draw_line(Vector2(cx0 - 14.0, top - 8.0), Vector2(cx0 + cw + 14.0, top - 8.0), Color(1.0, 0.25, 0.35, 0.35 * open), 3.0)
	for i in 4:
		var dx: float = cx0 + 50.0 + float(i) * (cw - 170.0) / 3.0
		draw_rect(Rect2(dx, top + 50.0, 70.0, 130.0), dark)
		draw_circle(Vector2(dx + 35.0, top + 50.0), 35.0, dark)
		draw_line(Vector2(dx + 35.0, top + 80.0), Vector2(dx + 35.0, top + 150.0), Color(0.6, 0.5, 0.7, 0.25), 3.0)
		draw_line(Vector2(dx + 12.0, top + 105.0), Vector2(dx + 58.0, top + 105.0), Color(0.6, 0.5, 0.7, 0.25), 3.0)

	# Tampa deslizando e tombando
	var lid_o := Vector2(lerpf(cx0 - 10.0, cx0 + cw * 0.36, open), top - 24.0 + open * open * 14.0)
	_slab(lid_o, cw * 0.78, 36.0, open * open * 0.13, Color(0.07, 0.055, 0.085))

	# Névoa vermelha e poeira na luz
	_clouds(floor_y - 20.0, Color(0.8, 0.1, 0.2, 0.14 * open), 20.0, 6, 3.0)
	_embers(34, gx - 220.0, gx + 220.0, top, 620.0, Color(1.0, 0.55, 0.55, 0.9 * open))


func _dracula_profile(base: Vector2, k: float, eyes: float) -> void:
	var sil := Color(0.004, 0.004, 0.009)
	var rim := Color(1.0, 0.22, 0.32, 0.9)
	_poly([Vector2(-30, 50), Vector2(60, 30), Vector2(80, -80), Vector2(-10, -80)], base, k, sil)
	_ln(Vector2(40, -60), Vector2(110, -20), base, k, sil, 20.0)
	_ln(Vector2(110, -20), Vector2(142, -22), base, k, sil, 16.0)
	for i in 3:
		_ln(Vector2(142.0 + float(i) * 6.0, -22), Vector2(134.0 + float(i) * 8.0, 2.0), base, k, sil, 4.0)
	_poly([Vector2(-5, -70), Vector2(-40, -160), Vector2(20, -140), Vector2(40, -80)], base, k, sil)
	draw_circle(base + Vector2(45, -110) * k, 22.0 * k, sil)
	_poly([Vector2(40, -95), Vector2(70, -100), Vector2(65, -120)], base, k, sil)
	_poly([Vector2(60, -130), Vector2(80, -115), Vector2(60, -105)], base, k, sil)
	_poly([Vector2(45, -130), Vector2(-10, -110), Vector2(-20, -70), Vector2(20, -100)], base, k, sil)
	draw_polyline(_xf([Vector2(70, -100), Vector2(80, -115), Vector2(60, -130), Vector2(45, -132)], base, k), rim, 2.5 * k, true)
	draw_polyline(_xf([Vector2(110, -15), Vector2(142, -24), Vector2(154, -24)], base, k), rim, 2.5 * k, true)
	_ln(Vector2(20, -140), Vector2(-40, -160), base, k, Color(0.6, 0.05, 0.15, 0.8), 2.0)
	if eyes > 0.0:
		var ep: Vector2 = base + Vector2(62, -118) * k
		_glow(ep, 60.0 * k * eyes, Color(1.0, 0.0, 0.1, 0.6 * eyes))
		draw_circle(ep, 4.0 * k, Color(1.0, 0.1, 0.15, eyes))
		draw_line(ep + Vector2(-3.0, 0.0) * k, ep + Vector2(9.0, 3.0) * k, Color(1.0, 0.3, 0.3, eyes), 2.5 * k, true)


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


func _scene_throne() -> void:
	var cx: float = _vw * 0.5
	var floor_y: float = 900.0
	var hw: float = 300.0
	var spring: float = 430.0
	var arch: PackedVector2Array = _ogive(cx, spring, hw, hw * 1.2)

	# Céu e Lua de sangue dentro da janela
	_vgrad(Rect2(cx - hw - 20.0, -100.0, hw * 2.0 + 40.0, floor_y + 100.0), Color(0.10, 0.01, 0.03), Color(0.40, 0.05, 0.08))
	var moon := Vector2(cx, 470.0)
	_moon(moon, 190.0, Color(0.95, 0.16, 0.18), Color(1.0, 0.1, 0.12))
	_clouds(450.0, Color(0.10, 0.0, 0.02, 0.6), 18.0, 4, 2.0)
	for i in 6:
		var fi: float = float(i)
		var bx: float = cx - 220.0 + fposmod(_total * 40.0 + fi * 80.0, 440.0)
		_bat(Vector2(bx, 380.0 + sin(_total * 2.0 + fi) * 50.0 + fi * 25.0), 0.7, fi, Color(0.015, 0.0, 0.01))

	# Paredes de pedra ao redor (polígono com a janela recortada)
	var wall := PackedVector2Array([Vector2(-500.0, 1500.0), Vector2(-500.0, -400.0), Vector2(_vw + 500.0, -400.0), Vector2(_vw + 500.0, 1500.0), Vector2(cx + hw, 1500.0)])
	for i in range(arch.size() - 1, -1, -1):
		wall.append(arch[i])
	wall.append(Vector2(cx - hw, 1500.0))
	draw_colored_polygon(wall, Color(0.012, 0.006, 0.014))
	draw_polyline(arch, Color(1.0, 0.25, 0.30, 0.55), 4.0, true)

	# Tracejado da janela
	var tr := Color(0.012, 0.006, 0.014)
	for mx in [-0.5, 0.0, 0.5]:
		draw_line(Vector2(cx + mx * hw, spring - 130.0), Vector2(cx + mx * hw, floor_y), tr, 12.0)
	draw_line(Vector2(cx - hw, 640.0), Vector2(cx + hw, 640.0), tr, 12.0)
	draw_line(Vector2(cx - hw, 800.0), Vector2(cx + hw, 800.0), tr, 10.0)
	draw_arc(Vector2(cx, 260.0), 70.0, 0.0, TAU, 28, tr, 10.0)
	for i in 6:
		var a: float = float(i) * TAU / 6.0
		draw_line(Vector2(cx, 260.0), Vector2(cx, 260.0) + Vector2(cos(a), sin(a)) * 70.0, tr, 7.0)

	# Raios de luz sobre o salão
	for i in 4:
		var fi: float = float(i)
		var x0: float = cx - hw * 0.75 + fi * hw * 0.5
		draw_polygon(
			PackedVector2Array([Vector2(x0 - 30.0, 640.0), Vector2(x0 + 30.0, 640.0), Vector2(x0 + 260.0 + fi * 60.0, floor_y + 160.0), Vector2(x0 - 140.0 + fi * 60.0, floor_y + 160.0)]),
			PackedColorArray([Color(1.0, 0.1, 0.15, 0.10), Color(1.0, 0.1, 0.15, 0.10), Color(1.0, 0.1, 0.15, 0.0), Color(1.0, 0.1, 0.15, 0.0)]))

	# Chão e tapete
	_vgrad(Rect2(-400.0, floor_y, _vw + 800.0, 500.0), Color(0.035, 0.012, 0.02), Color(0.008, 0.003, 0.006))
	_glow_ellipse(Vector2(cx, floor_y + 40.0), 520.0, 60.0, Color(1.0, 0.1, 0.15, 0.30))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 170.0, floor_y), Vector2(cx + 170.0, floor_y), Vector2(cx + 420.0, 1200.0), Vector2(cx - 420.0, 1200.0)]), Color(0.30, 0.02, 0.05))
	draw_line(Vector2(cx - 170.0, floor_y), Vector2(cx - 420.0, 1200.0), Color(0.75, 0.50, 0.15, 0.55), 7.0)
	draw_line(Vector2(cx + 170.0, floor_y), Vector2(cx + 420.0, 1200.0), Color(0.75, 0.50, 0.15, 0.55), 7.0)

	# Candelabros
	for sx in [cx - 520.0, cx + 520.0]:
		draw_line(Vector2(sx, floor_y + 20.0), Vector2(sx, floor_y - 240.0), Color(0.03, 0.02, 0.03), 10.0)
		for j in 3:
			var fx: float = sx + (float(j) - 1.0) * 34.0
			draw_line(Vector2(sx, floor_y - 200.0), Vector2(fx, floor_y - 250.0), Color(0.03, 0.02, 0.03), 5.0)
			_flames(Vector2(fx, floor_y - 250.0), 0.8, 0.9)

	# Drácula levitando
	var cs: float = 20.0 + sin(_total * 1.5) * 10.0
	var base := Vector2(cx, 600.0 + sin(_total * 2.5) * 14.0)
	var k: float = 1.7
	var sil := Color(0.0, 0.0, 0.0)
	var rim := Color(1.0, 0.35, 0.35, 0.9)
	_poly([Vector2(0, 160), Vector2(-60, 130), Vector2(-120, 160), Vector2(-160 - cs, 30), Vector2(-220 - cs, -50), Vector2(-150, -130),
		Vector2(-40, -70), Vector2(40, -70), Vector2(150, -130), Vector2(220 + cs, -50), Vector2(160 + cs, 30), Vector2(120, 160), Vector2(60, 130)], base, k, sil)
	_poly([Vector2(-30, -60), Vector2(30, -60), Vector2(15, 20), Vector2(-15, 20)], base, k, sil)
	_poly([Vector2(-15, 20), Vector2(15, 20), Vector2(8, 140), Vector2(-8, 140)], base, k, sil)
	_ln(Vector2(-30, -50), Vector2(-100, -20), base, k, sil, 14.0)
	_ln(Vector2(30, -50), Vector2(100, -20), base, k, sil, 14.0)
	_poly([Vector2(0, -60), Vector2(-40, -120), Vector2(40, -120)], base, k, sil)
	draw_circle(base + Vector2(0, -100) * k, 16.0 * k, sil)
	_poly([Vector2(-15, -110), Vector2(15, -110), Vector2(25 + cs * 0.5, -60), Vector2(-25 - cs * 0.5, -60)], base, k, sil)
	draw_polyline(_xf([Vector2(-220 - cs, -50), Vector2(-150, -130), Vector2(-40, -70)], base, k), rim, 3.0, true)
	draw_polyline(_xf([Vector2(40, -70), Vector2(150, -130), Vector2(220 + cs, -50)], base, k), rim, 3.0, true)
	draw_polyline(_xf([Vector2(-12, -110), Vector2(0, -116), Vector2(12, -110)], base, k), rim, 2.5, true)
	for side in [-1.0, 1.0]:
		var ep: Vector2 = base + Vector2(side * 6.0, -102.0) * k
		_glow(ep, 24.0, Color(1.0, 0.0, 0.1, 0.8))
		draw_circle(ep, 3.0, Color(1.0, 0.4, 0.4))
		var hand: Vector2 = base + Vector2(side * 110.0, -15.0) * k
		var mp: float = 0.5 + 0.5 * sin(_total * 10.0)
		_glow(hand, 80.0 + mp * 20.0, Color(1.0, 0.05, 0.12, 0.5))
		draw_circle(hand, 20.0 + mp * 6.0, Color(1.0, 0.25, 0.30, 0.85))
	_embers(30, cx - 400.0, cx + 400.0, floor_y, 700.0, Color(1.0, 0.2, 0.2, 0.9))


func _hunter(base: Vector2, k: float) -> void:
	var sil := Color(0.004, 0.004, 0.009)
	var rim := Color(0.80, 0.85, 1.0, 0.95)
	var bob: float = sin(_total * 6.0) * 4.0
	var wind: float = sin(_total * 2.5) * 20.0
	var b: Vector2 = base + Vector2(0.0, bob * k)
	_glow_ellipse(base + Vector2(10.0, 10.0) * k, 120.0 * k, 16.0 * k, Color(0, 0, 0, 0.6))
	_poly([Vector2(-30, -180), Vector2(40, -180), Vector2(60 + wind * 0.5, -30), Vector2(20 + wind, 10), Vector2(-85 + wind * 1.5, -10)], b, k, sil)
	_poly([Vector2(-20, -80), Vector2(0, -80), Vector2(-10, 0), Vector2(-35, 0)], b, k, sil)
	_poly([Vector2(10, -80), Vector2(35, -80), Vector2(45, 15), Vector2(15, 15)], b, k, sil)
	_ln(Vector2(-20, -170), Vector2(-40, -90), b, k, sil, 22.0)
	_ln(Vector2(30, -170), Vector2(90, -130), b, k, sil, 24.0)
	var g1 := Vector2(70, -140)
	var g2 := Vector2(200, -155)
	_ln(g1, g1 + Vector2(50, -5), b, k, sil, 24.0)
	_ln(g1 + Vector2(40, -5), g2, b, k, sil, 14.0)
	_ln(g1 + Vector2(40, -12), g2 + Vector2(0, -7), b, k, sil, 8.0)
	var core: Vector2 = b + (g1 + Vector2(65, -8)) * k
	var gp: float = 0.5 + 0.5 * sin(_total * 15.0)
	_glow(core, (26.0 + gp * 14.0) * k, Color(0.3, 0.7, 1.0, 0.55))
	draw_circle(core, 4.0 * k, Color(0.7, 0.95, 1.0))
	_glow(b + (g2 + Vector2(14, -12 + wind * 0.2)) * k, 26.0 * k, Color(0.6, 0.7, 0.8, 0.18))
	_poly([Vector2(-25, -180), Vector2(35, -180), Vector2(25, -210), Vector2(-15, -210)], b, k, sil)
	draw_circle(b + Vector2(5, -215) * k, 18.0 * k, sil)
	_ln(Vector2(10, -215), Vector2(18, -212), b, k, Color(0.4, 0.8, 1.0, 0.95), 2.0)
	_poly([Vector2(-55, -215), Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], b, k, sil)
	_poly([Vector2(-25, -230), Vector2(-15, -265), Vector2(15, -265), Vector2(25, -230)], b, k, sil)
	draw_polyline(_xf([Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], b, k), rim, 3.0, true)
	draw_polyline(_xf([Vector2(35, -180), Vector2(60 + wind * 0.5, -30)], b, k), rim, 2.5, true)
	_ln(g1 + Vector2(40, -16), g2 + Vector2(0, -11), b, k, rim, 2.0)


func _scene_hunter() -> void:
	var ground: float = 860.0
	_sky(Color(0.03, 0.04, 0.09), Color(0.17, 0.20, 0.30))
	var moon := Vector2(_vw * 0.84, 250.0)
	_moon(moon, 115.0, Color(0.86, 0.89, 0.96), Color(0.55, 0.65, 0.95))
	_clouds(300.0, Color(0.03, 0.04, 0.08, 0.55), 22.0, 6, 5.0)
	_mountains(780.0, 120.0, Color(0.05, 0.06, 0.10), 9.1)

	# Casas ao longe e portão gótico
	for i in 6:
		var fi: float = float(i)
		var hx: float = _vw * 0.30 + fi * 230.0
		_house(hx, ground - 20.0, 170.0, 140.0 + _h(fi) * 40.0, 90.0, Color(0.045, 0.055, 0.085), Color(0.025, 0.03, 0.05), fi * 2.0, int(fi) % 2 == 1, false)
	var iron := Color(0.015, 0.018, 0.035)
	var g_left: float = _vw * 0.12
	var g_right: float = _vw * 0.52
	draw_rect(Rect2(g_left, ground - 340.0, 64.0, 340.0), iron)
	draw_rect(Rect2(g_right, ground - 340.0, 64.0, 340.0), iron)
	draw_arc(Vector2((g_left + g_right + 64.0) * 0.5, ground - 330.0), (g_right - g_left + 64.0) * 0.5, PI, TAU, 28, iron, 40.0)
	var lantern := Vector2(g_left + 64.0, ground - 170.0)
	draw_line(Vector2(g_left + 32.0, ground - 240.0), lantern, iron, 4.0)
	_glow(lantern + Vector2(0.0, 18.0), 140.0, Color(1.0, 0.6, 0.15, 0.40))
	draw_rect(Rect2(lantern.x - 11.0, lantern.y, 22.0, 34.0), Color(1.0, 0.72, 0.25, 0.95 + sin(_total * 10.0) * 0.05))

	# Chão molhado com reflexos
	_vgrad(Rect2(-400.0, ground, _vw + 800.0, 700.0), Color(0.05, 0.06, 0.09), Color(0.012, 0.014, 0.025))
	draw_line(Vector2(-200.0, ground), Vector2(_vw + 200.0, ground), Color(0.15, 0.18, 0.26), 3.0)
	_glow_ellipse(Vector2(moon.x, ground + 90.0), 90.0, 260.0, Color(0.55, 0.65, 0.95, 0.20))
	_glow_ellipse(lantern + Vector2(0.0, 200.0), 70.0, 160.0, Color(1.0, 0.6, 0.2, 0.22))
	for i in 5:
		var fi: float = float(i)
		_glow_ellipse(Vector2(_vw * (0.1 + 0.2 * fi), ground + 120.0 + _h(fi * 4.0) * 120.0), 120.0, 18.0, Color(0.5, 0.6, 0.9, 0.16))

	_clouds(ground - 10.0, Color(0.45, 0.50, 0.70, 0.13), 15.0, 7, 1.0)
	_hunter(Vector2(_vw * 0.33, ground + 90.0), 1.75)
	_rain(150, 0.28)
	_clouds(ground + 60.0, Color(0.40, 0.45, 0.65, 0.10), 20.0, 5, 8.0)


func _scene_wolf_eye() -> void:
	_vgrad(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0), Color(0.008, 0.012, 0.02), Color(0.03, 0.04, 0.06))
	_glow_ellipse(Vector2(_vw * 0.25, 120.0), 700.0, 400.0, Color(0.35, 0.45, 0.75, 0.20))
	_pine_row(900.0, 110.0, 520.0, 260.0, Color(0.006, 0.01, 0.016), 4.0)
	_clouds(700.0, Color(0.30, 0.38, 0.55, 0.12), 10.0, 6, 2.0)

	var eye_open: float = clampf((_elapsed - 0.8) / 1.5, 0.0, 1.0)
	var awake: bool = eye_open > 0.8
	var breath: float = sin(_total * 3.0) * 6.0
	var shake := Vector2(sin(_total * 45.0) * 1.5, cos(_total * 35.0) * 1.5) if awake else Vector2.ZERO
	var c := Vector2(_vw * 0.5, 540.0) + Vector2(0.0, breath) + shake
	var k: float = 1.15
	var sil := Color(0.002, 0.003, 0.006)

	var outline: Array = [Vector2(0, -260), Vector2(120, -220), Vector2(220, -100), Vector2(170, -40), Vector2(280, 40), Vector2(230, 90),
		Vector2(260, 170), Vector2(130, 240), Vector2(80, 280), Vector2(-80, 280), Vector2(-130, 240), Vector2(-260, 170),
		Vector2(-230, 90), Vector2(-280, 40), Vector2(-170, -40), Vector2(-220, -100), Vector2(-120, -220)]
	_poly(outline, c, k, sil)

	# Pelagem: fios arrepiados ao longo do contorno
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		for j in 4:
			var t: float = float(j) / 4.0
			var p: Vector2 = a.lerp(b, t)
			var dir: Vector2 = p.normalized()
			var len_v: float = 14.0 + _h(float(i * 7 + j)) * 22.0
			var sway: float = sin(_total * 2.0 + float(i + j)) * 4.0
			draw_line(c + (p - dir * 12.0) * k, c + (p + dir * len_v + Vector2(sway, 0.0)) * k, sil, 5.0 * k, true)
	draw_polyline(_xf([Vector2(-170, -40), Vector2(-220, -100), Vector2(-120, -220), Vector2(0, -260), Vector2(120, -220), Vector2(220, -100), Vector2(170, -40)], c, k),
		Color(0.55, 0.68, 0.95, 0.45), 3.0, true)

	# Olhos
	if eye_open > 0.0:
		for side in [-1.0, 1.0]:
			var e: Vector2 = c + Vector2(side * 110.0, -50.0) * k
			var pulse: float = sin(_total * 12.0) * 6.0 * eye_open
			_glow(e, (150.0 * eye_open + pulse) * k, Color(0.9, 0.15, 0.0, 0.30))
			_glow(e, 80.0 * eye_open * k, Color(1.0, 0.45, 0.0, 0.50))
			var r: float = 28.0 * eye_open * k
			draw_circle(e, r, Color(1.0, 0.68, 0.0))
			draw_circle(e, r * 0.62, Color(1.0, 0.95, 0.3))
			var pw: float = 4.0 * eye_open * k
			var ph: float = 24.0 * eye_open * k
			draw_colored_polygon(PackedVector2Array([e + Vector2(0, -ph), e + Vector2(pw, 0), e + Vector2(0, ph), e + Vector2(-pw, 0)]), Color(0.05, 0.0, 0.0))
			var inner: float = side * -35.0
			var outer: float = side * 45.0
			draw_line(e + Vector2(outer, -35.0) * k, e + Vector2(inner, 5.0) * k, sil, 30.0 * k, true)
			draw_line(e + Vector2(outer, 28.0) * k, e + Vector2(inner, 15.0) * k, sil, 18.0 * k, true)
			draw_circle(e + Vector2(side * 8.0, -10.0) * k * eye_open, 4.0 * k * eye_open, Color(1, 1, 1, 0.7))

	# Presas, baba e vapor
	if eye_open > 0.6:
		var reveal: float = (eye_open - 0.6) * 2.5
		var sy: float = 120.0
		draw_line(c + Vector2(-40, sy - 20) * k, c + Vector2(40, sy - 20) * k, Color(0.3, 0.15, 0.0, 0.4 * reveal), 6.0 * k)
		draw_line(c + Vector2(-25, sy - 5) * k, c + Vector2(25, sy - 5) * k, Color(0.3, 0.15, 0.0, 0.3 * reveal), 4.0 * k)
		for side in [-1.0, 1.0]:
			var fp: Vector2 = c + Vector2(side * 50.0, sy + 70.0) * k
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-12, 0) * k, fp + Vector2(12, 0) * k, fp + Vector2(side * 5.0, 55.0) * k]), Color(0.85, 0.85, 0.80, 0.55 * reveal))
			draw_line(fp + Vector2(side * 5.0, 50.0) * k, fp + Vector2(side * 2.0, 10.0) * k, Color(1, 1, 1, 0.45 * reveal), 2.0 * k)
			var dt: float = _total * (80.0 if side < 0.0 else 110.0)
			var drop: float = fmod(dt, 120.0)
			if drop < 100.0:
				var dxp: float = fp.x + side * 2.0
				draw_line(Vector2(dxp, fp.y + 20.0 * k), Vector2(dxp, fp.y + (20.0 + drop) * k), Color(0.7, 0.9, 1.0, 0.22 * reveal), 2.0)
				draw_circle(Vector2(dxp, fp.y + (20.0 + drop) * k), 3.5, Color(0.8, 0.95, 1.0, 0.45 * reveal))
		for i in 8:
			var fi: float = float(i)
			var age: float = fposmod(_total * 0.5 + fi * 0.13, 1.0)
			_glow(c + Vector2((fi - 3.5) * 14.0 + sin(_total + fi) * 20.0, 250.0 - age * 200.0) * k, (30.0 + age * 50.0) * k, Color(0.7, 0.8, 1.0, 0.10 * (1.0 - age) * reveal))


# ==============================================================================
# CENAS 8-9: CONTROLES E TÍTULO FINAL
# ==============================================================================

const GOLD: Color = Color(1.0, 0.82, 0.45)
const BODY: Color = Color(0.92, 0.90, 0.96)


func _keycap(rect: Rect2, label: String, hi: bool, font_size: int, alpha: float) -> void:
	draw_style_box(_key_hi_style if hi else _key_style, rect)
	draw_string(FONT_BOLD, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + float(font_size) * 0.28), label,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(1, 1, 1, alpha))


func _text(pos: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	draw_string(FONT_BOLD, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, color.a * alpha))


func _card(rect: Rect2, header: String, delay: float, border: Color) -> float:
	var a: float = _smooth((_elapsed - delay) / 0.5)
	var r := Rect2(rect.position + Vector2(0.0, (1.0 - a) * 40.0), rect.size)
	draw_style_box(_card_style, r)
	draw_rect(r, Color(border.r, border.g, border.b, border.a * a), false, 3.0)
	_text(r.position + Vector2(40.0, 70.0), header, 42, GOLD, a)
	draw_line(r.position + Vector2(40.0, 92.0), r.position + Vector2(r.size.x - 40.0, 92.0), Color(0.55, 0.30, 0.75, 0.6 * a), 2.0)
	return a


func _scene_controls() -> void:
	var cx: float = _vw * 0.5
	_sky(Color(0.02, 0.012, 0.045), Color(0.10, 0.05, 0.15))
	_stars(60, 700.0, 0.7)
	_mountains(900.0, 160.0, Color(0.03, 0.02, 0.06), 2.0)
	_castle(Vector2(cx, 980.0), 0.55, false, true)
	draw_rect(Rect2(-400.0, -300.0, _vw + 800.0, 1700.0), Color(0.01, 0.005, 0.02, 0.62))

	var ta: float = _smooth(_elapsed / 0.6)
	draw_string_outline(FONT_BOLD, Vector2(0.0, 175.0), "GUIAS DE SOBREVIVÊNCIA", HORIZONTAL_ALIGNMENT_CENTER, _vw, 82, 12, Color(0.12, 0.03, 0.18, ta))
	draw_string(FONT_BOLD, Vector2(0.0, 175.0), "GUIAS DE SOBREVIVÊNCIA", HORIZONTAL_ALIGNMENT_CENTER, _vw, 82, Color(0.92, 0.80, 1.0, ta))

	var cw: float = minf(830.0, _vw * 0.5 - 70.0)
	var x1: float = cx - cw - 30.0
	var x2: float = cx + 30.0

	# --- Movimentação ---
	var a1: float = _card(Rect2(x1, 230.0, cw, 440.0), "MOVIMENTAÇÃO", 0.4, Color(0.55, 0.30, 0.75, 0.9))
	var hi: int = int(_total * 2.0) % 4
	var c1 := Vector2(x1, 230.0 + (1.0 - a1) * 40.0)
	_keycap(Rect2(c1.x + 120.0, c1.y + 125.0, 84.0, 84.0), "W", hi == 0, 40, a1)
	_keycap(Rect2(c1.x + 30.0, c1.y + 217.0, 84.0, 84.0), "A", hi == 1, 40, a1)
	_keycap(Rect2(c1.x + 120.0, c1.y + 217.0, 84.0, 84.0), "S", hi == 2, 40, a1)
	_keycap(Rect2(c1.x + 210.0, c1.y + 217.0, 84.0, 84.0), "D", hi == 3, 40, a1)
	_text(c1 + Vector2(340.0, 190.0), "W A S D", 40, GOLD, a1)
	_text(c1 + Vector2(340.0, 236.0), "Mover o Lobo", 34, BODY, a1)
	_keycap(Rect2(c1.x + 30.0, c1.y + 335.0, 280.0, 70.0), "ESPAÇO", int(_total * 1.2) % 2 == 0, 32, a1)
	_text(c1 + Vector2(340.0, 385.0), "Ataque corpo a corpo", 34, BODY, a1)

	# --- Combate ---
	var a2: float = _card(Rect2(x2, 230.0, cw, 440.0), "COMBATE", 0.9, Color(0.55, 0.30, 0.75, 0.9))
	var c2 := Vector2(x2, 230.0 + (1.0 - a2) * 40.0)
	var mouse := Rect2(c2.x + 60.0, c2.y + 125.0, 110.0, 170.0)
	draw_style_box(_key_style, mouse)
	var click: float = 0.5 + 0.5 * sin(_total * 5.0)
	draw_rect(Rect2(mouse.position.x + 6.0, mouse.position.y + 6.0, 48.0, 70.0), Color(1.0, 0.3, 0.35, (0.35 + 0.55 * click) * a2))
	draw_line(Vector2(mouse.position.x + 55.0, mouse.position.y + 6.0), Vector2(mouse.position.x + 55.0, mouse.position.y + 80.0), Color(0.6, 0.5, 0.8, a2), 3.0)
	draw_line(Vector2(mouse.position.x + 6.0, mouse.position.y + 80.0), Vector2(mouse.end.x - 6.0, mouse.position.y + 80.0), Color(0.6, 0.5, 0.8, a2), 3.0)
	_text(c2 + Vector2(230.0, 175.0), "MOUSE", 40, GOLD, a2)
	_text(c2 + Vector2(230.0, 218.0), "Mirar a arma", 34, BODY, a2)
	_text(c2 + Vector2(230.0, 285.0), "CLIQUE ESQ.", 40, GOLD, a2)
	_text(c2 + Vector2(230.0, 328.0), "Atirar", 34, BODY, a2)
	draw_multiline_string(FONT_BOLD, c2 + Vector2(40.0, 380.0), "A munição se regenera depois de alguns segundos sem atirar.",
		HORIZONTAL_ALIGNMENT_LEFT, cw - 80.0, 26, 2, Color(0.75, 0.70, 0.85, a2))

	# --- Objetivo ---
	var a3: float = _card(Rect2(x1, 705.0, cw * 2.0 + 60.0, 215.0), "OBJETIVO", 1.4, Color(0.85, 0.20, 0.30, 0.95))
	var c3 := Vector2(x1, 705.0 + (1.0 - a3) * 40.0)
	_keycap(Rect2(c3.x + 40.0, c3.y + 120.0, 76.0, 76.0), "Q", false, 38, a3)
	_text(c3 + Vector2(135.0, 172.0), "Interagir", 34, BODY, a3)
	_keycap(Rect2(c3.x + 380.0, c3.y + 120.0, 120.0, 76.0), "ESC", false, 32, a3)
	_text(c3 + Vector2(520.0, 172.0), "Pausar", 34, BODY, a3)
	draw_multiline_string(FONT_BOLD, c3 + Vector2(760.0, 150.0), "Sobreviva à noite, invada o castelo e destrua o Drácula.",
		HORIZONTAL_ALIGNMENT_LEFT, cw * 2.0 - 760.0 + 30.0, 36, 2, Color(1.0, 0.86, 0.86, a3))


func _scene_final() -> void:
	var cx: float = _vw * 0.5
	_sky(Color(0.11, 0.01, 0.04), Color(0.40, 0.05, 0.09))
	_stars(40, 500.0, 0.5)
	_moon(Vector2(cx, 430.0), 190.0, Color(1.0, 0.14, 0.18), Color(1.0, 0.05, 0.10))
	_clouds(390.0, Color(0.10, 0.0, 0.02, 0.65), 20.0, 6, 4.0)
	_mountains(850.0, 160.0, Color(0.05, 0.01, 0.04), 5.5)
	_glow(Vector2(cx, 600.0), 520.0, Color(1.0, 0.02, 0.05, 0.10 + 0.05 * sin(_total * 3.0)))
	_castle(Vector2(cx, 910.0), 0.8, true, true)
	for i in 14:
		var fi: float = float(i)
		var a: float = _total * (0.6 + _h(fi) * 0.5) + fi * 0.8
		_bat(Vector2(cx, 380.0) + Vector2(cos(a) * (320.0 + _h(fi * 2.0) * 300.0), sin(a) * (90.0 + _h(fi * 4.0) * 120.0)), 0.55 + _h(fi * 5.0) * 0.6, fi, Color(0.01, 0.0, 0.01))
	_clouds(960.0, Color(0.70, 0.12, 0.18, 0.16), 16.0, 7, 12.0)
	_embers(60, 0.0, _vw, 1040.0, 760.0, Color(1.0, 0.25, 0.12, 1.0))
	if _flash_now > 0.4:
		_bolt(_vw * (0.10 + 0.80 * _h(floorf((_total + 0.6) / 3.4))), -50.0, 760.0, floorf((_total + 0.6) / 3.4), Color(1.0, 0.55, 0.55))

# Logotipo
	var t: float = _smooth((_elapsed - 0.8) / 1.2)
	var scale_in: float = 1.0 + (1.0 - t) * 0.08
	_glow_ellipse(Vector2(cx, 230.0), 820.0, 240.0, Color(1.0, 0.05, 0.10, 0.34 * t))
	
	# Ajustado o tamanho da fonte para 130 para se adequar perfeitamente em duas linhas
	var fs: int = int(130.0 * scale_in)
	
	var line1: String = "THE LEGEND OF DRACULA"
	var line2: String = "FALLS IN THE MOONLIGHT"
	
	var y1: float = 200.0 # Altura da 1ª linha
	var y2: float = 300.0 # Altura da 2ª linha
	var dec_y: float = 310.0 # Altura da linha decorativa

	# Primeira Linha: "THE LEGEND OF DRACULA"
	draw_string_outline(FONT_BOLD, Vector2(0.0, y1), line1, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, 18, Color(0.12, 0.0, 0.02, t))
	draw_string(FONT_BOLD, Vector2(0.0, y1), line1, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, Color(1.0, 0.24, 0.18, t))

	# Segunda Linha: "FALLS IN THE MOONLIGHT"
	draw_string_outline(FONT_BOLD, Vector2(0.0, y2), line2, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, 18, Color(0.12, 0.0, 0.02, t))
	draw_string(FONT_BOLD, Vector2(0.0, y2), line2, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, Color(1.0, 0.24, 0.18, t))

	# Linhas decorativas e losango (posicionados logo abaixo da 2ª linha)
	draw_line(Vector2(cx - 260.0, dec_y), Vector2(cx - 24.0, dec_y), Color(1.0, 0.5, 0.45, 0.8 * t), 3.0, true)
	draw_line(Vector2(cx + 24.0, dec_y), Vector2(cx + 260.0, dec_y), Color(1.0, 0.5, 0.45, 0.8 * t), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, dec_y - 10.0), 
		Vector2(cx + 10.0, dec_y), 
		Vector2(cx, dec_y + 10.0), 
		Vector2(cx - 10.0, dec_y)
	]), Color(1.0, 0.5, 0.45, 0.9 * t))

func _play_shot_audio() -> void:
	if not play_music:
		return
	# some com o audio do plano anterior (caso o jogador tenha pulado)
	if is_instance_valid(_shot_player):
		var old: AudioStreamPlayer = _shot_player
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -50.0, 0.25)
		tw.tween_callback(old.queue_free)
	var path: String = AUDIO_DIR + SHOT_AUDIO[_shot]
	if not ResourceLoader.exists(path):
		return
	_shot_player = AudioStreamPlayer.new()
	_shot_player.stream = load(path)
	_shot_player.volume_db = -3.0
	add_child(_shot_player)
	_shot_player.play()


## Dispara o trovao no momento em que o relampago acende na tela.
func _update_thunder(delta: float) -> void:
	_thunder_cd = maxf(_thunder_cd - delta, 0.0)
	var f: float = _lightning_for_shot()
	if f > 0.3 and _prev_flash <= 0.3 and _thunder_cd <= 0.0:
		_play_thunder()
		_thunder_cd = 1.5
	_prev_flash = f


func _play_thunder() -> void:
	if not play_music or not ResourceLoader.exists(THUNDER_PATH):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(THUNDER_PATH)
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
