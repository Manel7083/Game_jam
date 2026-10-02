extends "res://leveis/level_base.gd"
## Interim objective for the prototype levels (level_1 and level_2 share this script).
## Real objectives (symbols, keys, ...) arrive with the level-building milestone.

func setup_objectives() -> void:
	ObjectiveManager.set_objective("Survive until dawn")
