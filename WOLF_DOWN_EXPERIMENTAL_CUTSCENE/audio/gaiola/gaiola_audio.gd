class_name GaiolaAudio
extends Node

## Wolf Down - Áudio da fase "A Gaiola dos Guardiões".
## Música (crossfade entre faixas) + sons ÚNICOS para cada guardião de pedra + sons da fase.
## Arquivos em res://audio/gaiola/  (music/*.ogg e sfx/*.ogg).
##
## - Instância (level_gaiola.gd cria com GaiolaAudio.new()): toca/troca a música com play_music().
## - Estático (qualquer script): GaiolaAudio.demon(self, kind, "wake", global_position)
##                               GaiolaAudio.sfx_ui(self, "lock_break")
## Se um arquivo não existir, simplesmente fica em silêncio (não quebra o jogo).

const AUDIO_DIR := "res://audio/gaiola/"
const KIND_NAMES: Array[String] = ["bruto", "arremessador", "rei"]

## Volume (dB) por evento do guardião e ajuste por tipo (0 = Bruto, 1 = Arremessador, 2 = Rei Gárgula).
const EVENT_DB := {
	"wake": 0.0, "windup": -2.0, "windup_volley": -2.0, "charge": 0.0, "slam": 1.0, "shoot": -2.0,
	"ring": 2.0, "hurt": -4.0, "die": 3.0, "revive": 1.0, "step": -9.0,
}
const KIND_DB: Array[float] = [0.0, -1.0, 0.0]
## Variação aleatória de tom (só nos sons que se repetem muito).
const PITCH_VAR := {"hurt": 0.06, "step": 0.06, "shoot": 0.03, "slam": 0.03}

## Somado a todos os efeitos (o level preenche com sfx_volume_db).
static var sfx_offset_db: float = 0.0
static var _cache: Dictionary = {}
static var _warned: bool = false

# ---------------------------------------------------------------- música (instância)
var music_volume_db: float = -8.0
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer
var _track: String = ""
var _tween: Tween


func _ready() -> void:
	_a = _make_player()
	_b = _make_player()


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = _bus_name("Music")
	p.volume_db = -80.0
	add_child(p)
	return p


## Troca a música com crossfade. track: "ambiente", "desafio", "ressurreicao" ou "vitoria".
func play_music(track: String, fade: float = 1.5, loop: bool = true) -> void:
	if track == _track:
		return
	_track = track
	if _tween:
		_tween.kill()
	for p in [_a, _b]:
		if p != _cur and p.playing:
			p.stop()
	var outgoing: AudioStreamPlayer = _cur
	var st: AudioStream = _load("music/gaiola_%s.ogg" % track)
	_tween = create_tween().set_parallel(true)
	if outgoing != null and outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", -80.0, fade)
		_tween.tween_callback(outgoing.stop).set_delay(fade)
	if st == null:
		_cur = null
		return
	var incoming: AudioStreamPlayer = _b if _cur == _a else _a
	var s2: AudioStream = st.duplicate()
	if s2 is AudioStreamOggVorbis:
		(s2 as AudioStreamOggVorbis).loop = loop
	incoming.stream = s2
	incoming.volume_db = -80.0
	incoming.play()
	_tween.tween_property(incoming, "volume_db", music_volume_db, fade)
	_cur = incoming


func stop_music(fade: float = 1.5) -> void:
	_track = ""
	if _cur == null:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_cur, "volume_db", -80.0, fade)
	_tween.tween_callback(_cur.stop)
	_cur = null


# ---------------------------------------------------------------- sons (estáticos)
static func _bus_name(preferred: String) -> String:
	return preferred if AudioServer.get_bus_index(preferred) != -1 else "Master"


static func _load(rel: String) -> AudioStream:
	if _cache.has(rel):
		return _cache[rel]
	var path: String = AUDIO_DIR + rel
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif not _warned and not DirAccess.dir_exists_absolute(AUDIO_DIR):
		_warned = true
		push_warning("GaiolaAudio: pasta %s não encontrada - copie audio/gaiola/ para o projeto." % AUDIO_DIR)
	_cache[rel] = s
	return s


## Som posicional (pan e volume pela distância até a câmera). Fica na cena, então toca até o fim
## mesmo que o guardião suma (queue_free).
static func sfx_at(host: Node, sound: String, pos: Vector2, db: float = 0.0, pitch_var: float = 0.0) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var st: AudioStream = _load("sfx/%s.ogg" % sound)
	if st == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.bus = _bus_name("SFX")
	p.volume_db = db + sfx_offset_db
	p.max_distance = 1800.0
	p.attenuation = 1.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.finished.connect(p.queue_free)
	var parent: Node = host.get_parent()
	if parent == null:
		parent = host.get_tree().current_scene
	parent.add_child(p)
	p.global_position = pos
	p.play()


## Som sem posição (sons da fase: cadeado, gaiola, revólver...).
static func sfx_ui(host: Node, sound: String, db: float = 0.0) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var st: AudioStream = _load("sfx/%s.ogg" % sound)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = _bus_name("SFX")
	p.volume_db = db + sfx_offset_db
	p.finished.connect(p.queue_free)
	host.add_child(p)
	p.play()


## Som de um guardião. kind: 0 Bruto, 1 Arremessador, 2 Rei Gárgula.
## event: wake, windup, windup_volley, charge, slam, shoot, ring, hurt, die, revive, step.
static func demon(host: Node, kind: int, event: String, pos: Vector2) -> void:
	var k: int = clampi(kind, 0, 2)
	var file: String = "%s_%s" % [KIND_NAMES[k], event]
	if event == "hurt":
		file = "%s_hurt%d" % [KIND_NAMES[k], randi_range(1, 3)]
	elif event == "step":
		file = "%s_step%d" % [KIND_NAMES[k], randi_range(1, 2)]
	var db: float = float(EVENT_DB.get(event, 0.0)) + KIND_DB[k]
	sfx_at(host, file, pos, db, float(PITCH_VAR.get(event, 0.0)))
