extends CanvasLayer
## Pause overlay. Pauses the whole tree; this node keeps running (process_mode ALWAYS).
## Layout: menu à esquerda; ao fundo, o caçador andando sob a chuva (rain_scene.gd).

const RAIN_SCENE_PATH := "res://ui/rain_scene.gd"

var _menu_root: Control
var _scene: Control
var _resume_button: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	# Fundo da chuva é opcional: se o script não existir, o menu abre mesmo assim.
	if ResourceLoader.exists(RAIN_SCENE_PATH):
		_scene = (load(RAIN_SCENE_PATH) as Script).new()
	else:
		push_warning("pause_menu: %s não encontrado, abrindo sem o fundo." % RAIN_SCENE_PATH)
		_scene = Control.new()
		_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)

	# Menu centralizado na metade esquerda da tela (o caçador anda na direita)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 0.58
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_menu_root = center

	var buttons: Array[Button] = []
	center.add_child(_build_menu_card(buttons))

	_animate_in(center, buttons)
	_resume_button.call_deferred("grab_focus")


func _build_menu_card(buttons: Array[Button]) -> Control:
	var card := UIKit.make_panel(36)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	col.add_child(UIKit.make_title("PAUSED", 68))
	col.add_child(UIKit.make_divider(320.0))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	_resume_button = UIKit.make_button("RESUME", _resume)
	buttons.append(_resume_button)
	buttons.append(UIKit.make_button("RESTART LEVEL", _restart))
	buttons.append(UIKit.make_button("CONTROLS", _show_controls))
	buttons.append(UIKit.make_button("MAIN MENU", _main_menu))
	for b in buttons:
		col.add_child(b)

	col.add_child(UIKit.make_label("ESC  -  RESUME", 20, UIKit.TEXT_DIM))
	return card


func _animate_in(center: Control, buttons: Array[Button]) -> void:
	_scene.modulate.a = 0.0
	center.modulate.a = 0.0
	center.offset_top = 28.0
	for b in buttons:
		b.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scene, "modulate:a", 1.0, 0.30)
	tw.tween_property(center, "modulate:a", 1.0, 0.22)
	tw.tween_property(center, "offset_top", 0.0, 0.28)
	for i in buttons.size():
		tw.tween_property(buttons[i], "modulate:a", 1.0, 0.18).set_delay(0.08 + 0.06 * float(i))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _menu_root.visible:
		_resume()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	get_tree().paused = false
	GameManager.close_overlay()


func _restart() -> void:
	GameManager.restart_level()


func _main_menu() -> void:
	GameManager.return_to_menu()


func _show_controls() -> void:
	_menu_root.visible = false
	var panel := ControlsPanel.new()
	add_child(panel)
	panel.closed.connect(_on_controls_closed)


func _on_controls_closed() -> void:
	_menu_root.visible = true
	_resume_button.grab_focus()
