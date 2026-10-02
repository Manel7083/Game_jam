extends CanvasLayer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	add_child(UIKit.make_dim_background(0.8))
	var column := UIKit.make_centered_column(self)
	column.add_child(UIKit.make_label("YOU DIED", 96, Color(0.8, 0.1, 0.1)))
	column.add_child(UIKit.make_button("RETRY LEVEL", GameManager.restart_level))
	column.add_child(UIKit.make_button("MAIN MENU", GameManager.return_to_menu))
