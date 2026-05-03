extends RefCounted

const PLAYABLE_SUPPLY_COLOR: Color = Color(0.88, 0.08, 0.06, 1.0)
const SPECIAL_PLAYABLE_COLOR: Color = Color(1.0, 0.82, 0.12, 1.0)
const ARROW_OUTLINE_COLOR: Color = Color(0.22, 0.03, 0.02, 1.0)
const BARRIER_FRAME_COLOR: Color = Color(0.02, 0.015, 0.01)
const BARRIER_SHINE_COLOR: Color = Color(1.0, 0.86, 0.48, 0.55)
const CONTESTED_SUPPLY_CONTROL_COLOR: Color = Color(1.0, 0.78, 0.08)

var game: Control
var displayed_supply_origin_cells: Dictionary = {}


func _init(game_node: Control) -> void:
	game = game_node


func queue_board_redraw() -> void:
	if game.supply_line_layer != null:
		game.supply_line_layer.queue_redraw()
	if game.barrier_layer != null:
		game.barrier_layer.queue_redraw()


func set_displayed_supply_origin_cells(cells_by_player: Dictionary) -> void:
	displayed_supply_origin_cells = cells_by_player.duplicate(true)
	queue_board_redraw()


func on_supply_line_layer_draw() -> void:
	_draw_supply_networks()
	_draw_board_grid_lines()
	var playable_cells: Dictionary = game._get_playable_cells_for_ui_pending_action()
	_draw_playable_supply_lines(playable_cells)
	_draw_special_playable_cells(playable_cells)


func on_barrier_layer_draw() -> void:
	var playable_cells: Dictionary = game._get_playable_cells_for_ui_pending_action()
	_draw_playable_arrow_heads(playable_cells)
	_draw_barriers()


func _draw_barriers() -> void:
	for y in range(game.GRID_HEIGHT):
		for x in range(game.GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var right: Vector2i = cell + Vector2i.RIGHT
			if game._is_inside(right) and game._has_barrier(cell, right):
				_draw_barrier_between(cell, right)

			var down: Vector2i = cell + Vector2i.DOWN
			if game._is_inside(down) and game._has_barrier(cell, down):
				_draw_barrier_between(cell, down)


func _draw_playable_supply_lines(playable_cells: Dictionary) -> void:
	if playable_cells.is_empty():
		return

	var origin_cells: Dictionary = game._get_supply_origin_cells(game.current_player)
	var supply_edges: Dictionary = game._get_supply_edges(game.current_player)
	var drawn_segments: Dictionary = {}
	for from_cell in supply_edges.keys():
		if not _should_draw_supply_network_cell(from_cell, origin_cells):
			continue
		var edges: Dictionary = supply_edges[from_cell]
		for to_cell in edges.keys():
			if _should_draw_supply_network_cell(to_cell, origin_cells):
				var segment_key: String = _get_undirected_segment_key(from_cell, to_cell)
				if drawn_segments.has(segment_key):
					continue
				drawn_segments[segment_key] = true
				_draw_playable_supply_segment(from_cell, to_cell, true, PLAYABLE_SUPPLY_COLOR)
	for cell in playable_cells.keys():
		for from_cell in _get_playable_source_cells(playable_cells[cell]):
			_draw_playable_supply_segment(from_cell, cell, false, _get_playable_access_color(playable_cells[cell]))


func _draw_special_playable_cells(playable_cells: Dictionary) -> void:
	for cell in playable_cells.keys():
		if _get_playable_access_kind(playable_cells[cell]) == "standard":
			continue
		var rect: Rect2 = _get_cell_rect_on_layer(cell, game.supply_line_layer)
		var marker_rect: Rect2 = rect.grow(-8.0)
		game.supply_line_layer.draw_rect(marker_rect, SPECIAL_PLAYABLE_COLOR, false, 5.0)


func _draw_board_grid_lines() -> void:
	if game.board_grid == null:
		return

	var layer_position: Vector2 = game.supply_line_layer.get_global_rect().position
	var board_rect: Rect2 = game.board_grid.get_global_rect()
	var board_position: Vector2 = board_rect.position - layer_position
	var board_size: Vector2 = board_rect.size

	for x in range(game.GRID_WIDTH + 1):
		var line_x: float = board_position.x
		if x == game.GRID_WIDTH:
			line_x += board_size.x
		elif x > 0:
			line_x += float(x * game.CELL_SIZE) + (float(x) - 0.5) * float(game.CELL_GAP)
		_draw_sketch_grid_line(
			Vector2(line_x, board_position.y),
			Vector2(line_x, board_position.y + board_size.y),
			x
		)

	for y in range(game.GRID_HEIGHT + 1):
		var line_y: float = board_position.y
		if y == game.GRID_HEIGHT:
			line_y += board_size.y
		elif y > 0:
			line_y += float(y * game.CELL_SIZE) + (float(y) - 0.5) * float(game.CELL_GAP)
		_draw_sketch_grid_line(
			Vector2(board_position.x, line_y),
			Vector2(board_position.x + board_size.x, line_y),
			100 + y
		)


func _draw_sketch_grid_line(start: Vector2, end: Vector2, line_seed: int) -> void:
	var direction: Vector2 = (end - start).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)

	for stroke_index in range(game.BOARD_GRID_SKETCH_STROKES):
		var stroke_offset: float = (float(stroke_index) - 1.0) * 0.42
		for segment_index in range(game.BOARD_GRID_SKETCH_SEGMENTS):
			var noise_seed: int = line_seed * 1000 + stroke_index * 100 + segment_index
			if _grid_line_noise(noise_seed) < 0.12:
				continue

			var t0: float = float(segment_index) / float(game.BOARD_GRID_SKETCH_SEGMENTS)
			var t1: float = float(segment_index + 1) / float(game.BOARD_GRID_SKETCH_SEGMENTS)
			t0 += _grid_line_noise(noise_seed + 17) * 0.012
			t1 -= _grid_line_noise(noise_seed + 31) * 0.012
			if t0 >= t1:
				continue

			var start_jitter: float = (_grid_line_noise(noise_seed + 43) - 0.5) * game.BOARD_GRID_SKETCH_JITTER + stroke_offset
			var end_jitter: float = (_grid_line_noise(noise_seed + 59) - 0.5) * game.BOARD_GRID_SKETCH_JITTER + stroke_offset
			var from_point: Vector2 = start.lerp(end, t0) + side * start_jitter
			var to_point: Vector2 = start.lerp(end, t1) + side * end_jitter
			var color: Color = game.BOARD_GRID_LINE_COLOR
			color.a *= 0.45 + _grid_line_noise(noise_seed + 71) * 0.55
			var width: float = game.BOARD_GRID_LINE_WIDTH + _grid_line_noise(noise_seed + 83) * 0.35
			game.supply_line_layer.draw_line(from_point, to_point, color, width)


func _grid_line_noise(seed: int) -> float:
	return fposmod(sin(float(seed) * 12.9898) * 43758.5453, 1.0)


func _draw_playable_arrow_heads(playable_cells: Dictionary) -> void:
	if playable_cells.is_empty():
		return

	var origin_cells: Dictionary = game._get_supply_origin_cells(game.current_player)
	var supply_edges: Dictionary = game._get_supply_edges(game.current_player)
	for from_cell in supply_edges.keys():
		if not _should_draw_supply_network_cell(from_cell, origin_cells):
			continue
		var edges: Dictionary = supply_edges[from_cell]
		for to_cell in edges.keys():
			if playable_cells.has(to_cell) and not origin_cells.has(to_cell) and _has_playable_source(playable_cells[to_cell], from_cell):
				_draw_playable_arrow_head_between(from_cell, to_cell, playable_cells, _get_playable_access_color(playable_cells[to_cell]))
	for cell in playable_cells.keys():
		for from_cell in _get_playable_source_cells(playable_cells[cell]):
			if supply_edges.get(from_cell, {}).has(cell):
				continue
			_draw_playable_arrow_head_between(from_cell, cell, playable_cells, _get_playable_access_color(playable_cells[cell]))


func _draw_playable_arrow_head_between(
	from_cell: Vector2i,
	to_cell: Vector2i,
	playable_cells: Dictionary,
	color: Color = PLAYABLE_SUPPLY_COLOR
) -> void:
	if not game._is_inside(to_cell):
		return
	if not playable_cells.has(to_cell):
		return
	var from_rect: Rect2 = _get_cell_rect_on_layer(from_cell, game.barrier_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(to_cell, game.barrier_layer)
	var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
	var tip: Vector2 = _get_rect_edge_point(to_rect, -direction) + direction * 10.0
	_draw_arrow_head(tip, direction, color, game.PLAYABLE_SUPPLY_PIPE_WIDTH)


func _draw_supply_networks() -> void:
	if not game.supply_control_transition.is_empty():
		_draw_supply_control_transition()
		return
	_draw_supply_origin_cells(displayed_supply_origin_cells)


func _draw_supply_origin_cells(origin_cells_by_player: Dictionary) -> void:
	var cells: Dictionary = _get_supply_cell_union(origin_cells_by_player)
	for cell in cells.keys():
		var color: Color = _get_supply_origin_cell_color(origin_cells_by_player, cell)
		if color.a <= 0.01:
			continue
		_draw_supply_control_cell(cell, color)


func _get_supply_cell_union(cells_by_player: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for player_index in cells_by_player.keys():
		for cell in Dictionary(cells_by_player[player_index]).keys():
			cells[cell] = true
	return cells


func _draw_supply_control_transition() -> void:
	var from_cells_by_player: Dictionary = game.supply_control_transition.get("from_cells", {})
	var to_cells_by_player: Dictionary = game.supply_control_transition.get("to_cells", {})
	var cells: Dictionary = _get_supply_cell_union(from_cells_by_player)
	for cell in _get_supply_cell_union(to_cells_by_player).keys():
		cells[cell] = true

	for cell in cells.keys():
		var from_color: Color = _get_supply_origin_cell_color(from_cells_by_player, cell)
		var to_color: Color = _get_supply_origin_cell_color(to_cells_by_player, cell)
		var color: Color = from_color.lerp(to_color, game.supply_control_transition_progress)
		if color.a <= 0.01:
			continue
		_draw_supply_control_cell(cell, color)


func _get_supply_origin_cell_color(origin_cells_by_player: Dictionary, cell: Vector2i) -> Color:
	var origin_owners: Array = _get_cell_owners(origin_cells_by_player, cell)
	if origin_owners.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var color: Color
	if origin_owners.size() > 1:
		color = CONTESTED_SUPPLY_CONTROL_COLOR
	else:
		color = game._get_player_card_color(int(origin_owners[0])).darkened(game.SUPPLY_CONTROL_DARKEN_AMOUNT)
	color.a = game.SUPPLY_CONTROL_ALPHA
	return color


func _get_cell_owners(cells_by_player: Dictionary, cell: Vector2i) -> Array:
	var owners: Array = []
	for player_index in cells_by_player.keys():
		var cells: Dictionary = cells_by_player[player_index]
		if cells.has(cell):
			owners.append(int(player_index))
	return owners


func _draw_supply_control_cell(cell: Vector2i, color: Color) -> void:
	var rect: Rect2 = _get_cell_rect_on_layer(cell, game.supply_line_layer)
	var half_gap: float = float(game.CELL_GAP) * 0.5
	var expanded_rect: Rect2 = rect.grow(half_gap)
	game.supply_line_layer.draw_rect(expanded_rect, color)


func _should_draw_supply_network_cell(cell: Vector2i, origin_cells: Dictionary) -> bool:
	return origin_cells.has(cell)


func _get_playable_access_kind(playable_info) -> String:
	if playable_info is Dictionary:
		return String(playable_info.get("kind", "standard"))
	return String(playable_info)


func _get_playable_source_cells(playable_info) -> Array:
	if playable_info is Dictionary:
		return Array(playable_info.get("sources", []))
	return []


func _get_playable_access_color(playable_info) -> Color:
	if _get_playable_access_kind(playable_info) == "standard":
		return PLAYABLE_SUPPLY_COLOR
	return SPECIAL_PLAYABLE_COLOR


func _has_playable_source(playable_info, source_cell: Vector2i) -> bool:
	for cell in _get_playable_source_cells(playable_info):
		if cell == source_cell:
			return true
	return false


func _get_undirected_segment_key(from_cell: Vector2i, to_cell: Vector2i) -> String:
	var first: Vector2i = from_cell
	var second: Vector2i = to_cell
	if _is_cell_after(first, second):
		first = to_cell
		second = from_cell
	return "%d,%d:%d,%d" % [first.x, first.y, second.x, second.y]


func _is_cell_after(first: Vector2i, second: Vector2i) -> bool:
	if first.y != second.y:
		return first.y > second.y
	return first.x > second.x


func _draw_playable_supply_segment(from_cell: Vector2i, to_cell: Vector2i, center_to_center: bool, color: Color) -> void:
	var from_rect: Rect2 = _get_cell_rect_on_layer(from_cell, game.supply_line_layer)
	var to_rect: Rect2 = _get_cell_rect_on_layer(to_cell, game.supply_line_layer)
	var direction: Vector2 = (to_rect.get_center() - from_rect.get_center()).normalized()
	var segment_end: Vector2 = to_rect.get_center()
	if not center_to_center:
		segment_end = _get_rect_edge_point(to_rect, -direction)
	game.supply_line_layer.draw_line(from_rect.get_center(), segment_end, color, game.PLAYABLE_SUPPLY_PIPE_WIDTH, true)


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color, width: float) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var length: float = 21.0
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
	game.barrier_layer.draw_colored_polygon(outline_points, ARROW_OUTLINE_COLOR)
	game.barrier_layer.draw_colored_polygon(points, color)


func _get_cell_rect_on_layer(cell: Vector2i, layer: Control) -> Rect2:
	var cell_panel: Control = game.board_cells[cell]
	var layer_position: Vector2 = layer.get_global_rect().position
	var cell_rect: Rect2 = cell_panel.get_global_rect()
	return Rect2(cell_rect.position - layer_position, cell_rect.size)


func _get_rect_edge_point(rect: Rect2, direction: Vector2) -> Vector2:
	var center: Vector2 = rect.get_center()
	if abs(abs(direction.x) - abs(direction.y)) < 0.001:
		var corner_x: float = rect.position.x
		var corner_y: float = rect.position.y
		if direction.x > 0.0:
			corner_x += rect.size.x
		if direction.y > 0.0:
			corner_y += rect.size.y
		return Vector2(corner_x, corner_y)
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			return Vector2(rect.position.x + rect.size.x, center.y)
		return Vector2(rect.position.x, center.y)

	if direction.y > 0.0:
		return Vector2(center.x, rect.position.y + rect.size.y)
	return Vector2(center.x, rect.position.y)


func _draw_barrier_between(first: Vector2i, second: Vector2i) -> void:
	var first_panel: Control = game.board_cells[first]
	var second_panel: Control = game.board_cells[second]
	var first_rect: Rect2 = first_panel.get_global_rect()
	var second_rect: Rect2 = second_panel.get_global_rect()
	var layer_position: Vector2 = game.barrier_layer.get_global_rect().position
	var thickness: float = 18.0
	var frame_width: float = 3.0
	var inset: float = 9.0
	var fill_color: Color = game.BARRIER_FILL_COLOR

	if first.y == second.y:
		var center_x: float = ((first_rect.position.x + first_rect.size.x) + second_rect.position.x) * 0.5 - layer_position.x
		var top_y: float = max(first_rect.position.y, second_rect.position.y) + inset - layer_position.y
		var height: float = min(first_rect.size.y, second_rect.size.y) - inset * 2.0
		var outer_rect: Rect2 = Rect2(center_x - thickness * 0.5, top_y, thickness, height)
		var inner_rect: Rect2 = outer_rect.grow(-frame_width)
		game.barrier_layer.draw_rect(outer_rect, BARRIER_FRAME_COLOR)
		game.barrier_layer.draw_rect(inner_rect, fill_color)
		game.barrier_layer.draw_rect(Rect2(inner_rect.position.x + frame_width, inner_rect.position.y, frame_width, inner_rect.size.y), BARRIER_SHINE_COLOR)
	else:
		var center_y: float = ((first_rect.position.y + first_rect.size.y) + second_rect.position.y) * 0.5 - layer_position.y
		var left_x: float = max(first_rect.position.x, second_rect.position.x) + inset - layer_position.x
		var width: float = min(first_rect.size.x, second_rect.size.x) - inset * 2.0
		var outer_rect: Rect2 = Rect2(left_x, center_y - thickness * 0.5, width, thickness)
		var inner_rect: Rect2 = outer_rect.grow(-frame_width)
		game.barrier_layer.draw_rect(outer_rect, BARRIER_FRAME_COLOR)
		game.barrier_layer.draw_rect(inner_rect, fill_color)
		game.barrier_layer.draw_rect(Rect2(inner_rect.position.x, inner_rect.position.y + frame_width, inner_rect.size.x, frame_width), BARRIER_SHINE_COLOR)
