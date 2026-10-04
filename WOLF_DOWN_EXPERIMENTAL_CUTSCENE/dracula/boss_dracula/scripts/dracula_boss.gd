class_name DraculaBoss
extends CharacterBody2D
## Boss final: Drácula. 3 fases, 5 ataques, teleporte, forma de morcego e morte com sinal.
##
## Como usar: instancie scenes/dracula_boss.tscn na fase, e (opcional) chame
## boss_health_bar.bind_boss(boss). O boss procura o Player no grupo "player"
## e recebe dano via take_damage(amount) (também aceita damage() e hit()).

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)
signal defeated

enum State { INTRO, CHASE, ATTACKING, DEAD }

@export_group("Atributos")
@export var max_health: int = 600
@export var move_speed: float = 70.0
@export var contact_damage: int = 1
@export var sprite_scale: float = 2.5

@export_group("Arena")
## Retângulo (coordenadas globais) onde o boss pode se teleportar/mover. Size 0 = sem limite.
@export var arena_rect: Rect2 = Rect2()

@export_group("Cenas")
@export var orb_scene: PackedScene = preload("res://boss_dracula/scenes/blood_orb.tscn")
@export var pool_scene: PackedScene = preload("res://boss_dracula/scenes/blood_pool.tscn")
@export var minion_scene: PackedScene = preload("res://boss_dracula/scenes/minion_bat.tscn")

const SPR := "res://boss_dracula/sprites/"

var health: int
var phase: int = 1
var state: State = State.INTRO
var invulnerable: bool = true

var _sprite: AnimatedSprite2D
var _contact: Area2D
var _contact_cd := 0.0
var _attack_cd := 1.5
var _strafe_dir := 1.0
var _dash_dir := Vector2.ZERO
var _dash_speed := 0.0
var _last_attack := -1
var _player: Node2D


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	health = max_health

	# colisão do corpo
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	body_shape.shape = circle
	body_shape.position = Vector2(0, 8)
	add_child(body_shape)

	# hurtbox (para balas Area2D)
	var hurt := Area2D.new()
	hurt.set_script(load("res://boss_dracula/scripts/boss_hurtbox.gd"))
	hurt.collision_layer = 1
	hurt.collision_mask = 0
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = 18.0
	hs.shape = hc
	hs.position = Vector2(0, 4)
	hurt.add_child(hs)
	add_child(hurt)

	# dano por contato
	_contact = Area2D.new()
	_contact.collision_layer = 0
	_contact.collision_mask = 0xFFFFFFFF
	var cs := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = 20.0
	cs.shape = cc
	_contact.add_child(cs)
	add_child(_contact)

	# sprites
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * sprite_scale
	var f := SpriteFrames.new()
	f.remove_animation("default")
	BossUtils.add_strip(f, "idle", SPR + "dracula_idle.png", 32, 5.0, true)
	BossUtils.add_strip(f, "walk", SPR + "dracula_walk.png", 32, 8.0, true)
	BossUtils.add_strip(f, "cast", SPR + "dracula_cast.png", 32, 8.0, false)
	BossUtils.add_strip(f, "roar", SPR + "dracula_roar.png", 32, 8.0, true)
	BossUtils.add_strip(f, "hurt", SPR + "dracula_hurt.png", 32, 12.0, false)
	BossUtils.add_strip(f, "death", SPR + "dracula_death.png", 32, 4.0, false)
	BossUtils.add_strip(f, "bat", SPR + "dracula_bat.png", 32, 14.0, true)
	_sprite.sprite_frames = f
	add_child(_sprite)

	health_changed.emit(health, max_health)
	_intro()


func _intro() -> void:
	state = State.INTRO
	invulnerable = true
	_sprite.modulate.a = 0.0
	_sprite.play("idle")
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(1.2).timeout
	_sprite.play("roar")
	BossUtils.shake(self, 8.0, 1.2)
	await get_tree().create_timer(1.3).timeout
	invulnerable = false
	state = State.CHASE
	_attack_cd = 1.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = BossUtils.get_player(get_tree())

	_contact_cd = maxf(0.0, _contact_cd - delta)
	_check_contact()

	match state:
		State.CHASE:
			_do_chase(delta)
		State.ATTACKING:
			# durante a investida o corpo se move; nos outros ataques _dash_speed = 0
			if _dash_speed > 0.0:
				velocity = _dash_dir * _dash_speed
				move_and_slide()
				_clamp_to_arena()
			else:
				velocity = Vector2.ZERO


func _do_chase(delta: float) -> void:
	if _player == null:
		_sprite.play("idle")
		return
	var to := _player.global_position - global_position
	var dist := to.length()
	var dir := to.normalized()
	var speed := move_speed * (1.0 + 0.25 * (phase - 1))
	var want := Vector2.ZERO
	if dist > 190.0:
		want = dir
	elif dist < 110.0:
		want = -dir * 0.8 + dir.orthogonal() * _strafe_dir * 0.6
	else:
		want = dir.orthogonal() * _strafe_dir * 0.7
	velocity = want.normalized() * speed if want != Vector2.ZERO else Vector2.ZERO
	move_and_slide()
	_clamp_to_arena()
	_face(to.x)
	if velocity.length() > 5.0:
		if _sprite.animation != "walk":
			_sprite.play("walk")
	elif _sprite.animation != "idle":
		_sprite.play("idle")

	if randf() < delta * 0.4:
		_strafe_dir *= -1.0

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_choose_attack()


func _face(dx: float) -> void:
	if absf(dx) > 4.0:
		_sprite.flip_h = dx < 0.0


func _check_contact() -> void:
	if _contact_cd > 0.0 or state == State.INTRO:
		return
	for b in _contact.get_overlapping_bodies():
		if b.is_in_group("player"):
			BossUtils.damage_player(b, contact_damage + (1 if _dash_speed > 0.0 else 0))
			_contact_cd = 1.0
			return


func _clamp_to_arena() -> void:
	if arena_rect.size != Vector2.ZERO:
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)


# ------------------------------------------------------------------ DANO / FASES

func take_damage(amount: int = 1) -> void:
	if state == State.DEAD or invulnerable:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_flash()
	_update_phase()
	if health <= 0:
		_die()


func damage(amount: int = 1) -> void:
	take_damage(amount)


func hit(amount: int = 1) -> void:
	take_damage(amount)


func _flash() -> void:
	_sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _update_phase() -> void:
	var ratio := float(health) / float(max_health)
	var new_phase := 1
	if ratio <= 0.33:
		new_phase = 3
	elif ratio <= 0.66:
		new_phase = 2
	if new_phase != phase and health > 0:
		phase = new_phase
		phase_changed.emit(phase)
		_phase_transition()


func _phase_transition() -> void:
	# o boss fica invulnerável, ruge, invoca morcegos e volta ao combate
	if state == State.DEAD:
		return
	state = State.ATTACKING
	_dash_speed = 0.0
	invulnerable = true
	_sprite.play("roar")
	BossUtils.shake(self, 10.0, 1.0)
	_ring_of_orbs(12, 180.0)
	await get_tree().create_timer(1.0).timeout
	if state == State.DEAD:
		return
	_spawn_minions(2 + phase)
	await get_tree().create_timer(0.6).timeout
	if state == State.DEAD:
		return
	invulnerable = false
	state = State.CHASE
	_attack_cd = 1.2


func _die() -> void:
	state = State.DEAD
	invulnerable = true
	_dash_speed = 0.0
	velocity = Vector2.ZERO
	# remove projéteis/lacaios restantes
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.queue_free()
	_sprite.modulate = Color.WHITE
	_sprite.play("death")
	BossUtils.shake(self, 12.0, 1.5)
	await get_tree().create_timer(2.2).timeout
	defeated.emit()
	queue_free()


# ------------------------------------------------------------------ ATAQUES

func _choose_attack() -> void:
	# pool de ataques por fase: 0 orbes, 1 morcegos, 2 teleporte, 3 investida, 4 poças
	var pool: Array[int] = [0, 2, 4]
	if phase >= 2:
		pool.append_array([1, 3])
	if phase >= 3:
		pool.append_array([0, 3, 4])
	var pick: int = pool.pick_random()
	if pick == _last_attack and pool.size() > 1:
		pick = pool.pick_random()
	_last_attack = pick

	state = State.ATTACKING
	_dash_speed = 0.0
	match pick:
		0: _attack_orbs()
		1: _attack_bats()
		2: _attack_teleport()
		3: _attack_bat_dash()
		4: _attack_pools()


func _end_attack(cooldown: float = -1.0) -> void:
	if state == State.DEAD or invulnerable:
		return  # morto ou em transição de fase
	_dash_speed = 0.0
	state = State.CHASE
	if cooldown < 0.0:
		cooldown = [2.4, 1.8, 1.2][phase - 1]
	_attack_cd = cooldown


func _alive() -> bool:
	return state != State.DEAD and is_inside_tree()


func _aim() -> Vector2:
	if _player == null:
		return Vector2.DOWN
	return (_player.global_position - global_position).normalized()


## Ataque 1: leque de orbes (fase 1: 3, fase 2: 5 + anel, fase 3: espiral)
func _attack_orbs() -> void:
	_face(_aim().x)
	_sprite.play("cast")
	await get_tree().create_timer(0.5).timeout
	if not _alive(): return
	var base := _aim()
	match phase:
		1:
			_fan(base, 3, 0.35, 230.0)
		2:
			_fan(base, 5, 0.3, 250.0)
			await get_tree().create_timer(0.6).timeout
			if not _alive(): return
			_ring_of_orbs(10, 190.0)
		3:
			for i in 16:
				if not _alive(): return
				var a := base.rotated(i * 0.45)
				_spawn_orb(a, 240.0)
				await get_tree().create_timer(0.07).timeout
			_fan(_aim(), 7, 0.25, 270.0)
	await get_tree().create_timer(0.4).timeout
	_end_attack()


## Ataque 2: invoca morcegos
func _attack_bats() -> void:
	_sprite.play("roar")
	BossUtils.shake(self, 5.0, 0.5)
	await get_tree().create_timer(0.8).timeout
	if not _alive(): return
	_spawn_minions(2 + phase * 1)
	await get_tree().create_timer(0.7).timeout
	_end_attack(2.2)


## Ataque 3: some em névoa, reaparece perto do jogador e atira
func _attack_teleport() -> void:
	invulnerable = true
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	await tw.finished
	if not _alive(): return
	await get_tree().create_timer(0.35).timeout
	if not _alive(): return
	if _player:
		var ang := randf() * TAU
		global_position = _player.global_position + Vector2.from_angle(ang) * randf_range(150.0, 230.0)
		_clamp_to_arena()
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "modulate:a", 1.0, 0.25)
	await tw2.finished
	if not _alive(): return
	invulnerable = false
	_face(_aim().x)
	_sprite.play("cast")
	await get_tree().create_timer(0.45).timeout
	if not _alive(): return
	_fan(_aim(), 3 + phase, 0.3, 240.0)
	await get_tree().create_timer(0.5).timeout
	_end_attack(1.4)


## Ataque 4: forma de morcego - investidas rápidas contra o jogador
func _attack_bat_dash() -> void:
	_sprite.play("bat")
	var dashes := 2 + phase
	for i in dashes:
		if not _alive(): return
		# telégrafo: pára e mira
		_dash_speed = 0.0
		_face(_aim().x)
		_sprite.modulate = Color(1.6, 0.8, 0.8)
		await get_tree().create_timer(0.55 - 0.08 * phase).timeout
		if not _alive(): return
		_sprite.modulate = Color.WHITE
		_dash_dir = _aim()
		_dash_speed = 380.0 + 40.0 * phase
		await get_tree().create_timer(0.5).timeout
	if not _alive(): return
	_dash_speed = 0.0
	_sprite.play("idle")
	await get_tree().create_timer(0.5).timeout
	_end_attack(2.0)


## Ataque 5: poças de sangue (aviso de 1s, depois explodem)
func _attack_pools() -> void:
	_sprite.play("cast")
	var count := 2 + phase * 2
	for i in count:
		if not _alive(): return
		var pos := global_position
		if _player:
			pos = _player.global_position
			if i > 0:
				pos += Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		_spawn_pool(pos)
		await get_tree().create_timer(0.55 - 0.08 * phase).timeout
	await get_tree().create_timer(0.8).timeout
	_end_attack(1.6)


# ------------------------------------------------------------------ SPAWNERS

func _spawn_orb(dir: Vector2, spd: float) -> void:
	var o := orb_scene.instantiate()
	o.global_position = global_position + dir * 20.0 + Vector2(0, 4)
	get_parent().add_child(o)
	o.launch(dir, spd)


func _fan(base: Vector2, count: int, spread: float, spd: float) -> void:
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		_spawn_orb(base.rotated(t * spread * 2.0), spd)


func _ring_of_orbs(count: int, spd: float) -> void:
	var off := randf() * TAU
	for i in count:
		_spawn_orb(Vector2.from_angle(off + TAU * i / count), spd)


func _spawn_pool(pos: Vector2) -> void:
	var p := pool_scene.instantiate()
	p.global_position = pos
	get_parent().add_child(p)


func _spawn_minions(n: int) -> void:
	var alive := get_tree().get_nodes_in_group("boss_minion").size()
	n = mini(n, 8 - alive)
	for i in n:
		var m := minion_scene.instantiate()
		m.global_position = global_position + Vector2.from_angle(TAU * i / maxf(n, 1)) * 40.0
		get_parent().add_child(m)
