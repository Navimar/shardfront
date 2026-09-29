extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")


static func ability_unit(card: Dictionary) -> Resource:
	return card.get("ability_unit", card.unit)


static func name_key(card: Dictionary) -> String:
	return String(ability_unit(card).name_key)


static func active_name_key(state: Dictionary, cell: Vector2i) -> String:
	var stack: Array = state.board[cell.y][cell.x]
	if stack.is_empty():
		return ""
	var index: int = stack.size() - 1
	while index >= 0:
		var card: Dictionary = stack[index]
		if bool(card.face_down):
			return ""
		var unit: Resource = ability_unit(card)
		if index < stack.size() - 1 and not String(unit.ability_symbols).contains("❗"):
			return ""
		if String(unit.name_key) != UnitKeys.ZERKALNYY_GOLEM_NAME:
			return String(unit.name_key)
		index -= 1
	return ""
