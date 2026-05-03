extends RefCounted

var game: Control


func _init(game_node: Control) -> void:
	game = game_node


func animate_action_result(result: Dictionary) -> void:
	var events: Array = result.get("events", [])
	if events.is_empty():
		return

	game.animation_running = true
	_prepare_supply_control_animation(events)
	for event in events:
		await _animate_action_event(event)
	_clear_supply_control_animation()
	game.animation_running = false


func _animate_action_event(event: Dictionary) -> void:
	var event_type: String = String(event.type)
	if event_type == "play_card":
		await _animate_play_card_event(event)
	elif event_type == "draw_card":
		await _animate_draw_event(event)
	elif event_type == "discard_card":
		await _animate_discard_event(event)
	elif event_type == game.ANIMATION_LAYOUT_STACK:
		await _animate_layout_stack_event(event)
	elif event_type == game.ANIMATION_SUPPLY_CONTROL:
		await _animate_supply_control_event(event)


func _animate_play_card_event(event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var card_id: int = int(event.card_id)
	var target_position: Vector2 = game._get_board_card_target_global_position_for_event(event, cell, card_id)
	var card_control: Control = game._get_or_create_event_card_view(event)
	await _animate_card_view_to(card_control, target_position, false)
	game._finish_play_card_animation(card_control, event)


func _animate_draw_event(event: Dictionary) -> void:
	var player_index: int = int(event.player_index)
	var card_id: int = int(event.card_id)
	var target_position: Vector2 = game._get_hand_card_target_global_position(player_index, card_id)
	var card_control: Control = game._get_or_create_event_card_view(event)
	await _animate_card_view_to(card_control, target_position, false)
	game._finish_draw_card_animation(card_control, player_index, card_id)


func _animate_discard_event(event: Dictionary) -> void:
	var player_index: int = int(event.player_index)
	var target_position: Vector2 = game._get_discard_target_position(player_index)
	var card_control: Control = game._get_or_create_event_card_view(event)
	await _animate_card_view_flip_face_up(card_control)
	await _animate_card_view_to(card_control, target_position, true)
	game._finish_discard_card_animation(card_control)


func _animate_layout_stack_event(event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var stack_container: Control = game.board_cell_stacks[cell]
	var stack: Array = game._get_event_stack_cards(event, cell)
	stack_container.visible = not stack.is_empty()
	var tween: Tween = game.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	var has_motion: bool = false
	for i in range(stack.size()):
		var card: Dictionary = stack[i]
		var card_control: Control = game._ensure_card_view(card)
		var is_covered: bool = i < stack.size() - 1
		game._configure_card_view(card_control, card, bool(card.face_down), false, is_covered)
		card_control.tooltip_text = game._get_card_tooltip(card)
		game._attach_card_view_to_container(card_control, stack_container)
		stack_container.move_child(card_control, i)
		var target_position: Vector2 = game._get_board_stack_card_local_position(stack.size(), i)
		if card_control.position.distance_squared_to(target_position) > 0.25:
			tween.tween_property(card_control, "position", target_position, game.CARD_FLY_DURATION * 0.35)
			has_motion = true
		else:
			card_control.position = target_position
	if has_motion:
		await tween.finished
	else:
		tween.kill()


func _animate_supply_control_event(event: Dictionary) -> void:
	game.supply_control_transition = event.duplicate(true)
	game.supply_control_transition_progress = 0.0
	game.board_draw_logic.queue_board_redraw()

	var tween: Tween = game.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_supply_control_transition_progress, 0.0, 1.0, game.SUPPLY_CONTROL_FADE_DURATION)
	await tween.finished
	game.board_draw_logic.set_displayed_supply_origin_cells(event.get("to_cells", {}))
	game.supply_control_transition.clear()
	game.supply_control_transition_progress = 1.0
	game.board_draw_logic.queue_board_redraw()


func _set_supply_control_transition_progress(progress: float) -> void:
	game.supply_control_transition_progress = progress
	game.board_draw_logic.queue_board_redraw()


func _prepare_supply_control_animation(events: Array) -> void:
	game.supply_control_transition.clear()
	game.supply_control_transition_progress = 1.0
	for event in events:
		if String(event.type) == game.ANIMATION_SUPPLY_CONTROL:
			game.board_draw_logic.set_displayed_supply_origin_cells(event.get("from_cells", {}))
			game.board_draw_logic.queue_board_redraw()
			return


func _clear_supply_control_animation() -> void:
	game.supply_control_transition.clear()
	game.supply_control_transition_progress = 1.0
	game.board_draw_logic.queue_board_redraw()


func _animate_card_view_to(card_control: Control, target_position: Vector2, fade_out: bool) -> void:
	if card_control == null or not is_instance_valid(card_control):
		await game.get_tree().create_timer(game.CARD_FLY_DURATION).timeout
		return
	var tween: Tween = game.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	if fade_out:
		tween.set_parallel(true)
	tween.tween_property(card_control, "global_position", target_position, game.CARD_FLY_DURATION)
	if fade_out:
		tween.tween_property(card_control, "modulate:a", 0.0, game.CARD_FLY_DURATION)
	await tween.finished
	if fade_out:
		card_control.visible = false
		card_control.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _animate_card_view_flip_face_up(card_control: Control) -> void:
	if card_control == null or not is_instance_valid(card_control):
		await game.get_tree().create_timer(game.CARD_DISCARD_FLIP_DURATION * 2.0).timeout
		return
	if not bool(card_control.face_down):
		return

	card_control.pivot_offset = card_control.size * 0.5
	var original_scale: Vector2 = card_control.scale
	var tween_out: Tween = game.create_tween()
	tween_out.set_trans(Tween.TRANS_CUBIC)
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.tween_property(card_control, "scale:x", 0.0, game.CARD_DISCARD_FLIP_DURATION)
	await tween_out.finished

	if card_control == null or not is_instance_valid(card_control):
		return
	card_control.face_down = false

	var tween_in: Tween = game.create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC)
	tween_in.set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card_control, "scale:x", original_scale.x, game.CARD_DISCARD_FLIP_DURATION)
	await tween_in.finished
	if card_control != null and is_instance_valid(card_control):
		card_control.scale = original_scale
