extends Node
class_name GOAPInterface

var weights: Dictionary = {}
var grid_manager: GridManager = null

func _init(action_weights: Dictionary = {}):
	weights = action_weights

func set_grid_manager(gm: GridManager):
	grid_manager = gm

# --- Burning forest queries ---

func get_burning_forests() -> Array:
	var all_forests = get_tree().get_nodes_in_group("forest")
	var burning = []
	for f in all_forests:
		if f.get("is_on_fire") and not f.get("is_dead"):
			burning.append(f)
	return burning

func get_nearest_burning(npc: Node2D) -> Node2D:
	var burning = get_burning_forests()
	var nearest = null
	var min_dist = INF
	for f in burning:
		var dist = _grid_distance(npc, f)
		if dist < min_dist:
			min_dist = dist
			nearest = f
	return nearest

func get_oldest_burning() -> Node2D:
	var burning = get_burning_forests()
	var oldest = null
	var max_timer := -1
	for f in burning:
		var bt: int = f.get("burn_timer") if f.get("burn_timer") != null else 0
		if bt > max_timer:
			max_timer = bt
			oldest = f
	return oldest

func get_newest_burning() -> Node2D:
	var burning = get_burning_forests()
	var newest = null
	var min_timer := 999999
	for f in burning:
		var bt: int = f.get("burn_timer") if f.get("burn_timer") != null else 999999
		if bt < min_timer:
			min_timer = bt
			newest = f
	return newest

func get_smallest_burning(npc: Node2D) -> Node2D:
	# "Easiest to contain" — low burn timer AND few burning neighbours.
	# Score = burn_timer + (burning_neighbours * 20). Lowest score wins.
	var burning = get_burning_forests()
	var best = null
	var best_score := INF
	for f in burning:
		var bt: int = f.get("burn_timer") if f.get("burn_timer") != null else 999999
		var neighbours := _count_burning_neighbours(f)
		var score: float = float(bt) + float(neighbours) * 20.0
		if score < best_score:
			best_score = score
			best = f
	return best

func get_highest_spread_burning() -> Node2D:
	# Fire with most burning neighbours — spreading fastest, highest priority to contain
	var burning = get_burning_forests()
	var best = null
	var max_neighbours := -1
	for f in burning:
		var n := _count_burning_neighbours(f)
		if n > max_neighbours:
			max_neighbours = n
			best = f
	return best

func get_isolated_burning() -> Node2D:
	# Fire with fewest burning neighbours — easiest to cut off and finish
	var burning = get_burning_forests()
	var best = null
	var min_neighbours := 999999
	for f in burning:
		var n := _count_burning_neighbours(f)
		if n < min_neighbours:
			min_neighbours = n
			best = f
	return best

func get_burning_near_water(npc: Node2D) -> Node2D:
	# Fire closest to any water station — quick extinguish and refill cycle
	var burning = get_burning_forests()
	var water_stations = get_tree().get_nodes_in_group("water_station")
	var best = null
	var min_score = INF
	for f in burning:
		var min_ws_dist = INF
		for ws in water_stations:
			var d = _grid_distance(f, ws)
			if d < min_ws_dist:
				min_ws_dist = d
		if min_ws_dist < min_score:
			min_score = min_ws_dist
			best = f
	return best

func get_unburned_near_fire(npc: Node2D) -> Node2D:
	# Unburned cell adjacent to fire — intercept spread before it reaches it
	var all_forests = get_tree().get_nodes_in_group("forest")
	var burning = get_burning_forests()
	if burning.is_empty():
		return null
	var best_target = null
	var best_score = INF
	for f in all_forests:
		if f.get("is_on_fire") or f.get("is_dead"):
			continue
		var min_fire_dist = INF
		for b in burning:
			var d = _grid_distance(f, b)
			if d < min_fire_dist:
				min_fire_dist = d
		if min_fire_dist <= 2.0:
			var drone_dist = _grid_distance(npc, f)
			if drone_dist < best_score:
				best_score = drone_dist
				best_target = f
	return best_target

# --- Helper ---

func _count_burning_neighbours(cell: Node2D) -> int:
	if grid_manager == null:
		return 0
	var count := 0
	var coord: Vector2i = cell.get("grid_coord") if cell.get("grid_coord") != null else Vector2i.ZERO
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var neighbour = grid_manager.get_cell_at(Vector2i(coord.x + dx, coord.y + dy))
			if neighbour and neighbour.get("is_on_fire"):
				count += 1
	return count

# --- Planning ---

func get_next_plan(npc_has_water: bool, npc_node: Node2D) -> Dictionary:
	var potential_actions = []

	if npc_has_water:
		var burning = get_burning_forests()

		if not burning.is_empty():
			var nearest = get_nearest_burning(npc_node)
			if nearest:
				potential_actions.append({"action": "extinguish_nearest", "target": nearest})

			var newest = get_newest_burning()
			if newest:
				potential_actions.append({"action": "extinguish_newest", "target": newest})

			var oldest = get_oldest_burning()
			if oldest:
				potential_actions.append({"action": "extinguish_oldest", "target": oldest})

			var smallest = get_smallest_burning(npc_node)
			if smallest:
				potential_actions.append({"action": "extinguish_smallest", "target": smallest})

			var high_spread = get_highest_spread_burning()
			if high_spread:
				potential_actions.append({"action": "extinguish_high_spread", "target": high_spread})

			var isolated = get_isolated_burning()
			if isolated:
				potential_actions.append({"action": "extinguish_isolated", "target": isolated})

			var near_water = get_burning_near_water(npc_node)
			if near_water:
				potential_actions.append({"action": "extinguish_near_water", "target": near_water})

		# Patrol unburned — available even when fires exist
		var patrol_target = get_unburned_near_fire(npc_node)
		if patrol_target:
			potential_actions.append({"action": "patrol_unburned", "target": patrol_target})

		# Assist another drone that is extinguishing
		var assist_target = _get_assist_target(npc_node)
		if assist_target:
			potential_actions.append({"action": "assist_drone", "target": assist_target})

		# Refill if already close to a water station
		var nearest_ws = get_nearest_in_group(npc_node, "water_station")
		if nearest_ws and _grid_distance(npc_node, nearest_ws) <= 3.0:
			potential_actions.append({"action": "refill_if_nearby", "target": nearest_ws})

	else:
		var nearest_ws = get_nearest_in_group(npc_node, "water_station")
		if nearest_ws:
			potential_actions.append({"action": "refill_nearest", "target": nearest_ws})
		var furthest_ws = get_furthest_in_group(npc_node, "water_station")
		if furthest_ws:
			potential_actions.append({"action": "refill_furthest", "target": furthest_ws})

	if potential_actions.is_empty():
		var fallback_target = get_nearest_in_group(npc_node, "water_station")
		if fallback_target:
			return {"target": fallback_target, "action": "refill_nearest", "data": []}
		return {"target": null, "action": "idle", "data": []}

	return select_weighted_action(potential_actions)

func _get_assist_target(npc_node: Node2D) -> Node2D:
	var drones = get_tree().get_nodes_in_group("drones")
	for drone in drones:
		if drone == npc_node:
			continue
		if drone.get("current_state") == 2:  # State.EXTINGUISHING
			var target = drone.get("current_target_object")
			if target and target.get("is_on_fire"):
				return target
	return null

func get_nearest_in_group(npc: Node2D, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var nearest_node = null
	var min_dist = INF
	for node in nodes:
		var dist = _grid_distance(npc, node)
		if dist < min_dist:
			min_dist = dist
			nearest_node = node
	return nearest_node

func get_furthest_in_group(npc: Node2D, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var furthest_node = null
	var max_dist = -1.0
	for node in nodes:
		var dist = _grid_distance(npc, node)
		if dist > max_dist:
			max_dist = dist
			furthest_node = node
	return furthest_node

func _grid_distance(a: Node2D, b: Node2D) -> float:
	var a_coord: Vector2i = a.get("grid_coord") if a.get("grid_coord") != null else Vector2i.ZERO
	var b_coord: Vector2i = b.get("grid_coord") if b.get("grid_coord") != null else Vector2i.ZERO
	return float(maxi(absi(a_coord.x - b_coord.x), absi(a_coord.y - b_coord.y)))

func select_weighted_action(actions: Array) -> Dictionary:
	if actions.is_empty(): return {}
	var total_weight = 0.0
	for a in actions:
		total_weight += weights.get(a.action, 1.0)
	var roll = randf() * total_weight
	var cursor = 0.0
	for a in actions:
		cursor += weights.get(a.action, 1.0)
		if roll <= cursor:
			return {"target": a.target, "action": a.action, "data": []}
	return {"target": actions[0].target, "action": actions[0].action, "data": []}
