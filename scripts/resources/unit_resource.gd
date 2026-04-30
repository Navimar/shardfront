extends Resource
class_name UnitResource

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var power: int = 0
@export var ability_symbols: String = ""
@export var portrait: Texture2D = null


func get_display_name() -> String:
	return tr(name_key)


func get_description() -> String:
	return tr(description_key)
