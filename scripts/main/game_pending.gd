extends RefCounted

var game: Node
var action: String = ""
var hand_discard_player: int = -1
var hand_discard_count: int = 0
var hand_discard_allowed_ids: Array = []
var hand_discard_card_id: int = -1
var hand_discard_source_cell: Vector2i = Vector2i(-1, -1)
var target_request: Dictionary = {}
var selected_target_edge: Array = []


func _init(game_node: Node) -> void:
	game = game_node


func clear() -> void:
	action = ""
	game.ui_selected_hand_card_id = -1
	hand_discard_player = -1
	hand_discard_count = 0
	hand_discard_allowed_ids.clear()
	hand_discard_card_id = -1
	hand_discard_source_cell = Vector2i(-1, -1)
	target_request.clear()
	selected_target_edge.clear()


func begin_target(request: Dictionary) -> void:
	action = "target"
	game.ui_selected_hand_card_id = -1
	target_request = request.duplicate(true)
	selected_target_edge.clear()


func begin_hand_discard(discard_info: Dictionary) -> void:
	action = "hand_discard"
	game.ui_selected_hand_card_id = -1
	hand_discard_player = int(discard_info.player_index)
	hand_discard_count = int(discard_info.count)
	hand_discard_allowed_ids = Array(discard_info.get("allowed_card_ids", [])).duplicate()
	hand_discard_card_id = int(discard_info.get("card_id", -1))
	hand_discard_source_cell = discard_info.get("source_cell", Vector2i(-1, -1))


func is_hand_card_inactive(card: Dictionary) -> bool:
	var view_player: int = game._get_view_player()
	if action == "hand_discard":
		if hand_discard_player != view_player:
			return false
		return not can_discard_hand_card(int(card.id))
	if game.current_player != view_player:
		return false
	if not game.action_restriction_logic.can_select_hand_card(game._get_live_game_state(), game.current_player, card):
		return true
	return game.minor_actions_spent > 0


func get_target_cells() -> Array:
	if is_choice_target():
		return []
	return game.target_logic.get_legal_target_cells(game._get_live_game_state(), target_request)


func get_target_edges() -> Array:
	if not is_choice_target():
		return []
	return game.target_logic.get_legal_target_edges(game._get_live_game_state(), target_request, selected_target_edge)


func is_choice_target() -> bool:
	return String(target_request.get("target_type", "cell")) == "choice"


func is_repeating_choice_target() -> bool:
	return game.target_logic.is_repeating_choice_request(target_request)


func can_finish_choice_target() -> bool:
	return game.target_logic.can_finish_choice_request(target_request)


func can_discard_hand_card(card_id: int) -> bool:
	if action != "hand_discard":
		return false
	if hand_discard_allowed_ids.is_empty():
		return true
	return hand_discard_allowed_ids.has(card_id)


func try_apply_target(cell: Vector2i) -> void:
	if action != "target":
		return
	if is_choice_target():
		return
	if int(target_request.get("player_index", -1)) != game.current_player:
		return
	var result: Dictionary = _apply_target_to_current_state(target_request, cell)
	if result.status != game.RESULT_OK:
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	if result.has("pending_target"):
		begin_target(result.pending_target)
	else:
		clear()
	game._sync_after_state_change_without_card_layout()


func try_apply_target_edge(edge: Array) -> void:
	if action != "target":
		return
	if not is_choice_target():
		return
	if int(target_request.get("player_index", -1)) != game.current_player:
		return
	var choice: Dictionary = game.target_logic.get_choice_for_edge_selection(
		game._get_live_game_state(),
		target_request,
		edge,
		selected_target_edge
	)
	if choice.is_empty():
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return
	if choice.has("select_edge"):
		selected_target_edge = Array(choice.select_edge).duplicate()
		game._sync_after_state_change_without_card_layout()
		return

	var should_finish: bool = not is_repeating_choice_target()
	var result: Dictionary = _apply_choice_to_current_state(target_request, choice, should_finish)
	if result.status != game.RESULT_OK:
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	if result.has("pending_target"):
		begin_target(result.pending_target)
	elif should_finish:
		clear()
	game._sync_after_state_change_without_card_layout()


func finish_repeating_target() -> void:
	if action != "target":
		return
	if not can_finish_choice_target():
		return
	var result: Dictionary = _finish_target_turn_in_current_state()
	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	clear()
	game._sync_after_state_change_without_card_layout()


func try_discard_hand_card(card_id: int) -> void:
	if action != "hand_discard":
		return
	if hand_discard_player != game._get_view_player():
		return
	if not can_discard_hand_card(card_id):
		return
	var hand: Array = game.players[hand_discard_player].hand
	var hand_index: int = game._find_card_index_in_array(hand, card_id)
	if hand_index < 0:
		return

	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var card: Dictionary = hand[hand_index]
	hand.remove_at(hand_index)
	game._discard_card_in_state(state, hand_discard_player, card, {
		"type": "hand",
		"hand_index": hand_index
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.events = state.events
	hand_discard_count -= 1
	hand_discard_allowed_ids.erase(card_id)
	if hand_discard_count <= 0 or game._count_discardable_hand_cards(hand, hand_discard_allowed_ids) <= 0:
		_apply_source_play_reactions_to_result(state, {
			"card_id": hand_discard_card_id,
			"source_cell": hand_discard_source_cell
		}, result)
	result.events = state.events

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false

	if hand_discard_count <= 0 or game._count_discardable_hand_cards(hand, hand_discard_allowed_ids) <= 0:
		clear()
		game._end_turn()
	game._sync_after_state_change_without_card_layout()


func _apply_target_to_current_state(request: Dictionary, target: Vector2i) -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_target(state, request, target)
	if result.status == game.RESULT_OK and not result.has("pending_target"):
		_apply_source_play_reactions_to_result(state, request, result)
		game._apply_end_turn_rules_to_state(state, result)
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _apply_choice_to_current_state(request: Dictionary, choice: Dictionary, finish_turn: bool = true) -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_choice(state, request, choice)
	if result.status == game.RESULT_OK:
		_apply_source_play_reactions_to_result(state, request, result)
	if result.status == game.RESULT_OK and finish_turn:
		game._apply_end_turn_rules_to_state(state, result)
	if result.status == game.RESULT_OK:
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
		if not result.has("pending_target"):
			result.end_turn = finish_turn
	result.events = state.events
	game._restore_game_state(state)
	return result


func _apply_source_play_reactions_to_result(state: Dictionary, request: Dictionary, result: Dictionary) -> void:
	if result.has("pending_target"):
		return
	if not request.has("card_id"):
		return
	var source_cell: Vector2i = request.source_cell
	if int(request.card_id) < 0 or not game._is_inside(source_cell):
		return
	var source_card: Dictionary = game._find_card_by_id_in_array(
		game._get_stack_in_state(state, source_cell),
		int(request.card_id)
	)
	if source_card.is_empty():
		return
	result.played_card = true
	result.card = source_card
	result.cell = source_cell
	game._apply_stack_reactions_after_play_to_state(state, result)


func _finish_target_turn_in_current_state() -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	game.target_logic.finish_choice(state, target_request)
	_apply_source_play_reactions_to_result(state, target_request, result)
	game._apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	game._restore_game_state(state)
	return result
