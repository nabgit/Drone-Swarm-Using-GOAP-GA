extends Node2D

var grid_coord: Vector2i = Vector2i(-1, -1)

func animate_smart_object(action_type: String, data: Array) -> bool:
	print("Object ", name, " starting action: ", action_type, " with data: ", data)
	
	await get_tree().create_timer(2.0).timeout
	
	var success = true 
	
	print("Object ", name, " finished action. Result: ", success)
	return success
