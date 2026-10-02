extends CanvasLayer
## Pause overlay. Pauses the whole tree; this node keeps running (process_mode ALWAYS).

var _menu_root: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	add_child(UIKit.make_dim_background())
	var column := UIKit.make_centered_column(self)
	_menu_root = column.get_parent()
	column.add_child(UIKit.make_label("PAUSED", 72))
	column.add_child(UIKit.make_button("RESUME", _resume))
	column.add_child(UIKit.make_button("RESTART LEVEL", _restart))
	column.add_child(UIKit.make_button("CONTROLS", _show_controls))
	column.add_child(UIKit.make_button("MAIN MENU", _main_menu))


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
	panel.closed.connect(func(): _menu_root.visible = true)
