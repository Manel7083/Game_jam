class_name InteractiveButton
extends Button
## Shared button behavior for every interactive UI button in Wolf Down.
##
## This intentionally keeps the implementation simple: Godot's native Button
## handles mouse/keyboard/gamepad activation while this script makes sure the
## control is always in the input path, including paused overlays.

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
