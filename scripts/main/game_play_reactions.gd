extends RefCounted

const CardAbilities: Script = preload("res://scripts/main/card_abilities.gd")
const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func apply_played_card_reactions(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return
	_apply_cherepaha_play_rule(state, result)
	_remove_barriers_adjacent_to_all_taran(state)


func apply_covered_card_reactions(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return
	var cell: Vector2i = result.cell
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.size() < 2:
		return
	var covering_card: Dictionary = stack[stack.size() - 1]
	var played_card: Dictionary = result.card
	if int(covering_card.id) != int(played_card.id):
		return
	var covered_card: Dictionary = stack[stack.size() - 2]
	var covering_name: String = String(result.get("ability_name_key", String(covering_card.unit.name_key)))
	if covering_name == UnitKeys.ENT_NAME:
		_return_covered_card_to_hand(state, cell, stack, covered_card)
		return
	if bool(covered_card.face_down):
		return

	var covered_name: String = CardAbilities.name_key(covered_card)
	if covered_name == UnitKeys.TARAN_NAME and int(covered_card.owner) == int(covering_card.owner):
		_remove_barriers_adjacent_to_cell(state, cell)
		var destinations: Array = _get_taran_destination_cells(state, cell, int(covered_card.owner))
		if destinations.is_empty():
			return
		if game._is_ai_player(int(covered_card.owner)):
			_move_taran_to_first_destination(state, cell, covered_card)
		else:
			result.pending_target = {
				"kind": "move_taran_to_neighbor",
				"target_type": "cell",
				"player_index": int(covered_card.owner),
				"source_player": int(covering_card.owner),
				"decision_player": int(covered_card.owner),
				"source_cell": cell,
				"card_id": int(covered_card.id)
			}
			result.end_turn = false
	elif covered_name == UnitKeys.VOLK_NAME:
		covered_card.attack_power_override = int(covering_card.get("copied_power", covering_card.unit.power))
		var volk_request: Dictionary = {
			"kind": "replay_volk",
			"target_type": "cell",
			"player_index": int(covered_card.owner),
			"source_player": int(covering_card.owner),
			"decision_player": int(covered_card.owner),
			"source_cell": cell,
			"card_id": int(covered_card.id)
		}
		var volk_destinations: Array = game.target_logic.get_legal_target_cells(state, volk_request)
		if volk_destinations.is_empty():
			return
		if game._is_ai_player(int(covered_card.owner)):
			game.target_logic.apply_target(state, volk_request, volk_destinations[0])
		else:
			result.pending_target = volk_request
			result.end_turn = false
	elif covered_name == UnitKeys.MINA_NAME:
		covered_card.face_down = true
		_discard_covering_card(state, result, cell, stack, covering_card)
	elif covered_name == UnitKeys.MAKOVOE_POLE_NAME and int(covering_card.get("copied_power", covering_card.unit.power)) >= 3:
		_discard_covering_card(state, result, cell, stack, covering_card)
	elif covered_name == UnitKeys.PAUK_NAME and int(covered_card.owner) != int(covering_card.owner):
		covering_card.face_down = true
		game._record_layout_stack_event_in_state(state, cell)


func _discard_covering_card(
	state: Dictionary,
	result: Dictionary,
	cell: Vector2i,
	stack: Array,
	covering_card: Dictionary
) -> void:
	stack.pop_back()
	result.played_card_removed = true
	game._discard_card_in_state(state, int(covering_card.owner), covering_card, {
		"type": "board",
		"cell": cell,
		"face_down": bool(covering_card.face_down)
	})


func _return_covered_card_to_hand(state: Dictionary, cell: Vector2i, stack: Array, covered_card: Dictionary) -> void:
	var covered_index: int = game._find_card_index_in_array(stack, int(covered_card.id))
	if covered_index < 0:
		return
	stack.remove_at(covered_index)
	game._return_card_to_hand_in_state(state, int(covered_card.owner), covered_card, {
		"type": "board",
		"cell": cell,
		"face_down": bool(covered_card.face_down)
	})


func _apply_cherepaha_play_rule(state: Dictionary, result: Dictionary) -> void:
	var card: Dictionary = result.card
	if bool(card.face_down):
		return
	if String(result.get("ability_name_key", String(card.unit.name_key))) != UnitKeys.CHEREPAHA_NAME:
		return

	var player_index: int = int(card.owner)
	if not game._refill_deck_if_empty_in_state(state, player_index):
		return
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return

	var tucked_card: Dictionary = deck.pop_back()
	tucked_card.owner = player_index
	tucked_card.face_down = true
	game._refill_deck_if_empty_in_state(state, player_index)

	var cell: Vector2i = result.cell
	var stack: Array = game._get_stack_in_state(state, cell)
	var card_index: int = game._find_card_index_in_array(stack, int(card.id))
	if card_index < 0:
		return
	stack.insert(card_index, tucked_card)
	game._record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(tucked_card.id),
		"player_index": player_index,
		"unit": tucked_card.unit,
		"cell": cell,
		"face_down": true,
		"stack_cards": game._get_stack_card_snapshots_in_state(state, cell),
		"source": {
			"type": "base",
			"face_down": true
		}
	})
	game._record_layout_stack_event_in_state(state, cell)


func _remove_barriers_adjacent_to_all_taran(state: Dictionary) -> void:
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if bool(card.face_down):
				continue
			if CardAbilities.active_name_key(state, cell) != UnitKeys.TARAN_NAME:
				continue
			_remove_barriers_adjacent_to_cell(state, cell)


func _remove_barriers_adjacent_to_cell(state: Dictionary, cell: Vector2i) -> void:
	for neighbor in game._get_board_neighbors(cell):
		game._remove_barrier_from_state(state, cell, neighbor)


func _move_taran_to_first_destination(state: Dictionary, source_cell: Vector2i, card: Dictionary) -> void:
	var destinations: Array = _get_taran_destination_cells(state, source_cell, int(card.owner))
	for target in destinations:
		var source_stack: Array = game._get_stack_in_state(state, source_cell)
		var card_index: int = game._find_card_index_in_array(source_stack, int(card.id))
		if card_index < 0:
			return
		source_stack.remove_at(card_index)
		game._get_stack_in_state(state, target).append(card)
		game._record_layout_stack_event_in_state(state, source_cell)
		game._record_layout_stack_event_in_state(state, target)
		_remove_barriers_adjacent_to_cell(state, target)
		return


func _get_taran_destination_cells(state: Dictionary, source_cell: Vector2i, owner: int) -> Array:
	var targets: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target: Vector2i = source_cell + direction
		if not game._is_inside(target):
			continue
		if game._has_barrier_in_state(state, source_cell, target):
			continue
		if game._get_base_owner_in_state(state, target) == owner:
			continue
		targets.append(target)
	return targets
