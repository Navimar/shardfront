extends RefCounted

const ENEMY_PLAYER_INDEX: int = 1
const COMBAT_CARDS_PER_PLAN: int = 1
const PATH_CARDS_PER_PLAN: int = 2
const MIN_POWER: int = 1
const MAX_POWER: int = 7
const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const PLAN_KIND_COMBAT: String = "combat"
const PLAN_KIND_PATH: String = "path"
const SoloEnemyPortrait: Texture2D = preload("res://assets/cards/card_oskolchnik.png")

var game: Node
var plan: Array = []
var resolving_plan: bool = false
var units_by_power: Dictionary = {}
var path_power_deck: Array = []


func _init(game_node: Node) -> void:
	game = game_node


func reset() -> void:
	plan.clear()
	resolving_plan = false
	path_power_deck.clear()


func make_deck_template() -> Array:
	var units: Array = []
	for power in range(MIN_POWER, MAX_POWER + 1):
		units.append(get_unit_for_power(power))
	return units


func get_unit_for_power(power: int) -> Resource:
	if units_by_power.has(power):
		return units_by_power[power]
	var unit: UnitResource = UnitResource.new()
	unit.id = "solo_enemy_%d" % power
	unit.name_key = "SOLO_ENEMY_NAME"
	unit.description_key = "SOLO_ENEMY_DESCRIPTION"
	unit.power = power
	unit.ability_symbols = ""
	unit.implementation_status = UnitResource.IMPLEMENTATION_TESTED
	unit.portrait = SoloEnemyPortrait
	units_by_power[power] = unit
	return unit


func prepare_plan(state: Dictionary) -> Array:
	plan.clear()
	var drawn_card_ids: Array = game._draw_cards_in_state(
		state,
		ENEMY_PLAYER_INDEX,
		COMBAT_CARDS_PER_PLAN
	)
	var reserved_cells: Dictionary = {}
	var supply_result: Dictionary = game.supply_logic.calculate_supply_result(state, ENEMY_PLAYER_INDEX)
	for card_id in drawn_card_ids:
		var card: Dictionary = game._find_card_by_id_in_array(
			state.players[ENEMY_PLAYER_INDEX].hand,
			int(card_id)
		)
		if card.is_empty():
			continue
		var target_cell: Vector2i = _choose_combat_target(state, card, reserved_cells, supply_result)
		if game._is_inside(target_cell):
			reserved_cells[target_cell] = true
		plan.append({
			"card_id": int(card.id),
			"kind": PLAN_KIND_COMBAT,
			"power": int(card.unit.power),
			"cell": target_cell
		})

	for _path_index in range(PATH_CARDS_PER_PLAN):
		var path_card: Dictionary = _create_path_card_in_hand(state)
		drawn_card_ids.append(int(path_card.id))
		var path_candidates: Array = _get_available_path_cells(
			state,
			path_card,
			reserved_cells,
			supply_result
		)
		var path_cell: Vector2i = _pick_random_cell(path_candidates)
		if game._is_inside(path_cell):
			reserved_cells[path_cell] = true
		plan.append({
			"card_id": int(path_card.id),
			"kind": PLAN_KIND_PATH,
			"power": 0,
			"cell": path_cell
		})
	return drawn_card_ids


func _create_path_card_in_hand(state: Dictionary) -> Dictionary:
	var path_power: int = _draw_path_power()
	var card: Dictionary = game._make_card_in_state(
		state,
		get_unit_for_power(path_power),
		ENEMY_PLAYER_INDEX,
		true
	)
	state.players[ENEMY_PLAYER_INDEX].hand.append(card)
	game._record_draw_event_in_state(state, ENEMY_PLAYER_INDEX, card)
	return card


func _draw_path_power() -> int:
	if path_power_deck.is_empty():
		for power in range(MIN_POWER, MAX_POWER + 1):
			path_power_deck.append(power)
		path_power_deck.shuffle()
	return int(path_power_deck.pop_back())


func _choose_combat_target(
	state: Dictionary,
	card: Dictionary,
	reserved_cells: Dictionary,
	supply_result: Dictionary
) -> Vector2i:
	var candidates: Array = _get_available_cells(state, card, reserved_cells, supply_result)
	if candidates.is_empty():
		return INVALID_CELL

	var opponent_index: int = game._opponent(ENEMY_PLAYER_INDEX)
	var opponent_base: Vector2i = state.players[opponent_index].base
	if candidates.has(opponent_base):
		return opponent_base

	var attack_cells: Array = []
	for cell in candidates:
		if game._top_owner_in_state(state, cell) == opponent_index:
			attack_cells.append(cell)
	if not attack_cells.is_empty():
		return _pick_random_cell(attack_cells)
	return _pick_random_cell(candidates)


func _get_available_cells(
	state: Dictionary,
	card: Dictionary,
	reserved_cells: Dictionary,
	supply_result: Dictionary
) -> Array:
	var cells: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if reserved_cells.has(cell):
				continue
			if can_play_at_cell(state, card, cell, supply_result):
				cells.append(cell)
	return cells


func _get_available_path_cells(
	state: Dictionary,
	card: Dictionary,
	reserved_cells: Dictionary,
	supply_result: Dictionary
) -> Array:
	var cells: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if reserved_cells.has(cell):
				continue
			if can_play_path_at_cell(state, card, cell, supply_result):
				cells.append(cell)
	return cells


func _pick_random_cell(cells: Array) -> Vector2i:
	if cells.is_empty():
		return INVALID_CELL
	cells.shuffle()
	return cells[0]


func can_play_at_cell(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> bool:
	if not game._is_inside(cell):
		return false
	if game._top_owner_in_state(state, cell) == ENEMY_PLAYER_INDEX:
		return false
	return (
		game.action_restriction_logic.can_play_hand_card(state, ENEMY_PLAYER_INDEX, card, cell)
		and game._can_play_card_in_state(state, card, cell, supply_result)
	)


func can_play_path_at_cell(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> bool:
	if not game._is_inside(cell):
		return false
	if game._top_owner_in_state(state, cell) == ENEMY_PLAYER_INDEX:
		return false
	if not game.action_restriction_logic.can_play_path(state, ENEMY_PLAYER_INDEX):
		return false
	var path_card: Dictionary = card.duplicate(true)
	path_card.face_down = true
	return game._can_play_card_in_state(state, path_card, cell, supply_result)


func get_visible_plan() -> Array:
	var visible_plan: Array = []
	for entry in plan:
		var cell: Vector2i = entry.get("cell", INVALID_CELL)
		if game._is_inside(cell):
			visible_plan.append(entry)
	return visible_plan


func get_entry_for_cell(cell: Vector2i) -> Dictionary:
	for entry in plan:
		if entry.get("cell", INVALID_CELL) == cell:
			return entry
	return {}


func has_entries() -> bool:
	return not plan.is_empty()


func pop_next_entry() -> Dictionary:
	if plan.is_empty():
		return {}
	return plan.pop_front()


func begin_resolution() -> void:
	resolving_plan = true


func finish_resolution() -> void:
	resolving_plan = false


func should_hold_enemy_turn(state: Dictionary) -> bool:
	return (
		resolving_plan
		and int(state.current_player) == ENEMY_PLAYER_INDEX
		and not plan.is_empty()
	)
