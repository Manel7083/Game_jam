extends "res://leveis/level_base.gd"
## Nível 3 - Castelo do Drácula: arena do chefe final.
## Sem ondas de inimigos nem temporizador: o nível termina quando o Drácula é derrotado.

const BOSS_SCENE := preload("res://boss_dracula/scenes/dracula_boss.tscn")
const BAR_SCENE := preload("res://boss_dracula/scenes/boss_health_bar.tscn")

const ENDING_CUTSCENE := preload("res://leveis/cutscene_level3.tscn")

const ARENA_SIZE := Vector2(896, 640)                 # tamanho da imagem da arena
const BOSS_AREA := Rect2(72, 104, 752, 460)           # onde o Drácula pode andar / teleportar

var boss: DraculaBoss


func _ready() -> void:
	# Antes do chefe, o jogador recupera toda a vida (e o snapshot do reinício já guarda isso).
	player.health = GameManager.player_max_hp
	GameManager.set_player_hp(player.health)
	# Na luta do chefe o neon fica mais discreto, para os ataques continuarem fáceis de ler.
	neon_intensity = minf(neon_intensity, 0.8)
	super._ready()
	_limit_camera()
	_spawn_boss()


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
