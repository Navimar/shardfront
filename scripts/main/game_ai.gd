extends RefCounted

const AI_SCORE_EPSILON: float = 0.0001
const HAND_DISADVANTAGE_TEMPO_PENALTY: float = 1.2
const HAND_ADVANTAGE_TEMPO_BONUS: float = 0.2

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func choose_action_variant(state: Dictionary, player_index: int) -> Dictionary:
	var variants: Array = game._get_turn_variants_for_state(state, player_index)
	if variants.is_empty():
		return {}

	var best_variant: Dictionary = {}
	var best_score: float = -INF
	var best_tiebreak: float = -INF
	var has_best_variant: bool = false
	for variant in variants:
		var candidate_state: Dictionary = game._duplicate_game_state(state)
		var result: Dictionary = game._apply_action_variant_to_state(candidate_state, variant)
		if result.status != game.RESULT_OK:
			continue
		if _is_state_won_by_player(candidate_state, player_index):
			return variant
		var score: float = _score_candidate_state(candidate_state, result, player_index)
		var tiebreak: float = _score_variant_tiebreak(state, candidate_state, variant, player_index)
		if not has_best_variant or score > best_score + AI_SCORE_EPSILON or (abs(score - best_score) <= AI_SCORE_EPSILON and tiebreak > best_tiebreak):
			has_best_variant = true
			best_score = score
			best_tiebreak = tiebreak
			best_variant = variant
	return best_variant


func evaluate_win_tempo(state: Dictionary, player_index: int) -> float:
	var breakdown: Dictionary = get_tempo_breakdown(state, player_index)
	return float(breakdown.tempo)


func get_tempo_breakdown(state: Dictionary, player_index: int) -> Dictionary:
	if (
		int(state.current_player) == player_index
		and int(state.minor_actions_spent) == 0
		and _can_finish_with_hand_in_state(state, player_index)
	):
		return _make_tempo_breakdown(0.0, 0.0, 0.0, 0.0)

	var opponent_index: int = game._opponent(player_index)
	var target: Vector2i = state.players[opponent_index].base
	var path_result: Dictionary = _get_path_tempo_result(state, player_index, target, true)
	var path_cost: float = float(path_result.cost)
	if path_cost >= 99.0:
		return _make_tempo_breakdown(99.0, 99.0, 0.0, 0.0)

	var own_hand_size: int = _get_tempo_hand_size(state, player_index)
	var opponent_hand_size: int = _get_tempo_hand_size(state, opponent_index)
	var hand_delta: int = opponent_hand_size - own_hand_size
	var turn_penalty: int = 0
	if int(state.current_player) != player_index:
		turn_penalty = 1
	var hand_penalty: float = 0.0
	if hand_delta > 0:
		hand_penalty = float(hand_delta) * HAND_DISADVANTAGE_TEMPO_PENALTY
	elif hand_delta < 0:
		hand_penalty = float(hand_delta) * HAND_ADVANTAGE_TEMPO_BONUS
	var tempo: float = path_cost + hand_penalty + float(turn_penalty)
	return _make_tempo_breakdown(tempo, path_cost, hand_penalty, float(turn_penalty))


func get_min_path_actions_to_supply_enemy_base(state: Dictionary, player_index: int) -> float:
	var opponent_index: int = game._opponent(player_index)
	var target: Vector2i = state.players[opponent_index].base
	var result: Dictionary = _get_path_tempo_result(state, player_index, target, true)
	return float(result.cost)


func _score_candidate_state(state: Dictionary, result: Dictionary, player_index: int) -> float:
	var score: float = _score_tempo_race(state, player_index)
	if bool(result.get("end_turn", false)):
		return score
	if int(state.current_player) != player_index:
		return score
	if int(state.minor_actions_spent) <= 0:
		return score

	var opponent_index: int = game._opponent(player_index)
	if not _can_finish_with_hand_in_state(state, opponent_index):
		return score

	var projected_state: Dictionary = game._duplicate_game_state(state)
	projected_state.events = []
	game._apply_end_turn_rules_to_state(projected_state)
	return min(score, _score_tempo_race(projected_state, player_index))


func _score_variant_tiebreak(before_state: Dictionary, after_state: Dictionary, variant: Dictionary, player_index: int) -> float:
	var before_tempo: float = evaluate_win_tempo(before_state, player_index)
	var after_tempo: float = evaluate_win_tempo(after_state, player_index)
	var tempo_gain: float = before_tempo - after_tempo
	return tempo_gain * 100.0 + _get_action_tiebreak_priority(variant)


func _get_action_tiebreak_priority(variant: Dictionary) -> float:
	var action_type: String = String(variant.type)
	if action_type == game.ACTION_PLAY_HAND_CARD:
		return 30.0
	if action_type == game.ACTION_PLAY_DECK_FACE_DOWN:
		return 20.0
	if action_type == game.ACTION_DRAW_CARD:
		return 10.0
	return 0.0


func _score_tempo_race(state: Dictionary, player_index: int) -> float:
	var opponent_index: int = game._opponent(player_index)
	if bool(state.game_over):
		if _is_state_won_by_player(state, player_index):
			return INF
		return -INF

	var own_tempo: float = evaluate_win_tempo(state, player_index)
	var opponent_tempo: float = evaluate_win_tempo(state, opponent_index)
	if own_tempo <= 0.0 and opponent_tempo <= 0.0:
		return 0.0
	if own_tempo <= 0.0:
		return INF
	if opponent_tempo <= 0.0:
		return -INF
	return opponent_tempo - own_tempo


func _is_state_won_by_player(state: Dictionary, player_index: int) -> bool:
	if not bool(state.game_over):
		return false
	var message: String = String(state.game_over_message)
	return message.find(String(state.players[player_index].name)) != -1


func _make_tempo_breakdown(
	tempo: float,
	path_cost: float,
	hand_penalty: float,
	turn_penalty: float
) -> Dictionary:
	return {
		"tempo": tempo,
		"path_cost": path_cost,
		"hand_penalty": hand_penalty,
		"turn_penalty": turn_penalty
	}


func _get_tempo_hand_size(state: Dictionary, player_index: int) -> int:
	return min(state.players[player_index].hand.size(), game.MAX_HAND)


func _get_path_tempo_result(
	state: Dictionary,
	player_index: int,
	target: Vector2i,
	target_is_enemy_base: bool,
	override_cell: Vector2i = Vector2i(-1, -1),
	override_cost: float = -1.0
) -> Dictionary:
	return _get_path_tempo_result_from_start(
		state,
		player_index,
		state.players[player_index].base,
		target,
		target_is_enemy_base,
		override_cell,
		override_cost
	)


func _get_path_tempo_result_from_start(
	state: Dictionary,
	player_index: int,
	start: Vector2i,
	target: Vector2i,
	target_is_enemy_base: bool,
	override_cell: Vector2i = Vector2i(-1, -1),
	override_cost: float = -1.0
) -> Dictionary:
	var distances: Dictionary = _get_tempo_distance_map_from_start(
		state,
		player_index,
		start,
		target,
		target_is_enemy_base,
		override_cell,
		override_cost
	)
	var parents: Dictionary = distances.parents
	var costs: Dictionary = distances.costs
	if costs.has(target):
		return {
			"cost": float(costs[target]),
			"path": _build_tempo_path(target, parents)
		}
	return {
		"cost": 99.0,
		"path": []
	}


func _get_tempo_distance_map_from_start(
	state: Dictionary,
	player_index: int,
	start: Vector2i,
	target: Vector2i,
	target_is_enemy_base: bool,
	override_cell: Vector2i = Vector2i(-1, -1),
	override_cost: float = -1.0
) -> Dictionary:
	var distances = {}
	var parents = {}
	var unvisited: Array = []
	var supply_edges: Dictionary = game._get_supply_edges_in_state(state, player_index)
	var supply_origins: Dictionary = game._get_supply_origin_cells_in_state(state, player_index)
	var supplied_cells: Dictionary = game._get_supplied_cells_in_state(state, player_index)

	distances[start] = 0.0
	parents[start] = start
	unvisited.append(start)

	while not unvisited.is_empty():
		var current: Vector2i = _pop_lowest_tempo_cell(unvisited, distances)
		var current_cost: float = float(distances[current])
		var next_cells: Array = _get_tempo_next_cells(state, player_index, current, supply_edges, supply_origins, supplied_cells)
		for next in next_cells:

			var step_cost: float
			if target_is_enemy_base and next == target:
				step_cost = 0.0
			else:
				step_cost = _get_cell_supply_card_cost(state, player_index, next, override_cell, override_cost)

			var new_cost: float = current_cost + step_cost
			if not distances.has(next) or new_cost < float(distances[next]):
				distances[next] = new_cost
				parents[next] = current
				if not unvisited.has(next):
					unvisited.append(next)

	return {
		"costs": distances,
		"parents": parents
	}


func _get_tempo_next_cells(
	state: Dictionary,
	player_index: int,
	current: Vector2i,
	supply_edges: Dictionary,
	supply_origins: Dictionary,
	supplied_cells: Dictionary
) -> Array:
	if supply_origins.has(current):
		var edges: Dictionary = supply_edges.get(current, {})
		return edges.keys()
	if supplied_cells.has(current) and game._top_owner_in_state(state, current) == player_index:
		return []
	return _get_standard_tempo_next_cells(state, current)


func _get_standard_tempo_next_cells(state: Dictionary, current: Vector2i) -> Array:
	var cells: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = current + direction
		if not game._is_inside(next):
			continue
		if game._has_barrier_in_state(state, current, next):
			continue
		cells.append(next)
	return cells


func _build_tempo_path(target: Vector2i, parents: Dictionary) -> Array:
	if not parents.has(target):
		return []
	var path: Array = []
	var current: Vector2i = target
	while true:
		path.push_front(current)
		var parent: Vector2i = parents[current]
		if parent == current:
			break
		current = parent
	return path


func _pop_lowest_tempo_cell(cells: Array, distances: Dictionary) -> Vector2i:
	var best_array_index: int = 0
	var best_cell: Vector2i = cells[0]
	var best_distance: float = float(distances[best_cell])
	for i in range(1, cells.size()):
		var cell: Vector2i = cells[i]
		var distance: float = float(distances[cell])
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
			best_array_index = i
	cells.remove_at(best_array_index)
	return best_cell


func _get_cell_supply_card_cost(
	state: Dictionary,
	player_index: int,
	cell: Vector2i,
	override_cell: Vector2i = Vector2i(-1, -1),
	override_cost: float = -1.0
) -> float:
	if cell == override_cell and override_cost >= 0.0:
		return override_cost + _get_tempo_threat_penalty(state, player_index, cell)

	var owner: int = game._top_owner_in_state(state, cell)
	var base_cost: float
	if owner == player_index:
		base_cost = 0.0
	elif owner == -1:
		base_cost = 1.0
	elif game._top_face_down_in_state(state, cell):
		base_cost = 3.0
	else:
		var power: int = game._top_power_in_state(state, cell)
		base_cost = 2.0 + float(power)

	return base_cost + _get_tempo_threat_penalty(state, player_index, cell)


func _get_tempo_threat_penalty(state: Dictionary, player_index: int, cell: Vector2i) -> float:
	var owner: int = game._top_owner_in_state(state, cell)
	if owner != player_index and owner != -1:
		return 0.0
	if not _is_threatened_by_opponent_supply(state, player_index, cell):
		return 0.0

	var own_power: int = 0
	if owner == player_index and not game._top_face_down_in_state(state, cell):
		own_power = game._top_power_in_state(state, cell)
	return float(max(0, 5 - own_power))


func _is_threatened_by_opponent_supply(state: Dictionary, player_index: int, cell: Vector2i) -> bool:
	var opponent_index: int = game._opponent(player_index)
	var opponent_edges: Dictionary = game._get_supply_edges_in_state(state, opponent_index)
	var opponent_origins: Dictionary = game._get_supply_origin_cells_in_state(state, opponent_index)
	for origin in opponent_origins.keys():
		if game._top_owner_in_state(state, origin) != opponent_index:
			continue
		var edges: Dictionary = opponent_edges.get(origin, {})
		if edges.has(cell):
			return true
	return false


func _can_finish_with_hand_in_state(state: Dictionary, player_index: int) -> bool:
	var hand: Array = state.players[player_index].hand
	var target: Vector2i = state.players[game._opponent(player_index)].base
	for hand_index in range(hand.size()):
		var card: Dictionary = hand[hand_index].duplicate(true)
		card.face_down = false
		if game._can_play_card_in_state(state, card, target):
			return true
	return false
