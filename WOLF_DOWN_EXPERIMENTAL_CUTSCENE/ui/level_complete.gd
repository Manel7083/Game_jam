extends CanvasLayer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var stats := GameManager.get_level_stats()
	add_child(UIKit.make_dim_background(0.75))
	var column := UIKit.make_centered_column(self)
	column.add_child(UIKit.make_label("LEVEL COMPLETE", 80))
	column.add_child(UIKit.make_label("TIME  %s" % GameManager.format_time(stats["time"]), 32))
	column.add_child(UIKit.make_label("ENEMIES DEFEATED  %d" % stats["enemies"], 32))
	column.add_child(UIKit.make_label("DAMAGE TAKEN  %d" % stats["damage"], 32))
	column.add_child(UIKit.make_label("ACCURACY  %d%%" % int(stats["accuracy"]), 32))
	column.add_child(UIKit.make_label("SCORE  %d" % GameManager.score, 40, Color(1, 0.85, 0.3)))
	column.add_child(UIKit.make_button("CONTINUE", GameManager.next_level))
