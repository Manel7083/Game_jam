# ============================================================================
# PATCH para opening_cinematic.gd  (OpeningCinematic)
# Copie a pasta audio_cinematica/ para res://audio/cinematica/
# ============================================================================

# ---- 1) Constantes e variaveis (junto das outras, no topo do script) --------
const AUDIO_DIR: String = "res://audio/cinematica/"
const THUNDER_PATH: String = "res://audio/cinematica/thunder.wav"
const SHOT_AUDIO: Array[String] = [
	"shot_00_prologo.wav",
	"shot_01_sepulturas.wav",
	"shot_02_vilarejo.wav",
	"shot_03_castelo.wav",
	"shot_04_cripta.wav",
	"shot_05_trono.wav",
	"shot_06_cacador.wav",
	"shot_07_olho_lobo.wav",
	"shot_08_controles.wav",
	"shot_09_final.wav"
]

var _shot_player: AudioStreamPlayer
var _prev_flash: float = 0.0
var _thunder_cd: float = 0.0


# ---- 2) _ready(): REMOVA a linha  _start_music()  (o audio agora vem de _reset_shot)

# ---- 3) _process(): logo depois de  _total += delta  adicione:
#         _update_thunder(delta)

# ---- 4) _reset_shot(): no FINAL da funcao (antes ou depois do queue_redraw) adicione:
#         _play_shot_audio()

# ---- 5) _finish(): troque o bloco do tween da musica por:
#	for p in [_shot_player, _music]:
#		if is_instance_valid(p):
#			create_tween().tween_property(p, "volume_db", -60.0, 0.6)


# ---- 6) Funcoes novas (cole em qualquer lugar do script) --------------------
func _play_shot_audio() -> void:
	if not play_music:
		return
	# some com o audio do plano anterior (caso o jogador tenha pulado)
	if is_instance_valid(_shot_player):
		var old: AudioStreamPlayer = _shot_player
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -50.0, 0.25)
		tw.tween_callback(old.queue_free)
	var path: String = AUDIO_DIR + SHOT_AUDIO[_shot]
	if not ResourceLoader.exists(path):
		return
	_shot_player = AudioStreamPlayer.new()
	_shot_player.stream = load(path)
	_shot_player.volume_db = -3.0
	add_child(_shot_player)
	_shot_player.play()


## Dispara o trovao no momento em que o relampago acende na tela.
func _update_thunder(delta: float) -> void:
	_thunder_cd = maxf(_thunder_cd - delta, 0.0)
	var f: float = _lightning_for_shot()
	if f > 0.3 and _prev_flash <= 0.3 and _thunder_cd <= 0.0:
		_play_thunder()
		_thunder_cd = 1.5
	_prev_flash = f


func _play_thunder() -> void:
	if not play_music or not ResourceLoader.exists(THUNDER_PATH):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(THUNDER_PATH)
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
