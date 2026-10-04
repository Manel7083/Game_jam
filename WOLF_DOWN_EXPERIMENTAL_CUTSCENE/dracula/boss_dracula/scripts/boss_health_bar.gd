extends CanvasLayer
## Barra de vida do boss (parte inferior da tela). Chame bind_boss(boss) depois de instanciar.

const BAR_W := 420.0
const BAR_H := 16.0

var _boss: Node
var _fill: ColorRect
var _lag: ColorRect
var _label: Label
var _root: Control

func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.position = Vector2(-BAR_W * 0.5, -60)
	holder.size = Vector2(BAR_W, BAR_H)
	_root.add_child(holder)

	var border := ColorRect.new()
	border.color = Color(0.09, 0.03, 0.08)
	border.position = Vector2(-3, -3)
	border.size = Vector2(BAR_W + 6, BAR_H + 6)
	holder.add_child(border)

	var back := ColorRect.new()
	back.color = Color(0.2, 0.05, 0.12)
	back.size = Vector2(BAR_W, BAR_H)
	holder.add_child(back)

	_lag = ColorRect.new()
	_lag.color = Color(0.95, 0.85, 0.85)
	_lag.size = Vector2(BAR_W, BAR_H)
	holder.add_child(_lag)

	_fill = ColorRect.new()
	_fill.color = Color(0.78, 0.09, 0.2)
	_fill.size = Vector2(BAR_W, BAR_H)
	holder.add_child(_fill)

	# marcas de fase (66% e 33%)
	for r in [0.66, 0.33]:
		var m := ColorRect.new()
		m.color = Color(0.09, 0.03, 0.08)
		m.position = Vector2(BAR_W * r - 1, 0)
		m.size = Vector2(2, BAR_H)
		holder.add_child(m)

	var icon := TextureRect.new()
	icon.texture = load("res://boss_dracula/sprites/dracula_icon.png")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.size = Vector2(32, 32)
	icon.position = Vector2(-42, -9)
	holder.add_child(icon)

	_label = Label.new()
	_label.text = "DRÁCULA"
	_label.position = Vector2(0, -26)
	_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0.09, 0.03, 0.08))
	_label.add_theme_constant_override("outline_size", 4)
	holder.add_child(_label)

	_root.visible = false

func bind_boss(boss: Node) -> void:
	_boss = boss
	boss.health_changed.connect(_on_health_changed)
	boss.phase_changed.connect(_on_phase_changed)
	boss.defeated.connect(_on_defeated)
	_root.visible = true

func _on_health_changed(cur: int, maxi_: int) -> void:
	var w := BAR_W * float(cur) / float(maxi_)
	_fill.size.x = w
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(_lag, "size:x", w, 0.4)

func _on_phase_changed(p: int) -> void:
	_label.text = "DRÁCULA  -  FASE %d" % p
	var tw := create_tween()
	tw.tween_property(_fill, "color", Color(1, 0.6, 0.65), 0.1)
	tw.tween_property(_fill, "color", Color(0.78, 0.09, 0.2), 0.3)

func _on_defeated() -> void:
	_root.visible = false
	queue_free()
