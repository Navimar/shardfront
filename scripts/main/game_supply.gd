extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func get_supplied_cells(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.supplied


func get_supply_edges(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.edges


func get_supply_origin_cells(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = calculate_supply_result(state, player_index)
	return result.origins


func calculate_supply_result(state: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = _make_empty_supply_result(state, player_index)
	_apply_base_supply_rule(result)
	_apply_oboz_supply_rule(result)
	_apply_istukan_supply_rule(result)
	_apply_standard_supply_bridge_rule(result)
	_apply_barrier_supply_rule(result)
	_apply_vorota_supply_rule(result)
	_apply_lokomotiv_supply_rule(result)
	_apply_tonnel_supply_rule(result)
	_resolve_yarkiy_les_supply_rule(result)
	_rebuild_reachability(result)
	return result


func _apply_base_supply_rule(result: Dictionary) -> void:
	var state: Dictionary = result.state
	var player_index: int = int(result.player_index)
	var base: Vector2i = state.players[player_index].base
	_add_source(result, base)
	_add_conductor(result, base)
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _top_owner(state, cell) == player_index:
				_add_conductor(result, cell)


func _apply_oboz_supply_rule(result: Dictionary) -> void:
	var player_index: int = int(result.player_index)
	for cell in _get_top_unit_cells(result.state, player_index, UnitKeys.OBOZ_NAME):
		_add_source(result, cell)
		_add_conductor(result, cell)


func _apply_istukan_supply_rule(result: Dictionary) -> void:
	var player_index: int = int(result.player_index)
	for cell in _get_top_unit_cells(result.state, player_index, UnitKeys.ISTUKAN_NAME):
		if not _is_base_cell(result, cell):
			_remove_conductor(result, cell)


func _apply_standard_supply_bridge_rule(result: Dictionary) -> void:
	for cell in result.conductors.keys():
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if not game._is_inside(next):
				continue
			_add_edge(result, cell, next)


func _apply_barrier_supply_rule(result: Dictionary) -> void:
	var blocked_edges: Array = []
	for from_cell in result.edges.keys():
		var edges: Dictionary = result.edges[from_cell]
		for to_cell in edges.keys():
			if game._has_barrier_in_state(result.state, from_cell, to_cell):
				blocked_edges.append([from_cell, to_cell])
	for edge in blocked_edges:
		_remove_edge(result, edge[0], edge[1])


func _apply_lokomotiv_supply_rule(result: Dictionary) -> void:
	var player_index: int = int(result.player_index)
	for cell in _get_top_unit_cells(result.state, player_index, UnitKeys.LOKOMOTIV_NAME):
		if not _is_conductor(result, cell):
			continue
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


func _apply_vorota_supply_rule(result: Dictionary) -> void:
	var player_index: int = int(result.player_index)
	for cell in _get_top_unit_cells(result.state, player_index, UnitKeys.VOROTA_NAME):
		if not _is_conductor(result, cell):
			continue
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if not game._is_inside(next):
				continue
			if not game._has_barrier_in_state(result.state, cell, next):
				continue
			_add_edge(result, cell, next)
			if _is_conductor(result, next):
				_add_edge(result, next, cell)


func _apply_tonnel_supply_rule(result: Dictionary) -> void:
	for cell in result.conductors.keys():
		if _top_name_key(result.state, cell) != UnitKeys.TONNEL_NAME:
			continue
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction * 2
			if not game._is_inside(next):
				continue
			_add_edge(result, cell, next)
			if _is_conductor(result, next):
				_add_edge(result, next, cell)


func _resolve_yarkiy_les_supply_rule(result: Dictionary) -> void:
	while true:
		_rebuild_reachability(result)
		var added_any: bool = false
		var opponent_index: int = game._opponent(int(result.player_index))
		for cell in result.supplied.keys():
			if _is_conductor(result, cell):
				continue
			if _top_owner(result.state, cell) != opponent_index:
				continue
			if _top_name_key(result.state, cell) != UnitKeys.YARKIY_LES_NAME:
				continue
			_add_conductor(result, cell)
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = cell + direction
				if game._is_inside(next) and not game._has_barrier_in_state(result.state, cell, next):
					_add_edge(result, cell, next)
			added_any = true
		if not added_any:
			return


func _rebuild_reachability(result: Dictionary) -> void:
	result.supplied.clear()
	result.origins.clear()
	var queue: Array = []
	for source in result.sources.keys():
		result.supplied[source] = true
		queue.append(source)
		if _is_conductor(result, source):
			result.origins[source] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var edges: Dictionary = result.edges.get(current, {})
		for next in edges.keys():
			if result.supplied.has(next):
				continue
			result.supplied[next] = true
			if _is_conductor(result, next):
				result.origins[next] = true
				queue.append(next)


func _make_empty_supply_result(state: Dictionary, player_index: int) -> Dictionary:
	return {
		"state": state,
		"player_index": player_index,
		"sources": {},
		"conductors": {},
		"edges": {},
		"supplied": {},
		"origins": {}
	}


func _add_source(result: Dictionary, cell: Vector2i) -> void:
	result.sources[cell] = true


func _add_conductor(result: Dictionary, cell: Vector2i) -> void:
	result.conductors[cell] = true


func _remove_conductor(result: Dictionary, cell: Vector2i) -> void:
	result.conductors.erase(cell)
	result.edges.erase(cell)


func _add_edge(result: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not result.edges.has(from_cell):
		result.edges[from_cell] = {}
	result.edges[from_cell][to_cell] = true


func _remove_edge(result: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if result.edges.has(from_cell):
		result.edges[from_cell].erase(to_cell)


func _is_conductor(result: Dictionary, cell: Vector2i) -> bool:
	return result.conductors.has(cell)


func _is_base_cell(result: Dictionary, cell: Vector2i) -> bool:
	return result.state.players[int(result.player_index)].base == cell


func _get_top_unit_cells(state: Dictionary, player_index: int, name_key: String) -> Array:
	var cells: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _top_owner(state, cell) == player_index and _top_name_key(state, cell) == name_key:
				cells.append(cell)
	return cells


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
