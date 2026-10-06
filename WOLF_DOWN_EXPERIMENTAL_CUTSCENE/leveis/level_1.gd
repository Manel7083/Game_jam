extends "res://leveis/level_base.gd"
## Interim objective for the prototype levels (level_1 and level_2 share this script).
## Real objectives (symbols, keys, ...) arrive with the level-building milestone.
##
## Câmera: os limites vêm do tamanho REAL do mapa (borda externa das paredes do TileMap),
## então a câmera nunca mostra o vazio (void) fora do cenário, em qualquer resolução.

## Folga (px) para dentro da borda, para o coice/tremor da câmera (offset) não vazar para o void.
const CAMERA_LIMIT_MARGIN: int = 6

var _camera_limit_rect: Rect2 = Rect2()
var _camera_base_zoom: Vector2 = Vector2(2.6, 2.6)


func _ready() -> void:
	super._ready()
	_limit_camera()


func setup_objectives() -> void:
	ObjectiveManager.set_objective("Survive until dawn")


func _limit_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var map := get_node_or_null("terreno/grass") as TileMap
	if cam == null or map == null or map.tile_set == null:
		return
	var used: Rect2i = map.get_used_rect()   # todas as camadas (chão, caminho, parede, detalhes)
	if used.size == Vector2i.ZERO:
		return

	# Cantos externos do mapa em coordenadas globais (map_to_local devolve o CENTRO da célula).
	var half := Vector2(map.tile_set.tile_size) / 2.0
	var top_left: Vector2 = map.to_global(map.map_to_local(used.position) - half)
	var bottom_right: Vector2 = map.to_global(map.map_to_local(used.end - Vector2i.ONE) + half)
	_camera_limit_rect = Rect2(top_left, bottom_right - top_left)

	cam.limit_left = ceili(top_left.x) + CAMERA_LIMIT_MARGIN
	cam.limit_top = ceili(top_left.y) + CAMERA_LIMIT_MARGIN
	cam.limit_right = floori(bottom_right.x) - CAMERA_LIMIT_MARGIN
	cam.limit_bottom = floori(bottom_right.y) - CAMERA_LIMIT_MARGIN

	# Se a janela for tão grande que a área visível passe do mapa, aumenta o zoom o mínimo necessário.
	_camera_base_zoom = cam.zoom
	get_viewport().size_changed.connect(_fit_camera_zoom)
	_fit_camera_zoom()


func _fit_camera_zoom() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null or _camera_limit_rect.size.x <= 0.0 or _camera_limit_rect.size.y <= 0.0:
		return
	var usable := _camera_limit_rect.size - Vector2(CAMERA_LIMIT_MARGIN * 2, CAMERA_LIMIT_MARGIN * 2)
	var view := get_viewport().get_visible_rect().size
	var min_zoom := maxf(view.x / usable.x, view.y / usable.y)
	var z := maxf(_camera_base_zoom.x, min_zoom)
	cam.zoom = Vector2(z, z)
