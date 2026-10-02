extends CanvasLayer

@onready var animation = $animation
var scene_path: String = ""
var _busy := false


func _ready() -> void:
	# Keep fading while the tree is paused (game over / pause menu) and draw above the overlays.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	# The fade layer is visual only and must never block buttons underneath.
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$text.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fades out, switches to `path`, fades back in. Ignored while a transition is running.
func change_scene(path: String) -> void:
	scene_path = path
	fade_in()


func fade_in(opt: bool = false) -> void:
	if _busy:
		return
	_busy = true
	if opt:
		animation.play("passagem_fase")
		return
	animation.play("fade_in")


func _on_animation_animation_finished(anim_name: String) -> void:
	if anim_name == "fade_in" or anim_name == "passagem_fase":
		if scene_path.is_empty():
			push_error("TransitionScreen: scene_path is empty")
		else:
			get_tree().paused = false
			get_tree().change_scene_to_file(scene_path)
		animation.play("fade_out")
	elif anim_name == "fade_out":
		_busy = false
