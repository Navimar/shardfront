extends Control

@export var unit: Resource:
	get:
		return _unit
	set(value):
		_unit = value
		if is_node_ready():
			_apply_unit()

var _unit: Resource = null

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var power_label: Label = %PowerLabel
@onready var description_label: Label = %DescriptionLabel


func _ready() -> void:
	_apply_unit()


func _apply_unit() -> void:
	if _unit == null:
		portrait.texture = null
		name_label.text = ""
		power_label.text = ""
		description_label.text = ""
		return

	portrait.texture = _unit.portrait
	name_label.text = _unit.get_display_name()
	power_label.text = "%s %s" % [_unit.ability_symbols, str(_unit.power)]
	description_label.text = _unit.get_description()
