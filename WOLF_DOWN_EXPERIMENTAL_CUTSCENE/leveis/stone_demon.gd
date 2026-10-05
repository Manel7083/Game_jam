class_name StoneDemon
extends CharacterBody2D

## Wolf Down - Demônio de Pedra (guardião da gaiola).
## Arte em pixel art (gaiola/sprites/demon_*.png, 5 quadros de 32x32). Nasce como ESTÁTUA (imóvel e invulnerável);
## só vira inimigo (grupo "enemies") quando o level chama awaken().
##
## kind 0 = BRUTO DE PEDRA   : persegue e investe em linha reta (avisa antes de investir)
## kind 1 = ARREMESSADOR     : mantém distância e lança leques de estilhaços
## kind 2 = REI GÁRGULA      : rápido, investe e solta anel de estilhaços, também lança leques

signal woke
signal died(demon: StoneDemon)

enum State { DORMANT, WAKING, CHASE, WINDUP, CHARGE, RECOVER, DEAD }

const NAMES: Array[String] = ["BRUTO DE PEDRA", "ARREMESSADOR", "REI GÁRGULA"]
const HEALTH: Array[int] = [10, 14, 20]
const SPEED: Array[float] = [52.0, 44.0, 78.0]
const SIZE_K: Array[float] = [1.0, 0.92, 1.3]
const ATTACK_CD: Array[float] = [2.0, 1.7, 1.3]
const SPRITE_NAMES: Array[String] = ["bruto", "arremessador", "rei"]
const LAVA_COLORS: Array[Color] = [Color(1.0, 0.55, 0.2), Color(0.82, 0.4, 1.0), Color(1.0, 0.28, 0.24)]
const LIGHT_TEX_PATH := "res://bullet/light2D-gradient.png"
## Quadros da folha: 0 estátua, 1-2 idle, 3 aviso do ataque, 4 ataque.
const FRAME := 32

@export var kind: int = 0
@export var health_override: int = 0
## Limites da arena (estilhaços somem fora daqui). O level preenche.
@export var bounds: Rect2 = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)

var display_name: String = ""
var health: int = 10
var max_health: int = 10
var hit_radius: float = 26.0
var state: State = State.DORMANT

var _t: float = 0.0
var _state_time: float = 0.0
var _face: float = 1.0
var _flash: float = 0.0
var _shake: float = 0.0
var _k: float = 1.0
var _attack_cd: float = 1.0
var _contact_cd: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _attack_kind: String = "charge"
var _recover_time: float = 0.8
var _strafe: float = 1.0
var _bits: Array = []
var _spr: float = 2.0
var _tex: Texture2D
var _aura: PointLight2D


func _ready() -> void:
	kind = clampi(kind, 0, 2)
	display_name = NAMES[kind]
	max_health = health_override if health_override > 0 else HEALTH[kind]
	health = max_health
	_k = SIZE_K[kind]
	_spr = 2.0 * _k

	# Mesma convenção dos outros inimigos: camada 2 = inimigos (a bala da pistola e a faca do lobo
	# só enxergam a camada 2) e máscara 4 = paredes das fases.
	collision_layer = 2
	collision_mask = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hit_radius = 11.0 * _spr

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.5 * _spr
	shape.shape = circle
	shape.position = Vector2(0.0, -5.0 * _spr)
	shape.name = "BodyShape"
	add_child(shape)

	var sheet := "res://gaiola/sprites/demon_%s.png" % SPRITE_NAMES[kind]
	if ResourceLoader.exists(sheet):
		_tex = load(sheet)
	else:
		push_error("stone_demon: sprite não encontrado: " + sheet)

	# Luz de brasa (mesma técnica de PointLight2D das outras fases); acende quando o guardião acorda.
	_aura = PointLight2D.new()
	_aura.color = LAVA_COLORS[kind]
	_aura.energy = 0.0
	_aura.position = Vector2(0.0, -15.0 * _spr)
	_aura.texture_scale = 0.55 * _k
	if ResourceLoader.exists(LIGHT_TEX_PATH):
		_aura.texture = load(LIGHT_TEX_PATH)
	add_child(_aura)
	_strafe = 1.0 if randf() > 0.5 else -1.0


## Entrada usada pela bala da pistola (bullet.gd chama take_damage nos nós do grupo "enemies").
func take_damage(amount: int = 1, _source_position: Vector2 = Vector2.ZERO, _melee: bool = false) -> void:
	update_health(amount)


## Centro do corpo (usado pelas balas para acertar).
func hit_center() -> Vector2:
	return global_position + Vector2(0.0, -15.0 * _spr)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


func awaken() -> void:
	if state != State.DORMANT:
		return
	state = State.WAKING
	_state_time = 0.0
	_shake = 1.0
	add_to_group("enemies")
	woke.emit()


# ==============================================================================
# COMPORTAMENTO
# ==============================================================================

func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	_update_bits(delta)

	var pl = Global.Player
	var pl_ok: bool = is_instance_valid(pl) and not pl.is_dead
	_update_aura(delta)

	match state:
		State.DORMANT:
			velocity = Vector2.ZERO
		State.WAKING:
			_shake = 1.0 - _smooth(_state_time / 1.6) * 0.7
			if randf() < delta * 14.0:
				_spawn_bits(1, 0.5)
			if _state_time >= 1.6:
				_shake = 0.0
				_enter(State.CHASE)
				_attack_cd = 0.8
		State.CHASE:
			if pl_ok:
				_chase(delta, pl)
		State.WINDUP:
			velocity = Vector2.ZERO
			_shake = 0.35
			var wt: float = 0.7 if _attack_kind == "charge" else 0.6
			if _state_time >= wt:
				_shake = 0.0
				_begin_attack()
		State.CHARGE:
			var cspeed: float = 270.0 if kind == 0 else 330.0
			velocity = _charge_dir * cspeed
			if _state_time >= 0.5 or (_state_time > 0.12 and get_slide_collision_count() > 0):
				_end_charge()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_time >= _recover_time:
				_enter(State.CHASE)
		State.DEAD:
			velocity = Vector2.ZERO
			queue_redraw()
			return

	if state != State.DORMANT:
		move_and_slide()
	if pl_ok and is_awake():
		_check_contact(pl)
	queue_redraw()


func _update_aura(delta: float) -> void:
	if not is_instance_valid(_aura):
		return
	var target: float = 0.0
	match state:
		State.WAKING:
			target = _smooth(_state_time / 1.6) * 0.9
		State.WINDUP:
			target = 1.5
		State.CHARGE:
			target = 1.2
		State.CHASE, State.RECOVER:
			target = 0.8 + 0.5 * (1.0 - float(health) / float(max_health)) + 0.1 * sin(_t * 7.0)
	_aura.energy = move_toward(_aura.energy, target, delta * 3.0)


func _enter(s: State) -> void:
	state = s
	_state_time = 0.0


func _chase(delta: float, pl: Node2D) -> void:
	var to_p: Vector2 = pl.global_position - global_position
	var dist: float = to_p.length()
	var dir: Vector2 = to_p / maxf(dist, 0.001)
	if absf(to_p.x) > 4.0:
		_face = signf(to_p.x)
	var spd: float = SPEED[kind]
	_attack_cd -= delta

	match kind:
		0:
			velocity = dir * spd
			if dist < 150.0 and _attack_cd <= 0.0:
				_start_windup("charge", dir)
		1:
			if dist < 170.0:
				velocity = -dir * spd
			elif dist > 260.0:
				velocity = dir * spd
			else:
				velocity = dir.orthogonal() * spd * 0.6 * _strafe
			if fposmod(_t, 3.0) < delta:
				_strafe = -_strafe
			if _attack_cd <= 0.0:
				_start_windup("volley", dir)
		_:
			velocity = dir * spd
			if _attack_cd <= 0.0:
				_start_windup("charge" if dist < 220.0 else "volley", dir)


func _start_windup(what: String, dir: Vector2) -> void:
	_attack_kind = what
	_charge_dir = dir
	_enter(State.WINDUP)


func _begin_attack() -> void:
	if _attack_kind == "charge":
		_enter(State.CHARGE)
	else:
		_fire_volley()
		_recover_time = 0.55
		_attack_cd = ATTACK_CD[kind]
		_enter(State.RECOVER)


func _end_charge() -> void:
	_shake = 0.6
	if kind == 2:
		_fire_ring(10)
	_recover_time = 0.9
	_attack_cd = ATTACK_CD[kind]
	_enter(State.RECOVER)


func _check_contact(pl: Node2D) -> void:
	if _contact_cd > 0.0:
		return
	if state == State.WAKING:
		return
	if hit_center().distance_to(pl.global_position) < 9.0 * _spr + 14.0:
		pl.update_health(2 if state == State.CHARGE else 1)
		_contact_cd = 0.9


func _fire_volley() -> void:
	var pl = Global.Player
	if not is_instance_valid(pl):
		return
	var base: float = (pl.global_position - hit_center()).angle()
	var count: int = 3 if kind == 1 else 5
	var spread: float = 0.35 if kind == 1 else 0.28
	for i in count:
		var a: float = base + (float(i) - float(count - 1) * 0.5) * spread
		_spawn_shard(Vector2(cos(a), sin(a)))


func _fire_ring(n: int) -> void:
	var off: float = randf() * TAU
	for i in n:
		var a: float = off + TAU * float(i) / float(n)
		_spawn_shard(Vector2(cos(a), sin(a)))


func _spawn_shard(dir: Vector2) -> void:
	var s := Shard.new()
	s.dir = dir
	s.bounds = bounds
	s.speed = 170.0 if kind == 1 else 200.0
	get_parent().add_child(s)
	s.global_position = hit_center() + dir * 20.0


# ==============================================================================
# DANO
# ==============================================================================

func update_health(value: int) -> void:
	if state == State.DORMANT or state == State.WAKING or state == State.DEAD:
		return
	health -= value
	_flash = 1.0
	_spawn_bits(3, 0.6)
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	if is_in_group("enemies"):
		remove_from_group("enemies")
	var shape := get_node_or_null("BodyShape") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	_spawn_bits(26, 2.6)
	died.emit(self)
	await get_tree().create_timer(3.2).timeout
	queue_free()


func _spawn_bits(count: int, life: float) -> void:
	for i in count:
		var ang: float = randf() * TAU
		_bits.append({
			"p": Vector2(randf_range(-22.0, 22.0), randf_range(-70.0, -10.0)) * _k,
			"v": Vector2(cos(ang) * randf_range(30.0, 130.0), randf_range(-170.0, -40.0)),
			"r": randf() * TAU,
			"w": randf_range(-6.0, 6.0),
			"s": randf_range(3.0, 9.0),
			"life": life,
			"max": life,
			"ground": randf_range(-4.0, 14.0)
		})


func _update_bits(delta: float) -> void:
	var i: int = _bits.size() - 1
	while i >= 0:
		var b: Dictionary = _bits[i]
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			_bits.remove_at(i)
		else:
			var v: Vector2 = b["v"]
			v.y += 520.0 * delta
			var p: Vector2 = b["p"] + v * delta
			if p.y > float(b["ground"]):
				p.y = float(b["ground"])
				v = Vector2(v.x * 0.3, 0.0)
				b["w"] = float(b["w"]) * 0.3
			b["p"] = p
			b["v"] = v
			b["r"] = float(b["r"]) + float(b["w"]) * delta
		i -= 1


# ==============================================================================
# DESENHO
# ==============================================================================

func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _frame_index() -> int:
	match state:
		State.DORMANT:
			return 0
		State.WAKING:
			return 0 if _state_time < 1.0 else 1
		State.WINDUP:
			return 3
		State.CHARGE:
			return 4
		_:
			return 1 + (int(_t * 3.0) % 2)


func _draw() -> void:
	var awake_f: float = 0.0
	match state:
		State.DORMANT, State.DEAD:
			awake_f = 0.0
		State.WAKING:
			awake_f = _smooth(_state_time / 1.6)
		_:
			awake_f = 1.0

	# sombra
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2(0.0, 6.0), 14.0 * _spr, Color(0, 0, 0, 0.45 if state != State.DEAD else 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# telegrafia do ataque (faixa de investida)
	if state == State.WINDUP and _attack_kind == "charge":
		var pulse: float = 0.4 + 0.5 * sin(_state_time * 30.0)
		var a: Vector2 = Vector2(0.0, -10.0)
		draw_line(a, a + _charge_dir * 190.0, Color(1.0, 0.2, 0.15, 0.25 + 0.25 * pulse), 18.0 * _k)
		draw_line(a, a + _charge_dir * 190.0, Color(1.0, 0.5, 0.3, 0.55 * pulse), 3.0)

	# corpo (sprite)
	if _tex != null:
		var alpha: float = 1.0
		if state == State.DEAD:
			alpha = clampf(1.0 - _state_time / 0.9, 0.0, 1.0)
		if alpha > 0.0:
			var shake: Vector2 = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * _shake * 2.5
			var moving: bool = velocity.length() > 5.0
			var bob: float = roundf(absf(sin(_t * 9.0)) * 2.0) if moving else 0.0
			var off := Vector2(roundf(shake.x), roundf(shake.y - bob))
			# estátua escurecida -> acende ao acordar; flash vermelho ao levar dano
			var tint: Color = Color(0.78, 0.8, 0.86).lerp(Color.WHITE, awake_f)
			tint = tint.lerp(Color(1.0, 0.4, 0.4), _flash * 0.85)
			tint.a = alpha
			draw_set_transform(off, 0.0, Vector2(_face * _spr, _spr))
			draw_texture_rect_region(_tex, Rect2(-16.0, -30.0, 32.0, 32.0), Rect2(float(_frame_index() * FRAME), 0.0, 32.0, 32.0), tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# pedaços de pedra (estilhaços e escombros)
	for b in _bits:
		var al: float = clampf(float(b["life"]) / float(b["max"]) * 2.0, 0.0, 1.0)
		draw_set_transform(b["p"], float(b["r"]), Vector2.ONE)
		var s: float = float(b["s"])
		draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s * 0.8), Color(0.38, 0.40, 0.49, al))
		draw_rect(Rect2(-s * 0.5, -s * 0.5, s, 2.0), Color(0.54, 0.56, 0.66, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==============================================================================
# ESTILHAÇO (projétil do demônio) - sem física, só distância ao jogador
# ==============================================================================

class Shard extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 190.0
	var bounds: Rect2 = Rect2()
	var life: float = 4.0

	func _process(delta: float) -> void:
		global_position += dir * speed * delta
		rotation += delta * 9.0
		life -= delta
		var pl = Global.Player
		if is_instance_valid(pl) and not pl.is_dead and global_position.distance_to(pl.global_position) < 15.0:
			pl.update_health(1)
			queue_free()
			return
		if life <= 0.0 or (bounds.size.x > 0.0 and not bounds.has_point(global_position)):
			queue_free()
			return
		queue_redraw()

	static var _tex: Texture2D

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _tex == null and ResourceLoader.exists("res://gaiola/sprites/shard.png"):
			_tex = load("res://gaiola/sprites/shard.png")

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.45, 0.15, 0.12))
		if _tex != null:
			draw_texture_rect(_tex, Rect2(-12.0, -12.0, 24.0, 24.0), false)
