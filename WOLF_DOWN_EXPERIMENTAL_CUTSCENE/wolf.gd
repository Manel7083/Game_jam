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

# DASH (Shift no teclado / X no controle) - curto, com cooldown e i-frames
const DASH_SPEED := 320.0      # velocidade durante o dash (andar normal = 100)
const DASH_DURATION := 0.15    # ~48px de distância
const DASH_COOLDOWN := 0.8     # contado a partir do início do dash
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction := Vector2.ZERO
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0   # lido pela HUD (barra roxa de dash)
var dash_trail: GPUParticles2D

# REVÓLVER .38 (arma desbloqueada na fase da gaiola; persiste entre fases via GameManager.set_meta)
const REVOLVER_BULLET = preload("res://leveis/revolver_bullet.gd")
const REVOLVER_CYLINDER := 6
const REVOLVER_DAMAGE := 4
const REVOLVER_FIRE_DELAY := 0.38
const REVOLVER_RELOAD_TIME := 1.3
var has_revolver: bool = false

# SOM DOS TIROS: pool de players não posicionais (o som não fica preso na bala nem é cortado).
const PISTOL_SFX_PATH := "res://bullet/pistol_shot.wav"
const REVOLVER_SFX_PATH := "res://bullet/gunshot_38.wav"
const SHOT_POOL_SIZE := 6
# SOM DA RECARGA do .38 lendário (dura ~1.3s, igual REVOLVER_RELOAD_TIME)
const REVOLVER_RELOAD_SFX_PATH := "res://leveis/sons/revolver_lendario_reload.wav"
var _sfx_reload: AudioStreamPlayer
var _sfx_pistol: AudioStream
var _sfx_revolver: AudioStream
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var revolver_equipped: bool = false
var revolver_rounds: int = REVOLVER_CYLINDER
var reload_progress: float = 0.0   # 0 = sem recarga; 0..1 durante a recarga (lido pela HUD)
var _reloading: bool = false
var _reload_left: float = 0.0

# OLHOS NEON - posição dos olhos no sprite (pixels, relativo ao centro do frame 256x256)
const EYE_BASE_LEFT := Vector2(-8, -14)
const EYE_BASE_RIGHT := Vector2(6, -14)
# Deslocamento dos olhos em cada um dos 5 frames da animação "run" (foxy_walk.png)
const WALK_EYE_SHIFT = [Vector2(0, 0), Vector2(0, 4), Vector2(8, 0), Vector2(8, 0), Vector2(4, 8)]
var eye_left: Node2D
var eye_right: Node2D

func _ready():
	Global.Player = self
	_setup_dash_input()
	_setup_weapon_inputs()
	_setup_shot_audio()
	virtual_mouse_pos = global_position
	can_attack = true
	# HP now persists across levels through GameManager instead of resetting to 5.
	health = GameManager.player_hp
	GameManager.set_player_hp(health)
	GameManager.set_ammo(ammo, max_ammo)
	ParticleFX.attach_ambient_dust(self)
	dash_trail = ParticleFX.create_dash_trail(self)
	eye_left = ParticleFX.create_eye_fx(self)
	eye_right = ParticleFX.create_eye_fx(self)
	if GameManager.get_meta("has_revolver", false):
		has_revolver = true
		revolver_equipped = true
		_apply_weapon_visual()


func _exit_tree() -> void:
	# Avoid leaving enemies with a dangling reference to a freed player.
	if Global.Player == self:
		Global.Player = null


func _physics_process(delta: float) -> void:
	_update_eye_fx()
	# Cooldown do dash (antes era um await; agora é uma variável para a HUD poder mostrar a barra)
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
		if dash_cooldown_left <= 0.0:
			can_dash = true
	# Recarga do revólver
	if _reloading:
		_reload_left -= delta
		reload_progress = clampf(1.0 - _reload_left / REVOLVER_RELOAD_TIME, 0.01, 1.0)
		if _reload_left <= 0.0:
			_finish_reload()
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
	
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_start_dash()
	
	if is_dashing:
		dash_time_left -= delta
		velocity = dash_direction * DASH_SPEED
		if dash_time_left <= 0.0:
			_end_dash()
	else:
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
	
	if Input.is_action_just_pressed("weapon_swap") and has_revolver:
		_toggle_weapon()
	_revolver_logic(final_dir)
	
	if not revolver_equipped and Input.is_action_pressed("shoot") and can_shoot and not is_dashing and ammo >= ammo_cost:
		_shoot(final_dir)
		_play_shot(_sfx_pistol, -3.0, 1.0)
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

func _update_eye_fx() -> void:
	if is_dead or not is_instance_valid(eye_left) or not is_instance_valid(eye_right):
		return
	
	# Os olhos balançam junto com a animação de andar
	var shift := Vector2.ZERO
	if animation.current_animation == "run" and texture.hframes == 5 \
			and texture.frame < WALK_EYE_SHIFT.size():
		shift = WALK_EYE_SHIFT[texture.frame]
	
	# Espelha no eixo X quando o sprite está virado para a esquerda
	var flip := -1.0 if texture.flip_h else 1.0
	var left := EYE_BASE_LEFT + shift
	var right := EYE_BASE_RIGHT + shift
	eye_left.position = texture.position + Vector2(left.x * flip, left.y) * texture.scale
	eye_right.position = texture.position + Vector2(right.x * flip, right.y) * texture.scale
	
	# Rastro só quando está andando (e não durante o ataque)
	var moving := can_attack and velocity.length() > 5.0
	ParticleFX.set_eye_trail(eye_left, moving, velocity)
	ParticleFX.set_eye_trail(eye_right, moving, velocity)


func _setup_dash_input() -> void:
	# DASH:
	# Teclado: SHIFT
	# Controle: X
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")

	_add_key_input_if_missing("dash", KEY_SHIFT)
	_add_joypad_button_if_missing("dash", JOY_BUTTON_X)


func _add_key_input_if_missing(action: StringName, keycode: Key) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)


func _add_joypad_button_if_missing(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return

	var joy_button := InputEventJoypadButton.new()
	joy_button.button_index = button
	InputMap.action_add_event(action, joy_button)


func _start_dash() -> void:
	# Direção: o que o jogador está apertando; parado, dasha para onde o lobo olha.
	if move_direction.length() > 0.1:
		dash_direction = move_direction.normalized()
	else:
		dash_direction = Vector2.LEFT if texture.flip_h else Vector2.RIGHT
	
	is_dashing = true
	can_dash = false
	dash_time_left = DASH_DURATION
	dash_cooldown_left = DASH_COOLDOWN
	
	# Feedback visual: fica translúcido durante o dash
	var tween := create_tween()
	tween.tween_property(texture, "modulate:a", 0.4, 0.05)
	tween.tween_property(texture, "modulate:a", 1.0, DASH_DURATION)
	
	# Partículas: rajada roxa/amarela + rastro contínuo
	ParticleFX.dash_start(get_tree().current_scene, global_position, dash_direction)
	if dash_trail:
		dash_trail.emitting = true
	
	# O cooldown agora é contado em _physics_process (dash_cooldown_left)


func _end_dash() -> void:
	is_dashing = false
	dash_direction = Vector2.ZERO
	if dash_trail:
		dash_trail.emitting = false
	ParticleFX.dash_end(get_tree().current_scene, global_position)


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



func _setup_shot_audio() -> void:
	# Pistola: som novo (pistol_shot.wav). Se ele ainda não foi importado pelo Godot, usa o .38 como reserva.
	_sfx_revolver = load(REVOLVER_SFX_PATH)
	_sfx_pistol = load(PISTOL_SFX_PATH) if ResourceLoader.exists(PISTOL_SFX_PATH) else _sfx_revolver
	# Garante que o tiro toca UMA vez (o .wav estava importado com loop e repetia enquanto a bala voava).
	for s in [_sfx_pistol, _sfx_revolver]:
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_DISABLED
	for i in SHOT_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	# Player dedicado à recarga (assim dá para interromper se trocar de arma)
	_sfx_reload = AudioStreamPlayer.new()
	_sfx_reload.volume_db = -3.0
	if ResourceLoader.exists(REVOLVER_RELOAD_SFX_PATH):
		var rs := load(REVOLVER_RELOAD_SFX_PATH) as AudioStream
		if rs is AudioStreamWAV:
			rs.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_sfx_reload.stream = rs
	add_child(_sfx_reload)


func _play_shot(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


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
	if is_dead or _invulnerable or is_dashing:
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
	if dash_trail:
		dash_trail.emitting = false
	ParticleFX.stop_eye_fx(eye_left)
	ParticleFX.stop_eye_fx(eye_right)
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


# ==============================================================================
# REVÓLVER .38
# ==============================================================================

func _setup_weapon_inputs() -> void:
	# Troca de arma:
	# Teclado: TAB
	# Controle: R1 / RB
	if not InputMap.has_action("weapon_swap"):
		InputMap.add_action("weapon_swap")

	_add_key_input_if_missing("weapon_swap", KEY_TAB)
	_add_joypad_button_if_missing("weapon_swap", JOY_BUTTON_LEFT_SHOULDER)

	# Recarga:
	# Teclado: R
	if not InputMap.has_action("reload"):
		InputMap.add_action("reload")

	_add_key_input_if_missing("reload", KEY_R)


## Chamada pela fase da gaiola quando o jogador pega o revólver.
func equip_revolver() -> void:
	has_revolver = true
	revolver_equipped = true
	revolver_rounds = REVOLVER_CYLINDER
	_reloading = false
	reload_progress = 0.0
	GameManager.set_meta("has_revolver", true)
	_apply_weapon_visual()


func _toggle_weapon() -> void:
	revolver_equipped = not revolver_equipped
	if is_instance_valid(_sfx_reload):
		_sfx_reload.stop()   # trocou de arma no meio da recarga: corta o som
	_reloading = false
	reload_progress = 0.0
	_apply_weapon_visual()


func _apply_weapon_visual() -> void:
	# Enquanto não há sprite próprio do .38, a arma ganha um tom de metal/latão.
	arma_sprite.modulate = Color(1.0, 0.86, 0.55) if revolver_equipped else Color.WHITE


func _revolver_logic(direction: Vector2) -> void:
	if not revolver_equipped or is_dead:
		return
	if Input.is_action_just_pressed("reload") and not _reloading and revolver_rounds < REVOLVER_CYLINDER:
		_start_reload()
		return
	if Input.is_action_just_pressed("shoot") and can_shoot and not is_dashing and not _reloading:
		if revolver_rounds <= 0:
			_start_reload()
		else:
			_fire_revolver(direction)


func _start_reload() -> void:
	_reloading = true
	_reload_left = REVOLVER_RELOAD_TIME
	reload_progress = 0.01
	if is_instance_valid(_sfx_reload) and _sfx_reload.stream != null:
		_sfx_reload.play()


func _finish_reload() -> void:
	_reloading = false
	reload_progress = 0.0
	revolver_rounds = REVOLVER_CYLINDER


func _fire_revolver(direction: Vector2) -> void:
	can_shoot = false
	revolver_rounds -= 1
	GameManager.register_shot()
	var b := REVOLVER_BULLET.new()
	get_tree().current_scene.add_child(b)
	b.global_position = ponto_tiro.global_position
	b.damage = REVOLVER_DAMAGE
	b.set_direction(direction)
	_play_shot(_sfx_revolver, -4.0, 0.65)
	ParticleFX.muzzle_flash(get_tree().current_scene, ponto_tiro.global_position, direction)
	pistol_animation.play("fire")
	pistol_animation.speed_scale = 4.0
	# coice na câmera
	camera.offset = -direction * 5.0
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.14)
	await get_tree().create_timer(REVOLVER_FIRE_DELAY).timeout
	can_shoot = true
