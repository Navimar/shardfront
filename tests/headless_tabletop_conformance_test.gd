extends "res://tests/headless_card_abilities_test.gd"


func _run() -> void:
	game = GameScene.instantiate()
	root.add_child(game)
	await process_frame
	for test in [
		"catalog", "recycle", "kochevniki", "primanka", "any_targets", "vsadnik_base",
		"golem_power", "golem_supply", "golem_defense", "robot_supply", "robot_trap",
		"hlamovnik", "hlamovnik_defense", "kladents", "podryvnik", "partizany",
		"assasin_hit", "assasin_miss", "opolchenie_cancel", "opolchenie_allow",
		"gondola_legality", "gondola_end_turn", "gondola_return", "taran", "barrier_limit", "avtopoezd_lower", "direct_cover", "movement_wins", "charodey", "kladents_ai_variant", "golem_sliz", "optional_avtopoezd", "varvar_recycle", "empty_deck_targets", "topolog_retained", "tower_any_base", "ballista_stack", "partizany_base_strength"
	]:
		_run_test(test, Callable(self, "_test_" + test))
	await _run_async_test("Option buttons preserve the selected choice", Callable(self, "_test_option_ui"))
	await _run_async_test("AI resolves Gondola's complete extra phase", Callable(self, "_test_gondola_ai"))
	if failures.is_empty():
		print("All tabletop conformance tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _request(kind: String, owner: int = 0, source: Vector2i = Vector2i(3, 2), source_id: int = -1) -> Dictionary:
	return {"kind": kind, "player_index": owner, "decision_player": owner, "source_player": owner, "source_cell": source, "card_id": source_id}


func _play(name: String, cell: Vector2i, payload: Dictionary = {}) -> Dictionary:
	var card: Dictionary = _make_card(name, int(game.current_player))
	game.players[game.current_player].hand.append(card)
	payload.hand_index = game.players[game.current_player].hand.size() - 1
	payload.cell = cell
	return game._apply_action_variant_to_state(game._get_live_game_state(), game._make_action_variant(game.ACTION_PLAY_HAND_CARD, game.current_player, payload))


func _test_catalog() -> void:
	_assert_equal(game._load_units(game.DECK_UNIT_STATUSES).size(), 89, "88 canonical cards and Topolog must be active.")
	_assert_equal(int(_find_unit(UnitKeys.PRIZYVATEL_NAME).power), 1, "Prizyvatel's base strength must be 1.")
	_assert_equal(_find_unit(UnitKeys.DEMON_NAME).get_display_name(), "Проглот", "Legacy Demon resource must display the canonical name.")
	_assert_true(_find_unit(UnitKeys.PODRYVNIK_NAME) != null, "Podryvnik must exist.")


func _test_recycle() -> void:
	var one: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	var two: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 0)
	game.players[0].discard = [one, two]
	game.players[0].deck_template = [_find_unit(UnitKeys.DRAKON_NAME)]
	var id_before: int = game.next_card_id
	game._draw_cards_in_state(game._get_live_game_state(), 0, 3)
	_assert_equal(game.players[0].hand.size(), 2, "Only the two discarded cards may be drawn.")
	_assert_equal(game.players[0].discard.size(), 0, "Recycled discard must be emptied.")
	_assert_equal(game.next_card_id, id_before, "Recycling must preserve identities.")
	_assert_false(game._can_draw_card_variant_in_state(game._get_live_game_state(), 0), "An exhausted deck and discard cannot draw.")


func _test_kochevniki() -> void:
	var base: Vector2i = game.players[1].base
	var neighbor: Vector2i = base + Vector2i.LEFT
	var targets: Array = game.target_logic.get_legal_target_cells(game._get_live_game_state(), _request("move_own_base_anywhere"))
	_assert_false(targets.has(base), "Kochevniki cannot move onto the enemy base.")
	_assert_false(targets.has(neighbor), "Kochevniki cannot move adjacent to the enemy base.")
	game._add_barrier(base, neighbor)
	targets = game.target_logic.get_legal_target_cells(game._get_live_game_state(), _request("move_own_base_anywhere"))
	_assert_true(targets.has(neighbor), "A barrier makes the lands non-adjacent under the canonical definition.")


func _test_primanka() -> void:
	var cell: Vector2i = Vector2i(3, 2)
	var lure: Dictionary = _place_card(UnitKeys.PRIMANKA_NAME, 0, cell)
	var bottom: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 1, Vector2i(2, 2))
	var first: Dictionary = _place_card(UnitKeys.GRIBNIK_NAME, 1, Vector2i(2, 2))
	var last: Dictionary = _place_card(UnitKeys.FOKUSNIK_NAME, 1, Vector2i(4, 2))
	var req: Dictionary = game.target_logic.get_target_request(game._get_live_game_state(), {"played_card": true, "card": lure, "cell": cell})
	_assert_false(game.target_logic.can_finish_choice_request(req), "Primanka's pulls are mandatory.")
	var result: Dictionary = game.target_logic.apply_target(game._get_live_game_state(), req, Vector2i(2, 2))
	_assert_equal(game._get_stack(Vector2i(2, 2)).size(), 1, "The previously covered creature must stay.")
	_assert_false(game.target_logic.get_legal_target_cells(game._get_live_game_state(), result.pending_target).has(Vector2i(2, 2)), "Primanka must not pull a newly exposed lower creature.")
	result = game.target_logic.apply_target(game._get_live_game_state(), result.pending_target, Vector2i(4, 2))
	_assert_false(result.has("pending_target"), "All captured tops resolve the effect.")
	_assert_equal(game._get_stack(cell)[0].id, lure.id, "Primanka must stay below the pulled creatures.")
	_assert_equal(game._get_stack(cell)[1].id, first.id, "The first chosen creature goes first.")
	_assert_equal(game._get_stack(cell)[2].id, last.id, "The last chosen creature is on top.")
	_assert_equal(game._get_stack(Vector2i(2, 2))[0].id, bottom.id, "Covered card identity must be preserved.")


func _test_any_targets() -> void:
	var cell: Vector2i = Vector2i(2, 2)
	var lower: Dictionary = _place_card(UnitKeys.VSADNIK_NAME, 1, cell)
	_place_card(UnitKeys.GRIBNIK_NAME, 0, cell)
	for kind in ["any_discard_adjacent_enemy", "any_return_adjacent", "any_move_adjacent", "any_discard_unsupplied_enemy", "partizany_weak"]:
		_assert_true(game.target_logic._target_cards_have_card_id(game.target_logic.get_legal_target_cards(game._get_live_game_state(), _request(kind)), lower.id), kind + " must allow the lower enemy creature.")
	var own: Dictionary = _place_closed(UnitKeys.RYTSAR_NAME, 0, Vector2i(4, 2))
	_place_card(UnitKeys.GRIBNIK_NAME, 1, Vector2i(4, 2))
	for kind in ["any_flip_own_up", "any_replace_own"]:
		_assert_true(game.target_logic._target_cards_have_card_id(game.target_logic.get_legal_target_cards(game._get_live_game_state(), _request(kind)), own.id), kind + " must allow the lower own creature.")


func _test_vsadnik_base() -> void:
	var target: Vector2i = game.players[1].base
	var lower: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, target + Vector2i.LEFT)
	_place_card(UnitKeys.GRIBNIK_NAME, 1, target + Vector2i.LEFT)
	var result: Dictionary = game.target_logic.apply_card_target(game._get_live_game_state(), _request("any_move_adjacent", 0, target + Vector2i.LEFT + Vector2i.UP), lower.id)
	_assert_true(result.has("pending_target"), "Vsadnik must select a destination after selecting a lower card.")
	result = game.pending_logic._apply_target_to_current_state(result.pending_target, target)
	_assert_true(game.game_over, "Movement onto the enemy base must win.")
	_assert_equal(game.destroyed_base_owner, 1, "The enemy base is captured.")


func _test_golem_power() -> void:
	var cell: Vector2i = Vector2i(0, 1)
	_place_card(UnitKeys.FEYA_NAME, 0, cell)
	var result: Dictionary = _play(UnitKeys.ZERKALNYY_GOLEM_NAME, cell)
	_assert_equal(game.power_logic.get_card_attack_power(result.card), int(result.card.unit.power), "Golem must not copy Feya's attack strength.")
	_assert_equal(game._top_power(cell), int(result.card.unit.power), "Golem must retain its base strength.")


func _test_golem_supply() -> void:
	var cell: Vector2i = Vector2i(6, 0)
	_place_card(UnitKeys.OBOZ_NAME, 0, cell)
	_place_card(UnitKeys.ZERKALNYY_GOLEM_NAME, 0, cell)
	_assert_true(game._get_supplied_cells(0).has(Vector2i(5, 0)), "Golem must copy Oboz's constant supply ability.")
	game._get_stack(cell).back().face_down = true
	_assert_false(game._get_supplied_cells(0).has(Vector2i(5, 0)), "Face-down Golem's copied constant ability is disabled.")


func _test_golem_defense() -> void:
	var cell: Vector2i = Vector2i(0, 1)
	_place_card(UnitKeys.MAGICHESKIY_SCHIT_NAME, 0, cell)
	var golem: Dictionary = _place_card(UnitKeys.ZERKALNYY_GOLEM_NAME, 0, cell)
	_assert_equal(game._top_power(cell), int(golem.unit.power), "Golem cannot copy the shield's defense ability.")


func _test_robot_supply() -> void:
	var cell: Vector2i = Vector2i(0, 1)
	var copied: Dictionary = _make_card(UnitKeys.OBOZ_NAME, 0)
	game.players[0].hand.append(copied)
	var result: Dictionary = _play(UnitKeys.ROBOT_NAME, cell, {"copied_card_id": copied.id})
	_assert_equal(game._top_power(cell), int(copied.unit.power), "Robot copies base strength for defense too.")
	game.players[0].base = Vector2i(6, 4)
	_assert_true(game._get_supplied_cells(0).has(Vector2i(0, 0)), "Robot's copied supply must persist beyond play.")
	_assert_equal(result.card.unit.name_key, UnitKeys.ROBOT_NAME, "Robot keeps its card identity.")


func _test_robot_trap() -> void:
	var cell: Vector2i = Vector2i(0, 1)
	var copied: Dictionary = _make_card(UnitKeys.MINA_NAME, 0)
	game.players[0].hand.append(copied)
	var result: Dictionary = _play(UnitKeys.ROBOT_NAME, cell, {"copied_card_id": copied.id})
	var cover: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, cell)
	game.play_reaction_logic.apply_covered_card_reactions(game._get_live_game_state(), {"played_card": true, "card": cover, "cell": cell})
	_assert_true(result.card.face_down, "Robot copying Mine must flip after its trap.")
	_assert_true(game._find_card_index_in_array(game.players[0].discard, cover.id) >= 0, "Robot's copied trap discards the covering card.")


func _test_hlamovnik() -> void:
	var chosen: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 1)
	game.players[1].discard.append(chosen)
	game.players[0].discard.append(_make_card(UnitKeys.RYTSAR_NAME, 0))
	game.players[0].deck.append(_make_card(UnitKeys.DRAKON_NAME, 0))
	game.players[0].deck.append(_make_card(UnitKeys.DRAKON_NAME, 0))
	var result: Dictionary = _play(UnitKeys.HLAMOVNIK_NAME, Vector2i(0, 1), {"copied_card_id": chosen.id})
	_assert_equal(game.players[0].hand.size(), 2, "Hlamovnik must copy the chosen enemy discard's two-card draw.")
	_assert_equal(game._top_power(result.cell), int(chosen.unit.power), "Hlamovnik copies strength for defense.")
	_assert_equal(game.players[1].discard.size(), 1, "Copying leaves the selected card in discard.")


func _test_hlamovnik_defense() -> void:
	var chosen: Dictionary = _make_card(UnitKeys.FEYA_NAME, 1)
	game.players[1].discard.append(chosen)
	var result: Dictionary = _play(UnitKeys.HLAMOVNIK_NAME, Vector2i(0, 1), {"copied_card_id": chosen.id})
	_assert_equal(game.power_logic.get_card_attack_power(result.card), int(chosen.unit.power), "Hlamovnik must copy Feya's base strength without its attack ability.")


func _test_kladents() -> void:
	var sword: Dictionary = _place_card(UnitKeys.KLADENETS_NAME, 0, Vector2i(0, 1))
	var target: Vector2i = Vector2i(0, 0)
	_place_card(UnitKeys.DRAKON_NAME, 1, target)
	var attacker: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	_assert_false(game._can_play_card_in_state(game._get_live_game_state(), attacker, target), "Face-up Kladents grants no automatic attack bonus.")
	game.tabletop_logic.apply_extra_action(game._get_live_game_state(), sword.id)
	_assert_true(sword.face_down, "Explicit activation must flip Kladents.")
	_assert_true(game._can_play_card_in_state(game._get_live_game_state(), attacker, target), "Activated Kladents permits the stronger attack.")
	var result: Dictionary = _play(UnitKeys.RYTSAR_NAME, target)
	_assert_equal(result.status, game.RESULT_OK, "The boosted attack must resolve.")
	_assert_equal(int(game.players[0].next_attack_bonus), 0, "The bonus is consumed by the next play.")


func _test_podryvnik() -> void:
	var source: Vector2i = Vector2i(0, 1)
	var own: Dictionary = _place_card(UnitKeys.OBOZ_NAME, 0, Vector2i(0, 0))
	var lower: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 1, Vector2i(0, 2))
	var enemy: Dictionary = _place_card(UnitKeys.GRIBNIK_NAME, 1, Vector2i(0, 2))
	var blocked: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 1, Vector2i(1, 1))
	game._add_barrier(source, Vector2i(1, 1))
	var result: Dictionary = _play(UnitKeys.PODRYVNIK_NAME, source)
	_assert_equal(result.status, game.RESULT_OK, "Podryvnik play succeeds.")
	_assert_equal(game._get_stack(Vector2i(0, 0)).size(), 0, "Podryvnik also discards own neighbors.")
	_assert_equal(game._get_stack(Vector2i(0, 2))[0].id, lower.id, "Only the original enemy top is discarded.")
	_assert_equal(game._get_stack(Vector2i(1, 1))[0].id, blocked.id, "Barriers exclude neighboring lands.")
	_assert_true(game._find_card_index_in_array(game.players[0].discard, own.id) >= 0, "Own top enters own discard.")
	_assert_true(game._find_card_index_in_array(game.players[1].discard, enemy.id) >= 0, "Enemy top enters enemy discard.")


func _test_partizany() -> void:
	var weak: Dictionary = _place_card(UnitKeys.VSADNIK_NAME, 1, Vector2i(2, 2))
	_place_card(UnitKeys.GRIBNIK_NAME, 0, Vector2i(2, 2))
	var closed: Dictionary = _place_closed(UnitKeys.DRAKON_NAME, 1, Vector2i(4, 2))
	var req: Dictionary = _request("partizany_choose")
	var options: Array = game.tabletop_logic.choices(game._get_live_game_state(), req)
	_assert_equal(options.size(), 2, "Both branches must remain available.")
	var result: Dictionary = game.target_logic.apply_choice(game._get_live_game_state(), req, options[1])
	result = game.target_logic.apply_card_target(game._get_live_game_state(), result.pending_target, weak.id)
	_assert_equal(result.status, game.RESULT_OK, "The weak lower creature may be chosen.")
	_assert_equal(game._get_stack(Vector2i(4, 2))[0].id, closed.id, "Choosing weak does not discard the closed creature.")


func _test_assasin_hit() -> void:
	var card: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 1)
	game.players[1].hand.append(card)
	var req: Dictionary = _request("assasin_name")
	for choice in game.tabletop_logic.choices(game._get_live_game_state(), req):
		if choice.unit_id == card.unit.id:
			game.target_logic.apply_choice(game._get_live_game_state(), req, choice)
	_assert_equal(game.players[1].hand.size(), 0, "Naming a present creature discards it.")
	_assert_equal(game.players[1].discard[0].id, card.id, "Assasin preserves discarded identity.")


func _test_assasin_miss() -> void:
	game.players[1].hand.append(_make_card(UnitKeys.GRIBNIK_NAME, 1))
	var state: Dictionary = game._get_live_game_state()
	state.events = []
	var req: Dictionary = _request("assasin_name")
	for choice in game.tabletop_logic.choices(state, req):
		if choice.unit_id == _find_unit(UnitKeys.RYTSAR_NAME).id:
			game.target_logic.apply_choice(state, req, choice)
	_assert_equal(game.players[1].hand.size(), 1, "A missed name leaves the hand intact.")
	_assert_equal(state.events[0].type, "show_hand", "A missed name reveals the opponent's hand.")


func _base_attack_setup() -> Dictionary:
	var base: Vector2i = game.players[1].base
	_place_card(UnitKeys.OBOZ_NAME, 0, base + Vector2i.LEFT)
	game.players[1].hand.append(_make_card(UnitKeys.OPOLCHENIE_NAME, 1))
	game.players[0].deck.append(_make_card(UnitKeys.RYTSAR_NAME, 0))
	game.players[0].deck.append(_make_card(UnitKeys.RYTSAR_NAME, 0))
	return _play(UnitKeys.GRIBNIK_NAME, base)


func _test_opolchenie_cancel() -> void:
	var result: Dictionary = _base_attack_setup()
	_assert_false(game.game_over, "The declared attack must wait for the defender's decision.")
	_assert_equal(game.players[0].hand.size(), 1, "Attack declaration must not run Gribnik's draw.")
	var options: Array = game.tabletop_logic.choices(game._get_live_game_state(), result.pending_target)
	result = game.pending_logic._apply_choice_to_current_state(result.pending_target, options[0])
	_assert_false(game.game_over, "Using Opolchenie saves the base.")
	_assert_equal(game.players[0].hand.size(), 0, "The declared attacker is discarded.")
	_assert_equal(game.players[0].deck.size(), 2, "Canceled on-play effects never draw cards.")
	_assert_equal(game.players[1].discard.size(), 1, "Militia must enter discard.")


func _test_opolchenie_allow() -> void:
	var result: Dictionary = _base_attack_setup()
	var options: Array = game.tabletop_logic.choices(game._get_live_game_state(), result.pending_target)
	result = game.pending_logic._apply_choice_to_current_state(result.pending_target, options[1])
	_assert_true(game.game_over, "Declining Opolchenie permits the winning play.")
	_assert_equal(game.players[0].hand.size(), 2, "Allowed attack applies Gribnik's draw.")
	_assert_equal(game.players[1].hand.size(), 1, "Declining keeps Opolchenie in hand.")


func _test_gondola_legality() -> void:
	var card: Dictionary = _make_card(UnitKeys.GONDOLA_NAME, 0)
	var target: Vector2i = Vector2i(0, 1)
	_assert_true(game._can_play_card_in_state(game._get_live_game_state(), card, target), "Gondola may play on supplied empty land.")
	_place_closed(UnitKeys.RYTSAR_NAME, 1, target)
	_assert_false(game._can_play_card_in_state(game._get_live_game_state(), card, target), "Gondola cannot cover an enemy, even face down.")
	game._get_stack(target).clear()
	_place_card(UnitKeys.RYTSAR_NAME, 0, target)
	_assert_true(game._can_play_card_in_state(game._get_live_game_state(), card, target), "Gondola may cover an own creature.")


func _test_gondola_end_turn() -> void:
	var card: Dictionary = _make_card(UnitKeys.GONDOLA_NAME, 0)
	game.players[0].hand.append(card)
	var result: Dictionary = _play(UnitKeys.RYTSAR_NAME, Vector2i(0, 1))
	_assert_equal(game.current_player, 0, "Main play must leave the Gondola extra phase in the same turn.")
	_assert_equal(result.pending_target.kind, "gondola_end_turn", "Gondola's extra action is offered at end of turn.")
	var options: Array = game.tabletop_logic.choices(game._get_live_game_state(), result.pending_target)
	result = game.pending_logic._apply_choice_to_current_state(result.pending_target, options[0])
	_assert_equal(result.pending_target.kind, "gondola_place", "The player chooses Gondola's land next.")
	result = game.pending_logic._apply_target_to_current_state(result.pending_target, Vector2i(0, 0))
	_assert_equal(game._get_stack(Vector2i(0, 0))[0].id, card.id, "Extra play places the existing Gondola.")
	options = game.tabletop_logic.choices(game._get_live_game_state(), result.pending_target)
	result = game.pending_logic._apply_choice_to_current_state(result.pending_target, options.back())
	_assert_equal(game.current_player, 1, "Choosing Finish finally passes the turn.")


func _test_gondola_return() -> void:
	var lower: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(0, 1))
	var card: Dictionary = _place_card(UnitKeys.GONDOLA_NAME, 0, Vector2i(0, 1))
	var result: Dictionary = game.tabletop_logic.apply_extra_action(game._get_live_game_state(), card.id)
	_assert_false(result.end_turn, "Returning Gondola does not consume the main action.")
	_assert_equal(game.players[0].hand[0].id, card.id, "Gondola returns to hand.")
	_assert_equal(game._get_stack(Vector2i(0, 1))[0].id, lower.id, "The covered card is exposed.")


func _test_taran() -> void:
	var cell: Vector2i = Vector2i(3, 2)
	_place_card(UnitKeys.TARAN_NAME, 0, cell)
	game._add_barrier(cell, Vector2i(2, 2))
	_assert_false(game._has_barrier(cell, Vector2i(2, 2)), "A newly added barrier next to Taran is immediately destroyed.")
	_place_card(UnitKeys.ZERKALNYY_GOLEM_NAME, 0, cell)
	game._add_barrier(cell, Vector2i(4, 2))
	_assert_false(game._has_barrier(cell, Vector2i(4, 2)), "Golem copies Taran's permanent barrier destruction.")


func _test_barrier_limit() -> void:
	for edge in game._get_all_board_edges():
		if game._get_barrier_edges_in_state(game._get_live_game_state()).size() >= 12:
			break
		game._add_barrier(edge[0], edge[1])
	_assert_equal(game.target_logic.get_legal_target_choices(game._get_live_game_state(), _request("add_barrier")).size(), 0, "All 12 components on board means Builder cannot add another.")


func _test_avtopoezd_lower() -> void:
	var cell: Vector2i = Vector2i(3, 2)
	var lower: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, cell)
	var top: Dictionary = _place_card(UnitKeys.GRIBNIK_NAME, 1, cell)
	var replacement: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 0)
	game.players[0].hand.append(replacement)
	var result: Dictionary = game.target_logic.apply_card_target(game._get_live_game_state(), _request("any_replace_own"), lower.id)
	game.target_logic.apply_hand_pick(game._get_live_game_state(), result.pending_hand_pick, 0)
	_assert_equal(game._get_stack(cell)[0].id, replacement.id, "Replacement occupies the chosen lower position.")
	_assert_equal(game._get_stack(cell)[1].id, top.id, "Upper card stays in position.")
	_assert_equal(game.players[0].hand.size(), 1, "Replaced card returns to hand without the new card's draw ability.")


func _test_direct_cover() -> void:
	var cell: Vector2i = Vector2i(3, 2)
	_place_card(UnitKeys.RYTSAR_NAME, 0, cell)
	_place_card(UnitKeys.GRIBNIK_NAME, 1, cell)
	var caster: Dictionary = _place_card(UnitKeys.ZAKLINATEL_NAME, 0, cell)
	_assert_true(game.target_logic._get_covered_own_card_info(game._get_live_game_state(), _request("play_covered_own_card", 0, cell, caster.id)).is_empty(), "Zaklinatel cannot search below the directly covered enemy for an own card.")


func _test_movement_wins() -> void:
	game.players[1].hand.append(_make_card(UnitKeys.OPOLCHENIE_NAME, 1))
	_place_card(UnitKeys.RYTSAR_NAME, 0, game.players[1].base)
	var state: Dictionary = game._get_live_game_state()
	game._check_base_capture_in_state(state)
	game._restore_game_state(state)
	_assert_true(game.game_over, "Any placement on the opposing base wins, even outside ordinary play.")
	_assert_equal(game.players[1].hand.size(), 1, "Opolchenie responds to declared plays, not movement.")


func _place_closed(name: String, owner: int, cell: Vector2i) -> Dictionary:
	var card: Dictionary = _place_card(name, owner, cell)
	card.face_down = true
	return card


func _test_charodey() -> void:
	var target: Vector2i = Vector2i(0, 1)
	_place_card(UnitKeys.DRAKON_NAME, 1, target)
	var payment: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	game.players[0].hand.append(payment)
	var result: Dictionary = _play(UnitKeys.CHARODEY_NAME, target, {"charodey_discard_id": payment.id})
	_assert_equal(result.status, game.RESULT_OK, "Charodey may pay for +10 before validating an attack.")
	_assert_equal(game.players[0].discard[0].id, payment.id, "The selected payment is discarded.")
	_assert_equal(game._top_power(target), 5, "Attack payment does not increase Charodey's defense.")
	_assert_false(result.has("pending_hand_discard"), "There is no second payment after the attack.")


func _test_kladents_ai_variant() -> void:
	var sword: Dictionary = _place_card(UnitKeys.KLADENETS_NAME, 0, Vector2i(0, 1))
	var target: Vector2i = Vector2i(0, 0)
	_place_card(UnitKeys.DRAKON_NAME, 1, target)
	game.players[0].hand.append(_make_card(UnitKeys.RYTSAR_NAME, 0))
	var found: bool = false
	for variant in game._get_turn_variants_for_state(game._get_live_game_state(), 0):
		if variant.type == game.ACTION_PLAY_HAND_CARD and variant.cell == target and variant.payload.has("activate_kladents_id"):
			_assert_equal(variant.payload.activate_kladents_id, sword.id, "Boosted AI attack must identify its Kladents payment.")
			var result: Dictionary = game._apply_action_variant_to_state(game._get_live_game_state(), variant)
			_assert_equal(result.status, game.RESULT_OK, "AI's combined free activation and main attack must resolve.")
			_assert_true(sword.face_down, "AI must actually pay by flipping Kladents.")
			found = true
			break
	_assert_true(found, "AI needs a variant for the attack that requires activating Kladents.")


func _test_golem_sliz() -> void:
	var source: Vector2i = Vector2i(0, 1)
	_place_card(UnitKeys.SLIZ_NAME, 0, source)
	var copied: Dictionary = _place_card(UnitKeys.RYTSAR_NAME, 0, Vector2i(0, 0))
	game.players[0].deck.append(_make_card(UnitKeys.GRIBNIK_NAME, 0))
	var result: Dictionary = _play(UnitKeys.ZERKALNYY_GOLEM_NAME, source)
	_assert_true(result.has("pending_target"), "Golem covering Sliz must request a copied on-play target.")
	if not result.has("pending_target"):
		return
	result = game.pending_logic._apply_card_target_to_current_state(result.pending_target, copied.id)
	_assert_equal(game.players[0].hand.size(), 1, "Golem's nested Sliz copy must execute Knight's draw.")


func _test_optional_avtopoezd() -> void:
	var hand_card: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	game.players[0].hand.append(hand_card)
	var result: Dictionary = _play(UnitKeys.AVTOPOEZD_NAME, Vector2i(0, 1))
	_assert_true(result.has("pending_target"), "Avtopoezd offers replacement when another hand card exists.")
	if not result.has("pending_target"):
		return
	_assert_true(game.target_logic.can_finish_choice_request(result.pending_target), "Avtopoezd replacement may be skipped.")
	game.pending_logic.begin_target(result.pending_target)
	game.pending_logic._finish_target_turn_in_current_state()
	_assert_equal(game.current_player, 1, "Skipping replacement passes the turn.")
	_assert_equal(game.players[0].hand[0].id, hand_card.id, "Skipping preserves the unused hand card.")
	_assert_equal(game._get_stack(Vector2i(0, 1)).back().unit.name_key, UnitKeys.AVTOPOEZD_NAME, "Skipping leaves the played Avtopoezd on the board.")

func _test_option_ui() -> void:
	var selected: String = ""
	game.tabletop_logic.show_choice_list([
		{"label": "Первый вариант", "value": "first"},
		{"label": "Второй вариант", "value": "second"}
	], func(choice: Dictionary):
		game.set_meta("test_option_value", choice.value)
	)
	await process_frame
	var buttons: Node = game.tabletop_logic.choice_window.get_child(0).get_child(0)
	_assert_equal(buttons.get_child_count(), 2, "Both modal choices must be rendered.")
	buttons.get_child(1).pressed.emit()
	selected = String(game.get_meta("test_option_value", ""))
	_assert_equal(selected, "second", "The clicked option must retain its own dictionary.")
	_assert_false(game.tabletop_logic.choice_window.visible, "The option dialog must hide after selection.")
	game.tabletop_logic.choice_window.queue_free()
	game.tabletop_logic.choice_window = null


func _test_gondola_ai() -> void:
	game.current_player = 1
	game.ai_running = true
	var card: Dictionary = _make_card(UnitKeys.GONDOLA_NAME, 1)
	game.players[1].hand.append(card)
	var result: Dictionary = _play(UnitKeys.RYTSAR_NAME, Vector2i(4, 3))
	_assert_true(result.has("pending_target"), "AI must receive its end-turn Gondola request.")
	if not result.has("pending_target"):
		game.ai_running = false
		return
	game._refresh_ui()
	await process_frame
	game.pending_logic.begin_target(result.pending_target)
	await game.pending_logic.try_apply_ai_decision()
	_assert_equal(game.pending_logic.target_request.kind, "gondola_place", "AI selects its extra Gondola play.")
	await game.pending_logic.try_apply_ai_decision()
	var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(game._get_live_game_state(), card.id)
	_assert_false(info.is_empty(), "AI must place Gondola on a legal land.")
	await game.pending_logic.try_apply_ai_decision()
	_assert_equal(game.current_player, 0, "AI finishes the extra phase and passes the turn.")
	_assert_equal(game.pending_logic.action, "", "AI extra phase must leave no pending action.")
	game.ai_running = false


func _test_varvar_recycle() -> void:
	var weak: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 0)
	var strong: Dictionary = _make_card(UnitKeys.RYTSAR_NAME, 0)
	game.players[0].deck.append(weak)
	game.players[0].discard.append(strong)
	game.play_effect_logic._draw_until_power_at_least_in_state(game._get_live_game_state(), 0, 5)
	_assert_equal(game.players[0].hand.size(), 1, "Varvar searches across deck exhaustion and the original discard.")
	_assert_equal(game.players[0].hand[0].id, strong.id, "Varvar finds the existing strong card.")
	_assert_equal(game.players[0].deck.size() + game.players[0].discard.size(), 1, "The rejected card remains in the physical card pool.")
	_initialize_empty_board()
	game.players[0].deck.append(_make_card(UnitKeys.GRIBNIK_NAME, 0))
	game.players[0].discard.append(_make_card(UnitKeys.VSADNIK_NAME, 0))
	game.play_effect_logic._draw_until_power_at_least_in_state(game._get_live_game_state(), 0, 5)
	_assert_equal(game.players[0].hand.size(), 0, "If no strong card exists, the search stops without cloning one.")
	_assert_equal(game.players[0].deck.size() + game.players[0].discard.size(), 2, "An unsuccessful search preserves every existing card.")


func _test_empty_deck_targets() -> void:
	game.players[0].deck_template.append(_find_unit(UnitKeys.RYTSAR_NAME))
	_place_card(UnitKeys.GRIBNIK_NAME, 0, Vector2i(0, 1))
	for kind in ["put_adjacent_deck_face_down", "play_deck_face_down_twice", "play_top_deck_open", "evacuate_own"]:
		_assert_true(game.target_logic.get_legal_target_cells(game._get_live_game_state(), _request(kind, 0, Vector2i(0, 1))).is_empty(), kind + " must not offer impossible targets with an empty deck and discard.")


func _test_topolog_retained() -> void:
	_place_card(UnitKeys.OBOZ_NAME, 0, Vector2i(0, 0))
	_place_card(UnitKeys.OBOZ_NAME, 1, Vector2i(6, 4))
	var topolog: Dictionary = _place_card(UnitKeys.TOPOLOG_NAME, 1, Vector2i(3, 2))
	_assert_true(game._get_supplied_cells(0).has(Vector2i(6, 0)), "Retained Topolog conducts supply across opposite edges for the first player.")
	_assert_true(game._get_supplied_cells(1).has(Vector2i(0, 4)), "Retained Topolog conducts supply for the second player too.")
	topolog.face_down = true
	_assert_false(game._get_supplied_cells(0).has(Vector2i(6, 0)), "Inactive Topolog no longer joins field edges.")


func _test_tower_any_base() -> void:
	var cell: Vector2i = game.players[1].base + Vector2i.LEFT
	var tower: Dictionary = _place_card(UnitKeys.BASHNYA_NAME, 0, cell)
	_assert_equal(game._top_power(cell), int(tower.unit.power) + 1, "Tower receives its defense bonus next to either base.")
	game._add_barrier(cell, game.players[1].base)
	_assert_equal(game._top_power(cell), int(tower.unit.power), "A barrier disables the adjacency bonus.")


func _test_ballista_stack() -> void:
	var target: Vector2i = Vector2i(3, 2)
	_place_card(UnitKeys.BALLISTA_NAME, 0, target + Vector2i.LEFT)
	_place_card(UnitKeys.BALLISTA_NAME, 1, target + Vector2i.RIGHT)
	var golem: Dictionary = _place_card(UnitKeys.ZERKALNYY_GOLEM_NAME, 0, target + Vector2i.RIGHT)
	_place_card(UnitKeys.OBOZ_NAME, 1, target + Vector2i.UP)
	_place_card(UnitKeys.MAGICHESKIY_SCHIT_NAME, 1, target)
	var attacker: Dictionary = _make_card(UnitKeys.GRIBNIK_NAME, 0)
	_assert_equal(game._top_power(target), 13, "Shield must have supplied defense 13.")
	_assert_true(game.power_logic.can_attack_card(game._get_live_game_state(), attacker, target), "Both active Ballista abilities contribute to the same attack.")
	golem.face_down = true
	_assert_false(game.power_logic.can_attack_card(game._get_live_game_state(), attacker, target), "A single Ballista bonus is insufficient for this attack.")


func _test_partizany_base_strength() -> void:
	var mana: Dictionary = _place_card(UnitKeys.MANOPROVOD_NAME, 1, Vector2i(3, 2))
	_assert_equal(game._top_power(Vector2i(3, 2)), 0, "Manoprovod without neighbors defends with zero strength.")
	_assert_false(game.target_logic._target_cards_have_card_id(game.tabletop_logic.card_targets(game._get_live_game_state(), _request("partizany_weak")), mana.id), "A defense-only formula does not reduce the printed strength for Partizany's discard effect.")
