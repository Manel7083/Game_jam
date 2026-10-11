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
## Marcas do glifo de invocação desenhado no chão, embaixo de cada estátua.
const RUNE_TICKS := 12
## Intervalo entre passadas (s) de cada tipo: o Bruto pisa pesado e devagar, o Rei é rápido.
const STEP_INTERVAL: Array[float] = [0.55, 0.40, 0.28]

@export var kind: int = 0
@export var health_override: int = 0
## DIFICULDADE (o level preenche; 1.0 / 0 = valores originais).
## Multiplica a vida base do guardião.
@export var health_mult: float = 1.0
## Dano extra no jogador (contato, investida e estilhaços).
@export var damage_bonus: int = 0
## Multiplica a velocidade de perseguição, da investida e dos estilhaços.
@export var speed_mult: float = 1.0
## Multiplica a frequência dos ataques (1.25 = ataca 25% mais rápido).
@export var attack_rate_mult: float = 1.0
## true = ao morrer o corpo continua na cena (some visualmente) para poder voltar com revive().
@export var keep_corpse: bool = false
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
## Camadas de efeitos (brilho aditivo): uma ATRÁS do corpo (glifo, anéis) e uma NA FRENTE (brilho, brasas).
var _fx_under: Node2D
var _fx_over: Node2D
var _add_mat: CanvasItemMaterial
var _rings: Array = []
var _embers: Array = []
var _dust: Array = []
var _trail: Array = []
var _trail_cd: float = 0.0
var _dust_cd: float = 0.0
var _step_cd: float = 0.0


func _ready() -> void:
	kind = clampi(kind, 0, 2)
	display_name = NAMES[kind]
	max_health = health_override if health_override > 0 else maxi(1, roundi(float(HEALTH[kind]) * health_mult))
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

	# Camadas de efeito com mistura ADITIVA e sem sofrer escurecimento da luz (brilham de verdade no escuro).
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fx_under = Node2D.new()
	_fx_under.name = "FxUnder"
	_fx_under.show_behind_parent = true
	_fx_under.material = _add_mat
	_fx_under.draw.connect(_draw_fx_under)
	add_child(_fx_under)
	_fx_over = Node2D.new()
	_fx_over.name = "FxOver"
	_fx_over.material = _add_mat
	_fx_over.draw.connect(_draw_fx_over)
	add_child(_fx_over)
	_strafe = 1.0 if randf() > 0.5 else -1.0


## Entrada usada pela bala da pistola (bullet.gd chama take_damage nos nós do grupo "enemies").
func take_damage(amount: int = 1, _source_position: Vector2 = Vector2.ZERO, _melee: bool = false) -> void:
	update_health(amount)


## Centro do corpo (usado pelas balas para acertar).
func hit_center() -> Vector2:
	return global_position + Vector2(0.0, -15.0 * _spr)


## Som único de cada guardião (res://audio/gaiola/sfx/<tipo>_<evento>.ogg), tocado na posição dele.
func _snd(event: String) -> void:
	GaiolaAudio.demon(self, kind, event, global_position)


func is_awake() -> bool:
	return state != State.DORMANT and state != State.DEAD


func awaken() -> void:
	if state != State.DORMANT:
		return
	state = State.WAKING
	_state_time = 0.0
	_shake = 1.0
	add_to_group("enemies")
	_add_ring(LAVA_COLORS[kind], 46.0 * _k, 0.6)
	_snd("wake")
	woke.emit()


## Volta dos mortos: levanta de novo (acorda como no começo: ~1.6 s imóvel e invulnerável) e a partir
## daí morre de vez. `health_factor` multiplica a vida da volta (1.0 = vida cheia, igual à primeira vez).
func revive(health_factor: float = 1.0) -> void:
	if state != State.DEAD:
		return
	keep_corpse = false
	max_health = maxi(1, roundi(float(max_health) * health_factor))
	health = max_health
	velocity = Vector2.ZERO
	_flash = 0.0
	_contact_cd = 0.0
	_bits.clear()
	var shape := get_node_or_null("BodyShape") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", false)
	state = State.WAKING
	_state_time = 0.0
	_shake = 1.0
	_spawn_bits(22, 1.2)
	_trail.clear()
	_add_ring(LAVA_COLORS[kind], 70.0 * _k, 0.8)
	add_to_group("enemies")
	_snd("revive")
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
	_update_fx(delta)

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
			if fposmod(_state_time, 0.5) < delta:
				_add_ring(LAVA_COLORS[kind], 34.0 * _k, 0.5)
			if _state_time >= 1.6:
				_shake = 0.0
				_add_ring(LAVA_COLORS[kind], 90.0 * _k, 0.7)
				_spawn_bits(10, 0.8)
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
			var cspeed: float = (270.0 if kind == 0 else 330.0) * speed_mult
			velocity = _charge_dir * cspeed
			if _state_time >= 0.5 or (_state_time > 0.12 and get_slide_collision_count() > 0):
				_end_charge()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_time >= _recover_time:
				_enter(State.CHASE)
		State.DEAD:
			velocity = Vector2.ZERO
			_redraw_all()
			return

	if state != State.DORMANT:
		move_and_slide()
	if state == State.CHASE and velocity.length() > 5.0:
		_step_cd -= delta
		if _step_cd <= 0.0:
			_step_cd = STEP_INTERVAL[kind]
			_snd("step")
	if pl_ok and is_awake():
		_check_contact(pl)
	_redraw_all()


func _update_aura(delta: float) -> void:
	if not is_instance_valid(_aura):
		return
	var target: float = 0.0
	match state:
		State.DORMANT:
			target = 0.1 + 0.05 * sin(_t * 1.5)
		State.WAKING:
			target = _smooth(_state_time / 1.6) * 0.9
		State.WINDUP:
			target = 1.5
		State.CHARGE:
			target = 1.2
		State.CHASE, State.RECOVER:
			target = 0.8 + 0.5 * (1.0 - float(health) / float(max_health)) + 0.1 * sin(_t * 7.0) + 0.06 * sin(_t * 17.3)
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
	var spd: float = SPEED[kind] * speed_mult
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
	_snd("windup" if what == "charge" else "windup_volley")
	_attack_kind = what
	_charge_dir = dir
	_enter(State.WINDUP)


func _begin_attack() -> void:
	if _attack_kind == "charge":
		_snd("charge")
		_enter(State.CHARGE)
	else:
		_fire_volley()
		_recover_time = 0.55
		_attack_cd = ATTACK_CD[kind] / attack_rate_mult
		_enter(State.RECOVER)


func _end_charge() -> void:
	_shake = 0.6
	_add_ring(LAVA_COLORS[kind], 64.0 * _k, 0.45)
	_spawn_dust(8)
	_snd("ring" if kind == 2 else "slam")
	if kind == 2:
		_fire_ring(10)
	_recover_time = 0.9
	_attack_cd = ATTACK_CD[kind] / attack_rate_mult
	_enter(State.RECOVER)


func _check_contact(pl: Node2D) -> void:
	if _contact_cd > 0.0:
		return
	if state == State.WAKING:
		return
	if hit_center().distance_to(pl.global_position) < 9.0 * _spr + 14.0:
		pl.update_health((2 if state == State.CHARGE else 1) + damage_bonus)
		_contact_cd = 0.9


func _fire_volley() -> void:
	var pl = Global.Player
	if not is_instance_valid(pl):
		return
	_snd("shoot")
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
	s.speed = (170.0 if kind == 1 else 200.0) * speed_mult
	s.damage = 1 + damage_bonus
	s.color = LAVA_COLORS[kind]
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
	else:
		_snd("hurt")


func _die() -> void:
	_snd("die")
	state = State.DEAD
	_state_time = 0.0   # a animação de desmoronar conta a partir daqui
	_shake = 0.3
	_add_ring(LAVA_COLORS[kind], 80.0 * _k, 0.7)
	if is_in_group("enemies"):
		remove_from_group("enemies")
	var shape := get_node_or_null("BodyShape") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	_spawn_bits(26, 2.6)
	died.emit(self)
	if keep_corpse:
		return
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
## Camadas: [FxUnder: glifo no chão e ondas de choque] -> [corpo: sombra, poeira, contorno, sprite]
## -> [FxOver: brilho de calor, varredura do despertar, clarão de dano, rastro e brasas].
## Tudo é desenhado em código por cima do sprite, então continua valendo se você trocar os PNGs.

func _smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _awake_factor() -> float:
	match state:
		State.DORMANT, State.DEAD:
			return 0.0
		State.WAKING:
			return _smooth(_state_time / 1.6)
	return 1.0


func _hp_lost() -> float:
	return clampf(1.0 - float(health) / float(maxi(max_health, 1)), 0.0, 1.0)


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


func _body_offset() -> Vector2:
	var shake: Vector2 = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * _shake * 2.5
	var bob: float = roundf(absf(sin(_t * 9.0)) * 2.0) if velocity.length() > 5.0 else 0.0
	return Vector2(roundf(shake.x), roundf(shake.y - bob))


func _redraw_all() -> void:
	queue_redraw()
	if is_instance_valid(_fx_under):
		_fx_under.queue_redraw()
	if is_instance_valid(_fx_over):
		_fx_over.queue_redraw()


## Desenha uma faixa de linhas (y0, n) do quadro `frame` em qualquer camada.
func _draw_sprite(c: CanvasItem, off: Vector2, face: float, frame: int, col: Color, y0: int = 0, n: int = FRAME) -> void:
	if _tex == null or n <= 0:
		return
	c.draw_set_transform(off, 0.0, Vector2(face * _spr, _spr))
	c.draw_texture_rect_region(_tex, Rect2(-16.0, -30.0 + float(y0), 32.0, float(n)), Rect2(float(frame * FRAME), float(y0), 32.0, float(n)), col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- efeitos (lógica)

func _add_ring(col: Color, radius: float, dur: float) -> void:
	_rings.append({"t": 0.0, "d": dur, "r": radius, "c": col})


func _spawn_ember() -> void:
	_embers.append({
		"p": Vector2(randf_range(-12.0, 12.0), randf_range(-38.0, -4.0)) * _k,
		"v": Vector2(randf_range(-10.0, 10.0), randf_range(-46.0, -20.0)),
		"life": randf_range(0.5, 1.1),
		"max": 1.1,
		"s": 2.0 + float(randi() % 2)
	})


func _spawn_dust(count: int) -> void:
	for i in count:
		_dust.append({
			"p": Vector2(randf_range(-9.0, 9.0) * _k, randf_range(-1.0, 5.0)),
			"v": Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, -6.0)),
			"life": 0.5,
			"max": 0.5,
			"s": randf_range(2.5, 5.0)
		})


func _age_list(list: Array, delta: float, drag: float) -> void:
	var i: int = list.size() - 1
	while i >= 0:
		var e: Dictionary = list[i]
		e["life"] = float(e["life"]) - delta
		if float(e["life"]) <= 0.0:
			list.remove_at(i)
		elif e.has("v"):
			var v: Vector2 = e["v"]
			e["p"] = Vector2(e["p"]) + v * delta
			e["v"] = v * maxf(1.0 - drag * delta, 0.0)
		i -= 1


func _update_fx(delta: float) -> void:
	# ondas de choque
	var i: int = _rings.size() - 1
	while i >= 0:
		var r: Dictionary = _rings[i]
		r["t"] = float(r["t"]) + delta
		if float(r["t"]) >= float(r["d"]):
			_rings.remove_at(i)
		i -= 1

	# brasas sobem do corpo; quanto mais ferido, mais brasas
	var af: float = _awake_factor()
	if af > 0.0 and state != State.DEAD:
		var rate: float = (5.0 + 14.0 * _hp_lost()) * af * (0.6 + 0.4 * _k)
		if state == State.WINDUP:
			rate += 25.0
		if randf() < rate * delta:
			_spawn_ember()
	_age_list(_embers, delta, 0.0)

	# rastro da investida
	if state == State.CHARGE:
		_trail_cd -= delta
		if _trail_cd <= 0.0:
			_trail_cd = 0.035
			_trail.append({"p": global_position, "f": _face, "fr": _frame_index(), "life": 0.25, "max": 0.25})
	var j: int = _trail.size() - 1
	while j >= 0:
		var tr: Dictionary = _trail[j]
		tr["life"] = float(tr["life"]) - delta
		if float(tr["life"]) <= 0.0:
			_trail.remove_at(j)
		j -= 1

	# poeira dos pés
	if is_awake() and velocity.length() > 5.0:
		_dust_cd -= delta
		if _dust_cd <= 0.0:
			_dust_cd = 0.07 if state == State.CHARGE else 0.16
			_spawn_dust(1)
	_age_list(_dust, delta, 3.0)


# ---------------------------------------------------------------- corpo

func _draw() -> void:
	var af: float = _awake_factor()
	var col: Color = LAVA_COLORS[kind]

	# sombra suave (3 elipses concêntricas)
	var sa: float = 0.5 if state != State.DEAD else 0.2
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 15.0 * _spr, Color(0, 0, 0, sa * 0.30))
	draw_circle(Vector2.ZERO, 11.5 * _spr, Color(0, 0, 0, sa * 0.40))
	draw_circle(Vector2.ZERO, 8.0 * _spr, Color(0, 0, 0, sa * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_telegraph(col)

	# poeira
	for d in _dust:
		var da: float = clampf(float(d["life"]) / float(d["max"]), 0.0, 1.0)
		draw_circle(d["p"], float(d["s"]) * (1.6 - 0.6 * da), Color(0.55, 0.56, 0.64, 0.38 * da))

	# corpo (sprite)
	if _tex != null:
		var off: Vector2 = _body_offset()
		if state == State.DEAD:
			_draw_crumble(off)
		else:
			var fi: int = _frame_index()
			# contorno escuro de 1 pixel (esquenta para vermelho-brasa quando acorda)
			var oc: Color = Color(0.06, 0.03, 0.09, 0.9).lerp(Color(col.r * 0.35, col.g * 0.2, col.b * 0.2, 0.95), af * 0.6)
			for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var dv: Vector2 = dir
				_draw_sprite(self, off + dv * _spr, _face, fi, oc)
			# estátua escurecida -> acende ao acordar; flash vermelho ao levar dano
			var tint: Color = Color(0.78, 0.8, 0.86).lerp(Color.WHITE, af)
			tint = tint.lerp(Color(1.0, 0.4, 0.4), _flash * 0.85)
			_draw_sprite(self, off, _face, fi, tint)

	# pedaços de pedra (estilhaços e escombros)
	for b in _bits:
		var al: float = clampf(float(b["life"]) / float(b["max"]) * 2.0, 0.0, 1.0)
		draw_set_transform(b["p"], float(b["r"]), Vector2.ONE)
		var s: float = float(b["s"])
		draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s * 0.8), Color(0.38, 0.40, 0.49, al))
		draw_rect(Rect2(-s * 0.5, -s * 0.5, s, 2.0), Color(0.54, 0.56, 0.66, al))
		draw_rect(Rect2(-s * 0.5, s * 0.3 - 1.0, s, 1.5), Color(0.2, 0.21, 0.28, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Aviso dos ataques: faixa da investida com setas correndo / linhas de mira do leque.
func _draw_telegraph(col: Color) -> void:
	if state != State.WINDUP:
		return
	var wt: float = 0.7 if _attack_kind == "charge" else 0.6
	var prog: float = clampf(_state_time / wt, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_state_time * 30.0)
	if _attack_kind == "charge":
		var a: Vector2 = Vector2(0.0, -10.0)
		var dir: Vector2 = _charge_dir
		var perp: Vector2 = dir.orthogonal()
		var w: float = 10.0 * _k
		var length: float = 190.0 * (0.35 + 0.65 * _smooth(prog * 2.0))
		var pts := PackedVector2Array([a + perp * w, a + dir * length + perp * w, a + dir * length - perp * w, a - perp * w])
		draw_colored_polygon(pts, Color(1.0, 0.2, 0.15, 0.12 + 0.12 * pulse))
		draw_line(a + perp * w, a + dir * length + perp * w, Color(1.0, 0.45, 0.3, 0.5 + 0.3 * pulse), 2.0)
		draw_line(a - perp * w, a + dir * length - perp * w, Color(1.0, 0.45, 0.3, 0.5 + 0.3 * pulse), 2.0)
		for i in 4:
			var d: float = fposmod(_state_time * 260.0 + float(i) * 48.0, length)
			var c: Vector2 = a + dir * d
			var ca: float = 0.7 * (1.0 - d / length)
			draw_polyline(PackedVector2Array([c - dir * 6.0 + perp * 8.0, c, c - dir * 6.0 - perp * 8.0]), Color(1.0, 0.6, 0.4, ca), 2.0)
	else:
		var center: Vector2 = Vector2(0.0, -15.0 * _spr)
		var count: int = 3 if kind == 1 else 5
		var spread: float = 0.35 if kind == 1 else 0.28
		var base: float = _charge_dir.angle()
		var pl = Global.Player
		if is_instance_valid(pl):
			base = (pl.global_position - hit_center()).angle()
		for i in count:
			var ang: float = base + (float(i) - float(count - 1) * 0.5) * spread
			var dv: Vector2 = Vector2(cos(ang), sin(ang))
			draw_dashed_line(center + dv * 24.0, center + dv * (40.0 + 120.0 * prog), Color(col.r, col.g, col.b, 0.25 + 0.5 * prog), 2.0, 6.0)


## Morte: o corpo desmorona em 8 fatias, de cima para baixo, afundando e sumindo.
func _draw_crumble(off: Vector2) -> void:
	var slices: int = 8
	var h: int = 4
	for i in slices:
		var t: float = clampf((_state_time - float(i) * 0.06) / 0.5, 0.0, 1.0)
		if t >= 1.0:
			continue
		var o: Vector2 = off + Vector2(sin(float(i) * 7.3) * t * 7.0, t * t * 16.0)
		draw_set_transform(o, 0.0, Vector2(_face * _spr, _spr))
		draw_texture_rect_region(_tex, Rect2(-16.0, -30.0 + float(i * h), 32.0, float(h)), Rect2(float(FRAME), float(i * h), 32.0, float(h)), Color(0.78, 0.8, 0.86, 1.0 - t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- camada de trás (chão)

func _draw_fx_under() -> void:
	var c: Node2D = _fx_under
	var col: Color = LAVA_COLORS[kind]
	var af: float = _awake_factor()
	var ga: float
	match state:
		State.DORMANT:
			ga = 0.10 + 0.04 * sin(_t * 1.5)
		State.DEAD:
			ga = clampf(0.45 - _state_time * 0.5, 0.0, 0.45)
		State.WINDUP:
			ga = 0.5 + 0.2 * sin(_state_time * 30.0)
		_:
			ga = lerpf(0.10, 0.38 + 0.12 * sin(_t * 3.0), af)

	var rad: float = 17.0 * _spr
	c.draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.38))
	if ga > 0.0:
		# poça de luz
		for i in 4:
			c.draw_circle(Vector2.ZERO, rad * (1.35 - float(i) * 0.22), Color(col.r, col.g, col.b, ga * 0.10))
		# anéis do glifo
		c.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(col.r, col.g, col.b, ga), 3.0)
		c.draw_arc(Vector2.ZERO, rad * 0.72, 0.0, TAU, 40, Color(col.r, col.g, col.b, ga * 0.7), 2.0)
		# marcas girando
		for i in RUNE_TICKS:
			var ang: float = _t * 0.5 + TAU * float(i) / float(RUNE_TICKS)
			var dv: Vector2 = Vector2(cos(ang), sin(ang))
			c.draw_line(dv * rad * 0.80, dv * rad * 0.97, Color(col.r, col.g, col.b, ga * 1.1), 3.0)
		# hexagrama (dois triângulos girando)
		for k in 2:
			var pts := PackedVector2Array()
			var rot: float = -_t * 0.35 + float(k) * PI / 3.0
			for v in 4:
				var a2: float = rot + TAU * float(v % 3) / 3.0
				pts.append(Vector2(cos(a2), sin(a2)) * rad * 0.6)
			c.draw_polyline(pts, Color(col.r, col.g, col.b, ga * 0.8), 2.0)

	# ondas de choque
	for r in _rings:
		var p: float = clampf(float(r["t"]) / float(r["d"]), 0.0, 1.0)
		var radius: float = float(r["r"]) * (1.0 - (1.0 - p) * (1.0 - p))
		var rc: Color = r["c"]
		c.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(rc.r, rc.g, rc.b, (1.0 - p) * 0.9), 3.0 + 3.0 * (1.0 - p))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- camada da frente (brilho)

func _draw_fx_over() -> void:
	var c: Node2D = _fx_over
	var col: Color = LAVA_COLORS[kind]
	var af: float = _awake_factor()
	var hp_lost: float = _hp_lost()
	var off: Vector2 = _body_offset()
	var center: Vector2 = Vector2(0.0, -15.0 * _spr)
	var fi: int = _frame_index() if state != State.DEAD else 1

	# rastro da investida (cópias do sprite que vão sumindo)
	for tr in _trail:
		var ta: float = float(tr["life"]) / float(tr["max"])
		_draw_sprite(c, to_local(tr["p"]), float(tr["f"]), int(tr["fr"]), Color(col.r, col.g, col.b, 0.45 * ta))

	# halo de calor em volta do corpo
	var halo: float = 0.0
	match state:
		State.DORMANT:
			halo = 0.025 + 0.02 * sin(_t * 1.5)
		State.DEAD:
			halo = clampf(0.5 - _state_time * 0.7, 0.0, 0.5)
		State.WINDUP:
			halo = 0.25 + 0.2 * sin(_state_time * 30.0)
		State.CHARGE:
			halo = 0.3
		_:
			halo = af * (0.14 + 0.04 * sin(_t * 6.0) + 0.14 * hp_lost)
	if halo > 0.0:
		c.draw_circle(center, 25.0 * _spr, Color(col.r, col.g, col.b, halo * 0.16))
		c.draw_circle(center, 18.0 * _spr, Color(col.r, col.g, col.b, halo * 0.30))
		c.draw_circle(center, 12.0 * _spr, Color(col.r, col.g, col.b, halo * 0.55))

	# despertar: a lava sobe pela pedra, de baixo para cima, com uma linha brilhante na frente
	if state == State.WAKING:
		var rows: int = int(roundf(_smooth(_state_time / 1.4) * float(FRAME)))
		_draw_sprite(c, off, _face, fi, Color(col.r, col.g, col.b, 0.6), FRAME - rows, rows)
		if rows > 0 and rows < FRAME:
			_draw_sprite(c, off, _face, fi, Color(1.0, 0.9, 0.7, 0.9), FRAME - rows, 1)

	# brilho de calor sobre o sprite (pulsa; fica mais forte com a vida baixa e nos ataques)
	if state != State.DORMANT and state != State.DEAD and state != State.WAKING:
		var sh: float = af * (0.08 + 0.05 * sin(_t * 5.0) + 0.14 * hp_lost)
		if state == State.WINDUP:
			sh += 0.30 * (0.5 + 0.5 * sin(_state_time * 30.0))
		elif state == State.CHARGE:
			sh += 0.25
		_draw_sprite(c, off, _face, fi, Color(col.r, col.g, col.b, sh))

	# clarão branco quando leva dano
	if _flash > 0.0 and state != State.DEAD:
		_draw_sprite(c, off, _face, fi, Color(1.0, 1.0, 1.0, _flash * 0.6))

	# partículas de energia sendo sugadas para o corpo antes do ataque
	if state == State.WINDUP:
		var wt: float = 0.7 if _attack_kind == "charge" else 0.6
		var prog: float = clampf(_state_time / wt, 0.0, 1.0)
		for i in 8:
			var ang: float = TAU * float(i) / 8.0 + _t * 2.5
			var rr: float = lerpf(46.0, 6.0, prog) * _k
			var p: Vector2 = center + Vector2(cos(ang), sin(ang) * 0.8) * rr
			c.draw_rect(Rect2(roundf(p.x) - 1.5, roundf(p.y) - 1.5, 3.0, 3.0), Color(1.0, 0.85, 0.65, 0.5 + 0.5 * prog))

	# brasas subindo
	for e in _embers:
		var ea: float = clampf(float(e["life"]) / float(e["max"]) * 1.5, 0.0, 1.0)
		var ep: Vector2 = e["p"]
		var es: float = float(e["s"])
		c.draw_rect(Rect2(roundf(ep.x), roundf(ep.y), es, es), Color(col.r, col.g, col.b, ea))
		c.draw_rect(Rect2(roundf(ep.x), roundf(ep.y), es * 0.5, es * 0.5), Color(1.0, 0.95, 0.8, ea * 0.9))


# ==============================================================================
# ESTILHAÇO (projétil do demônio) - sem física, só distância ao jogador
# ==============================================================================

class Shard extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 190.0
	var damage: int = 1
	var bounds: Rect2 = Rect2()
	var life: float = 4.0
	var color: Color = Color(1.0, 0.45, 0.15)
	var _age: float = 0.0
	var _trail: Array[Vector2] = []

	func _process(delta: float) -> void:
		global_position += dir * speed * delta
		rotation += delta * 9.0
		life -= delta
		_age += delta
		_trail.push_front(global_position)
		if _trail.size() > 9:
			_trail.pop_back()
		var pl = Global.Player
		if is_instance_valid(pl) and not pl.is_dead and global_position.distance_to(pl.global_position) < 15.0:
			pl.update_health(damage)
			queue_free()
			return
		if life <= 0.0 or (bounds.size.x > 0.0 and not bounds.has_point(global_position)):
			queue_free()
			return
		queue_redraw()

	static var _tex: Texture2D
	static var _ltex: Texture2D

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _tex == null and ResourceLoader.exists("res://gaiola/sprites/shard.png"):
			_tex = load("res://gaiola/sprites/shard.png")
		if _ltex == null and ResourceLoader.exists("res://bullet/light2D-gradient.png"):
			_ltex = load("res://bullet/light2D-gradient.png")
		# luz própria: o estilhaço ilumina o chão por onde passa
		if _ltex != null:
			var l := PointLight2D.new()
			l.texture = _ltex
			l.color = color
			l.energy = 0.8
			l.texture_scale = 0.22
			add_child(l)

	func _draw() -> void:
		# rastro (em coordenadas do mundo: cancela a rotação do nó)
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		for i in range(1, _trail.size()):
			var a: float = 1.0 - float(i) / float(_trail.size())
			draw_circle(_trail[i] - global_position, 5.0 * a + 1.5, Color(color.r, color.g, color.b, 0.35 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# halo pulsante
		draw_circle(Vector2.ZERO, 14.0 + 2.0 * sin(_age * 20.0), Color(color.r, color.g, color.b, 0.14))
		draw_circle(Vector2.ZERO, 8.0, Color(color.r, color.g, color.b, 0.24))
		if _tex != null:
			draw_texture_rect(_tex, Rect2(-12.0, -12.0, 24.0, 24.0), false)
