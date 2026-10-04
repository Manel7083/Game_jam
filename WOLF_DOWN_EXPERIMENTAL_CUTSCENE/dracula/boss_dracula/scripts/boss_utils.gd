class_name BossUtils
extends RefCounted
## Funções utilitárias compartilhadas pelo boss, projéteis e lacaios.

## Causa dano ao jogador tentando os nomes de método mais comuns.
## Adapte aqui se o seu Player usa outro nome.
static func damage_player(target: Node, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(amount)
	elif target.has_method("damage"):
		target.damage(amount)
	elif target.has_method("hit"):
		target.hit(amount)
	elif target.has_method("hurt"):
		target.hurt(amount)


static func get_player(tree: SceneTree) -> Node2D:
	var list := tree.get_nodes_in_group("player")
	if list.size() > 0:
		return list[0] as Node2D
	return null


## Tremor de câmera simples (usa a Camera2D ativa, se existir).
static func shake(node: Node, strength: float = 6.0, duration: float = 0.3) -> void:
	var cam := node.get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var k := 1.0 - float(i) / float(steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


## Cria uma animação em SpriteFrames a partir de uma fita horizontal de frames quadrados.
static func add_strip(frames: SpriteFrames, anim: String, path: String, frame_size: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("Sprite não encontrado: " + path)
		return
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var count := int(tex.get_width() / frame_size)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_size, 0, frame_size, tex.get_height())
		frames.add_frame(anim, at)
