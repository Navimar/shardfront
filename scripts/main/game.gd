extends Control

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 5
const MAX_HAND: int = 7
const UNIT_DIR: String = "res://resources/units"
const UnitScene: PackedScene = preload("res://scenes/unit.tscn")

var board = []
var barriers = {}
var players = []
var current_player: int = 0
var selected_hand_index: int = -1
var pending_action: String = ""
var pending_count: int = 0
var game_over: bool = false

var board_buttons = {}

var status_label: Label
var action_label: Label
var supply_label: Label
var hand_container: HBoxContainer
var board_grid: GridContainer
var discard_label: Label
var draw_two_button: Button
var deck_two_button: Button
var draw_deck_button: Button
var end_turn_button: Button


func _ready() -> void:
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
	_add_barrier(Vector2i(3, 2), Vector2i(4, 2))
	_add_barrier(Vector2i(5, 4), Vector2i(4, 4))
	_add_barrier(Vector2i(4, 2), Vector2i(4, 3))
	_add_barrier(Vector2i(4, 4), Vector2i(4, 3))

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


func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var main_row = HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	root.add_child(main_row)

	board_grid = GridContainer.new()
	board_grid.columns = GRID_WIDTH
	board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(board_grid)

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var button = Button.new()
			button.custom_minimum_size = Vector2(118, 88)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.clip_text = true
			button.set_meta("cell", Vector2i(x, y))
			button.pressed.connect(_on_board_button_pressed.bind(button))
			board_grid.add_child(button)
			board_buttons[Vector2i(x, y)] = button

	var side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 0)
	side.add_theme_constant_override("separation", 8)
	main_row.add_child(side)

	action_label = Label.new()
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(action_label)

	draw_two_button = Button.new()
	draw_two_button.text = "Добрать 2"
	draw_two_button.pressed.connect(_on_draw_two_pressed)
	side.add_child(draw_two_button)

	deck_two_button = Button.new()
	deck_two_button.text = "2 с верха рубашкой"
	deck_two_button.pressed.connect(_on_deck_two_pressed)
	side.add_child(deck_two_button)

	draw_deck_button = Button.new()
	draw_deck_button.text = "Добрать 1 + 1 рубашкой"
	draw_deck_button.pressed.connect(_on_draw_deck_pressed)
	side.add_child(draw_deck_button)

	end_turn_button = Button.new()
	end_turn_button.text = "Завершить ход"
	end_turn_button.pressed.connect(_end_turn)
	side.add_child(end_turn_button)

	discard_label = Label.new()
	discard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(discard_label)

	supply_label = Label.new()
	supply_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(supply_label)

	var hand_title = Label.new()
	hand_title.text = "Рука"
	root.add_child(hand_title)

	var hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 230)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(hand_scroll)

	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_container)


func _refresh_ui() -> void:
	var player = players[current_player]
	status_label.text = "%s. Колода: %d, рука: %d. Цель: разыграть существо на базу соперника." % [
		player.name,
		player.deck.size(),
		player.hand.size()
	]

	if game_over:
		action_label.text = "Игра окончена."
	else:
		action_label.text = _get_action_text()

	discard_label.text = "Сброс: %s / %s" % [players[0].discard.size(), players[1].discard.size()]
	supply_label.text = "Снабжение: подсвечены клетки, доступные текущему игроку."

	var supplied = _get_supplied_cells(current_player)
	for cell in board_buttons.keys():
		var button: Button = board_buttons[cell]
		button.text = _get_cell_text(cell)
		if supplied.has(cell):
			button.modulate = Color(1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.68, 0.68, 0.68)

	_refresh_hand()
	_set_action_buttons_enabled(not game_over and pending_action == "")


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	var hand: Array = players[current_player].hand
	for i in range(hand.size()):
		var unit_control: Control = UnitScene.instantiate()
		unit_control.custom_minimum_size = Vector2(190, 220)
		unit_control.unit = hand[i]
		unit_control.set_meta("hand_index", i)
		_prepare_hand_card_input(unit_control)
		unit_control.gui_input.connect(_on_hand_card_gui_input.bind(unit_control))
		if i == selected_hand_index:
			unit_control.modulate = Color(1.0, 0.92, 0.55)
		hand_container.add_child(unit_control)


func _get_action_text() -> String:
	if pending_action == "hand":
		return "Выберите клетку для карты из руки."
	if pending_action == "deck_face_down":
		return "Выберите клетку для карты с верха колоды рубашкой вверх. Осталось: %d" % pending_count
	if pending_action == "draw_then_deck":
		return "Выберите клетку для карты с верха колоды рубашкой вверх."
	return "Выберите действие хода или карту из руки."


func _get_cell_text(cell: Vector2i) -> String:
	var text: String = "%d,%d" % [cell.x + 1, cell.y + 1]
	var barrier_text: String = _get_barrier_text(cell)
	if barrier_text != "":
		text += "\nБарьеры: %s" % barrier_text
	var base_owner: int = _get_base_owner(cell)
	if base_owner != -1:
		text += "\nБаза\n%s" % _short_player_name(base_owner)

	var stack: Array = _get_stack(cell)
	if stack.size() > 0:
		text += "\n"
		for card in stack:
			text += _get_card_short_text(card) + "\n"
	return text.strip_edges()


func _get_barrier_text(cell: Vector2i) -> String:
	var parts: Array = []
	if _has_barrier(cell, cell + Vector2i.UP):
		parts.append("верх")
	if _has_barrier(cell, cell + Vector2i.RIGHT):
		parts.append("право")
	if _has_barrier(cell, cell + Vector2i.DOWN):
		parts.append("низ")
	if _has_barrier(cell, cell + Vector2i.LEFT):
		parts.append("лево")
	return ", ".join(parts)


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
	if game_over or pending_action != "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_hand_index = int(unit_control.get_meta("hand_index"))
		pending_action = "hand"
		pending_count = 1
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
	if not _can_start_action():
		return
	_draw_cards(current_player, 2)
	_end_turn()


func _on_deck_two_pressed() -> void:
	if not _can_start_action():
		return
	pending_action = "deck_face_down"
	pending_count = 2
	selected_hand_index = -1
	_refresh_ui()


func _on_draw_deck_pressed() -> void:
	if not _can_start_action():
		return
	_draw_cards(current_player, 1)
	pending_action = "draw_then_deck"
	pending_count = 1
	selected_hand_index = -1
	_refresh_ui()


func _on_board_button_pressed(button: Button) -> void:
	if game_over or pending_action == "":
		return

	var cell: Vector2i = button.get_meta("cell")
	if pending_action == "hand":
		_try_play_hand_card(cell)
	elif pending_action == "deck_face_down" or pending_action == "draw_then_deck":
		_try_play_from_deck_face_down(cell)


func _try_play_hand_card(cell: Vector2i) -> void:
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
		action_label.text = "Сюда нельзя разыграть эту карту."
		return

	hand.remove_at(selected_hand_index)
	_place_card(card, cell)
	_after_successful_play(cell)


func _try_play_from_deck_face_down(cell: Vector2i) -> void:
	var deck: Array = players[current_player].deck
	if deck.is_empty():
		action_label.text = "Колода пуста."
		return

	var unit: Resource = deck[deck.size() - 1]
	var card = {
		"unit": unit,
		"owner": current_player,
		"face_down": true
	}

	if not _can_play_card(card, cell):
		action_label.text = "Карту рубашкой можно класть только на пустую землю или свое существо в снабжении."
		return

	deck.pop_back()
	_place_card(card, cell)
	pending_count -= 1
	if pending_count <= 0:
		_after_successful_play(cell)
	else:
		_trim_stacks_and_hands()
		_refresh_ui()


func _after_successful_play(cell: Vector2i) -> void:
	if _get_base_owner(cell) == _opponent(current_player):
		game_over = true
		status_label.text = "%s победил: существо разыграно на базу соперника." % players[current_player].name
		_clear_pending()
		_refresh_ui()
		return

	_trim_stacks_and_hands()
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
	if game_over:
		_refresh_ui()
		return
	_clear_pending()
	current_player = _opponent(current_player)
	_refresh_ui()


func _clear_pending() -> void:
	pending_action = ""
	pending_count = 0
	selected_hand_index = -1


func _can_start_action() -> bool:
	return not game_over and pending_action == ""


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
			if _top_owner(next) == player_index and not _top_face_down(next):
				queue.append(next)

	return supplied


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
	draw_two_button.disabled = not enabled
	deck_two_button.disabled = not enabled
	draw_deck_button.disabled = not enabled
	end_turn_button.disabled = game_over
