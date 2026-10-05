extends Node2D

## Wolf Down - Fase "A Gaiola dos Guardiões".
## Câmara de pedra (arte em pixel art em gaiola/sprites/). Três estátuas de demônio guardam uma gaiola com
## um revólver .38. Os guardiões acordam UM DE CADA VEZ; cada derrota quebra um cadeado da gaiola.
## Com todos os cadeados quebrados a gaiola abre e o jogador pega o .38.
##
## Cena: leveis/level_gaiola.tscn (arena, paredes, luzes, gaiola, HUD e lobo já estão na cena).
## Os guardiões, os cadeados e a sequência da fase são criados aqui.

const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const SPR := "res://gaiola/sprites/"

const ARENA_SIZE := Vector2(896.0, 640.0)               # tamanho da imagem arena_gaiola.png
const FLOOR_RECT := Rect2(32.0, 72.0, 832.0, 536.0)     # parte jogável do piso
const PICKUP_RADIUS := 34.0
## Onde cada estátua fica (plintos desenhados na arena).
const PLINTHS: Array[Vector2] = [Vector2(208.0, 262.0), Vector2(448.0, 330.0), Vector2(688.0, 262.0)]

## Tipos de guardião, na ordem em que acordam: 0 = Bruto, 1 = Arremessador, 2 = Rei Gárgula.
## Para 2 demônios use [0, 2]. Para 3 use [0, 1, 2].
@export var demon_kinds: Array[int] = [0, 1, 2]
## Índice da próxima fase no GameManager. -1 = mostra a tela de fase concluída.
@export var next_level_index: int = -1
## Cura 1 de vida e recarrega a munição da pistola a cada guardião derrotado.
@export var reward_between_fights: bool = true

@onready var player: Node2D = $wolf
@onready var _cage: Node2D = $Cage
@onready var _bars: Sprite2D = $Cage/Bars
@onready var _revolver: Sprite2D = $Cage/Revolver
@onready var _cage_light: PointLight2D = $Cage/CageLight
@onready var _rune_light: PointLight2D = $lights/rune_light

var _statues: Array[StoneDemon] = []
var _locks: Array[Sprite2D] = []
var _locks_broken: int = 0
var _pickup_ready: bool = false
var _picked: bool = false
var _t: float = 0.0
var _overlay: Overlay
var _msg_tween: Tween
var _current: StoneDemon
var _rev_rest_y: float = 0.0


# ==============================================================================
# SETUP
# ==============================================================================

func _ready() -> void:
	# Mesmo contrato das outras fases: registra no GameManager (pausa, game over, reiniciar fase) e na transição.
	GameManager.register_level(scene_file_path)
	TransitionScreen.scene_path = scene_file_path
	ObjectiveManager.set_objective("Derrote os guardiões e abra a gaiola")
	y_sort_enabled = true

	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_overlay = Overlay.new()
	_overlay.locks_total = demon_kinds.size()
	if ResourceLoader.exists(SPR + "lock.png"):
		_overlay.lock_tex = load(SPR + "lock.png")
	ui.add_child(_overlay)

	_limit_camera()
	_build_locks()
	_build_statues()
	_rev_rest_y = _revolver.position.y
	_run()


func _limit_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ARENA_SIZE.x)
	cam.limit_bottom = int(ARENA_SIZE.y)


func _build_locks() -> void:
	var n: int = demon_kinds.size()
	var tex: Texture2D = load(SPR + "lock.png") if ResourceLoader.exists(SPR + "lock.png") else null
	for i in n:
		var t: float = 0.5 if n == 1 else float(i) / float(n - 1)
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(roundf(lerpf(-18.0, 18.0, t)), 22.0)
		s.z_index = 1
		_cage.add_child(s)
		_locks.append(s)


func _plinth_for(i: int, n: int) -> Vector2:
	if n == 1:
		return PLINTHS[1]
	if n == 2:
		return PLINTHS[0] if i == 0 else PLINTHS[2]
	if n == 3:
		return PLINTHS[i]
	var t: float = float(i) / float(n - 1)
	return Vector2(lerpf(PLINTHS[0].x, PLINTHS[2].x, t), PLINTHS[0].y + (68.0 if i % 2 == 1 else 0.0))


func _build_statues() -> void:
	var n: int = demon_kinds.size()
	for i in n:
		var d := StoneDemon.new()
		d.kind = demon_kinds[i]
		d.bounds = FLOOR_RECT.grow(8.0)
		d.position = _plinth_for(i, n)
		d.z_index = 1
		add_child(d)
		_statues.append(d)


# ==============================================================================
# SEQUÊNCIA DA FASE
# ==============================================================================

func _wait(sec: float) -> void:
	# false = o timer respeita a pausa do jogo (a sequência não anda com o menu de pausa aberto)
	await get_tree().create_timer(sec, false).timeout


func _say(text: String, dur: float = 2.2) -> void:
	_overlay.msg = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_overlay, "msg_a", 1.0, 0.3)
	_msg_tween.tween_interval(dur)
	_msg_tween.tween_property(_overlay, "msg_a", 0.0, 0.5)


func _run() -> void:
	await _wait(1.2)
	_say("A GAIOLA DOS GUARDIÕES", 2.6)
	await _wait(3.4)
	_say("Derrote os guardiões, um de cada vez.", 2.4)
	await _wait(2.6)

	for i in _statues.size():
		var d: StoneDemon = _statues[i]
		_current = d
		_overlay.boss_name = "%s   %d/%d" % [d.display_name, i + 1, _statues.size()]
		_overlay.boss_ratio = 1.0
		_overlay.boss_ghost = 1.0
		_overlay.boss_on = true
		_overlay.flash = 0.6
		d.awaken()
		await d.died
		_overlay.boss_on = false
		_overlay.flash = 0.5
		_break_lock(i)
		if reward_between_fights:
			_give_reward()
		if i < _statues.size() - 1:
			_say("GUARDIÃO %d DERROTADO" % (i + 1), 2.0)
			await _wait(3.2)

	_say("O CADEADO FINAL SE PARTE...", 2.0)
	await _wait(1.8)
	_open_cage()
	await _wait(1.8)
	_pickup_ready = true
	_overlay.flash = 0.7
	_say("O REVÓLVER .38 ESTÁ LIVRE!", 3.0)


func _break_lock(i: int) -> void:
	_locks_broken = i + 1
	_overlay.locks_broken = _locks_broken
	if i < _locks.size() and is_instance_valid(_locks[i]):
		ParticleFX.enemy_death(self, _locks[i].global_position)
		_locks[i].hide()


func _open_cage() -> void:
	ParticleFX.objective_complete(self, _cage.global_position)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bars, "position:y", -44.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_bars, "modulate:a", 0.0, 1.4)
	tw.tween_property(_revolver, "position:y", 58.0, 1.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cage_light, "energy", 1.8, 1.4)
	_rev_rest_y = 58.0


func _give_reward() -> void:
	var pl = Global.Player
	if not is_instance_valid(pl) or pl.is_dead:
		return
	pl.heal(1)
	pl.ammo = pl.max_ammo
	GameManager.set_ammo(pl.ammo, pl.max_ammo)


func _collect() -> void:
	_picked = true
	var pl = Global.Player
	if is_instance_valid(pl):
		pl.equip_revolver()
	ParticleFX.pickup(self, _revolver.global_position)
	_revolver.hide()
	_cage_light.energy = 0.0
	_overlay.flash = 1.0
	_say("REVÓLVER .38 OBTIDO", 3.0)
	await _wait(1.8)
	_say("TAB troca de arma  -  R recarrega", 3.0)
	await _wait(4.0)
	if next_level_index >= 0:
		GameManager.load_level(next_level_index)
	else:
		ObjectiveManager.complete_objective()
		GameManager.complete_level()


# ==============================================================================
# LOOP
# ==============================================================================

func _process(delta: float) -> void:
	if _overlay == null:
		return
	_t += delta

	# barra do guardião ativo
	if is_instance_valid(_current) and _overlay.boss_on:
		_overlay.boss_ratio = clampf(float(_current.health) / float(_current.max_health), 0.0, 1.0)
	_overlay.flash = maxf(_overlay.flash - delta * 2.0, 0.0)

	# luzes pulsando (círculo rúnico fica mais forte a cada cadeado quebrado) e revólver flutuando
	var prog: float = float(_locks_broken) / float(maxi(demon_kinds.size(), 1))
	_rune_light.energy = 0.55 + 0.25 * sin(_t * 1.6) + 0.7 * prog
	if _pickup_ready and not _picked:
		_revolver.position.y = _rev_rest_y + roundf(sin(_t * 2.2) * 2.0)

	# pegar o revólver
	if _pickup_ready and not _picked:
		var pl = Global.Player
		if is_instance_valid(pl) and not pl.is_dead and pl.global_position.distance_to(_revolver.global_position) < PICKUP_RADIUS:
			_collect()


# ==============================================================================
# OVERLAY (barra do guardião, cadeados, mensagens)
# ==============================================================================

class Overlay extends Control:
	const FONT: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
	var msg: String = ""
	var msg_a: float = 0.0
	var flash: float = 0.0
	var boss_name: String = ""
	var boss_ratio: float = 1.0
	var boss_ghost: float = 1.0
	var boss_on: bool = false
	var locks_total: int = 3
	var locks_broken: int = 0
	var lock_tex: Texture2D

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		if boss_ghost > boss_ratio:
			boss_ghost = move_toward(boss_ghost, boss_ratio, delta * 0.6)
		else:
			boss_ghost = boss_ratio
		queue_redraw()

	func _txt(pos: Vector2, text: String, fsize: int, col: Color, w: float) -> void:
		draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, 8, Color(0.09, 0.03, 0.08, col.a))
		draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, col)

	func _draw() -> void:
		var s: float = size.y / 720.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var vw: float = size.x / s

		if flash > 0.0:
			draw_rect(Rect2(-10.0, -10.0, vw + 20.0, 740.0), Color(1.0, 0.9, 0.9, 0.3 * flash))

		# barra do guardião: parte de baixo da tela, mesmo visual da barra do Drácula
		if boss_on:
			var bw: float = 560.0
			var bh: float = 20.0
			var x: float = (vw - bw) * 0.5
			var y: float = 720.0 - 70.0
			_txt(Vector2(0.0, y - 10.0), boss_name, 28, Color(0.95, 0.8, 0.85), vw)
			draw_rect(Rect2(x - 3.0, y - 3.0, bw + 6.0, bh + 6.0), Color(0.09, 0.03, 0.08))
			draw_rect(Rect2(x, y, bw, bh), Color(0.2, 0.05, 0.12))
			if boss_ghost > boss_ratio:
				draw_rect(Rect2(x, y, bw * boss_ghost, bh), Color(0.95, 0.85, 0.85))
			draw_rect(Rect2(x, y, bw * boss_ratio, bh), Color(0.78, 0.09, 0.2))

		# cadeados (progresso)
		if lock_tex != null:
			var step: float = 40.0
			var lx: float = (vw - float(locks_total) * step) * 0.5 + step * 0.5
			for i in locks_total:
				var done: bool = i < locks_broken
				var col := Color(1, 1, 1, 0.25) if done else Color.WHITE
				draw_texture_rect(lock_tex, Rect2(lx + float(i) * step - 12.0, 36.0, 24.0, 28.0), false, col)

		# mensagem
		if msg_a > 0.0:
			_txt(Vector2(0.0, 210.0), msg, 54, Color(1.0, 0.24, 0.18, msg_a), vw)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
