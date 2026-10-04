class_name Level1AftermathCinematic
extends Control

## Wolf Down - Cinemática pós Level 1.
## Lobsome aparece sob o luar, ferido, observa seu velho .38 e percebe
## que será necessário melhorar a arma antes de seguir para o cemitério.

const DESIGN_H: float = 1080.0
const TYPE_SPEED: float = 0.025
const NEXT_LEVEL_INDEX: int = 2
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const WOLF_PORTRAIT: Texture2D = preload("res://player_sprites/lobo3x4.png")
const MUSIC_PATH: String = "res://leveis/moonlight_hollow.wav"
const WOLF_SOUND_PATH: String = "res://audio/shot_07_olho_lobo.wav"

const SHOT_DURATION: Array[float] = [4.5, 4.5, 4.5, 5.0]
const ZOOM_FROM: Array[float] = [1.00, 1.05, 1.08, 1.00]
const ZOOM_TO: Array[float] = [1.05, 1.12, 1.22, 1.06]
const PAN_TO: Array[Vector2] = [Vector2(0, 0), Vector2(-40, -8), Vector2(90, 20), Vector2(0, 0)]

var _shot: int = 0
var _elapsed: float = 0.0
var _total: float = 0.0
var _typing_index: int = 0
var _typing_time: float = 0.0
var _finished: bool = false
var _fade_value: float = 0.0
var _scale: float = 1.0
var _vw: float = 1920.0

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
	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	_play_shot_sound()
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_fade_value = 0.0
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
	if _shot != 1 or not ResourceLoader.exists(WOLF_SOUND_PATH):
		return
	if is_instance_valid(_wolf_sound):
		_wolf_sound.queue_free()
	_wolf_sound = AudioStreamPlayer.new()
	_wolf_sound.stream = load(WOLF_SOUND_PATH)
	_wolf_sound.volume_db = -8.0
	add_child(_wolf_sound)
	_wolf_sound.play()


func _smooth(t: float) -> float:
	var v := clampf(t, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


func _draw() -> void:
	var screen := get_viewport_rect().size
	_scale = screen.y / DESIGN_H
	_vw = screen.x / _scale

	var p := clampf(_elapsed / SHOT_DURATION[_shot], 0.0, 1.0)
	var e := _smooth(p)
	var zoom := lerpf(ZOOM_FROM[_shot], ZOOM_TO[_shot], e)
	var pan := PAN_TO[_shot] * e
	var s := _scale * zoom
	var origin := screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + pan * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	_scene_aftermath()

	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color.WHITE)

	var bar_h := screen.y * 0.075
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.95))
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color(0, 0, 0, 0.95))

	if _fade_value > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, _fade_value))


func _scene_aftermath() -> void:
	var cx := _vw * 0.5
	var ground := 900.0

	# Céu profundo de inverno + halo frio da lua.
	_draw_vertical_gradient(Rect2(-400.0, -300.0, _vw + 800.0, 1500.0), Color(0.006, 0.008, 0.022), Color(0.075, 0.045, 0.13))
	_draw_stars(74)
	_draw_moon(Vector2(_vw * 0.74, 235.0), 105.0)
	_draw_clouds(305.0, Color(0.12, 0.10, 0.19, 0.22), 12.0, 5, 1.7)

	# Montanhas e árvores criam profundidade para o cenário pós-batalha.
	_draw_mountains(720.0, 170.0, Color(0.02, 0.018, 0.045))
	_draw_pines(855.0, Color(0.008, 0.009, 0.018), 260.0)
	_draw_pines(975.0, Color(0.004, 0.004, 0.010), 360.0)

	# Chão molhado e poça de luar.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-200, 845), Vector2(_vw + 200, 845), Vector2(_vw + 200, 1220), Vector2(-200, 1220)
	]), Color(0.012, 0.012, 0.024))
	_glow_ellipse(Vector2(cx, ground + 12.0), 430.0, 55.0, Color(0.30, 0.28, 0.58, 0.20))
	_glow_ellipse(Vector2(cx, ground + 15.0), 230.0, 28.0, Color(0.62, 0.67, 1.0, 0.15))

	_draw_blood_marks(cx, ground)
	_draw_lobsome(Vector2(cx - 70.0, 650.0), 1.0)

	# O revólver entra em destaque progressivamente.
	var gun_progress := _smooth(clampf((_elapsed - 0.65) / 2.8, 0.0, 1.0)) if _shot >= 2 else 0.0
	if _shot == 3:
		gun_progress = 1.0
	_draw_38(Vector2(cx + 280.0 - 120.0 * gun_progress, 792.0 - 50.0 * gun_progress), 1.15, gun_progress)

	# Cortina suave de névoa baixa.
	_draw_mist(930.0)


func _draw_lobsome(center: Vector2, body_scale: float) -> void:
	var breath := sin(_total * 2.4) * 7.0
	var c := center + Vector2(0, breath)
	var portrait_size := Vector2(520.0, 450.0) * body_scale

	# Ombros/torso em sombra.
	_glow_ellipse(c + Vector2(0, 235.0), 255.0, 95.0, Color(0, 0, 0, 0.60))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-210, 420), c + Vector2(-260, 290), c + Vector2(-175, 190),
		c + Vector2(175, 190), c + Vector2(260, 290), c + Vector2(210, 420)
	]), Color(0.012, 0.008, 0.020, 0.98))

	# Luz lunar recorta o contorno do pelo.
	var rim_alpha := 0.46 + 0.08 * sin(_total * 1.8)
	draw_arc(c + Vector2(0, 30), 275.0, PI * 1.04, PI * 1.96, 48, Color(0.66, 0.62, 1.0, rim_alpha), 5.0, true)
	draw_arc(c + Vector2(0, 30), 300.0, PI * 1.10, PI * 1.90, 40, Color(0.35, 0.26, 0.58, 0.35), 3.0, true)

	# O retrato existente do Lobsome: pelo roxo e olhos amarelos.
	var portrait_y := c.y - 35.0
	draw_texture_rect(WOLF_PORTRAIT, Rect2(Vector2(c.x, portrait_y) - portrait_size * 0.5, portrait_size), false, Color(1, 1, 1, 0.98))

	# Feridas visíveis sobre a pelagem.
	var wound := Color(0.58, 0.07, 0.20, 0.88)
	var wound_light := Color(0.92, 0.18, 0.28, 0.76)
	for side in [-1.0, 1.0]:
		var cheek := c + Vector2(side * 135.0, 68.0) * body_scale
		draw_line(cheek + Vector2(-34, -12) * side, cheek + Vector2(18, 26) * side, wound, 7.0, true)
		draw_line(cheek + Vector2(-20, -30) * side, cheek + Vector2(30, 6) * side, wound_light, 3.0, true)
		_glow_ellipse(cheek + Vector2(8, 7) * side, 30.0, 12.0, Color(0.55, 0.03, 0.12, 0.18))

	# Sangue seco no peito.
	for i in 5:
		var fi := float(i)
		var p := c + Vector2((fi - 2.0) * 34.0, 240.0 + sin(fi * 1.5 + _total) * 8.0)
		draw_circle(p, 5.0 + fi * 0.9, Color(0.35, 0.03, 0.12, 0.65))

	# Reflexo amarelo dos olhos, reforçado pelo luar.
	var eye_glow := 0.58 + 0.12 * sin(_total * 5.0)
	for side in [-1.0, 1.0]:
		var eye := c + Vector2(side * 100.0, -43.0) * body_scale
		_glow(eye, 80.0, Color(1.0, 0.68, 0.10, 0.12 * eye_glow))


func _draw_38(pos: Vector2, scale_v: float, reveal: float) -> void:
	if reveal <= 0.0:
		return
	var alpha := clampf(reveal, 0.0, 1.0)
	var steel := Color(0.19, 0.20, 0.24, alpha)
	var steel_hi := Color(0.58, 0.61, 0.70, 0.92 * alpha)
	var dark := Color(0.035, 0.025, 0.045, 0.98 * alpha)
	var grip := Color(0.16, 0.055, 0.07, 0.98 * alpha)

	_glow(pos + Vector2(-10, 0), 150.0 * alpha, Color(0.70, 0.75, 1.0, 0.10 * alpha))

	# Cano.
	draw_rect(Rect2(pos + Vector2(-150, -26) * scale_v, Vector2(140, 22) * scale_v), steel)
	draw_rect(Rect2(pos + Vector2(-153, -22) * scale_v, Vector2(140, 8) * scale_v), steel_hi)
	draw_rect(Rect2(pos + Vector2(-190, -31) * scale_v, Vector2(48, 34) * scale_v), dark)

	# Corpo + cilindro.
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-24, -52) * scale_v,
		pos + Vector2(62, -45) * scale_v,
		pos + Vector2(82, 16) * scale_v,
		pos + Vector2(20, 40) * scale_v,
		pos + Vector2(-34, 14) * scale_v
	]), steel)
	draw_circle(pos + Vector2(20, -4) * scale_v, 35.0 * scale_v, dark)
	draw_circle(pos + Vector2(20, -4) * scale_v, 30.0 * scale_v, steel_hi)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.2
		draw_circle(pos + Vector2(20, -4) * scale_v + Vector2(cos(a), sin(a)) * 20.0 * scale_v, 5.0 * scale_v, dark)

	# Cabo.
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(30, 24) * scale_v,
		pos + Vector2(70, 30) * scale_v,
		pos + Vector2(56, 122) * scale_v,
		pos + Vector2(2, 111) * scale_v,
		pos + Vector2(-10, 56) * scale_v
	]), grip)
	draw_line(pos + Vector2(20, 48) * scale_v, pos + Vector2(48, 108) * scale_v, Color(0.63, 0.16, 0.20, 0.60 * alpha), 4.0 * scale_v, true)

	# Marca .38.
	var label_pos := pos + Vector2(-74, 164) * scale_v
	draw_string(FONT_BOLD, label_pos, ".38", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(42.0 * scale_v), Color(0.95, 0.82, 0.48, alpha))


func _draw_blood_marks(cx: float, ground: float) -> void:
	for i in 9:
		var fi := float(i)
		var x := cx - 260.0 + fi * 62.0 + sin(fi * 4.3) * 20.0
		var y: float = ground + 14.0 + abs(sin(fi * 1.7)) * 28.0
		draw_circle(Vector2(x, y), 3.0 + fi * 0.35, Color(0.40, 0.02, 0.10, 0.44))


func _draw_vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]), top)
	var steps := 18
	for i in steps:
		var t := (float(i) + 1.0) / float(steps)
		var y0 := lerpf(rect.position.y, rect.end.y, float(i) / float(steps))
		var y1 := lerpf(rect.position.y, rect.end.y, t)
		draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0), top.lerp(bottom, t))


func _draw_stars(count: int) -> void:
	for i in count:
		var fi := float(i)
		var x := fposmod(fi * 287.0 + 80.0, _vw)
		var y := 90.0 + fposmod(fi * 149.0, 560.0)
		var tw := 0.30 + 0.35 * (0.5 + 0.5 * sin(_total * 2.1 + fi))
		draw_circle(Vector2(x, y), 1.5 + (fi % 3.0) * 0.5, Color(0.70, 0.75, 1.0, tw))


func _draw_moon(pos: Vector2, radius: float) -> void:
	_glow(pos, radius * 3.2, Color(0.66, 0.70, 1.0, 0.16))
	draw_circle(pos, radius, Color(0.89, 0.90, 1.0, 0.94))
	for i in 6:
		var fi := float(i)
		var crater := pos + Vector2(cos(fi * 2.2), sin(fi * 1.8)) * radius * (0.25 + (fi * 0.03))
		draw_circle(crater, radius * 0.08 + fi * 2.0, Color(0.70, 0.72, 0.82, 0.22))


func _draw_pines(base_y: float, col: Color, max_h: float) -> void:
	var x := -30.0
	var i := 0
	while x < _vw + 60.0:
		var h := max_h * (0.55 + 0.45 * fposmod(float(i) * 1.71, 1.0))
		var w := h * 0.34
		draw_rect(Rect2(x - h * 0.018, base_y - h * 0.08, h * 0.036, h * 0.18), col)
		for t in 5:
			var top := Vector2(x, base_y - h + float(t) * h * 0.16)
			var half := w * (0.28 + float(t) * 0.12)
			draw_colored_polygon(PackedVector2Array([
				top, Vector2(x + half, top.y + h * 0.23), Vector2(x - half, top.y + h * 0.23)
			]), col)
		x += 78.0
		i += 1


func _draw_mountains(base_y: float, amp: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var x := -200.0
	while x <= _vw + 200.0:
		var y := base_y - abs(sin(x * 0.0027)) * amp - sin(x * 0.006) * 30.0
		pts.append(Vector2(x, y))
		x += 35.0
	pts.append(Vector2(_vw + 300.0, 1200.0))
	pts.append(Vector2(-300.0, 1200.0))
	draw_colored_polygon(pts, col)


func _draw_clouds(y: float, col: Color, speed: float, count: int, seed_v: float) -> void:
	for i in count:
		var fi := float(i)
		var x := fposmod(fi * 410.0 + _total * speed + seed_v * 93.0, _vw + 500.0) - 250.0
		var cy := y + sin(_total * 0.25 + fi) * 14.0
		for j in 4:
			var fj := float(j)
			var r := 70.0 + fj * 18.0
			draw_circle(Vector2(x + (fj - 1.5) * 90.0, cy + sin(fj) * 12.0), r, col)


func _draw_mist(y: float) -> void:
	for i in 9:
		var fi := float(i)
		var x := fposmod(fi * 300.0 + _total * 18.0, _vw + 400.0) - 200.0
		var yy := y + sin(_total * 0.5 + fi) * 18.0
		_glow_ellipse(Vector2(x, yy), 180.0, 24.0, Color(0.35, 0.39, 0.63, 0.045))


func _glow(pos: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _glow_ellipse(pos: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(pos - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, color)
