extends SceneTree

const GameScene: PackedScene = preload("res://scenes/main.tscn")
const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node
var failures: Array = []
var cached_units: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	game = GameScene.instantiate()
	root.add_child(game)
	await process_frame

	_run_test("Sliz copies Rytsar draw effect", Callable(self, "_test_sliz_copies_rytsar_draw_effect"))
	await _run_async_test("Sliz card target remains clickable after board animation", Callable(self, "_test_sliz_card_target_remains_clickable"))
	_run_test("Mirror Golem copies Scarab overflow return", Callable(self, "_test_mirror_golem_copies_scarab_overflow_return"))
	_run_test("Primanka uses an on-play ability symbol", Callable(self, "_test_primanka_uses_on_play_ability_symbol"))
	_run_test("Manoprovod counts adjacent face-down paths", Callable(self, "_test_manoprovod_counts_adjacent_face_down_paths"))
	_run_test("Volk replay uses normal play legality", Callable(self, "_test_volk_replay_uses_normal_play_legality"))
	_run_test("Robot uses the explicitly selected hand creature", Callable(self, "_test_robot_uses_selected_hand_creature"))
	_run_test("Robot copied strength controls play legality", Callable(self, "_test_robot_copied_strength_controls_play_legality"))
	_run_test("Robot preserves copied targeted abilities", Callable(self, "_test_robot_preserves_copied_targeted_abilities"))
	_run_test("Randomag can draw Robot without creating a dead end", Callable(self, "_test_randomag_can_draw_robot"))
	await _run_async_test("Hand-limit overflow is discarded by owner choice", Callable(self, "_test_hand_limit_overflow_is_discarded_by_owner_choice"))
	_run_test("AI resolves its own hand-limit overflow", Callable(self, "_test_ai_resolves_own_hand_limit_overflow"))
	_run_test("AI canonicalizes order-independent target sequences", Callable(self, "_test_ai_canonicalizes_order_independent_target_sequences"))
	await _run_async_test("Duh Buri waits for the opponent's choice", Callable(self, "_test_duh_buri_waits_for_opponent_choice"))
	_run_test("Vihr target flow is finite and swaps neighbor stacks", Callable(self, "_test_vihr_target_flow"))
	_run_test("Sporovik asks for own stacks then enemy stacks", Callable(self, "_test_sporovik_two_phase_choice"))
	_run_test("Randomag draws the played card into hand first", Callable(self, "_test_randomag_draws_extra_play_card_into_hand"))
	_run_test("Repeating target auto-finishes without legal targets", Callable(self, "_test_repeating_target_autofinishes_without_legal_targets"))
	_run_test("Solo deck and plan use bounded random enemies", Callable(self, "_test_solo_deck_and_plan"))
	_run_test("Solo plan excludes enemy-controlled cells", Callable(self, "_test_solo_plan_excludes_enemy_controlled_cells"))
	_run_test("Solo combat prioritizes base then attacks", Callable(self, "_test_solo_combat_prioritizes_base_then_attacks"))
	_run_test("Solo plan keeps one enemy wave", Callable(self, "_test_solo_plan_keeps_one_enemy_wave"))
	_run_test("Blocked solo plan card is skipped", Callable(self, "_test_blocked_solo_plan_card_is_skipped"))
	_run_test("Board grid edge lines use outer gutters", Callable(self, "_test_board_grid_edge_lines_use_outer_gutters"))
	_run_test("Action status uses card title font", Callable(self, "_test_action_status_uses_card_title_font"))

	if failures.is_empty():
		print("All headless card ability tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(String(failure))
		quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	_initialize_empty_board()
	var failure_count_before: int = failures.size()
	test_callable.call()
	if failures.size() == failure_count_before:
		print("PASS: %s" % test_name)
	else:
		print("FAIL: %s" % test_name)


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	_initialize_empty_board()
	var failure_count_before: int = failures.size()
	await test_callable.call()
	if failures.size() == failure_count_before:
		print("PASS: %s" % test_name)
	else:
		print("FAIL: %s" % test_name)


func _initialize_empty_board() -> void:
	game.board.clear()
	for y in range(game.GRID_HEIGHT):
		var row: Array = []
		for x in range(game.GRID_WIDTH):
			row.append([])
		game.board.append(row)
	game.barriers.clear()
	game.players[0].deck_template.clear()
	game.players[0].deck.clear()
	game.players[0].hand.clear()
	game.players[0].discard.clear()
	game.players[1].deck_template.clear()
	game.players[1].deck.clear()
	game.players[1].hand.clear()
	game.players[1].discard.clear()
	for index in range(game.players.size()):
		var player: Dictionary = game.players[index]
		player.base = game.PLAYER_BASE_CELLS[index]
		player.next_attack_bonus = 0
		player.in_end_turn = false
		player.gondola_finished = false
	game.current_player = 0
	game.minor_actions_spent = 0
	game.game_over = false
	game.game_over_message = ""
	game.destroyed_base_owner = -1
	game.next_card_id = 1000
	game.pending_logic.clear()
	game.turn_restrictions.clear()
	game.barrier_removal_options.clear()


func _find_unit(name_key: String) -> Resource:
	if cached_units.is_empty():
		for unit in game._load_units([]):
			cached_units[String(unit.name_key)] = unit
	if cached_units.has(name_key):
		return cached_units[name_key]
	_fail("Missing unit resource: %s" % name_key)
	return null

func _make_card(name_key: String, owner: int, face_down: bool = false) -> Dictionary:
	return game._make_card(_find_unit(name_key), owner, face_down)


func _place_card(name_key: String, owner: int, cell: Vector2i) -> Dictionary:
	var card: Dictionary = _make_card(name_key, owner, false)
	game._place_card(card, cell)
	return card


func _place_full_stack(name_key: String, owner: int, cell: Vector2i) -> void:
	_place_card(name_key, owner, cell)
	_place_card(name_key, owner, cell)


func _top_card(cell: Vector2i) -> Dictionary:
	var stack: Array = game._get_stack_in_state(game._get_live_game_state(), cell)
	if stack.is_empty():
		return {}
	return stack[stack.size() - 1]


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _assert_false(condition: bool, message: String) -> void:
	if condition:
		_fail(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_fail("%s Expected=%s Actual=%s" % [message, var_to_str(expected), var_to_str(actual)])


func _assert_float_near(actual: float, expected: float, epsilon: float, message: String) -> void:
	if abs(actual - expected) > epsilon:
		_fail("%s Expected=%s Actual=%s Epsilon=%s" % [message, var_to_str(expected), var_to_str(actual), var_to_str(epsilon)])


func _assert_has_key(dictionary: Dictionary, key: String, message: String) -> void:
	if not dictionary.has(key):
		_fail("%s Missing key=%s Dictionary=%s" % [message, key, var_to_str(dictionary)])


func _assert_cells_equal_unordered(actual: Array, expected: Array, message: String) -> void:
	if actual.size() != expected.size():
		_fail("%s Expected=%s Actual=%s" % [message, var_to_str(expected), var_to_str(actual)])
		return
	for cell in expected:
		if not actual.has(cell):
			_fail("%s Missing cell=%s Actual=%s" % [message, var_to_str(cell), var_to_str(actual)])


func _fail(message: String) -> void:
	failures.append(message)


func _test_sliz_copies_rytsar_draw_effect() -> void:
	var sliz_card: Dictionary = _make_card(UnitKeys.SLIZ_NAME, 0)
	game.players[0].hand.append(sliz_card)
	var copied_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(3, 1))
	game.players[0].deck.append(_make_card(UnitKeys.GRIBNIK_NAME, 0))

	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": Vector2i(0, 1)
	})
	variant.target_card_id = int(copied_card.id)
	variant.payload = Dictionary(variant.payload).duplicate(true)
	variant.payload.target_card_id = int(copied_card.id)

	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
	_assert_equal(String(result.status), game.RESULT_OK, "Sliz play should succeed.")
	_assert_false(result.has("pending_target"), "Sliz copying Rytsar should finish without a pending target.")
	_assert_equal(game.players[0].hand.size(), 1, "Sliz should draw one card after copying Rytsar.")


func _test_sliz_card_target_remains_clickable() -> void:
	var copied_cell: Vector2i = Vector2i(3, 1)
	var copied_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, copied_cell)
	var copied_control: Control = game._ensure_card_view(copied_card)
	game._finish_play_card_animation(copied_control, {
		"type": "play_card",
		"card_id": int(copied_card.id),
		"player_index": 0,
		"unit": copied_card.unit,
		"cell": copied_cell,
		"face_down": false,
		"stack_cards": [copied_card],
		"source": {
			"type": "hand",
			"hand_index": 0
		}
	})
	_assert_equal(
		copied_control.get_meta("board_cell", Vector2i(-1, -1)),
		copied_cell,
		"A card moved onto the board by animation should remember its board cell."
	)
	_assert_true(
		bool(copied_control.get_meta("board_input_connected", false)),
		"A card moved onto the board by animation should receive board-card input."
	)

	var sliz_card: Dictionary = _make_card(UnitKeys.SLIZ_NAME, 0)
	game.players[0].hand.append(sliz_card)
	game.players[0].deck.append(_make_card(UnitKeys.GRIBNIK_NAME, 0))
	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": Vector2i(0, 1)
	})
	var play_result: Dictionary = game._apply_action_variant_to_current_state(variant)
	_assert_has_key(play_result, "pending_target", "Sliz should wait for an explicit board-card choice.")
	if not play_result.has("pending_target"):
		return
	game.pending_logic.begin_target(play_result.pending_target)
	_assert_true(
		game.pending_logic.is_target_card(int(copied_card.id)),
		"The copied open creature should be registered as an interactive Sliz target."
	)

	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	await game._on_board_card_gui_input(click_event, copied_control)
	_assert_equal(game.pending_logic.action, "", "Choosing the copied card should resolve Sliz instead of leaving target mode stuck.")
	_assert_equal(game.players[0].hand.size(), 1, "The copied Rytsar effect should draw one card through the interactive target flow.")


func _test_mirror_golem_copies_scarab_overflow_return() -> void:
	var target_cell: Vector2i = Vector2i(1, 0)
	var displaced_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 1, target_cell)
	var scarab_card: Dictionary = _place_card(UnitKeys.SKARABEY_NAME, 0, target_cell)
	var golem_card: Dictionary = _make_card(UnitKeys.ZERKALNYY_GOLEM_NAME, 0)
	game.players[0].hand.append(golem_card)

	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": target_cell
	})
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
	var stack: Array = game._get_stack_in_state(game._get_live_game_state(), target_cell)

	_assert_equal(String(result.status), game.RESULT_OK, "Mirror Golem play should succeed.")
	_assert_equal(stack.size(), 2, "Mirror Golem and Scarab should remain in the stack.")
	if stack.size() == 2:
		_assert_equal(int(stack[0].id), int(scarab_card.id), "Scarab should remain below Mirror Golem.")
		_assert_equal(int(stack[1].id), int(golem_card.id), "Mirror Golem should remain on top.")
	_assert_true(
		game._find_card_index_in_array(game.players[1].hand, int(displaced_card.id)) >= 0,
		"The creature displaced by Mirror Golem copying Scarab should return to its owner's hand."
	)
	_assert_equal(game.players[1].discard.size(), 0, "The displaced creature should not enter its owner's discard.")


func _test_primanka_uses_on_play_ability_symbol() -> void:
	var primanka: Resource = _find_unit(UnitKeys.PRIMANKA_NAME)
	_assert_equal(String(primanka.ability_symbols), "🃏", "Primanka should be marked as an on-play ability.")


func _test_manoprovod_counts_adjacent_face_down_paths() -> void:
	var manoprovod_cell: Vector2i = Vector2i(3, 2)
	_place_card(UnitKeys.MANOPROVOD_NAME, 0, manoprovod_cell)
	game._place_card(_make_card(UnitKeys.RYTSAR_NAME, 0, true), Vector2i(2, 2))
	game._place_card(_make_card(UnitKeys.GRIBNIK_NAME, 0, true), Vector2i(4, 2))
	_place_card(UnitKeys.BARON_NAME, 0, Vector2i(3, 1))
	game._place_card(_make_card(UnitKeys.RYTSAR_NAME, 1, true), Vector2i(3, 3))

	_assert_equal(
		game._top_power_in_state(game._get_live_game_state(), manoprovod_cell),
		12,
		"Manoprovod should count adjacent uncovered friendly creatures regardless of whether they are face-up or paths."
	)


func _test_volk_replay_uses_normal_play_legality() -> void:
	var source_cell: Vector2i = Vector2i(1, 0)
	var attack_cell: Vector2i = Vector2i(0, 1)
	var blocked_cell: Vector2i = Vector2i(2, 1)
	var distant_cell: Vector2i = Vector2i(6, 0)
	var volk_card: Dictionary = _place_card(UnitKeys.VOLK_NAME, 0, source_cell)
	var covering_card: Dictionary = _place_card(UnitKeys.STENA_NAME, 1, source_cell)
	_place_card(UnitKeys.BASHNYA_NAME, 1, attack_cell)
	game._add_barrier_to_state(game._get_live_game_state(), game.players[0].base, blocked_cell)

	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.played_card = true
	result.card = covering_card
	result.cell = source_cell
	result.end_turn = true
	game.play_reaction_logic.apply_covered_card_reactions(game._get_live_game_state(), result)

	_assert_equal(
		int(volk_card.get("attack_power_override", -1)),
		int(covering_card.unit.power),
		"Volk should receive the covering creature's base strength before destination checks."
	)
	_assert_has_key(result, "pending_target", "A covered human Volk should ask for a replay destination.")
	if not result.has("pending_target"):
		return

	var actual_targets: Array = game.target_logic.get_legal_target_cells(
		game._get_live_game_state(),
		result.pending_target
	)
	var preview_state: Dictionary = game._duplicate_game_state(game._get_live_game_state())
	var preview_stack: Array = game._get_stack_in_state(preview_state, source_cell)
	var preview_card_index: int = game._find_card_index_in_array(preview_stack, int(volk_card.id))
	var preview_card: Dictionary = preview_stack[preview_card_index]
	preview_stack.remove_at(preview_card_index)
	preview_card.face_down = false
	var supply_result: Dictionary = game.supply_logic.calculate_supply_result(preview_state, int(preview_card.owner))
	var expected_targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if cell == source_cell:
				continue
			if game._can_play_card_in_state(preview_state, preview_card, cell, supply_result):
				expected_targets.append(cell)

	_assert_cells_equal_unordered(
		actual_targets,
		expected_targets,
		"Volk destinations should exactly match normal play legality after temporarily removing it."
	)
	_assert_false(actual_targets.has(source_cell), "Volk should not replay onto its source land.")
	_assert_true(
		actual_targets.has(attack_cell),
		"Volk should use the covering creature's strength when attacking at its new supplied land."
	)
	_assert_false(actual_targets.has(blocked_cell), "A barrier should make the blocked land unavailable to Volk.")
	_assert_false(actual_targets.has(distant_cell), "An unsupplied distant land should be unavailable to Volk.")


func _test_robot_uses_selected_hand_creature() -> void:
	var robot_card: Dictionary = _make_card(UnitKeys.ROBOT_NAME, 0)
	var first_card: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	var copied_card: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 0)
	game.players[0].hand.append(robot_card)
	game.players[0].hand.append(first_card)
	game.players[0].hand.append(copied_card)
	game.players[0].deck.append(_make_card(UnitKeys.BARON_NAME, 0))
	game.players[0].deck.append(_make_card(UnitKeys.AGITATOR_NAME, 0))

	game.pending_logic.begin_robot_copy(int(robot_card.id))
	_assert_equal(String(game.pending_logic.action), "robot_copy", "Robot should first ask which hand creature to reveal.")
	_assert_false(
		game.pending_logic.try_select_robot_copy_card(int(robot_card.id)),
		"Robot should not be able to copy itself."
	)
	_assert_true(
		game.pending_logic.try_select_robot_copy_card(int(copied_card.id)),
		"The explicitly clicked creature should become Robot's copy source."
	)
	_assert_equal(String(game.pending_logic.action), "hand", "After choosing a creature, Robot should ask for its play cell.")
	_assert_equal(
		game.pending_logic.get_robot_copy_card_id(int(robot_card.id)),
		int(copied_card.id),
		"Robot should retain the selected creature while choosing a cell."
	)

	var variants: Array = game._get_play_hand_variants_for_state(
		game._get_live_game_state(),
		0,
		0,
		false,
		{},
		int(copied_card.id)
	)
	_assert_false(variants.is_empty(), "Robot copying Gribnik should have a legal play cell.")
	if variants.is_empty():
		return
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variants[0])
	_assert_equal(String(result.status), game.RESULT_OK, "Robot play with an explicit copy source should succeed.")
	_assert_equal(String(result.ability_name_key), UnitKeys.GRIBNIK_NAME, "Robot should use the selected Gribnik ability.")
	_assert_equal(int(result.copied_card_id), int(copied_card.id), "Robot result should retain the revealed card identity.")
	_assert_equal(game.players[0].hand.size(), 4, "Robot copying Gribnik should draw two cards, not the first card's one.")
	_assert_true(
		game._find_card_index_in_array(game.players[0].hand, int(copied_card.id)) >= 0,
		"The revealed creature should remain in hand."
	)
	var played_robot: Dictionary = _top_card(result.cell)
	_assert_equal(String(played_robot.unit.name_key), UnitKeys.ROBOT_NAME, "The card placed on the board should still be Robot.")
	_assert_equal(
		int(played_robot.get("attack_power_override", -1)),
		int(copied_card.unit.power),
		"Robot should use the selected creature's strength."
	)
	var revealed_card_id: int = -1
	for event in result.events:
		if String(event.get("type", "")) == game.ANIMATION_REVEAL_HAND_CARD:
			revealed_card_id = int(event.card_id)
			break
	_assert_equal(revealed_card_id, int(copied_card.id), "Robot should reveal the explicitly selected creature.")


func _test_robot_copied_strength_controls_play_legality() -> void:
	var target_cell: Vector2i = Vector2i(0, 1)
	_place_card(UnitKeys.BASHNYA_NAME, 1, target_cell)
	var robot_card: Dictionary = _make_card(UnitKeys.ROBOT_NAME, 0)
	var copied_card: Dictionary = _make_card(UnitKeys.ISTUKAN_NAME, 0)
	game.players[0].hand.append(robot_card)
	game.players[0].hand.append(copied_card)

	var missing_copy_variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": target_cell
	})
	var missing_copy_result: Dictionary = game._apply_action_variant_to_state(
		game._get_live_game_state(),
		missing_copy_variant
	)
	_assert_equal(String(missing_copy_result.status), game.RESULT_INVALID, "Robot should not silently choose a hand card.")
	_assert_equal(String(missing_copy_result.error), "robot_copy_required", "Robot should report the missing explicit copy choice.")

	var variants: Array = game._get_play_hand_variants_for_state(
		game._get_live_game_state(),
		0,
		0,
		false,
		{},
		int(copied_card.id)
	)
	var attack_variant: Dictionary = {}
	for variant in variants:
		if variant.cell == target_cell:
			attack_variant = variant
			break
	_assert_false(attack_variant.is_empty(), "Robot should be able to attack strength 6 with copied strength 7.")
	if attack_variant.is_empty():
		return
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), attack_variant)
	_assert_equal(String(result.status), game.RESULT_OK, "Robot's copied-strength attack should succeed.")
	_assert_equal(int(_top_card(target_cell).id), int(robot_card.id), "Robot should cover the stronger enemy after copying strength 7.")


func _test_robot_preserves_copied_targeted_abilities() -> void:
	var robot_cell: Vector2i = Vector2i(0, 1)
	var enemy_cell: Vector2i = Vector2i(0, 0)
	var enemy_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 1, enemy_cell)
	var robot_card: Dictionary = _make_card(UnitKeys.ROBOT_NAME, 0)
	var copied_card: Dictionary = _make_card(UnitKeys.BOEVOY_MAG_NAME, 0)
	game.players[0].hand.append(robot_card)
	game.players[0].hand.append(copied_card)

	var variants: Array = game._get_play_hand_variants_for_state(
		game._get_live_game_state(),
		0,
		0,
		false,
		{},
		int(copied_card.id)
	)
	var play_variant: Dictionary = {}
	for variant in variants:
		if variant.cell == robot_cell:
			play_variant = variant
			break
	_assert_false(play_variant.is_empty(), "Robot copying Battle Mage should have the expected play cell.")
	if play_variant.is_empty():
		return
	var play_result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), play_variant)
	_assert_equal(String(play_result.status), game.RESULT_OK, "Robot copying Battle Mage should be played.")
	_assert_has_key(play_result, "pending_target", "Robot should preserve the copied targeted ability.")
	if not play_result.has("pending_target"):
		return
	_assert_equal(
		String(play_result.pending_target.ability_name_key),
		UnitKeys.BOEVOY_MAG_NAME,
		"Robot's copied identity should survive until target resolution."
	)
	_assert_true(
		game.target_logic._target_cards_have_card_id(game.target_logic.get_legal_target_cards(game._get_live_game_state(), play_result.pending_target), int(enemy_card.id)),
		"The copied Battle Mage ability should target the adjacent enemy."
	)
	var target_result: Dictionary = game.pending_logic._apply_card_target_to_current_state(play_result.pending_target, int(enemy_card.id))
	_assert_equal(String(target_result.status), game.RESULT_OK, "Robot's copied targeted ability should resolve.")
	_assert_true(
		game._find_card_index_in_array(game.players[1].discard, int(enemy_card.id)) >= 0,
		"Robot copying Battle Mage should discard the selected enemy."
	)


func _test_randomag_can_draw_robot() -> void:
	var randomag_card: Dictionary = _make_card(UnitKeys.RANDOMAG_NAME, 0)
	var copy_source: Dictionary = _make_card(UnitKeys.ISTUKAN_NAME, 0)
	var drawn_robot: Dictionary = _make_card(UnitKeys.ROBOT_NAME, 0)
	game.players[0].hand.append(randomag_card)
	game.players[0].hand.append(copy_source)
	game.players[0].deck.append(drawn_robot)

	var variants: Array = game._get_play_hand_variants_for_state(game._get_live_game_state(), 0, 0, false)
	_assert_false(variants.is_empty(), "Randomag should have a legal play cell before drawing Robot.")
	if variants.is_empty():
		return
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variants[0])
	_assert_has_key(result, "pending_extra_hand_play", "Randomag should allow the drawn Robot to be played.")
	if not result.has("pending_extra_hand_play"):
		return
	game.pending_logic.begin_extra_hand_play(result.pending_extra_hand_play)
	_assert_equal(String(game.pending_logic.action), "robot_copy", "A Robot drawn by Randomag should ask for its copy source.")
	_assert_equal(game.ui_selected_hand_card_id, int(drawn_robot.id), "The forced Robot should remain selected.")
	_assert_true(
		game.pending_logic.try_select_robot_copy_card(int(copy_source.id)),
		"The forced Robot should accept another creature as its copy source."
	)


func _test_hand_limit_overflow_is_discarded_by_owner_choice() -> void:
	var hand_cards: Array = []
	for i in range(game.MAX_HAND + 1):
		var card: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
		hand_cards.append(card)
		game.players[0].hand.append(card)
	game._sync_hand_card_views()

	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	game._apply_end_turn_rules_to_state(state, result)
	game._restore_game_state(state)
	_assert_has_key(result, "pending_hand_discard", "A human hand over its limit should pause end-turn cleanup for a choice.")
	_assert_equal(game.players[0].hand.size(), game.MAX_HAND + 1, "No hand card should be discarded before the owner chooses it.")
	_assert_equal(game.current_player, 0, "The turn should not pass until the owner finishes discarding excess cards.")
	if not result.has("pending_hand_discard"):
		return

	game.pending_logic.begin_hand_discard(result.pending_hand_discard)
	_assert_true(game.pending_logic.is_hand_limit_discard(), "The pending choice should be identified as end-turn hand cleanup.")
	var chosen_card: Dictionary = hand_cards[0]
	var formerly_last_card: Dictionary = hand_cards[hand_cards.size() - 1]
	await game.pending_logic.try_discard_hand_card(int(chosen_card.id))
	_assert_equal(game.players[0].hand.size(), game.MAX_HAND, "The hand should be reduced to its current limit.")
	_assert_true(
		game._find_card_index_in_array(game.players[0].discard, int(chosen_card.id)) >= 0,
		"The exact card selected by the owner should enter the discard."
	)
	_assert_true(
		game._find_card_index_in_array(game.players[0].hand, int(formerly_last_card.id)) >= 0,
		"End-turn cleanup should no longer discard the last hand card automatically."
	)
	_assert_equal(game.current_player, 1, "The turn should pass only after hand-limit cleanup is complete.")


func _test_ai_resolves_own_hand_limit_overflow() -> void:
	game.current_player = 1
	for i in range(game.MAX_HAND + 2):
		game.players[1].hand.append(_make_card(UnitKeys.RYTSAR_NAME, 1))
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	game._apply_end_turn_rules_to_state(state, result)
	game._restore_game_state(state)
	_assert_false(result.has("pending_hand_discard"), "AI hand cleanup should not wait for human input.")
	_assert_equal(game.players[1].hand.size(), game.MAX_HAND, "AI should discard exactly the cards above its hand limit.")
	_assert_equal(game.players[1].discard.size(), 2, "AI excess hand cards should enter its discard.")
	_assert_equal(game.current_player, 0, "AI turn should finish after automatic hand cleanup.")


func _test_ai_canonicalizes_order_independent_target_sequences() -> void:
	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0)
	for cell in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		_place_card(UnitKeys.RYTSAR_NAME, 0, cell)
	var lich_request: Dictionary = {
		"kind": "lich_flip_own",
		"target_type": "cell_sequence",
		"player_index": 0,
		"source_cell": Vector2i(6, 4),
		"card_id": -1,
		"count": 0
	}
	var lich_variants: Array = game._expand_variant_with_target_sequence(
		game._get_live_game_state(),
		lich_request,
		variant,
		[]
	)
	_assert_equal(lich_variants.size(), 16, "Lich should evaluate each target subset once instead of every ordering.")

	_initialize_empty_board()
	variant = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0)
	_place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(0, 0))
	_place_card(UnitKeys.GRIBNIK_NAME, 0, Vector2i(2, 0))
	var trubadur_request: Dictionary = {
		"kind": "trubadur_return_own",
		"target_type": "cell_sequence",
		"player_index": 0,
		"source_cell": Vector2i(6, 4),
		"card_id": -1
	}
	var trubadur_variants: Array = game._expand_variant_with_target_sequence(
		game._get_live_game_state(),
		trubadur_request,
		variant,
		[]
	)
	_assert_equal(trubadur_variants.size(), 4, "Trubadur should evaluate each returned-card set once instead of every ordering.")

	_initialize_empty_board()
	variant = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0)
	var primanka_cell: Vector2i = Vector2i(3, 2)
	var primanka_card: Dictionary = _place_card(UnitKeys.PRIMANKA_NAME, 0, primanka_cell)
	_place_card(UnitKeys.RYTSAR_NAME, 1, Vector2i(2, 2))
	_place_card(UnitKeys.GRIBNIK_NAME, 1, Vector2i(4, 2))
	var primanka_request: Dictionary = {
		"kind": "primanka_pull",
		"target_type": "cell_sequence",
		"player_index": 0,
		"source_cell": primanka_cell,
		"card_id": int(primanka_card.id)
	}
	var primanka_variants: Array = game._expand_variant_with_target_sequence(
		game._get_live_game_state(),
		primanka_request,
		variant,
		[]
	)
	_assert_equal(primanka_variants.size(), 2, "Primanka must pull both top creatures and evaluate both stack orders.")


func _test_duh_buri_waits_for_opponent_choice() -> void:
	game.current_player = 1
	var first_human_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(0, 0))
	var second_human_card: Dictionary = _place_card(UnitKeys.GRIBNIK_NAME, 0, Vector2i(2, 0))
	var duh_buri_card: Dictionary = _make_card(UnitKeys.DUH_BURI_NAME, 1)
	game.players[1].hand.append(duh_buri_card)

	var base_variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 1, {
		"hand_index": 0,
		"cell": Vector2i(5, 2)
	})
	var expanded_variants: Array = game._expand_variant_with_target_choices(game._get_live_game_state(), base_variant)
	_assert_equal(expanded_variants.size(), 1, "AI should not expand choices that belong to the opponent.")
	if expanded_variants.is_empty():
		return
	var variant: Dictionary = expanded_variants[0]
	variant.target_cell = Vector2i(0, 0)
	variant.payload = Dictionary(variant.payload).duplicate(true)
	variant.payload.target_cell = Vector2i(0, 0)
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)

	_assert_has_key(result, "pending_target", "Duh Buri should leave a target choice for the opponent.")
	if result.has("pending_target"):
		_assert_equal(int(result.pending_target.decision_player), 0, "The human opponent should own the Duh Buri decision.")
	var ai_metrics: Dictionary = game.ai_logic._score_candidate_state(
		game._duplicate_game_state(game._get_live_game_state()),
		result,
		1
	)
	_assert_has_key(ai_metrics, "score", "AI should evaluate the opponent's worst legal Duh Buri response.")
	_assert_has_key(ai_metrics, "own_tempo", "Duh Buri response evaluation should retain tempo tiebreak data.")
	_assert_false(bool(first_human_card.face_down), "Duh Buri must not automatically flip the first human creature.")
	_assert_false(bool(second_human_card.face_down), "Duh Buri must not automatically flip the second human creature.")
	_assert_equal(game.current_player, 1, "The AI turn should remain pending until the opponent chooses.")

	game.pending_logic.begin_target(result.pending_target)
	_assert_true(
		game._pending_action_belongs_to_view_player(),
		"The human view player should be allowed to interact with the board during the AI's pending Duh Buri effect."
	)
	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	await game._on_board_cell_gui_input(click_event, game.board_cells[Vector2i(0, 0)])
	_assert_true(bool(_top_card(Vector2i(0, 0)).face_down), "The creature selected for Duh Buri should turn face-down.")
	_assert_false(bool(_top_card(Vector2i(2, 0)).face_down), "Duh Buri should only turn the selected creature face-down.")
	_assert_equal(game.current_player, 0, "The turn should pass to the human after resolving the Duh Buri choice.")


func _test_vihr_target_flow() -> void:
	var vihr_card: Dictionary = _make_card(UnitKeys.VIHR_NAME, 0)
	game.players[0].hand.append(vihr_card)
	var left_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(0, 0))
	var right_card: Dictionary = _place_card(UnitKeys.GRIBNIK_NAME, 0, Vector2i(2, 0))

	game.ui_selected_hand_card_id = int(vihr_card.id)
	game.pending_logic.action = "hand"
	var playable_cells: Dictionary = game._get_playable_cells_for_ui_pending_action()
	_assert_true(playable_cells.has(Vector2i(1, 0)), "Selecting Vihr should only compute playable cells and include the supplied target.")

	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": Vector2i(1, 0)
	})
	var play_result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
	_assert_equal(String(play_result.status), game.RESULT_OK, "Vihr play should succeed.")
	_assert_has_key(play_result, "pending_target", "Vihr play should ask for a target sequence.")

	var request: Dictionary = play_result.pending_target
	_assert_cells_equal_unordered(
		game.target_logic.get_legal_target_cells(game._get_live_game_state(), request),
		[Vector2i(0, 0), Vector2i(2, 0)],
		"Vihr first target should be a non-empty neighboring stack."
	)

	var first_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), request, Vector2i(0, 0))
	_assert_has_key(first_result, "pending_target", "Vihr should ask for the second swap location.")
	_assert_false(
		game.target_logic.can_finish_choice_request(first_result.pending_target),
		"Vihr should not allow finishing after selecting only the first stack."
	)

	var second_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), first_result.pending_target, Vector2i(2, 0))
	_assert_has_key(second_result, "pending_target", "Vihr should remain pending after a completed swap.")
	_assert_equal(int(_top_card(Vector2i(0, 0)).id), int(right_card.id), "Vihr should move the right stack to the left cell.")
	_assert_equal(int(_top_card(Vector2i(2, 0)).id), int(left_card.id), "Vihr should move the left stack to the right cell.")
	_assert_true(
		game.target_logic.can_finish_choice_request(second_result.pending_target),
		"Vihr should allow finishing after a completed swap pair."
	)


func _test_sporovik_two_phase_choice() -> void:
	var sporovik_card: Dictionary = _make_card(UnitKeys.SPOROVIK_NAME, 0)
	game.players[0].hand.append(sporovik_card)
	_place_full_stack(UnitKeys.RYTSAR_NAME, 0, Vector2i(1, 0))
	_place_full_stack(UnitKeys.GRIBNIK_NAME, 0, Vector2i(2, 0))
	_place_full_stack(UnitKeys.RYTSAR_NAME, 1, Vector2i(4, 0))
	_place_full_stack(UnitKeys.GRIBNIK_NAME, 1, Vector2i(5, 0))
	_place_full_stack(UnitKeys.BARON_NAME, 1, Vector2i(6, 0))

	var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, 0, {
		"hand_index": 0,
		"cell": Vector2i(0, 1)
	})
	var play_result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
	_assert_equal(String(play_result.status), game.RESULT_OK, "Sporovik play should succeed.")
	_assert_has_key(play_result, "pending_target", "Sporovik should ask for own full stacks.")

	var own_request: Dictionary = play_result.pending_target
	_assert_equal(String(own_request.kind), "sporovik_own_full_stack", "Sporovik first phase should target own stacks.")
	_assert_cells_equal_unordered(
		game.target_logic.get_legal_target_cells(game._get_live_game_state(), own_request),
		[Vector2i(1, 0), Vector2i(2, 0)],
		"Sporovik should find own full stacks."
	)

	var first_own_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), own_request, Vector2i(1, 0))
	_assert_has_key(first_own_result, "pending_target", "Sporovik should continue after the first own stack.")
	var second_own_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), first_own_result.pending_target, Vector2i(2, 0))
	_assert_has_key(second_own_result, "pending_target", "Sporovik should continue until the player presses done.")
	_assert_equal(game.players[0].discard.size(), 2, "Sporovik should discard selected own top cards immediately.")

	var finish_own_result: Dictionary = game.target_logic.finish_choice(game._get_live_game_state(), second_own_result.pending_target)
	_assert_has_key(finish_own_result, "pending_target", "Sporovik should start enemy phase after done.")
	var enemy_request: Dictionary = finish_own_result.pending_target
	_assert_equal(String(enemy_request.kind), "sporovik_enemy_full_stack", "Sporovik second phase should target enemy stacks.")
	_assert_equal(int(enemy_request.own_count), 2, "Sporovik enemy phase should remember own selected count.")
	_assert_cells_equal_unordered(
		game.target_logic.get_legal_target_cells(game._get_live_game_state(), enemy_request),
		[Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)],
		"Sporovik should find enemy full stacks."
	)

	var first_enemy_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), enemy_request, Vector2i(4, 0))
	_assert_has_key(first_enemy_result, "pending_target", "Sporovik should require the same number of enemy stacks.")
	var second_enemy_result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), first_enemy_result.pending_target, Vector2i(5, 0))
	_assert_false(second_enemy_result.has("pending_target"), "Sporovik should finish after matching own stack count.")
	_assert_equal(game.players[1].discard.size(), 2, "Sporovik should discard the selected enemy top cards.")


func _test_randomag_draws_extra_play_card_into_hand() -> void:
	var randomag_card: Dictionary = _make_card(UnitKeys.RANDOMAG_NAME, 0)
	var other_card: Dictionary = _make_card(UnitKeys.BARON_NAME, 0)
	var drawn_card: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	game.players[0].hand.append(randomag_card)
	game.players[0].hand.append(other_card)
	game.players[0].deck.append(drawn_card)

	var variants: Array = game._get_play_hand_variants_for_state(game._get_live_game_state(), 0, 0, false)
	_assert_false(variants.is_empty(), "Randomag should have at least one legal play cell.")
	if variants.is_empty():
		return
	var variant: Dictionary = variants[0]
	var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
	_assert_equal(String(result.status), game.RESULT_OK, "Randomag play should succeed.")
	_assert_false(result.has("pending_target"), "Randomag should not ask for a direct deck target.")
	_assert_has_key(result, "pending_extra_hand_play", "Randomag should start a normal extra hand play.")
	if not result.has("pending_extra_hand_play"):
		return
	_assert_equal(game.players[0].deck.size(), 0, "Randomag should move the top deck card out of the deck.")
	_assert_true(
		game._find_card_index_in_array(game.players[0].hand, int(drawn_card.id)) >= 0,
		"Randomag should draw the top deck card into hand before it is played."
	)

	var extra_request: Dictionary = result.pending_extra_hand_play
	_assert_equal(int(extra_request.forced_card_id), int(drawn_card.id), "Randomag should force the drawn card for the extra play.")
	game.pending_logic.begin_extra_hand_play(extra_request)
	_assert_equal(game.ui_selected_hand_card_id, int(drawn_card.id), "Randomag should auto-select the drawn card.")
	_assert_true(game.pending_logic.is_hand_card_inactive(other_card), "Randomag should make other hand cards inactive.")
	_assert_false(game.pending_logic.is_hand_card_inactive(drawn_card), "Randomag should keep the drawn card active.")
	_assert_false(
		game._get_playable_cells_for_ui_pending_action().is_empty(),
		"Randomag drawn card should expose normal hand-play cells."
	)


func _test_repeating_target_autofinishes_without_legal_targets() -> void:
	var trubadur_card: Dictionary = _make_card(UnitKeys.TRUBADUR_NAME, 0)
	var returned_card: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(3, 1))
	game.players[0].hand.append(trubadur_card)

	var variants: Array = game._get_play_hand_variants_for_state(game._get_live_game_state(), 0, 0, false)
	_assert_false(variants.is_empty(), "Trubadur should have at least one legal play cell.")
	var play_variant: Dictionary = {}
	for variant in variants:
		if variant.cell != Vector2i(3, 1):
			play_variant = variant
			break
	_assert_false(play_variant.is_empty(), "Trubadur should have a legal play cell away from the return target.")
	if play_variant.is_empty():
		return
	var play_result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), play_variant)
	_assert_equal(String(play_result.status), game.RESULT_OK, "Trubadur play should succeed.")
	_assert_has_key(play_result, "pending_target", "Trubadur should ask for return targets while one exists.")
	if not play_result.has("pending_target"):
		return

	var request: Dictionary = play_result.pending_target
	_assert_cells_equal_unordered(
		game.target_logic.get_legal_target_cells(game._get_live_game_state(), request),
		[Vector2i(3, 1)],
		"Trubadur should only be able to return the one other own top card."
	)

	var target_result: Dictionary = game.pending_logic._apply_target_to_current_state(request, Vector2i(3, 1))
	_assert_equal(String(target_result.status), game.RESULT_OK, "Trubadur target should succeed.")
	_assert_false(target_result.has("pending_target"), "Trubadur should auto-finish when no return targets remain.")
	_assert_equal(game.current_player, 1, "Trubadur auto-finish should end the turn.")
	_assert_true(
		game._find_card_index_in_array(game.players[0].hand, int(returned_card.id)) >= 0,
		"Trubadur should return the selected card to hand."
	)


func _test_solo_deck_and_plan() -> void:
	game.game_mode = game.GAME_MODE_SOLO
	game.current_player = 0
	game.minor_actions_spent = 0
	game._setup_game()

	_assert_equal(String(game.players[1].name), "Осколочный отряд", "Solo mode should use its own enemy identity.")
	var template: Array = game.players[1].deck_template
	_assert_equal(template.size(), 7, "Solo combat deck should contain one enemy of each power from 1 to 7.")
	var first_enemy: UnitResource = template[0]
	_assert_equal(first_enemy.get_display_name(), "Осколочник", "Solo enemies should use their own display name.")
	_assert_equal(
		String(first_enemy.portrait.resource_path),
		"res://assets/cards/card_oskolchnik.png",
		"Solo enemies should use their own portrait instead of a regular unit asset."
	)
	var power_counts: Dictionary = {}
	for unit in template:
		var power: int = int(unit.power)
		power_counts[power] = int(power_counts.get(power, 0)) + 1
		_assert_equal(String(unit.ability_symbols), "", "Solo enemies should have no ability symbols.")
	for power in range(1, 8):
		_assert_equal(int(power_counts.get(power, 0)), 1, "Solo combat deck should contain each enemy power exactly once.")

	_assert_equal(game.players[1].deck.size(), 6, "A wave should consume only one card from the seven-card combat deck.")
	_assert_equal(game.players[1].hand.size(), 3, "A solo wave should prepare one combat card and two separate path cards.")
	_assert_equal(game.solo_logic.plan.size(), 3, "Each solo wave should contain one combat action and two path actions.")
	var combat_entries: Array = []
	var path_entries: Array = []
	for entry in game.solo_logic.plan:
		if String(entry.kind) == game.solo_logic.PLAN_KIND_PATH:
			path_entries.append(entry)
		else:
			combat_entries.append(entry)
	_assert_equal(combat_entries.size(), 1, "A solo wave should contain exactly one combat card.")
	_assert_equal(path_entries.size(), 2, "A solo wave should contain exactly two separately generated paths.")
	_assert_equal(game.solo_logic.path_power_deck.size(), 5, "Two paths should come from their own rotating seven-power pool.")
	for entry in combat_entries:
		var combat_card: Dictionary = game._find_card_by_id_in_array(game.players[1].hand, int(entry.card_id))
		_assert_false(bool(combat_card.face_down), "The planned combat card should remain face-up in game state.")
	for entry in path_entries:
		var path_card: Dictionary = game._find_card_by_id_in_array(game.players[1].hand, int(entry.card_id))
		_assert_true(bool(path_card.face_down), "Separately generated path cards should be face-down.")
	var reserved_cells: Dictionary = {}
	var state: Dictionary = game._get_live_game_state()
	var supply_result: Dictionary = game.supply_logic.calculate_supply_result(state, 1)
	for entry in game.solo_logic.get_visible_plan():
		var cell: Vector2i = entry.cell
		var card: Dictionary = game._find_card_by_id_in_array(game.players[1].hand, int(entry.card_id))
		_assert_false(reserved_cells.has(cell), "Solo plan should not target the same land twice in one wave.")
		reserved_cells[cell] = true
		if String(entry.kind) == game.solo_logic.PLAN_KIND_PATH:
			_assert_true(
				game.solo_logic.can_play_path_at_cell(state, card, cell, supply_result),
				"Every highlighted solo path should be legal when the plan is created."
			)
		else:
			_assert_true(
				game.solo_logic.can_play_at_cell(state, card, cell, supply_result),
				"Every highlighted solo combat target should be legal when the plan is created."
			)
	game.players[1].deck.clear()
	_assert_true(
		game._refill_deck_if_empty_in_state(game._get_live_game_state(), 1),
		"An exhausted solo deck should be recreated from its bounded template."
	)
	_assert_equal(game.players[1].deck.size(), 7, "A recreated solo combat deck should again contain all seven powers.")
	game.game_mode = game.GAME_MODE_AI
	game.solo_logic.reset()


func _test_solo_plan_keeps_one_enemy_wave() -> void:
	game.game_mode = game.GAME_MODE_SOLO
	game.current_player = 1
	var first_target: Vector2i = Vector2i(5, 2)
	var second_target: Vector2i = Vector2i(4, 3)
	var third_target: Vector2i = Vector2i(6, 3)
	var first_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(2), 1)
	var second_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(3), 1, true)
	var third_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(4), 1, true)
	game.players[1].hand.append(first_card)
	game.players[1].hand.append(second_card)
	game.players[1].hand.append(third_card)
	var first_entry: Dictionary = {
		"card_id": int(first_card.id),
		"kind": game.solo_logic.PLAN_KIND_COMBAT,
		"power": 2,
		"cell": first_target
	}
	var second_entry: Dictionary = {
		"card_id": int(second_card.id),
		"kind": game.solo_logic.PLAN_KIND_PATH,
		"power": 0,
		"cell": second_target
	}
	var third_entry: Dictionary = {
		"card_id": int(third_card.id),
		"kind": game.solo_logic.PLAN_KIND_PATH,
		"power": 0,
		"cell": third_target
	}
	game.solo_logic.plan = [second_entry, third_entry]
	game.solo_logic.begin_resolution()

	var first_result: Dictionary = game._apply_solo_plan_entry_to_current_state(first_entry)
	_assert_equal(String(first_result.status), game.RESULT_OK, "The first solo plan card should be played.")
	_assert_equal(game.current_player, 1, "The enemy turn should remain active while planned cards remain.")
	_assert_equal(int(_top_card(first_target).id), int(first_card.id), "The first planned enemy should enter its target land.")

	var path_entry: Dictionary = game.solo_logic.pop_next_entry()
	var path_result: Dictionary = game._apply_solo_plan_entry_to_current_state(path_entry)
	_assert_equal(String(path_result.status), game.RESULT_OK, "The first planned path should be played.")
	_assert_equal(game.current_player, 1, "The enemy turn should remain active until both planned paths resolve.")
	_assert_true(bool(_top_card(second_target).face_down), "The first separate path card should enter play face-down.")

	var final_entry: Dictionary = game.solo_logic.pop_next_entry()
	var final_result: Dictionary = game._apply_solo_plan_entry_to_current_state(final_entry)
	_assert_equal(String(final_result.status), game.RESULT_OK, "The final solo plan card should be played.")
	_assert_equal(game.current_player, 0, "The whole solo wave should hand the turn back after its final card.")
	_assert_equal(int(_top_card(third_target).id), int(third_card.id), "The final separate path should enter its target land.")
	_assert_true(bool(_top_card(third_target).face_down), "The final separate path card should enter play face-down.")
	game.game_mode = game.GAME_MODE_AI
	game.solo_logic.reset()


func _test_solo_plan_excludes_enemy_controlled_cells() -> void:
	game.game_mode = game.GAME_MODE_SOLO
	game.current_player = game.solo_logic.ENEMY_PLAYER_INDEX
	var enemy_base: Vector2i = game.players[game.solo_logic.ENEMY_PLAYER_INDEX].base
	var controlled_cell: Vector2i = enemy_base + Vector2i.LEFT
	var open_cell: Vector2i = enemy_base + Vector2i.UP
	_place_card(UnitKeys.RYTSAR_NAME, game.solo_logic.ENEMY_PLAYER_INDEX, controlled_cell)
	var enemy_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(3), game.solo_logic.ENEMY_PLAYER_INDEX)
	var state: Dictionary = game._get_live_game_state()
	var supply_result: Dictionary = game.supply_logic.calculate_supply_result(
		state,
		game.solo_logic.ENEMY_PLAYER_INDEX
	)

	_assert_true(
		game._can_play_card_in_state(state, enemy_card, controlled_cell, supply_result),
		"Normal play legality should allow reinforcing an own controlled stack."
	)
	var candidates: Array = game.solo_logic._get_available_cells(state, enemy_card, {}, supply_result)
	_assert_false(
		candidates.has(controlled_cell),
		"Solo planning should remove cells already controlled by the enemy from its move candidates."
	)
	_assert_true(
		candidates.has(open_cell),
		"Solo planning should retain an otherwise legal supplied open cell."
	)
	_assert_false(
		game.solo_logic.can_play_at_cell(state, enemy_card, controlled_cell, supply_result),
		"Solo resolution should also reject a target that is controlled by the enemy."
	)
	game.game_mode = game.GAME_MODE_AI
	game.solo_logic.reset()


func _test_solo_combat_prioritizes_base_then_attacks() -> void:
	game.game_mode = game.GAME_MODE_SOLO
	game.current_player = game.solo_logic.ENEMY_PLAYER_INDEX
	var enemy_index: int = game.solo_logic.ENEMY_PLAYER_INDEX
	var player_index: int = game._opponent(enemy_index)
	var enemy_base: Vector2i = game.players[enemy_index].base
	var player_base: Vector2i = game.players[player_index].base
	var attack_cell: Vector2i = enemy_base + Vector2i.UP
	_place_card(UnitKeys.RYTSAR_NAME, player_index, attack_cell)
	var enemy_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(7), enemy_index)
	var state: Dictionary = game._get_live_game_state()
	var supply_result: Dictionary = game.supply_logic.calculate_supply_result(state, enemy_index)
	var target: Vector2i = game.solo_logic._choose_combat_target(state, enemy_card, {}, supply_result)
	_assert_equal(target, attack_cell, "The combat card should attack a legal player-controlled cell instead of taking open land.")

	for route_cell in [
		Vector2i(4, 3),
		Vector2i(3, 3),
		Vector2i(2, 3),
		Vector2i(1, 3),
		Vector2i(1, 2)
	]:
		_place_card(UnitKeys.RYTSAR_NAME, enemy_index, route_cell)
	state = game._get_live_game_state()
	supply_result = game.supply_logic.calculate_supply_result(state, enemy_index)
	target = game.solo_logic._choose_combat_target(state, enemy_card, {}, supply_result)
	_assert_equal(target, player_base, "A supplied player base should take priority over every other combat target.")
	game.game_mode = game.GAME_MODE_AI
	game.solo_logic.reset()


func _test_blocked_solo_plan_card_is_skipped() -> void:
	game.game_mode = game.GAME_MODE_SOLO
	game.current_player = 1
	var target: Vector2i = Vector2i(5, 2)
	var enemy_card: Dictionary = game._make_card(game.solo_logic.get_unit_for_power(3), 1)
	game.players[1].hand.append(enemy_card)
	_assert_true(
		game._can_play_card_in_state(game._get_live_game_state(), enemy_card, target),
		"The solo target should be legal when originally planned."
	)
	var blocking_card: Dictionary = _place_card(UnitKeys.STENA_NAME, 0, target)
	var entry: Dictionary = {
		"card_id": int(enemy_card.id),
		"power": 3,
		"cell": target
	}
	game.solo_logic.plan.clear()
	game.solo_logic.begin_resolution()

	var result: Dictionary = game._apply_solo_plan_entry_to_current_state(entry)
	_assert_equal(String(result.status), game.RESULT_OK, "A blocked solo action should resolve as a skipped plan entry.")
	_assert_true(bool(result.get("solo_skipped", false)), "The blocked solo action should be marked as skipped.")
	_assert_equal(int(_top_card(target).id), int(blocking_card.id), "A stronger player card should remain on the blocked target.")
	_assert_true(
		game._find_card_index_in_array(game.players[1].discard, int(enemy_card.id)) >= 0,
		"The enemy card from an impossible plan entry should be consumed into the discard."
	)
	_assert_equal(game.current_player, 0, "A skipped final plan entry should still finish the enemy wave.")
	game.game_mode = game.GAME_MODE_AI
	game.solo_logic.reset()


func _test_board_grid_edge_lines_use_outer_gutters() -> void:
	var draw_logic = game.board_draw_logic
	var layer: Control = game.supply_line_layer
	var half_gap: float = float(game.CELL_GAP) * 0.5
	var first_rect: Rect2 = draw_logic._get_cell_rect_on_layer(Vector2i(0, 0), layer)
	var next_rect: Rect2 = draw_logic._get_cell_rect_on_layer(Vector2i(1, 0), layer)
	var last_rect: Rect2 = draw_logic._get_cell_rect_on_layer(Vector2i(game.GRID_WIDTH - 1, game.GRID_HEIGHT - 1), layer)
	var grid_rect: Rect2 = draw_logic._get_board_grid_line_rect_on_layer(layer)

	var left_line_x: float = draw_logic._get_board_grid_line_x_on_layer(0, layer, grid_rect)
	var inner_line_x: float = draw_logic._get_board_grid_line_x_on_layer(1, layer, grid_rect)
	var right_line_x: float = draw_logic._get_board_grid_line_x_on_layer(game.GRID_WIDTH, layer, grid_rect)
	var top_line_y: float = draw_logic._get_board_grid_line_y_on_layer(0, layer, grid_rect)
	var bottom_line_y: float = draw_logic._get_board_grid_line_y_on_layer(game.GRID_HEIGHT, layer, grid_rect)
	var expected_inner_line_x: float = ((first_rect.position.x + first_rect.size.x) + next_rect.position.x) * 0.5

	_assert_float_near(left_line_x, first_rect.position.x - half_gap, 0.01, "Left board grid line should sit in the outer gutter.")
	_assert_float_near(inner_line_x, expected_inner_line_x, 0.01, "Interior board grid line should sit between neighboring cells.")
	_assert_float_near(right_line_x, last_rect.position.x + last_rect.size.x + half_gap, 0.01, "Right board grid line should sit in the outer gutter.")
	_assert_float_near(top_line_y, first_rect.position.y - half_gap, 0.01, "Top board grid line should sit in the outer gutter.")
	_assert_float_near(bottom_line_y, last_rect.position.y + last_rect.size.y + half_gap, 0.01, "Bottom board grid line should sit in the outer gutter.")
	_assert_true(left_line_x < first_rect.position.x, "Left board grid line should not be drawn inside the first cell.")
	_assert_true(top_line_y < first_rect.position.y, "Top board grid line should not be drawn inside the first cell.")


func _test_action_status_uses_card_title_font() -> void:
	var status_font: Font = game.action_label.get_theme_font("font")
	_assert_equal(
		status_font.resource_path,
		"res://assets/fonts/RussoOne-Regular.ttf",
		"Action status should use the same font as card names."
	)
