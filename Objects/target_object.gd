extends Node2D

# This function is called by the NPC
# It MUST be a coroutine (using await) so the NPC knows when it finishes
func animate_smart_object(action_type: String, data: Array) -> bool:
	print("Object ", name, " starting action: ", action_type, " with data: ", data)
	
	# 1. Trigger your visual/sound effects here
	# For example: $AnimationPlayer.play(action_type)
	
	# 2. Simulate the action taking time (e.g., 2 seconds)
	# This 'pauses' this function, which in turn keeps the NPC waiting
	await get_tree().create_timer(2.0).timeout
	
	# 3. Determine if the action was successful
	# You can add logic here to check if the NPC has the right items, etc.
	var success = true 
	
	print("Object ", name, " finished action. Result: ", success)
	return success
