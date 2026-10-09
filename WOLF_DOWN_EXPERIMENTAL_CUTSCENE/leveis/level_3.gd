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
const TENSION_MUSIC_PATH := "res://audio/l3_tension_loop.wav"
@export var tension_music_db: float = -4.0
## Se ligado, a música de fundo original do nível é silenciada para a de tensão tomar o lugar.
@export var replace_level_music: bool = true

var boss: DraculaBoss
var _tension_player: AudioStreamPlayer


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


func _fade_tension_music(seconds: float) -> void:
	if _tension_player != null and is_instance_valid(_tension_player):
		create_tween().tween_property(_tension_player, "volume_db", -40.0, seconds)


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
