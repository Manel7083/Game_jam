extends CanvasLayer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	add_child(UIKit.make_dim_background(0.82))
	var column := UIKit.make_centered_column(self)
	column.add_theme_constant_override("separation", 18)
	column.add_child(UIKit.make_title("YOU DIED", 110, UIKit.BLOOD))
	column.add_child(UIKit.make_divider(420.0))
	var retry := UIKit.make_button("RETRY LEVEL", GameManager.restart_level)
	column.add_child(retry)
	column.add_child(UIKit.make_button("MAIN MENU", GameManager.return_to_menu))
	retry.call_deferred("grab_focus")
