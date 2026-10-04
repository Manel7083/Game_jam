extends CharacterBody2D
## Morcego lacaio invocado pelo Dracula. Persegue o jogador em zigue-zague.

@export var max_health: int = 2
@export var speed: float = 120.0
@export var contact_damage: int = 1

var health: int
var _t := randf() * 10.0
var _cooldown := 0.0
var _sprite: AnimatedSprite2D
var _contact: Area2D

func _ready() -> void:
	add_to_group("boss_minion")
	add_to_group("enemy")
	health = max_health

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2, 2)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	BossUtils.add_strip(frames, "fly", "res://boss_dracula/sprites/minion_bat.png", 16, 12.0, true)
	_sprite.sprite_frames = frames
	_sprite.play("fly")
	add_child(_sprite)

	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 0xFFFFFFFF
	var cs := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = 10.0
	cs.shape = cc
	_contact.add_child(cs)
	add_child(_contact)

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	var p := BossUtils.get_player(get_tree())
	if p == null:
		return
	var to := (p.global_position - global_position).normalized()
	var side := to.orthogonal() * sin(_t * 6.0) * 0.8
	velocity = (to + side).normalized() * speed
	move_and_slide()
	_sprite.flip_h = velocity.x < 0.0
	if _cooldown <= 0.0:
		for b in _contact.get_overlapping_bodies():
			if b.is_in_group("player"):
				BossUtils.damage_player(b, contact_damage)
				_cooldown = 1.0
				break

func take_damage(amount: int = 1) -> void:
	health -= amount
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		queue_free()

func damage(amount: int = 1) -> void:
	take_damage(amount)

func hit(amount: int = 1) -> void:
	take_damage(amount)
