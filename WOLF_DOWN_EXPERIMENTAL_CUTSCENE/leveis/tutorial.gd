extends Node2D
@onready var canvas_layer = $CanvasLayer
@onready var botao = $cruz/Button
@onready var movimenta__o = $"CanvasLayer/ColorRect/movimentação"
@onready var objetivo = $CanvasLayer/ColorRect/objetivo
@onready var next = $CanvasLayer/ColorRect/Next
@export var current_scene: String
@export var next_scene: String

# Called when the node enters the scene tree for the first time.
func _ready():
	GameManager.register_level(scene_file_path)
	ObjectiveManager.set_objective("Learn the controls")
	objetivo.visible = false
	canvas_layer.visible = false
	botao.visible = false
	next.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if Input.is_action_just_pressed("interagir"):
		_on_button_pressed()



func _on_cruz_body_entered(body):
	botao.visible = true
	pass # Replace with function body.


func _on_button_pressed():
	
	canvas_layer.visible = true
	pass # Replace with function body.


func _on_butão_pressed():
	objetivo.visible = true
	movimenta__o.visible = false
	botao.visible = false
	next.visible = true
	pass # Replace with function body.


func _on_cruz_body_exited(body):
	botao.visible = false
	pass # Replace with function body.


func _on_next_pressed():
	ObjectiveManager.complete_objective()
	GameManager.next_level()
	
	pass # Replace with function body.
