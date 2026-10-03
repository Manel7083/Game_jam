extends Node2D
## Shared level logic: registers with GameManager, defines objectives, spawns capped enemy waves.
## Level scripts extend this and override setup_objectives().

@export var spawn_enemies := 50
@export var max_alive_enemies := 12

# Kept so existing scene files still load; progression is now owned by GameManager.
@export var current_scene: String
@export var next_scene: String

@onready var player = $wolf

var active_enemies: Array = []

var enemy_scenes: Dictionary = {
	"morcego": preload("res://morcego_inimigo/morcego/morcego.tscn"),
	"slime": preload("res://enemies_sprites/enemie.tscn")
}

var current_wave := 1
var enemies_per_wave := 3
var time_between_enemies := 0.3
var time_between_wave := 1.0
var is_spawning := false

func _ready() -> void:
	GameManager.register_level(scene_file_path)
	TransitionScreen.scene_path = scene_file_path
	setup_objectives()

## Override in each level.
func setup_objectives() -> void:
	pass

# Acionado pelo seu Timer
func _on_spawn_time_timeout() -> void:
	if not is_spawning:
		start_wave()

# Lógica assíncrona da onda de inimigos
func start_wave() -> void:
	is_spawning = true
	
	for i in range(enemies_per_wave):
		# Pausa a onda se o limite máximo de inimigos na tela for atingido
		if get_tree().get_nodes_in_group("enemies").size() >= max_alive_enemies:
			break
			
		spawn_random_enemy()
		
		# Espera o tempo entre um inimigo e outro antes de continuar o loop
		await get_tree().create_timer(time_between_enemies).timeout
	
	# Finaliza a horda atual e prepara a próxima após o intervalo da onda
	await get_tree().create_timer(time_between_wave).timeout
	
	current_wave += 1
	enemies_per_wave += 2 # Aumenta a dificuldade (2 inimigos a mais por onda)
	is_spawning = false

func spawn_random_enemy() -> void:
	if not is_instance_valid(player):
		return
		
	# Sorteia uma das chaves do dicionário ("morcego" ou "slime")
	var enemy_keys = enemy_scenes.keys()
	var random_key = enemy_keys.pick_random()
	var scene_to_spawn: PackedScene = enemy_scenes[random_key]
	
	var enemy = scene_to_spawn.instantiate()
	add_child(enemy)
	enemy.add_to_group("enemies") # Garante que o inimigo está no grupo para a contagem
	enemy.global_position = calculate_spawn_enemies()
	
	# Verifica se o script do inimigo tem a variável 'player' antes de atribuir
	if "player" in enemy:
		enemy.player = player
		
	active_enemies.append(enemy) # Opcional: guarda referência do inimigo ativo

func calculate_spawn_enemies() -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var spawn_distance = screen_size.length() / 2.0 + spawn_enemies
	var angle = randf_range(0, TAU)
	return player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
