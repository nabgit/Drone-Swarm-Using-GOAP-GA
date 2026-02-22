extends Node

var simulation_started = false
var timer = 0

var drones: Array = []

@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"

func start_simulation():
	drones = get_tree().get_nodes_in_group("drones")
	
	if drones.is_empty():
		print("ERROR: No drones found in 'drones' group!")
		return

	var alpha_parent = {
		"extinguish_nearest": 1.0, "extinguish_newest": 1.0, "extinguish_oldest": 1.0,
		"assist_drone": 1.0, "refill_nearest": 1.0, "refill_furthest": 1.0
	}
	var beta_parent = {
		"extinguish_nearest": 1.0, "extinguish_newest": 1.0, "extinguish_oldest": 1.0,
		"assist_drone": 1.0, "refill_nearest": 1.0, "refill_furthest": 1.0
	}
	
	var new_populations = GeneticAlgorithm.evolve(alpha_parent, beta_parent, drones.size())
	
	for i in range(drones.size()):
		var drone = drones[i]
		drone.initialize_goap(new_populations[i])
		drone.start_simulation()
	
	simulation_started = true


func _on_button_pressed() -> void:
	start_simulation()
