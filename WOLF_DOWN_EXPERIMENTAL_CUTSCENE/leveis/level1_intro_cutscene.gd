extends Level1AftermathCinematic
## Wolf Down - CUTSCENE DE ABERTURA DA FASE 1 (Godot 4.x), 100% desenhada por código.  [v2]
##
## Roteiro:
##   1) Cartela "FASE 1" e o caçador caminhando sob o luar, relâmpagos distantes iluminando o castelo.
##   2) Ele para. A escuridão ganha olhos: monstros nascem do chão, a chuva começa a cair.
##   3) A maldição desperta: TRANSFORMAÇÃO (coração acelerando, raios, lua vermelha, chapéu
##      caindo, pelos, garras, olhos em chamas) até a explosão de energia.
##   4) NOVO LOBO (desenhado neste arquivo, não usa mais o lobo uivando da cena pós-fase):
##      surge agachado no chão em brasa, respirando pesado -> levanta -> RUGE para os monstros
##      (onda de choque) -> dois golpes de garra (os monstros mais próximos se desfazem em pó)
##      -> ergue o .38 e DISPARA PARA CIMA -> os morcegos voam do castelo e o resto foge.
##   5) Encara a câmera (zoom nos olhos dourados) e aparece o título "A CAÇADA COMEÇA".
##
## REAPROVEITADO de Level1AftermathCinematic (leveis/cutscene_level1.gd): textura de brilho,
## vinheta, estrelas, lua, nuvens, montanhas, pinheiros, névoa e brasas.
## Sons: tiro, rugido e golpe de garra são gerados em código (nenhum arquivo novo é obrigatório).
## Se existirem, res://audio/menu_transform.wav, menu_howl.wav e thunder.wav são usados.
##
## Uso: instancie com `Script.new()` dentro de um CanvasLayer e espere o sinal `finished`.
## ESC / ENTER / ESPAÇO pulam a cena.

signal finished

const INTRO_MUSIC := "res://leveis/moonlight_hollow.wav"
const TRANSFORM_FILE := "res://audio/menu_transform.wav"
const HOWL_FILE := "res://audio/menu_howl.wav"
const THUNDER_FILE := "res://audio/thunder.wav"

# ---- linha do tempo (segundos) ----
const T_STOP := 7.0        # o caçador chega e para
const T_SPAWN0 := 7.6      # primeiro monstro começa a nascer
const T_MORPH0 := 11.0     # começa a transformação
const T_SWAP := 16.0       # explosão: vira lobisomem (agachado)
const T_ROAR := 17.55      # levantou: RUGIDO
const T_SLASH1 := 19.0     # golpe de garra para a direita
const T_SLASH2 := 19.9     # golpe de garra para a esquerda
const T_RAISE := 20.5      # o lobo ergue o .38
const T_SHOT := 21.7       # TIRO PARA CIMA
const T_STARE := 23.5      # encara a câmera
const T_FADE := 26.8       # começa a escurecer
const T_END := 27.8        # fim

const WOLF_SC := 0.92      # escala do lobo

# [instante, força, branco(1)/vermelho(0), decaimento]
const FLASHES: Array = [
	[3.4, 0.25, 1, 0.12], [5.2, 0.30, 1, 0.12],
	[11.6, 0.35, 0, 0.15], [12.4, 0.40, 0, 0.15], [13.0, 0.50, 0, 0.15], [13.5, 0.55, 0, 0.15],
	[14.1, 0.60, 0, 0.15], [14.6, 0.60, 0, 0.15], [15.0, 0.65, 1, 0.15], [15.4, 0.70, 1, 0.15],
	[15.7, 0.80, 1, 0.15], [16.0, 1.00, 1, 0.55],
	[17.55, 0.55, 0, 0.20],
	[19.0, 0.35, 1, 0.10], [19.9, 0.35, 1, 0.10],
	[21.7, 0.85, 1, 0.22],
]

# Raios no céu (os dois primeiros iluminam o castelo; o resto é a transformação).
const BOLT_TIMES: Array = [3.4, 5.2, 11.6, 12.4, 13.0, 13.5, 14.1, 14.6, 15.0, 15.4, 15.7, 16.0]

# [deslocamento x do ponto de parada do caçador, y do chão, escala, instante de nascer, tipo, direção, morre no golpe (-1 = foge)]
const MONSTERS: Array = [
	[-780, 925, 0.80, 7.6, 0, 1.0, -1.0], [-570, 915, 0.95, 8.3, 1, 1.0, -1.0],
	[-360, 960, 1.10, 9.1, 2, 1.0, -1.0], [-215, 930, 0.85, 10.4, 0, 1.0, 19.9],
	[260, 935, 1.00, 7.9, 0, -1.0, 19.0], [430, 970, 1.15, 8.7, 1, -1.0, -1.0],
	[620, 925, 0.90, 9.5, 2, -1.0, -1.0], [820, 950, 1.05, 10.0, 0, -1.0, -1.0],
]

var _done: bool = false
var _skipping: bool = false
var _skip_t: float = 0.0
var _ev: Dictionary = {}
var _ic_lean: float = 0.0

# Estado do desenho do lobo (preenchido por _ic_wolf, lido pelos efeitos).
var _nw_base: Vector2 = Vector2.ZERO
var _nw_sc: float = 1.0
var _nw_f: float = 1.0          # +1 olha para a direita, -1 para a esquerda
var _nw_S: Vector2 = Vector2.ZERO   # ombro (coordenadas locais do lobo)
var _nw_hd: Vector2 = Vector2.ZERO  # centro da cabeça (local)
var _nw_ha: float = 0.0             # inclinação da cabeça

var _sfx_transform: AudioStreamPlayer
var _sfx_howl: AudioStreamPlayer
var _sfx_thunder: AudioStreamPlayer
var _sfx_shot: AudioStreamPlayer
var _sfx_growl: AudioStreamPlayer
var _sfx_slash: AudioStreamPlayer

# ----------------------------------------------------------------------------
# Ciclo de vida
# ----------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_textures()   # herdado: brilho radial e vinheta
	_build_audio()
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	_total += delta
	_elapsed = _total
	_run_events()
	if _skipping:
		_skip_t += delta
		if _skip_t >= 0.45:
			_end()
	elif _total >= T_END:
		_end()
	queue_redraw()


# A classe-mãe avançava planos / carregava o próximo nível: aqui nada disso.
func _unhandled_input(_event: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if _done or _skipping or _total < 0.6:
		return
	var skip: bool = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		skip = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_skip()


func _skip() -> void:
	_skipping = true
	for p in [_sfx_transform, _sfx_howl, _sfx_thunder, _sfx_shot, _sfx_growl, _sfx_slash]:
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
	if is_instance_valid(_music):
		create_tween().tween_property(_music, "volume_db", -60.0, 0.4)


func _end() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _ic_once(key: String, cond: bool) -> bool:
	if cond and not _ev.has(key):
		_ev[key] = true
		return true
	return false



func _ic_play_vol(p: AudioStreamPlayer, db: float) -> void:
	if is_instance_valid(p):
		p.volume_db = db
		p.pitch_scale = 1.0
		p.play()


func _run_events() -> void:
	if _skipping:
		return
	if _ic_once("thunder_a", _total >= 3.4):
		_ic_play_vol(_sfx_thunder, -14.0)
	if _ic_once("thunder_b", _total >= 5.2):
		_ic_play_vol(_sfx_thunder, -11.0)
	if _ic_once("thunder_spawn", _total >= T_SPAWN0 + 0.4):
		_ic_play_vol(_sfx_thunder, -6.0)
	if _ic_once("transform", _total >= T_SWAP - 3.6):   # o "baque" do áudio cai na explosão
		_ic_play(_sfx_transform)
	if _ic_once("thunder_swap", _total >= T_SWAP):
		_ic_play_vol(_sfx_thunder, -6.0)
	if _ic_once("roar", _total >= T_ROAR):
		_ic_play_vol(_sfx_growl, -1.0)
	if _ic_once("slash1", _total >= T_SLASH1 - 0.04):
		_ic_play_vol(_sfx_slash, -2.0)
	if _ic_once("slash2", _total >= T_SLASH2 - 0.04):
		_ic_play_vol(_sfx_slash, -2.0)
	if _ic_once("shot", _total >= T_SHOT):
		_ic_play(_sfx_shot)
	if _ic_once("stare", _total >= T_STARE):
		if is_instance_valid(_sfx_growl):
			_sfx_growl.volume_db = -9.0
			_sfx_growl.pitch_scale = 0.78
			_sfx_growl.play()
	if _ic_once("howl_far", _total >= T_STARE + 1.0):
		_ic_play_vol(_sfx_howl, -16.0)   # outro lobo responde ao longe
	if _ic_once("fade_music", _total >= T_FADE):
		if is_instance_valid(_music):
			create_tween().tween_property(_music, "volume_db", -60.0, T_END - T_FADE)


# ----------------------------------------------------------------------------
# Áudio
# ----------------------------------------------------------------------------

func _ic_player(path: String, volume_db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func _ic_play(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.play()


func _build_audio() -> void:
	_sfx_transform = _ic_player(TRANSFORM_FILE, -4.0)
	_sfx_howl = _ic_player(HOWL_FILE, -16.0)
	_sfx_thunder = _ic_player(THUNDER_FILE, -6.0)
	_sfx_shot = AudioStreamPlayer.new()
	_sfx_shot.stream = _ic_make_gunshot()
	_sfx_shot.volume_db = -1.0
	add_child(_sfx_shot)
	_sfx_growl = AudioStreamPlayer.new()
	_sfx_growl.stream = _ic_make_growl()
	_sfx_growl.volume_db = -1.0
	add_child(_sfx_growl)
	_sfx_slash = AudioStreamPlayer.new()
	_sfx_slash.stream = _ic_make_slash()
	_sfx_slash.volume_db = -2.0
	add_child(_sfx_slash)
	_music = _ic_player(INTRO_MUSIC, -34.0)
	if is_instance_valid(_music):
		_music.play()
		create_tween().tween_property(_music, "volume_db", -12.0, 3.0)


## Tiro de revólver sintetizado: estalo agudo + corpo + "thump" grave + eco que morre.
func _ic_make_gunshot() -> AudioStreamWAV:
	var rate: int = 44100
	var n: int = int(float(rate) * 1.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 38
	var lp: float = 0.0
	for i in n:
		var tt: float = float(i) / float(rate)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.30)
		var crack: float = noise * exp(-tt * 60.0)
		var body: float = lp * exp(-tt * 9.0) * 0.8
		var thump: float = sin(TAU * 58.0 * tt) * exp(-tt * 13.0)
		var tail: float = lp * exp(-tt * 3.2) * 0.20
		var s: float = clampf((crack * 0.9 + body + thump * 0.9 + tail) * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## Rugido grave de lobisomem: serra em ~60 Hz com vibrato + ruído filtrado "tremendo" (rosnado).
func _ic_make_growl() -> AudioStreamWAV:
	var rate: int = 44100
	var n: int = int(float(rate) * 1.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lp: float = 0.0
	var ph: float = 0.0
	for i in n:
		var tt: float = float(i) / float(rate)
		var env: float = clampf(tt / 0.12, 0.0, 1.0) * exp(-maxf(tt - 0.55, 0.0) * 1.8)
		var f0: float = 62.0 + 14.0 * sin(TAU * 5.5 * tt) + 22.0 * exp(-tt * 3.0)
		ph += f0 / float(rate)
		var saw: float = fposmod(ph, 1.0) * 2.0 - 1.0
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.18)
		var rattle: float = 0.55 + 0.45 * sin(TAU * 31.0 * tt)
		var s: float = (saw * 0.55 * rattle + lp * 1.2 * rattle + sin(TAU * ph * 2.0) * 0.25) * env
		data.encode_s16(i * 2, int(clampf(s * 0.7, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## Golpe de garra: "swoosh" de ruído com filtro abrindo + estalo de rasgo no início.
func _ic_make_slash() -> AudioStreamWAV:
	var rate: int = 44100
	var dur: float = 0.42
	var n: int = int(float(rate) * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var lp: float = 0.0
	for i in n:
		var tt: float = float(i) / float(rate)
		var k: float = clampf(tt / dur, 0.0, 1.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, lerpf(0.08, 0.6, k))
		var env: float = sin(PI * k)
		var s: float = lp * env * 1.7 + noise * exp(-tt * 55.0) * 0.45
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# ----------------------------------------------------------------------------
# Desenho principal
# ----------------------------------------------------------------------------

func _ic_flash_color() -> Color:
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
	var cx: float = _vw * 0.5
	var hx_stop: float = cx - 120.0

	var spawn: float = _smooth((t - T_SPAWN0) / 3.0)                 # a escuridão se enche de monstros
	var morph: float = _smooth((t - T_MORPH0) / (T_SWAP - T_MORPH0))
	var after: float = _smooth((t - T_SWAP) / 0.6)
	var red: float = morph * (1.0 - after)

	# Batimento do coração: acelera conforme a maldição avança.
	var beat_rate: float = lerpf(2.2, 7.5, morph)
	var beat: float = pow(maxf(sin(t * beat_rate * 2.0), 0.0), 6.0) * morph * (1.0 - after)

	# ---- câmera ----
	var zoom: float = 1.0
	var pan := Vector2.ZERO
	if t < T_STOP:
		var e1: float = _smooth(t / T_STOP)
		zoom = lerpf(1.0, 1.07, e1)
		pan = Vector2(lerpf(80.0, -30.0, e1), 0.0)
	elif t < T_MORPH0:
		var e2: float = _smooth((t - T_STOP) / (T_MORPH0 - T_STOP))
		zoom = lerpf(1.07, 1.15, e2)
		pan = Vector2(lerpf(-30.0, -60.0, e2), 0.0)
	elif t < T_SWAP:
		var e3: float = _smooth((t - T_MORPH0) / (T_SWAP - T_MORPH0))
		zoom = lerpf(1.15, 1.32, e3)
		pan = Vector2(-60.0, lerpf(0.0, -40.0, e3))
	else:
		# Agachado: câmera baixa e próxima; no rugido ela abre para mostrar os monstros.
		var d: float = t - T_SWAP
		var open_k: float = _smooth((t - (T_ROAR - 0.2)) / 1.4)
		zoom = lerpf(1.32, 1.18, _smooth(d / 1.0))
		pan = Vector2(-60.0, -40.0).lerp(Vector2(-30.0, 0.0), _smooth(d / 1.0))
		zoom = lerpf(zoom, 1.03, open_k)
		pan = pan.lerp(Vector2.ZERO, open_k)
		zoom += 0.07 * exp(-absf(t - (T_ROAR + 0.2)) / 0.22)   # soco de câmera no rugido
		zoom += _nw_hit_punch(t)                                # e em cada golpe de garra
	# A câmera sobe para acompanhar o tiro.
	var tilt: float = _smooth((t - T_SHOT + 0.15) / 0.3) - _smooth((t - T_SHOT - 0.9) / 1.4)
	pan.y += 210.0 * tilt
	zoom += 0.04 * tilt
	# No final, aproxima devagar do rosto do lobo (olhos dourados).
	var sk: float = _smooth((t - T_STARE) / 1.6)
	if sk > 0.0:
		var head_p := Vector2(hx_stop + 105.0 * WOLF_SC, 905.0 - 620.0 * WOLF_SC)
		zoom = lerpf(zoom, 1.5, sk)
		pan = pan.lerp((Vector2(cx, DESIGN_H * 0.5) - head_p) * zoom, sk)

	var amp: float = 1.5
	if t < T_MORPH0:
		amp = 1.5 + 5.0 * spawn
	elif t < T_SWAP:
		amp = 4.0 + 14.0 * morph * morph
	else:
		amp = 2.0 + 30.0 * exp(-(t - T_SWAP) / 0.5) + 16.0 * _nw_roar(t) + _nw_hit_shake(t)
	if t >= T_SHOT:
		amp += 40.0 * exp(-(t - T_SHOT) / 0.35)
	var k40: float = floorf(t * 40.0)
	var shake := Vector2(_hsh(k40) - 0.5, _hsh(k40 + 9.1) - 0.5) * 2.0 * amp
	var sway := Vector2(sin(t * 0.7) * 4.0, cos(t * 0.9) * 3.0)
	var s: float = _scale * zoom
	var origin := screen * 0.5 - Vector2(_vw * 0.5, DESIGN_H * 0.5) * s + (pan + sway + shake) * _scale
	draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, origin))

	# ---- cenário ----
	var rise: float = _smooth(t / T_SWAP)
	var moon := Vector2(cx + 260.0, lerpf(470.0, 340.0, rise))
	var moon_r: float = lerpf(170.0, 250.0, rise)
	_ic_scenery(moon, moon_r, red, cx)

	# Nuvens negras cobrem a lua quando a escuridão chega; a transformação as rasga.
	var cover: float = spawn * (1.0 - _smooth((t - T_MORPH0) / 2.5))
	if cover > 0.01:
		for i in 3:
			_glow_ellipse(moon + Vector2(float(i - 1) * 80.0, float(i) * 12.0), moon_r * (2.5 - 0.3 * float(i)), moon_r * 1.15, Color(0.01, 0.01, 0.025, 0.55 * cover))
	# Escurece o mundo (o caçador e os monstros são desenhados por cima, em silhueta).
	var dark: float = 0.42 * spawn * (1.0 - after)
	if dark > 0.01:
		draw_rect(Rect2(-600.0, -800.0, _vw + 1200.0, 2300.0), Color(0.0, 0.0, 0.03, dark))

	_ic_eyes(spawn, after)
	_ic_sky_bolts(t, cx + 260.0)

	# ---- personagens ----
	var p: float = clampf(t / T_STOP, 0.0, 1.0)
	var hx: float = lerpf(-170.0, hx_stop, p * (2.0 - p))
	var walk: float = 1.0 - _smooth((t - (T_STOP - 1.4)) / 1.4)
	var stride: float = hx * 0.035

	_ic_draw_monsters(hx_stop, t, false)
	var wbase := Vector2(hx_stop, 905.0)
	if t < T_SWAP:
		_ic_hunter(Vector2(hx, 880.0), 1.6, morph, beat, stride, walk)
	else:
		_nw_cracks(wbase, WOLF_SC, t - T_SWAP)
		_nw_hat(wbase)
		_ic_wolf(wbase, WOLF_SC, t)
		_ic_raised_arm(t)
		_nw_fx(t)
		_ic_shockwaves(wbase, t - T_SWAP)
	_ic_draw_monsters(hx_stop, t, true)
	_ic_bats(t, cx)
	_ic_rain(spawn)
	_draw_mist(935.0, 0.05)
	_draw_embers(18)

	# ---- pós-processamento em coordenadas de tela ----
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color.WHITE)
	if spawn > 0.01:
		draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, screen), false, Color(1, 1, 1, 0.55 * spawn * (1.0 - after)))
	var red_a: float = (0.05 + 0.20 * beat) * morph * (1.0 - after)
	if red_a > 0.005:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.6, 0.0, 0.02, red_a))

	# Grão de filme.
	var seed_v: float = floorf(t * 24.0)
	for i in 70:
		var fi: float = float(i)
		var gx: float = _hsh(fi * 1.37 + seed_v) * screen.x
		var gy: float = _hsh(fi * 2.11 + seed_v * 1.7) * screen.y
		draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(1, 1, 1, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.10))

	# Clarões (transformação, rugido, garras e disparo).
	var fc: Color = _ic_flash_color()
	if fc.a > 0.01:
		draw_rect(Rect2(Vector2.ZERO, screen), fc)

	# Cartela de fase, legendas e título.
	_ic_chapter(screen)
	_ic_caption(screen, "O castelo do Conde Drácula espera no alto da colina.", 1.2, 6.4)
	_ic_caption(screen, "Mas a escuridão não está vazia...", 7.6, 11.0)
	_ic_caption(screen, "E o fardo do desperta.", 11.6, 15.8)
	_ic_caption(screen, "Agora, quem caça... é o lobo.", 18.8, 21.0)
	_ic_final_title(screen)

	# Dica para pular.
	var hint_a: float = clampf((t - 1.5) / 1.0, 0.0, 0.7) * (1.0 - _smooth((t - (T_FADE - 1.0)) / 0.6))
	if hint_a > 0.01:
		var hfs: int = int(22.0 * _scale)
		draw_string(FONT_BOLD, Vector2(0.0, screen.y * 0.965), "ESC / ENTER — PULAR     ", HORIZONTAL_ALIGNMENT_RIGHT, screen.x, hfs, Color(0.72, 0.67, 0.82, hint_a))

	# Letterbox cinematográfico.
	var bar_h: float = screen.y * 0.075 * _smooth(t / 1.2)
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.95))
	draw_rect(Rect2(0, screen.y - bar_h, screen.x, bar_h), Color(0, 0, 0, 0.95))

	# Sai do preto no começo; escurece no fim ou ao pular.
	var fade: float = 1.0 - _smooth(t / 1.2)
	fade = maxf(fade, _smooth((t - T_FADE) / (T_END - T_FADE)))
	if _skipping:
		fade = maxf(fade, clampf(_skip_t / 0.45, 0.0, 1.0))
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, fade))


## Cartela de abertura da fase.
func _ic_chapter(screen: Vector2) -> void:
	var a: float = _smooth((_total - 0.9) / 0.9) * (1.0 - _smooth((_total - 4.9) / 0.9))
	if a <= 0.01:
		return
	var fs1: int = int(30.0 * _scale)
	var fs2: int = int(84.0 * _scale)
	var y1: float = screen.y * 0.20
	var y2: float = screen.y * 0.20 + float(fs2) * 1.05
	draw_string_outline(FONT_BOLD, Vector2(0.0, y1), "FASE 1", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs1, int(8.0 * _scale) + 2, Color(0.05, 0.0, 0.08, a))
	draw_string(FONT_BOLD, Vector2(0.0, y1), "FASE 1", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs1, Color(0.80, 0.70, 0.95, a))
	draw_string_outline(FONT_BOLD, Vector2(0.0, y2), "A FLORESTA ASSOMBRADA", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs2, int(14.0 * _scale) + 2, Color(0.06, 0.0, 0.08, a))
	draw_string(FONT_BOLD, Vector2(0.0, y2), "A FLORESTA ASSOMBRADA", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs2, Color(0.95, 0.90, 1.0, a))


## Chuva fina (aparece junto com os monstros).
func _ic_rain(a: float) -> void:
	if a <= 0.02:
		return
	for i in 90:
		var fi: float = float(i)
		var x: float = fposmod(_hsh(fi * 1.3) * (_vw + 400.0) - _total * 240.0, _vw + 400.0) - 200.0
		var y: float = fposmod(_hsh(fi * 2.9) * 1300.0 + _total * 1500.0, 1300.0) - 100.0
		draw_line(Vector2(x, y), Vector2(x - 14.0, y + 46.0), Color(0.7, 0.78, 1.0, 0.22 * a * (0.4 + _hsh(fi * 5.1) * 0.6)), 2.0)


func _ic_caption(screen: Vector2, text: String, t0: float, t1: float) -> void:
	var a: float = _smooth((_total - t0) / 0.6) * (1.0 - _smooth((_total - (t1 - 0.6)) / 0.6))
	if a <= 0.01:
		return
	var fs: int = int(46.0 * _scale)
	var y: float = screen.y * 0.90
	draw_string_outline(FONT_BOLD, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs, int(10.0 * _scale) + 2, Color(0.02, 0.0, 0.05, a))
	draw_string(FONT_BOLD, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs, Color(0.96, 0.94, 1.0, a))


func _ic_final_title(screen: Vector2) -> void:
	var a: float = _smooth((_total - (T_STARE + 0.8)) / 0.9)
	if a <= 0.01:
		return
	var punch: float = 1.0 + (1.0 - a) * 0.10
	var fs: int = int(120.0 * _scale * punch)
	var y: float = screen.y * 0.25
	var cxs: float = screen.x * 0.5
	_glow_ellipse(Vector2(cxs, y - float(fs) * 0.3), screen.x * 0.36, float(fs) * 1.0, Color(1.0, 0.05, 0.10, 0.30 * a))
	var edge := Color(0.12, 0.0, 0.02, a)
	var fill := Color(1.0, 0.24, 0.18, a)
	var line := "A CAÇADA COMEÇA"
	draw_string_outline(FONT_BOLD, Vector2(0.0, y), line, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs, int(16.0 * _scale) + 2, edge)
	draw_string(FONT_BOLD, Vector2(0.0, y), line, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs, fill)
	var dy: float = y + float(fs) * 0.18
	var dc := Color(1.0, 0.5, 0.45, 0.8 * a)
	var sp: float = 230.0 * _scale
	draw_line(Vector2(cxs - sp, dy), Vector2(cxs - 24.0 * _scale, dy), dc, 3.0, true)
	draw_line(Vector2(cxs + 24.0 * _scale, dy), Vector2(cxs + sp, dy), dc, 3.0, true)
	var r: float = 10.0 * _scale
	draw_colored_polygon(PackedVector2Array([
		Vector2(cxs, dy - r), Vector2(cxs + r, dy), Vector2(cxs, dy + r), Vector2(cxs - r, dy),
	]), Color(1.0, 0.5, 0.45, 0.9 * a))


# ----------------------------------------------------------------------------
# Cenário: céu, lua, castelo na colina, pinheiros, chão molhado
# ----------------------------------------------------------------------------

func _ic_scenery(moon: Vector2, moon_r: float, red: float, cx: float) -> void:
	var vw: float = _vw
	var top := Color(0.006, 0.008, 0.022).lerp(Color(0.10, 0.0, 0.02), red * 0.55)
	var bottom := Color(0.075, 0.045, 0.13).lerp(Color(0.34, 0.04, 0.06), red * 0.8)
	_draw_vertical_gradient(Rect2(-600.0, -800.0, vw + 1200.0, 2100.0), top, bottom)
	_glow(moon, moon_r * 7.0, Color(0.30, 0.36, 0.85, 0.14).lerp(Color(0.90, 0.15, 0.10, 0.22), red))
	_draw_stars(90)
	_draw_moon(moon, moon_r)
	if red > 0.01:
		draw_circle(moon, moon_r, Color(0.95, 0.10, 0.08, 0.55 * red))
	_draw_god_rays(moon, 0.85 + 0.15 * sin(_total * 0.9))
	_draw_clouds(310.0, Color(0.12, 0.10, 0.19, 0.22), 12.0, 5, 1.7)
	_draw_mountains(720.0, 170.0, Color(0.02, 0.018, 0.045))
	_ic_castle(Vector2(minf(cx + 700.0, vw - 330.0), 735.0), 1.0, red)
	_draw_pines(855.0, Color(0.008, 0.009, 0.018), 260.0, 0.0)
	_draw_dead_tree(vw * 0.10, GROUND - 30.0, 520.0, Color(0.004, 0.004, 0.010), 1)
	_draw_dead_tree(vw * 0.92, GROUND - 20.0, 600.0, Color(0.004, 0.004, 0.010), 2)
	_draw_pines(975.0, Color(0.004, 0.004, 0.010), 360.0, 30.0)

	# Chão molhado com reflexo da lua (e do vermelho da maldição).
	_draw_vertical_gradient(Rect2(-200.0, 845.0, vw + 400.0, 380.0), Color(0.045, 0.045, 0.095), Color(0.004, 0.004, 0.012))
	_glow_ellipse(Vector2(moon.x * 0.6 + vw * 0.2, GROUND + 22.0), 360.0, 26.0, Color(0.55, 0.60, 1.0, 0.16))
	_glow_ellipse(Vector2(cx, GROUND + 12.0), 430.0, 55.0, Color(0.30, 0.28, 0.58, 0.20))
	if red > 0.01:
		_glow_ellipse(Vector2(cx, GROUND + 12.0), 620.0, 70.0, Color(0.85, 0.10, 0.10, 0.20 * red))


func _ic_castle(pos: Vector2, s: float, red: float) -> void:
	var dk := Color(0.004, 0.004, 0.014)
	var warm: Color = Color(1.0, 0.72, 0.30).lerp(Color(1.0, 0.15, 0.10), red)
	_glow_ellipse(_at(pos, s, 40.0, -200.0), 520.0 * s, 300.0 * s, Color(0.9, 0.10, 0.10, 0.18 * red))

	# Colina
	var hill := PackedVector2Array()
	var x: float = -560.0
	while x <= 560.0:
		hill.append(_at(pos, s, x, 70.0 - sin((x + 560.0) / 1120.0 * PI) * 90.0))
		x += 40.0
	var crest := hill.duplicate()
	hill.append(_at(pos, s, 560.0, 300.0))
	hill.append(_at(pos, s, -560.0, 300.0))
	draw_colored_polygon(hill, dk)
	draw_polyline(crest, Color(0.50, 0.55, 0.95, 0.14), 3.0, true)

	# Muralha e ameias
	draw_rect(Rect2(_at(pos, s, -250.0, -190.0), Vector2(580.0, 230.0) * s), dk)
	for i in 22:
		draw_rect(Rect2(_at(pos, s, -250.0 + float(i) * 27.0, -208.0), Vector2(16.0, 18.0) * s), dk)

	# Torres com telhado cônico: [x, largura, altura, altura do telhado]
	var towers: Array = [[-250.0, 64.0, 300.0, 100.0], [-120.0, 52.0, 400.0, 130.0], [70.0, 64.0, 470.0, 150.0], [210.0, 56.0, 360.0, 110.0], [330.0, 60.0, 280.0, 90.0]]
	for tw in towers:
		var tx: float = tw[0]
		var w: float = tw[1]
		var h: float = tw[2]
		var rf: float = tw[3]
		draw_rect(Rect2(_at(pos, s, tx - w * 0.5, -h), Vector2(w, h + 40.0) * s), dk)
		draw_colored_polygon(PackedVector2Array([_at(pos, s, tx - w * 0.5 - 8.0, -h), _at(pos, s, tx, -h - rf), _at(pos, s, tx + w * 0.5 + 8.0, -h)]), dk)
		draw_line(_at(pos, s, tx, -h - rf), _at(pos, s, tx, -h - rf - 40.0), dk, 4.0 * s, true)
		var fl: float = 0.75 + 0.25 * sin(_total * 3.0 + tx)
		var wp: Vector2 = _at(pos, s, tx - 6.0, -h * 0.62)
		_glow(wp + Vector2(6.0, 11.0) * s, 36.0 * s, Color(warm.r, warm.g, warm.b, 0.35 * fl))
		draw_rect(Rect2(wp, Vector2(12.0, 22.0) * s), Color(warm.r, warm.g, warm.b, 0.9 * fl))

	# Janelas do salão e portão
	for i in 8:
		var wx: float = -200.0 + float(i) * 70.0
		var fl2: float = 0.7 + 0.3 * sin(_total * 2.3 + float(i) * 1.7)
		draw_rect(Rect2(_at(pos, s, wx, -130.0), Vector2(10.0, 18.0) * s), Color(warm.r, warm.g, warm.b, 0.75 * fl2))
	_glow(_at(pos, s, 82.0, -10.0), 80.0 * s, Color(warm.r, warm.g, warm.b, 0.22))
	draw_rect(Rect2(_at(pos, s, 60.0, -60.0), Vector2(44.0, 100.0) * s), Color(0.0, 0.0, 0.0, 0.9))


## Pares de olhos acendendo na mata conforme a escuridão se enche de monstros.
func _ic_eyes(spawn: float, after: float) -> void:
	var n: int = int(48.0 * spawn)
	if n <= 0:
		return
	for i in n:
		var fi: float = float(i)
		var x: float = _hsh(fi * 3.17 + 2.0) * (_vw + 200.0) - 100.0
		var y: float = 770.0 + _hsh(fi * 5.71) * 150.0
		var blink: float = clampf(sin(_total * (1.2 + _hsh(fi)) + fi * 2.0) * 3.0 + 1.5, 0.0, 1.0)
		var a: float = blink * (0.5 + 0.4 * _hsh(fi * 9.0)) * (1.0 - after)
		if a <= 0.02:
			continue
		var col := Color(1.0, 0.20, 0.15) if i % 3 == 0 else Color(0.5, 1.0, 0.4)
		var sp: float = 7.0 + 5.0 * _hsh(fi * 1.7)
		for sd in [-1.0, 1.0]:
			var ep := Vector2(x + float(sd) * sp, y)
			_glow(ep, 13.0, Color(col, a * 0.5))
			draw_circle(ep, 2.2, Color(col, a))


# ----------------------------------------------------------------------------
# Monstros que nascem do chão
# ----------------------------------------------------------------------------

func _ic_draw_monsters(hx_stop: float, t: float, front: bool) -> void:
	var fear: float = _nw_roar(t)
	for m in MONSTERS:
		var spawn_t: float = float(m[3])
		var since: float = t - spawn_t
		if since < 0.0:
			continue
		var gy: float = float(m[1])
		if (gy > 925.0) != front:
			continue
		var dir: float = float(m[5])
		var sc: float = float(m[2])
		var kind: int = int(m[4])
		var kill: float = float(m[6])
		var rise: float = _smooth(since / 1.5)
		var x0: float = hx_stop + float(m[0])
		# Avançam em direção ao caçador, recuam na explosão, são empurrados pelo rugido e fogem depois do tiro.
		var approach: float = _smooth(since / maxf(T_SWAP - spawn_t, 0.1)) * 110.0 * dir
		var recoil: float = _smooth((t - T_SWAP) / 0.45) * 140.0 * dir
		var blast: float = _smooth((t - T_ROAR) / 0.3) * 90.0 * dir
		var flee: float = _smooth((t - T_SHOT - 0.25) / 1.1)
		var gx: float = x0 + approach - recoil - blast - dir * 900.0 * flee
		var alpha: float = 1.0 - flee
		if kill > 0.0:
			# Este monstro investe contra o lobo e é despedaçado pelo golpe de garra.
			var lunge: float = _smooth((t - (kill - 0.7)) / 0.55)
			gx = lerpf(gx, hx_stop - dir * 200.0, lunge)
			if t >= kill:
				var dd: float = t - kill
				alpha = 1.0 - _smooth(dd / 0.30)
				gx -= dir * 70.0 * _smooth(dd / 0.3)
				_ic_dissolve(Vector2(gx, gy - 90.0 * sc), sc, dd)
				if dd > 0.5:
					continue
		var pos := Vector2(gx, gy)
		_ic_spawn_fx(Vector2(x0, gy), sc, since)
		_ic_ghoul(pos, sc, rise * (1.0 - 0.18 * fear), dir, kind, spawn_t * 3.1, alpha)


## Monstro virando pó verde quando atingido pelas garras.
func _ic_dissolve(pos: Vector2, sc: float, dd: float) -> void:
	if dd < 0.0 or dd > 1.1:
		return
	var a: float = clampf(1.0 - dd / 1.1, 0.0, 1.0)
	_glow(pos, 170.0 * sc * (0.6 + dd), Color(0.45, 1.0, 0.55, 0.40 * a))
	for i in 26:
		var fi: float = float(i)
		var ang: float = TAU * _hsh(fi * 2.3)
		var sp: float = 120.0 + 380.0 * _hsh(fi * 5.9)
		var pp: Vector2 = pos + Vector2.from_angle(ang) * sp * dd * sc + Vector2(0.0, 260.0 * dd * dd)
		draw_circle(pp, (2.0 + 4.0 * _hsh(fi * 8.7)) * sc, Color(0.55, 1.0, 0.6, a))


func _ic_spawn_fx(pos: Vector2, sc: float, since: float) -> void:
	if since > 2.2:
		return
	var a: float = clampf(1.0 - since / 2.2, 0.0, 1.0)
	_glow_ellipse(pos + Vector2(0.0, 8.0), 150.0 * sc, 24.0 * sc, Color(0.25, 1.0, 0.45, 0.38 * a))
	_glow_ellipse(pos + Vector2(0.0, 8.0), 60.0 * sc, 12.0 * sc, Color(0.8, 1.0, 0.8, 0.30 * a))
	for i in 12:
		var fi: float = float(i)
		var ph: float = fposmod(since * 0.7 + _hsh(fi * 2.3), 1.0)
		var px: float = (_hsh(fi * 4.1) - 0.5) * 120.0 * sc
		draw_circle(pos + Vector2(px, -ph * 260.0 * sc), (2.0 + 3.0 * _hsh(fi * 6.3)) * sc, Color(0.45, 1.0, 0.55, (1.0 - ph) * 0.8 * a))


func _ic_m(pos: Vector2, sc: float, rise: float, dir: float, x: float, y: float) -> Vector2:
	return pos + Vector2(x * dir * sc, y * sc * rise)


## Ghoul em silhueta que cresce do chão (rise 0..1). dir: +1 olha para a direita, -1 para a esquerda.
func _ic_ghoul(pos: Vector2, sc: float, rise: float, dir: float, kind: int, ph: float, alpha: float) -> void:
	if rise < 0.08 or alpha <= 0.02:
		return
	var hh: float = [190.0, 235.0, 150.0][kind]
	var lean: float = [26.0, 12.0, 46.0][kind]
	var sil := Color(0.003, 0.004, 0.010, alpha)
	var rim := Color(0.55, 0.62, 1.0, 0.28 * alpha)
	var eye_c := Color(0.55, 1.0, 0.45) if kind != 1 else Color(1.0, 0.22, 0.12)
	var sway: float = sin(_total * 2.2 + ph) * 5.0
	var reach: float = sin(_total * 2.6 + ph) * 10.0

	var body := PackedVector2Array([
		_ic_m(pos, sc, rise, dir, -24.0, 0.0),
		_ic_m(pos, sc, rise, dir, -30.0, -hh * 0.45),
		_ic_m(pos, sc, rise, dir, -20.0 + sway * 0.5, -hh * 0.80),
		_ic_m(pos, sc, rise, dir, lean - 8.0 + sway, -hh * 0.96),
		_ic_m(pos, sc, rise, dir, lean + 16.0 + sway, -hh * 0.92),
		_ic_m(pos, sc, rise, dir, lean + 28.0, -hh * 0.68),
		_ic_m(pos, sc, rise, dir, 30.0, -hh * 0.38),
		_ic_m(pos, sc, rise, dir, 36.0, 0.0),
	])
	draw_colored_polygon(body, sil)
	draw_polyline(PackedVector2Array([body[1], body[2], body[3]]), rim, 3.0 * sc, true)

	# Braços compridos esticados para a frente, com garras.
	var sh_l := Vector2(lean, -hh * 0.82)
	var el_l := Vector2(lean + 36.0, -hh * 0.54)
	var hd_l := Vector2(lean + 74.0 + reach, -hh * 0.22 - reach * 0.5)
	var sh: Vector2 = _ic_m(pos, sc, rise, dir, sh_l.x, sh_l.y)
	var el: Vector2 = _ic_m(pos, sc, rise, dir, el_l.x, el_l.y)
	var hd: Vector2 = _ic_m(pos, sc, rise, dir, hd_l.x, hd_l.y)
	draw_line(sh, el, sil, 13.0 * sc, true)
	draw_line(el, hd, sil, 10.0 * sc, true)
	for i in 3:
		var tip: Vector2 = _ic_m(pos, sc, rise, dir, hd_l.x + 22.0, hd_l.y + float(i - 1) * 10.0 + 10.0)
		draw_line(hd, tip, Color(0.80, 0.80, 0.70, 0.8 * alpha), 3.0 * sc, true)
	var back_hd: Vector2 = _ic_m(pos, sc, rise, dir, lean + 44.0 - reach * 0.5, -hh * 0.14)
	draw_line(_ic_m(pos, sc, rise, dir, lean - 4.0, -hh * 0.82), back_hd, sil, 11.0 * sc, true)

	# Cabeça, chifres/focinho conforme o tipo.
	var head: Vector2 = _ic_m(pos, sc, rise, dir, lean + 6.0 + sway, -hh * 1.04)
	draw_circle(head, 17.0 * sc, sil)
	if kind == 1:
		draw_colored_polygon(PackedVector2Array([
			_ic_m(pos, sc, rise, dir, lean - 4.0, -hh * 1.10), _ic_m(pos, sc, rise, dir, lean - 12.0, -hh * 1.32), _ic_m(pos, sc, rise, dir, lean + 6.0, -hh * 1.12)]), sil)
		draw_colored_polygon(PackedVector2Array([
			_ic_m(pos, sc, rise, dir, lean + 10.0, -hh * 1.12), _ic_m(pos, sc, rise, dir, lean + 22.0, -hh * 1.32), _ic_m(pos, sc, rise, dir, lean + 22.0, -hh * 1.08)]), sil)
	elif kind == 2:
		draw_colored_polygon(PackedVector2Array([
			_ic_m(pos, sc, rise, dir, lean + 14.0, -hh * 1.08), _ic_m(pos, sc, rise, dir, lean + 44.0, -hh * 1.01), _ic_m(pos, sc, rise, dir, lean + 14.0, -hh * 0.97)]), sil)

	# Olhos brilhando (acendem quando já estão quase em pé).
	var er: float = clampf((rise - 0.5) / 0.5, 0.0, 1.0) * alpha
	if er > 0.01:
		var eye_p: Vector2 = _ic_m(pos, sc, rise, dir, lean + 16.0 + sway, -hh * 1.06)
		var flick: float = 0.8 + 0.2 * sin(_total * 9.0 + ph)
		_glow(eye_p, 24.0 * sc * flick, Color(eye_c, 0.55 * er))
		draw_circle(eye_p, 3.0 * sc, Color(eye_c.r, eye_c.g, eye_c.b, er))


# ----------------------------------------------------------------------------
# Efeitos da transformação e do tiro
# ----------------------------------------------------------------------------

## Raios cortando o céu a cada clarão frio, até a explosão.
func _ic_sky_bolts(t: float, cx: float) -> void:
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
func _ic_shockwaves(base: Vector2, dt: float) -> void:
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
func _ic_transform_fx(base: Vector2, k: float, morph: float) -> void:
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
		var fi2: float = float(i)
		var ph: float = fposmod(_total * (0.35 + 0.4 * _hsh(fi2 * 1.9)) + _hsh(fi2 * 6.1), 1.0)
		var px: float = (_hsh(fi2 * 2.3) - 0.5) * 300.0 + sin(_total * 2.0 + fi2) * 20.0
		var pp: Vector2 = o + Vector2(px, -ph * 520.0) * k
		var rad: float = (1.5 + 3.5 * _hsh(fi2 * 3.7)) * (1.0 - ph * 0.5)
		draw_circle(pp, rad, Color(1.0, 0.45 + 0.4 * (1.0 - ph), 0.15, (1.0 - ph) * 0.9 * morph))


## Clarão do disparo, estrela de fogo, projétil traçante subindo, onda de choque e fumaça.
func _ic_muzzle_fx(m: Vector2, u: Vector2, d: float, sc: float) -> void:
	var f: float = exp(-d / 0.10)
	_glow(m, (300.0 + 500.0 * f) * sc, Color(1.0, 0.85, 0.45, 0.55 * f))
	_glow(m, 120.0 * sc, Color(1.0, 1.0, 0.9, 0.9 * f))
	for i in 9:
		var fi: float = float(i)
		var ang: float = u.angle() + (fi - 4.0) * 0.32 + (_hsh(fi * 3.3) - 0.5) * 0.2
		var ln: float = (90.0 + 170.0 * _hsh(fi * 1.9)) * sc * f
		draw_line(m, m + Vector2.from_angle(ang) * ln, Color(1.0, 0.9, 0.5, 0.9 * f), 5.0 * sc * f + 1.0, true)
	if d < 1.2:
		var life: float = 1.0 - d / 1.2
		var head: Vector2 = m + u * (d * 2600.0)
		var tail: Vector2 = m + u * (maxf(d - 0.12, 0.0) * 2600.0)
		draw_line(tail, head, Color(1.0, 0.95, 0.7, 0.9 * life), 4.0, true)
		_glow(head, 40.0, Color(1.0, 0.9, 0.6, 0.6 * life))
	var ring: float = clampf(1.0 - d / 0.6, 0.0, 1.0)
	if ring > 0.0:
		draw_arc(m, d * 900.0 * sc + 10.0, 0.0, TAU, 64, Color(1.0, 0.9, 0.7, 0.5 * ring), 5.0 * sc + 1.0, true)
	var smoke: float = clampf(1.0 - d / 1.7, 0.0, 1.0)
	for i in 7:
		var fi2: float = float(i)
		var sp: Vector2 = m + u * (40.0 + d * (50.0 + 30.0 * fi2)) * sc + Vector2((_hsh(fi2 * 2.1) - 0.5) * 80.0 * d, 0.0)
		draw_circle(sp, (12.0 + 26.0 * d + fi2 * 3.0) * sc, Color(0.75, 0.75, 0.80, 0.16 * smoke))


## Morcegos saindo do castelo depois do tiro.
func _ic_bats(t: float, cx: float) -> void:
	if t < T_SHOT:
		return
	var d: float = t - T_SHOT
	var origin := Vector2(minf(cx + 700.0, _vw - 330.0) + 60.0, 430.0)
	for i in 18:
		var fi: float = float(i)
		var ang: float = -PI * (0.05 + 0.9 * _hsh(fi * 2.9))
		var sp: float = 260.0 + 380.0 * _hsh(fi * 4.7)
		var pos: Vector2 = origin + Vector2.from_angle(ang) * (sp * d) + Vector2(sin(d * 5.0 + fi) * 20.0, 0.0)
		_ic_bat(pos, 0.6 + _hsh(fi * 7.3) * 0.8, fi * 1.7)


func _ic_bat(pos: Vector2, s: float, phase: float) -> void:
	var col := Color(0.01, 0.006, 0.02)
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
			pos + Vector2(0.0, 9.0 * s),
		]), col)
	draw_circle(pos + Vector2(0.0, 2.0 * s), 6.0 * s, col)


# ----------------------------------------------------------------------------
# O NOVO LOBO (perfil, pelo roxo, olhos dourados) - desenhado só aqui.
# Fases: agachado ofegando -> levanta -> RUGE -> garra p/ direita -> garra p/ esquerda
#        -> ergue o .38 e atira -> encara a câmera.
# Todos os pontos são "locais" (pés em (0,0), y negativo = para cima, olhando para +x)
# e passam por _nw() para ganhar escala, posição e espelhamento (virar para a esquerda).
# ----------------------------------------------------------------------------

func _nw(p: Vector2) -> Vector2:
	return _nw_base + Vector2(p.x * _nw_f, p.y) * _nw_sc


## Ponto no sistema da cabeça (origem no centro do crânio) -> local do lobo.
func _nh(p: Vector2) -> Vector2:
	return _nw_hd + p.rotated(_nw_ha)


func _nw_poly(pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_nw(q as Vector2))
	draw_colored_polygon(out, col)


func _nw_hpoly(pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_nw(_nh(q as Vector2)))
	draw_colored_polygon(out, col)


func _nw_limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var pa: Vector2 = _nw(a)
	var pb: Vector2 = _nw(b)
	draw_line(pa, pb, col, w * _nw_sc, true)
	draw_circle(pa, w * _nw_sc * 0.5, col)
	draw_circle(pb, w * _nw_sc * 0.5, col)


func _nw_leg(hip: Vector2, knee: Vector2, ankle: Vector2, toe: Vector2, col: Color, claw: Color) -> void:
	_nw_limb(hip, knee, 78.0, col)
	_nw_limb(knee, ankle, 52.0, col)
	_nw_limb(ankle, toe, 32.0, col)
	for i in 3:
		var o: float = float(i) * 8.0 - 8.0
		draw_line(_nw(toe + Vector2(-4.0, o * 0.3)), _nw(toe + Vector2(24.0, o * 0.3 + 6.0)), claw, 4.0 * _nw_sc, true)


func _nw_face(t: float) -> float:
	# vira para a esquerda no 2º golpe e volta para a direita para mirar o .38
	var f: float = lerpf(1.0, -1.0, _smooth((t - (T_SLASH2 - 0.6)) / 0.22))
	f = lerpf(f, 1.0, _smooth((t - (T_RAISE - 0.35)) / 0.25))
	return f


func _nw_roar(t: float) -> float:
	return _smooth((t - T_ROAR) / 0.25) * (1.0 - _smooth((t - (T_ROAR + 1.1)) / 0.4))


## x = armar o golpe (braço para trás), y = golpe de fato.
func _nw_slash(t: float, tk: float) -> Vector2:
	var wind: float = _smooth((t - (tk - 0.34)) / 0.30) * (1.0 - _smooth((t - (tk + 0.10)) / 0.30))
	var strike: float = _smooth((t - (tk - 0.05)) / 0.10) * (1.0 - _smooth((t - (tk + 0.12)) / 0.30))
	return Vector2(wind, strike)


func _nw_hit_shake(t: float) -> float:
	var s: float = 0.0
	for tk in [T_SLASH1, T_SLASH2]:
		var dt: float = t - float(tk)
		if dt >= 0.0:
			s += 14.0 * exp(-dt / 0.15)
	return s


func _nw_hit_punch(t: float) -> float:
	var s: float = 0.0
	for tk in [T_SLASH1, T_SLASH2]:
		var dt: float = t - float(tk)
		if dt >= 0.0:
			s += 0.04 * exp(-dt / 0.12)
	return s


## 0 = braço da arma abaixado, 1 = erguido (o mesmo cálculo é usado pelo braço do .38 e pelo braço livre).
func _nw_gun(t: float) -> float:
	var r: float = _smooth((t - T_RAISE) / (T_SHOT - T_RAISE - 0.15))
	var lower: float = _smooth((t - T_SHOT - 1.1) / 0.9)
	return r * (1.0 - lower)


func _ic_wolf(base: Vector2, sc: float, t: float) -> void:
	var f: float = _nw_face(t)
	if absf(f) < 0.08:
		f = 0.08 if f >= 0.0 else -0.08
	_nw_base = base
	_nw_sc = sc
	_nw_f = f

	var d: float = t - T_SWAP
	var up: float = _smooth((d - 0.9) / 1.0)
	var crouch: float = 1.0 - up
	var heave: float = sin(t * 8.0) * (0.35 + 0.65 * crouch)
	var roar: float = _nw_roar(t)
	var stare: float = _smooth((t - T_STARE) / 1.2)
	var gun_r: float = _nw_gun(t)
	var kick: float = exp(-(t - T_SHOT) / 0.2) if t >= T_SHOT else 0.0
	var s1: Vector2 = _nw_slash(t, T_SLASH1)
	var s2: Vector2 = _nw_slash(t, T_SLASH2)
	var wind: float = clampf(s1.x + s2.x, 0.0, 1.0)
	var strike: float = clampf(s1.y + s2.y, 0.0, 1.0)

	# Paleta: quase preto + roxo profundo, com recorte frio da lua e olhos dourados.
	var fur_dark := Color(0.018, 0.010, 0.030)
	var fur_shadow := Color(0.045, 0.020, 0.070)
	var fur := Color(0.095, 0.038, 0.145)
	var fur_mid := Color(0.145, 0.065, 0.205)
	var fur_light := Color(0.38, 0.23, 0.58, 0.78)
	var rim := Color(0.68, 0.56, 1.0, 0.68)
	var chest := Color(0.18, 0.075, 0.24)
	var mouth := Color(0.20, 0.008, 0.025)
	var gum := Color(0.52, 0.035, 0.08)
	var claw := Color(0.97, 0.91, 0.74)
	var eye := Color(1.0, 0.78, 0.16)
	var eye_hot := Color(1.0, 0.95, 0.55)

	# ---------------------------------------------------------------------
	# ANATOMIA
	# ---------------------------------------------------------------------
	var hip := Vector2(-18.0, lerpf(-305.0, -175.0, crouch) + heave * 2.0)
	var pelvis := Vector2(14.0, lerpf(-330.0, -190.0, crouch) + heave * 2.5)
	var sho := Vector2(lerpf(66.0, 142.0, crouch), lerpf(-585.0, -315.0, crouch) + heave * 5.0)
	sho += Vector2(42.0 * roar + 54.0 * strike - 22.0 * wind - 14.0 * kick, 20.0 * roar + 16.0 * strike)
	_nw_S = sho
	var rib: Vector2 = pelvis.lerp(sho, 0.48)

	var thigh_front := Vector2(92.0, lerpf(-165.0, -110.0, crouch))
	var shin_front := Vector2(-18.0, lerpf(-72.0, -34.0, crouch))
	var foot_front := Vector2(70.0, 0.0)
	var thigh_back := Vector2(-76.0, lerpf(-145.0, -104.0, crouch))
	var shin_back := Vector2(-72.0, lerpf(-62.0, -30.0, crouch))
	var foot_back := Vector2(-48.0, 0.0)

	var jaw_open: float = roar * (0.88 + 0.08 * sin(t * 34.0)) + 0.28 * stare + 0.52 * strike + 0.10 * crouch * (0.5 + 0.5 * sin(t * 8.0))
	jaw_open = clampf(jaw_open, 0.0, 1.1)
	_nw_hd = sho + Vector2(lerpf(56.0, 52.0, crouch) + 18.0 * roar + 10.0 * strike, lerpf(-92.0, -18.0, crouch) + 12.0 * roar + 28.0 * stare)
	_nw_ha = lerpf(0.04, 0.36, crouch) - 0.40 * roar + 0.20 * stare - 0.10 * wind

	# Sombra no chão.
	_glow_ellipse(base + Vector2(18.0, 24.0) * sc, 235.0 * sc, 24.0 * sc, Color(0, 0, 0, 0.72))
	_glow_ellipse(base + Vector2(22.0, 8.0) * sc, 150.0 * sc, 14.0 * sc, Color(0.22, 0.03, 0.30, 0.16))

	# ---------------------------------------------------------------------
	# MEMBROS DE TRÁS / CAUDA
	# ---------------------------------------------------------------------
	_nw_leg(hip + Vector2(-26.0, 10.0), thigh_back + Vector2(-50.0, 8.0), shin_back + Vector2(-30.0, 0.0), foot_back, fur_dark, claw)
	var far_el: Vector2 = sho + Vector2(-14.0, 145.0)
	var far_wr: Vector2 = sho + Vector2(lerpf(-35.0, 42.0, crouch), lerpf(305.0, 270.0, crouch))
	_nw_limb(sho + Vector2(-16.0, -2.0), far_el, 54.0, fur_dark)
	_nw_limb(far_el, far_wr, 40.0, fur_dark)

	# Cauda longa e pesada, com ponta bifurcada de pelo.
	var tail0: Vector2 = hip + Vector2(-58.0, 28.0)
	var tail_prev: Vector2 = tail0
	for i in range(1, 9):
		var fi: float = float(i)
		var tp: Vector2 = tail0 + Vector2(-30.0 * fi, 14.0 * fi - 2.6 * fi * fi + sin(t * 2.6 + fi * 0.75) * (5.0 + fi))
		var tw: float = 48.0 - 4.5 * fi
		_nw_limb(tail_prev, tp, tw, fur_shadow if i < 5 else fur_dark)
		if i >= 6:
			_nw_poly([tp + Vector2(-7.0, -6.0), tp + Vector2(-42.0, -26.0 - fi * 2.0), tp + Vector2(-16.0, 8.0)], fur_shadow)
			tail_prev = tp
		else:
			tail_prev = tp

	# Farrapos do casaco antigo, ainda presos na cintura.
	for i in 4:
		var fi2: float = float(i)
		var c0: Vector2 = pelvis + Vector2(-55.0 + fi2 * 28.0, 0.0)
		var c1: Vector2 = c0 + Vector2(-92.0 - fi2 * 18.0 + 20.0 * sin(t * 4.6 + fi2), 78.0 + 35.0 * fi2)
		_nw_limb(c0, c1, 18.0 - fi2 * 2.5, fur_dark)

	# ---------------------------------------------------------------------
	# SILHUETA DO TORSO — ombros largos, cintura estreita e peito felpudo
	# ---------------------------------------------------------------------
	_nw_poly([
		hip + Vector2(-70.0, 45.0),
		pelvis + Vector2(-70.0, -18.0),
		rib + Vector2(-112.0, -34.0),
		sho + Vector2(-92.0, -32.0),
		sho + Vector2(-24.0, -84.0),
		sho + Vector2(58.0, -54.0),
		sho + Vector2(94.0, 4.0),
		rib + Vector2(72.0, 62.0),
		pelvis + Vector2(56.0, 74.0),
		hip + Vector2(42.0, 58.0),
	], fur_dark)
	_nw_poly([
		pelvis + Vector2(-58.0, 18.0),
		rib + Vector2(-92.0, -22.0),
		sho + Vector2(-72.0, -18.0),
		sho + Vector2(34.0, -28.0),
		rib + Vector2(58.0, 45.0),
		pelvis + Vector2(40.0, 58.0),
	], fur)

	# Deltóides / peitorais e abdômen em camadas.
	_nw_poly([sho + Vector2(-78.0, -22.0), rib + Vector2(-8.0, -36.0), rib + Vector2(18.0, 10.0), sho + Vector2(-16.0, 46.0)], fur_mid)
	_nw_poly([sho + Vector2(10.0, -34.0), sho + Vector2(76.0, 2.0), rib + Vector2(56.0, 46.0), rib + Vector2(12.0, 10.0)], fur_mid)
	_nw_poly([rib + Vector2(-18.0, 20.0), rib + Vector2(42.0, 22.0), pelvis + Vector2(30.0, 48.0), pelvis + Vector2(-22.0, 40.0)], chest)
	_nw_poly([rib + Vector2(-8.0, 66.0), rib + Vector2(40.0, 68.0), pelvis + Vector2(28.0, 104.0), pelvis + Vector2(-8.0, 94.0)], fur_shadow)

	# Linha da coluna + tufos agressivos nas costas.
	var back: Array = [hip + Vector2(-68.0, 34.0), rib + Vector2(-112.0, -28.0), sho + Vector2(-94.0, -24.0), sho + Vector2(-22.0, -78.0)]
	for i in 20:
		var fi3: float = float(i)
		var sg: float = fi3 / 19.0 * 3.0
		var idx: int = mini(int(sg), 2)
		var lt: float = sg - float(idx)
		var a_pt: Vector2 = back[idx]
		var b_pt: Vector2 = back[idx + 1]
		var bp: Vector2 = a_pt.lerp(b_pt, lt)
		var tg: Vector2 = (b_pt - a_pt).normalized()
		var nrm := Vector2(tg.y, -tg.x)
		var ln: float = (22.0 + 28.0 * _hsh(fi3 * 3.7)) * (1.0 + 0.9 * roar + 0.55 * strike + 0.20 * crouch)
		_nw_poly([bp - tg * 10.0, bp + nrm * ln + tg * 8.0, bp + tg * 10.0], fur_shadow if i % 3 else fur_mid)
	_nw_poly([sho + Vector2(-92.0, -24.0), sho + Vector2(-70.0, -74.0), sho + Vector2(-20.0, -90.0), sho + Vector2(-44.0, -24.0)], fur_mid)

	# Pequenas cicatrizes no peito/costas para dar identidade.
	for i in 3:
		var sy: float = 34.0 + float(i) * 28.0
		draw_line(_nw(rib + Vector2(30.0 + float(i) * 4.0, sy)), _nw(rib + Vector2(58.0 + float(i) * 5.0, sy + 12.0)), Color(0.62, 0.12, 0.25, 0.42), 4.0 * sc, true)

	# ---------------------------------------------------------------------
	# PERNA DA FRENTE — postura de predador
	# ---------------------------------------------------------------------
	_nw_leg(pelvis + Vector2(32.0, 6.0), thigh_front, shin_front, foot_front, fur, claw)
	_nw_poly([thigh_front + Vector2(-32.0, -5.0), thigh_front + Vector2(22.0, -38.0), shin_front + Vector2(26.0, -14.0), shin_front + Vector2(-34.0, 8.0)], fur_mid)
	_nw_poly([shin_front + Vector2(-28.0, -8.0), shin_front + Vector2(14.0, -18.0), foot_front + Vector2(-18.0, -4.0), foot_front + Vector2(-40.0, 15.0)], fur_shadow)
	# Garra do pé em três lâminas.
	for i in 4:
		var fo: float = (float(i) - 1.5) * 9.0
		var fp: Vector2 = foot_front + Vector2(22.0, fo * 0.55)
		draw_line(_nw(fp), _nw(fp + Vector2(34.0, fo * 0.08 + 7.0)), claw, 5.0 * sc, true)

	# ---------------------------------------------------------------------
	# PESCOÇO + CABEÇA — crânio grande, focinho canino e mandíbula de monstro
	# ---------------------------------------------------------------------
	_nw_limb(sho + Vector2(8.0, -34.0), _nw_hd + Vector2(-18.0, 22.0), 92.0, fur)
	_nw_poly([
		_nw_hd + Vector2(-52.0, 16.0),
		_nw_hd + Vector2(-20.0, -56.0),
		_nw_hd + Vector2(26.0, -72.0),
		_nw_hd + Vector2(62.0, -28.0),
		_nw_hd + Vector2(58.0, 32.0),
		_nw_hd + Vector2(14.0, 58.0),
	], fur_shadow)
	# Queixo / mandíbula.
	_nw_hpoly([
		Vector2(-16.0, 4.0), Vector2(46.0, 4.0), Vector2(96.0, 24.0),
		Vector2(92.0, 46.0), Vector2(54.0, 66.0), Vector2(-4.0, 38.0)
	], fur)
	# Focinho alongado.
	_nw_hpoly([
		Vector2(18.0, -30.0), Vector2(72.0, -24.0), Vector2(124.0, -4.0),
		Vector2(132.0, 18.0), Vector2(104.0, 32.0), Vector2(28.0, 26.0)
	], fur_mid)
	# Nariz grande.
	_nw_hpoly([
		Vector2(112.0, -6.0), Vector2(136.0, -1.0), Vector2(127.0, 15.0),
		Vector2(106.0, 13.0)
	], fur_dark)
	_nw_hpoly([Vector2(112.0, -3.0), Vector2(129.0, 1.0), Vector2(124.0, 6.0), Vector2(112.0, 5.0)], Color(0.12, 0.035, 0.10))

	# Orelhas altas e rasgadas.
	var ear_push: float = 20.0 * roar
	_nw_hpoly([Vector2(-40.0, -22.0), Vector2(-64.0 - ear_push, -118.0), Vector2(-4.0, -76.0)], fur)
	_nw_hpoly([Vector2(2.0, -48.0), Vector2(22.0 - ear_push, -132.0), Vector2(48.0, -52.0)], fur_mid)
	_nw_hpoly([Vector2(-43.0, -34.0), Vector2(-51.0 - ear_push, -97.0), Vector2(-16.0, -64.0)], Color(0.30, 0.055, 0.16))
	_nw_hpoly([Vector2(8.0, -54.0), Vector2(19.0 - ear_push, -110.0), Vector2(36.0, -58.0)], Color(0.30, 0.055, 0.16))

	# Topo do crânio com recorte de pelos.
	_nw_hpoly([
		Vector2(-36.0, -38.0), Vector2(-8.0, -82.0), Vector2(24.0, -62.0),
		Vector2(58.0, -42.0), Vector2(28.0, 2.0), Vector2(-18.0, 8.0)
	], fur_mid)
	for i in 6:
		var fi4: float = float(i)
		_nw_hpoly([
			Vector2(-18.0 + fi4 * 11.0, -68.0 + absf(2.0 - fi4) * 3.0),
			Vector2(-2.0 + fi4 * 11.0, -100.0 - fi4 * 2.0),
			Vector2(10.0 + fi4 * 11.0, -70.0)
		], fur)

	# Olho luminoso com sobrancelha pesada.
	var eye_p: Vector2 = _nw(_nh(Vector2(45.0, -20.0)))
	var eye_scale: float = 1.0 + 0.55 * roar + 1.15 * stare
	_glow(eye_p, 58.0 * sc * eye_scale, Color(1.0, 0.55, 0.04, 0.48))
	_nw_hpoly([Vector2(24.0, -34.0), Vector2(68.0, -22.0), Vector2(38.0, -6.0)], eye)
	draw_line(_nw(_nh(Vector2(34.0, -20.0))), _nw(_nh(Vector2(58.0, -17.0))), Color(0.035, 0.0, 0.0), 5.0 * sc, true)
	_nw_hpoly([Vector2(38.0, -22.0), Vector2(45.0, -19.0), Vector2(42.0, -7.0), Vector2(36.0, -10.0)], Color(0.02, 0.0, 0.0))
	_glow(eye_p, 20.0 * sc * eye_scale, Color(1.0, 0.82, 0.20, 0.72))

	# Sobrancelha / ponte nasal.
	_nw_hpoly([Vector2(15.0, -44.0), Vector2(74.0, -42.0), Vector2(64.0, -20.0), Vector2(26.0, -17.0)], fur_dark)
	_nw_hpoly([Vector2(60.0, -24.0), Vector2(104.0, -6.0), Vector2(83.0, 8.0), Vector2(52.0, -4.0)], fur)

	# Boca abre no rugido — interior escuro + gengiva + fileira dupla de dentes.
	var jp := Vector2(26.0, 18.0)
	var lower_jaw: float = jaw_open
	if lower_jaw > 0.03:
		_nw_hpoly([jp, jp + Vector2(92.0, -4.0), jp + Vector2(96.0, 20.0)], mouth)
		_nw_hpoly([jp + Vector2(10.0, 2.0), jp + Vector2(88.0, 4.0), jp + Vector2(78.0, 14.0)], gum)
		for i in 6:
			var tooth_x: float = 38.0 + float(i) * 13.0
			var tooth_h: float = 18.0 + 16.0 * clampf(lower_jaw * 1.4, 0.0, 1.0) + (6.0 if i % 2 == 0 else 0.0)
			_nw_hpoly([Vector2(tooth_x, 4.0), Vector2(tooth_x + 8.0, 4.0), Vector2(tooth_x + 4.0, 4.0 + tooth_h)], claw)
		for i in 4:
			var tooth_x2: float = 48.0 + float(i) * 15.0
			_nw_hpoly([Vector2(tooth_x2, 20.0 + lower_jaw * 5.0), Vector2(tooth_x2 + 8.0, 20.0 + lower_jaw * 5.0), Vector2(tooth_x2 + 4.0, 5.0)], claw)
	# Mandíbula inferior cheia de pelo.
	_nw_hpoly([Vector2(22.0, 20.0), Vector2(106.0, 28.0), Vector2(82.0, 52.0), Vector2(28.0, 42.0)], fur_shadow)
	for i in 4:
		var qx: float = 28.0 + float(i) * 18.0
		_nw_hpoly([Vector2(qx, 38.0), Vector2(qx + 10.0, 40.0), Vector2(qx + 4.0, 58.0)], fur)

	# Pelos laterais do maxilar.
	for i in 7:
		var fi5: float = float(i)
		_nw_poly([
			_nh(Vector2(-6.0 + fi5 * 7.0, 30.0)),
			_nh(Vector2(12.0 + fi5 * 7.0, 44.0 + (fi5 - 3.0) * 2.0)),
			_nh(Vector2(2.0 + fi5 * 7.0, 58.0))
		], fur_mid)

	# ---------------------------------------------------------------------
	# BRAÇO LIVRE — musculatura + quatro lâminas de garra
	# ---------------------------------------------------------------------
	if gun_r < 0.03:
		var sh2: Vector2 = sho + Vector2(10.0, -10.0)
		var hang_el: Vector2 = sho + Vector2(lerpf(58.0, 45.0, crouch), 158.0)
		var hang_wr: Vector2 = sho + Vector2(lerpf(36.0, 102.0, crouch), lerpf(325.0, 286.0, crouch))
		hang_el += Vector2(56.0, -34.0) * roar
		hang_wr += Vector2(100.0, -134.0) * roar
		var wind_el: Vector2 = sho + Vector2(-58.0, -70.0)
		var wind_wr: Vector2 = sho + Vector2(-132.0, -185.0)
		var str_el: Vector2 = sho + Vector2(142.0, 112.0)
		var str_wr: Vector2 = sho + Vector2(270.0, 240.0)
		var el: Vector2 = hang_el.lerp(wind_el, wind).lerp(str_el, strike)
		var wr: Vector2 = hang_wr.lerp(wind_wr, wind).lerp(str_wr, strike)
		_nw_limb(sh2, el, 72.0, fur)
		_nw_limb(el, wr, 56.0, fur_mid)
		# brilho muscular.
		draw_polyline(PackedVector2Array([_nw(sh2 + Vector2(30.0, -8.0)), _nw(el + Vector2(26.0, -2.0)), _nw(wr + Vector2(18.0, -4.0))]), rim, 4.0 * sc, true)
		draw_circle(_nw(wr), 31.0 * sc, fur)
		var ad: Vector2 = (wr - el).normalized()
		var ap := Vector2(-ad.y, ad.x)
		for i in 4:
			var o: float = (float(i) - 1.5) * 12.0
			var c_a: Vector2 = wr + ap * o
			draw_line(_nw(c_a), _nw(c_a + ad * (56.0 + 8.0 * float(i % 2)) + ap * o * 0.26), claw, 5.5 * sc, true)
		# Anéis de pelo no antebraço.
		for i in 3:
			var p_ring: Vector2 = el.lerp(wr, (float(i) + 0.25) / 3.2)
			draw_arc(_nw(p_ring), 34.0 * sc, 0.3, 2.6, 12, fur_light, 5.0 * sc, true)

	# Recorte frio de pelo no contorno para destacar o corpo contra a lua.
	draw_polyline(PackedVector2Array([
		_nw(sho + Vector2(-22.0, -84.0)),
		_nw(sho + Vector2(58.0, -54.0)),
		_nw(sho + Vector2(94.0, 4.0)),
		_nw(rib + Vector2(72.0, 62.0)),
		_nw(pelvis + Vector2(56.0, 74.0))
	]), rim, 4.0 * sc, true)

	# Feixe visual muito sutil dos olhos durante o rugido/encarada.
	var beam: float = clampf(roar + stare, 0.0, 1.0)
	if beam > 0.02:
		var bd := Vector2(_nw_f * cos(_nw_ha), sin(_nw_ha))
		draw_line(eye_p, eye_p + bd * (210.0 + 430.0 * stare) * sc, Color(1.0, 0.82, 0.22, 0.18 * beam), 8.0 * sc, true)
		draw_line(eye_p, eye_p + bd * (130.0 + 250.0 * stare) * sc, Color(1.0, 0.96, 0.62, 0.42 * beam), 2.5 * sc, true)


## Braço que segura o .38: sobe, atira para cima (com coice) e desce.
func _ic_raised_arm(t: float) -> void:
	var sc: float = _nw_sc
	var r: float = _nw_gun(t)
	if r <= 0.01:
		return
	var kick: float = 0.0
	if t >= T_SHOT:
		kick = exp(-(t - T_SHOT) / 0.18)
	var sil := Color(0.085, 0.042, 0.14)
	var rim := Color(0.72, 0.68, 1.0, 0.60)
	var sh: Vector2 = _nw(_nw_S + Vector2(8.0, -8.0))
	var el: Vector2 = _nw(_nw_S + Vector2(lerpf(45.0, 120.0, r), lerpf(120.0, -80.0, r) + 30.0 * kick))
	var hd: Vector2 = _nw(_nw_S + Vector2(lerpf(60.0, 160.0, r), lerpf(230.0, -230.0, r) + 55.0 * kick))
	draw_line(sh, el, sil, 64.0 * sc, true)
	draw_line(el, hd, sil, 52.0 * sc, true)
	draw_circle(sh, 32.0 * sc, sil)
	draw_circle(hd, 30.0 * sc, sil)
	draw_polyline(PackedVector2Array([sh + Vector2(26.0, -8.0) * sc, el + Vector2(30.0, 0.0) * sc, hd + Vector2(28.0, 0.0) * sc]), rim, 3.0 * sc, true)

	# O .38 apontado para o céu (o coice o inclina para trás).
	var u: Vector2 = Vector2(0.16, -1.0).normalized().rotated(-0.25 * kick)
	var nrm := Vector2(-u.y, u.x)
	var gp: Vector2 = hd + u * 8.0 * sc
	var barrel_end: Vector2 = gp + u * 150.0 * sc
	draw_line(gp - u * 12.0 * sc, barrel_end, Color(0.19, 0.20, 0.25), 16.0 * sc, true)
	draw_circle(gp + u * 40.0 * sc, 24.0 * sc, Color(0.23, 0.24, 0.30))
	draw_line(gp + nrm * 6.0 * sc + u * 40.0 * sc, barrel_end + nrm * 6.0 * sc, Color(0.62, 0.66, 0.78, 0.8), 3.0 * sc, true)
	draw_colored_polygon(PackedVector2Array([gp - u * 6.0 * sc - nrm * 8.0 * sc, gp - u * 30.0 * sc - nrm * 24.0 * sc, gp - u * 2.0 * sc - nrm * 14.0 * sc]), Color(0.14, 0.14, 0.18))
	if t >= T_SHOT and t < T_SHOT + 1.8:
		_ic_muzzle_fx(barrel_end + u * 6.0 * sc, u, t - T_SHOT, sc)


## Chão rachando em brasa embaixo do lobo logo depois da explosão.
func _nw_cracks(base: Vector2, sc: float, d: float) -> void:
	if d < 0.0 or d > 4.0:
		return
	var a: float = clampf(1.0 - d / 4.0, 0.0, 1.0)
	_glow_ellipse(base + Vector2(0.0, 14.0), 330.0 * sc, 34.0 * sc, Color(1.0, 0.30, 0.10, 0.30 * a))
	var grow: float = minf(d * 2.0, 1.0)
	for i in 11:
		var fi: float = float(i)
		var dx: float = (fi / 10.0 - 0.5) * 2.0
		var ln: float = (140.0 + 260.0 * _hsh(fi * 4.3)) * grow
		var e: Vector2 = base + Vector2(dx * ln, 12.0 + (_hsh(fi * 8.1) - 0.3) * 24.0)
		var fl: float = 0.6 + 0.4 * sin(_total * 9.0 + fi)
		draw_line(base + Vector2(0.0, 8.0), e, Color(1.0, 0.30, 0.08, 0.20 * a * fl), 9.0, true)
		draw_line(base + Vector2(0.0, 8.0), e, Color(1.0, 0.60, 0.20, 0.80 * a * fl), 3.0, true)


## O chapéu do caçador, caído no chão onde ele se transformou.
func _nw_hat(base: Vector2) -> void:
	var o: Vector2 = base + Vector2(-170.0, 20.0)
	var col := Color(0.012, 0.009, 0.018)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-78.0, 2.0), o + Vector2(-34.0, -12.0), o + Vector2(44.0, -12.0), o + Vector2(84.0, 4.0), o + Vector2(34.0, 14.0), o + Vector2(-40.0, 14.0)]), col)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-26.0, -10.0), o + Vector2(-16.0, -46.0), o + Vector2(18.0, -46.0), o + Vector2(30.0, -10.0)]), col)
	draw_polyline(PackedVector2Array([o + Vector2(-34.0, -12.0), o + Vector2(44.0, -12.0), o + Vector2(84.0, 4.0)]), Color(0.6, 0.65, 1.0, 0.35), 2.5, true)


## Efeitos do lobo: vapor da respiração, ondas do rugido e os arcos das garras.
func _nw_fx(t: float) -> void:
	var sc: float = _nw_sc
	var mouth: Vector2 = _nw(_nh(Vector2(112.0, 12.0)))
	if t > T_SWAP + 0.5:
		for i in 6:
			var age: float = fposmod(t * 0.8 + float(i) / 6.0, 1.0)
			var pp: Vector2 = mouth + Vector2(_nw_f * age * 110.0, -age * 70.0 + 10.0) * sc
			draw_circle(pp, (8.0 + age * 30.0) * sc, Color(0.80, 0.82, 0.95, 0.16 * (1.0 - age)))
	var d: float = t - T_ROAR
	if d >= 0.0 and d < 1.6:
		var dirv := Vector2(_nw_f * cos(_nw_ha), sin(_nw_ha))
		var ang: float = dirv.angle()
		for i in 5:
			var dd: float = d - float(i) * 0.15
			if dd <= 0.0:
				continue
			var a: float = clampf(1.0 - dd / 1.1, 0.0, 1.0)
			var c: Vector2 = mouth + dirv * dd * 520.0 * sc
			draw_arc(c, (50.0 + dd * 420.0) * sc, ang - 0.6, ang + 0.6, 24, Color(1.0, 0.85, 0.75, 0.5 * a), 7.0 * a + 2.0, true)
		var ga: float = clampf(1.0 - d / 1.4, 0.0, 1.0)
		_glow_ellipse(_nw_base + Vector2(0.0, 22.0), 300.0 + d * 900.0, 34.0, Color(0.75, 0.35, 0.95, 0.28 * ga))
	_nw_slash_fx(t, T_SLASH1, 1.0)
	_nw_slash_fx(t, T_SLASH2, -1.0)


## Três cortes de luz em arco. side = +1 golpeia para a direita, -1 para a esquerda.
func _nw_slash_fx(t: float, tk: float, side: float) -> void:
	var d: float = t - tk
	if d < -0.05 or d > 0.45:
		return
	var sc: float = _nw_sc
	var reveal: float = _smooth((d + 0.05) / 0.14)
	var fade: float = 1.0 - _smooth(d / 0.42)
	var c: Vector2 = _nw_base + Vector2(side * 40.0, -430.0) * sc
	var a0: float = -1.15
	var a1: float = a0 + 1.9 * reveal
	var lo: float = a0
	var hi: float = a1
	if side < 0.0:
		lo = PI - a1
		hi = PI - a0
	for i in 3:
		var fi: float = float(i)
		var r: float = (300.0 + fi * 26.0) * sc
		draw_arc(c, r, lo, hi, 28, Color(0.80, 0.50, 1.0, 0.25 * fade), (18.0 - 4.0 * fi) * sc, true)
		draw_arc(c, r, lo, hi, 28, Color(1.0, 0.92, 0.75, 0.85 * fade), (7.0 - 2.0 * fi) * sc + 1.0, true)
	var tip_ang: float = a1 if side > 0.0 else PI - a1
	_glow(c + Vector2.from_angle(tip_ang) * 326.0 * sc, 90.0 * sc, Color(1.0, 0.9, 0.6, 0.6 * fade))


# ----------------------------------------------------------------------------
# O caçador (silhueta de OpeningCinematic._hunter) caminhando e se transformando.
# morph: 0 = homem, 1 = prestes a virar lobo.  beat: pulso do coração (0..1).
# walk: 0 parado, 1 andando (stride é a fase dos passos).
# O corpo se curva para a frente (_ic_lean) conforme a transformação avança.
# ----------------------------------------------------------------------------

func _ic_deform(o: Vector2) -> Vector2:
	var h: float = clampf(-o.y / 230.0, 0.0, 1.0)
	return Vector2(o.x + _ic_lean * h * h, o.y + _ic_lean * 0.22 * h * h)


func _ic_pt(b: Vector2, k: float, o: Vector2) -> Vector2:
	return b + _ic_deform(o) * k


func _ic_hx(offsets: Array, b: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in offsets:
		out.append(_ic_pt(b, k, o as Vector2))
	return out


func _ic_hpoly(offsets: Array, b: Vector2, k: float, color: Color) -> void:
	draw_colored_polygon(_ic_hx(offsets, b, k), color)


func _ic_hline(a: Vector2, c: Vector2, b: Vector2, k: float, color: Color, width: float) -> void:
	draw_line(_ic_pt(b, k, a), _ic_pt(b, k, c), color, width * k, true)


func _ic_moved(offsets: Array, d: Vector2) -> Array:
	var out: Array = []
	for o in offsets:
		out.append((o as Vector2) + d)
	return out


func _ic_hunter(base: Vector2, k0: float, morph: float, beat: float, stride: float, walk: float) -> void:
	var sil := Color(0.004, 0.004, 0.009)
	var cool := Color(0.80, 0.85, 1.0, 0.95)
	var hot := Color(1.0, 0.35, 0.25, 0.95)
	var rim: Color = cool.lerp(hot, morph)
	var bob: float = -absf(sin(stride)) * 6.0 * walk + sin(_total * 3.0) * 2.0 * (1.0 - walk)
	bob *= 1.0 - 0.5 * morph
	var wind: float = sin(_total * 2.5) * 20.0 + 14.0 * walk
	var kj: float = floorf(_total * 30.0)
	var jit := Vector2(_hsh(kj) - 0.5, _hsh(kj + 3.7) - 0.5) * 22.0 * morph * morph
	var k: float = k0 * (1.0 + 0.28 * morph + 0.025 * beat)
	_ic_lean = 78.0 * morph * morph + 10.0 * beat
	var b: Vector2 = base + Vector2(0.0, bob * k) + jit

	# Sombra no chão, chão em brasa, partículas e aura.
	_glow_ellipse(base + Vector2(10.0, 30.0) * k, 120.0 * k, 16.0 * k, Color(0, 0, 0, 0.6))
	_ic_transform_fx(base, k, morph)
	_glow_ellipse(b + Vector2(0.0, -120.0) * k, 230.0 * k, 270.0 * k, Color(1.0, 0.15, 0.10, (0.24 + 0.14 * beat) * morph))

	# Corpo e pernas (as pernas dão passos enquanto ele anda).
	_ic_hpoly([Vector2(-30, -180), Vector2(40, -180), Vector2(60 + wind * 0.5, -30), Vector2(20 + wind, 10), Vector2(-85 + wind * 1.5, -10)], b, k, sil)
	var swing: float = sin(stride) * 26.0 * walk
	var lift1: float = maxf(cos(stride), 0.0) * 10.0 * walk
	var lift2: float = maxf(-cos(stride), 0.0) * 10.0 * walk
	_ic_hpoly([Vector2(-20, -80), Vector2(0, -80), Vector2(-10 + swing, -lift1), Vector2(-35 + swing, -lift1)], b, k, sil)
	_ic_hpoly([Vector2(10, -80), Vector2(35, -80), Vector2(45 - swing, 15 - lift2), Vector2(15 - swing, 15 - lift2)], b, k, sil)
	# Braço livre: os músculos incham e o braço se alonga.
	var free_end := Vector2(-40.0 - 22.0 * morph, -90.0 + 52.0 * morph)
	_ic_hline(Vector2(-20, -170), free_end, b, k, sil, 22.0 + 18.0 * morph)
	_ic_hline(Vector2(30, -170), Vector2(90, -130), b, k, sil, 24.0 + 12.0 * morph)

	# Braço com a arma + brilho azul (vira vermelho no fim).
	var g1 := Vector2(70, -140)
	var g2 := Vector2(200, -155)
	_ic_hline(g1, g1 + Vector2(50, -5), b, k, sil, 24.0)
	_ic_hline(g1 + Vector2(40, -5), g2, b, k, sil, 14.0)
	_ic_hline(g1 + Vector2(40, -12), g2 + Vector2(0, -7), b, k, sil, 8.0)
	var core: Vector2 = _ic_pt(b, k, g1 + Vector2(65, -8))
	var gp: float = 0.5 + 0.5 * sin(_total * 15.0)
	_glow(core, (26.0 + gp * 14.0) * k, Color(0.3, 0.7, 1.0, 0.55).lerp(Color(1.0, 0.3, 0.2, 0.55), morph))
	draw_circle(core, 4.0 * k, Color(0.7, 0.95, 1.0))
	_glow(_ic_pt(b, k, g2 + Vector2(14, -12 + wind * 0.2)), 26.0 * k, Color(0.6, 0.7, 0.8, 0.18))

	# Pescoço e cabeça; o focinho estica e as orelhas crescem com o morph.
	_ic_hpoly([Vector2(-25, -180), Vector2(35, -180), Vector2(25, -210), Vector2(-15, -210)], b, k, sil)
	draw_circle(_ic_pt(b, k, Vector2(5, -215)), 18.0 * k, sil)
	var m: float = 0.0
	if morph > 0.3:
		m = (morph - 0.3) / 0.7
		_ic_hpoly([Vector2(14, -224), Vector2(14 + 46.0 * m, -214), Vector2(14, -204)], b, k, sil)           # focinho
		_ic_hpoly([Vector2(-6, -228), Vector2(-14, -228 - 40.0 * m), Vector2(8, -230)], b, k, sil)           # orelha
		_ic_hpoly([Vector2(-14, -226), Vector2(-30, -224 - 30.0 * m), Vector2(-2, -230)], b, k, sil)         # 2ª orelha
	# Presas aparecem no fim.
	if morph > 0.6:
		var fm: float = clampf((morph - 0.6) / 0.4, 0.0, 1.0)
		var fang := Color(0.95, 0.93, 0.85, 0.95)
		_ic_hpoly([Vector2(14 + 22.0 * m, -208), Vector2(14 + 28.0 * m, -208), Vector2(14 + 25.0 * m, -208 + 11.0 * fm)], b, k, fang)
		_ic_hpoly([Vector2(14 + 36.0 * m, -211), Vector2(14 + 41.0 * m, -211), Vector2(14 + 39.0 * m, -211 + 9.0 * fm)], b, k, fang)

	# Olhos: de azul para amarelo brilhante, com feixes de luz.
	var eye_col: Color = Color(0.4, 0.8, 1.0, 0.95).lerp(Color(1.0, 0.9, 0.3, 1.0), clampf(morph * 1.6, 0.0, 1.0))
	_ic_hline(Vector2(10, -215), Vector2(18, -212), b, k, eye_col, 2.0 + 3.0 * morph)
	var eye: Vector2 = _ic_pt(b, k, Vector2(14, -213))
	_glow(eye, (10.0 + 46.0 * morph + 10.0 * beat) * k, Color(1.0, 0.8, 0.2, 0.15 + 0.65 * morph))
	if morph > 0.3:
		var ray: float = (morph - 0.3) / 0.7
		draw_line(eye, eye + Vector2(60.0 + 240.0 * ray, -8.0 * ray) * k, Color(1.0, 0.85, 0.3, 0.22 * ray), 7.0 * k, true)
		draw_line(eye, eye + Vector2(40.0 + 120.0 * ray, -4.0 * ray) * k, Color(1.0, 0.95, 0.6, 0.5 * ray), 2.5 * k, true)

	# Chapéu: cai quando a transformação passa de 55%.
	var hf: float = clampf((morph - 0.55) / 0.45, 0.0, 1.0)
	var hat_off := Vector2(40.0 * hf, -90.0 * hf + 330.0 * hf * hf)
	_ic_hpoly(_ic_moved([Vector2(-55, -215), Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], hat_off), b, k, sil)
	_ic_hpoly(_ic_moved([Vector2(-25, -230), Vector2(-15, -265), Vector2(15, -265), Vector2(25, -230)], hat_off), b, k, sil)
	if hf < 0.2:
		draw_polyline(_ic_hx([Vector2(-30, -235), Vector2(35, -235), Vector2(70, -210)], b, k), rim, 3.0, true)

	# Pelos nascendo nas costas e no peito.
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
			_ic_hpoly([p + Vector2(0, -9), p + nrm * spike + Vector2(0, spike * 0.25), p + Vector2(0, 9)], b, k, sil)

	# Trapos rasgados soltos pelo vento conforme o corpo cresce.
	if morph > 0.35:
		var tm: float = (morph - 0.35) / 0.65
		for i in 6:
			var fi2: float = float(i)
			var from: Vector2 = Vector2(-20.0 + 60.0 * _hsh(fi2 * 1.3), -160.0 + 110.0 * _hsh(fi2 * 2.9))
			var drift: Vector2 = Vector2(-50.0 - 70.0 * _hsh(fi2 * 4.1), -20.0 + 40.0 * sin(_total * 5.0 + fi2)) * tm
			draw_line(_ic_pt(b, k, from), _ic_pt(b, k, from + drift), sil, (5.0 - fi2 * 0.4) * k, true)

	draw_polyline(_ic_hx([Vector2(35, -180), Vector2(60 + wind * 0.5, -30)], b, k), rim, 2.5, true)
	_ic_hline(g1 + Vector2(40, -16), g2 + Vector2(0, -11), b, k, rim, 2.0)

	# Veias de brasa pulsando ao longo do pescoço e dos braços.
	if morph > 0.2:
		var vm: float = (morph - 0.2) / 0.8
		var vc := Color(1.0, 0.25, 0.10, (0.35 + 0.5 * beat) * vm)
		_ic_hline(Vector2(-5, -205), Vector2(-5, -178), b, k, vc, 2.0)
		_ic_hline(Vector2(-20, -165), free_end * 0.8 + Vector2(0, -20), b, k, vc, 2.0)
		_ic_hline(Vector2(25, -165), Vector2(80, -135), b, k, vc, 2.0)

	# Garras crescendo na mão livre.
	if morph > 0.5:
		var cm: float = (morph - 0.5) / 0.5
		var hand: Vector2 = _ic_pt(b, k, free_end)
		for i in 3:
			var o: float = float(i - 1) * 9.0
			draw_line(hand + Vector2(o, 0) * k, hand + Vector2(o - 4.0, 44.0 * cm) * k, Color(0.9, 0.85, 0.75, 0.9), 3.5 * k, true)
