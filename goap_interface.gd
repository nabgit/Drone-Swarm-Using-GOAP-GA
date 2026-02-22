extends Node
class_name GOAPInterface

var weights: Dictionary = {}

#{"extinguish_nearest": 10.0, "extinguish_oldest": 2.0}
func _init(action_weights: Dictionary = {}):
	weights = action_weights
	
func get_burning_forests() -> Array:
	var all_forests = get_tree().get_nodes_in_group("forest")
	var burning = []
	for f in all_forests:
		if f.get("is_on_fire"): # Safe check for the property
			burning.append(f)
	return burning

func get_nearest_burning(npc: Node2D) -> Node2D:
	var burning = get_burning_forests()
	var nearest = null
	var min_dist = INF
	for f in burning:
		var dist = npc.global_position.distance_to(f.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = f
	return nearest

func get_next_plan(npc_has_water: bool, npc_node: Node2D) -> Dictionary:
	var potential_actions = []
	
	if npc_has_water:
		var burning = get_burning_forests()
		
		# Add Fire Actions only if there are burning forests
		if not burning.is_empty():
			potential_actions.append({"action": "extinguish_nearest", "target": get_nearest_burning(npc_node)})
			potential_actions.append({"action": "extinguish_newest", "target": burning[-1]})
			potential_actions.append({"action": "extinguish_oldest", "target": burning[0]})
		
		# Add Drone Support
		var drone = get_nearest_in_group(npc_node, "drones") # Assuming drones group exists
		if drone and drone != npc_node: # Don't assist yourself
			potential_actions.append({"action": "assist_drone", "target": drone})
	else:
		# Refill Actions
		potential_actions.append({"action": "refill_nearest", "target": get_nearest_in_group(npc_node, "water_station")})
		potential_actions.append({"action": "refill_furthest", "target": get_furthest_in_group(npc_node, "water_station")})

	# If no burning forests and no drones to assist, the NPC might have nothing to do
	if potential_actions.is_empty():
		return {}

	return select_weighted_action(potential_actions)

func get_nearest_in_group(npc: Node2D, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var nearest_node = null
	var min_dist = INF
	for node in nodes:
		var dist = npc.global_position.distance_to(node.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_node = node
	return nearest_node

func get_furthest_in_group(npc: Node2D, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var furthest_node = null
	var max_dist = -1.0
	for node in nodes:
		var dist = npc.global_position.distance_to(node.global_position)
		if dist > max_dist:
			max_dist = dist
			furthest_node = node
	return furthest_node

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
	
	return actions[0]
