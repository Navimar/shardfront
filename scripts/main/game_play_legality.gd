extends RefCounted

const CardAbilities: Script = preload("res://scripts/main/card_abilities.gd")
const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node


func _init(game_node: Node) -> void:
	game = game_node


func can_play_card(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> bool:
	if not game._is_inside(cell):
		return false
	if not _is_target_allowed_by_turn_restrictions(state, card, cell):
		return false
	var player_index: int = int(card.owner)
	var base_owner: int = game._get_base_owner_in_state(state, cell)
	if base_owner == player_index:
		return false
	if not _has_play_supply_access(state, card, cell, supply_result):
		return false

	var stack: Array = game._get_stack_in_state(state, cell)
	if _is_card_name(card, UnitKeys.GONDOLA_NAME):
		return base_owner == -1 and (stack.is_empty() or game._top_owner_in_state(state, cell) == player_index)
	if _is_card_name(card, UnitKeys.GNOM_NAME):
		return _can_play_gnom(state, card, cell, base_owner, stack, supply_result)

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


func get_play_access_kind(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> String:
	return String(get_play_access_info(state, card, cell, supply_result).get("kind", ""))


func get_play_access_info(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> Dictionary:
	if not game._is_inside(cell):
		return {}
	if not _is_target_allowed_by_turn_restrictions(state, card, cell):
		return {}
	var player_index: int = int(card.owner)
	if _is_card_name(card, UnitKeys.GNOM_NAME):
		var gnom_stack: Array = game._get_stack_in_state(state, cell)
		if _can_play_gnom(state, card, cell, game._get_base_owner_in_state(state, cell), gnom_stack, supply_result):
			return {
				"kind": "gnom",
				"sources": _get_current_supply_play_source_cells(state, player_index, cell, supply_result)
			}
		return {}
	var resolved_supply_result: Dictionary = _resolve_supply_result(state, player_index, supply_result)
	if Dictionary(resolved_supply_result.supplied).has(cell):
		return {
			"kind": "standard",
			"sources": _get_current_supply_play_source_cells(state, player_index, cell, resolved_supply_result)
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
			"sources": _get_preview_supply_play_source_cells(state, card, cell, resolved_supply_result)
		}
	return {}


func _has_play_supply_access(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> bool:
	return get_play_access_kind(state, card, cell, supply_result) != ""


func _is_supplied_after_preview_play(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	if game._get_base_owner_in_state(state, cell) == int(card.owner):
		return false
	var preview_state: Dictionary = game._duplicate_game_state(state)
	var preview_card: Dictionary = card.duplicate(true)
	preview_card.face_down = false
	game._get_stack_in_state(preview_state, cell).append(preview_card)
	return game._get_supplied_cells_in_state(preview_state, int(card.owner)).has(cell)


func _get_current_supply_play_source_cells(
	state: Dictionary,
	player_index: int,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> Array:
	var resolved_supply_result: Dictionary = _resolve_supply_result(state, player_index, supply_result)
	var supply_edges: Dictionary = resolved_supply_result.edges
	var supply_origins: Dictionary = resolved_supply_result.origins
	return _get_supply_source_cells_for_target(supply_edges, supply_origins, cell)


func _get_preview_supply_play_source_cells(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	current_supply_result: Dictionary = {}
) -> Array:
	var player_index: int = int(card.owner)
	var preview_state: Dictionary = game._duplicate_game_state(state)
	var preview_card: Dictionary = card.duplicate(true)
	preview_card.face_down = false
	game._get_stack_in_state(preview_state, cell).append(preview_card)
	var supply_edges: Dictionary = game._get_supply_edges_in_state(preview_state, player_index)
	var resolved_current_supply_result: Dictionary = _resolve_supply_result(state, player_index, current_supply_result)
	var current_origins: Dictionary = resolved_current_supply_result.origins
	return _get_supply_source_cells_for_target(supply_edges, current_origins, cell)


func _resolve_supply_result(state: Dictionary, player_index: int, supply_result: Dictionary) -> Dictionary:
	if not supply_result.is_empty() and int(supply_result.get("player_index", -1)) == player_index:
		return supply_result
	return game.supply_logic.calculate_supply_result(state, player_index)


func _get_supply_source_cells_for_target(supply_edges: Dictionary, source_cells: Dictionary, target: Vector2i) -> Array:
	var sources: Array = []
	for from_cell in source_cells.keys():
		var edges: Dictionary = supply_edges.get(from_cell, {})
		if edges.has(target):
			sources.append(from_cell)
	return sources


func _is_target_allowed_by_turn_restrictions(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	if bool(card.face_down):
		return true
	var player_index: int = int(card.owner)
	if not _has_turn_restriction(state, player_index, "no_latnik_cell"):
		return true
	return not _is_open_latnik_cell(state, cell)


func _has_turn_restriction(state: Dictionary, player_index: int, kind: String) -> bool:
	if not state.has("turn_restrictions"):
		return false
	for restriction in state.turn_restrictions:
		if int(restriction.get("player_index", -1)) == player_index and String(restriction.get("kind", "")) == kind:
			return true
	return false


func _is_open_latnik_cell(state: Dictionary, cell: Vector2i) -> bool:
	var stack: Array = game._get_stack_in_state(state, cell)
	if stack.is_empty():
		return false
	var top_card: Dictionary = stack[stack.size() - 1]
	return _is_card_name(top_card, UnitKeys.LATNIK_NAME)


func _is_card_name(card: Dictionary, name_key: String) -> bool:
	if bool(card.face_down):
		return false
	return CardAbilities.name_key(card) == name_key


func _can_play_gnom(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	base_owner: int,
	stack: Array,
	supply_result: Dictionary = {}
) -> bool:
	var player_index: int = int(card.owner)
	if base_owner != -1:
		return false
	if stack.is_empty():
		return false
	var resolved_supply_result: Dictionary = _resolve_supply_result(state, player_index, supply_result)
	if not Dictionary(resolved_supply_result.supplied).has(cell):
		return false
	return true
