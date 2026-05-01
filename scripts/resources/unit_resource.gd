extends Resource
class_name UnitResource

const IMPLEMENTATION_UNIMPLEMENTED: String = "unimplemented"
const IMPLEMENTATION_IMPLEMENTED: String = "implemented"
const IMPLEMENTATION_TESTED: String = "tested"

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var power: int = 0
@export var ability_symbols: String = ""
@export_enum("unimplemented", "implemented", "tested") var implementation_status: String = IMPLEMENTATION_UNIMPLEMENTED
@export var portrait: Texture2D = null


func get_display_name() -> String:
	return tr(name_key)


func get_description() -> String:
	return tr(description_key)


func is_implemented() -> bool:
	return implementation_status == IMPLEMENTATION_IMPLEMENTED or implementation_status == IMPLEMENTATION_TESTED


func is_tested() -> bool:
	return implementation_status == IMPLEMENTATION_TESTED
