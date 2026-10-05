extends Node
## Central game state: level progression, run statistics, game over / level complete / pause.
## Level scripts only call register_level() and complete_level(); they know nothing about each other.

signal score_changed(value: int)
signal player_health_changed(hp: int, max_hp: int)
signal ammo_changed(value: float, max_value: float)
signal level_completed(level_index: int)
signal player_died
signal score_life_reward(new_max_hp: int, healed_hp: int)

const MENU_SCENE := "res://leveis/menu.tscn"
const INTRO_CUTSCENE_SCENE := "res://leveis/cutscene.tscn"
## Cinemática exibida entre o Level 1 e o Level 2 (Lobsome ferido sob o luar, decide melhorar o .38).
const LEVEL1_AFTERMATH_CUTSCENE := "res://leveis/cutscene_level1.tscn"
const LEVEL1_PATH := "res://leveis/level_1.tscn"
const PAUSE_MENU_SCENE := "res://ui/pause_menu.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const LEVEL_COMPLETE_SCENE := "res://ui/level_complete.tscn"

# Ordered progression. Levels 4-5 are appended here as they are built.
const LEVELS := [
	{"path": "res://leveis/tutorial.tscn", "title": "TUTORIAL"},
	{"path": "res://leveis/level_1.tscn", "title": "LEVEL 1 - THE HAUNTED FOREST"},
	# Depois do Level 1 vem a cutscene (NEXT_LEVEL_INDEX = 2 em cutscene_level1.gd) e então a fase dos guardiões.
	{"path": "res://leveis/level_gaiola.tscn", "title": "LEVEL 2 - THE GUARDIANS' CAGE"},
	# Aquecimento antes da maldição.
	{"path": "res://leveis/level_2.tscn", "title": "LEVEL 3 - DEADMAN'S CEMETERY"},
	{"path": "res://leveis/level_3.tscn", "title": "LEVEL 4 - DRACULA'S CASTLE"},
]

const STARTING_MAX_HP := 5
const MAX_PLAYER_HP := 10
const SCORE_PER_LIFE := 2000

var current_level: int = -1
var level_active: bool = false

var score: int = 0
var enemies_defeated: int = 0
var damage_taken: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var run_time: float = 0.0
var level_time: float = 0.0

var player_max_hp: int = STARTING_MAX_HP
var player_hp: int = STARTING_MAX_HP
var score_life_rewards_claimed: int = 0
var weapon_name: String = "PISTOL"

var _snapshot: Dictionary = {}
var _current_path: String = ""
var _overlay: Node = null


func _process(delta: float) -> void:
	if level_active:
		run_time += delta
		level_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		open_pause()


# --- Run / level flow -------------------------------------------------------

func start_game() -> void:
	reset_run()
	load_scene(INTRO_CUTSCENE_SCENE)


func reset_run() -> void:
	score = 0
	enemies_defeated = 0
	damage_taken = 0
	shots_fired = 0
	shots_hit = 0
	run_time = 0.0
	level_time = 0.0
	player_max_hp = STARTING_MAX_HP
	player_hp = STARTING_MAX_HP
	score_life_rewards_claimed = 0
	weapon_name = "PISTOL"
	_snapshot = {}


## Called by every level in _ready(). Works even when a level is launched directly from the editor.
func register_level(path: String) -> void:
	get_tree().paused = false
	_clear_overlay()
	_current_path = path
	current_level = _index_of(path)
	level_time = 0.0
	level_active = true
	ObjectiveManager.clear()
	_take_snapshot()


func complete_level() -> void:
	if not level_active:
		return
	level_active = false
	level_completed.emit(current_level)
	_show_overlay(LEVEL_COMPLETE_SCENE)


## True when the current level is the last one in LEVELS (the victory screen is shown instead of CONTINUE).
func is_last_level() -> bool:
	return current_level >= LEVELS.size() - 1


func next_level() -> void:
	var next_index := current_level + 1
	if current_level >= 0 and next_index < LEVELS.size():
		# Ao concluir o Level 1 passa primeiro pela cinemática; ela mesma carrega o Level 2 no final.
		if current_level == _index_of(LEVEL1_PATH) and ResourceLoader.exists(LEVEL1_AFTERMATH_CUTSCENE):
			load_scene(LEVEL1_AFTERMATH_CUTSCENE)
			return
		load_level(next_index)
	else:
		# End of the run: back to the menu (the level-complete screen already acts as the victory screen).
		return_to_menu()


func load_level(index: int) -> void:
	load_scene(LEVELS[index]["path"])


func restart_level() -> void:
	_restore_snapshot()
	load_scene(_current_path)


func return_to_menu() -> void:
	level_active = false
	ObjectiveManager.clear()
	load_scene(MENU_SCENE)


func load_scene(path: String) -> void:
	level_active = false
	get_tree().paused = false
	_clear_overlay()
	TransitionScreen.change_scene(path)


func on_player_died() -> void:
	if not level_active:
		return
	level_active = false
	player_died.emit()
	_show_overlay(GAME_OVER_SCENE)


func open_pause() -> void:
	if not level_active or is_instance_valid(_overlay):
		return
	_show_overlay(PAUSE_MENU_SCENE)


func close_overlay() -> void:
	_clear_overlay()


# --- Statistics -------------------------------------------------------------

func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	score_changed.emit(score)
	_check_score_life_rewards()


func _check_score_life_rewards() -> void:
	var earned_milestones := score / SCORE_PER_LIFE
	while score_life_rewards_claimed < earned_milestones:
		score_life_rewards_claimed += 1
		_award_score_life()


func _award_score_life() -> void:
	if player_max_hp >= MAX_PLAYER_HP:
		return

	player_max_hp += 1
	var healed_hp := mini(1, player_max_hp - player_hp)
	player_hp += healed_hp
	player_health_changed.emit(player_hp, player_max_hp)
	score_life_reward.emit(player_max_hp, healed_hp)

	if is_instance_valid(Global.Player):
		Global.Player.health = player_hp
		ParticleFX.score_reward(get_tree().current_scene, Global.Player.global_position)


func register_kill(points: int) -> void:
	enemies_defeated += 1
	add_score(points)


func register_shot() -> void:
	shots_fired += 1


func register_hit() -> void:
	shots_hit += 1


func register_damage(amount: int) -> void:
	damage_taken += amount


func set_player_hp(hp: int) -> void:
	player_hp = clampi(hp, 0, player_max_hp)
	player_health_changed.emit(player_hp, player_max_hp)


func set_ammo(value: float, max_value: float) -> void:
	ammo_changed.emit(value, max_value)


func get_score_reward_progress() -> Dictionary:
	if player_max_hp >= MAX_PLAYER_HP:
		return {"complete": true, "current": 0, "required": SCORE_PER_LIFE, "remaining": 0}
	var current := score % SCORE_PER_LIFE
	return {
		"complete": false,
		"current": current,
		"required": SCORE_PER_LIFE,
		"remaining": SCORE_PER_LIFE - current,
	}


func accuracy_percent() -> float:
	if shots_fired == 0:
		return 0.0
	return float(shots_hit) / float(shots_fired) * 100.0


func get_level_stats() -> Dictionary:
	return {
		"score": score - int(_snapshot.get("score", 0)),
		"enemies": enemies_defeated - int(_snapshot.get("enemies", 0)),
		"damage": damage_taken - int(_snapshot.get("damage", 0)),
		"time": level_time,
		"accuracy": accuracy_percent(),
	}


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


# --- Internals --------------------------------------------------------------

func _index_of(path: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["path"] == path:
			return i
	return -1


func _take_snapshot() -> void:
	_snapshot = {
		"score": score,
		"enemies": enemies_defeated,
		"damage": damage_taken,
		"shots_fired": shots_fired,
		"shots_hit": shots_hit,
		"run_time": run_time,
		"hp": player_hp,
		"max_hp": player_max_hp,
		"score_life_rewards_claimed": score_life_rewards_claimed,
	}


func _restore_snapshot() -> void:
	if _snapshot.is_empty():
		return
	score = _snapshot["score"]
	enemies_defeated = _snapshot["enemies"]
	damage_taken = _snapshot["damage"]
	shots_fired = _snapshot["shots_fired"]
	shots_hit = _snapshot["shots_hit"]
	run_time = _snapshot["run_time"]
	player_max_hp = _snapshot["max_hp"]
	player_hp = _snapshot["hp"]
	score_life_rewards_claimed = int(_snapshot.get("score_life_rewards_claimed", 0))
	score_changed.emit(score)
	player_health_changed.emit(player_hp, player_max_hp)


func _show_overlay(path: String) -> void:
	_clear_overlay()
	_overlay = load(path).instantiate()
	get_tree().root.add_child(_overlay)


func _clear_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
