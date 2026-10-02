extends "res://enemies/enemy_base.gd"
## Original basic chaser. All behavior now lives in EnemyBase; this script only keeps the
## original tuning (3 HP, speed 50, 1 damage) and will become the Small Bat in the next milestone.

func _ready() -> void:
	max_health = 3
	speed = 50.0
	damage = 1
	score_value = 100
	super._ready()
