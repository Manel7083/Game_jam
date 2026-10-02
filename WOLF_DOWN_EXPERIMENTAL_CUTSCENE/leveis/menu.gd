extends Control

@onready var start_button: Button = $buttons_conteins/Button
@onready var controls_button: Button = $buttons_conteins/Button2
@onready var quit_button: Button = $buttons_conteins/Button3


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Explicit setup keeps the menu independent from editor signal state.
	_connect_once(start_button, _on_start_pressed)
	_connect_once(controls_button, _on_controls_pressed)
	_connect_once(quit_button, _on_quit_pressed)


func _connect_once(button: Button, callback: Callable) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.disabled = false
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_controls_pressed() -> void:
	var panel := ControlsPanel.new()
	add_child(panel)


func _on_quit_pressed() -> void:
	get_tree().quit()
