extends Area2D

@export var speed: float = 300.0
var direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	
	

func set_direction(new_direction):
	direction = new_direction.normalized()
	rotation = direction.angle()


func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(1, global_position)
		GameManager.register_hit()
		ParticleFX.hit_spark(get_tree().current_scene, global_position)
	queue_free()


func _on_screen_visible_screen_exited():
	queue_free()
