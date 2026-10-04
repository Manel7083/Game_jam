extends "res://leveis/level_base.gd"
## Nível 3 - Castelo do Drácula: arena do chefe final.
## Sem ondas de inimigos nem temporizador: o nível termina quando o Drácula é derrotado.

const BOSS_SCENE := preload("res://boss_dracula/scenes/dracula_boss.tscn")
const BAR_SCENE := preload("res://boss_dracula/scenes/boss_health_bar.tscn")

const ARENA_SIZE := Vector2(896, 640)                 # tamanho da imagem da arena
const BOSS_AREA := Rect2(72, 104, 752, 460)           # onde o Drácula pode andar / teleportar

var boss: DraculaBoss


func _ready() -> void:
	# Antes do chefe, o jogador recupera toda a vida (e o snapshot do reinício já guarda isso).
	player.health = GameManager.player_max_hp
	GameManager.set_player_hp(player.health)
	super._ready()
	_limit_camera()
	_spawn_boss()


func setup_objectives() -> void:
	ObjectiveManager.set_objective("Derrote o Conde Drácula")


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
	await get_tree().create_timer(2.0).timeout
	GameManager.complete_level()
