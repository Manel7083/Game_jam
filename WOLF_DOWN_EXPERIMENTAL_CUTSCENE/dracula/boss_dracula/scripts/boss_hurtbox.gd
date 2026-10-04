extends Area2D
## Hurtbox do boss: encaminha dano de balas que usam Area2D (area_entered) para o boss.

func take_damage(amount: int = 1) -> void:
	var boss := get_parent()
	if boss and boss.has_method("take_damage"):
		boss.take_damage(amount)

func damage(amount: int = 1) -> void:
	take_damage(amount)

func hit(amount: int = 1) -> void:
	take_damage(amount)
