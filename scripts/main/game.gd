extends Control

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 5
const CARD_INNER_WIDTH: int = 124
const CARD_INNER_HEIGHT: int = 105
const CARD_FRAME_WIDTH: int = 2
const CARD_WIDTH: int = CARD_INNER_WIDTH + CARD_FRAME_WIDTH * 2
const CARD_HEIGHT: int = CARD_INNER_HEIGHT + CARD_FRAME_WIDTH * 2
const CELL_SIZE: int = CARD_WIDTH
const CELL_GAP: int = 8
const MAX_HAND: int = 7
const TURN_MINOR_ACTIONS: int = 2
const UNIT_DIR: String = "res://resources/units"
const WOOD_CARD_COLOR: Color = Color(0.32, 0.21, 0.12)
const METAL_CARD_COLOR: Color = Color(0.14, 0.22, 0.31)
const TOOLTIP_BACKGROUND_COLOR: Color = Color(0.03, 0.025, 0.02)
const SUPPLY_PIPE_WIDTH: float = float(CELL_GAP)
const UnitScene: PackedScene = preload("res://scenes/unit.tscn")
const WoodBaseTexture: Texture2D = preload("res://assets/bases/base_single.jpg")
const MetalBaseTexture: Texture2D = preload("res://assets/bases/bases_pair.jpg")
const WoodCardBackTexture: Texture2D = preload("res://assets/cards/card_back_red.jpeg")
const MetalCardBackTexture: Texture2D = preload("res://assets/cards/card_back_blue.jpeg")
const TableBackgroundTexture: Texture2D = preload("res://assets/backgrounds/table_stone_background.jpg")

var board = []
var barriers = {}
var players = []
var current_player: int = 0
var selected_hand_index: int = -1
var pending_action: String = ""
var minor_actions_spent: int = 0
var game_over: bool = false
var game_over_message: String = ""
var animation_running: bool = false

var board_cells = {}
var board_cell_labels = {}
var board_cell_bases = {}
var board_cell_stacks = {}
var hand_card_controls = {}

var action_label: Label
var hand_container: VBoxContainer
var opponent_hand_container: VBoxContainer
var board_area: Control
var board_grid: GridContainer
var supply_line_layer: Control
var barrier_layer: Control
var draw_two_button: Button
var deck_two_button: Button


func _ready() -> void:
	TranslationServer.set_locale("ru")
	randomize()
	_setup_game()
	_build_ui()
	_refresh_ui()


func _setup_game() -> void:
	board.clear()
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append([])
		board.append(row)

	barriers.clear()
	_generate_initial_barriers()

	var all_units = _load_units()
	all_units.shuffle()
	var midpoint: int = int(all_units.size() / 2)
	var first_deck = all_units.slice(0, midpoint)
	var second_deck = all_units.slice(midpoint, all_units.size())

	players = [
		{
			"name": "Древесный игрок",
			"base": Vector2i(1, 1),
			"deck": first_deck,
			"hand": [],
			"discard": []
		},
		{
			"name": "Металлический игрок",
			"base": Vector2i(5, 3),
			"deck": second_deck,
			"hand": [],
			"discard": []
		}
	]

	_draw_cards(0, 4)
	_draw_cards(1, 5)


func _load_units() -> Array:
	var units: Array = []
	var dir: DirAccess = DirAccess.open(UNIT_DIR)
	if dir == null:
		return units

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var unit = load("%s/%s" % [UNIT_DIR, file_name])
			if unit is Resource:
				units.append(unit)
		file_name = dir.get_next()
	dir.list_dir_end()
	return units


func _make_ui_theme() -> Theme:
	var ui_theme = Theme.new()

	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = TOOLTIP_BACKGROUND_COLOR
	tooltip_style.border_color = Color(0.72, 0.62, 0.46)
	tooltip_style.set_border_width_all(2)
	tooltip_style.set_corner_radius_all(0)
	tooltip_style.content_margin_left = 10
	tooltip_style.content_margin_top = 8
	tooltip_style.content_margin_right = 10
	tooltip_style.content_margin_bottom = 8

	ui_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	ui_theme.set_color("font_color", "TooltipLabel", Color(0.96, 0.94, 0.88))
	ui_theme.set_color("font_shadow_color", "TooltipLabel", Color(0.0, 0.0, 0.0))
	ui_theme.set_constant("shadow_offset_x", "TooltipLabel", 1)
	ui_theme.set_constant("shadow_offset_y", "TooltipLabel", 1)
	ui_theme.set_font_size("font_size", "TooltipLabel", 14)
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

	var root = CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var main_row = HBoxContainer.new()
	var board_size: Vector2 = _get_board_pixel_size()
	var side_panel_height: float = board_size.y
	main_row.custom_minimum_size = Vector2(
		CARD_WIDTH + 24 + board_size.x + 150 + 24,
		board_size.y
	)
	main_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_row.add_theme_constant_override("separation", 12)
	root.add_child(main_row)

	var hand_panel = VBoxContainer.new()
	hand_panel.custom_minimum_size = Vector2(CARD_WIDTH + 24, side_panel_height)
	hand_panel.add_theme_constant_override("separation", 6)
	main_row.add_child(hand_panel)

	action_label = Label.new()
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand_panel.add_child(action_label)

	draw_two_button = Button.new()
	draw_two_button.text = _tr_text("UI_DRAW")
	draw_two_button.tooltip_text = _tr_text("UI_TOOLTIP_DRAW")
	draw_two_button.pressed.connect(_on_draw_two_pressed)
	hand_panel.add_child(draw_two_button)

	deck_two_button = Button.new()
	deck_two_button.text = _tr_text("UI_PATH")
	deck_two_button.tooltip_text = _tr_text("UI_TOOLTIP_PATH")
	deck_two_button.pressed.connect(_on_deck_two_pressed)
	hand_panel.add_child(deck_two_button)

	var hand_scroll = ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_panel.add_child(hand_scroll)

	var hand_center = HBoxContainer.new()
	hand_center.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_center)

	hand_container = VBoxContainer.new()
	hand_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hand_container.add_theme_constant_override("separation", 8)
	hand_center.add_child(hand_container)

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
	opponent_hand_panel.custom_minimum_size = Vector2(150, side_panel_height)
	opponent_hand_panel.add_theme_constant_override("separation", 6)
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
	opponent_hand_container.add_theme_constant_override("separation", 8)
	opponent_hand_center.add_child(opponent_hand_container)

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

	_resize_board_to_available.call_deferred()


func _refresh_ui() -> void:
	if game_over:
		action_label.text = game_over_message
	else:
		action_label.text = _get_action_text()

	var playable_cells: Dictionary = _get_playable_cells_for_pending_action()
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
		_refresh_base_visual(cell, base_container)
		if stack_container.visible:
			_refresh_board_stack_visual(cell, stack_container)
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
	_refresh_hand()
	_refresh_opponent_hand()
	_set_action_buttons_enabled(_can_press_minor_action_button())


func _refresh_hand() -> void:
	hand_card_controls.clear()
	for child in hand_container.get_children():
		child.queue_free()

	var hand: Array = players[current_player].hand
	for i in range(hand.size()):
		var unit_control: Control = UnitScene.instantiate()
		unit_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		unit_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		unit_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		unit_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		unit_control.unit = hand[i]
		unit_control.player_index = current_player
		unit_control.tooltip_text = _get_unit_tooltip(hand[i])
		unit_control.set_meta("hand_index", i)
		_prepare_hand_card_input(unit_control)
		unit_control.gui_input.connect(_on_hand_card_gui_input.bind(unit_control))
		hand_card_controls[i] = unit_control
		if minor_actions_spent > 0:
			unit_control.set_portrait_desaturated(true)
			unit_control.set_text_muted(true)
		elif i == selected_hand_index:
			unit_control.modulate = Color(1.0, 0.92, 0.55)
		hand_container.add_child(unit_control)


func _refresh_opponent_hand() -> void:
	for child in opponent_hand_container.get_children():
		child.queue_free()

	var opponent_index: int = _opponent(current_player)
	var hand: Array = players[opponent_index].hand
	for i in range(hand.size()):
		var path_card: Control = _make_face_down_card(opponent_index)
		path_card.mouse_filter = Control.MOUSE_FILTER_STOP
		path_card.tooltip_text = _tr_text("UI_TOOLTIP_OPPONENT_PATH_HAND")
		path_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		path_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		opponent_hand_container.add_child(path_card)


func _get_action_text() -> String:
	if pending_action == "hand":
		return _tr_text("UI_STATUS_CHOOSE_HAND_CELL")
	if pending_action == "deck_face_down":
		return _tr_text("UI_STATUS_CHOOSE_PATH_CELL")
	if minor_actions_spent > 0:
		return _tr_text("UI_STATUS_MINOR_ACTIONS_LEFT")
	return _tr_text("UI_STATUS_CHOOSE_ACTION")


func _get_playable_cells_for_pending_action() -> Dictionary:
	var playable = {}
	var card: Dictionary = {}
	if pending_action == "hand":
		var hand: Array = players[current_player].hand
		if selected_hand_index < 0 or selected_hand_index >= hand.size():
			return playable
		card = {
			"unit": hand[selected_hand_index],
			"owner": current_player,
			"face_down": false
		}
	elif pending_action == "deck_face_down":
		var deck: Array = players[current_player].deck
		if deck.is_empty():
			return playable
		card = {
			"unit": deck[deck.size() - 1],
			"owner": current_player,
			"face_down": true
		}
	else:
		return playable

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if _can_play_card(card, cell):
				playable[cell] = true
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
	if base_owner == 0:
		style.border_color = Color(0.25, 0.16, 0.09)
	else:
		style.border_color = Color(0.10, 0.16, 0.23)
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
		if card.owner == current_player:
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


func _refresh_board_stack_visual(cell: Vector2i, stack_container: Control) -> void:
	for child in stack_container.get_children():
		child.queue_free()

	var stack: Array = _get_stack(cell)
	var overlap_offset: int = CELL_SIZE - CARD_HEIGHT
	var single_card_y: float = (CELL_SIZE - CARD_HEIGHT) * 0.5
	for i in range(stack.size()):
		var card = stack[i]
		var card_control: Control
		var is_covered: bool = i < stack.size() - 1
		if card.face_down:
			card_control = _make_face_down_board_card(card, cell)
		else:
			card_control = _make_board_unit_card(card, cell, is_covered)
		card_control.mouse_filter = Control.MOUSE_FILTER_PASS
		card_control.tooltip_text = _get_card_tooltip(card)
		var visual_index: int = stack.size() - 1 - i
		if stack.size() == 1:
			card_control.position = Vector2(0, single_card_y)
		else:
			card_control.position = Vector2(0, visual_index * overlap_offset)
		stack_container.add_child(card_control)


func _make_board_unit_card(card: Dictionary, cell: Vector2i, is_covered: bool) -> Control:
	var unit_control: Control = UnitScene.instantiate()
	unit_control.unit = card.unit
	unit_control.player_index = card.owner
	unit_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	unit_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	unit_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_unsupplied: bool = not _is_card_supplied(card, cell)
	if is_unsupplied:
		unit_control.set_portrait_desaturated(true)
	if is_unsupplied or is_covered:
		unit_control.set_text_muted(true)
	_disable_child_mouse_input(unit_control)
	return unit_control


func _is_card_supplied(card: Dictionary, cell: Vector2i) -> bool:
	var supplied_cells: Dictionary = _get_supplied_cells(card.owner)
	return supplied_cells.has(cell)


func _make_face_down_board_card(card: Dictionary, cell: Vector2i) -> Control:
	return _make_face_down_card(card.owner, not _is_card_supplied(card, cell))


func _make_face_down_card(owner: int, desaturate_back: bool = false) -> Control:
	var card_control = Control.new()
	card_control.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _make_card_background_style(owner))
	card_control.add_child(background)

	var card_back = TextureRect.new()
	card_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_back.offset_left = CARD_FRAME_WIDTH
	card_back.offset_top = CARD_FRAME_WIDTH
	card_back.offset_right = -CARD_FRAME_WIDTH
	card_back.offset_bottom = -CARD_FRAME_WIDTH
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_back.stretch_mode = TextureRect.STRETCH_SCALE
	if owner == 0:
		card_back.texture = WoodCardBackTexture
	else:
		card_back.texture = MetalCardBackTexture
	if desaturate_back:
		card_back.material = _make_desaturation_material()
	card_control.add_child(card_back)

	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _make_card_frame_style(owner))
	card_control.add_child(frame)
	return card_control


func _make_desaturation_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "
shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(color.rgb, vec3(gray), 0.65);
	COLOR = vec4(muted, color.a);
}
"
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	return shader_material


func _make_card_background_style(owner: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _get_player_card_color(owner)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _make_card_frame_style(owner: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color.a = 0.0
	style.border_color = _get_player_card_color(owner)
	style.set_border_width_all(CARD_FRAME_WIDTH)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _get_player_card_color(player_index: int) -> Color:
	if player_index == 0:
		return WOOD_CARD_COLOR
	if player_index == 1:
		return METAL_CARD_COLOR
	return Color(0.16, 0.16, 0.16)


func _animate_unit_to_cell(unit: Resource, source_control: Control, cell: Vector2i, player_index: int) -> void:
	if source_control == null:
		return

	source_control.visible = false

	var source_rect: Rect2 = source_control.get_global_rect()
	var target_position: Vector2 = _get_card_target_global_position(cell)
	var flying_unit: Control = UnitScene.instantiate()
	flying_unit.unit = unit
	flying_unit.player_index = player_index
	flying_unit.custom_minimum_size = source_rect.size
	flying_unit.size = source_rect.size
	flying_unit.global_position = source_rect.position
	flying_unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying_unit.set_as_top_level(true)
	flying_unit.z_index = 4096
	add_child(flying_unit)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_unit, "global_position", target_position, 0.32)
	await tween.finished
	flying_unit.queue_free()


func _get_card_target_global_position(cell: Vector2i) -> Vector2:
	var stack_container: Control = board_cell_stacks.get(cell, null)
	if stack_container != null:
		var target_position: Vector2 = stack_container.get_global_rect().position
		if _get_stack(cell).is_empty():
			target_position.y += (CELL_SIZE - CARD_HEIGHT) * 0.5
		return target_position

	var target_rect: Rect2 = board_cells[cell].get_global_rect()
	return target_rect.position


func _queue_barrier_redraw() -> void:
	if supply_line_layer != null:
		supply_line_layer.queue_redraw()
	if barrier_layer != null:
		barrier_layer.queue_redraw()


func _on_supply_line_layer_draw() -> void:
	_draw_supply_networks()
	var playable_cells: Dictionary = _get_playable_cells_for_pending_action()
	_draw_playable_supply_lines(playable_cells)


func _on_barrier_layer_draw() -> void:
	var playable_cells: Dictionary = _get_playable_cells_for_pending_action()
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
	var tip: Vector2 = _get_rect_edge_point(to_rect, -direction) + direction * 10.0
	_draw_arrow_head(tip, direction, color)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var length: float = 14.0
	var width: float = 8.0
	var outline_color: Color = Color(0.22, 0.03, 0.02, 1.0)
	var outline_length: float = length + 2.0
	var outline_width: float = width + 2.0
	var outline_points: PackedVector2Array = PackedVector2Array([
		tip + direction * 9.0,
		tip - direction * outline_length + side * outline_width,
		tip - direction * outline_length - side * outline_width
	])
	var points: PackedVector2Array = PackedVector2Array([
		tip + direction * 8.0,
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
	var thickness: float = 12.0
	var frame_width: float = 2.0
	var inset: float = 6.0
	var frame_color: Color = Color(0.02, 0.015, 0.01)
	var fill_color: Color = Color(0.88, 0.69, 0.32)
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


func _on_hand_card_gui_input(event: InputEvent, unit_control: Control) -> void:
	if game_over or animation_running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if minor_actions_spent > 0:
			return
		if pending_action != "" and pending_action != "hand":
			return
		selected_hand_index = int(unit_control.get_meta("hand_index"))
		pending_action = "hand"
		_refresh_ui()


func _prepare_hand_card_input(card_control: Control) -> void:
	card_control.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in card_control.get_children():
		_disable_child_mouse_input(child)


func _disable_child_mouse_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_child_mouse_input(child)


func _on_draw_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	_clear_pending()
	_draw_cards(current_player, 1)
	_finish_minor_action()


func _on_deck_two_pressed() -> void:
	if not _can_press_minor_action_button():
		return
	_clear_pending()
	pending_action = "deck_face_down"
	selected_hand_index = -1
	_refresh_ui()


func _on_board_cell_gui_input(event: InputEvent, cell_panel: PanelContainer) -> void:
	if game_over or animation_running or pending_action == "":
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var cell: Vector2i = cell_panel.get_meta("cell")
	if pending_action == "hand":
		_try_play_hand_card(cell)
	elif pending_action == "deck_face_down":
		_try_play_from_deck_face_down(cell)


func _try_play_hand_card(cell: Vector2i) -> void:
	if animation_running:
		return

	var hand: Array = players[current_player].hand
	if selected_hand_index < 0 or selected_hand_index >= hand.size():
		_clear_pending()
		return

	var unit: Resource = hand[selected_hand_index]
	var card = {
		"unit": unit,
		"owner": current_player,
		"face_down": false
	}

	if not _can_play_card(card, cell):
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_CARD")
		return

	var source_control: Control = hand_card_controls.get(selected_hand_index, null)
	hand.remove_at(selected_hand_index)
	animation_running = true
	_set_action_buttons_enabled(false)
	await _animate_unit_to_cell(unit, source_control, cell, current_player)
	_place_card(card, cell)
	animation_running = false
	_after_successful_play(cell)


func _try_play_from_deck_face_down(cell: Vector2i) -> void:
	var deck: Array = players[current_player].deck
	if deck.is_empty():
		action_label.text = _tr_text("UI_ERROR_EMPTY_DECK")
		return

	var unit: Resource = deck[deck.size() - 1]
	var card = {
		"unit": unit,
		"owner": current_player,
		"face_down": true
	}

	if not _can_play_card(card, cell):
		action_label.text = _tr_text("UI_ERROR_CANNOT_PLAY_PATH")
		return

	deck.pop_back()
	_place_card(card, cell)
	_finish_minor_action(not deck.is_empty())


func _after_successful_play(cell: Vector2i) -> void:
	if _get_base_owner(cell) == _opponent(current_player):
		game_over = true
		game_over_message = _tr_text("UI_GAME_OVER") % players[current_player].name
		_clear_pending()
		_refresh_ui()
		return

	_end_turn()


func _can_play_card(card: Dictionary, cell: Vector2i) -> bool:
	if not _is_inside(cell):
		return false
	if _get_base_owner(cell) == current_player:
		return false
	if not _get_supplied_cells(current_player).has(cell):
		return false

	var stack: Array = _get_stack(cell)
	var base_owner: int = _get_base_owner(cell)
	if card.face_down:
		if base_owner != -1:
			return false
		if stack.is_empty():
			return true
		return _top_owner(cell) == current_player

	if base_owner == _opponent(current_player):
		return true
	if stack.is_empty():
		return true
	if _top_owner(cell) == current_player:
		return true
	if _top_face_down(cell):
		return true

	var attack_power: int = card.unit.power
	var defense_power: int = _top_power(cell)
	return attack_power >= defense_power


func _place_card(card: Dictionary, cell: Vector2i) -> void:
	var stack: Array = _get_stack(cell)
	stack.append(card)


func _trim_stacks_and_hands() -> void:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var stack: Array = board[y][x]
			while stack.size() > 2:
				var removed = stack.pop_front()
				players[removed.owner].discard.append(removed.unit)

	for i in range(players.size()):
		while players[i].hand.size() > MAX_HAND:
			var discarded = players[i].hand.pop_back()
			players[i].discard.append(discarded)


func _end_turn() -> void:
	if animation_running:
		return
	if game_over:
		_refresh_ui()
		return
	_trim_stacks_and_hands()
	_clear_pending()
	minor_actions_spent = 0
	current_player = _opponent(current_player)
	_refresh_ui()


func _clear_pending() -> void:
	pending_action = ""
	selected_hand_index = -1


func _can_press_minor_action_button() -> bool:
	if game_over or animation_running:
		return false
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		return false
	return pending_action == "" or pending_action == "hand" or pending_action == "deck_face_down"


func _finish_minor_action(keep_path_pending: bool = false) -> void:
	minor_actions_spent += 1
	if minor_actions_spent >= TURN_MINOR_ACTIONS:
		_clear_pending()
		_end_turn()
	else:
		if keep_path_pending:
			pending_action = "deck_face_down"
			selected_hand_index = -1
		else:
			_clear_pending()
		_refresh_ui()


func _minor_actions_left() -> int:
	return max(0, TURN_MINOR_ACTIONS - minor_actions_spent)


func _draw_cards(player_index: int, count: int) -> void:
	var deck: Array = players[player_index].deck
	var hand: Array = players[player_index].hand
	for i in range(count):
		if deck.is_empty():
			return
		hand.append(deck.pop_back())


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
