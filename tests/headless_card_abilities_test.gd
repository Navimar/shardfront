extends SceneTree

const GameScene: PackedScene = preload("res://scenes/main.tscn")
const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")

var game: Node
var failures: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	game = GameScene.instantiate()
	root.add_child(game)
	await process_frame

	_run_test("Sliz copies Rytsar draw effect", Callable(self, "_test_sliz_copies_rytsar_draw_effect"))
	_run_test("Vihr target flow is finite and swaps neighbor stacks", Callable(self, "_test_vihr_target_flow"))
	_run_test("Sporovik asks for own stacks then enemy stacks", Callable(self, "_test_sporovik_two_phase_choice"))

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
	game.current_player = 0
	game.minor_actions_spent = 0
	game.game_over = false
	game.game_over_message = ""
	game.destroyed_base_owner = -1
	game.next_card_id = 1000
	game.pending_logic.clear()


func _find_unit(name_key: String) -> Resource:
	for unit in game._load_units([]):
		if String(unit.name_key) == name_key:
			return unit
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
