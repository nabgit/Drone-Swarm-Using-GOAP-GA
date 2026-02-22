extends Node2D

@export var is_on_fire: bool = false # Manually toggle in Inspector for testing

func animate_smart_object(action_type: String, data: Array) -> bool:
	print("Object ", name, " starting action: ", action_type, " with data: ", data)
	
	await get_tree().create_timer(2.0).timeout
	
	var success = true 
	
	# Logic: If we are extinguishing, put the fire out on success
	if success and action_type.begins_with("extinguish"):
		is_on_fire = false
	
	print("Object ", name, " finished action. Result: ", success)
	return success
