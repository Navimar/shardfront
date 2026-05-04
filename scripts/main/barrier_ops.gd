extends RefCounted


var topology: RefCounted


func _init(board_topology: RefCounted) -> void:
	topology = board_topology


func has_barrier(state: Dictionary, first: Vector2i, second: Vector2i) -> bool:
	return state.barriers.has(topology.edge_key(first, second))


func add_barrier(state: Dictionary, first: Vector2i, second: Vector2i) -> void:
	state.barriers[topology.edge_key(first, second)] = true


func remove_barrier(state: Dictionary, first: Vector2i, second: Vector2i) -> void:
	state.barriers.erase(topology.edge_key(first, second))


func get_barrier_edges(state: Dictionary) -> Array:
	var result: Array = []
	for edge in topology.get_all_edges():
		if has_barrier(state, edge[0], edge[1]):
			result.append(edge)
	return result
