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
	if name_key == UnitKeys.FOKUSNIK_NAME:
		return _get_sequence_request_if_available(state, result, "swap_own_enemy_top", [])
	if name_key == UnitKeys.GUSENITSA_NAME:
		return _get_sequence_request_if_available(state, result, "swap_same_side_top", [])
	if name_key == UnitKeys.SHAR_NAME:
		return _get_sequence_request_if_available(state, result, "move_own_top_anywhere", [])
	if name_key == UnitKeys.VSADNIK_NAME:
		return _get_sequence_request_if_available(state, result, "move_adjacent_top_to_neighbor", [])
	if name_key == UnitKeys.PRIMANKA_NAME:
		return _get_sequence_request_if_available(state, result, "primanka_pull", [])
	if name_key == UnitKeys.VIHR_NAME:
		return _get_sequence_request_if_available(state, result, "vihr_swap_neighbors", [])
	if name_key == UnitKeys.LICH_NAME:
		return _get_sequence_request_if_available(state, result, "lich_flip_own", [])
	if name_key == UnitKeys.TRUBADUR_NAME:
		return _get_sequence_request_if_available(state, result, "trubadur_return_own", [])
	if name_key == UnitKeys.AGITATOR_NAME:
		return _get_request_if_available(state, result, "flip_own_face_down_up", "cell")
	if name_key == UnitKeys.ALHIMIK_NAME:
		return _get_request_if_available(state, result, "swap_adjacent_stack_cards", "cell")
	if name_key == UnitKeys.AVTOPOEZD_NAME:
		if state.players[int(result.card.owner)].hand.is_empty():
			return {}
		return _get_request_if_available(state, result, "avtopoezd_replace_source", "cell")
	if name_key == UnitKeys.BOEVOY_MAG_NAME:
		return _get_request_if_available(state, result, "discard_adjacent_enemy", "cell")
	if name_key == UnitKeys.DUH_BURI_NAME:
		return _get_request_if_available_for_player(
			state,
			result,
			"flip_own_top_down",
			"cell",
			game._opponent(int(result.card.owner))
		)
	if name_key == UnitKeys.DEMON_NAME:
		return _get_request_if_available(state, result, "discard_own_open", "cell")
	if name_key == UnitKeys.EVAKUATOR_NAME:
		return _get_request_if_available(state, result, "evacuate_own", "cell")
	if name_key == UnitKeys.MEDBRAT_NAME:
		return _get_request_if_available(state, result, "return_own_any", "cell")
	if name_key == UnitKeys.LESHIY_NAME:
		return _get_request_if_available(state, result, "discard_unsupplied_enemy", "cell")
	if name_key == UnitKeys.PUGALO_NAME:
		return _get_request_if_available(state, result, "return_adjacent_top", "cell")
	if name_key == UnitKeys.PRIZYVATEL_NAME:
		return _get_request_if_available(state, result, "put_adjacent_deck_face_down", "cell")
	if name_key == UnitKeys.SVETLYACHOK_NAME:
		return _get_request_if_available(state, result, "flip_supplied_own_down", "cell")
	if name_key == UnitKeys.STROITEL_NAME:
		return _get_request_if_available(state, result, "add_barrier", "choice")
	if name_key == UnitKeys.KARTOGRAF_NAME:
		return _get_request_if_available(state, result, "move_barrier", "choice")
	if name_key == UnitKeys.KOCHEVNIKI_NAME:
		return _get_request_if_available(state, result, "move_own_base_anywhere", "cell")
	if name_key == UnitKeys.BOLOTNIK_NAME:
		return _get_request_if_available(state, result, "bolotnik_move_barrier", "choice")
	if name_key == UnitKeys.KREPOST_NAME:
		return _get_request_if_available(state, result, "set_adjacent_barriers", "choice")
	if name_key == UnitKeys.SHAMAN_NAME:
		return _get_request_if_available(state, result, "shaman_base_move", "cell")
	return {}


func get_legal_target_cells(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "swap_own_enemy_top":
		return _get_swap_own_enemy_top_cells(state, request)
	if kind == "swap_same_side_top":
		return _get_swap_same_side_top_cells(state, request)
	if kind == "move_own_top_anywhere":
		return _get_move_own_top_anywhere_cells(state, request)
	if kind == "move_adjacent_top_to_neighbor":
		return _get_move_adjacent_top_to_neighbor_cells(state, request)
	if kind == "primanka_pull":
		return _get_primanka_pull_cells(state, request)
	if kind == "vihr_swap_neighbors":
		return _get_vihr_swap_neighbor_cells(state, request)
	if kind == "lich_flip_own":
		return _get_own_face_up_top_cells(state, int(request.player_index))
	if kind == "trubadur_return_own":
		return _get_trubadur_return_cells(state, request)
	if kind == "flip_own_face_down_up":
		return _get_own_face_down_top_cells(state, request)
	if kind == "swap_adjacent_stack_cards":
		return _get_adjacent_two_card_stack_cells(state, request)
	if kind == "avtopoezd_replace_source":
		return _get_top_cells_for_owner(state, int(request.player_index))
	if kind == "flip_own_top_down":
		return _get_own_face_up_top_cells(state, int(request.player_index))
	if kind == "discard_adjacent_enemy":
		return _get_adjacent_enemy_target_cells(state, request)
	if kind == "discard_own_open":
		return _get_own_open_top_cells(state, request)
	if kind == "evacuate_own":
		return _get_evacuator_target_cells(state, request)
	if kind == "return_own_any":
		return _get_any_own_card_cells(state, request)
	if kind == "discard_unsupplied_enemy":
		return _get_unsupplied_enemy_top_cells(state, request)
	if kind == "return_adjacent_top":
		return _get_adjacent_top_unit_cells(state, request)
	if kind == "put_adjacent_deck_face_down":
		return _get_adjacent_put_deck_face_down_cells(state, request)
	if kind == "play_deck_face_down_twice":
		return _get_deck_face_down_play_cells(state, request)
	if kind == "play_top_deck_open":
		return _get_top_deck_open_play_cells(state, request)
	if kind == "move_taran_to_neighbor":
		return _get_taran_move_destination_cells(state, request)
	if kind == "move_own_base_anywhere":
		return _get_move_own_base_anywhere_cells(state, request)
	if kind == "shaman_base_move":
		return _get_shaman_base_move_cells(state, request)
	if kind == "flip_supplied_own_down":
		return _get_supplied_own_top_cells(state, request)
	if _is_barrier_kind(kind):
		return _get_barrier_choice_cells(state, request)
	return []


func get_legal_target_choices(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "add_barrier":
		return _get_add_barrier_choices(state, false)
	if kind == "move_barrier":
		return _get_move_barrier_choices(state, false)
	if kind == "bolotnik_move_barrier":
		return _get_move_barrier_choices(state, false)
	if kind == "set_adjacent_barriers":
		return _get_set_adjacent_barrier_choices(state, request)
	if kind == "optional_remove_barrier":
		return _get_optional_remove_barrier_choices(state, request)
	return []


func get_ai_target_choices(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "add_barrier":
		return _get_add_barrier_choices(state, true)
	if kind == "move_barrier":
		return _get_move_barrier_choices(state, true)
	if kind == "bolotnik_move_barrier":
		return _get_move_barrier_choices(state, true)
	return get_legal_target_choices(state, request)


func get_legal_target_edges(state: Dictionary, request: Dictionary, selected_edge: Array = []) -> Array:
	var kind: String = String(request.get("kind", ""))
	var edges: Dictionary = {}
	for choice in get_legal_target_choices(state, request):
		if kind == "move_barrier" or kind == "bolotnik_move_barrier":
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
		if kind == "move_barrier" or kind == "bolotnik_move_barrier":
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
	var kind: String = String(request.get("kind", ""))
	return (
		kind == "set_adjacent_barriers"
		or kind == "primanka_pull"
		or kind == "vihr_swap_neighbors"
		or kind == "lich_flip_own"
		or kind == "trubadur_return_own"
	)


func can_finish_choice_request(request: Dictionary) -> bool:
	var kind: String = String(request.get("kind", ""))
	return (
		kind == "set_adjacent_barriers"
		or kind == "optional_remove_barrier"
		or kind == "swap_adjacent_stack_cards"
		or kind == "primanka_pull"
		or kind == "vihr_swap_neighbors"
		or kind == "lich_flip_own"
		or kind == "trubadur_return_own"
	)


func get_end_turn_target_request(state: Dictionary) -> Dictionary:
	var option: Dictionary = _get_barrier_removal_option_for_player(state, int(state.current_player))
	if option.is_empty():
		return {}
	var edge: Array = Array(option.edge)
	if edge.size() != 2 or not game._has_barrier_in_state(state, edge[0], edge[1]):
		_remove_barrier_removal_option(state, int(state.current_player), edge)
		return {}
	return {
		"kind": "optional_remove_barrier",
		"target_type": "choice",
		"player_index": int(state.current_player),
		"edge": edge.duplicate()
	}


func apply_ai_end_turn_choice(state: Dictionary, request: Dictionary) -> void:
	var choices: Array = get_legal_target_choices(state, request)
	if not choices.is_empty():
		apply_choice(state, request, choices[0])
	else:
		finish_choice(state, request)


func finish_choice(state: Dictionary, request: Dictionary) -> void:
	var kind: String = String(request.get("kind", ""))
	if kind == "optional_remove_barrier":
		_remove_barrier_removal_options_for_player(state, int(request.player_index))
	elif kind == "lich_flip_own":
		var count: int = int(request.get("count", 0))
		if count > 0:
			game._draw_cards_in_state(state, int(request.player_index), count)


func apply_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_INVALID, "bad_target")
	var legal_targets: Array = get_legal_target_cells(state, request)
	if not legal_targets.has(target):
		return result

	var kind: String = String(request.get("kind", ""))
	if kind == "swap_own_enemy_top":
		return _apply_swap_own_enemy_top_target(state, request, target)
	if kind == "swap_same_side_top":
		return _apply_swap_same_side_top_target(state, request, target)
	if kind == "move_own_top_anywhere":
		return _apply_move_own_top_anywhere_target(state, request, target)
	if kind == "move_adjacent_top_to_neighbor":
		return _apply_move_adjacent_top_to_neighbor_target(state, request, target)
	if kind == "primanka_pull":
		return _apply_primanka_pull_target(state, request, target)
	if kind == "vihr_swap_neighbors":
		return _apply_vihr_swap_neighbor_target(state, request, target)
	if kind == "lich_flip_own":
		return _apply_lich_flip_own_target(state, request, target)
	if kind == "trubadur_return_own":
		return _apply_trubadur_return_own_target(state, request, target)
	if kind == "flip_own_face_down_up":
		return _apply_flip_top_card_target(state, target, false)
	if kind == "swap_adjacent_stack_cards":
		return _apply_swap_adjacent_stack_cards_target(state, target)
	if kind == "avtopoezd_replace_source":
		return _apply_avtopoezd_source_target(state, request, target)
	if kind == "flip_own_top_down":
		return _apply_flip_top_card_target(state, target, true)
	if kind == "discard_adjacent_enemy":
		return _apply_discard_adjacent_enemy_target(state, target)
	if kind == "discard_own_open" or kind == "discard_unsupplied_enemy":
		return _apply_discard_top_target(state, target)
	if kind == "evacuate_own":
		return _apply_evacuator_target(state, request, target)
	if kind == "return_own_any":
		return _apply_return_own_any_target(state, request, target)
	if kind == "return_adjacent_top":
		return _apply_return_top_target(state, target)
	if kind == "put_adjacent_deck_face_down":
		return _apply_put_adjacent_deck_face_down_target(state, request, target)
	if kind == "play_deck_face_down_twice":
		return _apply_play_deck_face_down_sequence_target(state, request, target)
	if kind == "play_top_deck_open":
		return _apply_play_top_deck_open_target(state, request, target)
	if kind == "move_taran_to_neighbor":
		return _apply_move_taran_to_neighbor_target(state, request, target)
	if kind == "move_own_base_anywhere":
		return _apply_move_own_base_anywhere_target(state, request, target)
	if kind == "shaman_base_move":
		return _apply_shaman_base_move_target(state, request, target)
	if kind == "flip_supplied_own_down":
		return _apply_flip_top_card_target(state, target, true)
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
	elif kind == "move_barrier" or kind == "bolotnik_move_barrier":
		_remove_barrier_from_state(state, choice.from_edge[0], choice.from_edge[1])
		_add_barrier_to_state(state, choice.to_edge[0], choice.to_edge[1])
		if kind == "bolotnik_move_barrier":
			_add_barrier_removal_option(state, game._opponent(int(request.player_index)), choice.to_edge)
	elif kind == "set_adjacent_barriers":
		for edge in choice.add_edges:
			_add_barrier_to_state(state, edge[0], edge[1])
		for edge in choice.remove_edges:
			_remove_barrier_from_state(state, edge[0], edge[1])
	elif kind == "optional_remove_barrier":
		_remove_barrier_from_state(state, choice.edge[0], choice.edge[1])
		_remove_barrier_removal_options_for_player(state, int(request.player_index))
	else:
		return result

	result.status = game.RESULT_OK
	result.error = ""
	result.end_turn = true
	return result


func _get_request_if_available(state: Dictionary, result: Dictionary, kind: String, target_type: String) -> Dictionary:
	return _get_request_if_available_for_player(state, result, kind, target_type, int(result.card.owner))


func _get_request_if_available_for_player(
	state: Dictionary,
	result: Dictionary,
	kind: String,
	target_type: String,
	player_index: int
) -> Dictionary:
	var request: Dictionary = {
		"kind": kind,
		"target_type": target_type,
		"player_index": player_index,
		"source_cell": result.cell,
		"card_id": int(result.card.id)
	}
	if target_type == "choice" and get_legal_target_choices(state, request).is_empty():
		return {}
	if target_type == "cell" and get_legal_target_cells(state, request).is_empty():
		return {}
	if target_type == "cell_sequence" and get_legal_target_cells(state, request).is_empty():
		return {}
	return request


func get_direct_target_request(state: Dictionary, result: Dictionary, kind: String, target_type: String) -> Dictionary:
	return _get_request_if_available(state, result, kind, target_type)


func _get_sequence_request_if_available(state: Dictionary, result: Dictionary, kind: String, selected_cells: Array) -> Dictionary:
	var request: Dictionary = {
		"kind": kind,
		"target_type": "cell_sequence",
		"player_index": int(result.card.owner),
		"source_cell": result.cell,
		"card_id": int(result.card.id),
		"selected_cells": selected_cells.duplicate()
	}
	if get_legal_target_cells(state, request).is_empty():
		return {}
	return request


func _make_pending_sequence_result(request: Dictionary, selected_cells: Array) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	var next_request: Dictionary = request.duplicate(true)
	next_request.selected_cells = selected_cells.duplicate()
	result.end_turn = false
	result.pending_target = next_request
	return result


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


func _get_adjacent_two_card_stack_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		var stack: Array = game._get_stack_in_state(state, cell)
		if stack.size() >= 2:
			targets.append(cell)
	return targets


func _get_own_face_down_top_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._top_owner_in_state(state, cell) != player_index:
				continue
			if not game._top_face_down_in_state(state, cell):
				continue
			targets.append(cell)
	return targets


func _get_own_open_top_cells(state: Dictionary, request: Dictionary) -> Array:
	return _get_own_face_up_top_cells(state, int(request.player_index))


func _get_own_face_up_top_cells(state: Dictionary, player_index: int) -> Array:
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._top_owner_in_state(state, cell) != player_index:
				continue
			if game._top_face_down_in_state(state, cell):
				continue
			targets.append(cell)
	return targets


func _get_evacuator_target_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	if state.players[player_index].deck.is_empty() and state.players[player_index].deck_template.is_empty():
		return []
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._top_owner_in_state(state, cell) == player_index:
				targets.append(cell)
	return targets


func _get_any_own_card_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _find_topmost_card_index_for_owner(state, cell, player_index) >= 0:
				targets.append(cell)
	return targets


func _get_unsupplied_enemy_top_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var opponent_index: int = game._opponent(player_index)
	var supplied_cells: Dictionary = game._get_supplied_cells_in_state(state, opponent_index)
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._top_owner_in_state(state, cell) != opponent_index:
				continue
			if supplied_cells.has(cell):
				continue
			targets.append(cell)
	return targets


func _get_supplied_own_top_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var supplied_cells: Dictionary = game._get_supplied_cells_in_state(state, player_index)
	var targets: Array = []
	for cell in supplied_cells.keys():
		if game._top_owner_in_state(state, cell) != player_index:
			continue
		targets.append(cell)
	return targets


func _get_adjacent_top_unit_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		if game._get_base_owner_in_state(state, cell) != -1:
			continue
		if game._get_stack_in_state(state, cell).is_empty():
			continue
		targets.append(cell)
	return targets


func _get_adjacent_put_deck_face_down_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var player_index: int = int(request.player_index)
	if state.players[player_index].deck.is_empty() and state.players[player_index].deck_template.is_empty():
		return []
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		var base_owner: int = game._get_base_owner_in_state(state, cell)
		if base_owner == player_index:
			continue
		targets.append(cell)
	return targets


func _get_deck_face_down_play_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	if state.players[player_index].deck.is_empty() and state.players[player_index].deck_template.is_empty():
		return []
	var targets: Array = []
	var card: Dictionary = _get_deck_preview_card(state, player_index, true)
	if card.is_empty():
		return targets
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._can_play_card_in_state(state, card, cell):
				targets.append(cell)
	return targets


func _get_top_deck_open_play_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	if state.players[player_index].deck.is_empty() and state.players[player_index].deck_template.is_empty():
		return []
	var targets: Array = []
	var card: Dictionary = _get_deck_preview_card(state, player_index, false)
	if card.is_empty():
		return targets
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._can_play_card_in_state(state, card, cell):
				targets.append(cell)
	return targets


func _get_taran_move_destination_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var owner: int = int(request.player_index)
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		if game._get_base_owner_in_state(state, cell) == owner:
			continue
		targets.append(cell)
	return targets


func _get_move_own_base_anywhere_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var own_base: Vector2i = state.players[player_index].base
	var opponent_base: Vector2i = state.players[game._opponent(player_index)].base
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == own_base or cell == opponent_base:
				continue
			targets.append(cell)
	return targets


func _get_shaman_base_move_cells(state: Dictionary, request: Dictionary) -> Array:
	var player_index: int = int(request.player_index)
	var own_base: Vector2i = state.players[player_index].base
	var opponent_base: Vector2i = state.players[game._opponent(player_index)].base
	var targets: Array = [opponent_base]
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = own_base + direction
		if not game._is_inside(cell):
			continue
		if cell == opponent_base:
			continue
		if game._has_barrier_in_state(state, own_base, cell):
			continue
		targets.append(cell)
	return targets


func _get_swap_own_enemy_top_cells(state: Dictionary, request: Dictionary) -> Array:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	var player_index: int = int(request.player_index)
	if selected_cells.is_empty():
		return _get_top_cells_for_owner(state, player_index)
	return _get_top_cells_for_owner(state, game._opponent(player_index), selected_cells[0])


func _get_swap_same_side_top_cells(state: Dictionary, request: Dictionary) -> Array:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	var player_index: int = int(request.player_index)
	if selected_cells.is_empty():
		var targets: Array = _get_top_cells_for_owner(state, player_index)
		targets.append_array(_get_top_cells_for_owner(state, game._opponent(player_index)))
		return targets
	var first_cell: Vector2i = selected_cells[0]
	var owner: int = game._top_owner_in_state(state, first_cell)
	return _get_top_cells_for_owner(state, owner, first_cell)


func _get_move_own_top_anywhere_cells(state: Dictionary, request: Dictionary) -> Array:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	var player_index: int = int(request.player_index)
	if selected_cells.is_empty():
		return _get_top_cells_for_owner(state, player_index)
	return _get_move_destination_cells(state, player_index, selected_cells[0], false)


func _get_move_adjacent_top_to_neighbor_cells(state: Dictionary, request: Dictionary) -> Array:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	var source_cell: Vector2i = request.source_cell
	if selected_cells.is_empty():
		var targets: Array = []
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var cell: Vector2i = source_cell + direction
			if not game._is_inside(cell):
				continue
			if game._has_barrier_in_state(state, source_cell, cell):
				continue
			if game._get_base_owner_in_state(state, cell) != -1:
				continue
			if game._get_stack_in_state(state, cell).is_empty():
				continue
			targets.append(cell)
		return targets
	var first_cell: Vector2i = selected_cells[0]
	return _get_unrestricted_move_destination_cells(state, first_cell, true)


func _get_primanka_pull_cells(state: Dictionary, request: Dictionary) -> Array:
	var source_cell: Vector2i = request.source_cell
	var opponent_index: int = game._opponent(int(request.player_index))
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		if game._top_owner_in_state(state, cell) != opponent_index:
			continue
		targets.append(cell)
	return targets


func _get_vihr_swap_neighbor_cells(state: Dictionary, request: Dictionary) -> Array:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	var source_cell: Vector2i = request.source_cell
	var excluded_cell: Vector2i = Vector2i(-1, -1)
	if not selected_cells.is_empty():
		excluded_cell = selected_cells[0]
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = source_cell + direction
		if cell == excluded_cell:
			continue
		if not game._is_inside(cell):
			continue
		if game._has_barrier_in_state(state, source_cell, cell):
			continue
		if game._get_stack_in_state(state, cell).is_empty():
			continue
		targets.append(cell)
	return targets


func _get_trubadur_return_cells(state: Dictionary, request: Dictionary) -> Array:
	var targets: Array = []
	var player_index: int = int(request.player_index)
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == request.source_cell:
				continue
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var top_card: Dictionary = stack[stack.size() - 1]
			if int(top_card.owner) != player_index:
				continue
			targets.append(cell)
	return targets


func _get_top_cells_for_owner(state: Dictionary, owner: int, excluded_cell: Vector2i = Vector2i(-1, -1)) -> Array:
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == excluded_cell:
				continue
			if game._top_owner_in_state(state, cell) != owner:
				continue
			targets.append(cell)
	return targets


func _get_move_destination_cells(state: Dictionary, owner: int, source_cell: Vector2i, only_adjacent: bool) -> Array:
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == source_cell:
				continue
			if only_adjacent and not _are_unblocked_neighbors(state, source_cell, cell):
				continue
			var base_owner: int = game._get_base_owner_in_state(state, cell)
			if base_owner == owner:
				continue
			var stack: Array = game._get_stack_in_state(state, cell)
			if not stack.is_empty() and game._top_owner_in_state(state, cell) != owner:
				continue
			targets.append(cell)
	return targets


func _get_unrestricted_move_destination_cells(state: Dictionary, source_cell: Vector2i, only_adjacent: bool) -> Array:
	var targets: Array = []
	var owner: int = game._top_owner_in_state(state, source_cell)
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == source_cell:
				continue
			if only_adjacent and not _are_unblocked_neighbors(state, source_cell, cell):
				continue
			var base_owner: int = game._get_base_owner_in_state(state, cell)
			if base_owner == owner:
				continue
			targets.append(cell)
	return targets


func _get_deck_preview_card(state: Dictionary, player_index: int, face_down: bool) -> Dictionary:
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return {}
	var card: Dictionary = deck[deck.size() - 1].duplicate(true)
	card.owner = player_index
	card.face_down = face_down
	return card


func _find_topmost_card_index_for_owner(state: Dictionary, cell: Vector2i, owner: int) -> int:
	var stack: Array = game._get_stack_in_state(state, cell)
	for index in range(stack.size() - 1, -1, -1):
		if int(stack[index].owner) == owner:
			return index
	return -1


func _are_unblocked_neighbors(state: Dictionary, first: Vector2i, second: Vector2i) -> bool:
	var diff: Vector2i = first - second
	if abs(diff.x) + abs(diff.y) != 1:
		return false
	return not game._has_barrier_in_state(state, first, second)


func _apply_discard_adjacent_enemy_target(state: Dictionary, target: Vector2i) -> Dictionary:
	return _apply_discard_top_target(state, target)


func _apply_swap_adjacent_stack_cards_target(state: Dictionary, target: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.size() < 2:
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	var top_index: int = stack.size() - 1
	var second_index: int = stack.size() - 2
	var top_card: Dictionary = stack[top_index]
	stack[top_index] = stack[second_index]
	stack[second_index] = top_card
	game._record_layout_stack_event_in_state(state, target)
	return _make_ok_target_result()


func _apply_avtopoezd_source_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	var hand: Array = state.players[player_index].hand
	if hand.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_hand")
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	if game._is_ai_player(player_index):
		_apply_avtopoezd_replace_with_hand_index(state, player_index, target, 0)
		result.end_turn = true
	else:
		result.pending_hand_pick = {
			"kind": "avtopoezd_replace",
			"player_index": player_index,
			"source_cell": target,
			"card_id": int(request.card_id)
		}
		result.end_turn = false
	return result


func apply_hand_pick(state: Dictionary, request: Dictionary, hand_index: int) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_INVALID, "bad_hand_index")
	var player_index: int = int(request.player_index)
	var hand: Array = state.players[player_index].hand
	if hand_index < 0 or hand_index >= hand.size():
		return result
	var kind: String = String(request.get("kind", ""))
	if kind == "avtopoezd_replace":
		_apply_avtopoezd_replace_with_hand_index(state, player_index, request.source_cell, hand_index)
	else:
		return result
	result.status = game.RESULT_OK
	result.error = ""
	result.end_turn = true
	return result


func _apply_avtopoezd_replace_with_hand_index(
	state: Dictionary,
	player_index: int,
	cell: Vector2i,
	hand_index: int
) -> void:
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.is_empty():
		return
	var old_card: Dictionary = stack.pop_back()
	game._return_card_to_hand_in_state(state, player_index, old_card, {
		"type": "board",
		"cell": cell,
		"face_down": bool(old_card.face_down)
	})
	var hand: Array = state.players[player_index].hand
	var new_card: Dictionary = hand[hand_index]
	hand.remove_at(hand_index)
	new_card.owner = player_index
	new_card.face_down = false
	stack.append(new_card)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(new_card.id),
		"player_index": player_index,
		"unit": new_card.unit,
		"cell": cell,
		"face_down": false,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, cell),
		"source": {
			"type": "hand",
			"hand_index": hand_index
		}
	})
	game._record_layout_stack_event_in_state(state, cell)


func _apply_swap_own_enemy_top_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	if selected_cells.is_empty():
		return _make_pending_sequence_result(request, [target])
	_swap_top_cards(state, selected_cells[0], target)
	return _make_ok_target_result()


func _apply_swap_same_side_top_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	if selected_cells.is_empty():
		return _make_pending_sequence_result(request, [target])
	_swap_top_cards(state, selected_cells[0], target)
	return _make_ok_target_result()


func _apply_move_own_top_anywhere_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	if selected_cells.is_empty():
		return _make_pending_sequence_result(request, [target])
	_move_top_card(state, selected_cells[0], target)
	return _make_ok_target_result()


func _apply_move_adjacent_top_to_neighbor_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	if selected_cells.is_empty():
		if _get_unrestricted_move_destination_cells(state, target, true).is_empty():
			return game._make_action_result(game.RESULT_INVALID, "bad_target")
		return _make_pending_sequence_result(request, [target])
	_move_top_card(state, selected_cells[0], target)
	return _make_ok_target_result()


func _apply_primanka_pull_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var source_cell: Vector2i = request.source_cell
	var source_stack: Array = game._get_stack_in_state(state, source_cell)
	var target_stack: Array = game._get_stack_in_state(state, target)
	if source_stack.is_empty() or target_stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var pulled_card: Dictionary = target_stack.pop_back()
	var primanka_index: int = source_stack.size() - 1
	source_stack.insert(primanka_index, pulled_card)
	game._record_layout_stack_event_in_state(state, target)
	game._record_layout_stack_event_in_state(state, source_cell)
	return _make_pending_sequence_result(request, [])


func _apply_vihr_swap_neighbor_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var selected_cells: Array = Array(request.get("selected_cells", []))
	if selected_cells.is_empty():
		return _make_pending_sequence_result(request, [target])
	_swap_stacks(state, selected_cells[0], target)
	return _make_pending_sequence_result(request, [])


func _apply_lich_flip_own_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack[stack.size() - 1]
	var was_face_down: bool = bool(card.face_down)
	card.face_down = true
	game._record_layout_stack_event_in_state(state, target)
	var next_request: Dictionary = request.duplicate(true)
	if was_face_down:
		next_request.count = int(request.get("count", 0))
	else:
		next_request.count = int(request.get("count", 0)) + 1
	return _make_pending_sequence_result(next_request, [])


func _apply_trubadur_return_own_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack.pop_back()
	game._return_card_to_hand_in_state(state, int(card.owner), card, {
		"type": "board",
		"cell": target,
		"face_down": bool(card.face_down)
	})
	return _make_pending_sequence_result(request, [])


func _swap_top_cards(state: Dictionary, first_cell: Vector2i, second_cell: Vector2i) -> void:
	var first_stack: Array = game._get_stack_in_state(state, first_cell)
	var second_stack: Array = game._get_stack_in_state(state, second_cell)
	var first_card: Dictionary = first_stack.pop_back()
	var second_card: Dictionary = second_stack.pop_back()
	first_stack.append(second_card)
	second_stack.append(first_card)
	game._record_layout_stack_event_in_state(state, first_cell)
	game._record_layout_stack_event_in_state(state, second_cell)


func _swap_stacks(state: Dictionary, first_cell: Vector2i, second_cell: Vector2i) -> void:
	var first_stack: Array = game._get_stack_in_state(state, first_cell)
	var second_stack: Array = game._get_stack_in_state(state, second_cell)
	state.board[first_cell.y][first_cell.x] = second_stack
	state.board[second_cell.y][second_cell.x] = first_stack
	game._record_layout_stack_event_in_state(state, first_cell)
	game._record_layout_stack_event_in_state(state, second_cell)


func _move_top_card(state: Dictionary, source_cell: Vector2i, target_cell: Vector2i) -> void:
	var source_stack: Array = game._get_stack_in_state(state, source_cell)
	var target_stack: Array = game._get_stack_in_state(state, target_cell)
	var card: Dictionary = source_stack.pop_back()
	target_stack.append(card)
	game._record_layout_stack_event_in_state(state, source_cell)
	game._record_layout_stack_event_in_state(state, target_cell)


func _make_ok_target_result() -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_discard_top_target(state: Dictionary, target: Vector2i) -> Dictionary:
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


func _apply_flip_top_card_target(state: Dictionary, target: Vector2i, face_down: bool) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack[stack.size() - 1]
	card.face_down = face_down
	game._record_layout_stack_event_in_state(state, target)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_return_top_target(state: Dictionary, target: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack.pop_back()
	var player_index: int = int(card.owner)
	game._return_card_to_hand_in_state(state, player_index, card, {
		"type": "board",
		"cell": target,
		"face_down": bool(card.face_down)
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_return_own_any_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	var stack: Array = game._get_stack_in_state(state, target)
	var card_index: int = _find_topmost_card_index_for_owner(state, target, player_index)
	if card_index < 0:
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = stack[card_index]
	stack.remove_at(card_index)
	game._return_card_to_hand_in_state(state, player_index, card, {
		"type": "board",
		"cell": target,
		"face_down": bool(card.face_down)
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_evacuator_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	var stack: Array = game._get_stack_in_state(state, target)
	if stack.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	if not game._refill_deck_if_empty_in_state(state, player_index):
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")

	var returned_card: Dictionary = stack.pop_back()
	game._return_card_to_hand_in_state(state, int(returned_card.owner), returned_card, {
		"type": "board",
		"cell": target,
		"face_down": bool(returned_card.face_down)
	})

	var replacement_card: Dictionary = deck.pop_back()
	replacement_card.owner = player_index
	replacement_card.face_down = true
	stack.append(replacement_card)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(replacement_card.id),
		"player_index": player_index,
		"unit": replacement_card.unit,
		"cell": target,
		"face_down": true,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, target),
		"source": {
			"type": "base",
			"face_down": true
		}
	})
	game._record_layout_stack_event_in_state(state, target)
	game._refill_deck_if_empty_in_state(state, player_index)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_play_deck_face_down_sequence_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	var played_count: int = int(request.get("played_count", 0))
	var result: Dictionary = _play_top_deck_card_to_cell(state, player_index, target, true)
	if result.status != game.RESULT_OK:
		return result
	played_count += 1
	if played_count >= 2:
		result.end_turn = true
		return result
	var next_request: Dictionary = request.duplicate(true)
	next_request.played_count = played_count
	if get_legal_target_cells(state, next_request).is_empty():
		result.end_turn = true
		return result
	result.end_turn = false
	result.pending_target = next_request
	return result


func _apply_play_top_deck_open_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	return _play_top_deck_card_to_cell(state, int(request.player_index), target, false)


func _apply_move_taran_to_neighbor_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var source_cell: Vector2i = request.source_cell
	var source_stack: Array = game._get_stack_in_state(state, source_cell)
	var card_index: int = game._find_card_index_in_array(source_stack, int(request.card_id))
	if card_index < 0:
		return game._make_action_result(game.RESULT_INVALID, "empty_target")
	var card: Dictionary = source_stack[card_index]
	source_stack.remove_at(card_index)
	game._get_stack_in_state(state, target).append(card)
	game._record_layout_stack_event_in_state(state, source_cell)
	game._record_layout_stack_event_in_state(state, target)
	_remove_adjacent_barriers_from_state(state, target)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_move_own_base_anywhere_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	_discard_stack_at_cell(state, target)
	state.players[player_index].base = target
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_shaman_base_move_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	var opponent_index: int = game._opponent(player_index)
	var own_base: Vector2i = state.players[player_index].base
	if target == state.players[opponent_index].base:
		state.players[player_index].base = state.players[opponent_index].base
		state.players[opponent_index].base = own_base
	else:
		_discard_stack_at_cell(state, target)
		state.players[player_index].base = target
		_place_top_deck_face_down_without_legality(state, player_index, own_base)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _discard_stack_at_cell(state: Dictionary, cell: Vector2i) -> void:
	var stack: Array = game._get_stack_in_state(state, cell)
	while not stack.is_empty():
		var card: Dictionary = stack.pop_back()
		game._discard_card_in_state(state, int(card.owner), card, {
			"type": "board",
			"cell": cell,
			"face_down": bool(card.face_down)
		})


func _place_top_deck_face_down_without_legality(state: Dictionary, player_index: int, target: Vector2i) -> void:
	if not game._refill_deck_if_empty_in_state(state, player_index):
		return
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return
	var card: Dictionary = deck.pop_back()
	card.owner = player_index
	card.face_down = true
	game._place_card_in_state(state, card, target)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"cell": target,
		"face_down": true,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, target),
		"source": {
			"type": "base",
			"face_down": true
		}
	})
	game._record_layout_stack_event_in_state(state, target)
	game._refill_deck_if_empty_in_state(state, player_index)


func _play_top_deck_card_to_cell(state: Dictionary, player_index: int, target: Vector2i, face_down: bool) -> Dictionary:
	if not game._refill_deck_if_empty_in_state(state, player_index):
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")
	var preview_card: Dictionary = deck[deck.size() - 1]
	preview_card.owner = player_index
	preview_card.face_down = face_down
	if not game._can_play_card_in_state(state, preview_card, target):
		return game._make_action_result(game.RESULT_INVALID, "cannot_play_card")
	var card: Dictionary = deck.pop_back()
	card.owner = player_index
	card.face_down = face_down
	game._place_card_in_state(state, card, target)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"cell": target,
		"face_down": face_down,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, target),
		"source": {
			"type": "base",
			"face_down": face_down
		}
	})
	game._record_layout_stack_event_in_state(state, target)
	game._refill_deck_if_empty_in_state(state, player_index)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.card = card
	result.cell = target
	result.played_card = true
	result.end_turn = true
	game._apply_after_action_rules_to_state(state, result)
	if not game._result_has_pending_action(result):
		game._apply_stack_reactions_after_play_to_state(state, result)
	return result


func _apply_put_adjacent_deck_face_down_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var player_index: int = int(request.player_index)
	if not game._refill_deck_if_empty_in_state(state, player_index):
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "empty_deck")
	var card: Dictionary = deck.pop_back()
	card.owner = player_index
	card.face_down = true
	game._get_stack_in_state(state, target).append(card)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"cell": target,
		"face_down": true,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, target),
		"source": {
			"type": "base",
			"face_down": true
		}
	})
	game._record_layout_stack_event_in_state(state, target)
	game._refill_deck_if_empty_in_state(state, player_index)
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
		if not _barrier_choice_keeps_bases_connected(state, [edge], []):
			continue
		choices.append({
			"edge": edge
		})
	return choices


func _get_move_barrier_choices(state: Dictionary, only_opponent_edges: bool) -> Array:
	var choices: Array = []
	for from_edge in _get_barrier_edges(state):
		for to_edge in game._get_all_board_edges():
			if game._has_barrier_in_state(state, to_edge[0], to_edge[1]):
				continue
			if only_opponent_edges and not _edge_touches_opponent_card_or_base(state, to_edge):
				continue
			if not _barrier_choice_keeps_bases_connected(state, [to_edge], [from_edge]):
				continue
			choices.append({
				"from_edge": from_edge,
				"to_edge": to_edge
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
		if not _barrier_choice_keeps_bases_connected(state, add_edges, remove_edges):
			continue
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
	return (
		kind == "add_barrier"
		or kind == "move_barrier"
		or kind == "bolotnik_move_barrier"
		or kind == "set_adjacent_barriers"
		or kind == "optional_remove_barrier"
	)


func _get_barrier_edges(state: Dictionary) -> Array:
	var edges: Array = []
	for edge in game._get_all_board_edges():
		if game._has_barrier_in_state(state, edge[0], edge[1]):
			edges.append(edge)
	return edges


func _get_optional_remove_barrier_choices(state: Dictionary, request: Dictionary) -> Array:
	var edge: Array = Array(request.get("edge", []))
	if edge.size() != 2:
		return []
	if not game._has_barrier_in_state(state, edge[0], edge[1]):
		return []
	return [{
		"edge": edge
	}]


func _barrier_choice_keeps_bases_connected(state: Dictionary, add_edges: Array, remove_edges: Array) -> bool:
	var preview_state: Dictionary = game._duplicate_game_state(state)
	for edge in remove_edges:
		_remove_barrier_from_state(preview_state, edge[0], edge[1])
	for edge in add_edges:
		_add_barrier_to_state(preview_state, edge[0], edge[1])
	return game._bases_are_connected_in_state(preview_state)


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


func _remove_adjacent_barriers_from_state(state: Dictionary, cell: Vector2i) -> void:
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = cell + direction
		if not game._is_inside(neighbor):
			continue
		_remove_barrier_from_state(state, cell, neighbor)


func _add_barrier_removal_option(state: Dictionary, player_index: int, edge: Array) -> void:
	if not state.has("barrier_removal_options"):
		state.barrier_removal_options = []
	_remove_barrier_removal_options_for_player(state, player_index)
	state.barrier_removal_options.append({
		"player_index": player_index,
		"edge": Array(edge).duplicate()
	})


func _get_barrier_removal_option_for_player(state: Dictionary, player_index: int) -> Dictionary:
	if not state.has("barrier_removal_options"):
		return {}
	for option in state.barrier_removal_options:
		if int(option.get("player_index", -1)) == player_index:
			return option
	return {}


func _remove_barrier_removal_option(state: Dictionary, player_index: int, edge: Array) -> void:
	if not state.has("barrier_removal_options"):
		return
	var kept: Array = []
	for option in state.barrier_removal_options:
		if int(option.get("player_index", -1)) == player_index and _edges_equal(Array(option.get("edge", [])), edge):
			continue
		kept.append(option)
	state.barrier_removal_options = kept


func _remove_barrier_removal_options_for_player(state: Dictionary, player_index: int) -> void:
	if not state.has("barrier_removal_options"):
		return
	var kept: Array = []
	for option in state.barrier_removal_options:
		if int(option.get("player_index", -1)) == player_index:
			continue
		kept.append(option)
	state.barrier_removal_options = kept
