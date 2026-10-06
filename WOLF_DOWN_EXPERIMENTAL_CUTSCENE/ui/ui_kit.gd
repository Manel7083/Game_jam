class_name UIKit
extends RefCounted
## Shared UI helpers used by menus and overlays.
##
## FONTES: o kit usa MountainsofChristmas (já no projeto) com espaçamento entre letras.
## Se você colocar qualquer uma das fontes abaixo em res://fonts/, ela passa a ser usada
## automaticamente, sem mudar mais nada no código:
##   Títulos: Cinzel-Bold.ttf, CinzelDecorative-Bold.ttf, PirataOne-Regular.ttf, MedievalSharp-Regular.ttf
##   Menus:   Cinzel-Regular.ttf, Metamorphous-Regular.ttf
## (todas são gratuitas, licença OFL, no Google Fonts)

const FONT_REGULAR: FontFile = preload("res://fonts/MountainsofChristmas-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://fonts/MountainsofChristmas-Bold.ttf")
const BUTTON_SCRIPT: Script = preload("res://ui/interactive_button.gd")

const GOLD := Color(1.0, 0.82, 0.45)
const GOLD_D := Color(0.72, 0.52, 0.22)
const PURPLE := Color(0.55, 0.30, 0.75)
const TEXT := Color(0.94, 0.92, 0.98)
const TEXT_DIM := Color(0.70, 0.66, 0.80)
const BLOOD := Color(0.85, 0.12, 0.16)

const TITLE_FONT_PATHS := [
	"res://fonts/Cinzel-Bold.ttf",
	"res://fonts/CinzelDecorative-Bold.ttf",
	"res://fonts/PirataOne-Regular.ttf",
	"res://fonts/MedievalSharp-Regular.ttf",
]
const UI_FONT_PATHS := [
	"res://fonts/Cinzel-Regular.ttf",
	"res://fonts/Metamorphous-Regular.ttf",
]

static var font_title: Font = _make_font(TITLE_FONT_PATHS, FONT_BOLD, 4)
static var font_ui: Font = _make_font(UI_FONT_PATHS, FONT_BOLD, 2)


static func _make_font(paths: Array, fallback: Font, spacing: int) -> Font:
	var base: Font = fallback
	for p in paths:
		if ResourceLoader.exists(p):
			var loaded: Resource = load(p)
			if loaded is Font:
				base = loaded as Font
				break
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	return fv


# ----------------------------------------------------------------------------
# Textos
# ----------------------------------------------------------------------------

static func make_label(text: String, size: int = 32, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font = font_ui
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color(0.02, 0.01, 0.04)
	settings.shadow_color = Color(0, 0, 0, 0.6)
	settings.shadow_offset = Vector2(0, 3)
	label.label_settings = settings
	return label


## Título grande, dourado, com contorno e sombra.
static func make_title(text: String, size: int = 64, color: Color = GOLD) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font = font_title
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = int(size * 0.18)
	settings.outline_color = Color(0.10, 0.02, 0.14)
	settings.shadow_color = Color(0, 0, 0, 0.75)
	settings.shadow_offset = Vector2(0, maxf(3.0, size * 0.06))
	settings.shadow_size = 4
	label.label_settings = settings
	return label


# ----------------------------------------------------------------------------
# Botões
# ----------------------------------------------------------------------------

static func _box(bg: Color, border: Color, border_w: int = 2, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.set_script(BUTTON_SCRIPT)
	button.text = text
	button.custom_minimum_size = Vector2(320, 58)
	button.add_theme_font_override("font", font_ui)
	button.add_theme_font_size_override("font_size", 30)

	var normal := _box(Color(0.09, 0.06, 0.15, 0.94), Color(0.40, 0.26, 0.58))
	var hover := _box(Color(0.22, 0.09, 0.30, 0.98), GOLD, 3)
	var pressed := _box(Color(0.38, 0.10, 0.18, 1.0), Color(1.0, 0.55, 0.45), 3)
	pressed.content_margin_top = 11.0
	pressed.content_margin_bottom = 7.0
	pressed.shadow_size = 2
	var disabled := _box(Color(0.07, 0.05, 0.10, 0.7), Color(0.25, 0.20, 0.32))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.55))
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.06))
	button.add_theme_constant_override("outline_size", 5)

	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(on_pressed)
	return button


# ----------------------------------------------------------------------------
# Painéis e fundos
# ----------------------------------------------------------------------------

static func make_panel(margin: int = 28) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.03, 0.085, 0.95)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.58, 0.40, 0.30)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 30
	sb.content_margin_left = float(margin)
	sb.content_margin_right = float(margin)
	sb.content_margin_top = float(margin)
	sb.content_margin_bottom = float(margin)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel


## Linha decorativa que some nas pontas.
static func make_divider(width: float = 300.0) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(GOLD_D, 0.0), Color(GOLD, 0.95), Color(GOLD_D, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(width, 3)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func make_dim_background(alpha: float = 0.7) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Decorative overlay must never block UI input.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Vinheta nas bordas
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0, 0.05, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var vig := TextureRect.new()
	vig.texture = tex
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(vig)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


## Adds a full-screen CenterContainer to `parent` and returns the VBox inside it.
static func make_centered_column(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(column)
	return column
