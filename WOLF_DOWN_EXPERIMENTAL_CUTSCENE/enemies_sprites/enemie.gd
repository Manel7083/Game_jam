extends "res://enemies/enemy_base.gd"
## Aranha Halloween. Não corre reto: faz zigue-zague enquanto se aproxima e,
## quando chega perto, para (treme), e dá um bote rápido na direção do jogador.
## Depois do bote fica vulnerável um instante. Tudo o mais vem do EnemyBase.

enum State { CHASE, TELEGRAPH, LUNGE, RECOVER }

@export var weave_frequency: float = 5.0     ## velocidade do zigue-zague
@export var weave_strength: float = 0.9      ## 0 = reto, 1+ = bem lateral
@export var lunge_range: float = 130.0       ## distância que dispara o bote
@export var lunge_speed: float = 340.0
@export var telegraph_time: float = 0.35     ## aviso antes do bote
@export var lunge_time: float = 0.28
@export var recover_time: float = 0.55       ## janela pra jogador revidar
@export var lunge_cooldown: float = 1.8
@export var turn_speed: float = 9.0          ## quão rápido ela vira o corpo (rad/s)

var _state: State = State.CHASE
var _state_time: float = 0.0
var _lunge_cd: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _weave_t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _fx_tween: Tween = null


func _ready() -> void:
	max_health = 3
	speed = 85.0
	damage = 1
	score_value = 150
	super._ready()
	_base_scale = texture.scale
	_weave_t = randf() * TAU
	_lunge_cd = randf_range(0.6, 1.6)


func move_toward_player() -> void:
	if not detect_player():
		velocity = Vector2.ZERO
		animation.pause()
		return

	var delta := get_physics_process_delta_time()
	_state_time += delta
	_lunge_cd = maxf(_lunge_cd - delta, 0.0)
	var to_player := global_position.direction_to(player.global_position)
	# sprite olha pra cima: gira o corpo pro jogador (ou pro bote) em vez de só espelhar
	var face := _lunge_dir if _state == State.LUNGE else to_player
	texture.rotation = lerp_angle(texture.rotation, face.angle() + PI * 0.5, minf(turn_speed * delta, 1.0))

	match _state:
		State.CHASE:
			_weave_t += delta * weave_frequency
			var side := to_player.rotated(PI * 0.5) * sin(_weave_t) * weave_strength
			direction = (to_player + side).normalized()
			velocity = direction * speed
			animation.speed_scale = 1.5
			animation.play("run")
			if _lunge_cd <= 0.0 and global_position.distance_to(player.global_position) <= lunge_range:
				_set_state(State.TELEGRAPH)

		State.TELEGRAPH:
			# para e treme olhando pro jogador; a mira é travada no fim do aviso
			velocity = Vector2.ZERO
			_lunge_dir = to_player
			if _state_time >= telegraph_time:
				_set_state(State.LUNGE)

		State.LUNGE:
			velocity = _lunge_dir * lunge_speed
			if _state_time >= lunge_time:
				_set_state(State.RECOVER)

		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _state_time >= recover_time:
				_lunge_cd = lunge_cooldown
				_set_state(State.CHASE)


func take_damage(amount: int, source_position: Vector2, melee: bool = false) -> void:
	super.take_damage(amount, source_position, melee)
	# levar dano interrompe o bote
	if not is_dead and (_state == State.TELEGRAPH or _state == State.LUNGE):
		_lunge_cd = lunge_cooldown * 0.5
		_set_state(State.CHASE)


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	if _fx_tween:
		_fx_tween.kill()
	match new_state:
		State.TELEGRAPH:
			animation.speed_scale = 0.4
			_fx_tween = create_tween().set_parallel(true)
			_fx_tween.tween_property(texture, "scale", _base_scale * Vector2(1.2, 0.8), telegraph_time)
			_fx_tween.tween_property(texture, "self_modulate", Color(1.6, 0.8, 0.4), telegraph_time)
		State.LUNGE:
			animation.speed_scale = 3.0
			texture.scale = _base_scale * Vector2(0.85, 1.25)
			texture.self_modulate = Color.WHITE
		State.RECOVER:
			animation.speed_scale = 0.5
			_fx_tween = create_tween()
			_fx_tween.tween_property(texture, "scale", _base_scale, recover_time * 0.5)
		State.CHASE:
			texture.scale = _base_scale
			texture.self_modulate = Color.WHITE
