extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")
var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func get_target_request(state: Dictionary, result: Dictionary) -> Dictionary:
	if not bool(result.get("played_card", false)):
		return {}
	var card: Dictionary = result.card
	if bool(card.face_down):
		return {}

	var name_key: String = String(card.unit.name_key)
	if name_key == UnitKeys.BOEVOY_MAG_NAME:
		return _get_request_if_available(state, result, "discard_adjacent_enemy", "cell")
	if name_key == UnitKeys.STROITEL_NAME:
		return _get_request_if_available(state, result, "add_barrier", "choice")
	if name_key == UnitKeys.KARTOGRAF_NAME:
		return _get_request_if_available(state, result, "move_barrier", "choice")
	if name_key == UnitKeys.BOLOTNIK_NAME:
		return _get_request_if_available(state, result, "move_barrier", "choice")
	if name_key == UnitKeys.KREPOST_NAME:
		return _get_request_if_available(state, result, "set_adjacent_barriers", "choice")
	return {}


func get_legal_target_cells(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "discard_adjacent_enemy":
		return _get_adjacent_enemy_target_cells(state, request)
	if _is_barrier_kind(kind):
		return _get_barrier_choice_cells(state, request)
	return []


func get_legal_target_choices(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "add_barrier":
		return _get_add_barrier_choices(state, false)
	if kind == "move_barrier":
		return _get_move_barrier_choices(state, false)
	if kind == "set_adjacent_barriers":
		return _get_set_adjacent_barrier_choices(state, request)
	return []


func get_ai_target_choices(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "add_barrier":
		return _get_add_barrier_choices(state, true)
	if kind == "move_barrier":
		return _get_move_barrier_choices(state, true)
	return get_legal_target_choices(state, request)


func get_legal_target_edges(state: Dictionary, request: Dictionary, selected_edge: Array = []) -> Array:
	var kind: String = String(request.get("kind", ""))
	var edges: Dictionary = {}
	for choice in get_legal_target_choices(state, request):
		if kind == "move_barrier":
			if selected_edge.is_empty():
				edges[_edge_key(choice.from_edge)] = choice.from_edge
			elif _edges_equal(choice.from_edge, selected_edge):
				edges[_edge_key(choice.to_edge)] = choice.to_edge
		else:
			for edge in _get_choice_edges(choice):
				if edge.is_empty():
					continue
				edges[_edge_key(edge)] = edge
	return edges.values()


func get_choice_for_edge_selection(state: Dictionary, request: Dictionary, edge: Array, selected_edge: Array = []) -> Dictionary:
	var kind: String = String(request.get("kind", ""))
	for choice in get_legal_target_choices(state, request):
		if kind == "move_barrier":
			if selected_edge.is_empty():
				if _edges_equal(choice.from_edge, edge):
					return {
						"select_edge": choice.from_edge
					}
			elif _edges_equal(choice.from_edge, selected_edge) and _edges_equal(choice.to_edge, edge):
				return choice
		elif kind == "set_adjacent_barriers":
			if _choice_contains_edge(choice, edge) and _get_choice_edges(choice).size() == 1:
				return choice
		elif _choice_contains_edge(choice, edge):
			return choice
	return {}


func is_repeating_choice_request(request: Dictionary) -> bool:
	return String(request.get("kind", "")) == "set_adjacent_barriers"


func apply_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_INVALID, "bad_target")
	var legal_targets: Array = get_legal_target_cells(state, request)
	if not legal_targets.has(target):
		return result

	var kind: String = String(request.get("kind", ""))
	if kind == "discard_adjacent_enemy":
		return _apply_discard_adjacent_enemy_target(state, target)
	if _is_barrier_kind(kind):
		var choice: Dictionary = _get_first_choice_for_cell(state, request, target)
		if choice.is_empty():
			return result
		return apply_choice(state, request, choice)
	return result


func apply_choice(state: Dictionary, request: Dictionary, choice: Dictionary, validate: bool = true) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_INVALID, "bad_target")
	if validate and not _has_choice(get_legal_target_choices(state, request), choice):
		return result

	var kind: String = String(request.get("kind", ""))
	if kind == "add_barrier":
		_add_barrier_to_state(state, choice.edge[0], choice.edge[1])
	elif kind == "move_barrier":
		_remove_barrier_from_state(state, choice.from_edge[0], choice.from_edge[1])
		_add_barrier_to_state(state, choice.to_edge[0], choice.to_edge[1])
	elif kind == "set_adjacent_barriers":
		for edge in choice.add_edges:
			_add_barrier_to_state(state, edge[0], edge[1])
		for edge in choice.remove_edges:
			_remove_barrier_from_state(state, edge[0], edge[1])
	else:
		return result

	result.status = game.RESULT_OK
	result.error = ""
	result.end_turn = true
	return result


func _get_request_if_available(state: Dictionary, result: Dictionary, kind: String, target_type: String) -> Dictionary:
	var request: Dictionary = {
		"kind": kind,
		"target_type": target_type,
		"player_index": int(result.card.owner),
		"source_cell": result.cell
	}
	if target_type == "choice" and get_legal_target_choices(state, request).is_empty():
		return {}
	if target_type == "cell" and get_legal_target_cells(state, request).is_empty():
		return {}
	return request


func _get_adjacent_enemy_target_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var player_index: int = int(request.player_index)
	var opponent_index: int = game._opponent(player_index)
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		if game._get_base_owner_in_state(state, cell) != -1:
			continue
		if game._top_owner_in_state(state, cell) != opponent_index:
			continue
		targets.append(cell)
	return targets


func _apply_discard_adjacent_enemy_target(state: Dictionary, target: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack.pop_back()
	var player_index: int = int(card.owner)
	game._discard_card_in_state(state, player_index, card, {
		"type": "board",
		"cell": target,
		"face_down": bool(card.face_down)
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _get_add_barrier_choices(state: Dictionary, only_opponent_edges: bool) -> Array:
	var choices: Array = []
	for edge in game._get_all_board_edges():
		if game._has_barrier_in_state(state, edge[0], edge[1]):
			continue
		if only_opponent_edges and not _edge_touches_opponent_card_or_base(state, edge):
			continue
		choices.append({
			"edge": edge
		})
	return choices


func _get_move_barrier_choices(state: Dictionary, only_opponent_edges: bool) -> Array:
	var choices: Array = []
	var add_choices: Array = _get_add_barrier_choices(state, only_opponent_edges)
	for from_edge in _get_barrier_edges(state):
		for add_choice in add_choices:
			choices.append({
				"from_edge": from_edge,
				"to_edge": add_choice.edge
			})
	return choices


func _edge_touches_opponent_card_or_base(state: Dictionary, edge: Array) -> bool:
	for cell in edge:
		if game._get_base_owner_in_state(state, cell) == game._opponent(int(state.current_player)):
			return true
		if game._top_owner_in_state(state, cell) == game._opponent(int(state.current_player)):
			return true
	return false


func _get_set_adjacent_barrier_choices(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var adjacent_edges: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = source_cell + direction
		if not game._is_inside(next):
			continue
		adjacent_edges.append([source_cell, next])

	var choices: Array = []
	var combination_count: int = int(pow(2.0, float(adjacent_edges.size())))
	for mask in range(combination_count):
		var add_edges: Array = []
		var remove_edges: Array = []
		for edge_index in range(adjacent_edges.size()):
			var edge: Array = adjacent_edges[edge_index]
			var should_have_barrier: bool = (mask & (1 << edge_index)) != 0
			var has_barrier: bool = game._has_barrier_in_state(state, edge[0], edge[1])
			if should_have_barrier and not has_barrier:
				add_edges.append(edge)
			elif not should_have_barrier and has_barrier:
				remove_edges.append(edge)
		choices.append({
			"add_edges": add_edges,
			"remove_edges": remove_edges
		})
	return choices


func _get_barrier_choice_cells(state: Dictionary, request: Dictionary) -> Array:
	var cells: Dictionary = {}
	for choice in get_legal_target_choices(state, request):
		for edge in _get_choice_edges(choice):
			cells[edge[0]] = true
			cells[edge[1]] = true
	return cells.keys()


func _get_first_choice_for_cell(state: Dictionary, request: Dictionary, cell: Vector2i) -> Dictionary:
	for choice in get_legal_target_choices(state, request):
		for edge in _get_choice_edges(choice):
			if edge[0] == cell or edge[1] == cell:
				return choice
	return {}


func _is_barrier_kind(kind: String) -> bool:
	return kind == "add_barrier" or kind == "move_barrier" or kind == "set_adjacent_barriers"


func _get_barrier_edges(state: Dictionary) -> Array:
	var edges: Array = []
	for edge in game._get_all_board_edges():
		if game._has_barrier_in_state(state, edge[0], edge[1]):
			edges.append(edge)
	return edges


func _get_choice_edges(choice: Dictionary) -> Array:
	var edges: Array = []
	if choice.has("edge"):
		edges.append(choice.edge)
	if choice.has("from_edge"):
		edges.append(choice.from_edge)
	if choice.has("to_edge"):
		edges.append(choice.to_edge)
	for edge in choice.get("add_edges", []):
		edges.append(edge)
	for edge in choice.get("remove_edges", []):
		edges.append(edge)
	return edges


func _choice_contains_edge(choice: Dictionary, edge: Array) -> bool:
	for choice_edge in _get_choice_edges(choice):
		if _edges_equal(choice_edge, edge):
			return true
	return false


func _edges_equal(first: Array, second: Array) -> bool:
	if first.size() != 2 or second.size() != 2:
		return false
	return game._edge_key(first[0], first[1]) == game._edge_key(second[0], second[1])


func _edge_key(edge: Array) -> String:
	if edge.size() != 2:
		return ""
	return game._edge_key(edge[0], edge[1])


func _has_choice(choices: Array, choice: Dictionary) -> bool:
	for candidate in choices:
		if var_to_str(candidate) == var_to_str(choice):
			return true
	return false


func _add_barrier_to_state(state: Dictionary, first: Vector2i, second: Vector2i) -> void:
	state.barriers[game._edge_key(first, second)] = true


func _remove_barrier_from_state(state: Dictionary, first: Vector2i, second: Vector2i) -> void:
	state.barriers.erase(game._edge_key(first, second))
