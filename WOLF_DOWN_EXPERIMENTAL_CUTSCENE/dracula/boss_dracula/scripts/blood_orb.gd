extends Area2D
## Projétil de sangue do Dracula.

@export var speed: float = 220.0
@export var damage: int = 1
@export var lifetime: float = 6.0

var direction: Vector2 = Vector2.RIGHT
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	var spr := AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	BossUtils.add_strip(frames, "spin", "res://boss_dracula/sprites/blood_orb.png", 16, 10.0, true)
	spr.sprite_frames = frames
	spr.play("spin")
	add_child(spr)

	body_entered.connect(_on_body_entered)

func launch(dir: Vector2, spd: float = -1.0) -> void:
	direction = dir.normalized()
	if spd > 0.0:
		speed = spd

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_t += delta
	if _t >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("boss") or body.is_in_group("boss_minion"):
		return
	if body.is_in_group("player"):
		BossUtils.damage_player(body, damage)
		queue_free()
	elif body is StaticBody2D or body is TileMapLayer:
		queue_free()
