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
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := UIKit.make_panel(36)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)

	column.add_child(UIKit.make_title("CONTROLS", 60))
	column.add_child(UIKit.make_divider(420.0))

	# Duas colunas: ação (dourado) e teclas (claro)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for line in LINES:
		var parts: PackedStringArray = (line as String).split("  -  ", false, 1)
		var action := UIKit.make_label(parts[0], 30, UIKit.GOLD)
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(action)
		var keys := UIKit.make_label(parts[1] if parts.size() > 1 else "", 28, UIKit.TEXT)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(keys)

	var back := UIKit.make_button("BACK", _on_back)
	column.add_child(back)
	back.call_deferred("grab_focus")


func _on_back() -> void:
	closed.emit()
	queue_free()
