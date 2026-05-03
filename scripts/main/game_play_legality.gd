extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func can_play_card(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	if not game._is_inside(cell):
		return false
	var player_index: int = int(card.owner)
	var base_owner: int = game._get_base_owner_in_state(state, cell)
	if base_owner == player_index:
		return false
	if not _has_play_supply_access(state, card, cell):
		return false

	var stack: Array = game._get_stack_in_state(state, cell)
	if bool(card.face_down):
		if base_owner != -1:
			return false
		if stack.is_empty():
			return true
		return game._top_owner_in_state(state, cell) == player_index

	if base_owner == game._opponent(player_index):
		return not _is_card_name(card, UnitKeys.GRIFFON_NAME)
	if stack.is_empty():
		return true
	if game._top_owner_in_state(state, cell) == player_index:
		return true
	if game._top_face_down_in_state(state, cell):
		return true

	return game.power_logic.can_attack_card(state, card, cell)


func get_play_access_kind(state: Dictionary, card: Dictionary, cell: Vector2i) -> String:
	return String(get_play_access_info(state, card, cell).get("kind", ""))


func get_play_access_info(state: Dictionary, card: Dictionary, cell: Vector2i) -> Dictionary:
	if not game._is_inside(cell):
		return {}
	var player_index: int = int(card.owner)
	if game._get_supplied_cells_in_state(state, player_index).has(cell):
		return {
			"kind": "standard",
			"sources": _get_current_supply_play_source_cells(state, player_index, cell)
		}
	if bool(card.face_down):
		return {}
	if _is_card_name(card, UnitKeys.GRIFFON_NAME) and game._get_base_owner_in_state(state, cell) == -1:
		return {
			"kind": "griffon",
			"sources": []
		}
	if _is_card_name(card, UnitKeys.VOROTA_NAME) and _is_supplied_after_preview_play(state, card, cell):
		return {
			"kind": "vorota",
			"sources": _get_preview_supply_play_source_cells(state, card, cell)
		}
	return {}


func _has_play_supply_access(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	return get_play_access_kind(state, card, cell) != ""


func _is_supplied_after_preview_play(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	if game._get_base_owner_in_state(state, cell) == int(card.owner):
		return false
	var preview_state: Dictionary = game._duplicate_game_state(state)
	var preview_card: Dictionary = card.duplicate(true)
	preview_card.face_down = false
	game._get_stack_in_state(preview_state, cell).append(preview_card)
	return game._get_supplied_cells_in_state(preview_state, int(card.owner)).has(cell)


func _get_current_supply_play_source_cells(state: Dictionary, player_index: int, cell: Vector2i) -> Array:
	var supply_edges: Dictionary = game._get_supply_edges_in_state(state, player_index)
	var supply_origins: Dictionary = game._get_supply_origin_cells_in_state(state, player_index)
	return _get_supply_source_cells_for_target(supply_edges, supply_origins, cell)


func _get_preview_supply_play_source_cells(state: Dictionary, card: Dictionary, cell: Vector2i) -> Array:
	var player_index: int = int(card.owner)
	var preview_state: Dictionary = game._duplicate_game_state(state)
	var preview_card: Dictionary = card.duplicate(true)
	preview_card.face_down = false
	game._get_stack_in_state(preview_state, cell).append(preview_card)
	var supply_edges: Dictionary = game._get_supply_edges_in_state(preview_state, player_index)
	var current_origins: Dictionary = game._get_supply_origin_cells_in_state(state, player_index)
	return _get_supply_source_cells_for_target(supply_edges, current_origins, cell)


func _get_supply_source_cells_for_target(supply_edges: Dictionary, source_cells: Dictionary, target: Vector2i) -> Array:
	var sources: Array = []
	for from_cell in source_cells.keys():
		var edges: Dictionary = supply_edges.get(from_cell, {})
		if edges.has(target):
			sources.append(from_cell)
	return sources


func _is_card_name(card: Dictionary, name_key: String) -> bool:
	if bool(card.face_down):
		return false
	return String(card.unit.name_key) == name_key
