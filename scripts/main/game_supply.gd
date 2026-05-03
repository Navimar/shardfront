extends RefCounted

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func get_supplied_cells(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.supplied


func get_supply_control_cells(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.control


func get_supply_edges(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.edges


func calculate_supply_result(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = _make_empty_supply_result(state, player_index)
	_apply_base_supply_rule(result)
	_apply_lokomotiv_supply_rule(result)
	_apply_yarkiy_les_supply_rule(result)
	_apply_istukan_supply_rule(result)
	return result


func _apply_base_supply_rule(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var base: Vector2i = state.players[player_index].base
	_add_conductor(result, base)
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _top_owner(state, cell) == player_index:
				_add_conductor(result, cell)
	_add_standard_edges_for_conductors(result)
	_rebuild_reachability_from_base(result)


func _apply_lokomotiv_supply_rule(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var lokomotivs: Array = []
	for cell in result.conductors.keys():
		if _top_owner(state, cell) == player_index and _top_name_key(state, cell) == game.UNIT_LOKOMOTIV_NAME:
			lokomotivs.append(cell)
	for cell in lokomotivs:
		_add_lokomotiv_diagonal_edges(result, cell)
	_rebuild_reachability_from_base(result)


func _apply_yarkiy_les_supply_rule(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var opponent_index: int = game._opponent(player_index)
	var supplied_forests: Array = []
	for cell in result.supplied.keys():
		if _top_owner(state, cell) == opponent_index and _top_name_key(state, cell) == game.UNIT_YARKIY_LES_NAME:
			supplied_forests.append(cell)
	for cell in supplied_forests:
		_add_conductor(result, cell)
		_add_standard_edges_for_conductor(result, cell)
	_rebuild_reachability_from_base(result)


func _apply_istukan_supply_rule(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var removed_any: bool = false
	for cell in result.conductors.keys():
		if cell == state.players[player_index].base:
			continue
		if _top_owner(state, cell) == player_index and _top_name_key(state, cell) == game.UNIT_ISTUKAN_NAME:
			_remove_conductor(result, cell)
			removed_any = true
	if removed_any:
		_rebuild_standard_edges(result)
		_rebuild_reachability_from_base(result)


func _make_empty_supply_result(state: Dictionary, player_index: int) -> Dictionary:
	return {
		"state": state,
		"player_index": player_index,
		"conductors": {},
		"edges": {},
		"supplied": {},
		"control": {}
	}


func _add_conductor(result: Dictionary, cell: Vector2i) -> void:
	result.conductors[cell] = true


func _remove_conductor(result: Dictionary, cell: Vector2i) -> void:
	result.conductors.erase(cell)
	result.edges.erase(cell)


func _rebuild_standard_edges(result: Dictionary) -> void:
	result.edges.clear()
	_add_standard_edges_for_conductors(result)
	_apply_lokomotiv_edges_from_current_result(result)
	_apply_yarkiy_les_edges_from_current_result(result)


func _apply_lokomotiv_edges_from_current_result(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	for cell in result.supplied.keys():
		if _is_conductor(result, cell) and _top_owner(state, cell) == player_index and _top_name_key(state, cell) == game.UNIT_LOKOMOTIV_NAME:
			_add_lokomotiv_diagonal_edges(result, cell)


func _apply_yarkiy_les_edges_from_current_result(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var opponent_index: int = game._opponent(player_index)
	for cell in result.supplied.keys():
		if _is_conductor(result, cell) and _top_owner(state, cell) == opponent_index and _top_name_key(state, cell) == game.UNIT_YARKIY_LES_NAME:
			_add_standard_edges_for_conductor(result, cell)


func _add_standard_edges_for_conductors(result: Dictionary) -> void:
	for cell in result.conductors.keys():
		_add_standard_edges_for_conductor(result, cell)


func _add_standard_edges_for_conductor(result: Dictionary, cell: Vector2i) -> void:
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + direction
		if not game._is_inside(next):
			continue
		if game._has_barrier_in_state(result.state, cell, next):
			continue
		_add_edge(result, cell, next)


func _add_lokomotiv_diagonal_edges(result: Dictionary, cell: Vector2i) -> void:
	for direction in [
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]:
		var next: Vector2i = cell + direction
		if not game._is_inside(next):
			continue
		_add_edge(result, cell, next)
		if _is_conductor(result, next):
			_add_edge(result, next, cell)


func _add_edge(result: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not result.edges.has(from_cell):
		result.edges[from_cell] = {}
	result.edges[from_cell][to_cell] = true


func _rebuild_reachability_from_base(result: Dictionary) -> void:
	result.supplied.clear()
	result.control.clear()
	var base: Vector2i = result.state.players[int(result.player_index)].base
	var queue: Array = [base]
	result.supplied[base] = true
	if _is_conductor(result, base):
		result.control[base] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var edges: Dictionary = result.edges.get(current, {})
		for next in edges.keys():
			if result.supplied.has(next):
				continue
			result.supplied[next] = true
			if _is_conductor(result, next):
				result.control[next] = true
				queue.append(next)


func _is_conductor(result: Dictionary, cell: Vector2i) -> bool:
	return result.conductors.has(cell)


func _top_owner(state: Dictionary, cell: Vector2i) -> int:
	return game._top_owner_in_state(state, cell)


func _top_name_key(state: Dictionary, cell: Vector2i) -> String:
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.is_empty():
		return ""
	var card: Dictionary = stack[stack.size() - 1]
	if bool(card.face_down):
		return ""
	return String(card.unit.name_key)
