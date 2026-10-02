extends CanvasLayer
## Countdown used as the "survive" objective of the prototype levels.
## On expiry it asks GameManager to complete the level (the manager owns what comes next).

@onready var temp = $temp
@onready var timer = $Timer
var tempo_restante = 120


func _ready():
	timer.wait_time = 1
	timer.start()
	atualizar_label()


func _on_timer_timeout():
	tempo_restante -= 1
	atualizar_label()

	if tempo_restante <= 0:
		timer.stop()
		ObjectiveManager.complete_objective()
		GameManager.complete_level()


func atualizar_label():
	var minutos = tempo_restante / 60
	var segundos = tempo_restante % 60

	temp.text = "%02d:%02d" % [minutos, segundos]
