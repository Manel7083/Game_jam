class_name ParticleFX
extends RefCounted
## Lightweight GPU particle bursts used for combat and progression feedback.
## Effects dynamically generate a soft glow texture, use controlled scales, 
## and feature proper physics like gravity and scale-fading.

const MAX_ACTIVE_EFFECTS := 300

# Paleta do Lobo (pelo roxo, olhos amarelos)
const WOLF_PURPLE := Color(0.55, 0.25, 0.9, 0.9)
const WOLF_VIOLET := Color(0.75, 0.5, 1.0, 0.85)
const WOLF_EYE_YELLOW := Color(1.0, 0.85, 0.2, 1.0)

# Neon dos olhos: amarelo elétrico que esfria para rosa-choque
const NEON_YELLOW := Color(1.0, 0.95, 0.15, 1.0)
const NEON_PINK := Color(1.0, 0.2, 0.8, 0.9)

static var _active_effects := 0
static var _texture: Texture2D
static var _additive_material: CanvasItemMaterial

# ==============================================================================
# PRESETS DE COMBATE E EFEITOS
# ==============================================================================

static func muzzle_flash(parent: Node, position: Vector2, direction: Vector2 = Vector2.RIGHT) -> void:
	# Disparo rápido, brilhante e concentrado.
	_spawn_burst(
		parent, position, 5, 0.12, 
		80.0, 150.0, 
		0.2, 0.5, # Escala muito menor e controlada
		Color(1.0, 0.85, 0.4, 0.95), 
		direction, 25.0, 
		Vector3.ZERO # Sem gravidade
	)

static func hit_spark(parent: Node, position: Vector2) -> void:
	# Faíscas afiadas quando um golpe acerta armadura/cenário.
	_spawn_burst(
		parent, position, 4, 0.15, 
		100.0, 200.0, 
		0.1, 0.3, 
		Color(1.0, 0.9, 0.6, 1.0), 
		Vector2.RIGHT, 180.0,
		Vector3(0, 200, 0) # Cai levemente
	)

static func enemy_death(parent: Node, position: Vector2) -> void:
	# Explosão sombria quando um inimigo comum morre.
	_spawn_burst(
		parent, position, 15, 0.40, 
		50.0, 120.0, 
		0.3, 0.8, 
		Color(0.2, 0.1, 0.3, 0.85), # Roxo sombrio/Sangue coagulado
		Vector2.UP, 360.0,
		Vector3(0, 50, 0)
	)

static func player_damage(parent: Node, position: Vector2) -> void:
	# O Lobo tomou dano: Gotas de sangue viscerais espirrando e caindo rápido.
	_spawn_burst(
		parent, position, 12, 0.60, 
		120.0, 250.0, 
		0.2, 0.6, 
		Color(0.8, 0.05, 0.1, 0.9), # Vermelho sangue vivo
		Vector2.UP, 140.0, # Espirra para cima
		Vector3(0, 600, 0) # Cai com muita gravidade (peso do sangue)
	)

static func score_reward(parent: Node, position: Vector2) -> void:
	# Brilho dourado flutuante.
	_spawn_burst(
		parent, position, 10, 0.50, 
		40.0, 80.0, 
		0.2, 0.5, 
		Color(1.0, 0.85, 0.2, 0.9), 
		Vector2.UP, 180.0,
		Vector3(0, -50, 0) # Flutua para cima (anti-gravidade)
	)

static func objective_complete(parent: Node, position: Vector2) -> void:
	_spawn_burst(
		parent, position, 15, 0.60, 
		30.0, 90.0, 
		0.3, 0.7, 
		Color(0.3, 1.0, 0.5, 0.8), 
		Vector2.UP, 360.0,
		Vector3(0, -20, 0)
	)

static func pickup(parent: Node, position: Vector2) -> void:
	_spawn_burst(
		parent, position, 6, 0.30, 
		20.0, 60.0, 
		0.15, 0.4, 
		Color(0.2, 0.8, 1.0, 0.85), 
		Vector2.UP, 360.0,
		Vector3.ZERO
	)

# ==============================================================================
# DASH DO LOBO
# ==============================================================================

static func dash_start(parent: Node, position: Vector2, direction: Vector2) -> void:
	# Arranque do dash: rajada roxa jogada PARA TRÁS (oposta ao movimento)
	# + faíscas amarelas, o brilho dos olhos do lobo.
	var back := -direction.normalized()
	_spawn_burst(
		parent, position, 10, 0.35,
		60.0, 140.0,
		0.3, 0.7,
		WOLF_PURPLE,
		back, 35.0,
		Vector3.ZERO
	)
	_spawn_burst(
		parent, position, 4, 0.25,
		80.0, 160.0,
		0.1, 0.25,
		WOLF_EYE_YELLOW,
		back, 25.0,
		Vector3.ZERO
	)

static func dash_end(parent: Node, position: Vector2) -> void:
	# Pequena nuvem violeta quando o lobo termina o dash.
	_spawn_burst(
		parent, position, 6, 0.30,
		20.0, 60.0,
		0.2, 0.5,
		WOLF_VIOLET,
		Vector2.UP, 360.0,
		Vector3.ZERO
	)

## Cria o rastro contínuo do dash, já anexado ao nó. Começa DESLIGADO:
## ligue com `trail.emitting = true` no início do dash e desligue no fim.
static func create_dash_trail(parent: Node2D) -> GPUParticles2D:
	if not is_instance_valid(parent):
		return null

	var particles := GPUParticles2D.new()
	particles.texture = _get_procedural_texture()
	particles.amount = 24
	particles.lifetime = 0.35
	particles.one_shot = false
	particles.emitting = false
	particles.explosiveness = 0.0
	particles.local_coords = false # Deixa o rastro para trás enquanto o lobo avança
	particles.z_index = -1         # Atrás do sprite do lobo

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 0.9
	_apply_scale_curve(mat)

	# Nasce com um brilho amarelo (olhos), vira roxo e some em fumaça escura.
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.9, 0.4, 0.8),
		Color(0.55, 0.25, 0.9, 0.7),
		Color(0.15, 0.05, 0.25, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	particles.process_material = mat
	parent.add_child(particles)
	return particles

# ==============================================================================
# OLHOS NEON DO LOBO
# ==============================================================================

## Cria um "olho" (Node2D) com um brilho sutil sempre ligado + um rastro que só
## emite quando o lobo anda. Crie um por olho e posicione o Node2D retornado.
static func create_eye_fx(parent: Node2D) -> Node2D:
	if not is_instance_valid(parent):
		return null
	var eye := Node2D.new()
	eye.name = "EyeFX"
	eye.z_index = 2 # Por cima do sprite do lobo
	parent.add_child(eye)
	eye.add_child(_make_eye_glow())
	eye.add_child(_make_eye_trail())
	return eye

## Liga/desliga o rastro. O rastro sai no sentido OPOSTO a `move_direction`.
static func set_eye_trail(eye: Node2D, active: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(eye):
		return
	var trail := eye.get_node_or_null("trail") as GPUParticles2D
	if trail == null:
		return
	trail.emitting = active
	if active and move_direction.length() > 0.01:
		var back := -move_direction.normalized()
		var mat := trail.process_material as ParticleProcessMaterial
		mat.direction = Vector3(back.x, back.y, 0.0)

## Desliga tudo (usado na morte do lobo).
static func stop_eye_fx(eye: Node2D) -> void:
	if not is_instance_valid(eye):
		return
	for child in eye.get_children():
		if child is GPUParticles2D:
			child.emitting = false

static func _make_eye_glow() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "glow"
	p.texture = _get_procedural_texture()
	p.material = _get_additive_material()
	p.amount = 2
	p.lifetime = 0.9
	p.one_shot = false
	p.local_coords = true # Acompanha o olho

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.06
	mat.scale_max = 0.14
	_apply_scale_curve(mat)
	mat.color_ramp = _neon_ramp()
	p.process_material = mat
	return p

static func _make_eye_trail() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "trail"
	p.texture = _get_procedural_texture()
	p.material = _get_additive_material()
	p.amount = 14
	p.lifetime = 0.4
	p.one_shot = false
	p.emitting = false
	p.explosiveness = 0.0
	p.local_coords = false # Fica no mundo: deixa o rastro para trás

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-1, 0, 0) # Atualizado em set_eye_trail()
	mat.spread = 6.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.07
	mat.scale_max = 0.14
	_apply_scale_curve(mat)
	mat.color_ramp = _neon_ramp()
	p.process_material = mat
	return p

static func _neon_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.95, 0.15, 0.55),
		Color(1.0, 0.2, 0.8, 0.40),
		Color(1.0, 0.2, 0.8, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	return ramp

## Blend aditivo: sobrepor partículas soma luz, dando o efeito neon.
static func _get_additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material

# ==============================================================================
# AURA DO LOBO (EFEITO CONTÍNUO)
# ==============================================================================

static func attach_ambient_dust(parent: Node2D) -> void:
	# Recriado: Uma névoa/energia negra e avermelhada que exala do Lobo
	# indicando fúria ou trevas. É contínuo, não é one_shot.
	if not is_instance_valid(parent): return
	
	var particles := GPUParticles2D.new()
	particles.texture = _get_procedural_texture()
	particles.amount = 12
	particles.lifetime = 1.2
	particles.one_shot = false # Fica ativo para sempre enquanto anexado
	particles.local_coords = false # Deixa rastro por onde o lobo anda
	particles.z_index = -1 # Fica atrás do sprite do lobo
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 25.0 # Espalha pelo corpo do lobo
	mat.direction = Vector3(0, -1, 0) # Sobe
	mat.spread = 45.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -10, 0) # Flutua lentamente
	
	# Escala sutil
	mat.scale_min = 0.4
	mat.scale_max = 0.9
	_apply_scale_curve(mat) # Diminui até sumir
	
	# Cor da aura: Começa vermelho escuro e vira fumaça preta
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.6, 0.0, 0.1, 0.6), # Carmesim
		Color(0.05, 0.05, 0.05, 0.0) # Fumaça preta invisível
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	
	particles.process_material = mat
	parent.add_child(particles)

# ==============================================================================
# SISTEMA CORE
# ==============================================================================

static func _spawn_burst(
	parent: Node, position: Vector2, amount: int, lifetime: float, 
	vel_min: float, vel_max: float, scale_min: float, scale_max: float, 
	tint: Color, direction: Vector2, spread: float, gravity: Vector3
) -> void:
	
	if not is_instance_valid(parent) or _active_effects >= MAX_ACTIVE_EFFECTS:
		return

	var particles := GPUParticles2D.new()
	particles.global_position = position
	particles.texture = _get_procedural_texture() # Usa nossa textura glow

	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.9 # Explosão mais orgânica que 1.0 absoluto
	particles.randomness = 0.5
	particles.local_coords = false
	particles.z_index = 20
	particles.modulate = tint

	# Optimization boundary
	particles.visibility_rect = Rect2(-200, -200, 400, 400)

	var mat := ParticleProcessMaterial.new()
	var dir := direction.normalized()
	mat.direction = Vector3(dir.x, dir.y, 0.0)
	mat.spread = spread
	
	mat.initial_velocity_min = vel_min
	mat.initial_velocity_max = vel_max
	mat.gravity = gravity # Gravidade customizada adicionada
	
	mat.damping_min = vel_min * 0.5 # Freio aerodinâmico dinâmico
	mat.damping_max = vel_max * 0.8
	
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	_apply_scale_curve(mat) # Faz as partículas encolherem lindamente

	# Fade suave no final
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	particles.process_material = mat
	parent.add_child(particles)

	_active_effects += 1
	particles.finished.connect(_on_finished.bind(particles))
	particles.emitting = true

static func _on_finished(particles: GPUParticles2D) -> void:
	_active_effects = maxi(_active_effects - 1, 0)
	if is_instance_valid(particles):
		particles.queue_free()

# ==============================================================================
# FUNÇÕES UTILITÁRIAS (Mágica Procedural)
# ==============================================================================

## Gera uma textura circular com brilho macio (Glow) sem precisar de arquivo PNG.
static func _get_procedural_texture() -> Texture2D:
	if _texture != null:
		return _texture
		
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1), # Centro sólido
		Color(1, 1, 1, 0.5), # Meio translúcido
		Color(1, 1, 1, 0)  # Borda invisível
	])
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5) # Centro exato
	tex.fill_to = Vector2(0.9, 0.5) # Define o tamanho do raio
	tex.width = 32
	tex.height = 32
	
	_texture = tex
	return _texture

## Cria uma curva para as partículas diminuírem gradativamente de tamanho antes de sumir
static func _apply_scale_curve(mat: ParticleProcessMaterial) -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0)) # Nasce em 100% do scale
	curve.add_point(Vector2(0.7, 0.8)) # Mantém 80% até os 70% da vida
	curve.add_point(Vector2(1.0, 0.0)) # Encolhe a 0% na hora de morrer
	
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
 
