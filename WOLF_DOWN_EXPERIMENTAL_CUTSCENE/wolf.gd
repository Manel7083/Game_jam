extends CharacterBody2D

@export var spawn_bullet: PackedScene 

@onready var animation = $animation
@onready var texture = $texture
@onready var arma = $arma
@onready var ponto_tiro = $arma/ponto_tiro
@onready var arma_sprite = $arma/arma_sprite
@onready var pistol_animation = $arma/pistol_animation
@onready var mira = $arma/mira
@onready var camera = $Camera2D
@onready var son_attack = $son_attack
@onready var som_bala = $arma/som_bala

var dano = 1
var health: int = 5
var is_dead: bool = false
var _invulnerable: bool = false
const INVULNERABILITY_TIME := 0.6
var speed = 100
var move_direction := Vector2.ZERO
var aim_direction := Vector2.RIGHT
#MIRA DO PLAYER
var can_shoot: bool = true
var can_attack: bool = true
var recarga_shoot: float = 0.1
var virtual_mouse_pos: Vector2

#RECARGA (energy-style ammo; replaced by per-weapon magazines in the weapons milestone)
# Was typed int, which truncated ammo_cost (2.5 -> 2) and the regeneration; now float.
var ammo: float = 100.0
var max_ammo: float = 100.0
var ammo_cost: float = 2.5
var _last_ammo_emitted: int = -1

var regen_delay: float = 5.0
var regen_speed: float = 60.0

var last_shot_time: float = 0.0

func _ready():
	Global.Player = self
	virtual_mouse_pos = global_position
	can_attack = true
	# HP now persists across levels through GameManager instead of resetting to 5.
	health = GameManager.player_hp
	GameManager.set_player_hp(health)
	GameManager.set_ammo(ammo, max_ammo)
	ParticleFX.attach_ambient_dust(self)


func _exit_tree() -> void:
	# Avoid leaving enemies with a dangling reference to a freed player.
	if Global.Player == self:
		Global.Player = null


func _physics_process(delta: float) -> void:
	if can_attack == false:
		return
	var viewport_size = get_viewport_rect().size
	var half_size = (viewport_size * camera.zoom) / 1.5
	var cam_pos = camera.get_screen_center_position()

	var left = cam_pos.x - half_size.x
	var right = cam_pos.x + half_size.x
	var top = cam_pos.y - half_size.y
	var bottom = cam_pos.y + half_size.y
	var current_time = Time.get_ticks_msec() / 1000.0
	
	
	rotation = aim_direction.angle()
	
	
	
	move_direction = Input.get_vector("left","right","up","down")
	
	var aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	
	var final_dir: Vector2
	if aim.length() > 0.2:
		var max_distance = 100
		var target_pos = global_position + aim.normalized() * max_distance
	
		target_pos.x = clamp(target_pos.x, left, right)
		target_pos.y = clamp(target_pos.y, top, bottom)
	
		virtual_mouse_pos = target_pos
		
	elif Input.get_last_mouse_velocity().length() > 0:
		var max_distance = 150
		
		virtual_mouse_pos = get_global_mouse_position()
		
		virtual_mouse_pos.x = clamp(virtual_mouse_pos.x, left, right)
		virtual_mouse_pos.y = clamp(virtual_mouse_pos.y, top, bottom)
	
	velocity = move_direction * speed
	
	final_dir = (virtual_mouse_pos - global_position).normalized()
	arma.rotation = final_dir.angle()
	mira.global_position = virtual_mouse_pos

# 👉 FLIP DA ARMA
	if final_dir.x < 0:
		arma.scale.y = -1
		texture.flip_h = true
		arma.position.x = 2
	else:
		arma.scale.y = 1
		texture.flip_h = false
		arma.position.x = -2
	
	if Input.is_action_pressed("shoot") and can_shoot and ammo >= ammo_cost:
		_shoot(final_dir)
		ParticleFX.muzzle_flash(get_tree().current_scene, ponto_tiro.global_position, final_dir)
		pistol_animation.play("fire")
		pistol_animation.speed_scale = 6.8
		
		ammo -= ammo_cost
		last_shot_time = current_time
		_emit_ammo()
		
		arma.rotation = final_dir.angle()
		if final_dir.x < 0:
			$arma.scale.y = -1
			
		else:
			$arma.scale.y = 1
			
	if not Input.is_action_pressed("shoot"):
		if current_time - last_shot_time >= regen_delay:
			if ammo < max_ammo:
				ammo += regen_speed * delta
				ammo = minf(ammo, max_ammo)
				_emit_ammo()
	
	animate()
	move_and_slide()
	attack_handler()

func animate():
	
	if can_attack == false:
		return
	
	if velocity.x > 0:
		texture.flip_h = false
		
	if velocity.x < 0:
		texture.flip_h = true
	
	if velocity != Vector2.ZERO:
		
		if velocity.x != 0:
			animation.play("run")
		elif  velocity.y != 0:
			animation.play("run")
		return
	animation.play("idle")
func _shoot(direction):
	
	can_shoot = false
	GameManager.register_shot()
	
	var bullet_instance = spawn_bullet.instantiate()
	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.global_position = ponto_tiro.global_position
	
	bullet_instance.set_direction(direction)
	
	await  get_tree().create_timer(recarga_shoot).timeout
	can_shoot = true

func attack_handler() -> void:
	if Input.is_action_just_pressed("ataque") and can_attack:
		can_attack = false
		arma.visible = false
		animation.play("attack")
		#son_attack.play()



func _on_animation_animation_finished(anim_name):
	match  anim_name:
		"attack": 
			can_attack = true
			arma.visible = true
	


func _on_attack_area_body_entered(body):
	if body.is_in_group("enemies"):
		body.update_health(dano)
		can_attack = false
		

func update_health(value: int) -> void:
	if is_dead or _invulnerable:
		return
	health = clampi(health - value, 0, GameManager.player_max_hp)
	GameManager.register_damage(value)
	ParticleFX.player_damage(get_tree().current_scene, global_position)
	GameManager.set_player_hp(health)
	if health <= 0:
		_die()
		return
	_start_invulnerability()


func heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(health + amount, GameManager.player_max_hp)
	GameManager.set_player_hp(health)


func _start_invulnerability() -> void:
	_invulnerable = true
	var tween := create_tween().set_loops(3)
	tween.tween_property(texture, "modulate", Color(1, 0.3, 0.3, 0.4), 0.1)
	tween.tween_property(texture, "modulate", Color.WHITE, 0.1)
	await get_tree().create_timer(INVULNERABILITY_TIME).timeout
	_invulnerable = false
	texture.modulate = Color.WHITE


func _die() -> void:
	# The player is no longer freed on death: GameManager shows Game Over and
	# the level is reloaded cleanly on retry.
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	arma.visible = false
	animation.pause()
	texture.modulate = Color(0.6, 0.1, 0.1)
	await get_tree().create_timer(0.8).timeout
	GameManager.on_player_died()


func _emit_ammo() -> void:
	var rounded := int(ammo)
	if rounded != _last_ammo_emitted:
		_last_ammo_emitted = rounded
		GameManager.set_ammo(ammo, max_ammo)


# wolf.tscn connects this signal but the handler was missing (caused an engine error).
func _on_pistol_animation_animation_finished(_anim_name: StringName) -> void:
	pass
