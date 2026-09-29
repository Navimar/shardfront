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
const GAME_MODE_AI: String = "ai"
const GAME_MODE_SOLO: String = "solo"
const DECK_ALL_STATUSES: Array = []
const DECK_UNIMPLEMENTED_STATUSES: Array = [UnitResource.IMPLEMENTATION_UNIMPLEMENTED]
const DECK_IMPLEMENTED_UNTESTED_STATUSES: Array = [UnitResource.IMPLEMENTATION_IMPLEMENTED]
const DECK_READY_STATUSES: Array = [UnitResource.IMPLEMENTATION_IMPLEMENTED, UnitResource.IMPLEMENTATION_TESTED]
const DECK_UNIT_STATUSES: Array = DECK_IMPLEMENTED_UNTESTED_STATUSES
const HUMAN_PLAYER_INDEX: int = 0
const AI_PLAYERS: Array = [1]
const PLAYER_BASE_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(5, 3)]
const AI_THINK_DELAY: float = 0.35
const TEMPO_BAR_HEIGHT: int = 6
const TEMPO_BAR_VERTICAL_WIDTH: int = 10
const CARD_FLY_DURATION: float = 0.72
const CARD_DISCARD_FLIP_DURATION: float = 0.18
const CARD_REVEAL_DURATION: float = 0.9
const ACTION_DRAW_CARD: String = "draw_card"
const ACTION_PLAY_HAND_CARD: String = "play_hand_card"
const ACTION_PLAY_DECK_FACE_DOWN: String = "play_deck_face_down"
const ACTION_SOLO_PLAY: String = "solo_play"
const ACTION_SOLO_PATH: String = "solo_path"
const ANIMATION_LAYOUT_STACK: String = "layout_stack"
const ANIMATION_SUPPLY_CONTROL: String = "supply_control"
const ANIMATION_REVEAL_HAND_CARD: String = "reveal_hand_card"
const RESULT_OK: String = "ok"
const RESULT_INVALID: String = "invalid"
const WOOD_CARD_COLOR: Color = Color(0.58, 0.32, 0.08)
const METAL_CARD_COLOR: Color = Color(0.06, 0.38, 0.62)
const BARRIER_FILL_COLOR: Color = Color(0.88, 0.69, 0.32)
const TOOLTIP_BACKGROUND_COLOR: Color = Color(0.03, 0.025, 0.02)
const BOARD_CELL_FILL_COLOR: Color = Color(0.12, 0.12, 0.12, 0.0)
const BOARD_OCCUPIED_CELL_FILL_COLOR: Color = Color(0.12, 0.12, 0.12, 0.0)
const BOARD_CELL_BORDER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const BOARD_GRID_LINE_COLOR: Color = Color(0.02, 0.018, 0.014, 0.34)
const BOARD_GRID_LINE_WIDTH: float = 1.0
const BOARD_GRID_SKETCH_STROKES: int = 3
const BOARD_GRID_SKETCH_SEGMENTS: int = 18
const BOARD_GRID_SKETCH_JITTER: float = 1.35
const SUPPLY_CONTROL_ALPHA: float = 0.65
const SUPPLY_CONTROL_DARKEN_AMOUNT: float = 0.35
const SUPPLY_CONTROL_FADE_DURATION: float = 0.28
const PLAYABLE_SUPPLY_PIPE_WIDTH: float = float(CELL_GAP)
const UnitScene: PackedScene = preload("res://scenes/unit.tscn")
const CardTitleFont: FontFile = preload("res://assets/fonts/RussoOne-Regular.ttf")
const BarrierOps: Script = preload("res://scripts/main/barrier_ops.gd")
const BoardTopology: Script = preload("res://scripts/main/board_topology.gd")
const GameAi: Script = preload("res://scripts/main/game_ai.gd")
const GameActionRestrictions: Script = preload("res://scripts/main/game_action_restrictions.gd")
const GameAnimation: Script = preload("res://scripts/main/game_animation.gd")
const GameBoardQuery: Script = preload("res://scripts/main/game_board_query.gd")
const GameBoardDraw: Script = preload("res://scripts/main/game_board_draw.gd")
const GamePlayEffects: Script = preload("res://scripts/main/game_play_effects.gd")
const GamePlayLegality: Script = preload("res://scripts/main/game_play_legality.gd")
const GamePlayReactions: Script = preload("res://scripts/main/game_play_reactions.gd")
const GamePending: Script = preload("res://scripts/main/game_pending.gd")
const GamePower: Script = preload("res://scripts/main/game_power.gd")
const GameSupply: Script = preload("res://scripts/main/game_supply.gd")
const GameTargets: Script = preload("res://scripts/main/game_targets.gd")
const GameTabletop: Script = preload("res://scripts/main/game_tabletop.gd")
const CardAbilities: Script = preload("res://scripts/main/card_abilities.gd")
const GameSolo: Script = preload("res://scripts/main/game_solo.gd")
const UnitKeys: Script = preload("res://scripts/main/unit_keys.gd")
const WoodBaseTexture: Texture2D = preload("res://assets/bases/base_single.jpg")
const MetalBaseTexture: Texture2D = preload("res://assets/bases/bases_pair.jpg")
const WoodBaseDestroyedTexture: Texture2D = preload("res://assets/bases/base_red_destroyed.jpg")
const MetalBaseDestroyedTexture: Texture2D = preload("res://assets/bases/base_blue_destroyed.jpg")
const TableBackgroundTexture: Texture2D = preload("res://assets/backgrounds/table_stone_background.jpg")

var board = []
var barriers = {}
var players = []
var current_player: int = 0
var ui_selected_hand_card_id: int = -1
var minor_actions_spent: int = 0
var game_over: bool = false
var game_over_message: String = ""
var destroyed_base_owner: int = -1
var turn_restrictions: Array = []
var barrier_removal_options: Array = []
var animation_running: bool = false
var ai_running: bool = false
var game_mode: String = GAME_MODE_AI
var action_restriction_logic: RefCounted
var ai_logic: RefCounted
var animation_logic: RefCounted
var board_topology: RefCounted
var barrier_ops: RefCounted
var board_query: RefCounted
var board_draw_logic: RefCounted
var pending_logic: RefCounted
var play_effect_logic: RefCounted
var play_legality_logic: RefCounted
var play_reaction_logic: RefCounted
var power_logic: RefCounted
var supply_logic: RefCounted
var target_logic: RefCounted
var solo_logic: RefCounted
var tabletop_logic: RefCounted
var next_card_id: int = 1
var supply_control_transition: Dictionary = {}
var supply_control_transition_progress: float = 1.0

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
var finish_choice_button: Button
var strateg_take_button: Button
var replay_button: Button
var discard_button: Button
var opponent_discard_button: Button
var game_mode_selector: OptionButton
var solo_plan_label: Label
var discard_dialog: AcceptDialog
var discard_grid: GridContainer


func _ready() -> void:
	TranslationServer.set_locale("ru")
	randomize()
	action_restriction_logic = GameActionRestrictions.new(self)
	ai_logic = GameAi.new(self)
	animation_logic = GameAnimation.new(self)
	board_topology = BoardTopology.new(GRID_WIDTH, GRID_HEIGHT)
	barrier_ops = BarrierOps.new(board_topology)
	board_query = GameBoardQuery.new(board_topology, barrier_ops, PLAYER_BASE_CELLS.size())
	board_draw_logic = GameBoardDraw.new(self)
	pending_logic = GamePending.new(self)
	play_effect_logic = GamePlayEffects.new(self)
	play_legality_logic = GamePlayLegality.new(self)
	play_reaction_logic = GamePlayReactions.new(self)
	power_logic = GamePower.new(self)
	supply_logic = GameSupply.new(board_query)
	target_logic = GameTargets.new(self)
	solo_logic = GameSolo.new(self)
	tabletop_logic = GameTabletop.new(self)
	_setup_game()
	_build_ui()
	_refresh_ui()


func _input(event: InputEvent) -> void:
	if game_over or animation_running or pending_logic.action == "":
		return
	if _is_ai_player(current_player) and not _pending_action_belongs_to_view_player():
		return
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if pending_logic.action == "target" and pending_logic.is_choice_target():
		var edge: Array = _get_board_edge_at_global_position(event.global_position)
		if not edge.is_empty():
			get_viewport().set_input_as_handled()
			await pending_logic.try_apply_target_edge(edge)
			return


func _setup_game() -> void:
	board.clear()
	next_card_id = 1
	game_over = false
	game_over_message = ""
	destroyed_base_owner = -1
	turn_restrictions.clear()
	barrier_removal_options.clear()
	if solo_logic != null:
		solo_logic.reset()
	if tabletop_logic != null:
		tabletop_logic.attack_discard_selections.clear()
	_clear_all_card_views()
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append([])
		board.append(row)

	barriers.clear()
	_generate_initial_barriers()

	var all_units: Array = _load_units(DECK_UNIT_STATUSES)
	var second_units: Array = all_units.duplicate()
	if _is_solo_mode():
		second_units = solo_logic.make_deck_template()
	var first_deck: Array = _make_deck_from_units(all_units, 0)
	var second_deck: Array = _make_deck_from_units(second_units, 1)
	first_deck.shuffle()
	second_deck.shuffle()

	players = [
		{
			"name": "Древесный игрок",
			"base": PLAYER_BASE_CELLS[0],
			"deck_template": all_units.duplicate(),
			"deck": first_deck,
			"hand": [],
			"discard": [], "next_attack_bonus": 0, "in_end_turn": false, "gondola_finished": false
		},
		{
			"name": _tr_text("SOLO_ENEMY_PLAYER_NAME") if _is_solo_mode() else "Металлический игрок",
			"base": PLAYER_BASE_CELLS[1],
			"deck_template": second_units.duplicate(),
			"deck": second_deck,
			"hand": [],
			"discard": [], "next_attack_bonus": 0, "in_end_turn": false, "gondola_finished": false
		}
	]

	_draw_cards(0, 4)
	if _is_solo_mode():
		solo_logic.prepare_plan(_get_live_game_state())
	else:
		_draw_cards(1, 5)
	if board_draw_logic != null:
		board_draw_logic.set_displayed_supply_origin_cells(_get_all_supply_origin_cells_in_state(_get_live_game_state()))


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

	finish_choice_button = Button.new()
	finish_choice_button.visible = false
	finish_choice_button.pressed.connect(_on_finish_choice_pressed)
	hand_content.add_child(finish_choice_button)

	strateg_take_button = Button.new()
	strateg_take_button.text = "Взять"
	strateg_take_button.visible = false
	strateg_take_button.pressed.connect(_on_strateg_take_pressed)
	hand_content.add_child(strateg_take_button)

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
	board_grid.resized.connect(board_draw_logic.queue_board_redraw)
	board_area.add_child(board_grid)

	supply_line_layer = Control.new()
	supply_line_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	supply_line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_line_layer.z_index = 5
	supply_line_layer.draw.connect(board_draw_logic.on_supply_line_layer_draw)
	supply_line_layer.resized.connect(board_draw_logic.queue_board_redraw)
	board_area.add_child(supply_line_layer)

	barrier_layer = Control.new()
	barrier_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	barrier_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrier_layer.z_index = 20
	barrier_layer.draw.connect(board_draw_logic.on_barrier_layer_draw)
	barrier_layer.resized.connect(board_draw_logic.queue_board_redraw)
	board_area.add_child(barrier_layer)

	tempo_debug_label = Label.new()
	tempo_debug_label.custom_minimum_size = Vector2(360.0, 72.0)
	tempo_debug_label.size = tempo_debug_label.custom_minimum_size
	tempo_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tempo_debug_label.z_index = 2049
	tempo_debug_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	tempo_debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	tempo_debug_label.add_theme_constant_override("shadow_offset_x", 2)
	tempo_debug_label.add_theme_constant_override("shadow_offset_y", 2)
	tempo_debug_label.add_theme_font_size_override("font_size", 12)
	tempo_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tempo_debug_label.visible = true
	board_area.add_child(tempo_debug_label)

	var opponent_hand_panel = VBoxContainer.new()
	opponent_hand_panel.custom_minimum_size = Vector2(225, side_panel_height)
	opponent_hand_panel.add_theme_constant_override("separation", 9)
	main_row.add_child(opponent_hand_panel)

	game_mode_selector = OptionButton.new()
	game_mode_selector.tooltip_text = _tr_text("UI_TOOLTIP_GAME_MODE")
	game_mode_selector.add_item(_tr_text("UI_GAME_MODE_AI"))
	game_mode_selector.add_item(_tr_text("UI_GAME_MODE_SOLO"))
	game_mode_selector.select(1 if _is_solo_mode() else 0)
	game_mode_selector.item_selected.connect(_on_game_mode_selected)
	opponent_hand_panel.add_child(game_mode_selector)

	solo_plan_label = Label.new()
	solo_plan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	solo_plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	solo_plan_label.add_theme_font_override("font", CardTitleFont)
	solo_plan_label.add_theme_font_size_override("font_size", 18)
	solo_plan_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	opponent_hand_panel.add_child(solo_plan_label)

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
	action_label.add_theme_font_override("font", CardTitleFont)
	action_label.add_theme_font_size_override("font_size", 32)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	action_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	action_label.add_theme_constant_override("outline_size", 6)
	main_column.add_child(action_label)

	_build_discard_dialog()
	_resize_board_to_available.call_deferred()


func _is_solo_mode() -> bool:
	return game_mode == GAME_MODE_SOLO


func _on_game_mode_selected(index: int) -> void:
	var selected_mode: String = GAME_MODE_SOLO if index == 1 else GAME_MODE_AI
	if selected_mode == game_mode:
		return
	if animation_running or ai_running:
		game_mode_selector.select(1 if _is_solo_mode() else 0)
		return
	game_mode = selected_mode
	pending_logic.clear()
	ui_selected_hand_card_id = -1
	minor_actions_spent = 0
	current_player = 0
	game_over = false
	game_over_message = ""
	destroyed_base_owner = -1
	_setup_game()
	_refresh_ui()


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
			cell_panel.add_theme_stylebox_override("panel", _make_cell_style(_get_board_cell_fill_color(has_stack), BOARD_CELL_BORDER_COLOR))
			label.modulate = Color(1.0, 1.0, 1.0)
		else:
			cell_panel.add_theme_stylebox_override("panel", _make_cell_style(_get_board_cell_fill_color(has_stack), BOARD_CELL_BORDER_COLOR))
			label.modulate = Color(1.0, 1.0, 1.0)

	board_draw_logic.queue_board_redraw()
	_refresh_discard_button()
	_refresh_game_mode_controls()
	_set_action_buttons_enabled(_can_press_minor_action_button())
	_refresh_finish_choice_button()
	replay_button.visible = game_over
	_refresh_tempo_bar()
	_sync_visible_card_visual_state()


func _refresh_game_mode_controls() -> void:
	if game_mode_selector != null:
		game_mode_selector.select(1 if _is_solo_mode() else 0)
		game_mode_selector.disabled = animation_running or ai_running
	if solo_plan_label == null:
		return
	solo_plan_label.visible = _is_solo_mode()
	if not _is_solo_mode():
		solo_plan_label.text = ""
		return
	var visible_plan_size: int = solo_logic.get_visible_plan().size()
	var deck_size: int = players[1].deck.size()
	solo_plan_label.text = _tr_text("UI_SOLO_PLAN_SUMMARY") % [visible_plan_size, deck_size]


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
		_configure_card_view(card_control, card, bool(card.face_down), false, is_covered)
		if not bool(card.face_down) and not is_covered:
			card_control.set_display_power(int(card.get("copied_power", card.unit.power)), power_logic.get_card_power_in_cell(_get_live_game_state(), card, cell))
		if pending_logic.is_target_card(int(card.id)):
			_add_selected_card_frame(card_control)


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
		var is_robot_selection: bool = current_player == view_player and (
			int(card.id) == ui_selected_hand_card_id
			or int(card.id) == pending_logic.robot_copy_card_id
		)
		if _is_hand_card_inactive_for_current_pending(card):
			card_control.set_portrait_desaturated(true)
			card_control.set_text_muted(true)
		if is_robot_selection:
			_add_selected_card_frame(card_control)


func _sync_opponent_hand_card_visual_state() -> void:
	var opponent_index: int = _opponent(_get_view_player())
	var hand: Array = players[opponent_index].hand
	for card in hand:
			var card_control: Control = card_views.get(int(card.id), null)
			if card_control == null or not is_instance_valid(card_control):
				continue
			_configure_card_view(card_control, card, true, false, false)


func _is_hand_card_inactive_for_current_pending(card: Dictionary) -> bool:
	return pending_logic.is_hand_card_inactive(card)


func _sync_after_state_change_without_card_layout() -> void:
	_sync_base_visuals()
	_sync_ui_chrome()
	_queue_ai_turn_if_needed()


func _refresh_tempo_bar() -> void:
	if _is_solo_mode():
		if tempo_debug_label != null:
			tempo_debug_label.visible = false
		if tempo_bar != null:
			tempo_bar.visible = false
		return
	if tempo_debug_label != null:
		tempo_debug_label.text = _get_tempo_debug_text()
		tempo_debug_label.visible = true
	if tempo_bar != null:
		tempo_bar.visible = true
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


func _refresh_finish_choice_button() -> void:
	strateg_take_button.visible = pending_logic.action == "strateg"
	strateg_take_button.disabled = animation_running or (_is_ai_player(current_player) and not _pending_action_belongs_to_view_player())
	var can_finish: bool = pending_logic.can_finish_choice_target()
	finish_choice_button.visible = can_finish
	if not can_finish:
		finish_choice_button.disabled = true
		return
	if pending_logic.action == "hand_discard":
		finish_choice_button.text = "Готово"
	elif pending_logic.action == "strateg":
		finish_choice_button.text = "Дальше"
	elif pending_logic.is_repeating_choice_target():
		finish_choice_button.text = "Готово"
	elif String(pending_logic.target_request.get("kind", "")) != "optional_remove_barrier":
		finish_choice_button.text = "Готово"
	else:
		finish_choice_button.text = "Пропустить"
	finish_choice_button.disabled = animation_running or (_is_ai_player(current_player) and not _pending_action_belongs_to_view_player())


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
		_connect_discard_card_input(unit_control)
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
		var is_robot_selection: bool = current_player == view_player and (
			int(card.id) == ui_selected_hand_card_id
			or int(card.id) == pending_logic.robot_copy_card_id
		)
		if _is_hand_card_inactive_for_current_pending(card):
			unit_control.set_portrait_desaturated(true)
			unit_control.set_text_muted(true)
		if is_robot_selection:
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
	if pending_logic.action == "hand":
		if pending_logic.has_robot_copy_selection():
			var copied_card: Dictionary = _find_card_by_id_in_array(
				players[_get_view_player()].hand,
				pending_logic.robot_copy_card_id
			)
			if not copied_card.is_empty():
				return _tr_text("UI_STATUS_CHOOSE_ROBOT_CELL") % copied_card.unit.get_display_name()
		return _tr_text("UI_STATUS_CHOOSE_HAND_CELL")
	if pending_logic.action == "robot_copy":
		return _tr_text("UI_STATUS_CHOOSE_ROBOT_COPY")
	if pending_logic.action == "deck_face_down":
		return _tr_text("UI_STATUS_CHOOSE_PATH_CELL")
	if pending_logic.action == "target":
		if pending_logic.is_choice_target():
			if pending_logic.is_repeating_choice_target():
				return "Выберите ребра."
			if pending_logic.can_finish_choice_target():
				return "Выберите ребро или пропустите."
			if not pending_logic.selected_target_edge.is_empty():
				return "Выберите новое ребро."
			return "Выберите ребро."
		if pending_logic.is_repeating_choice_target():
			return "Выберите цели или завершите." if pending_logic.can_finish_choice_target() else "Выберите порядок всех целей."
		return "Выберите цель."
	if pending_logic.action == "hand_discard":
		if pending_logic.is_hand_limit_discard():
			return _tr_text("UI_STATUS_DISCARD_HAND_OVERFLOW") % pending_logic.hand_discard_count
		return "Выберите карты для сброса (%d)." % pending_logic.hand_discard_count
	if pending_logic.action == "hand_pick":
		return "Выберите карту из руки."
	if pending_logic.action == "discard_pick":
		return "Выберите карту из сброса."
	if pending_logic.action == "strateg":
		return "Стратег: выберите карту, чтобы взять, или сбросьте ее."
	if _is_ai_player(current_player):
		if _is_solo_mode():
			return _tr_text("UI_STATUS_SOLO_RESOLVING")
		return "%s думает..." % players[current_player].name
	if minor_actions_spent > 0:
		var minor_status: String = _tr_text("UI_STATUS_MINOR_ACTIONS_LEFT")
		if _is_solo_mode():
			return "%s %s" % [minor_status, _tr_text("UI_STATUS_SOLO_PLAN") % solo_logic.get_visible_plan().size()]
		return minor_status
	var action_status: String = _tr_text("UI_STATUS_CHOOSE_ACTION")
	if _is_solo_mode():
		return "%s %s" % [action_status, _tr_text("UI_STATUS_SOLO_PLAN") % solo_logic.get_visible_plan().size()]
	return action_status


func _get_playable_cells_for_ui_pending_action() -> Dictionary:
	var playable = {}
	if pending_logic.action == "hand":
		var hand_index: int = _get_ui_selected_hand_index()
		var robot_copy_card_id: int = pending_logic.get_robot_copy_card_id(ui_selected_hand_card_id)
		for variant in _get_play_hand_variants_for_state(
			_get_live_game_state(),
			current_player,
			hand_index,
			false,
			{},
			robot_copy_card_id,
			int(tabletop_logic.attack_discard_selections.get(ui_selected_hand_card_id, -2))
		):
			playable[variant.cell] = variant.get("play_access", {})
	elif pending_logic.action == "deck_face_down":
		for variant in _get_deck_face_down_variants_for_state(_get_live_game_state(), current_player):
			playable[variant.cell] = variant.get("play_access", {})
	elif pending_logic.action == "target":
		for cell in pending_logic.get_target_cells():
			playable[cell] = {
				"kind": "target",
				"sources": []
			}
	return playable


func _get_playable_edges_for_ui_pending_action() -> Array:
	if pending_logic.action == "target" and pending_logic.is_choice_target():
		return pending_logic.get_target_edges()
	return []


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
	_position_tempo_debug_label()

	for cell_panel in board_cells.values():
		cell_panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

	board_draw_logic.queue_board_redraw()


func _position_tempo_debug_label() -> void:
	if tempo_debug_label == null or board_grid == null:
		return
	tempo_debug_label.position = board_grid.position + Vector2(8.0, 8.0)


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


func _get_board_cell_fill_color(has_stack: bool) -> Color:
	if has_stack:
		return BOARD_OCCUPIED_CELL_FILL_COLOR
	return BOARD_CELL_FILL_COLOR


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
	var plan_entry: Dictionary = {}
	if _is_solo_mode():
		plan_entry = solo_logic.get_entry_for_cell(cell)
	var plan_tooltip: String = ""
	if not plan_entry.is_empty():
		if String(plan_entry.get("kind", solo_logic.PLAN_KIND_COMBAT)) == solo_logic.PLAN_KIND_PATH:
			plan_tooltip = _tr_text("UI_TOOLTIP_SOLO_PLAN_PATH")
		else:
			plan_tooltip = _tr_text("UI_TOOLTIP_SOLO_PLAN") % int(plan_entry.power)
	var base_owner: int = _get_base_owner(cell)
	if base_owner != -1:
		var base_tooltip: String = _get_base_tooltip(base_owner)
		if not plan_tooltip.is_empty():
			return "%s\n%s" % [base_tooltip, plan_tooltip]
		return base_tooltip
	return plan_tooltip


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
	if card.has("ability_unit"):
		var copied: Resource = CardAbilities.ability_unit(card)
		return _wrap_tooltip_text("Копирует " + copied.get_display_name() + ": " + copied.get_description())
	if card.has("copied_name"):
		return _wrap_tooltip_text("Копирует силу и 🃏: " + String(card.copied_name) + ". " + unit.get_description())
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
		base_container.remove_child(child)
		child.free()

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
		if _is_base_destroyed(base_owner):
			base_image.texture = WoodBaseDestroyedTexture
		else:
			base_image.texture = WoodBaseTexture
	else:
		if _is_base_destroyed(base_owner):
			base_image.texture = MetalBaseDestroyedTexture
		else:
			base_image.texture = MetalBaseTexture
	base_container.add_child(base_image)


func _is_base_destroyed(base_owner: int) -> bool:
	return game_over and destroyed_base_owner == base_owner


func _sync_board_stack_card_views(cell: Vector2i, stack_container: Control) -> void:
	var stack: Array = _get_stack(cell)
	for i in range(stack.size()):
		var card = stack[i]
		var card_control: Control = _ensure_card_view(card)
		var is_covered: bool = i < stack.size() - 1
		_configure_card_view(card_control, card, bool(card.face_down), false, is_covered)
		if not bool(card.face_down) and not is_covered:
			card_control.set_display_power(int(card.get("copied_power", card.unit.power)), power_logic.get_card_power_in_cell(_get_live_game_state(), card, cell))
		card_control.tooltip_text = _get_card_tooltip(card)
		_prepare_board_card_interaction(card_control, cell)
		_attach_card_view_to_container(card_control, stack_container)
		card_control.position = _get_board_stack_card_local_position(stack.size(), i)
		card_control.z_index = i
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
	await animation_logic.animate_action_result(result)


func _finish_play_card_animation(card_control: Control, event: Dictionary) -> void:
	var cell: Vector2i = event.cell
	var card_id: int = int(event.card_id)
	var card: Dictionary = _find_card_by_id_on_board(cell, card_id)
	if card.is_empty():
		card = _get_card_from_event(event)
	var stack_container: Control = board_cell_stacks[cell]
	stack_container.visible = true
	_configure_card_view(card_control, card, bool(card.face_down), false, false)
	if not bool(card.face_down):
		card_control.set_display_power(int(card.get("copied_power", card.unit.power)), power_logic.get_card_power_in_cell(_get_live_game_state(), card, cell))
	_prepare_board_card_interaction(card_control, cell)
	_attach_card_view_to_container(card_control, stack_container)
	var stack: Array = _get_event_stack_cards(event, cell)
	var stack_index: int = _find_card_index_in_array(stack, card_id)
	if stack_index < 0:
		stack_index = stack.size() - 1
	card_control.position = _get_board_stack_card_local_position(stack.size(), stack_index)
	card_control.z_index = stack_index
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


func _finish_reveal_hand_card_animation(card_control: Control, event: Dictionary) -> void:
	if card_control == null or not is_instance_valid(card_control):
		return
	var player_index: int = int(event.player_index)
	var card_id: int = int(event.card_id)
	if _find_card_by_id_in_array(players[player_index].hand, card_id).is_empty():
		_finish_discard_card_animation(card_control)
		return
	_finish_draw_card_animation(card_control, player_index, card_id)


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
	var visual_index: int = min(stack_size - 1 - stack_index, 1)
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


func _get_supply_edges(player_index: int) -> Dictionary:
	return supply_logic.get_supply_edges(_get_live_game_state(), player_index)


func _get_supply_origin_cells(player_index: int) -> Dictionary:
	return supply_logic.get_supply_origin_cells(_get_live_game_state(), player_index)


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var card_id: int = int(unit_control.get_meta("card_id"))
		if pending_logic.action == "strateg":
			await pending_logic.try_take_strateg_preview(card_id)
			return
		if pending_logic.action == "hand_pick":
			await pending_logic.try_pick_hand_card(card_id)
			return
		if pending_logic.action == "hand_discard":
			await pending_logic.try_discard_hand_card(card_id)
			return
		if pending_logic.is_selecting_robot_copy():
			if pending_logic.try_select_robot_copy_card(card_id):
				var selected: Dictionary = _find_card_by_id_in_array(players[_get_view_player()].hand, pending_logic.robot_card_id)
				tabletop_logic.prompt_attack_discard(selected)
				_sync_after_state_change_without_card_layout()
			return
		if _is_ai_player(current_player):
			return
		if minor_actions_spent > 0:
			return
		if pending_logic.action != "" and pending_logic.action != "hand" and pending_logic.action != "deck_face_down":
			return
		var hand_index: int = _find_card_index_in_array(players[_get_view_player()].hand, card_id)
		if hand_index < 0:
			return
		if _is_hand_card_inactive_for_current_pending(players[_get_view_player()].hand[hand_index]):
			return
		var selected_card: Dictionary = players[_get_view_player()].hand[hand_index]
		if String(selected_card.unit.name_key) == UnitKeys.HLAMOVNIK_NAME and not tabletop_logic.get_hlamovnik_copy_cards(_get_live_game_state()).is_empty():
			tabletop_logic.choose_hlamovnik_copy(selected_card)
			return
		if String(selected_card.unit.name_key) == UnitKeys.ROBOT_NAME:
			if _get_robot_copy_cards_in_hand(players[_get_view_player()].hand, card_id).is_empty():
				action_label.text = _tr_text("UI_ERROR_ROBOT_COPY_REQUIRED")
				return
			pending_logic.begin_robot_copy(card_id)
			_sync_after_state_change_without_card_layout()
			return
		pending_logic.clear_robot_copy_selection()
		if tabletop_logic.prompt_attack_discard(selected_card):
			return
		ui_selected_hand_card_id = card_id
		pending_logic.action = "hand"
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


func _connect_discard_card_input(card_control: Control) -> void:
	if bool(card_control.get_meta("discard_input_connected", false)):
		return
	card_control.gui_input.connect(_on_discard_card_gui_input.bind(card_control))
	card_control.set_meta("discard_input_connected", true)


func _on_discard_card_gui_input(event: InputEvent, unit_control: Control) -> void:
	if game_over or animation_running:
		return
	if pending_logic.action != "discard_pick":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		await pending_logic.try_pick_discard_card(int(unit_control.get_meta("card_id")))


func _connect_board_card_input(card_control: Control) -> void:
	if bool(card_control.get_meta("board_input_connected", false)):
		return
	card_control.gui_input.connect(_on_board_card_gui_input.bind(card_control))
	card_control.set_meta("board_input_connected", true)


func _prepare_board_card_interaction(card_control: Control, cell: Vector2i) -> void:
	card_control.set_meta("board_cell", cell)
	_connect_board_card_input(card_control)


func _on_board_card_gui_input(event: InputEvent, unit_control: Control) -> void:
	if game_over or animation_running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if pending_logic.action == "target":
			unit_control.accept_event()
			if pending_logic.is_card_target():
				await pending_logic.try_apply_target_card(int(unit_control.get_meta("card_id")))
			elif unit_control.has_meta("board_cell"):
				await pending_logic.try_apply_target(unit_control.get_meta("board_cell"))
			return
		if _is_ai_player(current_player) or current_player != _get_view_player() or pending_logic.action not in ["", "hand", "deck_face_down"]:
			return
		var variant: Dictionary = _make_action_variant("tabletop_extra", current_player, {"card_id": int(unit_control.get_meta("card_id"))})
		var simulation: Dictionary = _simulate_action_variant(variant)
		if simulation.result.status != RESULT_OK:
			return
		unit_control.accept_event()
		var result: Dictionary = _apply_action_variant_to_current_state(variant)
		await _animate_action_result(result)
		pending_logic._begin_pending_from_result_or_clear(result)
		_sync_after_state_change_without_card_layout()

func _is_ai_player(player_index: int) -> bool:
	return AI_PLAYERS.has(player_index)


func _queue_ai_turn_if_needed() -> void:
	if ai_running or game_over or animation_running:
		return
	if pending_logic.action != "":
		if _is_ai_player(pending_logic.get_decision_player()):
			_run_ai_pending_decision.call_deferred()
		return
	if _is_solo_mode():
		if solo_logic.resolving_plan and current_player == HUMAN_PLAYER_INDEX:
			_finish_solo_resolution_and_prepare_plan.call_deferred()
		elif current_player == solo_logic.ENEMY_PLAYER_INDEX:
			_run_solo_turn_step.call_deferred()
		return
	if not _is_ai_player(current_player):
		return
	_run_ai_turn_step.call_deferred()


func _run_solo_turn_step() -> void:
	if ai_running or game_over or animation_running:
		return
	if not _is_solo_mode() or pending_logic.action != "":
		return
	if current_player != solo_logic.ENEMY_PLAYER_INDEX:
		return

	ai_running = true
	if not solo_logic.resolving_plan:
		solo_logic.begin_resolution()
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if game_over or animation_running or pending_logic.action != "" or not _is_solo_mode():
		ai_running = false
		return

	var result: Dictionary
	if solo_logic.has_entries():
		var entry: Dictionary = solo_logic.pop_next_entry()
		result = _apply_solo_plan_entry_to_current_state(entry)
	else:
		var state: Dictionary = _get_live_game_state()
		state.events = []
		result = _make_action_result(RESULT_OK, "")
		result.end_turn = true
		_apply_end_turn_rules_to_state(state, result)
		result.events = state.events
		_restore_game_state(state)

	animation_running = true
	_set_action_buttons_enabled(false)
	await _animate_action_result(result)
	animation_running = false
	pending_logic._begin_pending_from_result_or_clear(result)

	if pending_logic.action == "" and current_player == HUMAN_PLAYER_INDEX:
		solo_logic.finish_resolution()
		if not game_over:
			await _prepare_next_solo_plan(true)
	ai_running = false
	_sync_after_state_change_without_card_layout()


func _finish_solo_resolution_and_prepare_plan() -> void:
	if ai_running or game_over or animation_running or pending_logic.action != "":
		return
	if not _is_solo_mode() or not solo_logic.resolving_plan:
		return
	if current_player != HUMAN_PLAYER_INDEX:
		return
	ai_running = true
	solo_logic.finish_resolution()
	await _prepare_next_solo_plan(true)
	ai_running = false
	_sync_after_state_change_without_card_layout()


func _prepare_next_solo_plan(animate_draws: bool) -> void:
	var state: Dictionary = _get_live_game_state()
	state.events = []
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	solo_logic.prepare_plan(state)
	result.events = state.events
	_restore_game_state(state)
	if animate_draws and not result.events.is_empty():
		animation_running = true
		_set_action_buttons_enabled(false)
		await _animate_action_result(result)
		animation_running = false


func _apply_solo_plan_entry_to_current_state(entry: Dictionary) -> Dictionary:
	var state: Dictionary = _get_live_game_state()
	var result: Dictionary = _apply_solo_plan_entry_to_state(state, entry)
	_restore_game_state(state)
	return result


func _apply_solo_plan_entry_to_state(state: Dictionary, entry: Dictionary) -> Dictionary:
	var player_index: int = solo_logic.ENEMY_PLAYER_INDEX
	var hand: Array = state.players[player_index].hand
	var card_id: int = int(entry.get("card_id", -1))
	var hand_index: int = _find_card_index_in_array(hand, card_id)
	var target: Vector2i = entry.get("cell", solo_logic.INVALID_CELL)
	var plan_kind: String = String(entry.get("kind", solo_logic.PLAN_KIND_COMBAT))
	if hand_index >= 0:
		var card: Dictionary = hand[hand_index]
		if plan_kind == solo_logic.PLAN_KIND_PATH:
			card.face_down = true
			if solo_logic.can_play_path_at_cell(state, card, target):
				var path_variant: Dictionary = _make_action_variant(ACTION_SOLO_PATH, player_index, {
					"hand_index": hand_index,
					"cell": target
				})
				return _apply_action_variant_to_state(state, path_variant)
		else:
			card.face_down = false
		if plan_kind != solo_logic.PLAN_KIND_PATH and solo_logic.can_play_at_cell(state, card, target):
			var variant: Dictionary = _make_action_variant(ACTION_SOLO_PLAY, player_index, {
				"hand_index": hand_index,
				"cell": target
			})
			return _apply_action_variant_to_state(state, variant)

	state.events = []
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.solo_skipped = true
	result.end_turn = true
	if hand_index >= 0:
		var skipped_card: Dictionary = hand[hand_index]
		hand.remove_at(hand_index)
		_discard_card_in_state(state, player_index, skipped_card, {
			"type": "hand",
			"hand_index": hand_index
		})
	if not bool(state.game_over):
		_apply_end_turn_rules_to_state(state, result)
	result.events = state.events
	return result


func _run_ai_pending_decision() -> void:
	if ai_running or game_over or animation_running:
		return
	if pending_logic.action == "":
		return
	if not _is_ai_player(pending_logic.get_decision_player()):
		return

	ai_running = true
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if game_over or animation_running or pending_logic.action == "" or not _is_ai_player(pending_logic.get_decision_player()):
		ai_running = false
		return
	await pending_logic.try_apply_ai_decision()
	ai_running = false
	_sync_after_state_change_without_card_layout()


func _run_ai_turn_step() -> void:
	if ai_running or game_over or animation_running:
		return
	if _is_solo_mode():
		return
	if pending_logic.action != "":
		return
	if not _is_ai_player(current_player):
		return

	ai_running = true
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if game_over or animation_running or not _is_ai_player(current_player):
		ai_running = false
		return

	pending_logic.clear()
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
		if result.has("pending_hand_discard"):
			pending_logic.begin_hand_discard(result.pending_hand_discard)
		elif result.has("pending_hand_pick"):
			pending_logic.begin_hand_pick(result.pending_hand_pick)
		elif result.has("pending_discard_pick"):
			pending_logic.begin_discard_pick(result.pending_discard_pick)
		elif result.has("pending_strateg"):
			pending_logic.begin_strateg(result.pending_strateg)
		elif result.has("pending_extra_hand_play"):
			if _is_ai_player(current_player):
				await _try_ai_extra_hand_play(result.pending_extra_hand_play)
			else:
				pending_logic.begin_extra_hand_play(result.pending_extra_hand_play)
		elif result.has("pending_target"):
			pending_logic.begin_target(result.pending_target)

	ai_running = false
	_sync_after_state_change_without_card_layout()


func _try_ai_extra_hand_play(request: Dictionary = {}) -> void:
	var state: Dictionary = _capture_game_state()
	var variant: Dictionary = {}
	var forced_card_id: int = int(request.get("forced_card_id", -1))
	if forced_card_id >= 0:
		var hand_index: int = _find_card_index_in_array(state.players[current_player].hand, forced_card_id)
		if hand_index >= 0:
			var variants: Array = _get_play_hand_variants_for_state(state, current_player, hand_index)
			if not variants.is_empty():
				variant = variants[0]
	else:
		variant = ai_logic.choose_hand_play_action_variant(state, current_player)
	if variant.is_empty():
		var live_state: Dictionary = _get_live_game_state()
		live_state.events = []
		var end_result: Dictionary = _make_action_result(RESULT_OK, "")
		end_result.end_turn = true
		_apply_end_turn_rules_to_state(live_state, end_result)
		end_result.events = live_state.events
		_restore_game_state(live_state)
		await _animate_action_result(end_result)
		pending_logic._begin_pending_from_result_or_clear(end_result)
		return

	_add_deferred_source_play_reaction_to_variant(variant, request)
	var result: Dictionary = _apply_action_variant_to_current_state(variant)
	await _animate_action_result(result)
	if result.has("pending_hand_discard"):
		pending_logic.begin_hand_discard(result.pending_hand_discard)
	elif result.has("pending_hand_pick"):
		pending_logic.begin_hand_pick(result.pending_hand_pick)
	elif result.has("pending_discard_pick"):
		pending_logic.begin_discard_pick(result.pending_discard_pick)
	elif result.has("pending_strateg"):
		pending_logic.begin_strateg(result.pending_strateg)
	elif result.has("pending_extra_hand_play"):
		await _try_ai_extra_hand_play(result.pending_extra_hand_play)
	elif result.has("pending_target"):
		pending_logic.begin_target(result.pending_target)
	else:
		pending_logic.clear()


func _add_deferred_source_play_reaction_to_variant(variant: Dictionary, request: Dictionary) -> void:
	if request.is_empty():
		return
	var payload: Dictionary = Dictionary(variant.get("payload", {})).duplicate(true)
	_add_deferred_source_play_reaction_to_payload(payload, request)
	variant.payload = payload


func _add_deferred_source_play_reaction_to_payload(payload: Dictionary, request: Dictionary) -> void:
	if request.is_empty():
		return
	payload.deferred_source_play_reaction = request.duplicate(true)


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
		"destroyed_base_owner": destroyed_base_owner,
		"next_card_id": next_card_id,
		"turn_restrictions": turn_restrictions,
		"barrier_removal_options": barrier_removal_options
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
		"destroyed_base_owner": int(state.get("destroyed_base_owner", -1)),
		"next_card_id": int(state.get("next_card_id", next_card_id)),
		"turn_restrictions": Array(state.get("turn_restrictions", [])).duplicate(true),
		"barrier_removal_options": Array(state.get("barrier_removal_options", [])).duplicate(true)
	}


func _restore_game_state(state: Dictionary) -> void:
	board = state.board
	barriers = state.barriers
	players = state.players
	current_player = int(state.current_player)
	minor_actions_spent = int(state.minor_actions_spent)
	game_over = bool(state.game_over)
	game_over_message = String(state.game_over_message)
	destroyed_base_owner = int(state.get("destroyed_base_owner", -1))
	next_card_id = int(state.get("next_card_id", next_card_id))
	turn_restrictions = Array(state.get("turn_restrictions", [])).duplicate(true)
	barrier_removal_options = Array(state.get("barrier_removal_options", [])).duplicate(true)


func _duplicate_board(source_board: Array) -> Array:
	var new_board: Array = []
	for y in range(source_board.size()):
		var row: Array = []
		for x in range(source_board[y].size()):
			row.append(source_board[y][x].duplicate(true))
		new_board.append(row)
	return new_board


func _duplicate_players(source_players: Array) -> Array:
	return source_players.duplicate(true)

func _make_action_variant(action_type: String, player_index: int, payload: Dictionary = {}) -> Dictionary:
	var variant = {
		"type": action_type,
		"player_index": player_index,
		"hand_index": -1,
		"cell": Vector2i(-1, -1),
		"target_cell": Vector2i(-1, -1),
		"target_card_id": -1,
		"copied_card_id": -1,
		"target_sequence": [],
		"target_choice": {},
		"payload": payload
	}
	if payload.has("hand_index"):
		variant.hand_index = int(payload.hand_index)
	if payload.has("cell"):
		variant.cell = payload.cell
	if payload.has("play_access"):
		variant.play_access = payload.play_access
	if payload.has("target_cell"):
		variant.target_cell = payload.target_cell
	if payload.has("target_card_id"):
		variant.target_card_id = int(payload.target_card_id)
	if payload.has("copied_card_id"):
		variant.copied_card_id = int(payload.copied_card_id)
	if payload.has("target_sequence"):
		variant.target_sequence = Array(payload.target_sequence).duplicate()
	if payload.has("target_choice"):
		variant.target_choice = payload.target_choice
	return variant


func _get_turn_variants_for_state(state: Dictionary, player_index: int) -> Array:
	var variants: Array = []
	if bool(state.game_over) or bool(state.players[player_index].get("in_end_turn", false)):
		return variants
	if int(state.current_player) != player_index:
		return variants

	variants.append_array(tabletop_logic.extra_action_variants(state, player_index))
	if _can_draw_card_variant_in_state(state, player_index):
		variants.append(_make_action_variant(ACTION_DRAW_CARD, player_index))

	var supply_result: Dictionary = supply_logic.calculate_supply_result(state, player_index)
	if _can_play_minor_action_in_state(state):
		variants.append_array(_get_deck_face_down_variants_for_state(state, player_index, supply_result))

	if int(state.minor_actions_spent) == 0:
		var hand: Array = state.players[player_index].hand
		for hand_index in range(hand.size()):
			variants.append_array(_get_play_hand_variants_for_state(state, player_index, hand_index, true, supply_result))
	if int(state.minor_actions_spent) == 0:
		for extra in tabletop_logic.extra_action_variants(state, player_index):
			var info: Dictionary = target_logic._find_card_cell_and_index_in_board(state, int(extra.payload.card_id))
			var extra_card: Dictionary = _get_stack_in_state(state, info.cell)[int(info.index)]
			if CardAbilities.name_key(extra_card) != UnitKeys.KLADENETS_NAME:
				continue
			var boosted_state: Dictionary = _duplicate_game_state(state)
			tabletop_logic.apply_extra_action(boosted_state, int(extra.payload.card_id))
			for index in range(boosted_state.players[player_index].hand.size()):
				for attack in _get_play_hand_variants_for_state(boosted_state, player_index, index):
					attack.payload.activate_kladents_id = int(extra.payload.card_id)
					variants.append(attack)
	return action_restriction_logic.filter_turn_variants(state, player_index, variants)


func _get_play_hand_variants_for_state(
	state: Dictionary,
	player_index: int,
	hand_index: int,
	expand_targets: bool = true,
	supply_result: Dictionary = {},
	robot_copy_card_id: int = -1,
	attack_discard_id: int = -2
) -> Array:
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
	var play_options: Array = [{
		"card": card,
		"copied_card_id": -1
	}]
	if String(card.unit.name_key) == UnitKeys.HLAMOVNIK_NAME:
		var discarded_cards: Array = tabletop_logic.get_hlamovnik_copy_cards(state, robot_copy_card_id)
		if not discarded_cards.is_empty():
			play_options.clear()
			for copied in discarded_cards:
				play_options.append({"card": tabletop_logic.make_hlamovnik_preview(card, copied), "copied_card_id": int(copied.id)})
	if String(card.unit.name_key) == UnitKeys.ROBOT_NAME:
		play_options.clear()
		var copied_cards: Array = _get_robot_copy_cards_in_hand(
			hand,
			int(card.id),
			robot_copy_card_id,
			robot_copy_card_id < 0
		)
		for copied_card in copied_cards:
			play_options.append({
				"card": _make_robot_play_preview_card(card, copied_card),
				"copied_card_id": int(copied_card.id)
			})
		if play_options.is_empty():
			return variants
	play_options = tabletop_logic.expand_attack_payment_options(state, play_options, attack_discard_id)
	var resolved_supply_result: Dictionary = supply_result
	if resolved_supply_result.is_empty():
		resolved_supply_result = supply_logic.calculate_supply_result(state, player_index)
	for play_option in play_options:
		var play_card: Dictionary = play_option.card
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var cell: Vector2i = Vector2i(x, y)
				if action_restriction_logic.can_play_hand_card(state, player_index, play_card, cell) and _can_play_card_in_state(state, play_card, cell, resolved_supply_result):
					var payload: Dictionary = {
						"hand_index": hand_index,
						"cell": cell,
						"play_access": _get_play_access_info_in_state(state, play_card, cell, resolved_supply_result)
					}
					if play_option.has("charodey_discard_id"):
						payload.charodey_discard_id = int(play_option.charodey_discard_id)
					if int(play_option.copied_card_id) >= 0:
						payload.copied_card_id = int(play_option.copied_card_id)
					var base_variant: Dictionary = _make_action_variant(ACTION_PLAY_HAND_CARD, player_index, payload)
					if expand_targets:
						variants.append_array(_expand_variant_with_target_choices(state, base_variant))
					else:
						variants.append(base_variant)
	return variants


func _get_robot_copy_cards_in_hand(
	hand: Array,
	robot_card_id: int,
	requested_card_id: int = -1,
	deduplicate_equivalent_cards: bool = false
) -> Array:
	var copied_cards: Array = []
	var seen_signatures: Dictionary = {}
	for candidate in hand:
		if int(candidate.id) == robot_card_id:
			continue
		if requested_card_id >= 0 and int(candidate.id) != requested_card_id:
			continue
		if bool(candidate.get("face_down", false)):
			continue
		if deduplicate_equivalent_cards:
			var signature: String = "%s:%d:%d" % [
				String(candidate.unit.name_key),
				power_logic.get_card_attack_power(candidate),
				int(candidate.get("attack_bonus", 0))
			]
			if seen_signatures.has(signature):
				continue
			seen_signatures[signature] = true
		copied_cards.append(candidate)
	return copied_cards


func _is_robot_card(card: Dictionary) -> bool:
	if card.is_empty() or bool(card.get("face_down", false)):
		return false
	return String(card.unit.name_key) == UnitKeys.ROBOT_NAME


func _make_robot_play_preview_card(robot_card: Dictionary, copied_card: Dictionary) -> Dictionary:
	var preview: Dictionary = robot_card.duplicate(true)
	preview.ability_unit = CardAbilities.ability_unit(copied_card)
	preview.copied_power = int(copied_card.get("copied_power", copied_card.unit.power))
	preview.attack_power_override = preview.copied_power
	return preview

func _expand_variant_with_target_choices(state: Dictionary, variant: Dictionary) -> Array:
	var simulation_state: Dictionary = _duplicate_game_state(state)
	var result: Dictionary = _apply_action_variant_to_state(simulation_state, variant, false)
	if result.status != RESULT_OK:
		return []
	if not result.has("pending_target"):
		return [variant]
	var decision_player: int = int(result.pending_target.get("decision_player", result.pending_target.get("player_index", -1)))
	if decision_player != int(variant.player_index):
		return [variant]

	var variants: Array = []
	if String(result.pending_target.get("target_type", "cell")) in ["choice", "option"]:
		for target_choice in target_logic.get_ai_target_choices(simulation_state, result.pending_target):
			var choice_variant: Dictionary = variant.duplicate(true)
			choice_variant.target_choice = target_choice
			choice_variant.payload = Dictionary(choice_variant.payload).duplicate(true)
			choice_variant.payload.target_choice = target_choice
			variants.append(choice_variant)
	elif String(result.pending_target.get("target_type", "cell")) == "cell_sequence":
		variants.append_array(_expand_variant_with_target_sequence(simulation_state, result.pending_target, variant, []))
	elif String(result.pending_target.get("target_type", "cell")) == "card":
		for target_card in target_logic.get_legal_target_cards(simulation_state, result.pending_target):
			var card_variant: Dictionary = variant.duplicate(true)
			card_variant.target_card_id = int(target_card.card_id)
			card_variant.payload = Dictionary(card_variant.payload).duplicate(true)
			card_variant.payload.target_card_id = int(target_card.card_id)
			variants.append(card_variant)
	else:
		for target_cell in target_logic.get_legal_target_cells(simulation_state, result.pending_target):
			var target_variant: Dictionary = variant.duplicate(true)
			target_variant.target_cell = target_cell
			target_variant.payload = Dictionary(target_variant.payload).duplicate(true)
			target_variant.payload.target_cell = target_cell
			variants.append(target_variant)
	return variants


func _expand_variant_with_target_sequence(
	state: Dictionary,
	request: Dictionary,
	variant: Dictionary,
	selected_cells: Array,
	minimum_target_order: int = -1
) -> Array:
	var variants: Array = []
	var kind: String = String(request.get("kind", ""))
	var canonical_target_order: bool = _is_ai_sequence_target_order_irrelevant(kind)
	if target_logic.can_finish_choice_request(request):
		var finish_variant: Dictionary = variant.duplicate(true)
		finish_variant.target_sequence = selected_cells.duplicate()
		finish_variant.payload = Dictionary(finish_variant.payload).duplicate(true)
		finish_variant.payload.target_sequence = selected_cells.duplicate()
		variants.append(finish_variant)
	for target_cell in target_logic.get_legal_target_cells(state, request):
		var target_order: int = target_cell.y * GRID_WIDTH + target_cell.x
		if canonical_target_order and target_order < minimum_target_order:
			continue
		var next_state: Dictionary = _duplicate_game_state(state)
		var target_result: Dictionary = target_logic.apply_target(next_state, request, target_cell)
		if target_result.status != RESULT_OK:
			continue
		var next_selected_cells: Array = selected_cells.duplicate()
		next_selected_cells.append(target_cell)
		if target_result.has("pending_target"):
			var should_stop_expanding: bool = (
				(kind == "vihr_swap_neighbors" and next_selected_cells.size() >= 2)
				or (kind == "sporovik_own_full_stack" and next_selected_cells.size() >= 1)
			)
			if should_stop_expanding:
				var target_variant: Dictionary = variant.duplicate(true)
				target_variant.target_sequence = next_selected_cells.duplicate()
				target_variant.payload = Dictionary(target_variant.payload).duplicate(true)
				target_variant.payload.target_sequence = next_selected_cells.duplicate()
				variants.append(target_variant)
			else:
				var next_minimum_target_order: int = -1
				if canonical_target_order:
					next_minimum_target_order = target_order
				variants.append_array(_expand_variant_with_target_sequence(
					next_state,
					target_result.pending_target,
					variant,
					next_selected_cells,
					next_minimum_target_order
				))
		else:
			var target_variant: Dictionary = variant.duplicate(true)
			target_variant.target_sequence = next_selected_cells
			target_variant.payload = Dictionary(target_variant.payload).duplicate(true)
			target_variant.payload.target_sequence = next_selected_cells
			variants.append(target_variant)
	return variants


func _is_ai_sequence_target_order_irrelevant(kind: String) -> bool:
	return (
		kind == "lich_flip_own"
		or kind == "trubadur_return_own"
	)


func _get_deck_face_down_variants_for_state(
	state: Dictionary,
	player_index: int,
	supply_result: Dictionary = {}
) -> Array:
	var variants: Array = []
	if bool(state.game_over):
		return variants
	if int(state.current_player) != player_index:
		return variants
	if not action_restriction_logic.can_play_path(state, player_index):
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
	var resolved_supply_result: Dictionary = supply_result
	if resolved_supply_result.is_empty():
		resolved_supply_result = supply_logic.calculate_supply_result(state, player_index)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _can_play_card_in_state(state, card, cell, resolved_supply_result):
				variants.append(_make_action_variant(ACTION_PLAY_DECK_FACE_DOWN, player_index, {
					"cell": cell,
					"play_access": _get_play_access_info_in_state(state, card, cell, resolved_supply_result)
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


func _apply_action_variant_to_state(state: Dictionary, variant: Dictionary, record_events: bool = true) -> Dictionary:
	if record_events:
		state.events = []
	else:
		state.erase("events")
	var supply_origin_before: Dictionary = {}
	if record_events:
		supply_origin_before = _get_all_supply_origin_cells_in_state(state)
	var result: Dictionary = _apply_action_core_to_state(state, variant)
	if result.status != RESULT_OK:
		result.events = Array(state.get("events", []))
		return result

	_apply_after_action_rules_to_state(state, result)
	if result.has("pending_target"):
		var target_type: String = String(result.pending_target.get("target_type", "cell"))
		var decision_player: int = int(result.pending_target.get("decision_player", result.pending_target.get("player_index", -1)))
		var variant_can_resolve_target: bool = decision_player == int(variant.player_index)
		var target_result: Dictionary
		if (
			variant_can_resolve_target
			and target_type == "cell_sequence"
			and Dictionary(variant.get("payload", {})).has("target_sequence")
		):
			target_result = _apply_target_sequence_to_state(state, result.pending_target, Array(variant.target_sequence))
		elif variant_can_resolve_target and target_type in ["choice", "option"] and not Dictionary(variant.get("target_choice", {})).is_empty():
			target_result = target_logic.apply_choice(state, result.pending_target, variant.target_choice, false)
		elif variant_can_resolve_target and target_type == "card" and int(variant.get("target_card_id", -1)) >= 0:
			target_result = target_logic.apply_card_target(state, result.pending_target, int(variant.target_card_id))
		elif variant_can_resolve_target and target_type not in ["choice", "option"] and variant.get("target_cell", Vector2i(-1, -1)) != Vector2i(-1, -1):
			target_result = target_logic.apply_target(state, result.pending_target, variant.target_cell)
		else:
			result.end_turn = false
			target_result = {}
		if not target_result.is_empty():
			_copy_play_identity_from_request_to_result(result.pending_target, target_result)
			target_result = target_logic.autofinish_pending_target_if_empty(state, target_result)
			if target_result.status != RESULT_OK:
				target_result.events = Array(state.get("events", []))
				return target_result
			result.erase("pending_target")
			for pending_key in ["pending_target", "pending_hand_discard", "pending_hand_pick", "pending_discard_pick", "pending_strateg", "pending_extra_hand_play"]:
				if target_result.has(pending_key):
					result[pending_key] = target_result[pending_key]
			result.end_turn = bool(target_result.end_turn)
	_check_base_capture_in_state(state, result)
	if not _result_has_pending_action(result):
		_apply_stack_reactions_after_play_to_state(state, result)
		if not _result_has_pending_action(result):
			_apply_deferred_source_play_reactions_to_state(state, variant, result)
		_check_base_capture_in_state(state, result)
	if bool(result.get("end_turn", false)) and not _result_has_pending_action(result) and not bool(state.game_over):
		_apply_end_turn_rules_to_state(state, result)
	if record_events:
		_record_supply_control_event_if_changed_in_state(state, supply_origin_before)
	result.events = Array(state.get("events", []))
	return result


func _result_has_pending_action(result: Dictionary) -> bool:
	return (
		result.has("pending_target")
		or result.has("pending_hand_discard")
		or result.has("pending_hand_pick")
		or result.has("pending_discard_pick")
		or result.has("pending_strateg")
		or result.has("pending_extra_hand_play")
	)


func _apply_target_sequence_to_state(state: Dictionary, request: Dictionary, targets: Array) -> Dictionary:
	var current_request: Dictionary = request.duplicate(true)
	var target_result: Dictionary = {}
	if targets.is_empty() and target_logic.can_finish_choice_request(current_request):
		return target_logic.finish_choice(state, current_request)
	for target_cell in targets:
		target_result = target_logic.apply_target(state, current_request, target_cell)
		if target_result.status != RESULT_OK:
			return target_result
		if target_result.has("pending_target"):
			current_request = target_result.pending_target
		else:
			return target_result
	if target_result.is_empty():
		return {}
	if target_result.has("pending_target") and target_logic.can_finish_choice_request(target_result.pending_target):
		var finish_result: Dictionary = target_logic.finish_choice(state, target_result.pending_target)
		if finish_result.has("pending_target"):
			return finish_result
		target_result.erase("pending_target")
		target_result.end_turn = bool(finish_result.get("end_turn", true))
	return target_result


func _apply_action_core_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var action_type: String = String(variant.type)
	var player_index: int = int(variant.player_index)
	if int(state.current_player) != player_index:
		return _make_action_result(RESULT_INVALID, "wrong_player")
	if bool(state.game_over):
		return _make_action_result(RESULT_INVALID, "game_over")

	if action_type == "tabletop_extra":
		return tabletop_logic.apply_extra_action(state, int(variant.payload.card_id))
	if bool(state.players[player_index].get("in_end_turn", false)):
		return _make_action_result(RESULT_INVALID, "turn_finishing")
	if action_type == ACTION_DRAW_CARD:
		if not _can_draw_card_variant_in_state(state, player_index):
			return _make_action_result(RESULT_INVALID, "cannot_draw")
		_draw_cards_in_state(state, player_index, 1)
		var draw_result: Dictionary = _make_action_result(RESULT_OK, "")
		draw_result.end_turn = _spend_minor_action_in_state(state)
		return draw_result

	if action_type == ACTION_PLAY_HAND_CARD:
		if variant.payload.has("activate_kladents_id"):
			var extra_result: Dictionary = tabletop_logic.apply_extra_action(state, int(variant.payload.activate_kladents_id))
			if extra_result.status != RESULT_OK:
				return extra_result
		return _apply_play_hand_card_to_state(state, variant)
	if action_type == ACTION_SOLO_PLAY:
		return _apply_play_hand_card_to_state(state, variant)
	if action_type == ACTION_SOLO_PATH:
		return _apply_solo_path_card_to_state(state, variant)

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
	var ability_name_key: String = String(card.unit.name_key)
	var copied_card: Dictionary = {}
	var play_card: Dictionary = card
	if ability_name_key == UnitKeys.ROBOT_NAME:
		var payload: Dictionary = Dictionary(variant.get("payload", {}))
		var copied_card_id: int = int(payload.get("copied_card_id", variant.get("copied_card_id", -1)))
		if copied_card_id < 0:
			return _make_action_result(RESULT_INVALID, "robot_copy_required")
		var copied_cards: Array = _get_robot_copy_cards_in_hand(hand, int(card.id), copied_card_id)
		if copied_cards.is_empty():
			return _make_action_result(RESULT_INVALID, "robot_copy_required")
		copied_card = copied_cards[0]
		ability_name_key = String(copied_card.unit.name_key)
		play_card = _make_robot_play_preview_card(card, copied_card)
	elif ability_name_key == UnitKeys.HLAMOVNIK_NAME:
		var copied_id: int = int(variant.payload.get("copied_card_id", -1))
		var discarded_cards: Array = tabletop_logic.get_hlamovnik_copy_cards(state, copied_id)
		if not tabletop_logic.get_hlamovnik_copy_cards(state).is_empty():
			if copied_id < 0 or discarded_cards.is_empty():
				return _make_action_result(RESULT_INVALID, "hlamovnik_copy_required")
			copied_card = discarded_cards[0]
			play_card = tabletop_logic.make_hlamovnik_preview(card, copied_card)
	if not action_restriction_logic.can_play_hand_card(state, player_index, play_card, cell):
		return _make_action_result(RESULT_INVALID, "card_restricted")
	var attack_discard_id: int = int(variant.payload.get("charodey_discard_id", -1))
	if attack_discard_id >= 0:
		if CardAbilities.name_key(play_card) != UnitKeys.CHARODEY_NAME or attack_discard_id == int(card.id) or _find_card_index_in_array(hand, attack_discard_id) < 0:
			return _make_action_result(RESULT_INVALID, "bad_attack_payment")
		play_card = play_card.duplicate(true)
		play_card.attack_bonus = 10
	if not _can_play_card_in_state(state, play_card, cell):
		return _make_action_result(RESULT_INVALID, "cannot_play_card")
	if not bool(variant.payload.get("opolchenie_declined", false)):
		var response: Dictionary = tabletop_logic.play_response_request(state, {"card": card, "cell": cell})
		if not response.is_empty():
			response.erase("announced_result")
			response.announced_variant = variant.duplicate(true)
			var pending_result: Dictionary = _make_action_result(RESULT_OK, "")
			pending_result.pending_target = response
			return pending_result
	if not copied_card.is_empty():
		card.attack_power_override = int(copied_card.unit.power)
		card.copied_power = int(copied_card.unit.power)
		card.copied_name = copied_card.unit.get_display_name()
		if String(card.unit.name_key) == UnitKeys.ROBOT_NAME:
			card.ability_unit = CardAbilities.ability_unit(copied_card)

	var opponent_supplied_before: Dictionary = _get_supplied_cells_in_state(state, _opponent(player_index))
	state.players[player_index].next_attack_bonus = 0
	if not copied_card.is_empty() and String(card.unit.name_key) == UnitKeys.ROBOT_NAME:
		_record_action_event_in_state(state, {
			"type": ANIMATION_REVEAL_HAND_CARD,
			"card_id": int(copied_card.id),
			"player_index": player_index,
			"unit": copied_card.unit,
			"source": {
				"type": "hand",
				"hand_index": _find_card_index_in_array(hand, int(copied_card.id))
			}
		})
	hand.remove_at(hand_index)
	action_restriction_logic.remove_satisfied_forced_hand_play_restrictions(state, player_index, int(card.id))
	if attack_discard_id >= 0:
		var payment_index: int = _find_card_index_in_array(hand, attack_discard_id)
		var payment: Dictionary = hand[payment_index]
		hand.remove_at(payment_index)
		_discard_card_in_state(state, player_index, payment, {"type": "hand", "hand_index": payment_index})
	_place_played_hand_card_in_state(state, card, cell, ability_name_key)
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
	_apply_played_card_overflow_in_state(state, card, cell, ability_name_key)
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.card = card
	result.cell = cell
	if not copied_card.is_empty():
		result.ability_name_key = ability_name_key
		result.copied_card_id = int(copied_card.id)
	result.played_card = true
	result.end_turn = true
	result.opponent_supplied_before = opponent_supplied_before
	result.opolchenie_declined = bool(variant.payload.get("opolchenie_declined", false))
	return result


func _apply_play_deck_face_down_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var player_index: int = int(variant.player_index)
	var cell: Vector2i = variant.cell
	if not action_restriction_logic.can_play_path(state, player_index):
		return _make_action_result(RESULT_INVALID, "path_restricted")
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


func _apply_solo_path_card_to_state(state: Dictionary, variant: Dictionary) -> Dictionary:
	var player_index: int = int(variant.player_index)
	var hand_index: int = int(variant.hand_index)
	var cell: Vector2i = variant.cell
	var hand: Array = state.players[player_index].hand
	if hand_index < 0 or hand_index >= hand.size():
		return _make_action_result(RESULT_INVALID, "bad_hand_index")

	var card: Dictionary = hand[hand_index]
	card.face_down = true
	if not solo_logic.can_play_path_at_cell(state, card, cell):
		return _make_action_result(RESULT_INVALID, "cannot_play_path")

	hand.remove_at(hand_index)
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
			"type": "hand",
			"hand_index": hand_index,
			"face_down": true
		}
	})
	_record_layout_stack_event_in_state(state, cell)
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.card = card
	result.cell = cell
	result.played_card = true
	result.end_turn = true
	return result


func _apply_after_action_rules_to_state(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return

	if not bool(result.get("opolchenie_declined", false)):
		var response: Dictionary = tabletop_logic.play_response_request(state, result)
		if not response.is_empty():
			result.pending_target = response
			result.end_turn = false
			return
	play_reaction_logic.apply_played_card_reactions(state, result)
	if not bool(result.get("played_card_removed", false)):
		play_effect_logic.apply_played_card_effects(state, result)

	_check_base_capture_in_state(state, result)
	if bool(state.game_over):
		return
	if bool(result.get("played_card_removed", false)):
		return
	var target_request: Dictionary = target_logic.get_target_request(state, result)
	if not target_request.is_empty():
		result.pending_target = target_request
	_propagate_play_identity_to_pending_result(result)


func _propagate_play_identity_to_pending_result(result: Dictionary) -> void:
	if not result.has("ability_name_key"):
		return
	for pending_key in [
		"pending_target",
		"pending_hand_discard",
		"pending_hand_pick",
		"pending_discard_pick",
		"pending_strateg",
		"pending_extra_hand_play"
	]:
		if not result.has(pending_key):
			continue
		var request: Dictionary = result[pending_key]
		request.ability_name_key = String(result.ability_name_key)
		if result.has("copied_card_id"):
			request.copied_card_id = int(result.copied_card_id)


func _copy_play_identity_from_request_to_result(request: Dictionary, result: Dictionary) -> void:
	if request.has("ability_name_key"):
		result.ability_name_key = String(request.ability_name_key)
	if request.has("copied_card_id"):
		result.copied_card_id = int(request.copied_card_id)
	_propagate_play_identity_to_pending_result(result)


func _apply_stack_reactions_after_play_to_state(state: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("played_card", false)):
		return
	if bool(result.get("played_card_removed", false)):
		return
	play_reaction_logic.apply_covered_card_reactions(state, result)


func _apply_deferred_source_play_reactions_to_state(state: Dictionary, variant: Dictionary, result: Dictionary) -> void:
	var payload: Dictionary = Dictionary(variant.get("payload", {}))
	var request: Dictionary = Dictionary(payload.get("deferred_source_play_reaction", {}))
	if request.is_empty():
		return
	_apply_source_play_reactions_to_result_in_state(state, request, result)


func _apply_source_play_reactions_to_result_in_state(state: Dictionary, request: Dictionary, result: Dictionary) -> void:
	if result.has("pending_target"):
		return
	if not request.has("card_id"):
		return
	var source_cell: Vector2i = request.get("source_cell", Vector2i(-1, -1))
	if int(request.card_id) < 0 or not _is_inside(source_cell):
		return
	var source_card: Dictionary = _find_card_by_id_in_array(
		_get_stack_in_state(state, source_cell),
		int(request.card_id)
	)
	if source_card.is_empty():
		return
	result.played_card = true
	result.card = source_card
	result.cell = source_cell
	if request.has("ability_name_key"):
		result.ability_name_key = String(request.ability_name_key)
	if request.has("copied_card_id"):
		result.copied_card_id = int(request.copied_card_id)
	_apply_stack_reactions_after_play_to_state(state, result)


func _check_base_capture_in_state(state: Dictionary, result: Dictionary = {}) -> void:
	tabletop_logic.resolve_continuous(state)
	if result.has("pending_target") and String(result.pending_target.kind) == "opolchenie_response":
		return
	for base_owner in range(state.players.size()):
		var base_cell: Vector2i = state.players[base_owner].base
		var stack: Array = _get_stack_in_state(state, base_cell)
		if stack.is_empty():
			continue
		var top_card: Dictionary = stack[stack.size() - 1]
		var winner_index: int = int(top_card.owner)
		if winner_index == base_owner:
			continue
		state.game_over = true
		state.game_over_message = _tr_text("UI_GAME_OVER") % state.players[winner_index].name
		state.destroyed_base_owner = base_owner
		if not result.is_empty():
			result.end_turn = false
		return


func _apply_end_turn_rules_to_state(state: Dictionary, result: Dictionary = {}) -> void:
	if bool(state.game_over):
		return
	if _is_solo_mode() and solo_logic.should_hold_enemy_turn(state):
		_trim_stacks_in_state(state)
		return
	var tabletop_request: Dictionary = tabletop_logic.end_turn_request(state)
	if not tabletop_request.is_empty():
		if not result.is_empty():
			result.pending_target = tabletop_request
			result.end_turn = false
			return
		state.players[int(state.current_player)].gondola_finished = true
	var end_turn_target_request: Dictionary = target_logic.get_end_turn_target_request(state)
	if not end_turn_target_request.is_empty():
		if _is_ai_player(int(state.current_player)) or result.is_empty():
			target_logic.apply_ai_end_turn_choice(state, end_turn_target_request)
		else:
			result.pending_target = end_turn_target_request
			result.end_turn = false
			return
	_trim_stacks_in_state(state)
	while true:
		var hand_limit_request: Dictionary = _get_next_hand_limit_discard_request(state)
		if hand_limit_request.is_empty():
			break
		var decision_player: int = int(hand_limit_request.player_index)
		if _is_ai_player(decision_player) or result.is_empty():
			_discard_hand_limit_cards_for_ai_in_state(state, hand_limit_request)
			continue
		result.pending_hand_discard = hand_limit_request
		result.end_turn = false
		return
	action_restriction_logic.remove_finished_turn_restrictions(state, int(state.current_player))
	state.players[int(state.current_player)].next_attack_bonus = 0
	state.players[int(state.current_player)].in_end_turn = false
	state.players[int(state.current_player)].gondola_finished = false
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
	if not action_restriction_logic.can_draw_card(state, player_index):
		return false
	if not _can_play_minor_action_in_state(state):
		return false
	if bool(state.players[player_index].get("in_end_turn", false)):
		return false
	if state.players[player_index].deck.is_empty():
		return not state.players[player_index].discard.is_empty() or (_is_solo_mode() and player_index == solo_logic.ENEMY_PLAYER_INDEX and not state.players[player_index].deck_template.is_empty())
	var deck: Array = state.players[player_index].deck
	return not deck.is_empty()


func _can_play_minor_action_in_state(state: Dictionary) -> bool:
	if bool(state.game_over):
		return false
	return not bool(state.players[int(state.current_player)].get("in_end_turn", false)) and int(state.minor_actions_spent) < TURN_MINOR_ACTIONS


func _spend_minor_action_in_state(state: Dictionary) -> bool:
	state.minor_actions_spent = int(state.minor_actions_spent) + 1
	return int(state.minor_actions_spent) >= TURN_MINOR_ACTIONS


func _on_draw_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	if _is_ai_player(current_player):
		return
	if not action_restriction_logic.can_draw_card(_get_live_game_state(), current_player):
		return
	pending_logic.clear()
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
	pending_logic._begin_pending_from_result_or_clear(result)
	_sync_after_state_change_without_card_layout()


func _on_deck_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	if _is_ai_player(current_player):
		return
	if not action_restriction_logic.can_play_path(_get_live_game_state(), current_player):
		return
	pending_logic.clear()
	pending_logic.action = "deck_face_down"
	ui_selected_hand_card_id = -1
	_sync_after_state_change_without_card_layout()


func _on_strateg_take_pressed() -> void:
	if pending_logic.action != "strateg":
		return
	await pending_logic.try_take_strateg_preview(int(pending_logic.strateg_request.get("preview_card_id", -1)))


func _on_finish_choice_pressed() -> void:
	if game_over or animation_running:
		return
	if _is_ai_player(current_player) and not _pending_action_belongs_to_view_player():
		return
	if not pending_logic.can_finish_choice_target():
		return
	await pending_logic.finish_repeating_target()


func _on_replay_pressed() -> void:
	animation_running = false
	ai_running = false
	pending_logic.clear()
	minor_actions_spent = 0
	current_player = 0
	game_over = false
	game_over_message = ""
	destroyed_base_owner = -1
	_setup_game()
	_refresh_ui()


func _on_board_cell_gui_input(event: InputEvent, cell_panel: PanelContainer) -> void:
	if game_over or animation_running or pending_logic.action == "":
		return
	if _is_ai_player(current_player) and not _pending_action_belongs_to_view_player():
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	cell_panel.accept_event()
	var cell: Vector2i = cell_panel.get_meta("cell")
	if pending_logic.action == "hand":
		_try_play_hand_card(cell)
	elif pending_logic.action == "deck_face_down":
		_try_play_from_deck_face_down(cell)
	elif pending_logic.action == "target":
		await pending_logic.try_apply_target(cell)


func _pending_action_belongs_to_view_player() -> bool:
	var decision_player: int = pending_logic.get_decision_player()
	if decision_player != -1:
		return decision_player == _get_view_player()
	if pending_logic.action == "target":
		return int(pending_logic.target_request.get("player_index", -1)) == _get_view_player()
	if pending_logic.action == "hand_pick":
		return int(pending_logic.hand_pick_request.get("player_index", -1)) == _get_view_player()
	if pending_logic.action == "hand_discard":
		return pending_logic.hand_discard_player == _get_view_player()
	return false


func _get_board_cell_at_global_position(global_position: Vector2) -> Vector2i:
	for cell in board_cells.keys():
		var cell_panel: Control = board_cells[cell]
		if cell_panel.get_global_rect().has_point(global_position):
			return cell
	return Vector2i(-1, -1)


func _get_board_edge_at_global_position(global_position: Vector2) -> Array:
	for edge in pending_logic.get_target_edges():
		if _get_board_edge_global_rect(edge[0], edge[1]).has_point(global_position):
			return edge
	return []


func _get_board_edge_global_rect(first: Vector2i, second: Vector2i) -> Rect2:
	var first_rect: Rect2 = board_cells[first].get_global_rect()
	var second_rect: Rect2 = board_cells[second].get_global_rect()
	var thickness: float = max(18.0, float(CELL_GAP) + 10.0)
	if first.y == second.y:
		var center_x: float = ((first_rect.position.x + first_rect.size.x) + second_rect.position.x) * 0.5
		var top_y: float = max(first_rect.position.y, second_rect.position.y)
		var height: float = min(first_rect.size.y, second_rect.size.y)
		return Rect2(center_x - thickness * 0.5, top_y, thickness, height)
	var center_y: float = ((first_rect.position.y + first_rect.size.y) + second_rect.position.y) * 0.5
	var left_x: float = max(first_rect.position.x, second_rect.position.x)
	var width: float = min(first_rect.size.x, second_rect.size.x)
	return Rect2(left_x, center_y - thickness * 0.5, width, thickness)


func _try_play_hand_card(cell: Vector2i) -> void:
	if animation_running:
		return

	var hand: Array = players[current_player].hand
	var hand_index: int = _get_ui_selected_hand_index()
	if hand_index < 0 or hand_index >= hand.size():
		pending_logic.clear()
		return

	if pending_logic.is_extra_hand_play():
		var forced_card_id: int = int(pending_logic.extra_hand_play_request.get("forced_card_id", -1))
		if forced_card_id >= 0 and int(hand[hand_index].id) != forced_card_id:
			return

	var payload: Dictionary = {
		"hand_index": hand_index,
		"cell": cell
	}
	if tabletop_logic.attack_discard_selections.has(int(hand[hand_index].id)):
		payload.charodey_discard_id = int(tabletop_logic.attack_discard_selections[int(hand[hand_index].id)])
	var robot_copy_card_id: int = pending_logic.get_robot_copy_card_id(int(hand[hand_index].id))
	if String(hand[hand_index].unit.name_key) == UnitKeys.HLAMOVNIK_NAME and robot_copy_card_id >= 0:
		payload.copied_card_id = robot_copy_card_id
	if _is_robot_card(hand[hand_index]):
		if robot_copy_card_id < 0:
			action_label.text = _tr_text("UI_ERROR_ROBOT_COPY_REQUIRED")
			return
		payload.copied_card_id = robot_copy_card_id
	_add_deferred_source_play_reaction_to_payload(payload, pending_logic.get_extra_hand_play_source_request())
	var variant: Dictionary = _make_action_variant(ACTION_PLAY_HAND_CARD, current_player, payload)
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
	if result.has("pending_hand_discard"):
		pending_logic.begin_hand_discard(result.pending_hand_discard)
	elif result.has("pending_hand_pick"):
		pending_logic.begin_hand_pick(result.pending_hand_pick)
	elif result.has("pending_discard_pick"):
		pending_logic.begin_discard_pick(result.pending_discard_pick)
	elif result.has("pending_strateg"):
		pending_logic.begin_strateg(result.pending_strateg)
	elif result.has("pending_extra_hand_play"):
		pending_logic.begin_extra_hand_play(result.pending_extra_hand_play)
	elif result.has("pending_target"):
		pending_logic.begin_target(result.pending_target)
	else:
		pending_logic.clear()
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

	if _result_has_pending_action(result):
		pending_logic._begin_pending_from_result_or_clear(result)
	elif bool(result.keep_path_pending) and not bool(result.end_turn):
		pending_logic.action = "deck_face_down"
		ui_selected_hand_card_id = -1
	else:
		pending_logic.clear()
	_sync_after_state_change_without_card_layout()


func _can_play_card(card: Dictionary, cell: Vector2i) -> bool:
	return _can_play_card_in_state(_get_live_game_state(), card, cell)


func _can_play_card_in_state(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> bool:
	return play_legality_logic.can_play_card(state, card, cell, supply_result)


func _get_play_access_kind_in_state(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> String:
	return play_legality_logic.get_play_access_kind(state, card, cell, supply_result)


func _get_play_access_info_in_state(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	supply_result: Dictionary = {}
) -> Dictionary:
	return play_legality_logic.get_play_access_info(state, card, cell, supply_result)


func _place_card(card: Dictionary, cell: Vector2i) -> void:
	_place_card_in_state(_get_live_game_state(), card, cell)


func _place_card_in_state(state: Dictionary, card: Dictionary, cell: Vector2i) -> void:
	var stack: Array = _get_stack_in_state(state, cell)
	stack.append(card)


func _place_played_hand_card_in_state(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	ability_name_key: String = ""
) -> void:
	var stack: Array = _get_stack_in_state(state, cell)
	var play_name_key: String = ability_name_key
	if play_name_key.is_empty():
		play_name_key = String(card.unit.name_key)
	if play_name_key == UnitKeys.GNOM_NAME and not bool(card.face_down):
		stack.insert(0, card)
		return
	stack.append(card)


func _apply_played_card_overflow_in_state(
	state: Dictionary,
	card: Dictionary,
	cell: Vector2i,
	ability_name_key: String = ""
) -> void:
	if bool(card.face_down):
		return
	var name_key: String = ability_name_key
	if name_key.is_empty():
		name_key = String(card.unit.name_key)
	if name_key != UnitKeys.GNOM_NAME and name_key != UnitKeys.SKARABEY_NAME:
		return
	var stack: Array = _get_stack_in_state(state, cell)
	if stack.size() <= 2:
		return
	if name_key == UnitKeys.SKARABEY_NAME:
		var removed: Dictionary = stack.pop_front()
		_return_card_to_hand_in_state(state, int(removed.owner), removed, {
			"type": "board",
			"cell": cell,
			"face_down": bool(removed.face_down)
		})
		return
	var removed: Dictionary = stack.pop_back()
	_discard_card_in_state(state, int(removed.owner), removed, {
		"type": "board",
		"cell": cell,
		"face_down": bool(removed.face_down)
	})


func _record_action_event_in_state(state: Dictionary, event: Dictionary) -> void:
	if not state.has("events"):
		return
	state.events.append(event)


func _get_stack_card_snapshots_in_state(state: Dictionary, cell: Vector2i) -> Array:
	var snapshots: Array = []
	if not state.has("events"):
		return snapshots
	for card in _get_stack_in_state(state, cell):
		snapshots.append(card.duplicate(true))
	return snapshots


func _record_layout_stack_event_in_state(state: Dictionary, cell: Vector2i) -> void:
	if not state.has("events"):
		return
	_record_action_event_in_state(state, {
		"type": ANIMATION_LAYOUT_STACK,
		"cell": cell,
		"stack_cards": _get_stack_card_snapshots_in_state(state, cell)
	})


func _record_supply_control_event_if_changed_in_state(state: Dictionary, before_cells: Dictionary) -> void:
	var after_cells: Dictionary = _get_all_supply_origin_cells_in_state(state)
	if _supply_cells_equal(before_cells, after_cells):
		return
	_record_action_event_in_state(state, {
		"type": ANIMATION_SUPPLY_CONTROL,
		"from_cells": before_cells,
		"to_cells": after_cells
	})


func _supply_cells_equal(first: Dictionary, second: Dictionary) -> bool:
	for player_index in first.keys():
		var first_cells: Dictionary = first[player_index]
		var second_cells: Dictionary = second.get(player_index, {})
		if first_cells.size() != second_cells.size():
			return false
		for cell in first_cells.keys():
			if not second_cells.has(cell):
				return false
	for player_index in second.keys():
		if first.has(player_index):
			continue
		var second_cells: Dictionary = second[player_index]
		if not second_cells.is_empty():
			return false
	return true


func _discard_card_in_state(state: Dictionary, player_index: int, card: Dictionary, source: Dictionary = {}) -> void:
	if String(source.get("type", "")) == "board" and CardAbilities.name_key(card) == UnitKeys.FENIKS_NAME:
		_return_card_to_hand_in_state(state, player_index, card, source)
		return
	_reset_card_temporary_abilities(card)
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


func _return_card_to_hand_in_state(state: Dictionary, player_index: int, card: Dictionary, source: Dictionary = {}) -> void:
	_reset_card_temporary_abilities(card)
	card.owner = player_index
	card.face_down = false
	state.players[player_index].hand.append(card)
	_record_action_event_in_state(state, {
		"type": "draw_card",
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


func _trim_stacks_in_state(state: Dictionary) -> void:
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



func _get_next_hand_limit_discard_request(state: Dictionary) -> Dictionary:
	var player_count: int = state.players.size()
	for offset in range(player_count):
		var player_index: int = (int(state.current_player) + offset) % player_count
		var overflow_count: int = (
			state.players[player_index].hand.size()
			- _get_max_hand_size_in_state(state, player_index)
		)
		if overflow_count <= 0:
			continue
		return {
			"kind": "end_turn_hand_limit",
			"player_index": player_index,
			"decision_player": player_index,
			"count": overflow_count,
			"allowed_card_ids": [],
			"optional": false
		}
	return {}


func _discard_hand_limit_cards_for_ai_in_state(state: Dictionary, request: Dictionary) -> void:
	var player_index: int = int(request.player_index)
	var hand: Array = state.players[player_index].hand
	var discard_count: int = min(int(request.count), hand.size())
	for i in range(discard_count):
		var hand_index: int = hand.size() - 1
		var discarded: Dictionary = hand.pop_back()
		_discard_card_in_state(state, player_index, discarded, {
			"type": "hand",
			"hand_index": hand_index
		})


func _get_max_hand_size_in_state(state: Dictionary, player_index: int) -> int:
	var max_size: int = MAX_HAND
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var stack: Array = state.board[y][x]
			if stack.is_empty():
				continue
			var card: Dictionary = stack[stack.size() - 1]
			if int(card.owner) != player_index:
				continue
			if bool(card.face_down):
				continue
			if CardAbilities.active_name_key(state, Vector2i(x, y)) == UnitKeys.LAGER_NAME:
				max_size += 1
	return max_size


func _draw_cards_in_state(state: Dictionary, player_index: int, count: int) -> Array:
	var deck: Array = state.players[player_index].deck
	var hand: Array = state.players[player_index].hand
	var drawn_ids: Array = []
	for i in range(count):
		_refill_deck_if_empty_in_state(state, player_index)
		if deck.is_empty():
			return drawn_ids
		var card: Dictionary = deck.pop_back()
		card.owner = player_index
		card.face_down = false
		hand.append(card)
		drawn_ids.append(int(card.id))
		_record_draw_event_in_state(state, player_index, card)
	_refill_deck_if_empty_in_state(state, player_index)
	return drawn_ids


func _refill_deck_if_empty_in_state(state: Dictionary, player_index: int) -> bool:
	var deck: Array = state.players[player_index].deck
	if not deck.is_empty():
		return true
	if _is_solo_mode() and player_index == solo_logic.ENEMY_PLAYER_INDEX:
		for unit in state.players[player_index].deck_template:
			deck.append(_make_card_in_state(state, unit, player_index, false))
	else:
		var discard: Array = state.players[player_index].discard
		for card in discard:
			_reset_card_temporary_abilities(card)
			card.face_down = false
			deck.append(card)
		discard.clear()
	deck.shuffle()
	return not deck.is_empty()

func _count_discardable_hand_cards(hand: Array, allowed_card_ids: Array) -> int:
	if allowed_card_ids.is_empty():
		return hand.size()
	var count: int = 0
	for card in hand:
		if allowed_card_ids.has(int(card.id)):
			count += 1
	return count


func _get_supplied_cells_in_state(state: Dictionary, player_index: int) -> Dictionary:
	return supply_logic.get_supplied_cells(state, player_index)


func _get_all_supply_origin_cells_in_state(state: Dictionary) -> Dictionary:
	var all_cells: Dictionary = {}
	for player_index in range(state.players.size()):
		all_cells[player_index] = _get_supply_origin_cells_in_state(state, player_index)
	return all_cells


func _get_supply_edges_in_state(state: Dictionary, player_index: int) -> Dictionary:
	return supply_logic.get_supply_edges(state, player_index)


func _get_supply_origin_cells_in_state(state: Dictionary, player_index: int) -> Dictionary:
	return supply_logic.get_supply_origin_cells(state, player_index)


func _get_stack_in_state(state: Dictionary, cell: Vector2i) -> Array:
	return state.board[cell.y][cell.x]


func _top_owner_in_state(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = _get_stack_in_state(state, cell)
	if stack.is_empty():
		return -1
	return int(stack[stack.size() - 1].owner)


func _top_power_in_state(state: Dictionary, cell: Vector2i) -> int:
	return power_logic.get_top_power(state, cell)


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
	return barrier_ops.has_barrier(state, a, b)


func _add_barrier_to_state(state: Dictionary, a: Vector2i, b: Vector2i) -> void:
	barrier_ops.add_barrier(state, a, b)
	if tabletop_logic != null:
		tabletop_logic.resolve_continuous(state)


func _remove_barrier_from_state(state: Dictionary, a: Vector2i, b: Vector2i) -> void:
	barrier_ops.remove_barrier(state, a, b)


func _get_barrier_edges_in_state(state: Dictionary) -> Array:
	return barrier_ops.get_barrier_edges(state)


func _get_base_cell_for_player_in_state(state: Dictionary, player_index: int) -> Vector2i:
	var state_players: Array = Array(state.get("players", []))
	if player_index >= 0 and player_index < state_players.size():
		return state_players[player_index].base
	if player_index >= 0 and player_index < players.size():
		return players[player_index].base
	return PLAYER_BASE_CELLS[player_index]


func _bases_are_connected_in_state(state: Dictionary) -> bool:
	var start: Vector2i = _get_base_cell_for_player_in_state(state, 0)
	var target: Vector2i = _get_base_cell_for_player_in_state(state, 1)
	var visited = {}
	var queue: Array = [start]
	visited[start] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			return true

		for next in _get_board_neighbors(current):
			if visited.has(next):
				continue
			if _has_barrier_in_state(state, current, next):
				continue
			visited[next] = true
			queue.append(next)

	return false


func _end_turn() -> void:
	if animation_running:
		return
	if game_over:
		_sync_after_state_change_without_card_layout()
		return
	var state: Dictionary = _get_live_game_state()
	var result: Dictionary = _make_action_result(RESULT_OK, "")
	result.end_turn = true
	_apply_end_turn_rules_to_state(state, result)
	_restore_game_state(state)
	pending_logic._begin_pending_from_result_or_clear(result)
	_sync_after_state_change_without_card_layout()


func _can_press_minor_action_button() -> bool:
	if game_over or animation_running:
		return false
	if _is_ai_player(current_player):
		return false
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		return false
	if pending_logic.is_extra_hand_play():
		return false
	return pending_logic.action == "" or pending_logic.action == "hand" or pending_logic.action == "deck_face_down"


func _finish_minor_action(keep_path_pending: bool = false) -> void:
	minor_actions_spent += 1
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		pending_logic.clear()
		_end_turn()
	else:
		if keep_path_pending:
			pending_logic.action = "deck_face_down"
			ui_selected_hand_card_id = -1
		else:
			pending_logic.clear()
		_sync_after_state_change_without_card_layout()


func _minor_actions_left() -> int:
	return max(0, TURN_MINOR_ACTIONS - minor_actions_spent)


func _draw_cards(player_index: int, count: int) -> void:
	_draw_cards_in_state(_get_live_game_state(), player_index, count)


func _get_supplied_cells(player_index: int) -> Dictionary:
	return supply_logic.get_supplied_cells(_get_live_game_state(), player_index)


func _get_stack(cell: Vector2i) -> Array:
	return board[cell.y][cell.x]


func _top_owner(cell: Vector2i) -> int:
	var stack: Array = _get_stack(cell)
	if stack.is_empty():
		return -1
	return int(stack[stack.size() - 1].owner)


func _top_power(cell: Vector2i) -> int:
	return power_logic.get_top_power(_get_live_game_state(), cell)


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
	return board_topology.is_inside(cell)


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
	return board_topology.get_all_edges()


func _get_board_neighbors(cell: Vector2i) -> Array:
	return board_topology.get_neighbors(cell)


func _add_rotated_barrier(a: Vector2i, b: Vector2i) -> void:
	_add_barrier(_rotate_cell(a), _rotate_cell(b))


func _rotate_cell(cell: Vector2i) -> Vector2i:
	return board_topology.rotate_cell(cell)


func _bases_are_connected() -> bool:
	return _bases_are_connected_in_state(_get_live_game_state())


func _add_barrier(a: Vector2i, b: Vector2i) -> void:
	_add_barrier_to_state(_get_live_game_state(), a, b)


func _has_barrier(a: Vector2i, b: Vector2i) -> bool:
	return barrier_ops.has_barrier(_get_live_game_state(), a, b)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	return board_topology.edge_key(a, b)


func _set_action_buttons_enabled(enabled: bool) -> void:
	if not enabled or animation_running:
		draw_two_button.disabled = true
		deck_two_button.disabled = true
		finish_choice_button.disabled = true
		strateg_take_button.disabled = true
		return
	var state: Dictionary = _get_live_game_state()
	draw_two_button.disabled = not action_restriction_logic.can_draw_card(state, current_player)
	deck_two_button.disabled = not action_restriction_logic.can_play_path(state, current_player)
	finish_choice_button.disabled = not pending_logic.can_finish_choice_target()


func _reset_card_temporary_abilities(card: Dictionary) -> void:
	for key in ["ability_unit", "copied_power", "copied_name", "attack_power_override", "attack_bonus"]:
		card.erase(key)


func _has_available_deck_cards_in_state(state: Dictionary, player_index: int) -> bool:
	var player: Dictionary = state.players[player_index]
	return not player.deck.is_empty() or not player.discard.is_empty() or (_is_solo_mode() and player_index == solo_logic.ENEMY_PLAYER_INDEX and not player.deck_template.is_empty())
