extends RefCounted

var game: Node
var action: String = ""
var hand_discard_player: int = -1
var hand_discard_count: int = 0
var hand_discard_allowed_ids: Array = []
var target_request: Dictionary = {}


func _init(game_node: Node) -> void:
	game = game_node


func clear() -> void:
	action = ""
	game.ui_selected_hand_card_id = -1
	hand_discard_player = -1
	hand_discard_count = 0
	hand_discard_allowed_ids.clear()
	target_request.clear()


func begin_target(request: Dictionary) -> void:
	action = "target"
	game.ui_selected_hand_card_id = -1
	target_request = request.duplicate(true)


func begin_hand_discard(discard_info: Dictionary) -> void:
	action = "hand_discard"
	game.ui_selected_hand_card_id = -1
	hand_discard_player = int(discard_info.player_index)
	hand_discard_count = int(discard_info.count)
	hand_discard_allowed_ids = Array(discard_info.get("allowed_card_ids", [])).duplicate()


func is_hand_card_inactive(card: Dictionary) -> bool:
	var view_player: int = game._get_view_player()
	if game.current_player != view_player:
		return false
	if action == "hand_discard":
		return not can_discard_hand_card(int(card.id))
	if not game.action_restriction_logic.can_select_hand_card(game._get_live_game_state(), game.current_player, card):
		return true
	return game.minor_actions_spent > 0


func get_target_cells() -> Array:
	return game.target_logic.get_legal_target_cells(game._get_live_game_state(), target_request)


func can_discard_hand_card(card_id: int) -> bool:
	if action != "hand_discard":
		return false
	if hand_discard_allowed_ids.is_empty():
		return true
	return hand_discard_allowed_ids.has(card_id)


func try_apply_target(cell: Vector2i) -> void:
	if action != "target":
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
	if result.status == game.RESULT_OK:
		game._apply_end_turn_rules_to_state(state)
		game._record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = state.events
	game._restore_game_state(state)
	return result
