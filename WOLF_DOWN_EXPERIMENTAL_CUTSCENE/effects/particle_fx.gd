class_name ParticleFX
extends RefCounted
## Lightweight GPU particle bursts used for combat and progression feedback.
## Effects dynamically generate a soft glow texture, use controlled scales, 
## and feature proper physics like gravity and scale-fading.

const MAX_ACTIVE_EFFECTS := 300

static var _active_effects := 0
static var _texture: Texture2D

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
