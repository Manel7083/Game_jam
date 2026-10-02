class_name OpeningCinematic
extends Control
## Wolf Down - Cinemática de Abertura Profissional (Godot 4)
## Gráficos procedurais de alto contraste, textos traduzidos e iluminação aprimorada.

const TYPE_SPEED: float = 0.025

const SHOT_DURATION: Array[float] = [
	4.5, # 0 - Prólogo
	5.0, # 1 - Sepulturas
	5.0, # 2 - Vilarejo
	5.5, # 3 - Castelo
	6.0, # 4 - Despertar do Drácula
	4.5, # 5 - Drácula Despertado
	5.0, # 6 - O Caçador
	5.0, # 7 - Olho do Lobo
	6.5, # 8 - Controles
	5.5  # 9 - Título Final
]

var _shot: int = 0
var _elapsed: float = 0.0
var _typing_index: int = 0
var _typing_time: float = 0.0
var _finished: bool = false
var _fade_value: float = 0.0

var _story: Array[String] = [
	"Por séculos, o vilarejo viveu sob o peso de um nome esquecido.",
	"Então as sepulturas se abriram.\nOs mortos retornaram, e a noite aprendeu a caçar novamente.",
	"O vilarejo caiu em silêncio.\nPortas foram destruídas. Sangue manchou as ruas.\nNinguém sabia de onde as criaturas vinham.",
	"No centro da maldição ergue-se um castelo ancestral.\nAlgo em seu interior despertou.",
	"Sepultado sob a pedra e a escuridão,\nDrácula abre seus olhos mais uma vez.\nO selo foi quebrado.",
	"Ele se lembra do gosto do sangue.\nEle se lembra do medo.\nE ele se lembra do caçador.",
	"Um homem adentra a terra amaldiçoada.\nSem exército. Sem testemunhas.\nApenas uma arma... e um motivo para sobreviver.",
	"Wolf.\nA escuridão o observa.\nEntão, seus olhos se abrem.",
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
	"O OLHO NA ESCURIDÃO",
	"COMO SOBREVIVER",
	"A CAÇADA COMEÇA"
]

var _story_label: Label
var _title_label: Label
var _hint_label: Label
var _progress_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	_build_ui()
	_reset_shot()
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return

	_elapsed += delta
	_typing_time += delta

	var current_text: String = _story[_shot]

	if _typing_index < current_text.length():
		var steps: int = int(_typing_time / TYPE_SPEED)
		if steps > 0:
			_typing_index = mini(_typing_index + steps, current_text.length())
			_typing_time = 0.0
			_story_label.text = current_text.substr(0, _typing_index)
	else:
		_story_label.text = current_text

	_progress_label.text = "%d / %d" % [_shot + 1, _story.size()]
	_update_fade()
	queue_redraw()

	if _elapsed >= SHOT_DURATION[_shot]:
		_next_shot()


func _update_fade() -> void:
	var fade_in: float = clampf(_elapsed / 0.75, 0.0, 1.0)
	var time_left: float = float(SHOT_DURATION[_shot]) - _elapsed
	var fade_out: float = 0.0

	if time_left < 0.75:
		fade_out = clampf(1.0 - (time_left / 0.75), 0.0, 1.0)

	_fade_value = max(1.0 - fade_in, fade_out)


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


func _build_ui() -> void:
	# Legendas das Histórias com Alto Contraste
	_story_label = Label.new()
	_story_label.anchor_left = 0.08
	_story_label.anchor_right = 0.92
	_story_label.anchor_top = 0.58
	_story_label.anchor_bottom = 0.83
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.add_theme_font_size_override("font_size", 32)
	_story_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.98, 1.0))
	_story_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_story_label.add_theme_constant_override("shadow_offset_x", 2)
	_story_label.add_theme_constant_override("shadow_offset_y", 2)
	_story_label.add_theme_constant_override("outline_size", 6)
	_story_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 0.9))
	add_child(_story_label)

	# Título da Cena
	_title_label = Label.new()
	_title_label.anchor_left = 0.05
	_title_label.anchor_right = 0.95
	_title_label.anchor_top = 0.07
	_title_label.anchor_bottom = 0.18
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 44)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.98, 0.98))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.add_theme_constant_override("outline_size", 8)
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.15, 1.0))
	add_child(_title_label)

	# Contador de Progresso
	_progress_label = Label.new()
	_progress_label.anchor_left = 0.85
	_progress_label.anchor_right = 0.96
	_progress_label.anchor_top = 0.92
	_progress_label.anchor_bottom = 0.96
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.78, 0.8))
	add_child(_progress_label)

	# Barra de Dicas traduzida
	_hint_label = Label.new()
	_hint_label.anchor_left = 0.04
	_hint_label.anchor_right = 0.60
	_hint_label.anchor_top = 0.92
	_hint_label.anchor_bottom = 0.96
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.78, 0.8))
	_hint_label.text = "ENTER / ESPAÇO / CLIQUE — Continuar   |   ESC — Pular"
	add_child(_hint_label)


func _reset_shot() -> void:
	_elapsed = 0.0
	_typing_time = 0.0
	_typing_index = 0
	_story_label.text = ""
	_title_label.text = _titles[_shot]
	_title_label.visible = (_shot != 8)
	_story_label.visible = (_shot != 8)
	_hint_label.visible = true
	_progress_label.visible = true
	queue_redraw()


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


func _finish() -> void:
	if _finished:
		return

	_finished = true
	_hint_label.visible = false
	_progress_label.visible = false
	_story_label.visible = false
	_title_label.visible = false

	await get_tree().create_timer(0.7, true, false, true).timeout

	if is_instance_valid(GameManager):
		GameManager.load_level(1)


# ==============================================================================
# RENDERIZAÇÃO PRINCIPAL
# ==============================================================================

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size

	match _shot:
		0: _draw_prologue_scene(size)
		1: _draw_graves_scene(size)
		2: _draw_village_scene(size)
		3: _draw_castle_scene(size, false)
		4: _draw_dracula_wakeup_scene(size)    # REFORMULADA
		5: _draw_scene_6_dracula_throne(size)  # REFORMULADA
		6: _draw_hunter_scene(size)            # REFORMULADA
		7: _draw_wolf_eye_scene(size)
		8: _draw_controls_scene(size)
		9: _draw_final_scene(size)

	_draw_text_backdrop(size)
	_draw_letterbox(size)

	if _fade_value > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, _fade_value))


# ==============================================================================
# CENAS GRÁFICAS PROCEDURAIS
# ==============================================================================

func _draw_prologue_scene(size: Vector2) -> void:
	_draw_sky_gradient(size, Color(0.02, 0.01, 0.04), Color(0.08, 0.04, 0.12))
	_draw_stars(size)
	_draw_moon(Vector2(size.x * 0.78, size.y * 0.28), 75.0, Color(0.85, 0.85, 0.98), false)
	_draw_mountains(size, Color(0.03, 0.02, 0.05), 0.65)
	_draw_forest_silhouette(size, Color(0.02, 0.015, 0.035))
	_draw_ground(size)

	for i in range(5):
		var bx: float = fmod(_elapsed * 90.0 + float(i * 180), size.x + 200.0) - 100.0
		var by: float = size.y * 0.22 + sin(_elapsed * 2.0 + float(i)) * 25.0
		_draw_bat(Vector2(bx, by), 0.75)


func _draw_graves_scene(size: Vector2) -> void:
	_draw_sky_gradient(size, Color(0.01, 0.01, 0.03), Color(0.06, 0.04, 0.09))
	_draw_stars(size)
	_draw_moon(Vector2(size.x * 0.22, size.y * 0.30), 65.0, Color(0.75, 0.72, 0.88), false)
	_draw_fog_layer(size, 0.8)
	_draw_ground(size)

	for i in range(10):
		var gx: float = 60.0 + float(i) * (size.x / 10.0)
		var gh: float = 50.0 + float((i * 23) % 40)
		var top_y: float = size.y * 0.78 - gh

		draw_rect(Rect2(gx + 3, top_y + 3, 52, gh), Color(0.01, 0.01, 0.02, 0.6))
		draw_rect(Rect2(gx, top_y, 52, gh), Color(0.12, 0.11, 0.18))
		draw_arc(Vector2(gx + 26, top_y), 26, PI, TAU, 16, Color(0.12, 0.11, 0.18), 26.0)

		if i % 2 == 0:
			draw_line(Vector2(gx + 26, top_y + 15), Vector2(gx + 26, top_y + 45), Color(0.35, 0.30, 0.45), 3)
			draw_line(Vector2(gx + 12, top_y + 25), Vector2(gx + 40, top_y + 25), Color(0.35, 0.30, 0.45), 3)

	_draw_particles(size, 20, Color(0.4, 0.6, 0.9, 0.25), -40.0)


func _draw_village_scene(size: Vector2) -> void:
	_draw_sky_gradient(size, Color(0.03, 0.01, 0.05), Color(0.12, 0.03, 0.08))
	_draw_moon(Vector2(size.x * 0.80, size.y * 0.25), 70.0, Color(0.7, 0.6, 0.8), false)

	for i in range(5):
		var hx: float = 80.0 + float(i) * 280.0
		var hy: float = size.y * 0.52
		var flicker: float = 0.5 + sin(_elapsed * 8.0 + float(i * 3)) * 0.15

		draw_rect(Rect2(hx, hy, 210, 180), Color(0.04, 0.03, 0.06))
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx - 15, hy), Vector2(hx + 105, hy - 90), Vector2(hx + 225, hy)
		]), Color(0.02, 0.015, 0.035))

		draw_rect(Rect2(hx + 40, hy + 45, 30, 45), Color(0.9, 0.4, 0.1, flicker))
		draw_rect(Rect2(hx + 135, hy + 45, 30, 45), Color(0.9, 0.4, 0.1, flicker * 0.8))

	_draw_ground(size)


func _draw_castle_scene(size: Vector2, awakened: bool) -> void:
	# Céu mais claro e com contraste maior
	var sky_top: Color = (
		Color(0.12, 0.025, 0.055, 1.0)
		if awakened
		else
		Color(0.045, 0.025, 0.095, 1.0)
	)

	var sky_bot: Color = (
		Color(0.30, 0.045, 0.09, 1.0)
		if awakened
		else
		Color(0.14, 0.075, 0.19, 1.0)
	)

	_draw_sky_gradient(size, sky_top, sky_bot)

	# Lua bem mais visível
	var moon_col: Color = (
		Color(1.0, 0.16, 0.20, 0.98)
		if awakened
		else
		Color(0.92, 0.90, 1.0, 1.0)
	)

	_draw_moon(
		Vector2(size.x * 0.77, size.y * 0.24),
		92.0,
		moon_col,
		awakened
	)

	# ----------------------------------------------------------
	# CASTELO
	# ----------------------------------------------------------

	var cx: float = size.x * 0.32
	var cw: float = size.x * 0.36
	var base_y: float = size.y * 0.78

	# Corpo principal
	draw_rect(
		Rect2(
			cx,
			215.0,
			cw,
			base_y - 215.0
		),
		Color(0.055, 0.045, 0.075, 1.0)
	)

	# Parte iluminada da muralha
	draw_rect(
		Rect2(
			cx + 6.0,
			225.0,
			cw - 12.0,
			base_y - 225.0
		),
		Color(0.085, 0.065, 0.11, 1.0)
	)

	# ----------------------------------------------------------
	# TORRE ESQUERDA
	# ----------------------------------------------------------

	var left_x: float = cx - 55.0
	var tower_w: float = 105.0

	draw_rect(
		Rect2(
			left_x,
			150.0,
			tower_w,
			base_y - 150.0
		),
		Color(0.065, 0.052, 0.085, 1.0)
	)

	# Iluminação lateral
	draw_rect(
		Rect2(
			left_x + 5.0,
			155.0,
			10.0,
			base_y - 155.0
		),
		Color(0.16, 0.12, 0.19, 0.75)
	)

	# Telhado
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(left_x - 18.0, 150.0),
			Vector2(left_x + tower_w * 0.5, 70.0),
			Vector2(left_x + tower_w + 18.0, 150.0)
		]),
		Color(0.045, 0.032, 0.065, 1.0)
	)

	# ----------------------------------------------------------
	# TORRE DIREITA
	# ----------------------------------------------------------

	var right_x: float = cx + cw - 50.0

	draw_rect(
		Rect2(
			right_x,
			150.0,
			tower_w,
			base_y - 150.0
		),
		Color(0.065, 0.052, 0.085, 1.0)
	)

	draw_rect(
		Rect2(
			right_x + 5.0,
			155.0,
			10.0,
			base_y - 155.0
		),
		Color(0.16, 0.12, 0.19, 0.75)
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(right_x - 18.0, 150.0),
			Vector2(right_x + tower_w * 0.5, 70.0),
			Vector2(right_x + tower_w + 18.0, 150.0)
		]),
		Color(0.045, 0.032, 0.065, 1.0)
	)

	# ----------------------------------------------------------
	# TORRES — PONTAS
	# ----------------------------------------------------------

	draw_line(
		Vector2(left_x + tower_w * 0.5, 72.0),
		Vector2(left_x + tower_w * 0.5, 35.0),
		Color(0.18, 0.14, 0.22, 0.9),
		4.0
	)

	draw_line(
		Vector2(right_x + tower_w * 0.5, 72.0),
		Vector2(right_x + tower_w * 0.5, 35.0),
		Color(0.18, 0.14, 0.22, 0.9),
		4.0
	)

	# ----------------------------------------------------------
	# MURALHA SUPERIOR
	# ----------------------------------------------------------

	draw_rect(
		Rect2(
			cx,
			205.0,
			cw,
			20.0
		),
		Color(0.13, 0.10, 0.16, 1.0)
	)

	# Parapeito
	for i in range(8):
		var bx: float = cx + 8.0 + float(i) * 43.0

		draw_rect(
			Rect2(
				bx,
				165.0,
				30.0,
				42.0
			),
			Color(0.075, 0.058, 0.10, 1.0)
		)

	# ----------------------------------------------------------
	# LINHAS DAS PEDRAS
	# ----------------------------------------------------------

	for row in range(5):
		var y: float = 250.0 + float(row) * 48.0

		draw_line(
			Vector2(cx + 12.0, y),
			Vector2(cx + cw - 12.0, y),
			Color(0.17, 0.13, 0.19, 0.32),
			2.0
		)

	# ----------------------------------------------------------
	# KEEP CENTRAL
	# ----------------------------------------------------------

	var keep_x: float = size.x * 0.42
	var keep_w: float = size.x * 0.16

	draw_rect(
		Rect2(
			keep_x,
			150.0,
			keep_w,
			base_y - 150.0
		),
		Color(0.07, 0.052, 0.095, 1.0)
	)

	# Topo do keep
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(keep_x - 20.0, 150.0),
			Vector2(keep_x + keep_w * 0.5, 70.0),
			Vector2(keep_x + keep_w + 20.0, 150.0)
		]),
		Color(0.045, 0.030, 0.065, 1.0)
	)

	# ----------------------------------------------------------
	# GRANDE JANELA DO CASTELO
	# ----------------------------------------------------------

	var win_col: Color = (
		Color(1.0, 0.08, 0.13, 1.0)
		if awakened
		else
		Color(0.62, 0.24, 0.80, 1.0)
	)

	# brilho
	draw_circle(
		Vector2(size.x * 0.50, 285.0),
		48.0,
		Color(
			win_col.r,
			win_col.g,
			win_col.b,
			0.07
		)
	)

	draw_circle(
		Vector2(size.x * 0.50, 285.0),
		32.0,
		Color(
			win_col.r,
			win_col.g,
			win_col.b,
			0.12
		)
	)

	# Moldura
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x * 0.50 - 32.0, 325.0),
			Vector2(size.x * 0.50 - 32.0, 270.0),
			Vector2(size.x * 0.50, 230.0),
			Vector2(size.x * 0.50 + 32.0, 270.0),
			Vector2(size.x * 0.50 + 32.0, 325.0)
		]),
		Color(0.14, 0.09, 0.18, 1.0)
	)

	# Vidro
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x * 0.50 - 23.0, 316.0),
			Vector2(size.x * 0.50 - 23.0, 276.0),
			Vector2(size.x * 0.50, 247.0),
			Vector2(size.x * 0.50 + 23.0, 276.0),
			Vector2(size.x * 0.50 + 23.0, 316.0)
		]),
		win_col
	)

	# Divisão da janela
	draw_line(
		Vector2(size.x * 0.50, 248.0),
		Vector2(size.x * 0.50, 316.0),
		Color(0.03, 0.015, 0.04, 0.9),
		4.0
	)

	draw_line(
		Vector2(size.x * 0.50 - 23.0, 282.0),
		Vector2(size.x * 0.50 + 23.0, 282.0),
		Color(0.03, 0.015, 0.04, 0.9),
		4.0
	)

	# ----------------------------------------------------------
	# JANELAS MENORES
	# ----------------------------------------------------------

	for wx in [
		cx + 42.0,
		cx + 95.0,
		cx + 150.0,
		cx + cw - 150.0,
		cx + cw - 95.0,
		cx + cw - 42.0
	]:
		var small_win: Color = (
			Color(0.95, 0.08, 0.12, 0.85)
			if awakened
			else
			Color(0.46, 0.20, 0.58, 0.80)
		)

		draw_rect(
			Rect2(
				wx,
				350.0,
				20.0,
				45.0
			),
			Color(0.025, 0.015, 0.035, 1.0)
		)

		draw_rect(
			Rect2(
				wx + 4.0,
				354.0,
				12.0,
				37.0
			),
			small_win
		)

	# ----------------------------------------------------------
	# ENTRADA PRINCIPAL
	# ----------------------------------------------------------

	var gate_x: float = size.x * 0.50
	var gate_top: float = 415.0

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(gate_x - 60.0, base_y),
			Vector2(gate_x - 60.0, gate_top + 35.0),
			Vector2(gate_x - 45.0, gate_top),
			Vector2(gate_x + 45.0, gate_top),
			Vector2(gate_x + 60.0, gate_top + 35.0),
			Vector2(gate_x + 60.0, base_y)
		]),
		Color(0.015, 0.008, 0.022, 1.0)
	)

	# porta
	draw_rect(
		Rect2(
			gate_x - 48.0,
			gate_top + 28.0,
			96.0,
			base_y - gate_top - 28.0
		),
		Color(0.055, 0.025, 0.065, 1.0)
	)

	# tábuas
	for gx in range(-38, 39, 19):
		draw_line(
			Vector2(gate_x + float(gx), gate_top + 32.0),
			Vector2(gate_x + float(gx), base_y),
			Color(0.15, 0.08, 0.16, 0.65),
			3.0
		)

	# barras metálicas
	for gy in [455.0, 505.0]:
		draw_line(
			Vector2(gate_x - 45.0, gy),
			Vector2(gate_x + 45.0, gy),
			Color(0.22, 0.14, 0.24, 0.80),
			5.0
		)

	# ----------------------------------------------------------
	# TOCHAS
	# ----------------------------------------------------------

	var torch_col: Color = (
		Color(1.0, 0.08, 0.10, 0.95)
		if awakened
		else
		Color(1.0, 0.45, 0.10, 0.95)
	)

	for tx in [
		gate_x - 115.0,
		gate_x + 115.0
	]:
		draw_circle(
			Vector2(tx, 430.0),
			34.0,
			Color(
				torch_col.r,
				torch_col.g,
				torch_col.b,
				0.055
			)
		)

		draw_line(
			Vector2(tx, 440.0),
			Vector2(tx, 470.0),
			Color(0.12, 0.07, 0.13, 1.0),
			5.0
		)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(tx, 420.0),
				Vector2(tx - 9.0, 405.0),
				Vector2(tx - 4.0, 385.0),
				Vector2(tx, 375.0),
				Vector2(tx + 8.0, 400.0),
				Vector2(tx + 11.0, 416.0)
			]),
			torch_col
		)

	# ----------------------------------------------------------
	# CAMINHO ATÉ O CASTELO
	# ----------------------------------------------------------

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(gate_x - 75.0, base_y),
			Vector2(gate_x + 75.0, base_y),
			Vector2(gate_x + 260.0, size.y),
			Vector2(gate_x - 260.0, size.y)
		]),
		Color(0.09, 0.075, 0.11, 1.0)
	)

	for i in range(6):
		var py: float = base_y + float(i) * 40.0
		var pw: float = 80.0 + float(i) * 30.0

		draw_line(
			Vector2(gate_x - pw, py),
			Vector2(gate_x + pw, py),
			Color(0.20, 0.17, 0.22, 0.35),
			3.0
		)

	# ----------------------------------------------------------
	# NÉVOA
	# ----------------------------------------------------------

	var fog_col: Color = (
		Color(0.85, 0.12, 0.18, 0.045)
		if awakened
		else
		Color(0.65, 0.58, 0.82, 0.055)
	)

	for i in range(7):
		var fx: float = (
			fmod(
				_elapsed * (7.0 + float(i)),
				size.x + 300.0
			)
			- 150.0
		)

		var fy: float = (
			size.y * 0.70
			+ sin(_elapsed * 0.35 + float(i)) * 18.0
		)

		draw_circle(
			Vector2(fx, fy),
			40.0 + float(i % 3) * 18.0,
			fog_col
		)

	# ----------------------------------------------------------
	# CASTELO DESPERTADO
	# ----------------------------------------------------------

	if awakened:
		var pulse: float = (
			0.5
			+ sin(_elapsed * 3.0) * 0.5
		)

		draw_circle(
			Vector2(size.x * 0.50, 300.0),
			90.0 + pulse * 8.0,
			Color(
				1.0,
				0.02,
				0.05,
				0.035
			)
		)

	# ----------------------------------------------------------
	# CHÃO
	# ----------------------------------------------------------

	_draw_ground(size)


# ==============================================================================
# CENAS 4, 5 E 6 REFORMULADAS (ILUMINAÇÃO E VISIBILIDADE)
# ==============================================================================

func _draw_dracula_wakeup_scene(size: Vector2) -> void:
	# 1. AMBIENTE DA CRIPTA (Interior escuro e profundo)
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.015, 0.025)) # Fundo quase preto

	# Pilastras góticas ao fundo (para dar profundidade)
	var wall_color: Color = Color(0.04, 0.03, 0.05)
	for i in range(4):
		var px: float = size.x * 0.1 + i * 250.0
		draw_rect(Rect2(px, 0, 80, size.y), wall_color)
		# Arcos das pilastras
		draw_circle(Vector2(px + 40, 100), 120, Color(0.02, 0.015, 0.025))

	# 2. TOCHAS NA PAREDE (Iluminação quente tremeluzente)
	var flicker: float = sin(_elapsed * 12.0) * 0.1 + sin(_elapsed * 25.0) * 0.05
	for tx in [size.x * 0.2, size.x * 0.8]:
		var torch_pos: Vector2 = Vector2(tx, size.y * 0.3)
		# Suporte de ferro
		draw_rect(Rect2(torch_pos.x - 5, torch_pos.y, 10, 30), Color(0.1, 0.1, 0.1))
		# Fogo e brilho
		draw_circle(torch_pos + Vector2(0, -10), 15 + flicker * 20, Color(1.0, 0.6, 0.1, 0.8))
		draw_circle(torch_pos + Vector2(0, -10), 80, Color(1.0, 0.4, 0.0, 0.15 + flicker * 0.1))

	# 3. CHÃO DA CRIPTA
	var floor_y: float = size.y * 0.85
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color(0.03, 0.02, 0.04))
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color(0.1, 0.05, 0.08), 8)

	# 4. O SARCÓFAGO (Visto de lado)
	var coffin_x: float = size.x * 0.15
	var coffin_y: float = floor_y - 140
	var coffin_w: float = size.x * 0.6
	var coffin_h: float = 140
	var stone_color: Color = Color(0.08, 0.07, 0.09)
	var dark_stone: Color = Color(0.04, 0.03, 0.05)

	# Base pesada do sarcófago
	draw_rect(Rect2(coffin_x, coffin_y, coffin_w, coffin_h), stone_color)
	draw_rect(Rect2(coffin_x - 10, coffin_y + coffin_h - 20, coffin_w + 20, 20), dark_stone) # Rodapé
	draw_rect(Rect2(coffin_x - 10, coffin_y, coffin_w + 20, 15), dark_stone) # Borda superior

	# Ranhuras e decorações góticas no sarcófago
	for i in range(4):
		var dec_x: float = coffin_x + 60 + i * 150
		draw_rect(Rect2(dec_x, coffin_y + 30, 40, 80), dark_stone)
		draw_circle(Vector2(dec_x + 20, coffin_y + 30), 20, dark_stone) # Topo arredondado da decoração

	# Tampa do sarcófago (Inclinada e empurrada para a direita)
	var lid_color: Color = Color(0.06, 0.05, 0.07)
	draw_colored_polygon(PackedVector2Array([
		Vector2(coffin_x + 150, coffin_y - 15), # Ponto superior esquerdo
		Vector2(coffin_x + 180 + coffin_w, coffin_y + 120), # Ponto inferior direito (no chão)
		Vector2(coffin_x + 180 + coffin_w, coffin_y + 145), # Espessura direita
		Vector2(coffin_x + 150, coffin_y + 10) # Espessura esquerda
	]), lid_color)

	# 5. LUZ PROFANA (Brilho vermelho saindo da tumba)
	var glow_x: float = coffin_x + 100
	var magic_pulse: float = sin(_elapsed * 4.0) * 0.2 + 0.8
	draw_circle(Vector2(glow_x, coffin_y), 150, Color(0.8, 0.0, 0.1, 0.2 * magic_pulse))
	draw_circle(Vector2(glow_x, coffin_y), 70, Color(1.0, 0.0, 0.2, 0.4 * magic_pulse))

	# Névoa/Fumaça vermelha subindo
	for i in range(5):
		var smoke_y: float = coffin_y - (fmod(_elapsed * 30.0 + i * 40.0, 200.0))
		var smoke_x: float = glow_x - 20 + sin(smoke_y * 0.05) * 30.0
		var smoke_alpha: float = clamp(1.0 - (coffin_y - smoke_y) / 200.0, 0.0, 1.0)
		draw_circle(Vector2(smoke_x, smoke_y), 25 + i * 5.0, Color(0.7, 0.0, 0.1, 0.1 * smoke_alpha))

	# 6. O DRÁCULA (Silhueta lateral se erguendo)
	var cx: float = coffin_x + 80
	var cy: float = coffin_y + 20
	var sil: Color = Color(0.005, 0.005, 0.01) # Preto total para a silhueta
	var rim: Color = Color(1.0, 0.2, 0.3, 0.9) # Luz de contorno vermelha infernal

	# Respiração/Animação lenta de erguer-se
	var breath: float = sin(_elapsed * 2.0) * 3.0
	cy += breath

	# Corpo inclinado para frente (saindo da tumba)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 30, cy + 50), # Cintura/Fundo
		Vector2(cx + 60, cy + 30), # Peito
		Vector2(cx + 80, cy - 80), # Ombro
		Vector2(cx - 10, cy - 80)  # Costas
	]), sil)

	# Braço esquerdo se apoiando na borda do sarcófago
	# Ombro até cotovelo
	draw_line(Vector2(cx + 40, cy - 60), Vector2(cx + 110, cy - 20), sil, 20)
	# Cotovelo até a mão segurando a borda
	draw_line(Vector2(cx + 110, cy - 20), Vector2(cx + 140, coffin_y - 5), sil, 16)
	
	# Garras longas agarrando a pedra
	draw_line(Vector2(cx + 140, coffin_y - 5), Vector2(cx + 130, coffin_y + 20), sil, 4)
	draw_line(Vector2(cx + 145, coffin_y - 5), Vector2(cx + 140, coffin_y + 22), sil, 4)
	draw_line(Vector2(cx + 150, coffin_y - 5), Vector2(cx + 150, coffin_y + 18), sil, 4)

	# A Gola Alta Clássica do Vampiro (Emoldurando a nuca)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 5, cy - 70),  # Base do pescoço
		Vector2(cx - 40, cy - 160), # Ponta alta da gola (atrás)
		Vector2(cx + 20, cy - 140), # Lateral direita da gola
		Vector2(cx + 40, cy - 80)   # Frente do pescoço
	]), sil)

	# Cabeça de perfil
	# Pescoço e crânio
	draw_circle(Vector2(cx + 45, cy - 110), 22, sil)
	# Maxilar e queixo pontudo
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 40, cy - 95), Vector2(cx + 70, cy - 100), Vector2(cx + 65, cy - 120)
	]), sil)
	# Nariz aquilino/afiado
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 60, cy - 130), Vector2(cx + 80, cy - 115), Vector2(cx + 60, cy - 105)
	]), sil)
	# Cabelo liso penteado para trás caindo pela gola
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 45, cy - 130), Vector2(cx - 10, cy - 110),
		Vector2(cx - 20, cy - 70), Vector2(cx + 20, cy - 100)
	]), sil)

	# Olho brilhante demoníaco (Um único ponto de luz letal)
	draw_circle(Vector2(cx + 62, cy - 118), 3, Color(1.0, 0.0, 0.1))
	draw_line(Vector2(cx + 60, cy - 118), Vector2(cx + 68, cy - 116), Color(1.0, 0.2, 0.2, 0.8), 2)

	# 7. LUZ DE RECORTE (Rim Light) - O detalhe que dá vida ao 2D
	# O vermelho da tumba reflete de baixo para cima no rosto e garras do vampiro

	# Recorte no nariz, testa e queixo (Underlighting)
	draw_polyline(PackedVector2Array([
		Vector2(cx + 70, cy - 100), # Queixo
		Vector2(cx + 80, cy - 115), # Ponta do Nariz
		Vector2(cx + 60, cy - 130), # Testa
		Vector2(cx + 45, cy - 132)  # Topo da cabeça
	]), rim, 1.5)

	# Recorte no braço e mão agarrando a borda
	draw_polyline(PackedVector2Array([
		Vector2(cx + 110, cy - 15), Vector2(cx + 140, coffin_y - 2), Vector2(cx + 152, coffin_y - 2)
	]), rim, 2.0)
	
	# Recorte por dentro da icônica gola alta
	draw_line(Vector2(cx + 20, cy - 140), Vector2(cx - 40, cy - 160), Color(0.5, 0.0, 0.1, 0.8), 2.0)

func _draw_scene_6_dracula_throne(size: Vector2) -> void:
	# 1. CÉU NOTURNO E LUA DE SANGUE (Fundo)
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.04, 0.01, 0.02)) # Céu escuro avermelhado
	
	var center_x: float = size.x * 0.5
	var moon_y: float = size.y * 0.35
	
	# Brilho da lua (várias camadas para dar efeito de luz intensa)
	draw_circle(Vector2(center_x, moon_y), 180, Color(0.8, 0.1, 0.1, 0.1))
	draw_circle(Vector2(center_x, moon_y), 120, Color(1.0, 0.2, 0.2, 0.2))
	# Lua de sangue em si
	draw_circle(Vector2(center_x, moon_y), 80, Color(0.9, 0.1, 0.15))

	# 2. MORCEGOS VOANDO AO FUNDO (Atmosfera dinâmica)
	for i in range(6):
		# Movimento circular/senoidal atravessando a lua
		var bat_x: float = center_x - 150 + fmod(_elapsed * 40.0 + i * 60.0, 300.0)
		var bat_y: float = moon_y - 40 + sin(_elapsed * 2.0 + i) * 30.0 + i * 15.0
		var flap: float = sin(_elapsed * 15.0 + i) * 8.0 # Batida das asas
		var bat_color = Color(0.02, 0.01, 0.01) # Silhueta preta
		
		draw_polyline(PackedVector2Array([
			Vector2(bat_x - 12, bat_y - flap), # Ponta da asa esquerda
			Vector2(bat_x, bat_y),             # Corpo
			Vector2(bat_x + 12, bat_y - flap)  # Ponta da asa direita
		]), bat_color, 2.5)

	# 3. ARQUITETURA DO CASTELO (Janela Gótica Gigante em Silhueta)
	var stone: Color = Color(0.01, 0.005, 0.01) # Quase breu
	var arch_width: float = size.x * 0.35
	
	# Paredes laterais bloqueando o céu
	draw_rect(Rect2(0, 0, center_x - arch_width, size.y), stone)
	draw_rect(Rect2(center_x + arch_width, 0, size.x - (center_x + arch_width), size.y), stone)
	
	# Topo da janela (Arco gótico pontiagudo)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0),
		Vector2(center_x + arch_width, 100),
		Vector2(center_x, 30), # Ponta do arco no centro
		Vector2(center_x - arch_width, 100)
	]), stone)

	# 4. CHÃO E TAPETE DO SALÃO
	var floor_y: float = size.y * 0.85
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color(0.03, 0.01, 0.015))
	
	# Tapete vermelho longo em perspectiva
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - arch_width * 0.6, floor_y), 
		Vector2(center_x + arch_width * 0.6, floor_y),
		Vector2(center_x + arch_width * 1.2, size.y), 
		Vector2(center_x - arch_width * 1.2, size.y)
	]), Color(0.3, 0.02, 0.05)) # Vermelho veludo escuro
	
	# Bordas douradas envelhecidas do tapete
	draw_line(Vector2(center_x - arch_width * 0.6, floor_y), Vector2(center_x - arch_width * 1.2, size.y), Color(0.6, 0.4, 0.1, 0.5), 6)
	draw_line(Vector2(center_x + arch_width * 0.6, floor_y), Vector2(center_x + arch_width * 1.2, size.y), Color(0.6, 0.4, 0.1, 0.5), 6)

	# 5. O DRÁCULA (Design Majestoso Levitando)
	# Animação de levitação suave
	var float_y: float = sin(_elapsed * 2.5) * 12.0
	var dx: float = center_x
	var dy: float = size.y * 0.55 + float_y
	var sil: Color = Color(0.0, 0.0, 0.0) # Preto absoluto para destaque
	var rim: Color = Color(1.0, 0.3, 0.3, 0.9) # Luz da lua de sangue rebatendo nele

	# A Capa Gigante (Asas de Morcego)
	var cape_spread = 20 + sin(_elapsed * 1.5) * 10 # Capa respirando/movendo
	draw_colored_polygon(PackedVector2Array([
		Vector2(dx, dy + 160), # Ponta inferior da capa
		Vector2(dx - 60, dy + 130), Vector2(dx - 120, dy + 160), # Recortes esquerdos inferiores
		Vector2(dx - 160 - cape_spread, dy + 30), Vector2(dx - 220 - cape_spread, dy - 50), # Expansão esquerda
		Vector2(dx - 150, dy - 130), # Ponta alta do ombro esquerdo
		Vector2(dx - 40, dy - 70), # Gola esquerda
		Vector2(dx + 40, dy - 70), # Gola direita
		Vector2(dx + 150, dy - 130), # Ponta alta do ombro direito
		Vector2(dx + 220 + cape_spread, dy - 50), Vector2(dx + 160 + cape_spread, dy + 30), # Expansão direita
		Vector2(dx + 120, dy + 160), Vector2(dx + 60, dy + 130)  # Recortes direitos inferiores
	]), sil)

	# Corpo do Drácula (Terno/Armadura Slim e Elegante)
	# Tronco
	draw_colored_polygon(PackedVector2Array([
		Vector2(dx - 30, dy - 60), Vector2(dx + 30, dy - 60), # Ombros
		Vector2(dx + 15, dy + 20), Vector2(dx - 15, dy + 20)  # Cintura fina
	]), sil)
	# Pernas esticadas levitando
	draw_colored_polygon(PackedVector2Array([
		Vector2(dx - 15, dy + 20), Vector2(dx + 15, dy + 20), 
		Vector2(dx + 8, dy + 140), Vector2(dx - 8, dy + 140)
	]), sil)

	# Braços abertos conjurando poder
	draw_line(Vector2(dx - 30, dy - 50), Vector2(dx - 100, dy - 20), sil, 14) # Braço esquerdo
	draw_line(Vector2(dx + 30, dy - 50), Vector2(dx + 100, dy - 20), sil, 14) # Braço direito

	# Gola, Cabeça e Cabelo
	# Gola V gigante
	draw_colored_polygon(PackedVector2Array([
		Vector2(dx, dy - 60), Vector2(dx - 40, dy - 120), Vector2(dx + 40, dy - 120)
	]), sil)
	# Cabeça e queixo erguido de forma arrogante
	draw_circle(Vector2(dx, dy - 100), 16, sil)
	# Cabelo esvoaçante longo
	draw_colored_polygon(PackedVector2Array([
		Vector2(dx - 15, dy - 110), Vector2(dx + 15, dy - 110),
		Vector2(dx + 25 + cape_spread * 0.5, dy - 60), Vector2(dx - 25 - cape_spread * 0.5, dy - 60)
	]), sil)

	# 6. MAGIA DE SANGUE (Poder nas mãos)
	var magic_pulse = 0.5 + sin(_elapsed * 10.0) * 0.5
	var hand_l = Vector2(dx - 110, dy - 15)
	var hand_r = Vector2(dx + 110, dy - 15)
	
	for hand in [hand_l, hand_r]:
		draw_circle(hand, 30 + magic_pulse * 10, Color(0.9, 0.0, 0.1, 0.2)) # Aura
		draw_circle(hand, 15 + magic_pulse * 5, Color(1.0, 0.2, 0.3, 0.6)) # Núcleo
		# Fios de sangue circulando a mão
		draw_line(hand + Vector2(-15, 10), hand + Vector2(15, -10 + magic_pulse * 10), Color(1.0, 0.5, 0.5, 0.8), 2)
		draw_line(hand + Vector2(-10, -15), hand + Vector2(10, 15 - magic_pulse * 10), Color(1.0, 0.5, 0.5, 0.8), 2)

	# 7. RIM LIGHTING MÁXIMO (A luz da lua contornando o monstro)
	# Contorno superior da capa e ombros (mostra o volume do Drácula)
	draw_polyline(PackedVector2Array([
		Vector2(dx - 220 - cape_spread, dy - 50),
		Vector2(dx - 150, dy - 130),
		Vector2(dx - 40, dy - 70)
	]), rim, 2.5)
	
	draw_polyline(PackedVector2Array([
		Vector2(dx + 40, dy - 70),
		Vector2(dx + 150, dy - 130),
		Vector2(dx + 220 + cape_spread, dy - 50)
	]), rim, 2.5)

	# Contorno na cabeça e cabelo (brilho prateado/avermelhado)
	draw_polyline(PackedVector2Array([
		Vector2(dx - 12, dy - 110), Vector2(dx, dy - 116), Vector2(dx + 12, dy - 110)
	]), rim, 2.0)


func _draw_hunter_scene(size: Vector2) -> void:
	# 1. CÉU E AMBIENTE BASE (Noite chuvosa e profunda)
	_draw_sky_gradient(size, Color(0.03, 0.04, 0.08), Color(0.12, 0.14, 0.20))
	
	# Lua imponente à direita, servindo de luz de recorte (Backlight)
	var moon_pos: Vector2 = Vector2(size.x * 0.85, size.y * 0.25)
	_draw_moon(moon_pos, 110.0, Color(0.85, 0.88, 0.95), false)

	var ground_y: float = size.y * 0.80

	# 2. VILAREJO (Midground - Casas e Portão)
	# Silhuetas de casas do vilarejo ao fundo
	for i in range(5):
		var bx: float = size.x * 0.2 + i * 180.0
		var by: float = ground_y - 150.0 + (i % 3) * 20.0
		
		# Corpo da casa de pedra/madeira
		draw_rect(Rect2(bx, by, 120, 150), Color(0.05, 0.06, 0.09))
		# Telhado gótico pontiagudo
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 15, by), Vector2(bx + 60, by - 90), Vector2(bx + 135, by)
		]), Color(0.03, 0.04, 0.06))
		
		# Janelas iluminadas (dá a sensação de que há sobreviventes escondidos)
		if i % 2 != 0:
			var wx: float = bx + 45
			var wy: float = by + 50
			var window_glow: float = 0.7 + sin(_elapsed * 4.0 + float(i)) * 0.3
			draw_rect(Rect2(wx, wy, 30, 40), Color(0.9, 0.5, 0.1, 0.2 * window_glow))
			draw_rect(Rect2(wx + 5, wy + 5, 20, 30), Color(1.0, 0.7, 0.2, 0.9 * window_glow))

	# Portão Gótico Principal da Vila
	var gate_color: Color = Color(0.02, 0.02, 0.04)
	var g_left: float = size.x * 0.15
	var g_right: float = size.x * 0.65
	
	# Pilares esquerdo e direito do portão
	draw_rect(Rect2(g_left, ground_y - 300, 60, 300), gate_color)
	draw_rect(Rect2(g_right, ground_y - 300, 60, 300), gate_color)
	
	# Arcos de pedra em ruínas formando a entrada
	draw_line(Vector2(g_left + 30, ground_y - 280), Vector2(size.x * 0.4, ground_y - 380), gate_color, 40)
	draw_line(Vector2(g_right + 30, ground_y - 280), Vector2(size.x * 0.4, ground_y - 380), gate_color, 40)

	# Lampião pendurado no portão
	var lantern_pos: Vector2 = Vector2(g_left + 60, ground_y - 180)
	draw_line(Vector2(g_left + 30, ground_y - 220), lantern_pos, gate_color, 4) # Corrente
	draw_rect(Rect2(lantern_pos.x - 10, lantern_pos.y, 20, 30), gate_color) # Estrutura do lampião
	draw_rect(Rect2(lantern_pos.x - 6, lantern_pos.y + 5, 12, 20), Color(1.0, 0.6, 0.1, 0.9 + sin(_elapsed * 10) * 0.1)) # Fogo
	draw_circle(lantern_pos + Vector2(0, 15), 60, Color(1.0, 0.5, 0.1, 0.15)) # Brilho do lampião

	# 3. CHÃO REFLEXIVO
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), Color(0.04, 0.05, 0.07))
	# Reflexo pálido da lua no chão molhado de chuva
	draw_rect(Rect2(moon_pos.x - 40, ground_y, 80, size.y - ground_y), Color(0.5, 0.6, 0.8, 0.1))
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Color(0.1, 0.12, 0.18), 3)

	# 4. O CAÇADOR (Silhueta detalhada em primeiro plano)
	var cx: float = size.x * 0.38
	var cy: float = ground_y + 40
	var sil: Color = Color(0.005, 0.005, 0.01) # Quase preto puro
	var rim: Color = Color(0.8, 0.85, 1.0, 0.95) # Luz lunar brilhante nas bordas

	# Animação de caminhada e vento balançando as roupas
	var walk_bob: float = sin(_elapsed * 6.0) * 4.0
	var wind: float = sin(_elapsed * 2.5) * 20.0
	cy += walk_bob

	# Capote (Casaco Longo Esvoaçante ao Vento)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 30, cy - 180), # Ombro esquerdo
		Vector2(cx + 40, cy - 180), # Ombro direito
		Vector2(cx + 60 + wind * 0.5, cy - 30), # Barra da frente
		Vector2(cx + 20 + wind, cy + 10), # Meio do casaco
		Vector2(cx - 85 + wind * 1.5, cy - 10)  # Barra de trás voando
	]), sil)

	# Pernas com botas dando um passo
	# Perna de trás (Esquerda)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 20, cy - 80), Vector2(cx, cy - 80),
		Vector2(cx - 10, cy), Vector2(cx - 35, cy)
	]), sil)
	# Perna da frente (Direita)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 10, cy - 80), Vector2(cx + 35, cy - 80),
		Vector2(cx + 45, cy + 15), Vector2(cx + 15, cy + 15)
	]), sil)

	# Braço esquerdo solto
	draw_line(Vector2(cx - 20, cy - 170), Vector2(cx - 40, cy - 90), sil, 22)

	# Braço direito levantando a arma
	draw_line(Vector2(cx + 30, cy - 170), Vector2(cx + 90, cy - 130), sil, 24)

	# Arma: Escopeta Gótica / Lançador Duplo
	var gun_p1: Vector2 = Vector2(cx + 70, cy - 140)
	var gun_p2: Vector2 = Vector2(cx + 200, cy - 155)
	
	# Coronha pesada
	draw_line(gun_p1, gun_p1 + Vector2(50, -5), sil, 24)
	# Cano duplo
	draw_line(gun_p1 + Vector2(40, -5), gun_p2, sil, 14)
	draw_line(gun_p1 + Vector2(40, -12), gun_p2 + Vector2(0, -7), sil, 8)
	
	# Núcleo de energia / Magia na arma (Pulsante)
	var core_pos: Vector2 = gun_p1 + Vector2(65, -8)
	var weapon_glow: float = 0.5 + sin(_elapsed * 15.0) * 0.5
	draw_circle(core_pos, 8 + weapon_glow * 6, Color(0.2, 0.6, 1.0, 0.3))
	draw_circle(core_pos, 4, Color(0.6, 0.9, 1.0, 1.0))
	
	# Fumaça escapando do cano
	draw_circle(gun_p2 + Vector2(10, -10 + wind * 0.2), 8, Color(0.6, 0.7, 0.8, 0.2))

	# Chapéu de Caçador (Estilo Van Helsing)
	# Gola erguida cobrindo o pescoço
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 25, cy - 180), Vector2(cx + 35, cy - 180),
		Vector2(cx + 25, cy - 210), Vector2(cx - 15, cy - 210)
	]), sil)
	
	# Cabeça na sombra profunda
	draw_circle(Vector2(cx + 5, cy - 215), 18, sil)
	
	# Reflexo assassino (olho brilhante azul sob o chapéu)
	draw_line(Vector2(cx + 10, cy - 215), Vector2(cx + 18, cy - 212), Color(0.4, 0.8, 1.0, 0.9), 2)

	# Aba curva do chapéu
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 55, cy - 215), Vector2(cx - 30, cy - 235),
		Vector2(cx + 35, cy - 235), Vector2(cx + 70, cy - 210)
	]), sil)
	# Topo do chapéu
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 25, cy - 230), Vector2(cx - 15, cy - 265),
		Vector2(cx + 15, cy - 265), Vector2(cx + 25, cy - 230)
	]), sil)

	# 5. CONTORNOS DE LUZ (Rim Lighting - Deixa a silhueta tridimensional)
	# Luz pegando na aba direita do chapéu
	draw_polyline(PackedVector2Array([
		Vector2(cx - 30, cy - 235), Vector2(cx + 35, cy - 235), Vector2(cx + 70, cy - 210)
	]), rim, 2.5)
	# Luz refletindo no ombro direito e costas do casaco
	draw_polyline(PackedVector2Array([
		Vector2(cx + 35, cy - 180), Vector2(cx + 60 + wind * 0.5, cy - 30)
	]), rim, 2.0)
	# Reflexo prateado no topo do cano da arma
	draw_line(gun_p1 + Vector2(40, -16), gun_p2 + Vector2(0, -11), rim, 2.0)

	# 6. EFEITOS CLIMÁTICOS FINAIS
	_draw_fog_layer(size, 0.7)
	_draw_rain(size)
	
func _draw_wolf_eye_scene(size: Vector2) -> void:
	# 1. AMBIENTE DA FLORESTA NEGRA (Escuridão quase total)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.02))

	var eye_open: float = clampf((_elapsed - 0.8) / 1.5, 0.0, 1.0)
	var is_fully_awake: bool = eye_open > 0.8
	
	# Respiração profunda e Tremor do Rosnado (ativa quando o olho abre)
	var breath: float = sin(_elapsed * 3.0) * 5.0
	var growl_shake: Vector2 = Vector2(sin(_elapsed * 45.0) * 1.5, cos(_elapsed * 35.0) * 1.5) if is_fully_awake else Vector2.ZERO
	
	var center: Vector2 = Vector2(size.x * 0.50, size.y * 0.46) + Vector2(0, breath) + growl_shake
	var sil: Color = Color(0.002, 0.003, 0.005) # Cor da pele/pelagem (Quase breu)

	# 2. SILHUETA DA CABEÇA DO LOBO (Feroz, orelhas para trás e pelos espetados)
	var head_points = PackedVector2Array([
		center + Vector2(0, -260),      # Topo da cabeça
		center + Vector2(120, -220),    # Base da orelha dir
		center + Vector2(220, -100),    # Orelha dir abaixada (agressividade)
		center + Vector2(170, -40),     # Curva interna
		center + Vector2(280, 40),      # Bochecha peluda dir sup
		center + Vector2(230, 90), 
		center + Vector2(260, 170),     # Bochecha peluda dir inf
		center + Vector2(130, 240),     # Mandíbula dir
		center + Vector2(80, 280),      # Focinho dir
		center + Vector2(-80, 280),     # Focinho esq
		center + Vector2(-130, 240),    # Mandíbula esq
		center + Vector2(-260, 170),    # Bochecha peluda esq inf
		center + Vector2(-230, 90),
		center + Vector2(-280, 40),     # Bochecha peluda esq sup
		center + Vector2(-170, -40),    # Curva interna
		center + Vector2(-220, -100),   # Orelha esq abaixada
		center + Vector2(-120, -220)    # Base da orelha esq
	])
	draw_colored_polygon(head_points, sil)
	
	# Pelos soltos no topo da cabeça para quebrar a geometria perfeita
	draw_line(center + Vector2(-80, -250), center + Vector2(-110, -310), sil, 12)
	draw_line(center + Vector2(60, -255), center + Vector2(100, -320), sil, 15)

	# 3. OS OLHOS DO PREDADOR
	if eye_open > 0.0:
		for side in [-1.0, 1.0]: # -1.0 = Esquerdo, 1.0 = Direito
			var e_pos: Vector2 = center + Vector2(side * 110.0, -50.0)
			
			# A. BRILHO EXTERNO (Luz rebatendo na pelagem do rosto)
			var pulse: float = sin(_elapsed * 12.0) * 6.0 * eye_open
			draw_circle(e_pos, 80.0 * eye_open + pulse, Color(0.8, 0.1, 0.0, 0.06)) # Vermelho espalhado
			draw_circle(e_pos, 50.0 * eye_open, Color(1.0, 0.4, 0.0, 0.15)) # Laranja
			
			# B. GLOBO OCULAR BASE
			var eye_radius = 28.0 * eye_open
			draw_circle(e_pos, eye_radius, Color(1.0, 0.7, 0.0, 1.0)) # Laranja vibrante
			draw_circle(e_pos, eye_radius * 0.6, Color(1.0, 0.95, 0.3, 1.0)) # Centro amarelo vivo
			
			# C. PUPILA FENDIDA (Estilo réptil/lobo)
			var pupil_w: float = 4.0 * eye_open
			var pupil_h: float = 24.0 * eye_open
			draw_colored_polygon(PackedVector2Array([
				e_pos + Vector2(0, -pupil_h), e_pos + Vector2(pupil_w, 0),
				e_pos + Vector2(0, pupil_h), e_pos + Vector2(-pupil_w, 0)
			]), Color(0.05, 0.0, 0.0))
			
			# D. "ESCULPINDO" A RAIVA (Usando as pálpebras/sobrancelhas)
			# Calculamos a direção baseada no lado (-1 ou 1) para fazer as sobrancelhas \ /
			var inner_x: float = side * -35.0 # Canto do olho perto do nariz
			var outer_x: float = side * 45.0  # Canto do olho perto da orelha
			
			# Sobrancelha superior (Abaixa no centro, sobe na lateral)
			draw_line(e_pos + Vector2(outer_x, -35), e_pos + Vector2(inner_x, 5), sil, 30.0)
			
			# Pálpebra inferior / Bochecha (Corta o olho por baixo)
			draw_line(e_pos + Vector2(outer_x, 28), e_pos + Vector2(inner_x, 15), sil, 18.0)
			
			# Reflexo molhado no olho (Catchlight)
			draw_circle(e_pos + Vector2(side * 8.0, -10.0 * eye_open), 4.0 * eye_open, Color(1.0, 1.0, 1.0, 0.7))

	# 4. FOCINHO, PRESAS E BABA (Revelados apenas quando o olho está bem aberto)
	if eye_open > 0.6:
		var snout_y: float = 120.0
		var reveal_alpha: float = (eye_open - 0.6) * 2.5 # Vai de 0 a 1 rápido no final
		
		# Rugas do focinho rosnando (Pegam o reflexo da luz do olho)
		draw_line(center + Vector2(-40, snout_y - 20), center + Vector2(40, snout_y - 20), Color(0.3, 0.15, 0.0, 0.4 * reveal_alpha), 6)
		draw_line(center + Vector2(-25, snout_y - 5), center + Vector2(25, snout_y - 5), Color(0.3, 0.15, 0.0, 0.3 * reveal_alpha), 4)

		# Presas Brilhantes
		for side in [-1.0, 1.0]:
			var fang_pos: Vector2 = center + Vector2(side * 50.0, snout_y + 70.0)
			
			# A Presa em si
			draw_colored_polygon(PackedVector2Array([
				fang_pos + Vector2(-12, 0), fang_pos + Vector2(12, 0), fang_pos + Vector2(side * 5, 55)
			]), Color(0.8, 0.8, 0.75, 0.5 * reveal_alpha))
			
			# Brilho afiado na ponta da presa
			draw_line(fang_pos + Vector2(side * 5, 50), fang_pos + Vector2(side * 2, 10), Color(1.0, 1.0, 1.0, 0.4 * reveal_alpha), 2)
			
			# 5. SALIVA / BABA (Animação contínua pingando da boca)
			# Usamos tempos diferentes para a baba esquerda e direita não ficarem iguais
			var drool_time = _elapsed * (80.0 if side == -1.0 else 110.0)
			var drop_y = fmod(drool_time, 120.0)
			var drool_x = fang_pos.x + (side * 2.0)
			
			# Fio da saliva esticando e o pingo na ponta
			if drop_y < 100:
				draw_line(Vector2(drool_x, fang_pos.y + 20), Vector2(drool_x, fang_pos.y + 20 + drop_y), Color(0.7, 0.9, 1.0, 0.2 * reveal_alpha), 2)
				draw_circle(Vector2(drool_x, fang_pos.y + 20 + drop_y), 3.5, Color(0.8, 0.95, 1.0, 0.4 * reveal_alpha))

func _draw_controls_scene(size: Vector2) -> void:
	_draw_sky_gradient(size, Color(0.02, 0.01, 0.04), Color(0.06, 0.03, 0.09))

	var title_pos: Vector2 = Vector2(size.x * 0.5, size.y * 0.13)
	draw_string(ThemeDB.fallback_font, title_pos - Vector2(190, 0), "GUIAS DE SOBREVIVÊNCIA", HORIZONTAL_ALIGNMENT_CENTER, 380, 36, Color(0.9, 0.8, 1.0))

	var card_bg: Color = Color(0.06, 0.04, 0.10, 0.92)
	var card_border: Color = Color(0.45, 0.25, 0.60, 0.8)

	_draw_control_card(Rect2(size.x * 0.12, size.y * 0.24, size.x * 0.35, size.y * 0.32), "MOVIMENTAÇÃO", "WASD — Mover / Esquivar\nESPAÇO — Ataque Corpo a Corpo", card_bg, card_border)
	_draw_control_card(Rect2(size.x * 0.53, size.y * 0.24, size.x * 0.35, size.y * 0.32), "COMBATE", "MOUSE — Mirar Arma\nCLIQUE ESQ. — Atirar\nRECARGA - ESPERE ALGUNS SEGUNDOS PARA VOLTAR DISPARAR", card_bg, card_border)
	_draw_control_card(Rect2(size.x * 0.12, size.y * 0.60, size.x * 0.76, size.y * 0.18), "OBJETIVO", "Q — Interagir com Objetos   |   Sobreviva à noite, invada o castelo e destrua o Drácula.", card_bg, Color(0.8, 0.2, 0.3, 0.9))


func _draw_final_scene(size: Vector2) -> void:
	_draw_castle_scene(size, true)
	_draw_particles(size, 40, Color(1.0, 0.3, 0.1, 0.6), -80.0)


func _draw_sky_gradient(size: Vector2, top_color: Color, bottom_color: Color) -> void:
	var steps: int = 16
	var h: float = size.y / float(steps)
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var c: Color = top_color.lerp(bottom_color, t)
		draw_rect(Rect2(0, float(i) * h, size.x, h + 1.0), c)


func _draw_moon(pos: Vector2, radius: float, color: Color, is_blood: bool) -> void:
	draw_circle(pos, radius * 1.4, Color(color.r, color.g, color.b, 0.15))
	draw_circle(pos, radius * 1.15, Color(color.r, color.g, color.b, 0.25))
	draw_circle(pos, radius, color)

	var crater_col: Color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.4)
	draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.2), radius * 0.22, crater_col)
	draw_circle(pos + Vector2(radius * 0.2, radius * 0.3), radius * 0.18, crater_col)


func _draw_stars(size: Vector2) -> void:
	for i in range(35):
		var x: float = fmod(float(i * 157), size.x)
		var y: float = fmod(float(i * 83), size.y * 0.48)
		var twinkle: float = 0.3 + sin(_elapsed * 3.0 + float(i)) * 0.2
		draw_circle(Vector2(x, y), 1.8, Color(0.8, 0.8, 1.0, twinkle))


func _draw_forest_silhouette(size: Vector2, color: Color) -> void:
	for i in range(14):
		var x: float = float(i) * (size.x / 13.0)
		var w: float = 60.0
		var h: float = 140.0 + float((i * 11) % 50)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, size.y * 0.78),
			Vector2(x, size.y * 0.78 - h),
			Vector2(x + w * 0.5, size.y * 0.78)
		]), color)


func _draw_mountains(size: Vector2, color: Color, height_factor: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, size.y))
	for i in range(8):
		var x: float = float(i) * (size.x / 7.0)
		var y: float = size.y * height_factor - float((i * 37) % 80)
		points.append(Vector2(x, y))
	points.append(Vector2(size.x, size.y))
	draw_colored_polygon(points, color)


func _draw_ground(size: Vector2) -> void:
	var gy: float = size.y * 0.76
	draw_rect(Rect2(0, gy, size.x, size.y - gy), Color(0.02, 0.015, 0.03))
	draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.18, 0.12, 0.25), 3)


func _draw_fog_layer(size: Vector2, alpha: float) -> void:
	var fy: float = size.y * 0.68
	var fog_color: Color = Color(0.15, 0.12, 0.22, alpha * 0.3)
	draw_rect(Rect2(0, fy, size.x, size.y * 0.15), fog_color)


func _draw_particles(size: Vector2, count: int, color: Color, speed_y: float) -> void:
	for i in range(count):
		var px: float = fmod(float(i * 97) + sin(_elapsed + float(i)) * 40.0, size.x)
		var py: float = fmod(size.y + fmod(_elapsed * speed_y + float(i * 53), size.y), size.y)
		draw_circle(Vector2(px, py), 2.0, color)


func _draw_rain(size: Vector2) -> void:
	for i in range(40):
		var rx: float = fmod(float(i * 73) + _elapsed * 200.0, size.x)
		var ry: float = fmod(float(i * 41) + _elapsed * 800.0, size.y)
		draw_line(Vector2(rx, ry), Vector2(rx - 8, ry + 24), Color(0.6, 0.6, 0.9, 0.25), 2)


func _draw_bat(pos: Vector2, scale_val: float) -> void:
	var flap: float = sin(_elapsed * 10.0) * 12.0
	draw_colored_polygon(PackedVector2Array([
		pos, pos + Vector2(-30 * scale_val, -15 - flap), pos + Vector2(-15 * scale_val, 10)
	]), Color(0.02, 0.01, 0.03))
	draw_colored_polygon(PackedVector2Array([
		pos, pos + Vector2(30 * scale_val, -15 - flap), pos + Vector2(15 * scale_val, 10)
	]), Color(0.02, 0.01, 0.03))


func _draw_text_backdrop(size: Vector2) -> void:
	if _shot == 8:
		return
	var gradient_height: float = size.y * 0.35
	var start_y: float = size.y - gradient_height
	var steps: int = 12

	for i in range(steps):
		var t: float = float(i) / float(steps)
		var alpha: float = lerp(0.0, 0.88, t)
		draw_rect(Rect2(0, start_y + (float(i) * (gradient_height / float(steps))), size.x, gradient_height / float(steps) + 1.0), Color(0.01, 0.005, 0.02, alpha))


func _draw_letterbox(size: Vector2) -> void:
	var bar_h: float = 65.0
	draw_rect(Rect2(0, 0, size.x, bar_h), Color(0.0, 0.0, 0.0, 1.0))
	draw_rect(Rect2(0, size.y - bar_h, size.x, bar_h), Color(0.0, 0.0, 0.0, 1.0))


func _draw_control_card(rect: Rect2, header: String, body: String, bg: Color, border: Color) -> void:
	draw_rect(rect, bg)
	draw_rect(rect, border, false, 2)

	draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 35), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.7, 1.0))
	draw_line(rect.position + Vector2(20, 45), rect.position + Vector2(rect.size.x - 20, 45), border * 0.8, 1)

	var lines: PackedStringArray = body.split("\n")
	var line_y: float = rect.position.y + 75.0
	for line in lines:
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 20, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))
		line_y += 28.0
