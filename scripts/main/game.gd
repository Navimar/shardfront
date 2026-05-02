extends Control

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 5
const CARD_INNER_WIDTH: int = 186
const CARD_INNER_HEIGHT: int = 158
const CARD_FRAME_WIDTH: int = 3
const CARD_WIDTH: int = CARD_INNER_WIDTH + CARD_FRAME_WIDTH * 2
const CARD_HEIGHT: int = CARD_INNER_HEIGHT + CARD_FRAME_WIDTH * 2
const CELL_SIZE: int = CARD_WIDTH
const CELL_GAP: int = 12
const MAX_HAND: int = 7
const TURN_MINOR_ACTIONS: int = 2
const UNIT_DIR: String = "res://resources/units"
const DECK_ALL_STATUSES: Array = []
const DECK_IMPLEMENTED_UNTESTED_STATUSES: Array = [UnitResource.IMPLEMENTATION_IMPLEMENTED]
const DECK_READY_STATUSES: Array = [UnitResource.IMPLEMENTATION_IMPLEMENTED, UnitResource.IMPLEMENTATION_TESTED]
const DECK_UNIT_STATUSES: Array = DECK_ALL_STATUSES
const HUMAN_PLAYER_INDEX: int = 0
const AI_PLAYERS: Array = [1]
const AI_THINK_DELAY: float = 0.35
const TEMPO_BAR_HEIGHT: int = 6
const TEMPO_BAR_VERTICAL_WIDTH: int = 10
const CARD_FLY_DURATION: float = 0.72
const CARD_DISCARD_FLIP_DURATION: float = 0.18
const ACTION_DRAW_CARD: String = "draw_card"
const ACTION_PLAY_HAND_CARD: String = "play_hand_card"
const ACTION_PLAY_DECK_FACE_DOWN: String = "play_deck_face_down"
const ANIMATION_LAYOUT_STACK: String = "layout_stack"
const RESULT_OK: String = "ok"
const RESULT_INVALID: String = "invalid"
const UNIT_ABBERATSIYA_NAME: String = "UNIT_ABBERATSIYA_NAME"
const UNIT_BARON_NAME: String = "UNIT_BARON_NAME"
const UNIT_DRAKON_NAME: String = "UNIT_DRAKON_NAME"
const UNIT_DROVOSEK_NAME: String = "UNIT_DROVOSEK_NAME"
const UNIT_GRIBNIK_NAME: String = "UNIT_GRIBNIK_NAME"
const UNIT_KRYSA_NAME: String = "UNIT_KRYSA_NAME"
const UNIT_LUCHNIK_NAME: String = "UNIT_LUCHNIK_NAME"
const UNIT_MOZGOSHMYG_NAME: String = "UNIT_MOZGOSHMYG_NAME"
const UNIT_RYTSAR_NAME: String = "UNIT_RYTSAR_NAME"
const UNIT_VARVAR_NAME: String = "UNIT_VARVAR_NAME"
const WOOD_CARD_COLOR: Color = Color(0.42, 0.25, 0.10)
const METAL_CARD_COLOR: Color = Color(0.10, 0.30, 0.46)
const BARRIER_FILL_COLOR: Color = Color(0.88, 0.69, 0.32)
const TOOLTIP_BACKGROUND_COLOR: Color = Color(0.03, 0.025, 0.02)
const SUPPLY_PIPE_WIDTH: float = float(CELL_GAP)
const UnitScene: PackedScene = preload("res://scenes/unit.tscn")
const GameAi: Script = preload("res://scripts/main/game_ai.gd")
const WoodBaseTexture: Texture2D = preload("res://assets/bases/base_single.jpg")
const MetalBaseTexture: Texture2D = preload("res://assets/bases/bases_pair.jpg")
const TableBackgroundTexture: Texture2D = preload("res://assets/backgrounds/table_stone_background.jpg")

var board = []
var barriers = {}
var players = []
var current_player: int = 0
var ui_selected_hand_card_id: int = -1
var ui_pending_action: String = ""
var minor_actions_spent: int = 0
var game_over: bool = false
var game_over_message: String = ""
var animation_running: bool = false
var ai_running: bool = false
var ai_logic: RefCounted
var next_card_id: int = 1

var board_cells = {}
var board_cell_labels = {}
var board_cell_bases = {}
var board_cell_stacks = {}
var hand_card_controls = {}
var card_views = {}

var action_label: Label
var tempo_bar: Control
var tempo_debug_label: Label
var hand_container: VBoxContainer
var opponent_hand_container: VBoxContainer
var board_area: Control
var board_grid: GridContainer
var supply_line_layer: Control
var barrier_layer: Control
var draw_two_button: Button
var deck_two_button: Button
var replay_button: Button
var discard_button: Button
var opponent_discard_button: Button
var discard_dialog: AcceptDialog
var discard_grid: GridContainer


func _ready() -> void:
	TranslationServer.set_locale("ru")
	randomize()
	ai_logic = GameAi.new(self)
	_setup_game()
	_build_ui()
	_refresh_ui()


func _input(event: InputEvent) -> void:
	if game_over or animation_running or ui_pending_action == "":
		return
	if _is_ai_player(current_player):
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var cell: Vector2i = _get_board_cell_at_global_position(event.global_position)
	if cell == Vector2i(-1, -1):
		return

	get_viewport().set_input_as_handled()
	if ui_pending_action == "hand":
		_try_play_hand_card(cell)
	elif ui_pending_action == "deck_face_down":
		_try_play_from_deck_face_down(cell)


func _setup_game() -> void:
	board.clear()
	next_card_id = 1
	_clear_all_card_views()
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append([])
		board.append(row)

	barriers.clear()
	_generate_initial_barriers()

	var all_units: Array = _load_units(DECK_UNIT_STATUSES)
	var first_deck: Array = _make_deck_from_units(all_units, 0)
	var second_deck: Array = _make_deck_from_units(all_units, 1)
	first_deck.shuffle()
	second_deck.shuffle()

	players = [
		{
			"name": "Древесный игрок",
			"base": Vector2i(1, 1),
			"deck_template": all_units.duplicate(),
			"deck": first_deck,
			"hand": [],
			"discard": []
		},
		{
			"name": "Металлический игрок",
			"base": Vector2i(5, 3),
			"deck_template": all_units.duplicate(),
			"deck": second_deck,
			"hand": [],
			"discard": []
		}
	]

	_draw_cards(0, 4)
	_draw_cards(1, 5)


func _clear_all_card_views() -> void:
	for card_control in card_views.values():
		if card_control != null and is_instance_valid(card_control):
			card_control.queue_free()
	card_views.clear()


func _make_deck_from_units(units: Array, owner: int) -> Array:
	var deck: Array = []
	for unit in units:
		deck.append(_make_card(unit, owner, false))
	return deck


func _make_card(unit: Resource, owner: int, face_down: bool = false) -> Dictionary:
	var card: Dictionary = {
		"id": next_card_id,
		"unit": unit,
		"owner": owner,
		"face_down": face_down
	}
	next_card_id += 1
	return card


func _make_card_in_state(state: Dictionary, unit: Resource, owner: int, face_down: bool = false) -> Dictionary:
	var id: int = int(state.get("next_card_id", next_card_id))
	var card: Dictionary = {
		"id": id,
		"unit": unit,
		"owner": owner,
		"face_down": face_down
	}
	state.next_card_id = id + 1
	return card


func _load_units(status_filter: Array = []) -> Array:
	var units: Array = []
	var dir: DirAccess = DirAccess.open(UNIT_DIR)
	if dir == null:
		return units

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var unit = load("%s/%s" % [UNIT_DIR, file_name])
			if unit is Resource and _unit_matches_status_filter(unit, status_filter):
				units.append(unit)
		file_name = dir.get_next()
	dir.list_dir_end()
	return units


func _unit_matches_status_filter(unit: Resource, status_filter: Array) -> bool:
	if status_filter.is_empty():
		return true
	var implementation_status = unit.get("implementation_status")
	return status_filter.has(implementation_status)


func _make_ui_theme() -> Theme:
	var ui_theme = Theme.new()

	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = TOOLTIP_BACKGROUND_COLOR
	tooltip_style.border_color = Color(0.72, 0.62, 0.46)
	tooltip_style.set_border_width_all(3)
	tooltip_style.set_corner_radius_all(0)
	tooltip_style.content_margin_left = 15
	tooltip_style.content_margin_top = 12
	tooltip_style.content_margin_right = 15
	tooltip_style.content_margin_bottom = 12

	ui_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	ui_theme.set_color("font_color", "TooltipLabel", Color(0.96, 0.94, 0.88))
	ui_theme.set_color("font_shadow_color", "TooltipLabel", Color(0.0, 0.0, 0.0))
	ui_theme.set_constant("shadow_offset_x", "TooltipLabel", 2)
	ui_theme.set_constant("shadow_offset_y", "TooltipLabel", 2)
	ui_theme.set_font_size("font_size", "TooltipLabel", 21)
	return ui_theme


func _tr_text(key: String) -> String:
	return tr(key).replace("\\n", "\n")


func _build_ui() -> void:
	theme = _make_ui_theme()

	var table_background = TextureRect.new()
	table_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	table_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_background.texture = TableBackgroundTexture
	table_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table_background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(table_background)

	var root = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_top", CELL_GAP)
	add_child(root)

	var main_column = VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_column.add_theme_constant_override("separation", 4)
	root.add_child(main_column)

	var main_row = HBoxContainer.new()
	var board_size: Vector2 = _get_board_pixel_size()
	var side_panel_height: float = board_size.y
	main_row.custom_minimum_size = Vector2(
		CARD_WIDTH + 36 + board_size.x + 225 + 36,
		board_size.y
	)
	main_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_row.add_theme_constant_override("separation", 18)
	main_column.add_child(main_row)

	var hand_panel = VBoxContainer.new()
	hand_panel.custom_minimum_size = Vector2(CARD_WIDTH + 36, side_panel_height)
	hand_panel.add_theme_constant_override("separation", 9)
	main_row.add_child(hand_panel)

	var tempo_row = HBoxContainer.new()
	tempo_row.custom_minimum_size = Vector2(CARD_WIDTH + 36, side_panel_height)
	tempo_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tempo_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tempo_row.add_theme_constant_override("separation", 8)
	hand_panel.add_child(tempo_row)

	tempo_bar = Control.new()
	tempo_bar.custom_minimum_size = Vector2(TEMPO_BAR_VERTICAL_WIDTH, side_panel_height)
	tempo_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tempo_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tempo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tempo_bar.z_index = 2048
	tempo_bar.draw.connect(_on_tempo_bar_draw)
	tempo_row.add_child(tempo_bar)

	var hand_content = VBoxContainer.new()
	hand_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_content.add_theme_constant_override("separation", 9)
	tempo_row.add_child(hand_content)

	tempo_debug_label = Label.new()
	tempo_debug_label.custom_minimum_size = Vector2(CARD_WIDTH + 36 - TEMPO_BAR_VERTICAL_WIDTH - 8, 86)
	tempo_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tempo_debug_label.z_index = 2049
	tempo_debug_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	tempo_debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	tempo_debug_label.add_theme_constant_override("shadow_offset_x", 2)
	tempo_debug_label.add_theme_constant_override("shadow_offset_y", 2)
	tempo_debug_label.add_theme_font_size_override("font_size", 12)
	tempo_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tempo_debug_label.visible = true
	hand_content.add_child(tempo_debug_label)

	draw_two_button = Button.new()
	draw_two_button.text = _tr_text("UI_DRAW")
	draw_two_button.tooltip_text = _tr_text("UI_TOOLTIP_DRAW")
	draw_two_button.pressed.connect(_on_draw_two_pressed)
	hand_content.add_child(draw_two_button)

	deck_two_button = Button.new()
	deck_two_button.text = _tr_text("UI_PATH")
	deck_two_button.tooltip_text = _tr_text("UI_TOOLTIP_PATH")
	deck_two_button.pressed.connect(_on_deck_two_pressed)
	hand_content.add_child(deck_two_button)

	replay_button = Button.new()
	replay_button.text = _tr_text("UI_REPLAY")
	replay_button.visible = false
	replay_button.pressed.connect(_on_replay_pressed)
	hand_content.add_child(replay_button)

	var hand_scroll = ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_content.add_child(hand_scroll)

	var hand_center = HBoxContainer.new()
	hand_center.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_center)

	hand_container = VBoxContainer.new()
	hand_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hand_container.add_theme_constant_override("separation", 12)
	hand_center.add_child(hand_container)

	discard_button = Button.new()
	discard_button.text = _tr_text("UI_DISCARD_BUTTON") % 0
	discard_button.tooltip_text = _tr_text("UI_TOOLTIP_DISCARD")
	discard_button.pressed.connect(_on_discard_pressed)
	hand_content.add_child(discard_button)

	board_area = Control.new()
	board_area.custom_minimum_size = board_size
	board_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_area.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_area.resized.connect(_resize_board_to_available)
	main_row.add_child(board_area)

	board_grid = GridContainer.new()
	board_grid.columns = GRID_WIDTH
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", CELL_GAP)
	board_grid.add_theme_constant_override("v_separation", CELL_GAP)
	board_grid.resized.connect(_queue_barrier_redraw)
	board_area.add_child(board_grid)

	supply_line_layer = Control.new()
	supply_line_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	supply_line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_line_layer.z_index = 5
	supply_line_layer.draw.connect(_on_supply_line_layer_draw)
	supply_line_layer.resized.connect(_queue_barrier_redraw)
	board_area.add_child(supply_line_layer)

	barrier_layer = Control.new()
	barrier_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	barrier_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrier_layer.z_index = 20
	barrier_layer.draw.connect(_on_barrier_layer_draw)
	barrier_layer.resized.connect(_queue_barrier_redraw)
	board_area.add_child(barrier_layer)

	var opponent_hand_panel = VBoxContainer.new()
	opponent_hand_panel.custom_minimum_size = Vector2(225, side_panel_height)
	opponent_hand_panel.add_theme_constant_override("separation", 9)
	main_row.add_child(opponent_hand_panel)

	var opponent_hand_scroll = ScrollContainer.new()
	opponent_hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opponent_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opponent_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	opponent_hand_panel.add_child(opponent_hand_scroll)

	var opponent_hand_center = HBoxContainer.new()
	opponent_hand_center.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_hand_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_hand_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opponent_hand_scroll.add_child(opponent_hand_center)

	opponent_hand_container = VBoxContainer.new()
	opponent_hand_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	opponent_hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	opponent_hand_container.add_theme_constant_override("separation", 12)
	opponent_hand_center.add_child(opponent_hand_container)

	opponent_discard_button = Button.new()
	opponent_discard_button.text = _tr_text("UI_DISCARD_BUTTON") % 0
	opponent_discard_button.tooltip_text = _tr_text("UI_TOOLTIP_OPPONENT_DISCARD")
	opponent_discard_button.pressed.connect(_on_opponent_discard_pressed)
	opponent_hand_panel.add_child(opponent_discard_button)

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell_panel = PanelContainer.new()
			cell_panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell_panel.mouse_filter = Control.MOUSE_FILTER_STOP
			cell_panel.set_meta("cell", Vector2i(x, y))
			cell_panel.gui_input.connect(_on_board_cell_gui_input.bind(cell_panel))
			board_grid.add_child(cell_panel)
			board_cells[Vector2i(x, y)] = cell_panel

			var content = VBoxContainer.new()
			content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.add_theme_constant_override("separation", 0)
			content.z_index = 10
			cell_panel.add_child(content)

			var label = Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = true
			content.add_child(label)
			board_cell_labels[Vector2i(x, y)] = label

			var base_container = VBoxContainer.new()
			base_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			base_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			base_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.add_child(base_container)
			board_cell_bases[Vector2i(x, y)] = base_container

			var stack_container = Control.new()
			stack_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stack_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stack_container.clip_contents = true
			content.add_child(stack_container)
			board_cell_stacks[Vector2i(x, y)] = stack_container

	action_label = Label.new()
	action_label.custom_minimum_size = Vector2(main_row.custom_minimum_size.x, 54)
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.add_theme_font_size_override("font_size", 32)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	action_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	action_label.add_theme_constant_override("outline_size", 6)
	main_column.add_child(action_label)

	_build_discard_dialog()
	_resize_board_to_available.call_deferred()


func _refresh_ui() -> void:
	_sync_base_visuals()
	_sync_ui_chrome()
	_sync_all_card_views()
	_queue_ai_turn_if_needed()


func _sync_base_visuals() -> void:
	for cell in board_cell_bases.keys():
		_refresh_base_visual(cell, board_cell_bases[cell])


func _sync_ui_chrome() -> void:
	var status_text: String
	if game_over:
		status_text = game_over_message
	else:
		status_text = _get_action_text()
	action_label.text = status_text
	action_label.visible = status_text != ""

	var playable_cells: Dictionary = _get_playable_cells_for_ui_pending_action()
	for cell in board_cells.keys():
		var cell_panel: PanelContainer = board_cells[cell]
		var label: Label = board_cell_labels[cell]
		var base_container: VBoxContainer = board_cell_bases[cell]
		var stack_container: Control = board_cell_stacks[cell]
		var base_owner: int = _get_base_owner(cell)
		var has_stack: bool = not _get_stack(cell).is_empty()
		cell_panel.tooltip_text = _get_cell_tooltip(cell)
		label.visible = false
		base_container.visible = base_owner != -1
		stack_container.visible = base_owner == -1 and has_stack
		label.text = _get_cell_text(cell)
		if base_owner != -1:
			cell_panel.add_theme_stylebox_override("panel", _make_base_cell_style(base_owner))
			label.modulate = Color(1.0, 1.0, 1.0)
		elif playable_cells.has(cell):
			cell_panel.add_theme_stylebox_override("panel", _make_cell_style(Color(0.12, 0.12, 0.12, 0.22), Color(0.0, 0.0, 0.0, 0.0)))
			label.modulate = Color(1.0, 1.0, 1.0)
		else:
			cell_panel.add_theme_stylebox_override("panel", _make_cell_style(Color(0.12, 0.12, 0.12, 0.22), Color(0.0, 0.0, 0.0, 0.0)))
			label.modulate = Color(1.0, 1.0, 1.0)

	_queue_barrier_redraw()
	_refresh_discard_button()
	_set_action_buttons_enabled(_can_press_minor_action_button())
	replay_button.visible = game_over
	_refresh_tempo_bar()
	_sync_visible_card_visual_state()


func _sync_all_card_views() -> void:
	for cell in board_cell_stacks.keys():
		var stack_container: Control = board_cell_stacks[cell]
		if stack_container.visible:
			_sync_board_stack_card_views(cell, stack_container)
	_sync_hand_card_views()
	_sync_opponent_hand_card_views()
	_hide_discard_card_views()


func _sync_visible_card_visual_state() -> void:
	_sync_board_card_visual_state()
	_sync_hand_card_visual_state()
	_sync_opponent_hand_card_visual_state()


func _sync_board_card_visual_state() -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			_sync_board_stack_card_visual_state(cell)


func _sync_board_stack_card_visual_state(cell: Vector2i) -> void:
	var stack: Array = _get_stack(cell)
	for i in range(stack.size()):
		var card: Dictionary = stack[i]
		var card_control: Control = card_views.get(int(card.id), null)
		if card_control == null or not is_instance_valid(card_control):
			continue
		var is_covered: bool = i < stack.size() - 1
		var is_unsupplied: bool = not _is_card_supplied(card, cell)
		_configure_card_view(card_control, card, bool(card.face_down), is_unsupplied, is_unsupplied or is_covered)


func _sync_hand_card_visual_state() -> void:
	var view_player: int = _get_view_player()
	var hand: Array = players[view_player].hand
	hand_card_controls.clear()
	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var card_control: Control = card_views.get(int(card.id), null)
		if card_control == null or not is_instance_valid(card_control):
			continue
		card_control.set_meta("hand_index", i)
		hand_card_controls[i] = card_control
		_configure_card_view(card_control, card, false, false, false)
		_connect_hand_card_input(card_control)
		if current_player == view_player and minor_actions_spent > 0:
			card_control.set_portrait_desaturated(true)
			card_control.set_text_muted(true)
		elif current_player == view_player and int(card.id) == ui_selected_hand_card_id:
			_add_selected_card_frame(card_control)


func _sync_opponent_hand_card_visual_state() -> void:
	var opponent_index: int = _opponent(_get_view_player())
	var hand: Array = players[opponent_index].hand
	for card in hand:
			var card_control: Control = card_views.get(int(card.id), null)
			if card_control == null or not is_instance_valid(card_control):
				continue
			_configure_card_view(card_control, card, true, false, false)


func _sync_after_state_change_without_card_layout() -> void:
	_sync_ui_chrome()
	_queue_ai_turn_if_needed()


func _refresh_tempo_bar() -> void:
	if tempo_debug_label != null:
		tempo_debug_label.text = _get_tempo_debug_text()
		tempo_debug_label.visible = true
	if tempo_bar != null:
		tempo_bar.queue_redraw()


func _on_tempo_bar_draw() -> void:
	if tempo_bar == null or players.size() < 2:
		return

	var rect: Rect2 = Rect2(Vector2.ZERO, tempo_bar.size)
	var wood_share: float = _get_tempo_bar_player_share(0)
	var split_y: float = rect.size.y * wood_share
	var wood_rect: Rect2 = Rect2(rect.position, Vector2(rect.size.x, split_y))
	var metal_rect: Rect2 = Rect2(Vector2(0.0, split_y), Vector2(rect.size.x, rect.size.y - split_y))
	tempo_bar.draw_rect(wood_rect, WOOD_CARD_COLOR)
	tempo_bar.draw_rect(metal_rect, METAL_CARD_COLOR)
	tempo_bar.draw_line(Vector2(0.0, split_y), Vector2(rect.size.x, split_y), Color(1.0, 0.95, 0.78, 0.85), 2.0)
	tempo_bar.draw_line(Vector2(0.0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.5), Color(0.0, 0.0, 0.0, 0.45), 1.0)


func _get_tempo_bar_score() -> float:
	var state: Dictionary = _capture_game_state()
	var human_tempo: float = ai_logic.evaluate_win_tempo(state, 0)
	var ai_tempo: float = ai_logic.evaluate_win_tempo(state, 1)
	if human_tempo <= 0.0 and ai_tempo <= 0.0:
		return 0.0
	if human_tempo <= 0.0:
		return -INF
	if ai_tempo <= 0.0:
		return INF
	return human_tempo - ai_tempo


func _get_tempo_bar_player_share(player_index: int) -> float:
	var state: Dictionary = _capture_game_state()
	var player_tempo: float = ai_logic.evaluate_win_tempo(state, player_index)
	var opponent_tempo: float = ai_logic.evaluate_win_tempo(state, _opponent(player_index))
	if player_tempo <= 0.0 and opponent_tempo <= 0.0:
		return 0.5
	if player_tempo <= 0.0:
		return 1.0
	if opponent_tempo <= 0.0:
		return 0.0
	var total: float = player_tempo + opponent_tempo
	if total <= 0.0:
		return 0.5
	return clamp(opponent_tempo / total, 0.0, 1.0)


func _get_tempo_debug_text() -> String:
	if players.size() < 2:
		return ""
	var state: Dictionary = _capture_game_state()
	var human_breakdown: Dictionary = ai_logic.get_tempo_breakdown(state, 0)
	var ai_breakdown: Dictionary = ai_logic.get_tempo_breakdown(state, 1)
	var human_tempo: float = float(human_breakdown.tempo)
	var ai_tempo: float = float(ai_breakdown.tempo)
	var tempo_diff: float = _get_tempo_bar_score()
	var wood_share: float = _get_tempo_bar_player_share(0) * 100.0
	return "W t=%s p=%s h=%s turn=%s\nM t=%s p=%s h=%s turn=%s\nratio=%s/%s diff=%s" % [
		_format_tempo_debug_float(human_tempo),
		_format_tempo_debug_float(float(human_breakdown.path_cost)),
		_format_tempo_debug_float(float(human_breakdown.hand_penalty)),
		_format_tempo_debug_float(float(human_breakdown.turn_penalty)),
		_format_tempo_debug_float(ai_tempo),
		_format_tempo_debug_float(float(ai_breakdown.path_cost)),
		_format_tempo_debug_float(float(ai_breakdown.hand_penalty)),
		_format_tempo_debug_float(float(ai_breakdown.turn_penalty)),
		_format_tempo_debug_float(wood_share),
		_format_tempo_debug_float(100.0 - wood_share),
		_format_tempo_debug_float(tempo_diff)
	]


func _format_tempo_debug_float(value: float) -> String:
	if value != value:
		return "nan"
	if value == INF:
		return "+inf"
	if value == -INF:
		return "-inf"
	return "%.2f" % value


func _build_discard_dialog() -> void:
	discard_dialog = AcceptDialog.new()
	discard_dialog.title = _tr_text("UI_DISCARD_DIALOG_TITLE")
	discard_dialog.min_size = Vector2(780, 630)
	discard_dialog.visibility_changed.connect(_on_discard_dialog_visibility_changed)
	add_child(discard_dialog)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(750, 510)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	discard_dialog.add_child(scroll)

	discard_grid = GridContainer.new()
	discard_grid.columns = 3
	discard_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_grid.add_theme_constant_override("h_separation", 12)
	discard_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(discard_grid)


func _refresh_discard_button() -> void:
	var view_player: int = _get_view_player()
	var discard: Array = players[view_player].discard
	discard_button.text = _tr_text("UI_DISCARD_BUTTON") % discard.size()
	discard_button.disabled = discard.is_empty()

	var opponent_discard: Array = players[_opponent(view_player)].discard
	opponent_discard_button.text = _tr_text("UI_DISCARD_BUTTON") % opponent_discard.size()
	opponent_discard_button.disabled = opponent_discard.is_empty()


func _on_discard_pressed() -> void:
	_refresh_discard_dialog(_get_view_player())
	discard_dialog.popup_centered()


func _on_opponent_discard_pressed() -> void:
	_refresh_discard_dialog(_opponent(_get_view_player()))
	discard_dialog.popup_centered()


func _refresh_discard_dialog(player_index: int) -> void:
	for child in discard_grid.get_children():
		if child.has_meta("card_id"):
			discard_grid.remove_child(child)
		else:
			child.queue_free()

	discard_dialog.title = _tr_text("UI_DISCARD_DIALOG_TITLE")
	var discard: Array = players[player_index].discard
	if discard.is_empty():
		var empty_label = Label.new()
		empty_label.text = _tr_text("UI_DISCARD_EMPTY")
		discard_grid.add_child(empty_label)
		return

	for card in discard:
		card.face_down = false
		var unit_control: Control = _ensure_card_view(card)
		_configure_card_view(unit_control, card, false, false, false)
		_attach_card_view_to_container(unit_control, discard_grid)
		unit_control.visible = true


func _on_discard_dialog_visibility_changed() -> void:
	if discard_dialog.visible:
		return
	_hide_discard_card_views()


func _sync_hand_card_views() -> void:
	hand_card_controls.clear()

	var view_player: int = _get_view_player()
	var hand: Array = players[view_player].hand
	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var unit_control: Control = _ensure_card_view(card)
		_configure_card_view(unit_control, card, false, false, false)
		unit_control.set_meta("hand_index", i)
		_connect_hand_card_input(unit_control)
		hand_card_controls[i] = unit_control
		if current_player == view_player and minor_actions_spent > 0:
			unit_control.set_portrait_desaturated(true)
			unit_control.set_text_muted(true)
		elif current_player == view_player and int(card.id) == ui_selected_hand_card_id:
			_add_selected_card_frame(unit_control)
		_attach_card_view_to_container(unit_control, hand_container)
		hand_container.move_child(unit_control, i)


func _sync_opponent_hand_card_views() -> void:
	var opponent_index: int = _opponent(_get_view_player())
	var hand: Array = players[opponent_index].hand
	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var path_card: Control = _ensure_card_view(card)
		_configure_card_view(path_card, card, true, false, false)
		path_card.tooltip_text = _tr_text("UI_TOOLTIP_OPPONENT_PATH_HAND")
		_attach_card_view_to_container(path_card, opponent_hand_container)
		opponent_hand_container.move_child(path_card, i)


func _ensure_card_view(card: Dictionary) -> Control:
	var card_id: int = int(card.id)
	var existing: Control = card_views.get(card_id, null)
	if existing != null and is_instance_valid(existing):
		return existing

	var unit_control: Control = UnitScene.instantiate()
	unit_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	unit_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	unit_control.set_meta("card_id", card_id)
	card_views[card_id] = unit_control
	add_child(unit_control)
	return unit_control


func _configure_card_view(card_control: Control, card: Dictionary, force_face_down: bool, desaturate: bool, text_muted: bool) -> void:
	_remove_selected_card_frame(card_control)
	card_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_control.visible = true
	card_control.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_control.unit = card.unit
	card_control.player_index = int(card.owner)
	card_control.face_down = force_face_down or bool(card.face_down)
	card_control.tooltip_text = _get_card_tooltip(card)
	card_control.reset_visual_modifiers()
	if card_control.face_down:
		card_control.set_back_desaturated(desaturate)
	else:
		card_control.set_portrait_desaturated(desaturate)
		card_control.set_text_muted(text_muted)

func _attach_card_view_to_container(card_control: Control, container: Node) -> void:
	var parent: Node = card_control.get_parent()
	if parent != container:
		if parent != null:
			parent.remove_child(card_control)
		container.add_child(card_control)
	card_control.set_as_top_level(false)
	card_control.z_index = 0
	card_control.visible = true


func _hide_discard_card_views() -> void:
	for player in players:
		for card in player.discard:
			var card_id: int = int(card.id)
			var card_control: Control = card_views.get(card_id, null)
			if card_control != null and is_instance_valid(card_control) and card_control.get_parent() != discard_grid:
				card_control.visible = false


func _add_selected_card_frame(card_control: Control) -> void:
	_remove_selected_card_frame(card_control)
	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 4096
	frame.set_meta("selection_frame", true)
	frame.add_theme_stylebox_override("panel", _make_selected_card_frame_style())
	card_control.add_child(frame)


func _remove_selected_card_frame(card_control: Control) -> void:
	var frames: Array = []
	for child in card_control.get_children():
		if bool(child.get_meta("selection_frame", false)):
			frames.append(child)
	for frame in frames:
		card_control.remove_child(frame)
		frame.free()


func _make_selected_card_frame_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color.a = 0.0
	style.border_color = BARRIER_FILL_COLOR
	style.set_border_width_all(max(2, CARD_FRAME_WIDTH * 2))
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _get_action_text() -> String:
	if _is_ai_player(current_player):
		return "%s думает..." % players[current_player].name
	if ui_pending_action == "hand":
		return _tr_text("UI_STATUS_CHOOSE_HAND_CELL")
	if ui_pending_action == "deck_face_down":
		return _tr_text("UI_STATUS_CHOOSE_PATH_CELL")
	if minor_actions_spent > 0:
		return _tr_text("UI_STATUS_MINOR_ACTIONS_LEFT")
	return _tr_text("UI_STATUS_CHOOSE_ACTION")


func _get_playable_cells_for_ui_pending_action() -> Dictionary:
	var playable = {}
	if ui_pending_action == "hand":
		var hand_index: int = _get_ui_selected_hand_index()
		for variant in _get_play_hand_variants_for_state(_get_live_game_state(), current_player, hand_index):
			playable[variant.cell] = true
	elif ui_pending_action == "deck_face_down":
		for variant in _get_deck_face_down_variants_for_state(_get_live_game_state(), current_player):
			playable[variant.cell] = true
	return playable


func _get_board_pixel_size() -> Vector2:
	return Vector2(
		CELL_SIZE * GRID_WIDTH + CELL_GAP * (GRID_WIDTH - 1),
		CELL_SIZE * GRID_HEIGHT + CELL_GAP * (GRID_HEIGHT - 1)
	)


func _resize_board_to_available() -> void:
	if board_area == null or board_grid == null:
		return
	if board_area.size.x <= 0.0 or board_area.size.y <= 0.0:
		return

	var board_size: Vector2 = _get_board_pixel_size()

	board_grid.custom_minimum_size = board_size
	board_grid.size = board_size
	board_grid.position = Vector2(
		max(0.0, (board_area.size.x - board_size.x) * 0.5),
		max(0.0, (board_area.size.y - board_size.y) * 0.5)
	)

	for cell_panel in board_cells.values():
		cell_panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

	_queue_barrier_redraw()


func _make_cell_style(fill_color: Color, border_color: Color, border_width: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _make_base_cell_style(base_owner: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12)
	style.border_color = _get_player_card_color(base_owner)
	style.set_border_width_all(CARD_FRAME_WIDTH)
	style.set_corner_radius_all(0)
	style.content_margin_left = CARD_FRAME_WIDTH
	style.content_margin_top = CARD_FRAME_WIDTH
	style.content_margin_right = CARD_FRAME_WIDTH
	style.content_margin_bottom = CARD_FRAME_WIDTH
	return style


func _get_cell_text(cell: Vector2i) -> String:
	if _get_base_owner(cell) != -1:
		return ""
	return "%d,%d" % [cell.x + 1, cell.y + 1]


func _get_cell_tooltip(cell: Vector2i) -> String:
	var base_owner: int = _get_base_owner(cell)
	if base_owner != -1:
		return _get_base_tooltip(base_owner)
	return ""


func _get_base_tooltip(base_owner: int) -> String:
	if base_owner == 0:
		return _tr_text("UI_TOOLTIP_WOOD_BASE")
	return _tr_text("UI_TOOLTIP_METAL_BASE")


func _get_card_tooltip(card: Dictionary) -> String:
	if card.face_down:
		if card.owner == _get_view_player():
			return _tr_text("UI_TOOLTIP_PATH_CARD")
		return _tr_text("UI_TOOLTIP_OPPONENT_PATH_CARD")

	var unit: Resource = card.unit
	return _get_unit_tooltip(unit)


func _get_unit_tooltip(unit: Resource) -> String:
	var description: String = unit.get_description()
	if description == "":
		return ""
	return _wrap_tooltip_text(description)


func _wrap_tooltip_text(text: String, max_line_length: int = 28) -> String:
	var words: PackedStringArray = text.split(" ", false)
	var lines: Array[String] = []
	var current_line: String = ""
	for word in words:
		if current_line == "":
			current_line = word
		elif current_line.length() + 1 + word.length() <= max_line_length:
			current_line = "%s %s" % [current_line, word]
		else:
			lines.append(current_line)
			current_line = word
	if current_line != "":
		lines.append(current_line)
	return "\n".join(lines)


func _refresh_base_visual(cell: Vector2i, base_container: VBoxContainer) -> void:
	for child in base_container.get_children():
		child.queue_free()

	var base_owner: int = _get_base_owner(cell)
	if base_owner == -1:
		return

	var base_image = TextureRect.new()
	base_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_image.stretch_mode = TextureRect.STRETCH_SCALE
	if base_owner == 0:
		base_image.texture = WoodBaseTexture
	else:
		base_image.texture = MetalBaseTexture
	base_container.add_child(base_image)


func _sync_board_stack_card_views(cell: Vector2i, stack_container: Control) -> void:
	var stack: Array = _get_stack(cell)
	for i in range(stack.size()):
		var card = stack[i]
		var card_control: Control = _ensure_card_view(card)
		var is_covered: bool = i < stack.size() - 1
		var is_unsupplied: bool = not _is_card_supplied(card, cell)
		_configure_card_view(card_control, card, bool(card.face_down), is_unsupplied, is_unsupplied or is_covered)
		card_control.tooltip_text = _get_card_tooltip(card)
		_attach_card_view_to_container(card_control, stack_container)
		card_control.position = _get_board_stack_card_local_position(stack.size(), i)
		stack_container.move_child(card_control, i)


func _is_card_supplied(card: Dictionary, cell: Vector2i) -> bool:
	var supplied_cells: Dictionary = _get_supplied_cells(card.owner)
	return supplied_cells.has(cell)


func _get_player_card_color(player_index: int) -> Color:
	if player_index == 0:
		return WOOD_CARD_COLOR
	if player_index == 1:
		return METAL_CARD_COLOR
	return Color(0.16, 0.16, 0.16)


func _animate_action_result(result: Dictionary) -> void:
	var events: Array = result.get("events", [])
	if events.is_empty():
		return

	animation_running = true
	for event in events:
		await _animate_action_event(event)
	animation_running = false


func _animate_action_event(event: Dictionary) -> void:
	var event_type: String = String(event.type)
	if event_type == "play_card":
		await _animate_play_card_event(event)
	elif event_type == "draw_card":
		await _animate_draw_event(event)
	elif event_type == "discard_card":
		await _animate_discard_event(event)
	elif event_type == ANIMATION_LAYOUT_STACK:
		await _animate_layout_stack_event(event)


func _animate_play_card_event(event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var card_id: int = int(event.card_id)
	var target_position: Vector2 = _get_board_card_target_global_position_for_event(event, cell, card_id)
	var card_control: Control = _get_or_create_event_card_view(event)
	await _animate_card_view_to(card_control, target_position, false)
	_finish_play_card_animation(card_control, event)


func _animate_draw_event(event: Dictionary) -> void:
	var player_index: int = int(event.player_index)
	var card_id: int = int(event.card_id)
	var target_position: Vector2 = _get_hand_card_target_global_position(player_index, card_id)
	var card_control: Control = _get_or_create_event_card_view(event)
	await _animate_card_view_to(card_control, target_position, false)
	_finish_draw_card_animation(card_control, player_index, card_id)


func _animate_discard_event(event: Dictionary) -> void:
	var player_index: int = int(event.player_index)
	var target_position: Vector2 = _get_discard_target_position(player_index)
	var card_control: Control = _get_or_create_event_card_view(event)
	await _animate_card_view_flip_face_up(card_control)
	await _animate_card_view_to(card_control, target_position, true)
	_finish_discard_card_animation(card_control)


func _animate_layout_stack_event(event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var stack_container: Control = board_cell_stacks[cell]
	var stack: Array = _get_event_stack_cards(event, cell)
	stack_container.visible = not stack.is_empty()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	var has_motion: bool = false
	for i in range(stack.size()):
		var card: Dictionary = stack[i]
		var card_control: Control = _ensure_card_view(card)
		var is_covered: bool = i < stack.size() - 1
		var is_unsupplied: bool = not _is_card_supplied(card, cell)
		_configure_card_view(card_control, card, bool(card.face_down), is_unsupplied, is_unsupplied or is_covered)
		card_control.tooltip_text = _get_card_tooltip(card)
		_attach_card_view_to_container(card_control, stack_container)
		stack_container.move_child(card_control, i)
		var target_position: Vector2 = _get_board_stack_card_local_position(stack.size(), i)
		if card_control.position.distance_squared_to(target_position) > 0.25:
			tween.tween_property(card_control, "position", target_position, CARD_FLY_DURATION * 0.35)
			has_motion = true
		else:
			card_control.position = target_position
	if has_motion:
		await tween.finished
	else:
		tween.kill()


func _finish_play_card_animation(card_control: Control, event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var card_id: int = int(event.card_id)
	var card: Dictionary = _find_card_by_id_on_board(cell, card_id)
	if card.is_empty():
		card = _get_card_from_event(event)
	var stack_container: Control = board_cell_stacks[cell]
	stack_container.visible = true
	_configure_card_view(card_control, card, bool(card.face_down), not _is_card_supplied(card, cell), false)
	_attach_card_view_to_container(card_control, stack_container)
	var stack: Array = _get_event_stack_cards(event, cell)
	var stack_index: int = _find_card_index_in_array(stack, card_id)
	if stack_index < 0:
		stack_index = stack.size() - 1
	card_control.position = _get_board_stack_card_local_position(stack.size(), stack_index)
	stack_container.move_child(card_control, stack_index)


func _finish_draw_card_animation(card_control: Control, player_index: int, card_id: int) -> void:
	var card: Dictionary = _find_card_by_id_in_array(players[player_index].hand, card_id)
	if card.is_empty():
		return
	var target_container: Control = hand_container
	var force_face_down: bool = false
	if player_index != _get_view_player():
		target_container = opponent_hand_container
		force_face_down = true
	_configure_card_view(card_control, card, force_face_down, false, false)
	if player_index == _get_view_player():
		_connect_hand_card_input(card_control)
	_attach_card_view_to_container(card_control, target_container)
	var hand_index: int = _find_card_index_in_array(players[player_index].hand, card_id)
	target_container.move_child(card_control, hand_index)


func _finish_discard_card_animation(card_control: Control) -> void:
	if card_control == null or not is_instance_valid(card_control):
		return
	var parent: Node = card_control.get_parent()
	if parent != self:
		if parent != null:
			parent.remove_child(card_control)
		add_child(card_control)
	card_control.set_as_top_level(false)
	card_control.visible = false


func _get_or_create_event_card_view(event: Dictionary) -> Control:
	var card_id: int = int(event.get("card_id", -1))
	var source: Dictionary = event.get("source", {})
	var player_index: int = int(event.player_index)
	var should_show_back: bool = bool(event.get("face_down", false)) or bool(source.get("face_down", false))
	if String(event.type) == "draw_card" and player_index != _get_view_player():
		should_show_back = true
	var existing: Control = card_views.get(card_id, null)
	if existing != null and is_instance_valid(existing):
		_configure_event_card_view(existing, event, should_show_back)
		_lift_card_view_for_animation(existing)
		return existing

	if not _can_create_missing_event_card_view(event):
		push_warning("Missing card view for animated card_id=%d" % card_id)
		return null

	var card_control: Control = UnitScene.instantiate()
	card_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.global_position = _get_event_fallback_source_position(event)
	card_control.set_meta("card_id", card_id)
	card_views[card_id] = card_control
	add_child(card_control)
	_configure_event_card_view(card_control, event, should_show_back)
	_lift_card_view_for_animation(card_control)
	return card_control


func _can_create_missing_event_card_view(event: Dictionary) -> bool:
	var source: Dictionary = event.get("source", {})
	var source_type: String = String(source.get("type", "base"))
	return source_type == "base"


func _lift_card_view_for_animation(card_control: Control) -> void:
	var rect: Rect2 = card_control.get_global_rect()
	card_control.set_as_top_level(true)
	card_control.global_position = rect.position
	card_control.size = rect.size
	card_control.z_index = 4096


func _configure_event_card_view(card_control: Control, event: Dictionary, face_down: bool) -> void:
	card_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.visible = true
	card_control.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_control.unit = event.unit
	card_control.player_index = int(event.player_index)
	card_control.face_down = face_down
	card_control.reset_visual_modifiers()


func _animate_card_view_to(card_control: Control, target_position: Vector2, fade_out: bool) -> void:
	if card_control == null or not is_instance_valid(card_control):
		await get_tree().create_timer(CARD_FLY_DURATION).timeout
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	if fade_out:
		tween.set_parallel(true)
	tween.tween_property(card_control, "global_position", target_position, CARD_FLY_DURATION)
	if fade_out:
		tween.tween_property(card_control, "modulate:a", 0.0, CARD_FLY_DURATION)
	await tween.finished
	if fade_out:
		card_control.visible = false
		card_control.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _animate_card_view_flip_face_up(card_control: Control) -> void:
	if card_control == null or not is_instance_valid(card_control):
		await get_tree().create_timer(CARD_DISCARD_FLIP_DURATION * 2.0).timeout
		return
	if not bool(card_control.face_down):
		return

	card_control.pivot_offset = card_control.size * 0.5
	var original_scale: Vector2 = card_control.scale
	var tween_out: Tween = create_tween()
	tween_out.set_trans(Tween.TRANS_CUBIC)
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.tween_property(card_control, "scale:x", 0.0, CARD_DISCARD_FLIP_DURATION)
	await tween_out.finished

	if card_control == null or not is_instance_valid(card_control):
		return
	card_control.face_down = false

	var tween_in: Tween = create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC)
	tween_in.set_ease(Tween.EASE_OUT)
	tween_in.tween_property(card_control, "scale:x", original_scale.x, CARD_DISCARD_FLIP_DURATION)
	await tween_in.finished
	if card_control != null and is_instance_valid(card_control):
		card_control.scale = original_scale


func _get_event_fallback_source_position(event: Dictionary) -> Vector2:
	var player_index: int = int(event.player_index)
	var event_type: String = String(event.type)
	if event_type == "draw_card":
		return _get_player_base_card_source_position(player_index)

	var source: Dictionary = event.get("source", {})
	var source_type: String = String(source.get("type", "base"))
	if source_type == "board":
		var cell: Vector2i = source.get("cell", players[player_index].base)
		return _get_card_target_global_position(cell)
	return _get_player_base_card_source_position(player_index)


func _get_discard_target_position(player_index: int) -> Vector2:
	var target_button: Control
	if player_index == _get_view_player():
		target_button = discard_button
	else:
		target_button = opponent_discard_button
	var target_rect: Rect2 = target_button.get_global_rect()
	return target_rect.get_center() - Vector2(CARD_WIDTH, CARD_HEIGHT) * 0.5


func _get_player_base_card_source_position(player_index: int) -> Vector2:
	var base_cell: Vector2i = players[player_index].base
	var base_panel: Control = board_cells.get(base_cell, null)
	if base_panel == null:
		return Vector2.ZERO
	var base_rect: Rect2 = base_panel.get_global_rect()
	return base_rect.get_center() - Vector2(CARD_WIDTH, CARD_HEIGHT) * 0.5


func _get_player_hand_draw_target_position(player_index: int) -> Vector2:
	var target_container: Control
	if player_index == _get_view_player():
		target_container = hand_container
	else:
		target_container = opponent_hand_container

	if target_container.get_child_count() > 0:
		var last_card: Control = target_container.get_child(target_container.get_child_count() - 1)
		return last_card.get_global_rect().position + Vector2(0.0, CARD_HEIGHT * 0.35)

	var target_rect: Rect2 = target_container.get_global_rect()
	return target_rect.position


func _get_hand_card_target_global_position(player_index: int, card_id: int) -> Vector2:
	var target_container: Control
	if player_index == _get_view_player():
		target_container = hand_container
	else:
		target_container = opponent_hand_container

	var hand: Array = players[player_index].hand
	var hand_index: int = _find_card_index_in_array(hand, card_id)
	if hand_index < 0:
		return _get_player_hand_draw_target_position(player_index)

	var separation: int = target_container.get_theme_constant("separation")
	var target_rect: Rect2 = target_container.get_global_rect()
	return target_rect.position + Vector2(0.0, float(hand_index * (CARD_HEIGHT + separation)))


func _get_card_target_global_position(cell: Vector2i) -> Vector2:
	var stack_container: Control = board_cell_stacks.get(cell, null)
	if stack_container != null:
		var target_position: Vector2 = stack_container.get_global_rect().position
		if _get_stack(cell).is_empty():
			target_position.y += (CELL_SIZE - CARD_HEIGHT) * 0.5
		return target_position

	var target_rect: Rect2 = board_cells[cell].get_global_rect()
	return target_rect.position


func _get_board_card_target_global_position(cell: Vector2i, card_id: int) -> Vector2:
	var stack_container: Control = board_cell_stacks.get(cell, null)
	if stack_container == null:
		return _get_card_target_global_position(cell)

	var stack: Array = _get_stack(cell)
	var stack_index: int = _find_card_index_in_array(stack, card_id)
	if stack_index < 0:
		return _get_card_target_global_position(cell)

	var local_position: Vector2 = _get_board_stack_card_local_position(stack.size(), stack_index)
	return stack_container.get_global_rect().position + local_position


func _get_board_card_target_global_position_for_event(event: Dictionary, cell: Vector2i, card_id: int) -> Vector2:
	var stack_container: Control = board_cell_stacks.get(cell, null)
	if stack_container == null:
		return _get_card_target_global_position(cell)

	var stack: Array = _get_event_stack_cards(event, cell)
	var stack_index: int = _find_card_index_in_array(stack, card_id)
	if stack_index < 0:
		return _get_board_card_target_global_position(cell, card_id)

	var local_position: Vector2 = _get_board_stack_card_local_position(stack.size(), stack_index)
	return stack_container.get_global_rect().position + local_position


func _get_board_stack_card_local_position(stack_size: int, stack_index: int) -> Vector2:
	var overlap_offset: int = CELL_SIZE - CARD_HEIGHT
	var single_card_y: float = (CELL_SIZE - CARD_HEIGHT) * 0.5
	if stack_size <= 1:
		return Vector2(0.0, single_card_y)
	var visual_index: int = stack_size - 1 - stack_index
	return Vector2(0.0, float(visual_index * overlap_offset))


func _find_card_index_in_array(cards: Array, card_id: int) -> int:
	for i in range(cards.size()):
		if int(cards[i].id) == card_id:
			return i
	return -1


func _find_card_by_id_in_array(cards: Array, card_id: int) -> Dictionary:
	var index: int = _find_card_index_in_array(cards, card_id)
	if index < 0:
		return {}
	return cards[index]


func _find_card_by_id_on_board(cell: Vector2i, card_id: int) -> Dictionary:
	if not _is_inside(cell):
		return {}
	return _find_card_by_id_in_array(_get_stack(cell), card_id)


func _get_event_stack_cards(event: Dictionary, cell: Vector2i) -> Array:
	if event.has("stack_cards"):
		return event.stack_cards
	return _get_stack(cell)


func _get_card_from_event(event: Dictionary) -> Dictionary:
	return {
		"id": int(event.card_id),
		"unit": event.unit,
		"owner": int(event.player_index),
		"face_down": bool(event.get("face_down", false))
	}


func _queue_barrier_redraw() -> void:
	if supply_line_layer != null:
		supply_line_layer.queue_redraw()
	if barrier_layer != null:
		barrier_layer.queue_redraw()


func _on_supply_line_layer_draw() -> void:
	_draw_supply_networks()
	var playable_cells: Dictionary = _get_playable_cells_for_ui_pending_action()
	_draw_playable_supply_lines(playable_cells)


func _on_barrier_layer_draw() -> void:
	var playable_cells: Dictionary = _get_playable_cells_for_ui_pending_action()
	_draw_playable_arrow_heads(playable_cells)

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var right: Vector2i = cell + Vector2i.RIGHT
			if _is_inside(right) and _has_barrier(cell, right):
				_draw_barrier_between(cell, right)

			var down: Vector2i = cell + Vector2i.DOWN
			if _is_inside(down) and _has_barrier(cell, down):
				_draw_barrier_between(cell, down)


func _draw_playable_supply_lines(playable_cells: Dictionary) -> void:
	if playable_cells.is_empty():
		return

	var supplied_cells: Dictionary = _get_supplied_cells(current_player)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if not _should_draw_supply_network_cell(current_player, cell, supplied_cells):
				continue
			_draw_playable_network_segment(cell, cell + Vector2i.RIGHT, supplied_cells)
			_draw_playable_network_segment(cell, cell + Vector2i.DOWN, supplied_cells)
			_draw_playable_frontier_segment(cell, cell + Vector2i.UP, playable_cells)
			_draw_playable_frontier_segment(cell, cell + Vector2i.DOWN, playable_cells)
			_draw_playable_frontier_segment(cell, cell + Vector2i.LEFT, playable_cells)
			_draw_playable_frontier_segment(cell, cell + Vector2i.RIGHT, playable_cells)


func _draw_playable_arrow_heads(playable_cells: Dictionary) -> void:
	if playable_cells.is_empty():
		return

	var supplied_cells: Dictionary = _get_supplied_cells(current_player)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if not _should_draw_supply_network_cell(current_player, cell, supplied_cells):
				continue
			_draw_playable_arrow_head_between(cell, cell + Vector2i.UP, playable_cells)
			_draw_playable_arrow_head_between(cell, cell + Vector2i.DOWN, playable_cells)
			_draw_playable_arrow_head_between(cell, cell + Vector2i.LEFT, playable_cells)
			_draw_playable_arrow_head_between(cell, cell + Vector2i.RIGHT, playable_cells)


func _draw_playable_network_segment(from_cell: Vector2i, to_cell: Vector2i, supplied_cells: Dictionary) -> void:
	if not _is_inside(to_cell):
		return
	if _has_barrier(from_cell, to_cell):
		return
	if not _should_draw_supply_network_cell(current_player, to_cell, supplied_cells):
		return
	_draw_supply_segment(from_cell, to_cell, true, Color(0.88, 0.08, 0.06, 1.0))


func _draw_playable_frontier_segment(from_cell: Vector2i, to_cell: Vector2i, playable_cells: Dictionary) -> void:
	if not _is_inside(to_cell):
		return
	if _has_barrier(from_cell, to_cell):
		return
	if not playable_cells.has(to_cell):
		return
	if _top_owner(to_cell) == current_player:
		return
	_draw_supply_segment(from_cell, to_cell, false, Color(0.88, 0.08, 0.06, 1.0))


func _draw_playable_arrow_head_between(from_cell: Vector2i, to_cell: Vector2i, playable_cells: Dictionary) -> void:
	if not _is_inside(to_cell):
		return
	if _has_barrier(from_cell, to_cell):
		return
	if not playable_cells.has(to_cell):
		return
	if _top_owner(to_cell) == current_player:
		return
	var from_rect: Rect2 = _get_cell_rect_on_layer(from_cell, barrier_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(to_cell, barrier_layer)
	var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
	var tip: Vector2 = _get_rect_edge_point(to_rect, -direction) + direction * 10.0
	_draw_arrow_head(tip, direction, Color(0.88, 0.08, 0.06, 1.0))


func _draw_supply_networks() -> void:
	for player_index in range(players.size()):
		_draw_supply_network(player_index)


func _draw_supply_network(player_index: int) -> void:
	var supplied_cells: Dictionary = _get_supplied_cells(player_index)
	var color: Color = _get_player_card_color(player_index)

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if not _should_draw_supply_network_cell(player_index, cell, supplied_cells):
				continue
			_draw_supply_network_segment(player_index, cell, cell + Vector2i.RIGHT, supplied_cells, color)
			_draw_supply_network_segment(player_index, cell, cell + Vector2i.DOWN, supplied_cells, color)


func _draw_supply_network_segment(player_index: int, from_cell: Vector2i, to_cell: Vector2i, supplied_cells: Dictionary, color: Color) -> void:
	if not _is_inside(to_cell):
		return
	if _has_barrier(from_cell, to_cell):
		return
	if not _should_draw_supply_network_cell(player_index, to_cell, supplied_cells):
		return
	var from_rect: Rect2 = _get_cell_rect_on_layer(from_cell, supply_line_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(to_cell, supply_line_layer)
	supply_line_layer.draw_line(from_rect.get_center(), to_rect.get_center(), color, SUPPLY_PIPE_WIDTH, true)


func _should_draw_supply_network_cell(player_index: int, cell: Vector2i, supplied_cells: Dictionary) -> bool:
	return supplied_cells.has(cell) and (players[player_index].base == cell or _top_owner(cell) == player_index)


func _draw_supply_segment(from_cell: Vector2i, to_cell: Vector2i, center_to_center: bool, color: Color) -> void:
	var from_rect: Rect2 = _get_cell_rect_on_layer(from_cell, supply_line_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(to_cell, supply_line_layer)
	var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
	var segment_end: Vector2 = to_rect.get_center()
	if not center_to_center:
		segment_end = _get_rect_edge_point(to_rect, -direction)
	supply_line_layer.draw_line(from_rect.get_center(), segment_end, color, SUPPLY_PIPE_WIDTH, true)


func _build_supply_path(target_cell: Vector2i, parents: Dictionary) -> Array:
	var path: Array = [target_cell]
	var current: Vector2i = target_cell
	while parents.has(current):
		var parent: Vector2i = parents[current]
		if parent == current:
			break
		path.push_front(parent)
		current = parent
	return path


func _draw_supply_line_path(path: Array, is_secondary: bool) -> void:
	if path.size() < 2:
		return

	var color: Color = Color(0.88, 0.08, 0.06, 1.0)
	var width: float = SUPPLY_PIPE_WIDTH

	for i in range(path.size() - 1):
		var from_rect: Rect2 = _get_cell_rect_on_layer(path[i], supply_line_layer)
		var to_rect: Rect2 = _get_cell_rect_on_layer(path[i + 1], supply_line_layer)
		var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
		var segment_start: Vector2 = from_rect.get_center()
		var segment_end: Vector2 = to_rect.get_center()
		if i == path.size() - 2 and not is_secondary:
			segment_end = _get_rect_edge_point(to_rect, -direction)
		supply_line_layer.draw_line(segment_start, segment_end, color, width, true)


func _draw_supply_arrow_head_for_path(path: Array) -> void:
	if path.size() < 2:
		return

	var from_rect: Rect2 = _get_cell_rect_on_layer(path[path.size() - 2], barrier_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(path[path.size() - 1], barrier_layer)
	var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
	var color: Color = Color(0.88, 0.08, 0.06, 1.0)
	var tip: Vector2 = _get_rect_edge_point(to_rect, -direction) + direction * 15.0
	_draw_arrow_head(tip, direction, color)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var length: float = 21.0
	var width: float = SUPPLY_PIPE_WIDTH
	var outline_color: Color = Color(0.22, 0.03, 0.02, 1.0)
	var outline_length: float = length + 3.0
	var outline_width: float = width + 3.0
	var outline_points: PackedVector2Array = PackedVector2Array([
		tip + direction * 14.0,
		tip - direction * outline_length + side * outline_width,
		tip - direction * outline_length - side * outline_width
	])
	var points: PackedVector2Array = PackedVector2Array([
		tip + direction * 12.0,
		tip - direction * length + side * width,
		tip - direction * length - side * width
	])
	barrier_layer.draw_colored_polygon(outline_points, outline_color)
	barrier_layer.draw_colored_polygon(points, color)


func _get_cell_rect_on_layer(cell: Vector2i, layer: Control) -> Rect2:
	var cell_panel: Control = board_cells[cell]
	var layer_position: Vector2 = layer.get_global_rect().position
	var cell_rect: Rect2 = cell_panel.get_global_rect()
	return Rect2(cell_rect.position - layer_position, cell_rect.size)


func _get_rect_edge_point(rect: Rect2, direction: Vector2) -> Vector2:
	var center: Vector2 = rect.get_center()
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			return Vector2(rect.position.x + rect.size.x, center.y)
		return Vector2(rect.position.x, center.y)

	if direction.y > 0.0:
		return Vector2(center.x, rect.position.y + rect.size.y)
	return Vector2(center.x, rect.position.y)


func _draw_barrier_between(first: Vector2i, second: Vector2i) -> void:
	var first_panel: Control = board_cells[first]
	var second_panel: Control = board_cells[second]
	var first_rect: Rect2 = first_panel.get_global_rect()
	var second_rect: Rect2 = second_panel.get_global_rect()
	var layer_position: Vector2 = barrier_layer.get_global_rect().position
	var thickness: float = 18.0
	var frame_width: float = 3.0
	var inset: float = 9.0
	var frame_color: Color = Color(0.02, 0.015, 0.01)
	var fill_color: Color = BARRIER_FILL_COLOR
	var shine_color: Color = Color(1.0, 0.86, 0.48, 0.55)

	if first.y == second.y:
		var center_x: float = ((first_rect.position.x + first_rect.size.x) + second_rect.position.x) * 0.5 - layer_position.x
		var top_y: float = max(first_rect.position.y, second_rect.position.y) + inset - layer_position.y
		var height: float = min(first_rect.size.y, second_rect.size.y) - inset * 2.0
		var outer_rect: Rect2 = Rect2(center_x - thickness * 0.5, top_y, thickness, height)
		var inner_rect: Rect2 = outer_rect.grow(-frame_width)
		barrier_layer.draw_rect(outer_rect, frame_color)
		barrier_layer.draw_rect(inner_rect, fill_color)
		barrier_layer.draw_rect(Rect2(inner_rect.position.x + frame_width, inner_rect.position.y, frame_width, inner_rect.size.y), shine_color)
	else:
		var center_y: float = ((first_rect.position.y + first_rect.size.y) + second_rect.position.y) * 0.5 - layer_position.y
		var left_x: float = max(first_rect.position.x, second_rect.position.x) + inset - layer_position.x
		var width: float = min(first_rect.size.x, second_rect.size.x) - inset * 2.0
		var outer_rect: Rect2 = Rect2(left_x, center_y - thickness * 0.5, width, thickness)
		var inner_rect: Rect2 = outer_rect.grow(-frame_width)
		barrier_layer.draw_rect(outer_rect, frame_color)
		barrier_layer.draw_rect(inner_rect, fill_color)
		barrier_layer.draw_rect(Rect2(inner_rect.position.x, inner_rect.position.y + frame_width, inner_rect.size.x, frame_width), shine_color)


func _get_card_short_text(card: Dictionary) -> String:
	if card.face_down:
		return "Рубашка %s" % _short_player_name(card.owner)
	var unit: Resource = card.unit
	return "%s %d %s" % [unit.get_display_name(), unit.power, _short_player_name(card.owner)]


func _short_player_name(index: int) -> String:
	if index == 0:
		return "Д"
	return "М"


func _get_view_player() -> int:
	return HUMAN_PLAYER_INDEX


func _on_hand_card_gui_input(event: InputEvent, unit_control: Control) -> void:
	if game_over or animation_running:
		return
	if _is_ai_player(current_player):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if minor_actions_spent > 0:
			return
		if ui_pending_action != "" and ui_pending_action != "hand" and ui_pending_action != "deck_face_down":
			return
		ui_selected_hand_card_id = int(unit_control.get_meta("card_id"))
		ui_pending_action = "hand"
		_sync_after_state_change_without_card_layout()


func _get_ui_selected_hand_index() -> int:
	if ui_selected_hand_card_id == -1:
		return -1
	return _find_card_index_in_array(players[_get_view_player()].hand, ui_selected_hand_card_id)


func _connect_hand_card_input(card_control: Control) -> void:
	if bool(card_control.get_meta("hand_input_connected", false)):
		return
	card_control.gui_input.connect(_on_hand_card_gui_input.bind(card_control))
	card_control.set_meta("hand_input_connected", true)


func _is_ai_player(player_index: int) -> bool:
	return AI_PLAYERS.has(player_index)


func _queue_ai_turn_if_needed() -> void:
	if ai_running or game_over or animation_running:
		return
	if not _is_ai_player(current_player):
		return
	_run_ai_turn_step.call_deferred()


func _run_ai_turn_step() -> void:
	if ai_running or game_over or animation_running:
		return
	if not _is_ai_player(current_player):
		return

	ai_running = true
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if game_over or animation_running or not _is_ai_player(current_player):
		ai_running = false
		return

	_clear_pending()
	var state: Dictionary = _capture_game_state()
	var variant: Dictionary = ai_logic.choose_action_variant(state, current_player)
	if variant.is_empty():
		var live_state: Dictionary = _get_live_game_state()
		live_state.events = []
		_apply_end_turn_rules_to_state(live_state)
		_restore_game_state(live_state)
		await _animate_action_result(live_state)
	else:
		var result: Dictionary = _apply_action_variant_to_current_state(variant)
		await _animate_action_result(result)

	ai_running = false
	_sync_after_state_change_without_card_layout()


func _get_min_path_actions_to_supply_enemy_base(state: Dictionary, player_index: int) -> float:
	return ai_logic.get_min_path_actions_to_supply_enemy_base(state, player_index)


func _get_live_game_state() -> Dictionary:
	return {
		"board": board,
		"barriers": barriers,
		"players": players,
		"current_player": current_player,
		"minor_actions_spent": minor_actions_spent,
		"game_over": game_over,
		"game_over_message": game_over_message,
		"next_card_id": next_card_id
	}


func _capture_game_state() -> Dictionary:
	return _duplicate_game_state(_get_live_game_state())


func _duplicate_game_state(state: Dictionary) -> Dictionary:
	return {
		"board": _duplicate_board(state.board),
		"barriers": state.barriers.duplicate(true),
		"players": _duplicate_players(state.players),
		"current_player": int(state.current_player),
		"minor_actions_spent": int(state.minor_actions_spent),
		"game_over": bool(state.game_over),
		"game_over_message": String(state.game_over_message),
		"next_card_id": int(state.get("next_card_id", next_card_id))
	}


func _restore_game_state(state: Dictionary) -> void:
	board = state.board
	barriers = state.barriers
	players = state.players
	current_player = int(state.current_player)
	minor_actions_spent = int(state.minor_actions_spent)
	game_over = bool(state.game_over)
	game_over_message = String(state.game_over_message)
	next_card_id = int(state.get("next_card_id", next_card_id))


func _duplicate_board(source_board: Array) -> Array:
	var new_board: Array = []
	for y in range(source_board.size()):
		var row: Array = []
		for x in range(source_board[y].size()):
			row.append(source_board[y][x].duplicate(true))
		new_board.append(row)
	return new_board


func _duplicate_players(source_players: Array) -> Array:
	var new_players: Array = []
	for player in source_players:
		var deck_template: Array = player.deck_template
		new_players.append({
			"name": player.name,
			"base": player.base,
			"deck_template": deck_template.duplicate(),
			"deck": player.deck.duplicate(true),
			"hand": player.hand.duplicate(true),
			"discard": player.discard.duplicate(true)
		})
	return new_players


func _make_action_variant(action_type: String, player_index: int, payload: Dictionary = {}) -> Dictionary:
	var variant = {
		"type": action_type,
		"player_index": player_index,
		"hand_index": -1,
		"cell": Vector2i(-1, -1),
		"payload": payload
	}
	if payload.has("hand_index"):
		variant.hand_index = int(payload.hand_index)
	if payload.has("cell"):
		variant.cell = payload.cell
	return variant


func _get_turn_variants_for_state(state: Dictionary, player_index: int) -> Array:
	var variants: Array = []
	if bool(state.game_over):
		return variants
	if int(state.current_player) != player_index:
		return variants

	if _can_draw_card_variant_in_state(state, player_index):
		variants.append(_make_action_variant(ACTION_DRAW_CARD, player_index))

	if _can_play_minor_action_in_state(state):
		variants.append_array(_get_deck_face_down_variants_for_state(state, player_index))

	if int(state.minor_actions_spent) == 0:
		var hand: Array = state.players[player_index].hand
		for hand_index in range(hand.size()):
			variants.append_array(_get_play_hand_variants_for_state(state, player_index, hand_index))
	return variants


func _get_play_hand_variants_for_state(state: Dictionary, player_index: int, hand_index: int) -> Array:
	var variants: Array = []
	if bool(state.game_over):
		return variants
	if int(state.current_player) != player_index:
		return variants
	if int(state.minor_actions_spent) > 0:
		return variants

	var hand: Array = state.players[player_index].hand
	if hand_index < 0 or hand_index >= hand.size():
		return variants

	var card: Dictionary = hand[hand_index].duplicate(true)
	card.face_down = false
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _can_play_card_in_state(state, card, cell):
				variants.append(_make_action_variant(ACTION_PLAY_HAND_CARD, player_index, {
					"hand_index": hand_index,
					"cell": cell
				}))
	return variants


func _get_deck_face_down_variants_for_state(state: Dictionary, player_index: int) -> Array:
	var variants: Array = []
	if bool(state.game_over):
		return variants
	if int(state.current_player) != player_index:
		return variants
	if not _can_play_minor_action_in_state(state):
		return variants

	var preview_state: Dictionary = _duplicate_game_state(state)
	if not _refill_deck_if_empty_in_state(preview_state, player_index):
		return variants

	var deck: Array = preview_state.players[player_index].deck
	if deck.is_empty():
		return variants

	var card: Dictionary = deck[deck.size() - 1].duplicate(true)
	card.face_down = true
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _can_play_card_in_state(state, card, cell):
				variants.append(_make_action_variant(ACTION_PLAY_DECK_FACE_DOWN, player_index, {
					"cell": cell
				}))
	return variants


func _simulate_action_variant(variant: Dictionary) -> Dictionary:
	var state: Dictionary = _capture_game_state()
	var result: Dictionary = _apply_action_variant_to_state(state, variant)
	return {
		"state": state,
		"result": result
	}


func _apply_action_variant_to_current_state(variant: Dictionary) -> Dictionary:
	var state: Dictionary = _get_live_game_state()
	var result: Dictionary = _apply_action_variant_to_state(state, variant)
	_restore_game_state(state)
	return result


func _apply_action_variant_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	state.events = []
	var result: Dictionary = _apply_action_core_to_state(state, variant)
	if result.status != RESULT_OK:
		result.events = state.events
		return result

	_apply_after_action_rules_to_state(state, result)
	if bool(result.get("end_turn", false)):
		_apply_end_turn_rules_to_state(state)
	result.events = state.events
	return result


func _apply_action_core_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var action_type: String = String(variant.type)
	var player_index: int = int(variant.player_index)
	if int(state.current_player) != player_index:
		return _make_action_result(RESULT_INVALID, "wrong_player")
	if bool(state.game_over):
		return _make_action_result(RESULT_INVALID, "game_over")

	if action_type == ACTION_DRAW_CARD:
		if not _can_draw_card_variant_in_state(state, player_index):
			return _make_action_result(RESULT_INVALID, "cannot_draw")
		_draw_cards_in_state(state, player_index, 1)
		var draw_result: Dictionary = _make_action_result(RESULT_OK, "")
		draw_result.end_turn = _spend_minor_action_in_state(state)
		return draw_result

	if action_type == ACTION_PLAY_HAND_CARD:
		return _apply_play_hand_card_to_state(state, variant)

	if action_type == ACTION_PLAY_DECK_FACE_DOWN:
		return _apply_play_deck_face_down_to_state(state, variant)

	return _make_action_result(RESULT_INVALID, "unknown_action")


func _apply_play_hand_card_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var player_index: int = int(variant.player_index)
	var hand_index: int = int(variant.hand_index)
	var cell: Vector2i = variant.cell
	var hand: Array = state.players[player_index].hand
	if hand_index < 0 or hand_index >= hand.size():
		return _make_action_result(RESULT_INVALID, "bad_hand_index")

	var card: Dictionary = hand[hand_index]
	card.face_down = false
	if not _can_play_card_in_state(state, card, cell):
		return _make_action_result(RESULT_INVALID, "cannot_play_card")

	hand.remove_at(hand_index)
	_place_card_in_state(state, card, cell)
	_record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"cell": cell,
		"face_down": false,
		"stack_cards": _get_stack_card_snapshots_in_state(state, cell),
		"source": {
			"type": "hand",
			"hand_index": hand_index
		}
	})
	_record_layout_stack_event_in_state(state, cell)
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.card = card
	result.cell = cell
	result.played_card = true
	result.end_turn = true
	return result


func _apply_play_deck_face_down_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var player_index: int = int(variant.player_index)
	var cell: Vector2i = variant.cell
	_refill_deck_if_empty_in_state(state, player_index)
	var deck: Array = state.players[player_index].deck
	if deck.is_empty():
		return _make_action_result(RESULT_INVALID, "empty_deck")

	var card: Dictionary = deck[deck.size() - 1]
	card.face_down = true
	if not _can_play_card_in_state(state, card, cell):
		return _make_action_result(RESULT_INVALID, "cannot_play_path")

	card = deck.pop_back()
	card.face_down = true
	_refill_deck_if_empty_in_state(state, player_index)
	_place_card_in_state(state, card, cell)
	_record_action_event_in_state(state, {
		"type": "play_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"cell": cell,
		"face_down": true,
		"stack_cards": _get_stack_card_snapshots_in_state(state, cell),
		"source": {
			"type": "base"
		}
	})
	_record_layout_stack_event_in_state(state, cell)
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.card = card
	result.cell = cell
	result.played_card = true
	result.keep_path_pending = not deck.is_empty()
	result.end_turn = _spend_minor_action_in_state(state)
	return result


func _apply_after_action_rules_to_state(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return

	_apply_played_card_effect_rules_to_state(state, result)

	var cell: Vector2i = result.cell
	var player_index: int = int(state.current_player)
	if _get_base_owner_in_state(state, cell) == _opponent(player_index):
		state.game_over = true
		state.game_over_message = _tr_text("UI_GAME_OVER") % state.players[player_index].name
		result.end_turn = false


func _apply_played_card_effect_rules_to_state(state: Dictionary, result: Dictionary) -> void:
	var card: Dictionary = result.card
	if bool(card.face_down):
		return

	var player_index: int = int(card.owner)
	var opponent_index: int = _opponent(player_index)
	var unit: Resource = card.unit
	var name_key: String = String(unit.name_key)

	if name_key == UNIT_RYTSAR_NAME:
		_draw_cards_in_state(state, player_index, 1)
	elif name_key == UNIT_GRIBNIK_NAME:
		_draw_cards_in_state(state, player_index, 2)
	elif name_key == UNIT_ABBERATSIYA_NAME:
		_draw_cards_in_state(state, opponent_index, 2)
	elif name_key == UNIT_DRAKON_NAME:
		_discard_cards_from_hand_end_in_state(state, player_index, 2)
	elif name_key == UNIT_BARON_NAME:
		_draw_cards_in_state(state, player_index, 2)
		_discard_cards_from_hand_end_in_state(state, player_index, 1)
	elif name_key == UNIT_DROVOSEK_NAME:
		_draw_then_discard_drawn_cards_in_state(state, player_index, 3, 2)
	elif name_key == UNIT_KRYSA_NAME:
		_discard_cards_from_hand_end_in_state(state, opponent_index, 1)
	elif name_key == UNIT_LUCHNIK_NAME:
		_discard_random_cards_from_hand_in_state(state, opponent_index, 1)
	elif name_key == UNIT_MOZGOSHMYG_NAME:
		_redraw_hand_in_state(state, opponent_index)
	elif name_key == UNIT_VARVAR_NAME:
		_draw_until_power_at_least_in_state(state, player_index, 5)


func _apply_end_turn_rules_to_state(state: Dictionary) -> void:
	if bool(state.game_over):
		return
	_trim_stacks_and_hands_in_state(state)
	state.minor_actions_spent = 0
	state.current_player = _opponent(int(state.current_player))


func _make_action_result(status: String, error: String) -> Dictionary:
	return {
		"status": status,
		"error": error,
		"end_turn": false,
		"keep_path_pending": false,
		"played_card": false,
		"events": []
	}


func _can_draw_card_variant_in_state(state: Dictionary, player_index: int) -> bool:
	if not _can_play_minor_action_in_state(state):
		return false
	if state.players[player_index].deck.is_empty() and not state.players[player_index].deck_template.is_empty():
		return true
	var deck: Array = state.players[player_index].deck
	return not deck.is_empty()


func _can_play_minor_action_in_state(state: Dictionary) -> bool:
	if bool(state.game_over):
		return false
	return int(state.minor_actions_spent) < TURN_MINOR_ACTIONS


func _spend_minor_action_in_state(state: Dictionary) -> bool:
	state.minor_actions_spent = int(state.minor_actions_spent) + 1
	return int(state.minor_actions_spent) >= TURN_MINOR_ACTIONS


func _on_draw_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	if _is_ai_player(current_player):
		return
	_clear_pending()
	var variant: Dictionary = _make_action_variant(ACTION_DRAW_CARD, current_player)
	var simulation: Dictionary = _simulate_action_variant(variant)
	if simulation.result.status != RESULT_OK:
		action_label.text = _tr_text("UI_ERROR_EMPTY_DECK")
		return
	animation_running = true
	_set_action_buttons_enabled(false)
	var result: Dictionary = _apply_action_variant_to_current_state(variant)
	if result.status != RESULT_OK:
		animation_running = false
		action_label.text = _tr_text("UI_ERROR_EMPTY_DECK")
		return
	await _animate_action_result(result)
	animation_running = false
	_clear_pending()
	_sync_after_state_change_without_card_layout()


func _on_deck_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	if _is_ai_player(current_player):
		return
	_clear_pending()
	ui_pending_action = "deck_face_down"
	ui_selected_hand_card_id = -1
	_sync_after_state_change_without_card_layout()


func _on_replay_pressed() -> void:
	animation_running = false
	ai_running = false
	_clear_pending()
	minor_actions_spent = 0
	current_player = 0
	game_over = false
	game_over_message = ""
	_setup_game()
	_refresh_ui()


func _on_board_cell_gui_input(event: InputEvent, cell_panel: PanelContainer) -> void:
	if game_over or animation_running or ui_pending_action == "":
		return
	if _is_ai_player(current_player):
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var cell: Vector2i = cell_panel.get_meta("cell")
	if ui_pending_action == "hand":
		_try_play_hand_card(cell)
	elif ui_pending_action == "deck_face_down":
		_try_play_from_deck_face_down(cell)


func _get_board_cell_at_global_position(global_position: Vector2) -> Vector2i:
	for cell in board_cells.keys():
		var cell_panel: Control = board_cells[cell]
		if cell_panel.get_global_rect().has_point(global_position):
			return cell
	return Vector2i(-1, -1)


func _try_play_hand_card(cell: Vector2i) -> void:
	if animation_running:
		return

	var hand: Array = players[current_player].hand
	var hand_index: int = _get_ui_selected_hand_index()
	if hand_index < 0 or hand_index >= hand.size():
		_clear_pending()
		return

	var variant: Dictionary = _make_action_variant(ACTION_PLAY_HAND_CARD, current_player, {
		"hand_index": hand_index,
		"cell": cell
	})
	var simulation: Dictionary = _simulate_action_variant(variant)
	if simulation.result.status != RESULT_OK:
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	animation_running = true
	_set_action_buttons_enabled(false)
	var result: Dictionary = _apply_action_variant_to_current_state(variant)
	if result.status != RESULT_OK:
		animation_running = false
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		_sync_after_state_change_without_card_layout()
		return
	await _animate_action_result(result)
	animation_running = false
	_clear_pending()
	_sync_after_state_change_without_card_layout()


func _try_play_from_deck_face_down(cell: Vector2i) -> void:
	var variant: Dictionary = _make_action_variant(ACTION_PLAY_DECK_FACE_DOWN, current_player, {
		"cell": cell
	})
	var simulation: Dictionary = _simulate_action_variant(variant)
	if simulation.result.status != RESULT_OK:
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_PATH")
		return
	animation_running = true
	_set_action_buttons_enabled(false)
	var result: Dictionary = _apply_action_variant_to_current_state(variant)
	if result.status != RESULT_OK:
		animation_running = false
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_PATH")
		return
	await _animate_action_result(result)
	animation_running = false

	if bool(result.keep_path_pending) and not bool(result.end_turn):
		ui_pending_action = "deck_face_down"
		ui_selected_hand_card_id = -1
	else:
		_clear_pending()
	_sync_after_state_change_without_card_layout()


func _can_play_card(card: Dictionary, cell: Vector2i) -> bool:
	return _can_play_card_in_state(_get_live_game_state(), card, cell)


func _can_play_card_in_state(state: Dictionary, card: Dictionary, cell: Vector2i) -> bool:
	if not _is_inside(cell):
		return false
	var player_index: int = int(card.owner)
	if _get_base_owner_in_state(state, cell) == player_index:
		return false
	if not _get_supplied_cells_in_state(state, player_index).has(cell):
		return false

	var stack: Array = _get_stack_in_state(state, cell)
	var base_owner: int = _get_base_owner_in_state(state, cell)
	if card.face_down:
		if base_owner != -1:
			return false
		if stack.is_empty():
			return true
		return _top_owner_in_state(state, cell) == player_index

	if base_owner == _opponent(player_index):
		return true
	if stack.is_empty():
		return true
	if _top_owner_in_state(state, cell) == player_index:
		return true
	if _top_face_down_in_state(state, cell):
		return true

	var attack_power: int = card.unit.power
	var defense_power: int = _top_power_in_state(state, cell)
	return attack_power >= defense_power


func _place_card(card: Dictionary, cell: Vector2i) -> void:
	_place_card_in_state(_get_live_game_state(), card, cell)


func _place_card_in_state(state: Dictionary, card: Dictionary, cell: Vector2i) -> void:
	var stack: Array = _get_stack_in_state(state, cell)
	stack.append(card)


func _record_action_event_in_state(state: Dictionary, event: Dictionary) -> void:
	if not state.has("events"):
		return
	state.events.append(event)


func _get_stack_card_snapshots_in_state(state: Dictionary, cell: Vector2i) -> Array:
	var snapshots: Array = []
	for card in _get_stack_in_state(state, cell):
		snapshots.append(card.duplicate(true))
	return snapshots


func _record_layout_stack_event_in_state(state: Dictionary, cell: Vector2i) -> void:
	_record_action_event_in_state(state, {
		"type": ANIMATION_LAYOUT_STACK,
		"cell": cell,
		"stack_cards": _get_stack_card_snapshots_in_state(state, cell)
	})


func _discard_card_in_state(state: Dictionary, player_index: int, card: Dictionary, source: Dictionary = {}) -> void:
	card.owner = player_index
	card.face_down = false
	state.players[player_index].discard.append(card)
	_record_action_event_in_state(state, {
		"type": "discard_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"source": source
	})
	if String(source.get("type", "")) == "board":
		_record_layout_stack_event_in_state(state, source.cell)


func _record_draw_event_in_state(state: Dictionary, player_index: int, card: Dictionary) -> void:
	_record_action_event_in_state(state, {
		"type": "draw_card",
		"card_id": int(card.id),
		"player_index": player_index,
		"unit": card.unit,
		"source": {
			"type": "base"
		}
	})


func _trim_stacks_and_hands_in_state(state: Dictionary) -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var stack: Array = state.board[y][x]
			while stack.size() > 2:
				var removed = stack.pop_front()
				_discard_card_in_state(state, removed.owner, removed, {
					"type": "board",
					"cell": Vector2i(x, y),
					"face_down": bool(removed.face_down)
				})

	for i in range(state.players.size()):
		while state.players[i].hand.size() > MAX_HAND:
			var discarded = state.players[i].hand.pop_back()
			_discard_card_in_state(state, i, discarded, {
				"type": "hand",
				"hand_index": state.players[i].hand.size()
			})


func _draw_cards_in_state(state: Dictionary, player_index: int, count: int) -> void:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	for i in range(count):
		_refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			return
		var card: Dictionary = deck.pop_back()
		card.owner = player_index
		card.face_down = false
		hand.append(card)
		_record_draw_event_in_state(state, player_index, card)
	_refill_deck_if_empty_in_state(state, player_index)


func _refill_deck_if_empty_in_state(state: Dictionary, player_index: int) -> bool:
	var deck: Array = state.players[player_index].deck
	if not deck.is_empty():
		return true

	var deck_template: Array = state.players[player_index].deck_template
	if deck_template.is_empty():
		return false

	for unit in deck_template:
		deck.append(_make_card_in_state(state, unit, player_index, false))
	deck.shuffle()
	return true


func _discard_cards_from_hand_end_in_state(state: Dictionary, player_index: int, count: int) -> void:
	var hand: Array = state.players[player_index].hand
	for i in range(count):
		if hand.is_empty():
			return
		var hand_index: int = hand.size() - 1
		var card: Dictionary = hand.pop_back()
		_discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})


func _discard_random_cards_from_hand_in_state(state: Dictionary, player_index: int, count: int) -> void:
	var hand: Array = state.players[player_index].hand
	for i in range(count):
		if hand.is_empty():
			return
		var hand_index: int = randi_range(0, hand.size() - 1)
		var card: Dictionary = hand[hand_index]
		hand.remove_at(hand_index)
		_discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})


func _draw_then_discard_drawn_cards_in_state(state: Dictionary, player_index: int, draw_count: int, discard_count: int) -> void:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	var drawn_cards: Array = []
	for i in range(draw_count):
		_refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			break
		drawn_cards.append(deck.pop_back())
	_refill_deck_if_empty_in_state(state, player_index)

	while drawn_cards.size() > 0 and discard_count > 0:
		var discarded_card: Dictionary = drawn_cards.pop_back()
		_discard_card_in_state(state, player_index, discarded_card, {
			"type": "base"
		})
		discard_count -= 1

	for card in drawn_cards:
		card.owner = player_index
		card.face_down = false
		hand.append(card)
		_record_draw_event_in_state(state, player_index, card)


func _redraw_hand_in_state(state: Dictionary, player_index: int) -> void:
	var hand: Array = state.players[player_index].hand
	var card_count: int = hand.size()
	while not hand.is_empty():
		var hand_index: int = hand.size() - 1
		var card: Dictionary = hand.pop_back()
		_discard_card_in_state(state, player_index, card, {
			"type": "hand",
			"hand_index": hand_index
		})
	_draw_cards_in_state(state, player_index, card_count)


func _draw_until_power_at_least_in_state(state: Dictionary, player_index: int, minimum_power: int) -> void:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	var checked_count: int = 0
	var max_checks: int = state.players[player_index].deck_template.size()
	while checked_count < max_checks:
		_refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			return
		var card: Dictionary = deck.pop_back()
		checked_count += 1
		if int(card.unit.power) >= minimum_power:
			card.owner = player_index
			card.face_down = false
			hand.append(card)
			_record_draw_event_in_state(state, player_index, card)
			_refill_deck_if_empty_in_state(state, player_index)
			return
		_discard_card_in_state(state, player_index, card, {
			"type": "base"
		})
	_refill_deck_if_empty_in_state(state, player_index)


func _get_supplied_cells_in_state(state: Dictionary, player_index: int) -> Dictionary:
	var supplied = {}
	var base: Vector2i = state.players[player_index].base
	var queue: Array = [base]
	supplied[base] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if not _is_inside(next):
				continue
			if supplied.has(next):
				continue
			if _has_barrier_in_state(state, current, next):
				continue
			supplied[next] = true
			if _top_owner_in_state(state, next) == player_index:
				queue.append(next)

	return supplied


func _get_stack_in_state(state: Dictionary, cell: Vector2i) -> Array:
	return state.board[cell.y][cell.x]


func _top_owner_in_state(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = _get_stack_in_state(state, cell)
	if stack.is_empty():
		return -1
	return int(stack[stack.size() - 1].owner)


func _top_power_in_state(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = _get_stack_in_state(state, cell)
	if stack.is_empty():
		return 0
	var card: Dictionary = stack[stack.size() - 1]
	if card.face_down:
		return 0
	return int(card.unit.power)


func _top_face_down_in_state(state: Dictionary, cell: Vector2i) -> bool:
	var stack: Array = _get_stack_in_state(state, cell)
	if stack.is_empty():
		return false
	return bool(stack[stack.size() - 1].face_down)


func _get_base_owner_in_state(state: Dictionary, cell: Vector2i) -> int:
	for i in range(state.players.size()):
		if state.players[i].base == cell:
			return i
	return -1


func _has_barrier_in_state(state: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return state.barriers.has(_edge_key(a, b))


func _trim_stacks_and_hands() -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var stack: Array = board[y][x]
			while stack.size() > 2:
				var removed = stack.pop_front()
				removed.face_down = false
				players[removed.owner].discard.append(removed)

		for i in range(players.size()):
			while players[i].hand.size() > MAX_HAND:
				var discarded = players[i].hand.pop_back()
				discarded.face_down = false
				players[i].discard.append(discarded)


func _end_turn() -> void:
	if animation_running:
		return
	if game_over:
		_sync_after_state_change_without_card_layout()
		return
	_trim_stacks_and_hands()
	_clear_pending()
	minor_actions_spent = 0
	current_player = _opponent(current_player)
	_sync_after_state_change_without_card_layout()


func _clear_pending() -> void:
	ui_pending_action = ""
	ui_selected_hand_card_id = -1


func _can_press_minor_action_button() -> bool:
	if game_over or animation_running:
		return false
	if _is_ai_player(current_player):
		return false
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		return false
	return ui_pending_action == "" or ui_pending_action == "hand" or ui_pending_action == "deck_face_down"


func _finish_minor_action(keep_path_pending: bool = false) -> void:
	minor_actions_spent += 1
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		_clear_pending()
		_end_turn()
	else:
		if keep_path_pending:
			ui_pending_action = "deck_face_down"
			ui_selected_hand_card_id = -1
		else:
			_clear_pending()
		_sync_after_state_change_without_card_layout()


func _minor_actions_left() -> int:
	return max(0, TURN_MINOR_ACTIONS - minor_actions_spent)


func _draw_cards(player_index: int, count: int) -> void:
	_draw_cards_in_state(_get_live_game_state(), player_index, count)


func _get_supplied_cells(player_index: int) -> Dictionary:
	var supplied = {}
	var base: Vector2i = players[player_index].base
	var queue: Array = [base]
	supplied[base] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if not _is_inside(next):
				continue
			if supplied.has(next):
				continue
			if _has_barrier(current, next):
				continue
			supplied[next] = true
			if _top_owner(next) == player_index:
				queue.append(next)

	return supplied


func _get_supply_parents(player_index: int) -> Dictionary:
	var parents = {}
	var supplied = {}
	var base: Vector2i = players[player_index].base
	var queue: Array = [base]
	supplied[base] = true
	parents[base] = base

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if not _is_inside(next):
				continue
			if supplied.has(next):
				continue
			if _has_barrier(current, next):
				continue
			supplied[next] = true
			parents[next] = current
			if _top_owner(next) == player_index:
				queue.append(next)

	return parents


func _get_stack(cell: Vector2i) -> Array:
	return board[cell.y][cell.x]


func _top_owner(cell: Vector2i) -> int:
	var stack: Array = _get_stack(cell)
	if stack.is_empty():
		return -1
	return int(stack[stack.size() - 1].owner)


func _top_power(cell: Vector2i) -> int:
	var stack: Array = _get_stack(cell)
	if stack.is_empty():
		return 0
	var card: Dictionary = stack[stack.size() - 1]
	if card.face_down:
		return 0
	return int(card.unit.power)


func _top_face_down(cell: Vector2i) -> bool:
	var stack: Array = _get_stack(cell)
	if stack.is_empty():
		return false
	return bool(stack[stack.size() - 1].face_down)


func _get_base_owner(cell: Vector2i) -> int:
	for i in range(players.size()):
		if players[i].base == cell:
			return i
	return -1


func _opponent(player_index: int) -> int:
	return 1 - player_index


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func _generate_initial_barriers() -> void:
	var all_edges: Array = _get_all_board_edges()
	all_edges.shuffle()

	for first_edge in all_edges:
		barriers.clear()
		_add_barrier(first_edge[0], first_edge[1])
		_add_rotated_barrier(first_edge[0], first_edge[1])

		var candidates: Array = _get_all_board_edges()
		candidates.shuffle()
		for second_edge in candidates:
			var previous_barriers = barriers.duplicate()
			_add_barrier(second_edge[0], second_edge[1])
			_add_rotated_barrier(second_edge[0], second_edge[1])

			if barriers.size() == 4 and _bases_are_connected():
				return

			barriers = previous_barriers

	barriers.clear()


func _get_all_board_edges() -> Array:
	var edges: Array = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var right: Vector2i = cell + Vector2i.RIGHT
			if _is_inside(right):
				edges.append([cell, right])

			var down: Vector2i = cell + Vector2i.DOWN
			if _is_inside(down):
				edges.append([cell, down])
	return edges


func _add_rotated_barrier(a: Vector2i, b: Vector2i) -> void:
	_add_barrier(_rotate_cell(a), _rotate_cell(b))


func _rotate_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(GRID_WIDTH - 1 - cell.x, GRID_HEIGHT - 1 - cell.y)


func _bases_are_connected() -> bool:
	var start: Vector2i = Vector2i(1, 1)
	var target: Vector2i = Vector2i(5, 3)
	var visited = {}
	var queue: Array = [start]
	visited[start] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			return true

		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if not _is_inside(next):
				continue
			if visited.has(next):
				continue
			if _has_barrier(current, next):
				continue
			visited[next] = true
			queue.append(next)

	return false


func _add_barrier(a: Vector2i, b: Vector2i) -> void:
	barriers[_edge_key(a, b)] = true


func _has_barrier(a: Vector2i, b: Vector2i) -> bool:
	return barriers.has(_edge_key(a, b))


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first: Vector2i = a
	var second: Vector2i = b
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		first = b
		second = a
	return "%d,%d-%d,%d" % [first.x, first.y, second.x, second.y]


func _set_action_buttons_enabled(enabled: bool) -> void:
	draw_two_button.disabled = not enabled or animation_running
	deck_two_button.disabled = not enabled or animation_running
