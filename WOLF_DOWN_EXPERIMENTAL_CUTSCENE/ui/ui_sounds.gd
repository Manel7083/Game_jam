class_name UISounds
extends RefCounted
## Sons de interface (hover / clique) do Wolf Down.
##
## Os players ficam na raiz da árvore (não no botão), então o som termina de tocar
## mesmo que o botão seja destruído logo após o clique (ex.: RETRY, MAIN MENU).
## Tudo roda em PROCESS_MODE_ALWAYS, então também funciona com o jogo pausado.

const HOVER_PATH := "res://audio/ui/ui_hover.wav"
const CLICK_PATH := "res://audio/ui/ui_click.wav"

## Ajuste aqui o volume de cada som (em dB).
const HOVER_VOLUME_DB := -12.0
const CLICK_VOLUME_DB := -5.0

const POOL_SIZE := 6

static var _streams: Dictionary = {}
static var _warned: Dictionary = {}
static var _players: Array[AudioStreamPlayer] = []
static var _next: int = 0


static func play_hover(tree: SceneTree) -> void:
	_play(tree, HOVER_PATH, HOVER_VOLUME_DB)


static func play_click(tree: SceneTree) -> void:
	_play(tree, CLICK_PATH, CLICK_VOLUME_DB)


static func _play(tree: SceneTree, path: String, volume_db: float) -> void:
	if tree == null:
		return
	var stream := _get_stream(path)
	if stream == null:
		return
	_ensure_players(tree)
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	# Deferido: garante que o player já entrou na árvore (e evita erro de "parent busy").
	(func() -> void:
		if is_instance_valid(player) and player.is_inside_tree():
			player.play()
	).call_deferred()


static func _get_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("UISounds: %s não encontrado." % path)
		return null
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		_streams[path] = loaded
		return loaded as AudioStream
	return null


static func _ensure_players(tree: SceneTree) -> void:
	if not _players.is_empty() and is_instance_valid(_players[0]):
		return
	_players.clear()
	_next = 0
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "UISoundPlayer%d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = bus
		tree.root.add_child.call_deferred(p)
		_players.append(p)
