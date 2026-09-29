extends RefCounted

var game: Node
var action: String = ""
var hand_discard_player: int = -1
var hand_discard_count: int = 0
var hand_discard_done: int = 0
var hand_discard_allowed_ids: Array = []
var hand_discard_card_id: int = -1
var hand_discard_source_cell: Vector2i = Vector2i(-1, -1)
var hand_discard_optional: bool = false
var hand_discard_draw_bonus: int = 0
var hand_discard_attack_bonus: int = 0
var hand_discard_ability_name_key: String = ""
var hand_discard_copied_card_id: int = -1
var hand_discard_kind: String = ""
var hand_pick_request: Dictionary = {}
var discard_pick_request: Dictionary = {}
var strateg_request: Dictionary = {}
var extra_hand_play_request: Dictionary = {}
var target_request: Dictionary = {}
var selected_target_edge: Array = []
var robot_card_id: int = -1
var robot_copy_card_id: int = -1


func _init(game_node: Node) -> void:
	game = game_node


func clear() -> void:
	action = ""
	game.ui_selected_hand_card_id = -1
	hand_discard_player = -1
	hand_discard_count = 0
	hand_discard_done = 0
	hand_discard_allowed_ids.clear()
	hand_discard_card_id = -1
	hand_discard_source_cell = Vector2i(-1, -1)
	hand_discard_optional = false
	hand_discard_draw_bonus = 0
	hand_discard_attack_bonus = 0
	hand_discard_ability_name_key = ""
	hand_discard_copied_card_id = -1
	hand_discard_kind = ""
	hand_pick_request.clear()
	discard_pick_request.clear()
	strateg_request.clear()
	extra_hand_play_request.clear()
	target_request.clear()
	selected_target_edge.clear()
	robot_card_id = -1
	robot_copy_card_id = -1


func begin_target(request: Dictionary) -> void:
	action = "target"
	game.ui_selected_hand_card_id = -1
	target_request = request.duplicate(true)
	if not target_request.has("decision_player"):
		target_request.decision_player = int(target_request.get("player_index", -1))
	if not target_request.has("source_player"):
		target_request.source_player = int(target_request.get("player_index", -1))
	selected_target_edge.clear()
	if String(target_request.get("target_type", "")) == "option":
		game.tabletop_logic.show_options(target_request)


func begin_hand_discard(discard_info: Dictionary) -> void:
	action = "hand_discard"
	game.ui_selected_hand_card_id = -1
	hand_discard_player = int(discard_info.player_index)
	hand_discard_count = int(discard_info.count)
	hand_discard_done = 0
	hand_discard_allowed_ids = Array(discard_info.get("allowed_card_ids", [])).duplicate()
	hand_discard_card_id = int(discard_info.get("card_id", -1))
	hand_discard_source_cell = discard_info.get("source_cell", Vector2i(-1, -1))
	hand_discard_optional = bool(discard_info.get("optional", false))
	hand_discard_draw_bonus = int(discard_info.get("draw_bonus", 0))
	hand_discard_attack_bonus = int(discard_info.get("attack_bonus", 0))
	hand_discard_ability_name_key = String(discard_info.get("ability_name_key", ""))
	hand_discard_copied_card_id = int(discard_info.get("copied_card_id", -1))
	hand_discard_kind = String(discard_info.get("kind", ""))


func begin_hand_pick(request: Dictionary) -> void:
	action = "hand_pick"
	game.ui_selected_hand_card_id = -1
	hand_pick_request = request.duplicate(true)


func begin_discard_pick(request: Dictionary) -> void:
	action = "discard_pick"
	game.ui_selected_hand_card_id = -1
	discard_pick_request = request.duplicate(true)
	game._refresh_discard_dialog(int(request.player_index))
	game.discard_dialog.popup_centered()


func begin_strateg(request: Dictionary) -> void:
	action = "strateg"
	game.ui_selected_hand_card_id = int(request.get("preview_card_id", -1))
	strateg_request = request.duplicate(true)


func begin_extra_hand_play(request: Dictionary) -> void:
	action = "hand"
	hand_pick_request.clear()
	discard_pick_request.clear()
	strateg_request.clear()
	target_request.clear()
	selected_target_edge.clear()
	extra_hand_play_request = request.duplicate(true)
	robot_card_id = -1
	robot_copy_card_id = -1
	game.ui_selected_hand_card_id = int(extra_hand_play_request.get("forced_card_id", -1))
	var forced_card_id: int = game.ui_selected_hand_card_id
	if forced_card_id >= 0:
		var player_index: int = int(extra_hand_play_request.get("player_index", -1))
		var hand: Array = game.players[player_index].hand
		var hand_index: int = game._find_card_index_in_array(hand, forced_card_id)
		if (
			hand_index >= 0
			and game._is_robot_card(hand[hand_index])
			and not game._get_robot_copy_cards_in_hand(hand, forced_card_id).is_empty()
		):
			begin_robot_copy(forced_card_id)


func begin_robot_copy(card_id: int) -> void:
	action = "robot_copy"
	robot_card_id = card_id
	robot_copy_card_id = -1
	game.ui_selected_hand_card_id = card_id


func try_select_robot_copy_card(card_id: int) -> bool:
	if action != "robot_copy" or card_id == robot_card_id:
		return false
	var hand: Array = game.players[game._get_view_player()].hand
	if game._find_card_index_in_array(hand, robot_card_id) < 0:
		return false
	if game._find_card_index_in_array(hand, card_id) < 0:
		return false
	robot_copy_card_id = card_id
	action = "hand"
	return true


func clear_robot_copy_selection() -> void:
	robot_card_id = -1
	robot_copy_card_id = -1
	if action == "robot_copy":
		action = ""


func is_selecting_robot_copy() -> bool:
	return action == "robot_copy" and robot_card_id >= 0


func has_robot_copy_selection() -> bool:
	return robot_card_id >= 0 and robot_copy_card_id >= 0


func get_robot_copy_card_id(card_id: int) -> int:
	if robot_card_id != card_id:
		return -1
	return robot_copy_card_id


func is_extra_hand_play() -> bool:
	return (action == "hand" or action == "robot_copy") and not extra_hand_play_request.is_empty()


func get_extra_hand_play_source_request() -> Dictionary:
	if extra_hand_play_request.is_empty():
		return {}
	if int(extra_hand_play_request.get("card_id", -1)) < 0:
		return {}
	if not game._is_inside(extra_hand_play_request.get("source_cell", Vector2i(-1, -1))):
		return {}
	return extra_hand_play_request.duplicate(true)


func is_hand_card_inactive(card: Dictionary) -> bool:
	var view_player: int = game._get_view_player()
	if is_selecting_robot_copy():
		return false
	if is_extra_hand_play():
		if int(extra_hand_play_request.get("player_index", -1)) != view_player:
			return false
		var forced_card_id: int = int(extra_hand_play_request.get("forced_card_id", -1))
		if forced_card_id >= 0:
			return int(card.id) != forced_card_id
	if action == "strateg":
		if int(strateg_request.get("player_index", -1)) != view_player:
			return false
		return int(card.id) != int(strateg_request.get("preview_card_id", -1))
	if action == "hand_pick":
		if int(hand_pick_request.get("player_index", -1)) != view_player:
			return false
		return not can_pick_hand_card(int(card.id))
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
	if is_card_target():
		return []
	return game.target_logic.get_legal_target_cells(game._get_live_game_state(), target_request)


func get_target_cards() -> Array:
	if not is_card_target():
		return []
	return game.target_logic.get_legal_target_cards(game._get_live_game_state(), target_request)


func get_target_edges() -> Array:
	if not is_choice_target():
		return []
	return game.target_logic.get_legal_target_edges(game._get_live_game_state(), target_request, selected_target_edge)


func is_choice_target() -> bool:
	return String(target_request.get("target_type", "cell")) == "choice"


func is_card_target() -> bool:
	return String(target_request.get("target_type", "cell")) == "card"


func is_repeating_choice_target() -> bool:
	return game.target_logic.is_repeating_choice_request(target_request)


func can_finish_choice_target() -> bool:
	if action == "strateg":
		return int(strateg_request.get("checks", 0)) < 10
	if action == "hand_discard" and hand_discard_optional:
		return true
	return game.target_logic.can_finish_choice_request(target_request)


func get_decision_player() -> int:
	if action == "target":
		return int(target_request.get("decision_player", target_request.get("player_index", -1)))
	if action == "robot_copy":
		return game._get_view_player()
	if is_extra_hand_play():
		return int(extra_hand_play_request.get("decision_player", extra_hand_play_request.get("player_index", -1)))
	if action == "hand_pick":
		return int(hand_pick_request.get("decision_player", hand_pick_request.get("player_index", -1)))
	if action == "discard_pick":
		return int(discard_pick_request.get("decision_player", discard_pick_request.get("player_index", -1)))
	if action == "strateg":
		return int(strateg_request.get("decision_player", strateg_request.get("player_index", -1)))
	if action == "hand_discard":
		return hand_discard_player
	return -1


func is_decision_player_view_player() -> bool:
	return get_decision_player() == game._get_view_player()


func can_discard_hand_card(card_id: int) -> bool:
	if action != "hand_discard":
		return false
	if hand_discard_allowed_ids.is_empty():
		return true
	return hand_discard_allowed_ids.has(card_id)


func is_hand_limit_discard() -> bool:
	return action == "hand_discard" and hand_discard_kind == "end_turn_hand_limit"


func can_pick_hand_card(card_id: int) -> bool:
	if action != "hand_pick":
		return false
	return int(hand_pick_request.get("player_index", -1)) == game._get_view_player()


func is_target_card(card_id: int) -> bool:
	if action != "target" or not is_card_target():
		return false
	for target in get_target_cards():
		if int(target.get("card_id", -1)) == card_id:
			return true
	return false


func _begin_pending_from_result_or_clear(result: Dictionary) -> void:
	if result.has("pending_hand_discard"):
		begin_hand_discard(result.pending_hand_discard)
	elif result.has("pending_hand_pick"):
		begin_hand_pick(result.pending_hand_pick)
	elif result.has("pending_discard_pick"):
		begin_discard_pick(result.pending_discard_pick)
	elif result.has("pending_strateg"):
		begin_strateg(result.pending_strateg)
	elif result.has("pending_extra_hand_play"):
		begin_extra_hand_play(result.pending_extra_hand_play)
	elif result.has("pending_target"):
		begin_target(result.pending_target)
	else:
		clear()


func try_apply_target(cell: Vector2i) -> void:
	if action != "target":
		return
	if is_choice_target() or is_card_target():
		return
	if not is_decision_player_view_player():
		return
	var result: Dictionary = _apply_target_to_current_state(target_request, cell)
	if result.status != game.RESULT_OK:
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_apply_target_card(card_id: int) -> void:
	if action != "target":
		return
	if not is_card_target():
		return
	if not is_decision_player_view_player():
		return
	var result: Dictionary = _apply_card_target_to_current_state(target_request, card_id)
	if result.status != game.RESULT_OK:
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_apply_target_edge(edge: Array) -> void:
	if action != "target":
		return
	if not is_choice_target():
		return
	if not is_decision_player_view_player():
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
	if result.has("pending_target") or should_finish:
		_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func finish_repeating_target() -> void:
	if action == "strateg":
		await try_discard_strateg_preview()
		return
	if action == "hand_discard" and hand_discard_optional:
		var hand_result: Dictionary = _finish_hand_discard_optional_in_current_state()
		game.animation_running = true
		game._set_action_buttons_enabled(false)
		await game._animate_action_result(hand_result)
		game.animation_running = false
		_begin_pending_from_result_or_clear(hand_result)
		game._sync_after_state_change_without_card_layout()
		return
	if action != "target":
		return
	if not can_finish_choice_target():
		return
	var result: Dictionary = _finish_target_turn_in_current_state()
	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_apply_ai_decision() -> void:
	if is_extra_hand_play():
		await game._try_ai_extra_hand_play(extra_hand_play_request)
		return
	if action != "target":
		return
	if not game._is_ai_player(get_decision_player()):
		return
	if is_card_target():
		var target_cards: Array = get_target_cards()
		if target_cards.is_empty():
			return
		await _apply_ai_target_card(int(target_cards[0].card_id))
		return
	if is_choice_target() or String(target_request.get("target_type", "")) == "option":
		var choices: Array = game.target_logic.get_ai_target_choices(game._get_live_game_state(), target_request)
		if choices.is_empty():
			if can_finish_choice_target():
				await _apply_ai_finish_target()
			return
		await _apply_ai_target_choice(choices[0])
		return
	var target_cells: Array = get_target_cells()
	if target_cells.is_empty():
		if can_finish_choice_target():
			await _apply_ai_finish_target()
		return
	await _apply_ai_target_cell(target_cells[0])


func _apply_ai_target_cell(cell: Vector2i) -> void:
	var result: Dictionary = _apply_target_to_current_state(target_request, cell)
	await _animate_ai_pending_result(result)


func _apply_ai_target_card(card_id: int) -> void:
	var result: Dictionary = _apply_card_target_to_current_state(target_request, card_id)
	await _animate_ai_pending_result(result)


func _apply_ai_target_choice(choice: Dictionary) -> void:
	var should_finish: bool = not is_repeating_choice_target()
	var result: Dictionary = _apply_choice_to_current_state(target_request, choice, should_finish)
	await _animate_ai_pending_result(result)


func _apply_ai_finish_target() -> void:
	var result: Dictionary = _finish_target_turn_in_current_state()
	await _animate_ai_pending_result(result)


func _animate_ai_pending_result(result: Dictionary) -> void:
	if result.status != game.RESULT_OK:
		return
	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_take_strateg_preview(card_id: int) -> void:
	if action != "strateg":
		return
	if int(strateg_request.get("player_index", -1)) != game._get_view_player():
		return
	if card_id != int(strateg_request.get("preview_card_id", -1)):
		return
	var result: Dictionary = _finish_strateg_in_current_state()
	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_discard_strateg_preview() -> void:
	if action != "strateg":
		return
	if int(strateg_request.get("player_index", -1)) != game._get_view_player():
		return
	var result: Dictionary = _discard_strateg_preview_in_current_state()
	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
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
	hand_discard_done += 1
	hand_discard_allowed_ids.erase(card_id)
	var discard_complete: bool = (
		hand_discard_count <= 0
		or game._count_discardable_hand_cards(hand, hand_discard_allowed_ids) <= 0
	)
	if not hand_discard_optional and discard_complete:
		_apply_source_play_reactions_to_result(state, _get_hand_discard_source_request(), result)
	if hand_discard_attack_bonus != 0:
		_apply_hand_discard_attack_bonus_to_source(state)
	var resumed_end_turn: bool = is_hand_limit_discard() and discard_complete
	if resumed_end_turn:
		result.end_turn = true
		game._apply_end_turn_rules_to_state(state, result)
		game._restore_game_state(state)
	result.events = state.events

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false

	if discard_complete:
		if hand_discard_optional:
			await finish_repeating_target()
		elif resumed_end_turn:
			_begin_pending_from_result_or_clear(result)
		else:
			clear()
			game._end_turn()
	game._sync_after_state_change_without_card_layout()


func try_pick_hand_card(card_id: int) -> void:
	if action != "hand_pick":
		return
	if int(hand_pick_request.get("player_index", -1)) != game._get_view_player():
		return
	var hand: Array = game.players[game._get_view_player()].hand
	var hand_index: int = game._find_card_index_in_array(hand, card_id)
	if hand_index < 0:
		return
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_hand_pick(state, hand_pick_request, hand_index)
	if result.status != game.RESULT_OK:
		game.action_label.text = game._tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return
	_apply_source_play_reactions_to_result(state, hand_pick_request, result)
	if not result.has("pending_target"):
		game._apply_end_turn_rules_to_state(state, result)
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func try_pick_discard_card(card_id: int) -> void:
	if action != "discard_pick":
		return
	if int(discard_pick_request.get("player_index", -1)) != game._get_view_player():
		return
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = _apply_discard_pick_to_state(state, discard_pick_request, card_id)
	if result.status != game.RESULT_OK:
		return
	_apply_source_play_reactions_to_result(state, discard_pick_request, result)
	if not result.has("pending_target"):
		game._apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	game._restore_game_state(state)
	game.discard_dialog.hide()

	game.animation_running = true
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	game.animation_running = false
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()


func _apply_discard_pick_to_state(state: Dictionary, request: Dictionary, card_id: int) -> Dictionary:
	var player_index: int = int(request.player_index)
	var discard: Array = state.players[player_index].discard
	var card_index: int = game._find_card_index_in_array(discard, card_id)
	if card_index < 0:
		return game._make_action_result(game.RESULT_INVALID, "bad_discard_index")
	var card: Dictionary = discard[card_index]
	discard.remove_at(card_index)
	game._return_card_to_hand_in_state(state, player_index, card, {
		"type": "discard"
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	return result


func _apply_target_to_current_state(request: Dictionary, target: Vector2i) -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_target(state, request, target)
	game._copy_play_identity_from_request_to_result(request, result)
	result = game.target_logic.autofinish_pending_target_if_empty(state, result)
	if result.status == game.RESULT_OK and not game._result_has_pending_action(result):
		_apply_source_play_reactions_to_result(state, request, result)
		game._check_base_capture_in_state(state, result)
		if not game._result_has_pending_action(result):
			if not bool(state.game_over):
				game._apply_end_turn_rules_to_state(state, result)
			game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _apply_card_target_to_current_state(request: Dictionary, card_id: int) -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_card_target(state, request, card_id)
	game._copy_play_identity_from_request_to_result(request, result)
	result = game.target_logic.autofinish_pending_target_if_empty(state, result)
	if result.status == game.RESULT_OK and not game._result_has_pending_action(result):
		_apply_source_play_reactions_to_result(state, request, result)
		game._check_base_capture_in_state(state, result)
		if not game._result_has_pending_action(result):
			if not bool(state.game_over):
				game._apply_end_turn_rules_to_state(state, result)
			game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _finish_hand_discard_optional_in_current_state() -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	if hand_discard_draw_bonus != 0:
		game._draw_cards_in_state(state, hand_discard_player, hand_discard_done + hand_discard_draw_bonus)
	if hand_discard_attack_bonus != 0 and hand_discard_done > 0:
		_apply_hand_discard_attack_bonus_to_source(state)
	_apply_source_play_reactions_to_result(state, _get_hand_discard_source_request(), result)
	game._apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _finish_strateg_in_current_state() -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	_apply_source_play_reactions_to_result(state, strateg_request, result)
	if not game._result_has_pending_action(result):
		game._apply_end_turn_rules_to_state(state, result)
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _discard_strateg_preview_in_current_state() -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var player_index: int = int(strateg_request.player_index)
	var preview_card_id: int = int(strateg_request.preview_card_id)
	var hand: Array = state.players[player_index].hand
	var hand_index: int = game._find_card_index_in_array(hand, preview_card_id)
	if hand_index < 0:
		return game._make_action_result(game.RESULT_INVALID, "bad_hand_index")
	var card: Dictionary = hand[hand_index]
	hand.remove_at(hand_index)
	game._discard_card_in_state(state, player_index, card, {
		"type": "hand",
		"hand_index": hand_index
	})
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	var checks: int = int(strateg_request.get("checks", 0))
	if checks < 10:
		var preview: Dictionary = _draw_strateg_preview_card(state, player_index)
		if not preview.is_empty():
			var next_request: Dictionary = strateg_request.duplicate(true)
			next_request.preview_card_id = int(preview.id)
			next_request.checks = checks + 1
			result.pending_strateg = next_request
			result.end_turn = false
			result.events = state.events
			game._restore_game_state(state)
			return result
	_apply_source_play_reactions_to_result(state, strateg_request, result)
	if not game._result_has_pending_action(result):
		game._apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	game._restore_game_state(state)
	return result


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


func _apply_hand_discard_attack_bonus_to_source(state: Dictionary) -> void:
	if hand_discard_card_id < 0 or not game._is_inside(hand_discard_source_cell):
		return
	var source_card: Dictionary = game._find_card_by_id_in_array(
		game._get_stack_in_state(state, hand_discard_source_cell),
		hand_discard_card_id
	)
	if source_card.is_empty():
		return
	source_card.attack_bonus = int(source_card.get("attack_bonus", 0)) + hand_discard_attack_bonus
	hand_discard_attack_bonus = 0


func _get_hand_discard_source_request() -> Dictionary:
	var request: Dictionary = {
		"card_id": hand_discard_card_id,
		"source_cell": hand_discard_source_cell
	}
	if not hand_discard_ability_name_key.is_empty():
		request.ability_name_key = hand_discard_ability_name_key
	if hand_discard_copied_card_id >= 0:
		request.copied_card_id = hand_discard_copied_card_id
	return request


func _apply_choice_to_current_state(request: Dictionary, choice: Dictionary, finish_turn: bool = true) -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var supply_origin_before: Dictionary = game._get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = game.target_logic.apply_choice(state, request, choice)
	game._copy_play_identity_from_request_to_result(request, result)
	if result.status == game.RESULT_OK:
		result = game.target_logic.autofinish_pending_target_if_empty(state, result)
		_apply_source_play_reactions_to_result(state, request, result)
	if result.status == game.RESULT_OK and finish_turn and not game._result_has_pending_action(result):
		game._check_base_capture_in_state(state, result)
		game._apply_end_turn_rules_to_state(state, result)
	if result.status == game.RESULT_OK:
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
		if not game._result_has_pending_action(result):
			result.end_turn = finish_turn and not bool(state.game_over)
	result.events = state.events
	game._restore_game_state(state)
	return result


func _apply_source_play_reactions_to_result(state: Dictionary, request: Dictionary, result: Dictionary) -> void:
	game._apply_source_play_reactions_to_result_in_state(state, request, result)


func _finish_target_turn_in_current_state() -> Dictionary:
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = game.target_logic.finish_choice(state, target_request)
	game._copy_play_identity_from_request_to_result(target_request, result)
	if not result.has("pending_target"):
		_apply_source_play_reactions_to_result(state, target_request, result)
		game._check_base_capture_in_state(state, result)
		if not game._result_has_pending_action(result) and not bool(state.game_over):
			game._apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	game._restore_game_state(state)
	return result


func try_apply_target_option(choice: Dictionary) -> void:
	if action != "target" or game.animation_running or not is_decision_player_view_player():
		return
	var result: Dictionary = _apply_choice_to_current_state(target_request, choice)
	if result.status != game.RESULT_OK:
		return
	game._set_action_buttons_enabled(false)
	await game._animate_action_result(result)
	_begin_pending_from_result_or_clear(result)
	game._sync_after_state_change_without_card_layout()
