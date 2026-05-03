extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func apply_after_play(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return
	_apply_covered_card_reactions(state, result)
	if bool(result.get("played_card_removed", false)):
		return
	_apply_cherepaha_play_rule(state, result)


func _apply_covered_card_reactions(state: Dictionary, result: Dictionary) -> void:
	var cell: Vector2i = result.cell
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.size() < 2:
		return
	var covering_card: Dictionary = stack[stack.size() - 1]
	var played_card: Dictionary = result.card
	if int(covering_card.id) != int(played_card.id):
		return
	var covered_card: Dictionary = stack[stack.size() - 2]
	if bool(covered_card.face_down):
		return

	var covered_name: String = String(covered_card.unit.name_key)
	if covered_name == UnitKeys.MINA_NAME:
		covered_card.face_down = true
		_discard_covering_card(state, result, cell, stack, covering_card)
	elif covered_name == UnitKeys.MAKOVOE_POLE_NAME and int(covering_card.unit.power) >= 3:
		_discard_covering_card(state, result, cell, stack, covering_card)


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


func _apply_cherepaha_play_rule(state: Dictionary, result: Dictionary) -> void:
	var card: Dictionary = result.card
	if bool(card.face_down):
		return
	if String(card.unit.name_key) != UnitKeys.CHEREPAHA_NAME:
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
