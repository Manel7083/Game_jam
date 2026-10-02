extends Node2D
## Shared level logic: registers with GameManager, defines objectives, spawns capped enemy waves.
## Level scripts extend this and override setup_objectives().

@export var enemies_scene: PackedScene
@export var spawn_enemies := 50
@export var max_alive_enemies := 12
# Kept so existing scene files still load; progression is now owned by GameManager.
@export var current_scene: String
@export var next_scene: String

@onready var player = $wolf


func _ready() -> void:
	GameManager.register_level(scene_file_path)
	TransitionScreen.scene_path = scene_file_path
	setup_objectives()


## Override in each level.
func setup_objectives() -> void:
	pass


func enemies_spawn() -> void:
	if enemies_scene == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive_enemies:
		return
	var enemy = enemies_scene.instantiate()
	add_child(enemy)
	enemy.global_position = calculate_spawn_enemies()
	enemy.player = player


func calculate_spawn_enemies() -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var spawn_distance = screen_size.length() / 2 + spawn_enemies
	var angle = randf_range(0, TAU)
	return player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance


func _on_spawn_time_timeout() -> void:
	enemies_spawn()
