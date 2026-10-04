extends Node2D
## EXEMPLO: coloque este script em um Node2D da fase do Dracula para spawnar o boss.
## Ajuste spawn_point e arena_rect para o tamanho da sua sala.

@export var spawn_point: Vector2 = Vector2(600, 200)
@export var arena_rect: Rect2 = Rect2(100, 100, 1000, 600)

func _ready() -> void:
	var boss: DraculaBoss = preload("res://boss_dracula/scenes/dracula_boss.tscn").instantiate()
	boss.arena_rect = arena_rect
	boss.global_position = spawn_point
	add_child(boss)

	var bar = preload("res://boss_dracula/scenes/boss_health_bar.tscn").instantiate()
	add_child(bar)
	bar.bind_boss(boss)

	boss.phase_changed.connect(func(p): print("Dracula entrou na fase ", p))
	boss.defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	print("Dracula derrotado! Chame aqui a tela de vitória / créditos.")
	# GameManager.show_victory()
