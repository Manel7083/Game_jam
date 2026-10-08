extends Node2D
## Wolf Down - Partículas neon de ambiente (discretas) para deixar a noite mais viva e brilhante.
##
## Cria sozinho, só com código (sem imagens): poeira neon macia + faíscas pequenas que piscam
## (CPUParticles2D com mistura aditiva) e alguns "fogos-fátuos" com uma luzinha colorida que passeiam.
##
## Dois modos:
##  - fixed_rect vazio  -> segue a câmera (mapas grandes: a densidade é sempre a mesma na tela).
##  - fixed_rect preenchido -> cobre só aquela área (arenas fixas, ex.: Rect2(0, 0, 896, 640)).
##
## Para diminuir/aumentar o efeito use `intensity` (0 = desligado, 1 = padrão, 2 = bem mais cheio).

@export var palette: PackedColorArray = PackedColorArray([Color(1.0, 0.25, 0.85), Color(0.2, 0.95, 1.0), Color(0.65, 0.35, 1.0)])
@export var fixed_rect: Rect2 = Rect2()
@export_range(0.0, 2.0, 0.05) var intensity: float = 1.0
@export_range(0, 6) var wisp_count: int = 3

## Área visível de referência (~738 x 415: tela 1920x1080 com zoom 2.6). Serve para escalar arenas maiores.
const VISIBLE_AREA_REF: float = 306000.0
const MOTE_LIFETIME: float = 7.0
const SPARK_LIFETIME: float = 3.2

var _follow: bool = true
var _extents: Vector2 = Vector2(380.0, 215.0)
var _emitters: Array[CPUParticles2D] = []
var _wisp_nodes: Array[Node2D] = []
var _wisp_lights: Array[PointLight2D] = []
var _wisp_cores: Array[Sprite2D] = []
var _wisp_seed: Array[float] = []
var _t: float = 0.0
var _soft_tex: GradientTexture2D
var _light_tex: GradientTexture2D
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	# Fica acima do chão e das decorações, mas continua sendo mundo (o HUD é CanvasLayer, não é afetado).
	z_index = 6
	z_as_relative = false
	_follow = fixed_rect.size.x <= 0.0 or fixed_rect.size.y <= 0.0

	_soft_tex = _make_radial(64)
	_light_tex = _make_radial(128)
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var density: float = 1.0
	if _follow:
		_refresh_follow()
	else:
		global_position = fixed_rect.position + fixed_rect.size * 0.5
		_extents = fixed_rect.size * 0.5
		density = clampf(fixed_rect.size.x * fixed_rect.size.y / VISIBLE_AREA_REF, 0.8, 2.2)

	_build_emitters(density)
	_build_wisps()
	_apply_extents()

	if _follow:
		# A câmera só vira a ativa no primeiro frame: recomeça as partículas já perto do jogador.
		await get_tree().process_frame
		_refresh_follow()
		_apply_extents()
		for e in _emitters:
			e.restart()
		for i in _wisp_nodes.size():
			_wisp_nodes[i].global_position = global_position + _wisp_target(_wisp_seed[i], _t)


func _process(delta: float) -> void:
	_t += delta
	if _follow:
		var old: Vector2 = _extents
		_refresh_follow()
		if not old.is_equal_approx(_extents):
			_apply_extents()
	_update_wisps(delta)


# ==============================================================================
# CONSTRUÇÃO
# ==============================================================================

func _make_radial(px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


## Rampa de transparência ao longo da vida da partícula (nasce, pisca e some suave).
func _make_ramp(offsets: Array, alphas: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in offsets.size():
		offs.append(float(offsets[i]))
		cols.append(Color(1, 1, 1, float(alphas[i])))
	g.offsets = offs
	g.colors = cols
	return g


func _make_emitter(col: Color, amount: int, life: float, ramp: Gradient) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.lifetime_randomness = 0.5
	p.local_coords = false
	p.texture = _soft_tex
	p.material = _add_mat
	p.color = col
	p.color_ramp = ramp
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = _extents
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.tangential_accel_min = -5.0
	p.tangential_accel_max = 5.0
	return p


func _build_emitters(density: float) -> void:
	if palette.is_empty() or intensity <= 0.0:
		return
	var soft_ramp: Gradient = _make_ramp([0.0, 0.18, 0.55, 0.85, 1.0], [0.0, 0.8, 0.45, 0.75, 0.0])
	var spark_ramp: Gradient = _make_ramp([0.0, 0.10, 0.30, 0.55, 0.80, 1.0], [0.0, 1.0, 0.15, 0.9, 0.15, 0.0])
	for i in palette.size():
		var c: Color = palette[i]

		# Poeira neon: pontos macios que flutuam devagar.
		var motes: CPUParticles2D = _make_emitter(c, maxi(1, roundi(9.0 * intensity * density)), MOTE_LIFETIME, soft_ramp)
		motes.initial_velocity_min = 3.0
		motes.initial_velocity_max = 12.0
		motes.scale_amount_min = 0.10
		motes.scale_amount_max = 0.24
		add_child(motes)
		_emitters.append(motes)

		# Faíscas: bem pequenas, mais claras, piscando.
		var sparks: CPUParticles2D = _make_emitter(c.lightened(0.35), maxi(1, roundi(6.0 * intensity * density)), SPARK_LIFETIME, spark_ramp)
		sparks.initial_velocity_min = 6.0
		sparks.initial_velocity_max = 18.0
		sparks.scale_amount_min = 0.04
		sparks.scale_amount_max = 0.09
		add_child(sparks)
		_emitters.append(sparks)


func _build_wisps() -> void:
	if wisp_count <= 0 or palette.is_empty() or intensity <= 0.05:
		return
	for i in wisp_count:
		var c: Color = palette[i % palette.size()]
		var node := Node2D.new()

		# Luzinha colorida que ilumina o chão em volta (deixa a noite mais clara onde ele passa).
		var light := PointLight2D.new()
		light.texture = _light_tex
		light.texture_scale = 0.8
		light.color = c
		light.energy = 0.35 * intensity
		light.shadow_enabled = false
		node.add_child(light)

		# Núcleo brilhante do fogo-fátuo.
		var core := Sprite2D.new()
		core.texture = _soft_tex
		core.material = _add_mat
		core.modulate = c.lightened(0.25)
		core.scale = Vector2(0.14, 0.14)
		node.add_child(core)

		add_child(node)
		node.global_position = global_position + _wisp_target(float(i) * 2.1, 0.0)
		_wisp_nodes.append(node)
		_wisp_lights.append(light)
		_wisp_cores.append(core)
		_wisp_seed.append(float(i) * 2.1 + 0.7)


# ==============================================================================
# ATUALIZAÇÃO
# ==============================================================================

func _refresh_follow() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	global_position = cam.get_screen_center_position()
	var view: Vector2 = get_viewport().get_visible_rect().size
	_extents = (view / cam.zoom) * 0.55


func _apply_extents() -> void:
	for e in _emitters:
		e.emission_rect_extents = _extents


## Posição-alvo (relativa ao centro) de cada fogo-fátuo: um passeio lento em curvas.
func _wisp_target(seed_v: float, time_v: float) -> Vector2:
	return Vector2(
		sin(time_v * 0.23 + seed_v * 1.9) * _extents.x * 0.75,
		cos(time_v * 0.17 + seed_v * 1.3) * _extents.y * 0.70)


func _update_wisps(delta: float) -> void:
	for i in _wisp_nodes.size():
		var sd: float = _wisp_seed[i]
		var target: Vector2 = global_position + _wisp_target(sd, _t)
		# Segue o alvo com folga: não fica "grudado" na tela quando a câmera anda.
		_wisp_nodes[i].global_position = _wisp_nodes[i].global_position.lerp(target, clampf(delta * 0.6, 0.0, 1.0))
		var pulse: float = 0.5 + 0.5 * sin(_t * 1.7 + sd * 3.0)
		_wisp_lights[i].energy = intensity * (0.22 + 0.22 * pulse)
		_wisp_cores[i].modulate.a = 0.55 + 0.4 * pulse
