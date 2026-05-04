extends RefCounted


var grid_width: int = 0
var grid_height: int = 0


func _init(width: int, height: int) -> void:
	grid_width = width
	grid_height = height


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height


func are_neighbors(first: Vector2i, second: Vector2i) -> bool:
	if not is_inside(first) or not is_inside(second):
		return false
	var diff: Vector2i = first - second
	return abs(diff.x) + abs(diff.y) == 1


func get_neighbors(cell: Vector2i) -> Array:
	var result: Array = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = cell + direction
		if is_inside(neighbor):
			result.append(neighbor)
	return result


func edge_key(first_cell: Vector2i, second_cell: Vector2i) -> String:
	var first: Vector2i = first_cell
	var second: Vector2i = second_cell
	if second.x < first.x or (second.x == first.x and second.y < first.y):
		first = second_cell
		second = first_cell
	return "%d,%d-%d,%d" % [first.x, first.y, second.x, second.y]


func get_all_edges() -> Array:
	var edges: Array = []
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: Vector2i = Vector2i(x, y)
			var right: Vector2i = cell + Vector2i.RIGHT
			if is_inside(right):
				edges.append([cell, right])

			var down: Vector2i = cell + Vector2i.DOWN
			if is_inside(down):
				edges.append([cell, down])
	return edges


func rotate_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(grid_width - 1 - cell.x, grid_height - 1 - cell.y)
