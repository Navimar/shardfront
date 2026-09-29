extends RefCounted

const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")
const CardAbilities: Script = preload("res://scripts/main/card_abilities.gd")
const TARGET_KINDS: Array = ["any_discard_adjacent_enemy", "any_return_adjacent", "any_move_adjacent", "move_selected_to_neighbor", "any_flip_own_up", "any_discard_unsupplied_enemy", "any_replace_own", "partizany_choose", "partizany_weak", "assasin_name", "gondola_end_turn", "gondola_place", "opolchenie_response"]

var game: Node
var choice_window: Window
var attack_discard_selections: Dictionary = {}


func _init(game_node: Node) -> void:
	game = game_node


func handles(kind: String) -> bool:
	return TARGET_KINDS.has(kind)


func target_request(state: Dictionary, result: Dictionary, name: String) -> Dictionary:
	var kinds: Dictionary = {
		UnitKeys.BOEVOY_MAG_NAME: "any_discard_adjacent_enemy",
		UnitKeys.PUGALO_NAME: "any_return_adjacent",
		UnitKeys.VSADNIK_NAME: "any_move_adjacent",
		UnitKeys.AGITATOR_NAME: "any_flip_own_up",
		UnitKeys.LESHIY_NAME: "any_discard_unsupplied_enemy",
		UnitKeys.AVTOPOEZD_NAME: "any_replace_own",
		UnitKeys.PARTIZANY_NAME: "partizany_choose",
		UnitKeys.ASSASIN_NAME: "assasin_name"
	}
	var kind: String = String(kinds.get(name, ""))
	if kind.is_empty():
		return {}
	var request: Dictionary = {
		"kind": kind, "target_type": "card", "player_index": int(result.card.owner),
		"decision_player": int(result.card.owner), "source_player": int(result.card.owner),
		"source_cell": result.cell, "card_id": int(result.card.id)
	}
	if kind == "any_replace_own" and state.players[int(result.card.owner)].hand.is_empty():
		return {}
	if kind == "partizany_choose" or kind == "assasin_name":
		request.target_type = "option"
		return request if not choices(state, request).is_empty() else {}
	return request if not card_targets(state, request).is_empty() else {}


func card_targets(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.kind)
	var owner: int = int(request.player_index)
	var targets: Array = []
	var enemy_supply: Dictionary = {}
	if kind == "any_discard_unsupplied_enemy":
		enemy_supply = game._get_supplied_cells_in_state(state, game._opponent(owner))
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if game._get_base_owner_in_state(state, cell) != -1:
				continue
			var adjacent: bool = kind in ["any_discard_adjacent_enemy", "any_return_adjacent", "any_move_adjacent"]
			if adjacent and not game.target_logic._are_unblocked_neighbors(state, request.source_cell, cell):
				continue
			for card in game._get_stack_in_state(state, cell):
				var same_owner: bool = int(card.owner) == owner
				if kind in ["any_discard_adjacent_enemy", "any_discard_unsupplied_enemy", "partizany_weak"] and same_owner:
					continue
				if kind in ["any_flip_own_up", "any_replace_own"] and not same_owner:
					continue
				if kind == "any_flip_own_up" and not bool(card.face_down):
					continue
				if kind == "any_discard_unsupplied_enemy" and enemy_supply.has(cell):
					continue
				if kind == "partizany_weak" and (bool(card.face_down) or int(card.get("copied_power", card.unit.power)) > 2):
					continue
				targets.append({"cell": cell, "card_id": int(card.id)})
	return targets


func cell_targets(state: Dictionary, request: Dictionary) -> Array:
	var targets: Array = []
	var kind: String = String(request.kind)
	if kind == "move_selected_to_neighbor":
		var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(state, int(request.selected_card_id))
		if info.is_empty():
			return targets
		var card: Dictionary = game._get_stack_in_state(state, info.cell)[int(info.index)]
		for cell in game._get_board_neighbors(info.cell):
			if not game._has_barrier_in_state(state, info.cell, cell) and game._get_base_owner_in_state(state, cell) != int(card.owner):
				targets.append(cell)
	elif kind == "gondola_place":
		var card: Dictionary = game._find_card_by_id_in_array(state.players[int(request.player_index)].hand, int(request.selected_card_id))
		if card.is_empty():
			return targets
		for y in range(game.GRID_HEIGHT):
			for x in range(game.GRID_WIDTH):
				var cell: Vector2i = Vector2i(x, y)
				if game._can_play_card_in_state(state, card, cell):
					targets.append(cell)
	return targets


func choices(state: Dictionary, request: Dictionary) -> Array:
	var kind: String = String(request.kind)
	var options: Array = []
	var owner: int = int(request.player_index)
	if kind == "partizany_choose":
		if not _closed_enemy_tops(state, owner).is_empty():
			options.append({"option": "closed", "label": "Сбросить все верхние карты соперника рубашкой вверх"})
		var weak_request: Dictionary = request.duplicate(true)
		weak_request.kind = "partizany_weak"
		if not card_targets(state, weak_request).is_empty():
			options.append({"option": "weak", "label": "Выбрать существо соперника с силой 2 или меньше"})
	elif kind == "assasin_name":
		if state.players[game._opponent(owner)].hand.is_empty():
			return options
		for unit in game._load_units([]):
			options.append({"unit_id": String(unit.id), "label": unit.get_display_name()})
	elif kind == "opolchenie_response":
		options = [{"option": "defend", "label": "Сбросить Ополчение и отменить атакующее существо"}, {"option": "allow", "label": "Не применять Ополчение"}]
	elif kind == "gondola_end_turn":
		for card in state.players[owner].hand:
			if CardAbilities.name_key(card) != UnitKeys.GONDOLA_NAME:
				continue
			var place: Dictionary = request.duplicate(true)
			place.kind = "gondola_place"
			place.selected_card_id = int(card.id)
			if not cell_targets(state, place).is_empty():
				options.append({"card_id": int(card.id), "label": "Разыграть Гондолу дополнительным действием"})
		if not game._is_ai_player(owner):
			for variant in extra_action_variants(state, owner):
				var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(state, int(variant.payload.card_id))
				var card: Dictionary = game._get_stack_in_state(state, info.cell)[int(info.index)]
				var label: String = "Перевернуть Кладенец: +10 к атаке следующего розыгрыша" if CardAbilities.name_key(card) == UnitKeys.KLADENETS_NAME else "Вернуть Гондолу в руку"
				options.append({"extra_card_id": int(card.id), "label": label})
		options.append({"option": "finish", "label": "Завершить ход"})
	return options


func apply_card_target(state: Dictionary, request: Dictionary, card_id: int) -> Dictionary:
	var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(state, card_id)
	if info.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	var cell: Vector2i = info.cell
	var stack: Array = game._get_stack_in_state(state, cell)
	var card: Dictionary = stack[int(info.index)]
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	var kind: String = String(request.kind)
	if kind == "any_move_adjacent":
		var next: Dictionary = request.duplicate(true)
		next.kind = "move_selected_to_neighbor"
		next.target_type = "cell"
		next.selected_card_id = card_id
		if cell_targets(state, next).is_empty():
			return game._make_action_result(game.RESULT_INVALID, "bad_target")
		result.pending_target = next
		result.end_turn = false
	elif kind == "any_replace_own":
		result.pending_hand_pick = {
			"kind": "avtopoezd_replace", "player_index": int(request.player_index),
			"decision_player": int(request.player_index), "source_player": int(request.player_index),
			"source_cell": cell, "selected_card_id": card_id, "card_id": int(request.card_id)
		}
		result.end_turn = false
	elif kind == "any_flip_own_up":
		card.face_down = false
		game._record_layout_stack_event_in_state(state, cell)
	else:
		stack.remove_at(int(info.index))
		var source: Dictionary = {"type": "board", "cell": cell, "face_down": bool(card.face_down)}
		if kind == "any_return_adjacent":
			game._return_card_to_hand_in_state(state, int(card.owner), card, source)
		else:
			game._discard_card_in_state(state, int(card.owner), card, source)
	resolve_continuous(state)
	return result


func apply_cell_target(state: Dictionary, request: Dictionary, cell: Vector2i) -> Dictionary:
	if String(request.kind) == "gondola_place":
		var owner: int = int(request.player_index)
		var index: int = game._find_card_index_in_array(state.players[owner].hand, int(request.selected_card_id))
		var variant: Dictionary = game._make_action_variant(game.ACTION_PLAY_HAND_CARD, owner, {"hand_index": index, "cell": cell, "gondola_extra": true})
		var result: Dictionary = game._apply_play_hand_card_to_state(state, variant)
		if result.status == game.RESULT_OK:
			game._apply_after_action_rules_to_state(state, result)
			if not game._result_has_pending_action(result):
				game._apply_stack_reactions_after_play_to_state(state, result)
		return result
	var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(state, int(request.selected_card_id))
	if info.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	var stack: Array = game._get_stack_in_state(state, info.cell)
	var card: Dictionary = stack[int(info.index)]
	stack.remove_at(int(info.index))
	game._get_stack_in_state(state, cell).append(card)
	game._record_layout_stack_event_in_state(state, info.cell)
	game._record_layout_stack_event_in_state(state, cell)
	resolve_continuous(state)
	return game.target_logic._make_ok_target_result()


func apply_choice(state: Dictionary, request: Dictionary, choice: Dictionary) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	var owner: int = int(request.player_index)
	var kind: String = String(request.kind)
	if kind == "partizany_choose":
		if String(choice.option) == "closed":
			for entry in _closed_enemy_tops(state, owner):
				apply_card_target(state, {"kind": "partizany_weak", "player_index": owner}, int(entry.card_id))
		else:
			var next: Dictionary = request.duplicate(true)
			next.kind = "partizany_weak"
			next.target_type = "card"
			result.pending_target = next
			result.end_turn = false
	elif kind == "assasin_name":
		var enemy: int = game._opponent(owner)
		var matched: bool = false
		for card in state.players[enemy].hand.duplicate():
			if String(card.unit.id) == String(choice.unit_id):
				var index: int = game._find_card_index_in_array(state.players[enemy].hand, int(card.id))
				state.players[enemy].hand.remove_at(index)
				game._discard_card_in_state(state, enemy, card, {"type": "hand", "hand_index": index})
				matched = true
				break
		if not matched:
			game._record_action_event_in_state(state, {"type": "show_hand", "player_index": enemy, "cards": state.players[enemy].hand.duplicate(true)})
	elif kind == "gondola_end_turn":
		if choice.has("extra_card_id"):
			return apply_extra_action(state, int(choice.extra_card_id))
		if choice.has("card_id"):
			var next: Dictionary = request.duplicate(true)
			next.kind = "gondola_place"
			next.target_type = "cell"
			next.selected_card_id = int(choice.card_id)
			result.pending_target = next
			result.end_turn = false
		else:
			state.players[owner].gondola_finished = true
	elif kind == "opolchenie_response":
		return apply_opolchenie_response(state, request, String(choice.option) == "defend")
	return result


func _closed_enemy_tops(state: Dictionary, owner: int) -> Array:
	var targets: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var stack: Array = game._get_stack_in_state(state, cell)
			if not stack.is_empty():
				var card: Dictionary = stack[stack.size() - 1]
				if int(card.owner) != owner and bool(card.face_down):
					targets.append({"cell": cell, "card_id": int(card.id)})
	return targets


func apply_podryvnik(state: Dictionary, result: Dictionary) -> void:
	var targets: Array = []
	for cell in game._get_board_neighbors(result.cell):
		if game._has_barrier_in_state(state, result.cell, cell):
			continue
		var stack: Array = game._get_stack_in_state(state, cell)
		if not stack.is_empty():
			targets.append(int(stack[stack.size() - 1].id))
	for card_id in targets:
		apply_card_target(state, {"kind": "partizany_weak"}, card_id)


func resolve_continuous(state: Dictionary) -> void:
	game.play_reaction_logic._remove_barriers_adjacent_to_all_taran(state)


func show_options(request: Dictionary) -> void:
	if int(request.get("decision_player", request.player_index)) != game._get_view_player():
		return
	show_choice_list(choices(game._get_live_game_state(), request), func(choice: Dictionary):
		await game.pending_logic.try_apply_target_option(choice)
	)


func show_choice_list(options: Array, callback: Callable) -> void:
	if choice_window != null and is_instance_valid(choice_window):
		choice_window.queue_free()
	choice_window = Window.new()
	choice_window.title = "Выберите действие"
	choice_window.size = Vector2i(660, 560)
	choice_window.exclusive = true
	choice_window.transient = true
	game.add_child(choice_window)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_window.add_child(scroll)
	var buttons = VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buttons)
	for choice in options:
		var button = Button.new()
		button.text = String(choice.label)
		button.tooltip_text = String(choice.get("description", ""))
		button.add_theme_font_size_override("font_size", 18)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 48
		buttons.add_child(button)
		button.pressed.connect(func():
			choice_window.hide()
			callback.call(choice)
		)
	choice_window.popup_centered()


func show_hand(event: Dictionary) -> void:
	if int(event.player_index) == game._get_view_player():
		return
	var names: PackedStringArray = []
	for card in event.cards:
		names.append(card.unit.get_display_name() + " — " + card.unit.get_description())
	var dialog = AcceptDialog.new()
	dialog.title = "Рука соперника"
	dialog.dialog_text = "\n\n".join(names) if not names.is_empty() else "Рука пуста"
	game.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))
	await dialog.popup_hide
	dialog.queue_free()


func apply_opolchenie_response(state: Dictionary, request: Dictionary, defend: bool) -> Dictionary:
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = true
	if defend:
		var owner: int = int(request.player_index)
		var hand: Array = state.players[owner].hand
		var index: int = game._find_card_index_in_array(hand, int(request.opolchenie_id))
		if index < 0:
			return game._make_action_result(game.RESULT_INVALID, "bad_target")
		var militia: Dictionary = hand[index]
		hand.remove_at(index)
		game._discard_card_in_state(state, owner, militia, {"type": "hand", "hand_index": index})
		var attacker: Dictionary = request.attacking_card
		if request.has("announced_variant"):
			var attacking_hand: Array = state.players[int(attacker.owner)].hand
			index = game._find_card_index_in_array(attacking_hand, int(attacker.id))
			if index >= 0:
				attacking_hand.remove_at(index)
				game._discard_card_in_state(state, int(attacker.owner), attacker, {"type": "hand", "hand_index": index})
		else:
			var stack: Array = game._get_stack_in_state(state, request.source_cell)
			index = game._find_card_index_in_array(stack, int(attacker.id))
			if index >= 0:
				stack.remove_at(index)
				game._discard_card_in_state(state, int(attacker.owner), attacker, {"type": "board", "cell": request.source_cell, "face_down": false})
		state.players[int(attacker.owner)].next_attack_bonus = 0
		result.played_card_removed = true
	else:
		if request.has("announced_variant"):
			var variant: Dictionary = request.announced_variant.duplicate(true)
			variant.payload.opolchenie_declined = true
			result = game._apply_play_hand_card_to_state(state, variant)
		else:
			result = request.announced_result.duplicate(true)
		result.opolchenie_declined = true
		game._apply_after_action_rules_to_state(state, result)
	return result

func play_response_request(state: Dictionary, result: Dictionary) -> Dictionary:
	var base_owner: int = game._get_base_owner_in_state(state, result.cell)
	if base_owner < 0 or base_owner == int(result.card.owner):
		return {}
	for card in state.players[base_owner].hand:
		if CardAbilities.name_key(card) == UnitKeys.OPOLCHENIE_NAME:
			return {
				"kind": "opolchenie_response", "target_type": "option",
				"player_index": base_owner, "decision_player": base_owner,
				"source_player": int(result.card.owner), "source_cell": result.cell,
				"card_id": int(result.card.id), "opolchenie_id": int(card.id),
				"attacking_card": result.card, "announced_result": result.duplicate(true)
			}
	return {}


func extra_action_variants(state: Dictionary, owner: int) -> Array:
	var variants: Array = []
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var stack: Array = game._get_stack_in_state(state, Vector2i(x, y))
			if stack.is_empty():
				continue
			var card: Dictionary = stack.back()
			if int(card.owner) == owner and not bool(card.face_down) and CardAbilities.name_key(card) in [UnitKeys.KLADENETS_NAME, UnitKeys.GONDOLA_NAME]:
				variants.append(game._make_action_variant("tabletop_extra", owner, {"card_id": int(card.id)}))
	return variants


func apply_extra_action(state: Dictionary, card_id: int) -> Dictionary:
	var owner: int = int(state.current_player)
	var info: Dictionary = game.target_logic._find_card_cell_and_index_in_board(state, card_id)
	if info.is_empty():
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	var stack: Array = game._get_stack_in_state(state, info.cell)
	var card: Dictionary = stack[int(info.index)]
	if int(info.index) != stack.size() - 1 or int(card.owner) != owner or bool(card.face_down):
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	var name: String = CardAbilities.name_key(card)
	if name == UnitKeys.KLADENETS_NAME:
		card.face_down = true
		state.players[owner].next_attack_bonus = int(state.players[owner].get("next_attack_bonus", 0)) + 10
		game._record_layout_stack_event_in_state(state, info.cell)
	elif name == UnitKeys.GONDOLA_NAME:
		stack.pop_back()
		game._return_card_to_hand_in_state(state, owner, card, {"type": "board", "cell": info.cell, "face_down": false})
	else:
		return game._make_action_result(game.RESULT_INVALID, "bad_target")
	resolve_continuous(state)
	var result: Dictionary = game._make_action_result(game.RESULT_OK, "")
	result.end_turn = bool(state.players[owner].get("in_end_turn", false))
	return result


func end_turn_request(state: Dictionary) -> Dictionary:
	var owner: int = int(state.current_player)
	if bool(state.players[owner].get("gondola_finished", false)):
		return {}
	var request: Dictionary = {"kind": "gondola_end_turn", "target_type": "option", "player_index": owner, "decision_player": owner, "source_player": owner}
	var options: Array = choices(state, request)
	if options.size() <= 1:
		return {}
	state.players[owner].in_end_turn = true
	return request


func get_hlamovnik_copy_cards(state: Dictionary, requested_id: int = -1) -> Array:
	var cards: Array = []
	for player in state.players:
		for card in player.discard:
			if requested_id < 0 or int(card.id) == requested_id:
				cards.append(card)
	return cards


func make_hlamovnik_preview(card: Dictionary, copied: Dictionary) -> Dictionary:
	var preview: Dictionary = card.duplicate(true)
	preview.copied_power = int(copied.unit.power)
	preview.attack_power_override = int(copied.unit.power)
	return preview


func choose_hlamovnik_copy(card: Dictionary) -> void:
	var options: Array = []
	for copied in get_hlamovnik_copy_cards(game._get_live_game_state()):
		options.append({"card_id": int(copied.id), "label": "%s — сила %d, %s" % [copied.unit.get_display_name(), int(copied.unit.power), game.players[int(copied.owner)].name], "description": copied.unit.get_description()})
	show_choice_list(options, func(choice: Dictionary):
		game.pending_logic.robot_card_id = int(card.id)
		game.pending_logic.robot_copy_card_id = int(choice.card_id)
		game.ui_selected_hand_card_id = int(card.id)
		game.pending_logic.action = "hand"
		game._sync_after_state_change_without_card_layout()
	)


func prompt_attack_discard(card: Dictionary) -> bool:
	var copied_id: int = game.pending_logic.get_robot_copy_card_id(int(card.id))
	var ability: String = CardAbilities.name_key(card)
	if String(card.unit.name_key) == UnitKeys.ROBOT_NAME and copied_id >= 0:
		var copied: Dictionary = game._find_card_by_id_in_array(game.players[int(card.owner)].hand, copied_id)
		if not copied.is_empty():
			ability = CardAbilities.name_key(copied)
	if ability != UnitKeys.CHARODEY_NAME:
		return false
	var options: Array = [{"card_id": -1, "label": "Разыграть без дополнительного сброса"}]
	for candidate in game.players[int(card.owner)].hand:
		if int(candidate.id) != int(card.id):
			options.append({"card_id": int(candidate.id), "label": "Сбросить " + candidate.unit.get_display_name() + ": +10 к атаке"})
	show_choice_list(options, func(choice: Dictionary):
		attack_discard_selections[int(card.id)] = int(choice.card_id)
		game.ui_selected_hand_card_id = int(card.id)
		game.pending_logic.action = "hand"
		game._sync_after_state_change_without_card_layout()
	)
	return true


func expand_attack_payment_options(state: Dictionary, original_options: Array, requested_id: int) -> Array:
	var options: Array = []
	for original in original_options:
		var card: Dictionary = original.card
		if CardAbilities.name_key(card) != UnitKeys.CHARODEY_NAME:
			options.append(original)
			continue
		if requested_id < 0:
			options.append(original)
		for candidate in state.players[int(card.owner)].hand:
			if int(candidate.id) == int(card.id) or (requested_id >= -1 and int(candidate.id) != requested_id):
				continue
			var boosted: Dictionary = original.duplicate(true)
			boosted.card.attack_bonus = 10
			boosted.charodey_discard_id = int(candidate.id)
			options.append(boosted)
	return options
