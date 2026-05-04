extends RefCounted

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func add_next_turn_restriction(state: Dictionary, player_index: int, kind: String, source_cell: Vector2i = Vector2i(-1, -1)) -> void:
	if not state.has("turn_restrictions"):
		state.turn_restrictions = []
	state.turn_restrictions.append({
		"player_index": player_index,
		"kind": kind,
		"source_cell": source_cell
	})


func add_next_turn_random_hand_play_restriction(state: Dictionary, player_index: int, source_cell: Vector2i = Vector2i(-1, -1)) -> void:
	if not state.has("turn_restrictions"):
		state.turn_restrictions = []
	var forced_card_id: int = _pick_random_hand_card_id(state, player_index)
	state.turn_restrictions.append({
		"player_index": player_index,
		"kind": "only_hand_play",
		"source_cell": source_cell,
		"forced_card_id": forced_card_id
	})


func remove_finished_turn_restrictions(state: Dictionary, player_index: int) -> void:
	if not state.has("turn_restrictions"):
		return
	var kept: Array = []
	for restriction in state.turn_restrictions:
		if int(restriction.get("player_index", -1)) != player_index:
			kept.append(restriction)
	state.turn_restrictions = kept


func can_draw_card(state: Dictionary, player_index: int) -> bool:
	return not _has_restriction(state, player_index, "no_draw") and not _has_restriction(state, player_index, "only_hand_play")


func can_play_path(state: Dictionary, player_index: int) -> bool:
	return not _has_restriction(state, player_index, "only_hand_play")


func can_play_hand_card(state: Dictionary, player_index: int, card: Dictionary, cell: Vector2i) -> bool:
	if not can_select_hand_card(state, player_index, card):
		return false
	if _has_restriction(state, player_index, "no_large_units") and int(card.unit.power) >= 5:
		return false
	return true


func can_select_hand_card(state: Dictionary, player_index: int, card: Dictionary) -> bool:
	var forced_card_id: int = _get_forced_hand_card_id(state, player_index)
	if forced_card_id == -1:
		return true
	return int(card.id) == forced_card_id


func filter_turn_variants(state: Dictionary, player_index: int, variants: Array) -> Array:
	if not _has_restriction(state, player_index, "only_hand_play"):
		return variants
	var filtered: Array = []
	for variant in variants:
		if String(variant.type) == game.ACTION_PLAY_HAND_CARD:
			filtered.append(variant)
	return filtered


func _has_restriction(state: Dictionary, player_index: int, kind: String) -> bool:
	if not state.has("turn_restrictions"):
		return false
	for restriction in state.turn_restrictions:
		if int(restriction.get("player_index", -1)) == player_index and String(restriction.get("kind", "")) == kind:
			return true
	return false


func _get_forced_hand_card_id(state: Dictionary, player_index: int) -> int:
	if not state.has("turn_restrictions"):
		return -1
	for restriction in state.turn_restrictions:
		if int(restriction.get("player_index", -1)) != player_index:
			continue
		if String(restriction.get("kind", "")) != "only_hand_play":
			continue
		return int(restriction.get("forced_card_id", -1))
	return -1


func _pick_random_hand_card_id(state: Dictionary, player_index: int) -> int:
	var hand: Array = state.players[player_index].hand
	if hand.is_empty():
		return -1
	var hand_index: int = randi_range(0, hand.size() - 1)
	return int(hand[hand_index].id)
