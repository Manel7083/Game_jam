extends CanvasLayer
## HUD. Driven entirely by GameManager / ObjectiveManager signals - no values are hard-coded.

@onready var hp: Label = $HP
@onready var ammo_bar: TextureProgressBar = $"barra_munição/barra_municao"

var _score_label: Label
var _objective_box: VBoxContainer
var _banner: Label
var _reward_label: Label


func _ready() -> void:
	_build_extra_ui()
	GameManager.player_health_changed.connect(update_health)
	GameManager.ammo_changed.connect(update_ammo)
	GameManager.score_changed.connect(update_score)
	GameManager.score_life_reward.connect(_on_score_life_reward)
	ObjectiveManager.objective_changed.connect(_refresh_objective)
	ObjectiveManager.objective_completed.connect(_on_objective_completed)
	update_health(GameManager.player_hp, GameManager.player_max_hp)
	update_score(GameManager.score)
	_update_reward_progress()
	_refresh_objective(ObjectiveManager.title, ObjectiveManager.items, ObjectiveManager.done)


func update_health(value: int, max_value: int = 0) -> void:
	var max_hp := max_value if max_value > 0 else GameManager.player_max_hp
	hp.text = "HP: %d/%d" % [value, max_hp]


func update_ammo(value: float, max_value: float = 100.0) -> void:
	ammo_bar.max_value = max_value
	ammo_bar.value = value


func update_score(value: int) -> void:
	_score_label.text = "SCORE  %d" % value
	_update_reward_progress()


func _update_reward_progress() -> void:
	if not is_instance_valid(_reward_label):
		return
	var progress := GameManager.get_score_reward_progress()
	if progress["complete"]:
		_reward_label.text = "MAX HP"
		_reward_label.modulate = Color(0.55, 1.0, 0.65)
	else:
		reward_label_text(progress)


func reward_label_text(progress: Dictionary) -> void:
	_reward_label.text = "HP +1  %d/%d" % [progress["current"], progress["required"]]
	_reward_label.modulate = Color(0.95, 0.85, 0.35)


func _on_score_life_reward(new_max_hp: int, healed_hp: int) -> void:
	show_banner("MAX HP +1   %d/%d" % [healed_hp, new_max_hp])
	_update_reward_progress()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _build_extra_ui() -> void:
	_score_label = UIKit.make_label("SCORE  0", 32)
	add_child(_score_label)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_objective_box = VBoxContainer.new()
	add_child(_objective_box)
	_objective_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	_banner = UIKit.make_label("", 56, Color(1, 0.85, 0.3))
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 120)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.modulate.a = 0.0

	_reward_label = UIKit.make_label("HP +1  0/5000", 22, Color(0.95, 0.85, 0.35))
	add_child(_reward_label)
	_reward_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_reward_label.position.y = 62
	_reward_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _refresh_objective(title: String, items: Array, done: Array) -> void:
	for child in _objective_box.get_children():
		child.queue_free()
	if title.is_empty():
		return
	var header := UIKit.make_label("OBJECTIVE", 24, Color(0.8, 0.8, 0.8))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_box.add_child(header)
	var title_label := UIKit.make_label(title, 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_box.add_child(title_label)
	for i in items.size():
		var mark := "[x] " if done[i] else "[ ] "
		var color := Color(0.5, 1.0, 0.5) if done[i] else Color.WHITE
		var line := UIKit.make_label(mark + str(items[i]), 26, color)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_objective_box.add_child(line)


func _on_objective_completed() -> void:
	show_banner("OBJECTIVE COMPLETE")
	if is_instance_valid(Global.Player):
		ParticleFX.objective_complete(get_tree().current_scene, Global.Player.global_position)
