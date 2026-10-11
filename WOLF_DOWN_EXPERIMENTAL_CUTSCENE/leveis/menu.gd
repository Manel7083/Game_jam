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
##    fonte MountainsofChristmas (o título agora é desenhado por código, igual ao da cutscene).
## NOVOS: audio/menu_transform.wav e audio/menu_howl.wav (gerados por audio/gerar_audio_menu.py).
##
## Qualquer tecla / clique pula a cutscene.

const MUSIC_FILE := "res://audio/musica_halloween.wav"
const MUSIC_PITCH := 0.85          # a cutscene de abertura usa 0.83; 1.0 = velocidade original
const THUNDER_FILE := "res://audio/thunder.wav"
const TRANSFORM_FILE := "res://audio/menu_transform.wav"
const HOWL_FILE := "res://audio/menu_howl.wav"

const TITLE_LINE_1 := "THE LAST LEGEND"
const TITLE_LINE_2 := ""

# ---- linha do tempo (segundos) ----
const T_FADE_IN := 1.6      # sai do preto
const T_SFX := 1.4          # começa o áudio da transformação (o "baque" cai em T_SFX + 3.6)
const T_MORPH0 := 2.0       # o caçador começa a se contorcer
const T_SWAP := 5.0         # clarão: vira lobisomem
const T_HOWL := 6.0         # começa o uivo
const T_MENU := 8.6         # título, música e botões entram

# [instante, força, branco(1)/vermelho(0), decaimento]
const FLASHES: Array = [
	[2.6, 0.35, 0, 0.15], [3.0, 0.25, 0, 0.12], [3.4, 0.40, 0, 0.15], [3.7, 0.30, 0, 0.12],
	[4.0, 0.50, 0, 0.15], [4.2, 0.35, 0, 0.12], [4.4, 0.55, 0, 0.15],
	[4.7, 0.60, 1, 0.15], [4.9, 0.70, 1, 0.15], [5.0, 1.00, 1, 0.55],
	[8.6, 0.30, 0, 0.30],
]

# Raios no céu durante a transformação (instante de cada clarão frio).
const BOLT_TIMES: Array = [2.6, 3.4, 4.0, 4.4, 4.7, 4.9, 5.0]

const BUTTON_LABELS: Array[String] = ["START", "CONTROL", "QUIT GAME"]

var _skipped: bool = false
var _menu_shown: bool = false
var _ev: Dictionary = {}

var _sfx_transform: AudioStreamPlayer
var _sfx_howl: AudioStreamPlayer
var _sfx_thunder: AudioStreamPlayer
var _title_start: float = -1.0      # instante (em _total) em que o título começou a entrar
var _lean: float = 0.0              # curvatura do corpo do caçador (usada por _deform)
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
	# O título é desenhado em _draw() (_draw_title), com a mesma fonte do logotipo da cutscene.

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

	# O título entra (fade + zoom + brilho) dentro de _draw_title(), a partir deste instante.
	_title_start = _total

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

	# Batimento do coração: acelera e fica mais forte conforme a maldição avança.
	var beat_rate: float = lerpf(2.2, 7.5, morph)
	var beat: float = pow(maxf(sin(t * beat_rate * 2.0), 0.0), 6.0) * morph * (1.0 - after)

	# A lua fica vermelha/ameaçadora e pulsa junto com o coração.
	_glow(moon, 1300.0, Color(0.95, 0.12, 0.10, (0.16 + 0.12 * beat) * morph * (1.0 - 0.6 * after)))
	_glow(moon, 420.0, Color(1.0, 0.25, 0.15, 0.22 * morph * (0.6 + 0.4 * beat) * (1.0 - after)))

	_draw_sky_bolts(t, cx + shift)

	var base := Vector2(cx + 40.0 + shift, 905.0)
	if t < T_SWAP:
		_draw_hunter(Vector2(base.x, base.y - 25.0), 1.8, morph, beat)
	else:
		var sc: float = lerpf(1.08, 0.9, _smooth((t - T_SWAP) / 0.6))
		_wolf_howl(base, sc, t, howl)   # herdado
		_howl_rings(base, sc, howl)
		_draw_shockwaves(base, t - T_SWAP)
	_draw_mist(935.0, 0.05)
	_draw_embers(18)

	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color.WHITE)

	# Vinheta vermelha pulsando no ritmo do coração.
	var red_a: float = (0.05 + 0.20 * beat) * morph * (1.0 - after)
	if red_a > 0.005:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.6, 0.0, 0.02, red_a))

	# Título (logotipo desenhado por código): entra junto com o menu.
	_draw_title(screen)

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
# Título: logotipo desenhado por código (mesma fonte, cor, contorno e brilho do logotipo
# da cutscene). Entra junto com o menu: fade + zoom + clarão de impacto + "respiração".
# ----------------------------------------------------------------------------

func _draw_title(screen: Vector2) -> void:
	if _title_start < 0.0:
		return
	var since: float = _total - _title_start
	var t: float = _smooth(since / 1.2)
	if t <= 0.0:
		return

	# Espaço de design (altura DESIGN_H), sem o tremor de câmera da cena.
	draw_set_transform_matrix(Transform2D(0.0, Vector2(_scale, _scale), 0.0, Vector2.ZERO))
	var cx: float = _vw * 0.5
	var scale_in: float = 1.0 + (1.0 - t) * 0.08
	var breathe: float = 1.0 + 0.012 * sin(since * 1.6)
	var impact: float = exp(-since / 0.35)

	# Tamanho base 130; reduz sozinho se a linha mais larga não couber na tela.
	var fs_base: float = 130.0
	var w1: float = FONT_BOLD.get_string_size(TITLE_LINE_1, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs_base)).x
	var w2: float = FONT_BOLD.get_string_size(TITLE_LINE_2, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs_base)).x
	var widest: float = maxf(w1, w2)
	var max_w: float = _vw * 0.86
	if widest > max_w:
		fs_base *= max_w / widest
		widest = max_w
	var fs: int = int(fs_base * scale_in * breathe)
	var outline: int = maxi(int(18.0 * fs_base / 130.0), 4)

	var y1: float = 60.0 + fs_base * 1.05      # baseline da 1ª linha
	var y2: float = y1 + fs_base * 0.78        # baseline da 2ª linha
	var dec_y: float = y2 + fs_base * 0.10     # linha decorativa

	# Brilho vermelho atrás do logotipo.
	_glow_ellipse(Vector2(cx, (y1 + y2) * 0.5 - fs_base * 0.2), widest * 0.62, fs_base * 1.5, Color(1.0, 0.05, 0.10, (0.34 + 0.12 * impact) * t))

	var fill := Color(1.0, 0.24, 0.18, t)
	var edge := Color(0.12, 0.0, 0.02, t)
	draw_string_outline(FONT_BOLD, Vector2(0.0, y1), TITLE_LINE_1, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, outline, edge)
	draw_string(FONT_BOLD, Vector2(0.0, y1), TITLE_LINE_1, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, fill)
	draw_string_outline(FONT_BOLD, Vector2(0.0, y2), TITLE_LINE_2, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, outline, edge)
	draw_string(FONT_BOLD, Vector2(0.0, y2), TITLE_LINE_2, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, fill)

	# Clarão quente na hora do impacto.
	if impact > 0.05:
		var hot := Color(1.0, 0.85, 0.6, 0.45 * impact * t)
		draw_string(FONT_BOLD, Vector2(0.0, y1), TITLE_LINE_1, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, hot)
		draw_string(FONT_BOLD, Vector2(0.0, y2), TITLE_LINE_2, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, hot)

	# Linhas decorativas e losango.
	var dc := Color(1.0, 0.5, 0.45, 0.8 * t)
	draw_line(Vector2(cx - 260.0, dec_y), Vector2(cx - 24.0, dec_y), dc, 3.0, true)
	draw_line(Vector2(cx + 24.0, dec_y), Vector2(cx + 260.0, dec_y), dc, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, dec_y - 10.0),
		Vector2(cx + 10.0, dec_y),
		Vector2(cx, dec_y + 10.0),
		Vector2(cx - 10.0, dec_y),
	]), Color(1.0, 0.5, 0.45, 0.9 * t))

	draw_set_transform_matrix(Transform2D.IDENTITY)


# ----------------------------------------------------------------------------
# Efeitos da transformação
# ----------------------------------------------------------------------------

## Raios cortando o céu a cada clarão frio (BOLT_TIMES), até a virada.
func _draw_sky_bolts(t: float, cx: float) -> void:
	if t > T_SWAP + 0.3:
		return
	for i in BOLT_TIMES.size():
		var dt: float = t - float(BOLT_TIMES[i])
		if dt < 0.0 or dt > 0.22:
			continue
		var a: float = 1.0 - dt / 0.22
		var sd: float = float(BOLT_TIMES[i]) * 13.0 + float(i)
		var px: float = cx - 520.0 + _hsh(sd) * 1000.0
		var y: float = -20.0
		var pts := PackedVector2Array()
		while y < 740.0:
			pts.append(Vector2(px, y))
			y += 55.0 + _hsh(sd + y) * 40.0
			px += (_hsh(sd * 1.7 + y) - 0.5) * 120.0
		pts.append(Vector2(px, 760.0))
		draw_polyline(pts, Color(0.55, 0.65, 1.0, 0.25 * a), 16.0, true)
		draw_polyline(pts, Color(0.92, 0.95, 1.0, 0.9 * a), 4.0, true)
		if pts.size() > 3:
			var q: Vector2 = pts[2]
			var br := PackedVector2Array([
				q,
				q + Vector2((_hsh(sd + 5.0) - 0.5) * 260.0, 120.0),
				q + Vector2((_hsh(sd + 8.0) - 0.5) * 340.0, 260.0),
			])
			draw_polyline(br, Color(0.92, 0.95, 1.0, 0.6 * a), 2.5, true)
		_glow(Vector2(px, 760.0), 160.0, Color(0.7, 0.8, 1.0, 0.35 * a))


## Onda de choque + poeira + faíscas quando o caçador vira lobo.
func _draw_shockwaves(base: Vector2, dt: float) -> void:
	if dt > 1.6:
		return
	var center: Vector2 = base + Vector2(0.0, -300.0)
	for i in 3:
		var d: float = dt - float(i) * 0.14
		if d <= 0.0:
			continue
		var a: float = clampf(1.0 - d / 1.3, 0.0, 1.0)
		var col := Color(1.0, 0.45 + 0.2 * float(i), 0.3, 0.55 * a)
		if i == 2:
			col = Color(1.0, 0.95, 0.9, 0.4 * a)
		draw_arc(center, d * 1500.0, 0.0, TAU, 96, col, 10.0 * a + 2.0, true)

	var fade: float = clampf(1.0 - dt / 1.2, 0.0, 1.0)
	_glow_ellipse(base + Vector2(0.0, 20.0), 120.0 + dt * 700.0, 30.0 + dt * 50.0, Color(0.8, 0.2, 0.15, 0.35 * fade))
	if fade <= 0.0:
		return
	for i in 30:
		var fi: float = float(i)
		var ang: float = -PI * (0.1 + 0.8 * _hsh(fi * 2.7))
		var sp: float = 500.0 + 900.0 * _hsh(fi * 5.3)
		var pos: Vector2 = center + Vector2.from_angle(ang) * (sp * dt) + Vector2(0.0, 400.0 * dt * dt)
		draw_circle(pos, 2.0 + 3.0 * _hsh(fi * 9.1), Color(1.0, 0.6, 0.25, fade))


## Chão rachando em brasa, aura e partículas subindo ao redor do caçador.
func _draw_transform_fx(base: Vector2, k: float, morph: float) -> void:
	if morph < 0.05:
		return
	var o: Vector2 = base + Vector2(10.0, 30.0) * k
	_glow_ellipse(o, (150.0 + 160.0 * morph) * k, 26.0 * k, Color(1.0, 0.25, 0.08, 0.30 * morph))

	for i in 9:
		var fi: float = float(i)
		var dx: float = (fi / 8.0 - 0.5) * 2.0
		var ln: float = (120.0 + 220.0 * _hsh(fi * 4.3)) * morph * k
		var end: Vector2 = o + Vector2(dx * ln, (_hsh(fi * 8.1) - 0.3) * 30.0 * k)
		var fl: float = 0.5 + 0.5 * sin(_total * 9.0 + fi)
		draw_line(o, end, Color(1.0, 0.30, 0.08, 0.20 * morph * fl), 10.0 * k, true)
		draw_line(o, end, Color(1.0, 0.55, 0.15, 0.80 * morph * fl), 3.0 * k, true)

	for i in 44:
		var fi: float = float(i)
		var ph: float = fposmod(_total * (0.35 + 0.4 * _hsh(fi * 1.9)) + _hsh(fi * 6.1), 1.0)
		var px: float = (_hsh(fi * 2.3) - 0.5) * 300.0 + sin(_total * 2.0 + fi) * 20.0
		var pp: Vector2 = o + Vector2(px, -ph * 520.0) * k
		var rad: float = (1.5 + 3.5 * _hsh(fi * 3.7)) * (1.0 - ph * 0.5)
		draw_circle(pp, rad, Color(1.0, 0.45 + 0.4 * (1.0 - ph), 0.15, (1.0 - ph) * 0.9 * morph))


# ----------------------------------------------------------------------------
# O caçador (silhueta de OpeningCinematic._hunter) com efeitos de transformação.
# morph: 0 = homem, 1 = prestes a virar lobo.  beat: pulso do coração (0..1).
# O corpo se curva para a frente (_lean) conforme a transformação avança.
# ----------------------------------------------------------------------------

## Curva o corpo: quanto mais alto o ponto, mais ele é empurrado para a frente (e um pouco para baixo).
func _deform(o: Vector2) -> Vector2:
	var h: float = clampf(-o.y / 230.0, 0.0, 1.0)
	return Vector2(o.x + _lean * h * h, o.y + _lean * 0.22 * h * h)


func _pt(b: Vector2, k: float, o: Vector2) -> Vector2:
	return b + _deform(o) * k


func _hx(offsets: Array, b: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in offsets:
		out.append(_pt(b, k, o as Vector2))
	return out


func _hpoly(offsets: Array, b: Vector2, k: float, color: Color) -> void:
	draw_colored_polygon(_hx(offsets, b, k), color)


func _hline(a: Vector2, c: Vector2, b: Vector2, k: float, color: Color, width: float) -> void:
	draw_line(_pt(b, k, a), _pt(b, k, c), color, width * k, true)


func _moved(offsets: Array, d: Vector2) -> Array:
	var out: Array = []
	for o in offsets:
		out.append((o as Vector2) + d)
	return out


func _draw_hunter(base: Vector2, k0: float, morph: float, beat: float) -> void:
	var sil := Color(0.004, 0.004, 0.009)
	var cool := Color(0.80, 0.85, 1.0, 0.95)
	var hot := Color(1.0, 0.35, 0.25, 0.95)
	var rim: Color = cool.lerp(hot, morph)
	var bob: float = sin(_total * 6.0) * 4.0 * (1.0 - 0.5 * morph)
	var wind: float = sin(_total * 2.5) * 20.0
	var kj: float = floorf(_total * 30.0)
	var jit := Vector2(_hsh(kj) - 0.5, _hsh(kj + 3.7) - 0.5) * 22.0 * morph * morph
	var k: float = k0 * (1.0 + 0.28 * morph + 0.025 * beat)
	_lean = 78.0 * morph * morph + 10.0 * beat
	var b: Vector2 = base + Vector2(0.0, bob * k) + jit

	# Sombra no chão, chão em brasa e partículas.
	_glow_ellipse(base + Vector2(10.0, 30.0) * k, 120.0 * k, 16.0 * k, Color(0, 0, 0, 0.6))
	_draw_transform_fx(base, k, morph)
	_glow_ellipse(b + Vector2(0.0, -120.0) * k, 230.0 * k, 270.0 * k, Color(1.0, 0.15, 0.10, (0.24 + 0.14 * beat) * morph))

	# Corpo, pernas, braços (mesmos polígonos do caçador original).
	_hpoly([Vector2(-30, -180), Vector2(40, -180), Vector2(60 + wind * 0.5, -30), Vector2(20 + wind, 10), Vector2(-85 + wind * 1.5, -10)], b, k, sil)
	_hpoly([Vector2(-20, -80), Vector2(0, -80), Vector2(-10, 0), Vector2(-35, 0)], b, k, sil)
	_hpoly([Vector2(10, -80), Vector2(35, -80), Vector2(45, 15), Vector2(15, 15)], b, k, sil)
	# Braço livre: os músculos incham e o braço se alonga.
	var free_end := Vector2(-40.0 - 22.0 * morph, -90.0 + 52.0 * morph)
	_hline(Vector2(-20, -170), free_end, b, k, sil, 22.0 + 18.0 * morph)
	_hline(Vector2(30, -170), Vector2(90, -130), b, k, sil, 24.0 + 12.0 * morph)

	# Braço com a arma + brilho azul (vira vermelho no fim).
	var g1 := Vector2(70, -140)
	var g2 := Vector2(200, -155)
	_hline(g1, g1 + Vector2(50, -5), b, k, sil, 24.0)
	_hline(g1 + Vector2(40, -5), g2, b, k, sil, 14.0)
	_hline(g1 + Vector2(40, -12), g2 + Vector2(0, -7), b, k, sil, 8.0)
	var core: Vector2 = _pt(b, k, g1 + Vector2(65, -8))
	var gp: float = 0.5 + 0.5 * sin(_total * 15.0)
	_glow(core, (26.0 + gp * 14.0) * k, Color(0.3, 0.7, 1.0, 0.55).lerp(Color(1.0, 0.3, 0.2, 0.55), morph))
	draw_circle(core, 4.0 * k, Color(0.7, 0.95, 1.0))
	_glow(_pt(b, k, g2 + Vector2(14, -12 + wind * 0.2)), 26.0 * k, Color(0.6, 0.7, 0.8, 0.18))

	# Pescoço e cabeça; o focinho estica e as orelhas crescem com o morph.
	_hpoly([Vector2(-25, -180), Vector2(35, -180), Vector2(25, -210), Vector2(-15, -210)], b, k, sil)
	draw_circle(_pt(b, k, Vector2(5, -215)), 18.0 * k, sil)
	var m: float = 0.0
	if morph > 0.3:
		m = (morph - 0.3) / 0.7
		_hpoly([Vector2(14, -224), Vector2(14 + 46.0 * m, -214), Vector2(14, -204)], b, k, sil)           # focinho
		_hpoly([Vector2(-6, -228), Vector2(-14, -228 - 40.0 * m), Vector2(8, -230)], b, k, sil)           # orelha
		_hpoly([Vector2(-14, -226), Vector2(-30, -224 - 30.0 * m), Vector2(-2, -230)], b, k, sil)         # 2ª orelha
	# Presas aparecem no fim.
	if morph > 0.6:
		var fm: float = clampf((morph - 0.6) / 0.4, 0.0, 1.0)
		var fang := Color(0.95, 0.93, 0.85, 0.95)
		_hpoly([Vector2(14 + 22.0 * m, -208), Vector2(14 + 28.0 * m, -208), Vector2(14 + 25.0 * m, -208 + 11.0 * fm)], b, k, fang)
		_hpoly([Vector2(14 + 36.0 * m, -211), Vector2(14 + 41.0 * m, -211), Vector2(14 + 39.0 * m, -211 + 9.0 * fm)], b, k, fang)

	# Olhos: de azul para amarelo/vermelho brilhante, com feixes de luz.
	var eye_col: Color = Color(0.4, 0.8, 1.0, 0.95).lerp(Color(1.0, 0.9, 0.3, 1.0), clampf(morph * 1.6, 0.0, 1.0))
	_hline(Vector2(10, -215), Vector2(18, -212), b, k, eye_col, 2.0 + 3.0 * morph)
	var eye: Vector2 = _pt(b, k, Vector2(14, -213))
	_glow(eye, (10.0 + 46.0 * morph + 10.0 * beat) * k, Color(1.0, 0.8, 0.2, 0.15 + 0.65 * morph))
	if morph > 0.3:
		var ray: float = (morph - 0.3) / 0.7
		draw_line(eye, eye + Vector2(60.0 + 240.0 * ray, -8.0 * ray) * k, Color(1.0, 0.85, 0.3, 0.22 * ray), 7.0 * k, true)
		draw_line(eye, eye + Vector2(40.0 + 120.0 * ray, -4.0 * ray) * k, Color(1.0, 0.95, 0.6, 0.5 * ray), 2.5 * k, true)

	# Chapéu: cai quando a transformação passa de 55%.
	var hf: float = clampf((morph - 0.55) / 0.45, 0.0, 1.0)
	var hat_off := Vector2(40.0 * hf, -90.0 * hf + 330.0 * hf * hf)
	_hpoly(_moved([Vector2(-55, -215), Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], hat_off), b, k, sil)
	_hpoly(_moved([Vector2(-25, -230), Vector2(-15, -265), Vector2(15, -265), Vector2(25, -230)], hat_off), b, k, sil)
	if hf < 0.2:
		draw_polyline(_hx([Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], b, k), rim, 3.0, true)

	# Pelos nascendo nas costas e no peito (mais densos que antes).
	if morph > 0.12:
		var m2: float = (morph - 0.12) / 0.88
		for i in 40:
			var fi: float = float(i)
			var back: bool = i % 2 == 0
			var a_pt: Vector2 = Vector2(-30, -180) if back else Vector2(40, -180)
			var c_pt: Vector2 = Vector2(-85 + wind * 1.5, -10) if back else Vector2(60 + wind * 0.5, -30)
			var p: Vector2 = a_pt.lerp(c_pt, _hsh(fi * 3.1))
			var spike: float = (16.0 + 40.0 * _hsh(fi * 7.7)) * m2 * (0.75 + 0.25 * sin(_total * 18.0 + fi))
			if spike < 3.0:
				continue
			var nrm := Vector2(-1.0, 0.0) if back else Vector2(1.0, 0.0)
			_hpoly([p + Vector2(0, -9), p + nrm * spike + Vector2(0, spike * 0.25), p + Vector2(0, 9)], b, k, sil)

	# Trapos rasgados soltos pelo vento conforme o corpo cresce.
	if morph > 0.35:
		var tm: float = (morph - 0.35) / 0.65
		for i in 6:
			var fi: float = float(i)
			var from: Vector2 = Vector2(-20.0 + 60.0 * _hsh(fi * 1.3), -160.0 + 110.0 * _hsh(fi * 2.9))
			var drift: Vector2 = Vector2(-50.0 - 70.0 * _hsh(fi * 4.1), -20.0 + 40.0 * sin(_total * 5.0 + fi)) * tm
			draw_line(_pt(b, k, from), _pt(b, k, from + drift), sil, (5.0 - fi * 0.4) * k, true)

	draw_polyline(_hx([Vector2(35, -180), Vector2(60 + wind * 0.5, -30)], b, k), rim, 2.5, true)
	_hline(g1 + Vector2(40, -16), g2 + Vector2(0, -11), b, k, rim, 2.0)

	# Veias de brasa pulsando ao longo do pescoço e do braço.
	if morph > 0.2:
		var vm: float = (morph - 0.2) / 0.8
		var vc := Color(1.0, 0.25, 0.10, (0.35 + 0.5 * beat) * vm)
		_hline(Vector2(-5, -205), Vector2(-5, -178), b, k, vc, 2.0)
		_hline(Vector2(-20, -165), free_end * 0.8 + Vector2(0, -20), b, k, vc, 2.0)
		_hline(Vector2(25, -165), Vector2(80, -135), b, k, vc, 2.0)

	# Garras crescendo na mão livre.
	if morph > 0.5:
		var cm: float = (morph - 0.5) / 0.5
		var hand: Vector2 = _pt(b, k, free_end)
		for i in 3:
			var o: float = float(i - 1) * 9.0
			draw_line(hand + Vector2(o, 0) * k, hand + Vector2(o - 4.0, 44.0 * cm) * k, Color(0.9, 0.85, 0.75, 0.9), 3.5 * k, true)
