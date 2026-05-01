extends Control

const NAME_FONT_SIZE: int = 24
const POWER_FONT_SIZE: int = 30

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
			_apply_face_state()

@export var face_down: bool = false:
	get:
		return _face_down
	set(value):
		_face_down = value
		if is_node_ready():
			_apply_face_state()

var _unit: Resource = null
var _player_index: int = -1
var _face_down: bool = false
var _portrait_desaturated: bool = false
var _text_muted: bool = false
var _back_desaturated: bool = false

@onready var panel: Panel = %Panel
@onready var background: Panel = %Background
@onready var content: VBoxContainer = $Content
@onready var portrait: TextureRect = %Portrait
@onready var power_badge: Panel = %PowerBadge
@onready var name_label: Label = %NameLabel
@onready var power_label: Label = %PowerLabel
@onready var description_label: Label = %DescriptionLabel

var back_texture: TextureRect
var wood_card_back: Texture2D = preload("res://assets/cards/card_back_red.jpeg")
var metal_card_back: Texture2D = preload("res://assets/cards/card_back_blue.jpeg")


func _ready() -> void:
	_build_back_texture()
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	power_label.add_theme_font_size_override("font_size", POWER_FONT_SIZE)
	_apply_unit()
	_apply_player_style()
	_apply_portrait_desaturation()
	_apply_text_muted()
	_apply_face_state()


func set_portrait_desaturated(enabled: bool) -> void:
	_portrait_desaturated = enabled
	if is_node_ready():
		_apply_portrait_desaturation()


func set_text_muted(enabled: bool) -> void:
	_text_muted = enabled
	if is_node_ready():
		_apply_text_muted()


func set_back_desaturated(enabled: bool) -> void:
	_back_desaturated = enabled
	if is_node_ready():
		_apply_face_state()


func reset_visual_modifiers() -> void:
	set_portrait_desaturated(false)
	set_text_muted(false)
	set_back_desaturated(false)
	_clear_extra_frames()
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _build_back_texture() -> void:
	back_texture = TextureRect.new()
	back_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_texture.offset_left = 3
	back_texture.offset_top = 3
	back_texture.offset_right = -3
	back_texture.offset_bottom = -3
	back_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_texture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(back_texture)
	move_child(back_texture, get_child_count() - 2)


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
		background_style.bg_color = Color(0.42, 0.25, 0.10)
		style.border_color = Color(0.42, 0.25, 0.10)
	elif _player_index == 1:
		background_style.bg_color = Color(0.10, 0.30, 0.46)
		style.border_color = Color(0.10, 0.30, 0.46)
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
	style.set_border_width_all(3)
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


func _apply_face_state() -> void:
	if back_texture == null:
		return
	if _player_index == 0:
		back_texture.texture = wood_card_back
	else:
		back_texture.texture = metal_card_back
	back_texture.visible = _face_down
	content.visible = not _face_down
	if _back_desaturated:
		back_texture.material = _make_desaturation_material()
	else:
		back_texture.material = null


func _make_desaturation_material() -> ShaderMaterial:
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
	return shader_material


func _clear_extra_frames() -> void:
	for child in get_children():
		if child.has_meta("selection_frame"):
			child.queue_free()
