
@tool
extends Node2D

@export var build_level_1: bool = false:
	set(val):
		if val:
			generate_level_1()
			build_level_1 = false

@export var build_level_2: bool = false:
	set(val):
		if val:
			generate_level_2()
			build_level_2 = false

@onready var terrain_layer: TileMapLayer = $TileMapTerrain

# Configuração de IDs de Terrenos/AutoTiles
const SOURCE_ID = 0
const TILE_STONE_SURFACE = Vector2i(1, 0)
const TILE_DIRT_FILL = Vector2i(1, 1)
const TILE_WOOD_PLATFORM = Vector2i(3, 0)
const TILE_CASTLE_WALL = Vector2i(0, 2)

func generate_level_1() -> void:
	if not terrain_layer:
		return
	terrain_layer.clear()
	
	# Gerar Chão Principal da Fase 1 (Cemitério)
	for x in range(0, 40):
		# Superfície
		terrain_layer.set_cell(Vector2i(x, 10), SOURCE_ID, TILE_STONE_SURFACE)
		# Preenchimento Subterrâneo
		for y in range(11, 14):
			terrain_layer.set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT_FILL)
			
	# Gerar Plataformas Elevadas
	for x in range(8, 13):
		terrain_layer.set_cell(Vector2i(x, 7), SOURCE_ID, TILE_STONE_SURFACE)
	for x in range(20, 25):
		terrain_layer.set_cell(Vector2i(x, 5), SOURCE_ID, TILE_STONE_SURFACE)
	
	print("✓ Layout da Fase 1 gerado com sucesso!")

func generate_level_2() -> void:
	if not terrain_layer:
		return
	terrain_layer.clear()
	
	# Gerar Chão da Fase 2 (Catacumbas / Vilarejo)
	for x in range(0, 50):
		if x in range(12, 16) or x in range(30, 34):
			continue # Buracos / Armadilhas (Hazards)
		terrain_layer.set_cell(Vector2i(x, 12), SOURCE_ID, TILE_CASTLE_WALL)
		terrain_layer.set_cell(Vector2i(x, 13), SOURCE_ID, TILE_CASTLE_WALL)
			
	# Gerar Pontes de Madeira do Vilarejo
	for x in range(11, 17):
		terrain_layer.set_cell(Vector2i(x, 9), SOURCE_ID, TILE_WOOD_PLATFORM)
	for x in range(28, 35):
		terrain_layer.set_cell(Vector2i(x, 7), SOURCE_ID, TILE_WOOD_PLATFORM)
		
	print("✓ Layout da Fase 2 gerado com sucesso!")
