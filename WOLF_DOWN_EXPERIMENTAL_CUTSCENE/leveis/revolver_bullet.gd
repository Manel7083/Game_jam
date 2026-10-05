extends Node2D

## Bala do revólver .38 do Wolf Down. Rápida e forte, sem depender de camadas de colisão:
## o dano é aplicado a qualquer nó do grupo "enemies" (update_health) cruzado pelo trajeto da bala.
## Uso: var b := REVOLVER_BULLET.new(); add_child(b); b.global_position = ...; b.damage = 4; b.set_direction(dir)

var damage: int = 4
var speed: float = 640.0
var direction: Vector2 = Vector2.RIGHT
var life: float = 1.2

var _dying: bool = false
var _die_t: float = 0.0


func set_direction(d: Vector2) -> void:
	direction = d.normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _dying:
		_die_t += delta
		modulate.a = 1.0 - _die_t / 0.12
		queue_redraw()
		if _die_t >= 0.12:
			queue_free()
		return

	var from: Vector2 = global_position
	var to: Vector2 = from + direction * speed * delta

	# 1) inimigos no trajeto
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var center: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var rad: float = 18.0
		var hr = e.get("hit_radius")
		if hr != null:
			rad = float(hr)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, from, to)
		if closest.distance_to(center) <= rad:
			if e.has_method("update_health"):
				e.update_health(damage)
			_impact(closest)
			return

	# 2) paredes (qualquer corpo estático no caminho)
	var params := PhysicsRayQueryParameters2D.create(from, to, 1)
	if is_instance_valid(Global.Player):
		params.exclude = [Global.Player.get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	if not hit.is_empty() and not (hit["collider"] is CharacterBody2D):
		_impact(hit["position"])
		return

	global_position = to
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _impact(pos: Vector2) -> void:
	global_position = pos
	_dying = true
	set_physics_process(true)


func _draw() -> void:
	if _dying:
		draw_circle(Vector2.ZERO, 10.0 * (1.0 + _die_t * 8.0), Color(1.0, 0.8, 0.3, 0.55))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.9))
		return
	draw_line(Vector2(-34.0, 0.0), Vector2(0.0, 0.0), Color(1.0, 0.75, 0.25, 0.30), 6.0)
	draw_line(Vector2(-20.0, 0.0), Vector2(0.0, 0.0), Color(1.0, 0.9, 0.6, 0.7), 3.0)
	draw_circle(Vector2.ZERO, 3.2, Color(1.0, 0.97, 0.85))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.75, 0.3, 0.18))
