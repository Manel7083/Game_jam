extends CanvasLayer
## HUD. Driven entirely by GameManager / ObjectiveManager signals - no values are hard-coded.
## v2: vida, munição e dash agora são desenhados pelo PlayerHUD (player_hud.gd), no estilo da cinemática.
## Os nós antigos (HP / barra_munição) continuam na cena, só ficam escondidos.

const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const OUTLINE_COL := Color(0.08, 0.0, 0.10)
const WEAPON_HUD := preload("res://leveis/weapon_hud.gd")
## Nomes de propriedade do jogador que a HUD tenta ler para saber a arma atual
## (só é usado se o GameManager NÃO tiver o sinal `weapon_changed`).
const WEAPON_PROPS := ["current_weapon", "weapon", "arma_atual", "arma", "selected_weapon", "weapon_index", "current_gun"]

@onready var hp: Label = $HP
@onready var ammo_bar: TextureProgressBar = $"barra_munição/barra_municao"

var _player_hud: PlayerHUD
var _score_label: Label
var _objective_box: VBoxContainer
var _banner: Label
var _reward_label: Label
var _weapon_hud: Control
var _weapon_signal_ok: bool = false


func _ready() -> void:
	# Esconde a HUD antiga e cria a nova
	hp.visible = false
	$"barra_munição".visible = false
	_player_hud = PlayerHUD.new()
	add_child(_player_hud)
	_weapon_hud = WEAPON_HUD.new()
	add_child(_weapon_hud)

	_weapon_hud.set_unlocked(&"lendario", bool(GameManager.get_meta("has_revolver", false)))
	_build_extra_ui()
	GameManager.player_health_changed.connect(update_health)
	GameManager.ammo_changed.connect(update_ammo)
	GameManager.score_changed.connect(update_score)
	GameManager.score_life_reward.connect(_on_score_life_reward)
	if GameManager.has_signal("weapon_changed"):
		GameManager.weapon_changed.connect(set_weapon)
		_weapon_signal_ok = true
	ObjectiveManager.objective_changed.connect(_refresh_objective)
	ObjectiveManager.objective_completed.connect(_on_objective_completed)
	update_health(GameManager.player_hp, GameManager.player_max_hp)
	update_score(GameManager.score)
	_update_reward_progress()
	_refresh_objective(ObjectiveManager.title, ObjectiveManager.items, ObjectiveManager.done)


func _process(_delta: float) -> void:
	if not is_instance_valid(Global.Player):
		return
	var player: Object = Global.Player
	# .38 lendário: o slot só aparece depois que o jogador libera o revólver
	var has_rev: Variant = player.get("has_revolver")
	if has_rev != null:
		_weapon_hud.set_unlocked(&"lendario", bool(has_rev))
		# Arma na mão: revólver equipado = lendário ligado / antigo desligado (e vice-versa)
		var rev_eq: Variant = player.get("revolver_equipped")
		if rev_eq != null and not _weapon_signal_ok:
			set_weapon(1 if (bool(has_rev) and bool(rev_eq)) else 0)
			return
	if _weapon_signal_ok:
		return
	for prop in WEAPON_PROPS:
		var value: Variant = player.get(prop)
		if value != null:
			set_weapon(value)
			return


## Atualiza o destaque da arma. Aceita índice (0 = antigo, 1 = lendário)
## ou texto/nome (qualquer coisa com "lend"/"legend" vira lendário).
func set_weapon(weapon: Variant) -> void:
	_weapon_hud.select_weapon(_weapon_id(weapon))


func _weapon_id(weapon: Variant) -> StringName:
	if weapon is int:
		return &"lendario" if weapon == 1 else &"antigo"
	var text := str(weapon).to_lower()
	return &"lendario" if ("lend" in text or "legend" in text) else &"antigo"


# Mantidos por compatibilidade com os sinais (a nova HUD lê direto do jogador).
func update_health(value: int, max_value: int = 0) -> void:
	var max_hp := max_value if max_value > 0 else GameManager.player_max_hp
	hp.text = "HP: %d/%d" % [value, max_hp]


func update_ammo(value: float, max_value: float = 100.0) -> void:
	ammo_bar.max_value = max_value
	ammo_bar.value = value


func update_score(value: int) -> void:
	_score_label.text = "SCORE  %d" % value
	_update_reward_progress()


func _update_reward_progress() -> void:
	if not is_instance_valid(_reward_label):
		return
	var progress := GameManager.get_score_reward_progress()
	if progress["complete"]:
		_reward_label.text = "MAX HP"
		_reward_label.modulate = Color(0.55, 1.0, 0.65)
	else:
		reward_label_text(progress)


func reward_label_text(progress: Dictionary) -> void:
	_reward_label.text = "HP +1  %d/%d" % [progress["current"], progress["required"]]
	_reward_label.modulate = Color(0.95, 0.85, 0.35)


func _on_score_life_reward(new_max_hp: int, healed_hp: int) -> void:
	show_banner("MAX HP +1   %d/%d" % [healed_hp, new_max_hp])
	_update_reward_progress()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Aplica a fonte da cinemática (Mountains of Christmas Bold) com contorno escuro.
func _style(label: Label, outline: int = 8) -> Label:
	if label.label_settings != null:
		var ls := label.label_settings.duplicate() as LabelSettings
		ls.font = FONT_BOLD
		ls.outline_size = outline
		ls.outline_color = OUTLINE_COL
		ls.shadow_color = Color(0, 0, 0, 0.8)
		ls.shadow_offset = Vector2(2, 2)
		label.label_settings = ls
	else:
		label.add_theme_font_override("font", FONT_BOLD)
		label.add_theme_color_override("font_outline_color", OUTLINE_COL)
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _build_extra_ui() -> void:
	_score_label = _style(UIKit.make_label("SCORE  0", 32, Color(1.0, 0.82, 0.45)))
	add_child(_score_label)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_objective_box = VBoxContainer.new()
	add_child(_objective_box)
	_objective_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	_banner = _style(UIKit.make_label("", 56, Color(1.0, 0.24, 0.18)), 14)
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 120)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.modulate.a = 0.0

	_reward_label = _style(UIKit.make_label("HP +1  0/5000", 22, Color(0.95, 0.85, 0.35)), 6)
	add_child(_reward_label)
	_reward_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_reward_label.position.y = 62
	_reward_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _refresh_objective(title: String, items: Array, done: Array) -> void:
	for child in _objective_box.get_children():
		child.queue_free()
	if title.is_empty():
		return
	var header := _style(UIKit.make_label("OBJECTIVE", 24, Color(0.72, 0.66, 0.82)), 6)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_box.add_child(header)
	var title_label := _style(UIKit.make_label(title, 32, Color(0.90, 0.72, 1.0)))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_box.add_child(title_label)
	for i in items.size():
		var mark := "[x] " if done[i] else "[ ] "
		var color := Color(0.5, 1.0, 0.5) if done[i] else Color(0.95, 0.93, 0.98)
		var line := _style(UIKit.make_label(mark + str(items[i]), 26, color), 6)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_objective_box.add_child(line)


func _on_objective_completed() -> void:
	show_banner("OBJECTIVE COMPLETE")
	if is_instance_valid(Global.Player):
		ParticleFX.objective_complete(get_tree().current_scene, Global.Player.global_position)
