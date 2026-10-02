class_name ControlsPanel
extends CenterContainer
## Controls reference. Shared by the main menu and the pause menu.

signal closed

const LINES := [
	"MOVE  -  W A S D / Left stick",
	"AIM  -  Mouse / Right stick",
	"SHOOT  -  Left mouse / Right trigger",
	"KNIFE  -  Space / Right stick click",
	"INTERACT  -  Q / Y button",
	"PAUSE  -  Esc / Start",
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(UIKit.make_label("CONTROLS", 64))
	for line in LINES:
		column.add_child(UIKit.make_label(line, 30))
	column.add_child(UIKit.make_button("BACK", _on_back))


func _on_back() -> void:
	closed.emit()
	queue_free()
