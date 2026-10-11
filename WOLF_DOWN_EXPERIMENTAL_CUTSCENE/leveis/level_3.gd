extends "res://leveis/level_base.gd"
## Nível 3 - Castelo do Drácula: arena do chefe final.
## Sem ondas de inimigos nem temporizador: o nível termina quando o Drácula é derrotado.

const BOSS_SCENE := preload("res://boss_dracula/scenes/dracula_boss.tscn")
const BAR_SCENE := preload("res://boss_dracula/scenes/boss_health_bar.tscn")

const ENDING_CUTSCENE := preload("res://leveis/cutscene_level3.tscn")

const ARENA_SIZE := Vector2(896, 640)                 # tamanho da imagem da arena
const BOSS_AREA := Rect2(72, 104, 752, 460)           # onde o Drácula pode andar / teleportar

## A cutscene de abertura toca uma vez por partida (não repete a cada "tentar de novo").
## Desmarque para desligar a cutscene.
@export var play_intro: bool = true
static var _intro_seen: bool = false

## Música de tensão do nível (loop). Toca desde o começo da cutscene de abertura e segue
## durante toda a luta. Se o arquivo não existir, o nível funciona normalmente sem ela.
const TENSION_MUSIC_PATH := "res://audio/dracula/l3_halloween_loop.wav"
@export var tension_music_db: float = -8.0
## Se ligado, a música de fundo original do nível é silenciada para a de tensão tomar o lugar.
@export var replace_level_music: bool = true

## --- Música que escala com a vida do Drácula -----------------------------------------
## Cada vez que o Drácula entra numa nova fase (vida abaixo de 66% e de 33%), a música sobe: toca um
## impacto, fica mais rápida/aguda e mais alta, e entram camadas extras (pulso grave e
## ticks agudos). Os arrays abaixo têm 1 valor por fase (fase 1, 2 e 3).
const PULSE_PATH := "res://audio/dracula/l3_pulse_loop.wav"
const HATS_PATH := "res://audio/dracula/l3_hats_loop.wav"
const STAGE_HIT_PATH := "res://audio/dracula/l3_stage_hit.wav"

## Velocidade/tom da música em cada estágio (1.0 = normal).
@export var stage_pitch: Array[float] = [1.0, 1.07, 1.15]
## Volume extra (dB) da música principal em cada estágio.
@export var stage_music_db: Array[float] = [0.0, 1.5, 3.0]
## Volume (dB) das camadas extras em cada estágio (-80 = mudo).
@export var stage_pulse_db: Array[float] = [-80.0, -11.0, -5.0]
@export var stage_hats_db: Array[float] = [-80.0, -16.0, -8.0]

var boss: DraculaBoss
var _tension_player: AudioStreamPlayer
var _pulse_player: AudioStreamPlayer
var _hats_player: AudioStreamPlayer
var _music_stage: int = 0
var _music_tween: Tween


func _ready() -> void:
	# Antes do chefe, o jogador recupera toda a vida (e o snapshot do reinício já guarda isso).
	player.health = GameManager.player_max_hp
	GameManager.set_player_hp(player.health)
	# Na luta do chefe o neon fica mais discreto, para os ataques continuarem fáceis de ler.
	neon_intensity = minf(neon_intensity, 0.8)
	super._ready()
	_limit_camera()
	_start_tension_music()
	if play_intro and not _intro_seen:
		_intro_seen = true
		await _play_intro_cutscene()
		if not is_inside_tree():
			return
	_spawn_boss()


func _start_tension_music() -> void:
	if replace_level_music:
		var bg := get_node_or_null("music_background") as AudioStreamPlayer2D
		if bg != null:
			bg.stop()
	if not ResourceLoader.exists(TENSION_MUSIC_PATH):
		return
	var stream := load(TENSION_MUSIC_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frame_bytes: int = (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / frame_bytes)
	_tension_player = AudioStreamPlayer.new()
	_tension_player.stream = stream
	_tension_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_tension_player.volume_db = -40.0
	_tension_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tension_player)
	_tension_player.finished.connect(_tension_player.play)  # garantia extra de loop
	_tension_player.play()
	create_tween().tween_property(_tension_player, "volume_db", tension_music_db, 3.0)
	# Camadas extras (começam mudas, em sincronia com a música, e entram nos estágios).
	_pulse_player = _make_layer(PULSE_PATH)
	_hats_player = _make_layer(HATS_PATH)


func _music_bus() -> String:
	return "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"


func _loop_wav(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frame_bytes: int = (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / frame_bytes)


func _make_layer(path: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s == null:
		return null
	_loop_wav(s)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = _music_bus()
	p.volume_db = -80.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p


func _stage_value(values: Array[float], stage: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(stage, 0, values.size() - 1)]


## O Drácula tem 3 fases (sinal phase_changed: 1, 2, 3). A música sobe um estágio a cada fase.
func _on_boss_phase_changed(phase: int) -> void:
	_set_music_stage(phase - 1)


func _set_music_stage(stage: int) -> void:
	stage = mini(stage, stage_pitch.size() - 1)
	if stage <= _music_stage:  # só sobe: a música nunca desacelera no meio da luta
		return
	_music_stage = stage
	_play_stage_hit()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var pitch: float = _stage_value(stage_pitch, stage, 1.0)
	if _tension_player != null and is_instance_valid(_tension_player):
		_music_tween.tween_property(_tension_player, "volume_db", tension_music_db + _stage_value(stage_music_db, stage, 0.0), 1.5)
		_music_tween.tween_property(_tension_player, "pitch_scale", pitch, 1.5)
	if _pulse_player != null and is_instance_valid(_pulse_player):
		_music_tween.tween_property(_pulse_player, "volume_db", _stage_value(stage_pulse_db, stage, -80.0), 1.5)
		_music_tween.tween_property(_pulse_player, "pitch_scale", pitch, 1.5)
	if _hats_player != null and is_instance_valid(_hats_player):
		_music_tween.tween_property(_hats_player, "volume_db", _stage_value(stage_hats_db, stage, -80.0), 1.5)
		_music_tween.tween_property(_hats_player, "pitch_scale", pitch, 1.5)


func _play_stage_hit() -> void:
	if not ResourceLoader.exists(STAGE_HIT_PATH):
		return
	var s := load(STAGE_HIT_PATH) as AudioStream
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = _music_bus()
	p.volume_db = 0.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _fade_tension_music(seconds: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for p in [_tension_player, _pulse_player, _hats_player]:
		if p != null and is_instance_valid(p):
			create_tween().tween_property(p, "volume_db", -80.0 if p != _tension_player else -40.0, seconds)


func setup_objectives() -> void:
	ObjectiveManager.set_objective("Derrote o Conde Drácula")


## Neon do castelo: violeta, carmesim e um toque de ciano. Cobre só a arena.
func _neon_palette() -> PackedColorArray:
	return PackedColorArray([Color(0.78, 0.38, 1.0), Color(1.0, 0.25, 0.5), Color(0.2, 0.95, 1.0)])


func _neon_area() -> Rect2:
	return Rect2(Vector2.ZERO, ARENA_SIZE)


func _limit_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ARENA_SIZE.x)
	cam.limit_bottom = int(ARENA_SIZE.y)


func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.arena_rect = BOSS_AREA
	boss.position = $BossSpawn.position
	add_child(boss)

	var bar := BAR_SCENE.instantiate()
	add_child(bar)
	bar.bind_boss(boss)

	boss.defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(_on_boss_phase_changed)


func _on_boss_defeated() -> void:
	_intro_seen = false  # na próxima partida a cutscene de abertura volta a tocar
	ParticleFX.objective_complete(self, boss.global_position)
	ObjectiveManager.complete_objective()
	# O jogador fica parado durante a morte do chefe e a cutscene final.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(2.0).timeout
	await _play_ending_cutscene()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	GameManager.complete_level()


## Cutscene final: Drácula se destruindo, o lobo volta a ser caçador e descansa.
## Toca por cima do nível (CanvasLayer) e termina quando o sinal `finished` é emitido.
func _play_ending_cutscene() -> void:
	_fade_tension_music(1.5)
	var music := get_node_or_null("music_background")
	if music != null:
		create_tween().tween_property(music, "volume_db", -40.0, 1.0)

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var cine := ENDING_CUTSCENE.instantiate() as Level3EndingCinematic
	layer.add_child(cine)
	await cine.finished
	layer.queue_free()


## Cutscene de abertura: o Lobo chega ao recinto do Drácula e a fúria toma conta dele.
## O jogador fica parado e o chefe só aparece depois que ela termina (ou é pulada).
func _play_intro_cutscene() -> void:
	var music := get_node_or_null("music_background") as AudioStreamPlayer2D
	if music != null and not replace_level_music:
		music.volume_db = -16.0
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var cine := Level3IntroCinematic.new()
	layer.add_child(cine)
	await cine.finished
	layer.queue_free()

	player.process_mode = Node.PROCESS_MODE_INHERIT
	if music != null and not replace_level_music:
		create_tween().tween_property(music, "volume_db", 0.0, 1.5)
