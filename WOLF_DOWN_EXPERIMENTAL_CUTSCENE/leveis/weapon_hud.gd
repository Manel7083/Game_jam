extends Control
## HUD de armas (canto inferior direito).
## - Cada arma tem um slot com ícone "ligado" (colorido, moldura acesa, brilho)
##   e "desligado" (escuro, sem brilho, menor).
## - A arma que o jogador está segurando fica LIGADA; as outras ficam DESLIGADAS.
## - O slot do .38 lendário fica escondido até o jogador desbloquear o revólver.
## API: select_weapon(id), set_unlocked(id, bool)   (ids: &"antigo", &"lendario"; a adaga é fixa e sempre ligada)

const DIR := "res://leveis/icones_armas/"
## A adaga o jogador já possui: o slot dela fica SEMPRE visível e SEMPRE ligado,
## independente da arma de fogo selecionada.
const ALWAYS_ON: Array[StringName] = [&"adaga"]

## Sons da troca de arma (o do lendário tem um "brilho" metálico extra).
const SFX_DIR := "res://leveis/sons/"
const SFX_ANTIGO := "weapon_swap_antigo.wav"
const SFX_LENDARIO := "weapon_swap_lendario.wav"
const SFX_VOLUME_DB := -6.0
## Ignora o som logo ao carregar a fase (sincronização inicial da HUD).
const SFX_MUTE_MS := 600

const SLOT_SIZE := 76.0
const OFF_SCALE := 0.86

const WEAPONS := {
	&"adaga": {"on": "adaga.png", "off": "adaga_off.png", "glow": Color(0.75, 0.85, 1.0), "unlocked": true},
	&"antigo": {"on": "revolver_antigo.png", "off": "revolver_antigo_off.png", "glow": Color(1.0, 0.72, 0.40), "unlocked": true},
	&"lendario": {"on": "revolver_lendario.png", "off": "revolver_lendario_off.png", "glow": Color(1.0, 0.35, 0.78), "unlocked": false},
}

var _slots: Dictionary = {}
var _selected: StringName = &""
var _row: HBoxContainer
var _sfx: AudioStreamPlayer
var _born_ms: int = 0


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = SFX_VOLUME_DB
	add_child(_sfx)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN

	for id in [&"adaga", &"antigo", &"lendario"]:
		_build_slot(id)
	select_weapon(&"antigo", true)


func _build_slot(id: StringName) -> void:
	var data: Dictionary = WEAPONS[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.pivot_offset = Vector2(SLOT_SIZE, SLOT_SIZE) * 0.5
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	_row.add_child(panel)
	var tex_on := load(DIR + data["on"]) as Texture2D
	var tex_off: Texture2D = load(DIR + data["off"]) if ResourceLoader.exists(DIR + data["off"]) else null
	_slots[id] = {"panel": panel, "icon": icon, "on": tex_on, "off": tex_off,
		"glow": data["glow"], "unlocked": data["unlocked"], "lit": null}
	panel.visible = data["unlocked"]
	_apply_state(id, id in ALWAYS_ON, false)


## Liga a arma `weapon_id` e desliga as demais.
func select_weapon(weapon_id: StringName, force: bool = false) -> void:
	if not _slots.has(weapon_id) or weapon_id in ALWAYS_ON:
		return
	if _selected == weapon_id and not force:
		return
	_selected = weapon_id
	if not force:
		_play_swap(weapon_id)
	for id in _slots:
		if id in ALWAYS_ON:
			continue
		_apply_state(id, id == weapon_id, not force)


## Mostra/esconde o slot de uma arma (o .38 lendário só aparece depois de liberado).
func set_unlocked(weapon_id: StringName, value: bool) -> void:
	if not _slots.has(weapon_id):
		return
	var s: Dictionary = _slots[weapon_id]
	if s["unlocked"] == value:
		return
	s["unlocked"] = value
	var panel: PanelContainer = s["panel"]
	panel.visible = value
	if value:
		_apply_state(weapon_id, weapon_id in ALWAYS_ON or _selected == weapon_id, false)
		# "pop" de entrada quando a arma é liberada
		panel.scale = Vector2(0.2, 0.2)
		panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, 0.25)


func _apply_state(id: StringName, lit: bool, animate: bool) -> void:
	var s: Dictionary = _slots[id]
	if s["lit"] == lit and animate:
		return
	s["lit"] = lit
	var panel: PanelContainer = s["panel"]
	var icon: TextureRect = s["icon"]
	var glow: Color = s["glow"]

	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.set_border_width_all(3 if lit else 2)
	if lit:
		box.bg_color = Color(0.16, 0.08, 0.20, 0.92)
		box.border_color = glow
		box.shadow_color = Color(glow.r, glow.g, glow.b, 0.55)
		box.shadow_size = 12
	else:
		box.bg_color = Color(0.07, 0.05, 0.09, 0.80)
		box.border_color = Color(0.28, 0.27, 0.32)
		box.shadow_size = 0
	panel.add_theme_stylebox_override("panel", box)

	var off_tex: Texture2D = s["off"]
	icon.texture = s["on"] if (lit or off_tex == null) else off_tex
	var target_scale := Vector2.ONE if lit else Vector2(OFF_SCALE, OFF_SCALE)
	var target_mod := Color.WHITE if lit else (Color(1, 1, 1, 0.75) if off_tex != null else Color(0.35, 0.35, 0.4, 0.85))
	if not animate or not panel.visible:
		panel.scale = target_scale
		icon.modulate = target_mod
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "modulate", target_mod, 0.18)
	if lit:
		# flash rápido ao ligar
		icon.modulate = Color(2.2, 2.2, 2.2, 1.0)


func _play_swap(weapon_id: StringName) -> void:
	if Time.get_ticks_msec() - _born_ms < SFX_MUTE_MS:
		return
	var path := SFX_DIR + (SFX_LENDARIO if weapon_id == &"lendario" else SFX_ANTIGO)
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.play()
