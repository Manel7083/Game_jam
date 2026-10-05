extends Level1AftermathCinematic
## Wolf Down - MENU PRINCIPAL COM CUTSCENE (Godot 4.x)
##
## Sequência:  noite -> o caçador sente a maldição -> TRANSFORMAÇÃO -> lobisomem
##             -> UIVO para a lua -> só então entram título, música e botões animados.
##
## REAPROVEITADO do projeto (nada de PNG novo):
##  - Level1AftermathCinematic (leveis/cutscene_level1.gd): cenário (lua, estrelas, pinheiros,
##    cemitério, névoa, brasas) e o lobo uivando (_wolf_howl). Este script ESTENDE aquela classe.
##  - OpeningCinematic._hunter (leveis/cutscene.gd): a silhueta do caçador (copiada aqui com
##    efeitos de transformação: pelos nascendo, olhos amarelos, chapéu caindo).
##  - UIKit / InteractiveButton / ControlsPanel (ui/): botões e painel de controles de sempre.
##  - GameManager.start_game(), res://audio/musica_halloween.wav, res://audio/thunder.wav,
##    fonte MountainsofChristmas e res://menu/tiulo_jogo.png.
## NOVOS: audio/menu_transform.wav e audio/menu_howl.wav (gerados por audio/gerar_audio_menu.py).
##
## Qualquer tecla / clique pula a cutscene.

const MUSIC_FILE := "res://audio/musica_halloween.wav"
const MUSIC_PITCH := 0.85          # a cutscene de abertura usa 0.83; 1.0 = velocidade original
const THUNDER_FILE := "res://audio/thunder.wav"
const TRANSFORM_FILE := "res://audio/menu_transform.wav"
const HOWL_FILE := "res://audio/menu_howl.wav"
const TITLE_FILE := "res://menu/tiulo_jogo.png"

# ---- linha do tempo (segundos) ----
const T_FADE_IN := 1.6      # sai do preto
const T_SFX := 1.4          # começa o áudio da transformação (o "baque" cai em T_SFX + 3.6)
const T_MORPH0 := 2.0       # o caçador começa a se contorcer
const T_SWAP := 5.0         # clarão: vira lobisomem
const T_HOWL := 6.0         # começa o uivo
const T_MENU := 8.6         # título, música e botões entram

# [instante, força, branco(1)/vermelho(0), decaimento]
const FLASHES: Array = [
	[2.6, 0.35, 0, 0.15], [3.4, 0.40, 0, 0.15], [4.0, 0.50, 0, 0.15], [4.4, 0.55, 0, 0.15],
	[4.7, 0.60, 1, 0.15], [4.9, 0.70, 1, 0.15], [5.0, 1.00, 1, 0.55],
	[8.6, 0.30, 0, 0.30],
]

const BUTTON_LABELS: Array[String] = ["START", "CONTROL", "QUIT GAME"]

var _skipped: bool = false
var _menu_shown: bool = false
var _ev: Dictionary = {}

var _sfx_transform: AudioStreamPlayer
var _sfx_howl: AudioStreamPlayer
var _sfx_thunder: AudioStreamPlayer
var _title_node: Control
var _menu_box: VBoxContainer
var _menu_buttons: Array[Button] = []
var _skip_hint: Label


# ----------------------------------------------------------------------------
# Ciclo de vida
# ----------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_textures()   # herdado: brilho radial e vinheta
	_build_menu_ui()
	_build_audio()
	queue_redraw()


func _process(delta: float) -> void:
	_total += delta
	_elapsed = _total
	_run_events()
	if _skip_hint:
		_skip_hint.modulate.a = clampf((_total - 1.0) / 1.0, 0.0, 0.7) * (1.0 - _smooth((_total - T_MENU) / 0.5))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _menu_shown or _skipped:
		return
	var pressed: bool = false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_skip()


# Desativa o _input da classe-mãe (ela avançava planos da cutscene antiga).
func _input(_event: InputEvent) -> void:
	pass


func _run_events() -> void:
	if _skipped:
		return
	if _once("sfx", _total >= T_SFX):
		_play(_sfx_transform)
	if _once("thunder1", _total >= 2.6):
		_play(_sfx_thunder)
	if _once("thunder2", _total >= T_SWAP):
		_play(_sfx_thunder)
	if _once("howl", _total >= T_HOWL):
		_play(_sfx_howl)
	if _once("menu", _total >= T_MENU):
		_show_menu()


func _once(key: String, cond: bool) -> bool:
	if cond and not _ev.has(key):
		_ev[key] = true
		return true
	return false


func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	for p in [_sfx_transform, _sfx_howl, _sfx_thunder]:
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
	_total = maxf(_total, T_MENU + 3.0)
	_show_menu()


# ----------------------------------------------------------------------------
# Áudio
# ----------------------------------------------------------------------------

func _make_player(path: String, volume_db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.play()


func _build_audio() -> void:
	_sfx_transform = _make_player(TRANSFORM_FILE, -4.0)
	_sfx_howl = _make_player(HOWL_FILE, -3.0)
	_sfx_thunder = _make_player(THUNDER_FILE, -6.0)
	_music = _make_player(MUSIC_FILE, -40.0)
	if is_instance_valid(_music):
		_music.pitch_scale = MUSIC_PITCH
		_music.finished.connect(_music.play)   # loop garantido, independente do import


func _start_music() -> void:
	if not is_instance_valid(_music) or _music.playing:
		return
	_music.play()
	create_tween().tween_property(_music, "volume_db", -8.0, 3.0)


# ----------------------------------------------------------------------------
# UI do menu (título + botões). Tudo nasce escondido e entra depois do uivo.
# ----------------------------------------------------------------------------

func _build_menu_ui() -> void:
	# Título: reaproveita res://menu/tiulo_jogo.png; se faltar, usa texto com a fonte do jogo.
	if ResourceLoader.exists(TITLE_FILE):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(TITLE_FILE)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_title_node = tex_rect
	else:
		_title_node = UIKit.make_label("A LENDA DO LOBISOMEN", 84, Color(1.0, 0.35, 0.2))
	_title_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_node.anchor_left = 0.03
	_title_node.anchor_top = 0.03
	_title_node.anchor_right = 0.50
	_title_node.anchor_bottom = 0.40
	_title_node.modulate.a = 0.0
	add_child(_title_node)

	# Botões (na esquerda, para não cobrir o lobo e a lua).
	_menu_box = VBoxContainer.new()
	_menu_box.anchor_left = 0.06
	_menu_box.anchor_right = 0.06
	_menu_box.anchor_top = 0.50
	_menu_box.anchor_bottom = 0.50
	_menu_box.grow_horizontal = Control.GROW_DIRECTION_END
	_menu_box.grow_vertical = Control.GROW_DIRECTION_END
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.add_theme_constant_override("separation", 18)
	add_child(_menu_box)

	var callbacks: Array[Callable] = [_on_start, _on_controls, _on_quit]
	for i in BUTTON_LABELS.size():
		var b: Button = UIKit.make_button(BUTTON_LABELS[i], callbacks[i])
		_style_button(b)
		_menu_box.add_child(b)
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE   # só liga quando o menu aparece
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))
		b.focus_entered.connect(_on_button_hover.bind(b, true))
		b.focus_exited.connect(_on_button_hover.bind(b, false))
		_menu_buttons.append(b)

	_skip_hint = Label.new()
	_skip_hint.text = "QUALQUER TECLA / CLIQUE - PULAR"
	_skip_hint.anchor_left = 0.1
	_skip_hint.anchor_right = 0.9
	_skip_hint.anchor_top = 0.945
	_skip_hint.anchor_bottom = 0.99
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_font_override("font", FONT_BOLD)
	_skip_hint.add_theme_font_size_override("font_size", 20)
	_skip_hint.add_theme_color_override("font_color", Color(0.72, 0.67, 0.82))
	_skip_hint.modulate.a = 0.0
	add_child(_skip_hint)


func _style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(360, 66)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.25, 0.15))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0))
	b.add_theme_constant_override("outline_size", 6)
	var looks := {
		"normal": [Color(0.07, 0.02, 0.10, 0.80), Color(0.55, 0.10, 0.08)],
		"hover": [Color(0.30, 0.04, 0.05, 0.92), Color(1.00, 0.42, 0.10)],
		"pressed": [Color(0.45, 0.03, 0.03, 0.95), Color(1.00, 0.20, 0.10)],
		"disabled": [Color(0.07, 0.02, 0.10, 0.50), Color(0.30, 0.10, 0.10)],
	}
	for state in looks:
		var sb := StyleBoxFlat.new()
		sb.bg_color = looks[state][0]
		sb.border_color = looks[state][1]
		sb.set_border_width_all(3)
		sb.border_width_left = 8
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 22
		b.add_theme_stylebox_override(state, sb)
	var focus := StyleBoxFlat.new()   # contorno para teclado/controle
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.85, 0.40)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(3)
	b.add_theme_stylebox_override("focus", focus)


func _show_menu() -> void:
	if _menu_shown:
		return
	_menu_shown = true
	_start_music()

	# Título cai com impacto.
	_title_node.pivot_offset = _title_node.size * 0.5
	_title_node.scale = Vector2(1.35, 1.35)
	var tt := create_tween().set_parallel(true)
	tt.tween_property(_title_node, "modulate:a", 1.0, 0.5)
	tt.tween_property(_title_node, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var idle := create_tween().set_loops()   # título "respirando"
	idle.tween_interval(0.9)
	idle.tween_property(_title_node, "scale", Vector2(1.02, 1.02), 1.6).set_trans(Tween.TRANS_SINE)
	idle.tween_property(_title_node, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)

	# Botões entram um por um, abrindo da esquerda.
	var delay: float = 0.55
	for b in _menu_buttons:
		b.pivot_offset = Vector2(0.0, b.size.y * 0.5)
		b.scale = Vector2(0.15, 1.0)
		var bt := create_tween()
		bt.tween_interval(delay)
		bt.tween_property(b, "modulate:a", 1.0, 0.25)
		bt.parallel().tween_property(b, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_callback(_enable_button.bind(b))
		delay += 0.18
	var first: Button = _menu_buttons[0]
	await get_tree().create_timer(delay + 0.5).timeout
	if is_instance_valid(first):
		first.grab_focus()   # teclado/controle já começam no START


func _enable_button(b: Button) -> void:
	if not is_instance_valid(b):
		return
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_ALL


func _on_button_hover(b: Button, inside: bool) -> void:
	if not _menu_shown or not is_instance_valid(b):
		return
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(1.07, 1.07) if inside else Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start() -> void:
	for b in _menu_buttons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(_music):
		create_tween().tween_property(_music, "volume_db", -60.0, 0.9)
	GameManager.start_game()


func _on_controls() -> void:
	var dim: ColorRect = UIKit.make_dim_background(0.82)
	add_child(dim)
	var panel := ControlsPanel.new()
	add_child(panel)
	panel.closed.connect(dim.queue_free)


func _on_quit() -> void:
	get_tree().quit()


# ----------------------------------------------------------------------------
# Desenho
# ----------------------------------------------------------------------------

func _flash_color() -> Color:
	var a: float = 0.0
	var white: float = 0.0
	for f in FLASHES:
		var dt: float = _total - float(f[0])
		if dt < 0.0:
			continue
		var v: float = float(f[1]) * exp(-dt / float(f[3]))
		a += v
		white = maxf(white, v * float(f[2]))
	a = clampf(a, 0.0, 1.0)
	var w: float = clampf(white / maxf(a, 0.001), 0.0, 1.0)
	return Color(1.0, lerpf(0.12, 1.0, w), lerpf(0.08, 1.0, w), a)


func _draw() -> void:
	var screen := get_viewport_rect().size
	_scale = screen.y / DESIGN_H
	_vw = screen.x / _scale
	var t: float = _total

	var morph: float = _smooth((t - T_MORPH0) / (T_SWAP - T_MORPH0))
	var after: float = _smooth((t - T_SWAP) / 0.6)
	var howl: float = _smooth((t - T_HOWL) / 2.8)

	# Câmera: aproxima devagar; treme na transformação.
	var zoom: float = 1.0 + 0.05 * _smooth(t / T_SWAP) + 0.05 * _smooth((t - T_HOWL) / 3.0)
	var amp: float = 2.0 + 14.0 * morph * morph
	if t >= T_SWAP:
		amp = 2.0 + 30.0 * exp(-(t - T_SWAP) / 0.5) + 2.0 * howl
	var k40: float = floorf(t * 40.0)
	var shake := Vector2(_hsh(k40) - 0.5, _hsh(k40 + 9.1) - 0.5) * 2.0 * amp
	var sway := Vector2(sin(t * 0.7) * 4.0, cos(t * 0.9) * 3.0)
	var s: float = _scale * zoom
	var origin := screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + (sway + shake) * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	# Cenário (herdado): a lua nasce e cresce durante a transformação.
	var cx: float = _vw * 0.5
	var shift: float = _vw * 0.14   # personagem à direita; botões ficam à esquerda
	var rise: float = _smooth(t / T_SWAP)
	var moon := Vector2(cx + 220.0 + shift, lerpf(520.0, 360.0, rise))
	_bg(moon, lerpf(170.0, 250.0, rise), false, true)
	# A lua fica vermelha/ameaçadora enquanto ele se transforma.
	_glow(moon, 1300.0, Color(0.95, 0.12, 0.10, 0.16 * morph * (1.0 - 0.6 * after)))

	var base := Vector2(cx + 40.0 + shift, 905.0)
	if t < T_SWAP:
		_draw_hunter(Vector2(base.x, base.y - 25.0), 1.8, morph)
	else:
		var sc: float = lerpf(1.08, 0.9, _smooth((t - T_SWAP) / 0.6))
		_wolf_howl(base, sc, t, howl)   # herdado
		_howl_rings(base, sc, howl)
	_draw_mist(935.0, 0.05)
	_draw_embers(18)

	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color.WHITE)

	# Grão de filme.
	var seed_v: float = floorf(t * 24.0)
	for i in 70:
		var fi: float = float(i)
		var gx: float = _hsh(fi * 1.37 + seed_v) * screen.x
		var gy: float = _hsh(fi * 2.11 + seed_v * 1.7) * screen.y
		draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(1, 1, 1, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.10))

	# Clarões da transformação.
	var fc: Color = _flash_color()
	if fc.a > 0.01:
		draw_rect(Rect2(Vector2.ZERO, screen), fc)

	# Letterbox cinematográfico: entra no começo e sai quando o menu aparece.
	var bar_k: float = _smooth(t / 1.2) * (1.0 - _smooth((t - T_MENU) / 1.0))
	var bar_h: float = screen.y * 0.075 * bar_k
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.95))
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color(0, 0, 0, 0.95))

	# Sai do preto no começo.
	var fade: float = 1.0 - _smooth(t / T_FADE_IN)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, fade))


## Ondas do uivo saindo do focinho em direção à lua.
func _howl_rings(base: Vector2, sc: float, howl: float) -> void:
	if howl < 0.15:
		return
	var tilt: float = -lerpf(0.35, 0.95, howl)
	var pivot: Vector2 = _at(base, sc, 70.0, -640.0)
	var mouth: Vector2 = _hh(pivot, tilt, sc, 150.0, -10.0)
	var dir := Vector2.RIGHT.rotated(tilt)
	for i in 4:
		var ph: float = fposmod(_total * 0.45 + float(i) * 0.25, 1.0)
		var c: Vector2 = mouth + dir * (ph * 140.0 * sc)
		var r: float = (30.0 + ph * 380.0) * sc
		draw_arc(c, r, tilt - 0.55, tilt + 0.55, 28, Color(0.85, 0.82, 1.0, 0.45 * (1.0 - ph) * howl), 4.0 * sc + 2.0, true)


# ----------------------------------------------------------------------------
# O caçador (silhueta de OpeningCinematic._hunter) com efeitos de transformação.
# morph: 0 = homem, 1 = prestes a virar lobo.
# ----------------------------------------------------------------------------

func _hx(offsets: Array, b: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in offsets:
		out.append(b + (o as Vector2) * k)
	return out


func _hpoly(offsets: Array, b: Vector2, k: float, color: Color) -> void:
	draw_colored_polygon(_hx(offsets, b, k), color)


func _hline(a: Vector2, c: Vector2, b: Vector2, k: float, color: Color, width: float) -> void:
	draw_line(b + a * k, b + c * k, color, width * k, true)


func _moved(offsets: Array, d: Vector2) -> Array:
	var out: Array = []
	for o in offsets:
		out.append((o as Vector2) + d)
	return out


func _draw_hunter(base: Vector2, k0: float, morph: float) -> void:
	var sil := Color(0.004, 0.004, 0.009)
	var cool := Color(0.80, 0.85, 1.0, 0.95)
	var hot := Color(1.0, 0.35, 0.25, 0.95)
	var rim: Color = cool.lerp(hot, morph)
	var bob: float = sin(_total * 6.0) * 4.0 * (1.0 - 0.5 * morph)
	var wind: float = sin(_total * 2.5) * 20.0
	var kj: float = floorf(_total * 30.0)
	var jit := Vector2(_hsh(kj) - 0.5, _hsh(kj + 3.7) - 0.5) * 16.0 * morph * morph
	var k: float = k0 * (1.0 + 0.28 * morph)
	var b: Vector2 = base + Vector2(0.0, bob * k) + jit

	# Sombra no chão e aura vermelha.
	_glow_ellipse(base + Vector2(10.0, 30.0) * k, 120.0 * k, 16.0 * k, Color(0, 0, 0, 0.6))
	_glow_ellipse(b + Vector2(0.0, -120.0) * k, 230.0 * k, 270.0 * k, Color(1.0, 0.15, 0.10, 0.24 * morph))

	# Corpo, pernas, braços (mesmos polígonos do caçador original).
	_hpoly([Vector2(-30, -180), Vector2(40, -180), Vector2(60 + wind * 0.5, -30), Vector2(20 + wind, 10), Vector2(-85 + wind * 1.5, -10)], b, k, sil)
	_hpoly([Vector2(-20, -80), Vector2(0, -80), Vector2(-10, 0), Vector2(-35, 0)], b, k, sil)
	_hpoly([Vector2(10, -80), Vector2(35, -80), Vector2(45, 15), Vector2(15, 15)], b, k, sil)
	_hline(Vector2(-20, -170), Vector2(-40, -90), b, k, sil, 22.0 + 14.0 * morph)
	_hline(Vector2(30, -170), Vector2(90, -130), b, k, sil, 24.0 + 12.0 * morph)

	# Braço com a arma + brilho azul (vira vermelho no fim).
	var g1 := Vector2(70, -140)
	var g2 := Vector2(200, -155)
	_hline(g1, g1 + Vector2(50, -5), b, k, sil, 24.0)
	_hline(g1 + Vector2(40, -5), g2, b, k, sil, 14.0)
	_hline(g1 + Vector2(40, -12), g2 + Vector2(0, -7), b, k, sil, 8.0)
	var core: Vector2 = b + (g1 + Vector2(65, -8)) * k
	var gp: float = 0.5 + 0.5 * sin(_total * 15.0)
	_glow(core, (26.0 + gp * 14.0) * k, Color(0.3, 0.7, 1.0, 0.55).lerp(Color(1.0, 0.3, 0.2, 0.55), morph))
	draw_circle(core, 4.0 * k, Color(0.7, 0.95, 1.0))
	_glow(b + (g2 + Vector2(14, -12 + wind * 0.2)) * k, 26.0 * k, Color(0.6, 0.7, 0.8, 0.18))

	# Pescoço e cabeça; o focinho começa a esticar com o morph.
	_hpoly([Vector2(-25, -180), Vector2(35, -180), Vector2(25, -210), Vector2(-15, -210)], b, k, sil)
	draw_circle(b + Vector2(5, -215) * k, 18.0 * k, sil)
	if morph > 0.3:
		var m: float = (morph - 0.3) / 0.7
		_hpoly([Vector2(14, -224), Vector2(14 + 46.0 * m, -214), Vector2(14, -204)], b, k, sil)           # focinho
		_hpoly([Vector2(-6, -228), Vector2(-14, -228 - 40.0 * m), Vector2(8, -230)], b, k, sil)           # orelha
	# Olhos: de azul para amarelo brilhante.
	var eye_col: Color = Color(0.4, 0.8, 1.0, 0.95).lerp(Color(1.0, 0.9, 0.3, 1.0), clampf(morph * 1.6, 0.0, 1.0))
	_hline(Vector2(10, -215), Vector2(18, -212), b, k, eye_col, 2.0 + 3.0 * morph)
	_glow(b + Vector2(14, -213) * k, (10.0 + 40.0 * morph) * k, Color(1.0, 0.8, 0.2, 0.15 + 0.65 * morph))

	# Chapéu: cai quando a transformação passa de 55%.
	var hf: float = clampf((morph - 0.55) / 0.45, 0.0, 1.0)
	var hat_off := Vector2(40.0 * hf, -90.0 * hf + 330.0 * hf * hf)
	_hpoly(_moved([Vector2(-55, -215), Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], hat_off), b, k, sil)
	_hpoly(_moved([Vector2(-25, -230), Vector2(-15, -265), Vector2(15, -265), Vector2(25, -230)], hat_off), b, k, sil)
	if hf < 0.2:
		draw_polyline(_hx([Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], b, k), rim, 3.0, true)

	# Pelos nascendo nas costas e no peito.
	if morph > 0.12:
		var m2: float = (morph - 0.12) / 0.88
		for i in 26:
			var fi: float = float(i)
			var back: bool = i % 2 == 0
			var a_pt: Vector2 = Vector2(-30, -180) if back else Vector2(40, -180)
			var c_pt: Vector2 = Vector2(-85 + wind * 1.5, -10) if back else Vector2(60 + wind * 0.5, -30)
			var p: Vector2 = a_pt.lerp(c_pt, _hsh(fi * 3.1))
			var spike: float = (16.0 + 34.0 * _hsh(fi * 7.7)) * m2 * (0.75 + 0.25 * sin(_total * 18.0 + fi))
			if spike < 3.0:
				continue
			var nrm := Vector2(-1.0, 0.0) if back else Vector2(1.0, 0.0)
			_hpoly([p + Vector2(0, -9), p + nrm * spike + Vector2(0, spike * 0.25), p + Vector2(0, 9)], b, k, sil)

	draw_polyline(_hx([Vector2(35, -180), Vector2(60 + wind * 0.5, -30)], b, k), rim, 2.5, true)
	_hline(g1 + Vector2(40, -16), g2 + Vector2(0, -11), b, k, rim, 2.0)

	# Garras brilhando na mão livre.
	if morph > 0.5:
		var cm: float = (morph - 0.5) / 0.5
		var hand: Vector2 = b + Vector2(-40, -90) * k
		for i in 3:
			var o: float = float(i - 1) * 9.0
			draw_line(hand + Vector2(o, 0) * k, hand + Vector2(o - 4.0, 30.0 * cm) * k, Color(0.9, 0.85, 0.75, 0.9), 3.0 * k, true)
