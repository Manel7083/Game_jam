class_name InteractiveButton
extends Button
## Shared button behavior for every interactive UI button in Wolf Down.
##
## This intentionally keeps the implementation simple: Godot's native Button
## handles mouse/keyboard/gamepad activation while this script makes sure the
## control is always in the input path, including paused overlays.
##
## Também toca os sons de interface: hover (mouse), foco (teclado/controle) e clique.
## Os sons ficam em UISounds (res://ui/ui_sounds.gd).

# Ignora o som de foco logo após o botão aparecer (menus chamam grab_focus ao abrir).
const FOCUS_SOUND_DELAY_MSEC := 250

var _ready_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Prevent accidental clipping/input issues when a container recalculates size.
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size.x = 280.0
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 52.0

	_ready_msec = Time.get_ticks_msec()
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	# button_down vem antes de pressed, então o som sai antes de o botão ser destruído.
	button_down.connect(_on_button_down)


func _on_mouse_entered() -> void:
	if disabled or not is_visible_in_tree():
		return
	UISounds.play_hover(get_tree())


func _on_focus_entered() -> void:
	if disabled or not is_visible_in_tree():
		return
	if Time.get_ticks_msec() - _ready_msec < FOCUS_SOUND_DELAY_MSEC:
		return
	UISounds.play_hover(get_tree())


func _on_button_down() -> void:
	UISounds.play_click(get_tree())
