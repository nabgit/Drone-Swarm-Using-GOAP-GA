extends Node
class_name GOAPInterface

# Finds the nearest Node2D in a specific group relative to the NPC
func get_nearest_in_group(npc: Node2D, group_name: String) -> Node2D:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var nearest_node = null
	var min_dist = INF
	
	for node in nodes:
		# distance_to works on Vector2 for 2D positions
		var dist = npc.global_position.distance_to(node.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_node = node
	return nearest_node

func get_next_plan(npc_has_water: bool, npc_node: Node2D) -> Dictionary:
	if npc_has_water:
		var target = get_nearest_in_group(npc_node, "forest")
		return {
			"target": target,
			"action": "water_plants",
			"data": ["heavy_pour"]
		}
	else:
		var target = get_nearest_in_group(npc_node, "water_station")
		return {
			"target": target,
			"action": "refill",
			"data": []
		}
