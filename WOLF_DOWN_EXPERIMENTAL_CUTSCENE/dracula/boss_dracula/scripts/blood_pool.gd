extends Node2D
## Poça de sangue: círculo de aviso, depois explode e causa dano a quem estiver dentro.

@export var radius: float = 40.0
@export var warn_time: float = 1.0
@export var damage: int = 1

const BURST_SFX := "res://audio/dracula/drac_pool_burst.wav"

var _t := 0.0
var _burst := false

func _ready() -> void:
	z_index = -1   # desenha no chão, abaixo dos personagens

func _process(delta: float) -> void:
	_t += delta
	if not _burst and _t >= warn_time:
		_burst = true
		_t = 0.0
		_do_burst()
	elif _burst and _t >= 0.5:
		queue_free()
	queue_redraw()

func _do_burst() -> void:
	_play_burst_sound()
	var p := BossUtils.get_player(get_tree())
	if p and p.global_position.distance_to(global_position) <= radius:
		BossUtils.damage_player(p, damage)
	BossUtils.shake(self, 4.0, 0.2)

## Som da explosão. Fica no nó pai para não ser cortado quando a poça some (queue_free).
func _play_burst_sound() -> void:
	if not ResourceLoader.exists(BURST_SFX) or get_parent() == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = load(BURST_SFX)
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	p.play()

func _draw() -> void:
	var dark := Color(0.44, 0.03, 0.13)
	var mid := Color(0.78, 0.09, 0.2)
	var hi := Color(1.0, 0.38, 0.43)
	if not _burst:
		var k := clampf(_t / warn_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(dark, 0.25 + 0.2 * k))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(mid, 0.9), 2.0)
		draw_circle(Vector2.ZERO, radius * k, Color(mid, 0.35))
		for i in 8:
			var a := TAU * i / 8.0 + _t * 3.0
			draw_rect(Rect2(Vector2.from_angle(a) * radius * 0.6 - Vector2(2, 2), Vector2(4, 4)), hi)
	else:
		var f := 1.0 - clampf(_t / 0.5, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(mid, 0.8 * f))
		draw_circle(Vector2.ZERO, radius * 0.6, Color(hi, 0.8 * f))
		for i in 10:
			var a := TAU * i / 10.0
			var r := radius * (1.0 + (1.0 - f) * 0.4)
			draw_rect(Rect2(Vector2.from_angle(a) * r - Vector2(3, 3), Vector2(6, 6)), Color(dark, f))
