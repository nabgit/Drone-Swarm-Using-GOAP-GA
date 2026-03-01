class_name GridManager
extends Node

const GRID_SIZE := 10
const BURN_DEATH_TIME := 100
const SPREAD_CHECK_INTERVAL := 10
const DEPLOYMENT_THRESHOLD := 0.10

# cells[col][row] holds the scene node at that grid position.
var cells: Array = []
var grid_origin := Vector2.ZERO
var cell_size := Vector2.ZERO
var total_forest := 0


func initialize(forests: Array, water_stations: Array) -> void:
	# Find corner water stations to determine grid geometry.
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for ws in water_stations:
		min_x = minf(min_x, ws.position.x)
		min_y = minf(min_y, ws.position.y)
		max_x = maxf(max_x, ws.position.x)
		max_y = maxf(max_y, ws.position.y)

	grid_origin = Vector2(min_x, min_y)
	cell_size = Vector2(
		(max_x - min_x) / float(GRID_SIZE - 1),
		(max_y - min_y) / float(GRID_SIZE - 1)
	)

	# Initialize empty grid.
	cells = []
	for col in range(GRID_SIZE):
		var column: Array = []
		column.resize(GRID_SIZE)
		cells.append(column)

	# Place all nodes on the grid.
	var all_nodes: Array = forests.duplicate()
	all_nodes.append_array(water_stations)

	for node in all_nodes:
		var gp := world_to_grid(node.position)
		gp.x = clampi(gp.x, 0, GRID_SIZE - 1)
		gp.y = clampi(gp.y, 0, GRID_SIZE - 1)
		cells[gp.x][gp.y] = node
		node.grid_coord = gp

	total_forest = forests.size()
	print("GridManager: Initialized %dx%d grid. Origin=%s, CellSize=%s, Forests=%d" % [
		GRID_SIZE, GRID_SIZE, grid_origin, cell_size, total_forest])


func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(
		roundi((pos.x - grid_origin.x) / cell_size.x),
		roundi((pos.y - grid_origin.y) / cell_size.y)
	)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_origin.x + grid_pos.x * cell_size.x,
		grid_origin.y + grid_pos.y * cell_size.y
	)


func get_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n := cell + offset
		if n.x >= 0 and n.x < GRID_SIZE and n.y >= 0 and n.y < GRID_SIZE:
			neighbors.append(n)
	return neighbors


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]

	var visited := {}
	var parent := {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	while not queue.is_empty():
		var current := queue.pop_front() as Vector2i
		if current == to:
			# Reconstruct path.
			var path: Array[Vector2i] = []
			var step := to
			while step != from:
				path.push_front(step)
				step = parent[step]
			path.push_front(from)
			return path

		for neighbor in get_adjacent_cells(current):
			if not visited.has(neighbor):
				visited[neighbor] = true
				parent[neighbor] = current
				queue.append(neighbor)

	# No path found (shouldn't happen on full 10x10 grid).
	return []


func tick_fire() -> void:
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE):
			var node = cells[col][row]
			if node == null:
				continue
			if not node.get("is_on_fire"):
				continue
			if node.get("is_dead"):
				continue

			node.burn_timer += 1

			if node.burn_timer >= BURN_DEATH_TIME:
				node.kill()
				continue

			if node.burn_timer % SPREAD_CHECK_INTERVAL == 0:
				_attempt_spread(Vector2i(col, row), node.burn_timer)


func _attempt_spread(cell: Vector2i, burn_time: int) -> void:
	var probability := burn_time / 100.0
	var neighbors := get_adjacent_cells(cell)

	# Collect valid spread candidates.
	var candidates: Array[Vector2i] = []
	for n in neighbors:
		var node = cells[n.x][n.y]
		if node == null:
			continue
		if node.get("is_on_fire") or node.get("is_dead"):
			continue
		if node.is_in_group("forest"):
			candidates.append(n)

	if candidates.is_empty():
		return

	# Pick one random candidate and roll.
	var target_pos: Vector2i = candidates[randi() % candidates.size()]
	if randf() < probability:
		var target_node = cells[target_pos.x][target_pos.y]
		target_node.is_on_fire = true


func should_deploy_drones() -> bool:
	var burning_or_dead := 0
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE):
			var node = cells[col][row]
			if node == null:
				continue
			if not node.is_in_group("forest"):
				continue
			if node.get("is_on_fire") or node.get("is_dead"):
				burning_or_dead += 1
	return float(burning_or_dead) / float(total_forest) >= DEPLOYMENT_THRESHOLD


func get_burning_cells() -> Array:
	var burning: Array = []
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE):
			var node = cells[col][row]
			if node == null:
				continue
			if node.get("is_on_fire") and not node.get("is_dead"):
				burning.append(node)
	return burning


func get_forest_alive_count() -> int:
	var count := 0
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE):
			var node = cells[col][row]
			if node == null:
				continue
			if not node.is_in_group("forest"):
				continue
			if not node.get("is_dead"):
				count += 1
	return count


func reset() -> void:
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE):
			var node = cells[col][row]
			if node == null:
				continue
			if node.is_in_group("forest") and node.has_method("reset"):
				node.reset()
