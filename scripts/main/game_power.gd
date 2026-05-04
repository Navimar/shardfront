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
	if name_key == UnitKeys.NAMESTNIK_NAME:
		return base_power + _get_namestnik_defense_bonus(state, cell)
	return base_power


func get_card_attack_power(card: Dictionary) -> int:
	if bool(card.face_down):
		return 0
	var name_key: String = String(card.unit.name_key)
	if name_key == UnitKeys.FEYA_NAME:
		return 15
	if name_key == UnitKeys.STENA_NAME:
		return 0
	return int(card.get("attack_power_override", int(card.unit.power)))


func can_attack_card(state: Dictionary, attack_card: Dictionary, target_cell: Vector2i) -> bool:
	if bool(attack_card.face_down):
		return false
	if String(attack_card.unit.name_key) == UnitKeys.MEHROY_NAME:
		return game._top_power_in_state(state, target_cell) > 4
	return _get_card_attack_power_for_target(state, attack_card, target_cell) >= game._top_power_in_state(state, target_cell)


func _get_card_attack_power_for_target(state: Dictionary, attack_card: Dictionary, target_cell: Vector2i) -> int:
	return (
		_get_card_attack_power_in_state(state, attack_card)
		+ _get_ballista_attack_bonus(state, int(attack_card.owner), target_cell)
		+ _get_kladents_attack_bonus(state, int(attack_card.owner))
		+ int(attack_card.get("attack_bonus", 0))
	)


func _get_card_attack_power_in_state(state: Dictionary, card: Dictionary) -> int:
	if bool(card.get("face_down", false)):
		return get_card_attack_power(card)
	if String(card.unit.name_key) != UnitKeys.ZERKALNYY_GOLEM_NAME:
		return get_card_attack_power(card)
	var location: Dictionary = _find_card_cell_and_index(state, int(card.id))
	if location.is_empty():
		return get_card_attack_power(card)
	var stack: Array = game._get_stack_in_state(state, location.cell)
	var card_index: int = int(location.index)
	if card_index <= 0:
		return get_card_attack_power(card)
	var copied_card: Dictionary = stack[card_index - 1]
	if bool(copied_card.face_down):
		return get_card_attack_power(card)
	return get_card_attack_power(copied_card)


func _find_card_cell_and_index(state: Dictionary, card_id: int) -> Dictionary:
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			var card_index: int = game._find_card_index_in_array(stack, card_id)
			if card_index >= 0:
				return {
					"cell": cell,
					"index": card_index
				}
	return {}


func _get_kladents_attack_bonus(state: Dictionary, player_index: int) -> int:
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != player_index:
				continue
			if bool(card.face_down):
				continue
			if String(card.unit.name_key) == UnitKeys.KLADENETS_NAME:
				return 10
	return 0


func _get_bashnya_defense_bonus(state: Dictionary, player_index: int, cell: Vector2i) -> int:
	var base: Vector2i = state.players[player_index].base
	if _are_unblocked_orthogonal_neighbors(state, base, cell):
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
		if game._has_barrier_in_state(state, cell, neighbor):
			continue
		if game._top_owner_in_state(state, neighbor) != player_index:
			continue
		if game._top_face_down_in_state(state, neighbor):
			continue
		neighbor_count += 1
	return 4 * neighbor_count


func _get_namestnik_defense_bonus(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.size() < 2:
		return 0
	var covered_card: Dictionary = stack[stack.size() - 2]
	if bool(covered_card.face_down):
		return 0
	return int(covered_card.unit.power)


func _get_ballista_attack_bonus(state: Dictionary, player_index: int, target_cell: Vector2i) -> int:
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = target_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, target_cell, cell):
			continue
		var stack: Array = game._get_stack_in_state(state, cell)
		if stack.is_empty():
			continue
		var card: Dictionary = stack[stack.size() - 1]
		if int(card.owner) != player_index:
			continue
		if bool(card.face_down):
			continue
		if String(card.unit.name_key) == UnitKeys.BALLISTA_NAME:
			return 9
	return 0


func _are_unblocked_orthogonal_neighbors(state: Dictionary, first: Vector2i, second: Vector2i) -> bool:
	var diff: Vector2i = first - second
	if abs(diff.x) + abs(diff.y) != 1:
		return false
	return not game._has_barrier_in_state(state, first, second)
