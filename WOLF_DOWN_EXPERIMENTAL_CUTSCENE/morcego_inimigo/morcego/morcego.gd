extends CharacterBody2D
## Shared enemy behavior: chase, contact attack with cooldown, damage, knockback, death.
## Subclasses override only what differs (move_toward_player(), attack(), die()).

@export var max_health: int = 3
@export var speed: float = 90.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
@export var detection_range: float = 0.0  ## 0 = always aware of the player
@export var score_value: int = 100
@export var knockback_force: float = 250.0
@export var knock_decay: float = 800.0

var health: int = 0
var player: Node2D = null
var direction: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _attack_timer: float = 0.0
var _aware: bool = false  ## já gritou ao notar o jogador
var _color_original: Color = Color.WHITE

@onready var texture: Sprite2D = $texture
@onready var animation: AnimationPlayer = $animation
@onready var audio_hit_fogo: AudioStreamPlayer2D = $audio_hit_fogo
@onready var audio_hit_faca: AudioStreamPlayer2D = $audio_hit_faca
@onready var audio_asas: AudioStreamPlayer2D = $audio_asas
@onready var audio_grito: AudioStreamPlayer2D = $audio_grito
@onready var audio_dano: AudioStreamPlayer2D = $audio_dano
@onready var audio_morte: AudioStreamPlayer2D = $audio_morte


func _ready() -> void:
	health = max_health
	player = Global.Player
	_color_original = texture.modulate


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if knockback_velocity.length() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knock_decay * delta)
	else:
		move_toward_player()
	move_and_slide()
	_check_contact_attack()


func detect_player() -> bool:
	if not is_instance_valid(player):
		return false
	if detection_range <= 0.0:
		return true
	return global_position.distance_to(player.global_position) <= detection_range


func move_toward_player() -> void:
	if detect_player():
		direction = global_position.direction_to(player.global_position)
		animation.play("run")
		velocity = direction * speed
		if not _aware:
			_aware = true
			_play_varied(audio_grito)
		_loop_wings()
		# visão top-down: o sprite olha pra cima, então gira o corpo pro jogador
		var turn := minf(10.0 * get_physics_process_delta_time(), 1.0)
		texture.rotation = lerp_angle(texture.rotation, direction.angle() + PI * 0.5, turn)
	else:
		velocity = Vector2.ZERO
		animation.play("idle")
		_aware = false
		_loop_wings()


func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force * (1.0 - knockback_resistance)


func take_damage(amount: int, source_position: Vector2, melee: bool = false) -> void:
	if is_dead:
		return
	apply_knockback((global_position - source_position).normalized() * knockback_force)
	health -= amount
	_flash_hit()
	_play_varied(audio_dano)
	ParticleFX.hit_spark(get_tree().current_scene, global_position)
	if melee:
		audio_hit_faca.play()
	else:
		audio_hit_fogo.play()
	if health <= 0:
		die()


## Legacy entry point used by the player's knife.
func update_health(value: int) -> void:
	var source := player.global_position if is_instance_valid(player) else global_position
	take_damage(value, source, true)


func attack() -> void:
	if _attack_timer > 0.0 or not is_instance_valid(player):
		return
	_attack_timer = attack_cooldown
	_play_varied(audio_grito)
	player.update_health(damage)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	audio_asas.stop()
	$collision.set_deferred("disabled", true)
	GameManager.register_kill(score_value)
	ParticleFX.bat_death(get_tree().current_scene, global_position, knockback_velocity)
	_play_death_sound()
	var tween := create_tween()
	tween.tween_property(texture, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _check_contact_attack() -> void:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			attack()
			return


func _flash_hit() -> void:
	texture.modulate = Color.RED
	create_tween().tween_property(texture, "modulate", _color_original, 0.1)


## Bate de asas em sequência enquanto o morcego está vivo.
func _loop_wings() -> void:
	if not audio_asas.playing:
		audio_asas.pitch_scale = randf_range(0.95, 1.05)
		audio_asas.play()


## Toca o som com um pouco de variação de tom para não soar repetido.
func _play_varied(player_audio: AudioStreamPlayer2D, spread: float = 0.1) -> void:
	player_audio.pitch_scale = randf_range(1.0 - spread, 1.0 + spread)
	player_audio.play()


## The sound must outlive this node, so it is played from a detached player.
func _play_death_sound() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for source in [audio_morte, audio_hit_faca]:
		if source.stream == null:
			continue
		var sound := AudioStreamPlayer2D.new()
		sound.stream = source.stream
		sound.volume_db = source.volume_db
		sound.pitch_scale = source.pitch_scale
		sound.max_distance = source.max_distance
		sound.global_position = global_position
		scene.add_child(sound)
		sound.finished.connect(sound.queue_free)
		sound.play()
