extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func get_top_power(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.is_empty():
		return 0
	var card: Dictionary = stack[stack.size() - 1]
	if bool(card.face_down):
		return 0
	return get_card_power_in_cell(state, card, cell)


func get_card_power_in_cell(state: Dictionary, card: Dictionary, cell: Vector2i) -> int:
	if bool(card.face_down):
		return 0
	var base_power: int = int(card.unit.power)
	var name_key: String = String(card.unit.name_key)
	if name_key == UnitKeys.BASHNYA_NAME:
		return base_power + _get_bashnya_defense_bonus(state, int(card.owner), cell)
	if name_key == UnitKeys.MAGICHESKIY_SCHIT_NAME:
		return base_power + _get_magicheskiy_schit_defense_bonus(state, int(card.owner), cell)
	if name_key == UnitKeys.MANOPROVOD_NAME:
		return _get_manoprovod_power(state, int(card.owner), cell)
	return base_power


func _get_bashnya_defense_bonus(state: Dictionary, player_index: int, cell: Vector2i) -> int:
	var base: Vector2i = state.players[player_index].base
	if _are_orthogonal_neighbors(base, cell):
		return 1
	return 0


func _get_magicheskiy_schit_defense_bonus(state: Dictionary, player_index: int, cell: Vector2i) -> int:
	if game._get_supplied_cells_in_state(state, player_index).has(cell):
		return 10
	return 0


func _get_manoprovod_power(state: Dictionary, player_index: int, cell: Vector2i) -> int:
	var neighbor_count: int = 0
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = cell + direction
		if not game._is_inside(neighbor):
			continue
		if game._top_owner_in_state(state, neighbor) != player_index:
			continue
		if game._top_face_down_in_state(state, neighbor):
			continue
		neighbor_count += 1
	return 4 * neighbor_count


func _are_orthogonal_neighbors(first: Vector2i, second: Vector2i) -> bool:
	var diff: Vector2i = first - second
	return abs(diff.x) + abs(diff.y) == 1
