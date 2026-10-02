class_name UIKit
extends RefCounted
## Shared UI helpers used by menus and overlays.

const FONT_REGULAR: FontFile = preload("res://fonts/MountainsofChristmas-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const BUTTON_SCRIPT: Script = preload("res://ui/interactive_button.gd")


static func make_label(text: String, size: int = 32, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font = FONT_REGULAR
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	return label


static func make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.set_script(BUTTON_SCRIPT)
	button.text = text
	button.custom_minimum_size = Vector2(280, 52)
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 30)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(on_pressed)
	return button


static func make_dim_background(alpha: float = 0.7) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Decorative overlay must never block UI input.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Adds a full-screen CenterContainer to `parent` and returns the VBox inside it.
static func make_centered_column(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(column)
	return column
