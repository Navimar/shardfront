extends RefCounted


var topology: RefCounted
var barriers: RefCounted
var grid_width: int:
	get:
		return int(topology.grid_width)
var grid_height: int:
	get:
		return int(topology.grid_height)
var player_count: int = 2


func _init(board_topology: RefCounted, barrier_ops: RefCounted, players_count: int = 2) -> void:
	topology = board_topology
	barriers = barrier_ops
	player_count = players_count


func is_inside(cell: Vector2i) -> bool:
	return topology.is_inside(cell)


func are_neighbors(first: Vector2i, second: Vector2i) -> bool:
	return topology.are_neighbors(first, second)


func get_neighbors(cell: Vector2i) -> Array:
	return topology.get_neighbors(cell)


func opponent(player_index: int) -> int:
	return (player_index + 1) % player_count


func get_cell_stack(state: Dictionary, cell: Vector2i) -> Array:
	return state.board[cell.y][cell.x]


func top_owner(state: Dictionary, cell: Vector2i) -> int:
	var stack: Array = get_cell_stack(state, cell)
	if stack.is_empty():
		return -1
	return int(stack[stack.size() - 1].owner)


func top_name_key(state: Dictionary, cell: Vector2i) -> String:
	var stack: Array = get_cell_stack(state, cell)
	if stack.is_empty():
		return ""
	var card: Dictionary = stack[stack.size() - 1]
	if bool(card.face_down):
		return ""
	return String(card.unit.name_key)


func has_barrier(state: Dictionary, first: Vector2i, second: Vector2i) -> bool:
	return barriers.has_barrier(state, first, second)


func edge_key(first_cell: Vector2i, second_cell: Vector2i) -> String:
	return topology.edge_key(first_cell, second_cell)
