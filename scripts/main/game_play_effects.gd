extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func apply_played_card_effects(state: Dictionary, result: Dictionary) -> void:
	var card: Dictionary = result.card
	if bool(card.face_down):
		return
	_apply_played_card_effects_for_name(state, result, String(result.get("ability_name_key", String(card.unit.name_key))))


func apply_copied_card_play_effects(state: Dictionary, result: Dictionary, copied_card: Dictionary) -> void:
	if bool(copied_card.get("face_down", false)):
		return
	var copied_name: String = String(copied_card.unit.name_key)
	if not _can_copy_play_effect(copied_name):
		return
	result.card.attack_power_override = game.power_logic.get_card_attack_power(copied_card)
	result.ability_name_key = copied_name
	_apply_played_card_effects_for_name(state, result, copied_name)


func _apply_played_card_effects_for_name(state: Dictionary, result: Dictionary, name_key: String) -> void:
	var card: Dictionary = result.card
	var player_index: int = int(card.owner)
	var opponent_index: int = game._opponent(player_index)

	if name_key == UnitKeys.RYTSAR_NAME:
		game._draw_cards_in_state(state, player_index, 1)
	elif name_key == UnitKeys.ROBOT_NAME:
		_apply_robot_effect(state, result, player_index)
	elif name_key == UnitKeys.CHARODEY_NAME:
		_apply_attack_bonus_by_optional_hand_discard(state, result, player_index)
	elif name_key == UnitKeys.DIVERSANT_NAME:
		game.action_restriction_logic.add_next_turn_random_hand_play_restriction(state, opponent_index, result.cell)
	elif name_key == UnitKeys.GRIBNIK_NAME:
		game._draw_cards_in_state(state, player_index, 2)
	elif name_key == UnitKeys.ABBERATSIYA_NAME:
		game._draw_cards_in_state(state, opponent_index, 2)
	elif name_key == UnitKeys.DRAKON_NAME:
		if game._is_ai_player(player_index):
			_discard_cards_from_hand_end_in_state(state, player_index, 2)
		else:
			_set_pending_hand_discard_result(state, result, player_index, 2, [])
	elif name_key == UnitKeys.BARON_NAME:
		game._draw_cards_in_state(state, player_index, 2)
		if game._is_ai_player(player_index):
			_discard_cards_from_hand_end_in_state(state, player_index, 1)
		else:
			_set_pending_hand_discard_result(state, result, player_index, 1, [])
	elif name_key == UnitKeys.DROVOSEK_NAME:
		if game._is_ai_player(player_index):
			_draw_then_discard_drawn_cards_in_state(state, player_index, 3, 2)
		else:
			var drawn_ids: Array = game._draw_cards_in_state(state, player_index, 3)
			_set_pending_hand_discard_result(state, result, player_index, 2, drawn_ids)
	elif name_key == UnitKeys.DYMETS_NAME:
		game.action_restriction_logic.add_next_turn_restriction(state, opponent_index, "no_draw", result.cell)
	elif name_key == UnitKeys.KRYSA_NAME:
		if game._is_ai_player(opponent_index):
			_discard_cards_from_hand_end_in_state(state, opponent_index, 1)
		else:
			_set_pending_hand_discard_result(state, result, opponent_index, 1, [])
	elif name_key == UnitKeys.LATNIK_NAME:
		game.action_restriction_logic.add_next_turn_restriction(state, opponent_index, "no_latnik_cell", result.cell)
	elif name_key == UnitKeys.LEDENETS_NAME:
		game.action_restriction_logic.add_next_turn_restriction(state, opponent_index, "no_large_units", result.cell)
	elif name_key == UnitKeys.LUCHNIK_NAME:
		_discard_random_cards_from_hand_in_state(state, opponent_index, 1)
	elif name_key == UnitKeys.MOZGOSHMYG_NAME:
		_redraw_hand_in_state(state, opponent_index)
	elif name_key == UnitKeys.PARTIZANY_NAME:
		_apply_partizany_effect(state, player_index, opponent_index)
	elif name_key == UnitKeys.MELNIK_NAME:
		if game._is_ai_player(player_index):
			var discard_count: int = state.players[player_index].hand.size()
			_discard_cards_from_hand_end_in_state(state, player_index, discard_count)
			game._draw_cards_in_state(state, player_index, discard_count + 1)
		elif state.players[player_index].hand.is_empty():
			game._draw_cards_in_state(state, player_index, 1)
		else:
			_set_pending_hand_discard_result(state, result, player_index, state.players[player_index].hand.size(), [], {
				"optional": true,
				"draw_bonus": 1
			})
	elif name_key == UnitKeys.NALETCHIK_NAME:
		if not state.players[player_index].hand.is_empty():
			result.pending_extra_hand_play = {
				"player_index": player_index
			}
			result.end_turn = false
	elif name_key == UnitKeys.NEKROMANT_NAME:
		if not state.players[player_index].discard.is_empty():
			if game._is_ai_player(player_index):
				var necro_card: Dictionary = state.players[player_index].discard.pop_back()
				game._return_card_to_hand_in_state(state, player_index, necro_card, {
					"type": "discard"
				})
			else:
				result.pending_discard_pick = {
					"kind": "nekromant_return",
					"player_index": player_index,
					"card_id": int(result.card.id),
					"source_cell": result.cell
				}
				result.end_turn = false
	elif name_key == UnitKeys.VARVAR_NAME:
		_draw_until_power_at_least_in_state(state, player_index, 5)
	elif name_key == UnitKeys.BAYUN_NAME:
		_flip_all_top_units_face_down_in_state(state)
	elif name_key == UnitKeys.PUTNIK_NAME:
		var putnik_request: Dictionary = game.target_logic.get_direct_target_request(
			state,
			result,
			"play_deck_face_down_twice",
			"cell_sequence"
		)
		if not putnik_request.is_empty():
			result.pending_target = putnik_request
	elif name_key == UnitKeys.RANDOMAG_NAME:
		var randomag_request: Dictionary = game.target_logic.get_direct_target_request(
			state,
			result,
			"play_top_deck_open",
			"cell"
		)
		if not randomag_request.is_empty():
			result.pending_target = randomag_request
	elif name_key == UnitKeys.ZARAZA_NAME:
		_discard_enemy_units_that_lost_supply_in_state(state, result, opponent_index)
	elif name_key == UnitKeys.HLAMOVNIK_NAME:
		_apply_hlamovnik_effect(state, result, player_index)
	elif name_key == UnitKeys.STRATEG_NAME:
		_apply_strateg_effect(state, result, player_index)
	elif name_key == UnitKeys.SPOROVIK_NAME:
		_apply_sporovik_effect(state, player_index, opponent_index)
	elif name_key == UnitKeys.ZERKALNYY_GOLEM_NAME:
		_apply_zerkalnyy_golem_effect(state, result)


func _can_copy_play_effect(name_key: String) -> bool:
	return (
		name_key != UnitKeys.ROBOT_NAME
		and name_key != UnitKeys.HLAMOVNIK_NAME
		and name_key != UnitKeys.SLIZ_NAME
		and name_key != UnitKeys.ZERKALNYY_GOLEM_NAME
	)


func _flip_all_top_units_face_down_in_state(state: Dictionary) -> void:
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if bool(card.face_down):
				continue
			card.face_down = true
			game._record_layout_stack_event_in_state(state, cell)


func _discard_enemy_units_that_lost_supply_in_state(state: Dictionary, result: Dictionary, opponent_index: int) -> void:
	var before_supplied: Dictionary = Dictionary(result.get("opponent_supplied_before", {}))
	if before_supplied.is_empty():
		return
	var after_supplied: Dictionary = game._get_supplied_cells_in_state(state, opponent_index)
	for cell in before_supplied.keys():
		if after_supplied.has(cell):
			continue
		var stack: Array = game._get_stack_in_state(state, cell)
		if stack.is_empty():
			continue
		var card: Dictionary = stack[stack.size() - 1]
		if int(card.owner) != opponent_index:
			continue
		stack.pop_back()
		game._discard_card_in_state(state, opponent_index, card, {
			"type": "board",
			"cell": cell,
			"face_down": bool(card.face_down)
		})


func _apply_attack_bonus_by_optional_hand_discard(state: Dictionary, result: Dictionary, player_index: int) -> void:
	if state.players[player_index].hand.is_empty():
		return
	if game._is_ai_player(player_index):
		var hand: Array = state.players[player_index].hand
		var hand_index: int = hand.size() - 1
		var card: Dictionary = hand.pop_back()
		game._discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})
		result.card.attack_bonus = int(result.card.get("attack_bonus", 0)) + 10
	else:
		_set_pending_hand_discard_result(state, result, player_index, 1, [], {
			"optional": true,
			"attack_bonus": 10
		})


func _apply_robot_effect(state: Dictionary, result: Dictionary, player_index: int) -> void:
	var hand: Array = state.players[player_index].hand
	if hand.is_empty():
		return
	var copied_card: Dictionary = hand[0]
	apply_copied_card_play_effects(state, result, copied_card)


func _apply_hlamovnik_effect(state: Dictionary, result: Dictionary, player_index: int) -> void:
	var discard: Array = state.players[player_index].discard
	if discard.is_empty():
		return
	var copied_card: Dictionary = discard[discard.size() - 1]
	apply_copied_card_play_effects(state, result, copied_card)


func _apply_zerkalnyy_golem_effect(state: Dictionary, result: Dictionary) -> void:
	var cell: Vector2i = result.cell
	var stack: Array = game._get_stack_in_state(state, cell)
	var golem_index: int = game._find_card_index_in_array(stack, int(result.card.id))
	if golem_index <= 0:
		return
	var copied_card: Dictionary = stack[golem_index - 1]
	apply_copied_card_play_effects(state, result, copied_card)


func _apply_partizany_effect(state: Dictionary, player_index: int, opponent_index: int) -> void:
	var discarded_any: bool = false
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != opponent_index:
				continue
			if not bool(card.face_down):
				continue
			stack.pop_back()
			game._discard_card_in_state(state, opponent_index, card, {
				"type": "board",
				"cell": cell,
				"face_down": true
			})
			discarded_any = true
	if discarded_any:
		return
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != opponent_index:
				continue
			if bool(card.face_down):
				continue
			if game.power_logic.get_card_power_in_cell(state, card, cell) > 2:
				continue
			stack.pop_back()
			game._discard_card_in_state(state, opponent_index, card, {
				"type": "board",
				"cell": cell,
				"face_down": false
			})
			return


func _apply_strateg_effect(state: Dictionary, result: Dictionary, player_index: int) -> void:
	if game._is_ai_player(player_index):
		_apply_ai_strateg_effect(state, player_index)
		return
	var preview: Dictionary = _draw_strateg_preview_card(state, player_index)
	if preview.is_empty():
		return
	result.pending_strateg = {
		"player_index": player_index,
		"card_id": int(result.card.id),
		"source_cell": result.cell,
		"preview_card_id": int(preview.id),
		"checks": 1
	}
	result.end_turn = false


func _apply_ai_strateg_effect(state: Dictionary, player_index: int) -> void:
	var checks: int = 0
	while checks < 10:
		game._refill_deck_if_empty_in_state(state, player_index)
		var deck: Array = state.players[player_index].deck
		if deck.is_empty():
			return
		var card: Dictionary = deck.pop_back()
		checks += 1
		card.owner = player_index
		card.face_down = false
		if int(card.unit.power) >= 4 or checks >= 10:
			state.players[player_index].hand.append(card)
			game._record_draw_event_in_state(state, player_index, card)
			game._refill_deck_if_empty_in_state(state, player_index)
			return
		game._discard_card_in_state(state, player_index, card, {
			"type": "base"
		})
		game._refill_deck_if_empty_in_state(state, player_index)


func _draw_strateg_preview_card(state: Dictionary, player_index: int) -> Dictionary:
	game._refill_deck_if_empty_in_state(state, player_index)
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return {}
	var card: Dictionary = deck.pop_back()
	card.owner = player_index
	card.face_down = false
	state.players[player_index].hand.append(card)
	game._record_draw_event_in_state(state, player_index, card)
	game._refill_deck_if_empty_in_state(state, player_index)
	return card


func _apply_sporovik_effect(state: Dictionary, player_index: int, opponent_index: int) -> void:
	var own_count: int = 0
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.size() < 2:
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != player_index:
				continue
			stack.pop_back()
			game._discard_card_in_state(state, player_index, card, {
				"type": "board",
				"cell": cell,
				"face_down": bool(card.face_down)
			})
			own_count += 1
	var opponent_count: int = 0
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			if opponent_count >= own_count:
				return
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if stack.size() < 2:
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != opponent_index:
				continue
			stack.pop_back()
			game._discard_card_in_state(state, opponent_index, card, {
				"type": "board",
				"cell": cell,
				"face_down": bool(card.face_down)
			})
			opponent_count += 1


func _discard_cards_from_hand_end_in_state(state: Dictionary, player_index: int, count: int) -> void:
	var hand: Array = state.players[player_index].hand
	for i in range(count):
		if hand.is_empty():
			return
		var hand_index: int = hand.size() - 1
		var card: Dictionary = hand.pop_back()
		game._discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})


func _discard_random_cards_from_hand_in_state(state: Dictionary, player_index: int, count: int) -> void:
	var hand: Array = state.players[player_index].hand
	for i in range(count):
		if hand.is_empty():
			return
		var hand_index: int = randi_range(0, hand.size() - 1)
		var card: Dictionary = hand[hand_index]
		hand.remove_at(hand_index)
		game._discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})


func _set_pending_hand_discard_result(
	state: Dictionary,
	result: Dictionary,
	player_index: int,
	count: int,
	allowed_card_ids: Array,
	options: Dictionary = {}
) -> void:
	var hand: Array = state.players[player_index].hand
	var discard_count: int = min(count, game._count_discardable_hand_cards(hand, allowed_card_ids))
	if discard_count <= 0:
		return
	result.pending_hand_discard = {
		"player_index": player_index,
		"count": discard_count,
		"allowed_card_ids": allowed_card_ids.duplicate(),
		"optional": bool(options.get("optional", false)),
		"draw_bonus": int(options.get("draw_bonus", 0)),
		"attack_bonus": int(options.get("attack_bonus", 0))
	}
	if result.has("card") and result.has("cell"):
		result.pending_hand_discard.card_id = int(result.card.id)
		result.pending_hand_discard.source_cell = result.cell
	result.end_turn = false


func _draw_then_discard_drawn_cards_in_state(state: Dictionary, player_index: int, draw_count: int, discard_count: int) -> void:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	var drawn_cards: Array = []
	for i in range(draw_count):
		game._refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			break
		drawn_cards.append(deck.pop_back())
	game._refill_deck_if_empty_in_state(state, player_index)

	while drawn_cards.size() > 0 and discard_count > 0:
		var discarded_card: Dictionary = drawn_cards.pop_back()
		game._discard_card_in_state(state, player_index, discarded_card, {
			"type": "base"
		})
		discard_count -= 1

	for card in drawn_cards:
		card.owner = player_index
		card.face_down = false
		hand.append(card)
		game._record_draw_event_in_state(state, player_index, card)


func _redraw_hand_in_state(state: Dictionary, player_index: int) -> void:
	var hand: Array = state.players[player_index].hand
	var card_count: int = hand.size()
	while not hand.is_empty():
		var hand_index: int = hand.size() - 1
		var card: Dictionary = hand.pop_back()
		game._discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})
	game._draw_cards_in_state(state, player_index, card_count)


func _draw_until_power_at_least_in_state(state: Dictionary, player_index: int, minimum_power: int) -> void:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	var checked_count: int = 0
	var max_checks: int = state.players[player_index].deck_template.size()
	while checked_count < max_checks:
		game._refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			return
		var card: Dictionary = deck.pop_back()
		checked_count += 1
		if int(card.unit.power) >= minimum_power:
			card.owner = player_index
			card.face_down = false
			hand.append(card)
			game._record_draw_event_in_state(state, player_index, card)
			game._refill_deck_if_empty_in_state(state, player_index)
			return
		game._discard_card_in_state(state, player_index, card, {
			"type": "base"
		})
	game._refill_deck_if_empty_in_state(state, player_index)
