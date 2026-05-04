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
		return _get_boevoy_mag_target_request(state, result)
	return {}


func get_legal_target_cells(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.get("kind", ""))
	if kind == "discard_adjacent_enemy":
		return _get_adjacent_enemy_target_cells(state, request)
	return []


func apply_target(state: Dictionary, request: Dictionary, target: Vector2i) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_INVALID, "bad_target")
	var legal_targets: Array = get_legal_target_cells(state, request)
	if not legal_targets.has(target):
		return result

	var kind: String = String(request.get("kind", ""))
	if kind == "discard_adjacent_enemy":
		return _apply_discard_adjacent_enemy_target(state, target)
	return result


func _get_boevoy_mag_target_request(state: Dictionary, result: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"kind": "discard_adjacent_enemy",
		"player_index": int(result.card.owner),
		"source_cell": result.cell
	}
	if get_legal_target_cells(state, request).is_empty():
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
