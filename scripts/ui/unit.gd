extends Control

@export var unit: Resource:
	get:
		return _unit
	set(value):
		_unit = value
		if is_node_ready():
			_apply_unit()

@export var player_index: int = -1:
	get:
		return _player_index
	set(value):
		_player_index = value
		if is_node_ready():
			_apply_player_style()

var _unit: Resource = null
var _player_index: int = -1
var _portrait_desaturated: bool = false
var _text_muted: bool = false

@onready var panel: Panel = %Panel
@onready var background: Panel = %Background
@onready var portrait: TextureRect = %Portrait
@onready var power_badge: Panel = %PowerBadge
@onready var name_label: Label = %NameLabel
@onready var power_label: Label = %PowerLabel
@onready var description_label: Label = %DescriptionLabel


func _ready() -> void:
	_apply_unit()
	_apply_player_style()
	_apply_portrait_desaturation()
	_apply_text_muted()


func set_portrait_desaturated(enabled: bool) -> void:
	_portrait_desaturated = enabled
	if is_node_ready():
		_apply_portrait_desaturation()


func set_text_muted(enabled: bool) -> void:
	_text_muted = enabled
	if is_node_ready():
		_apply_text_muted()


func _apply_unit() -> void:
	if _unit == null:
		portrait.texture = null
		name_label.text = ""
		power_label.text = ""
		description_label.text = ""
		return

	portrait.texture = _unit.portrait
	name_label.text = _unit.get_display_name()
	power_label.text = str(_unit.power)
	description_label.text = _unit.get_description()


func _apply_player_style() -> void:
	var background_style = StyleBoxFlat.new()
	var style = StyleBoxFlat.new()
	if _player_index == 0:
		background_style.bg_color = Color(0.32, 0.21, 0.12)
		style.border_color = Color(0.32, 0.21, 0.12)
	elif _player_index == 1:
		background_style.bg_color = Color(0.14, 0.22, 0.31)
		style.border_color = Color(0.14, 0.22, 0.31)
	else:
		background_style.bg_color = Color(0.16, 0.16, 0.16)
		style.border_color = Color(0.28, 0.28, 0.28)
	background_style.set_corner_radius_all(0)
	background_style.content_margin_left = 0
	background_style.content_margin_top = 0
	background_style.content_margin_right = 0
	background_style.content_margin_bottom = 0
	var badge_style: StyleBoxFlat = background_style.duplicate()
	style.bg_color.a = 0.0
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	background.add_theme_stylebox_override("panel", background_style)
	power_badge.add_theme_stylebox_override("panel", badge_style)
	panel.add_theme_stylebox_override("panel", style)


func _apply_portrait_desaturation() -> void:
	if not _portrait_desaturated:
		portrait.material = null
		return

	var shader = Shader.new()
	shader.code = "
shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(color.rgb, vec3(gray), 0.65);
	COLOR = vec4(muted, color.a);
}
"
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	portrait.material = shader_material


func _apply_text_muted() -> void:
	var color: Color = Color(1.0, 1.0, 1.0)
	if _text_muted:
		color = Color(0.62, 0.62, 0.62)
	name_label.add_theme_color_override("font_color", color)
	power_label.add_theme_color_override("font_color", color)
