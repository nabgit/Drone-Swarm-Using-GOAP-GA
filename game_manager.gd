extends Node

const ROUND_DURATION := 45.0
const NUM_FIRES_PER_ROUND := 4
const NUM_GENERATIONS := 10

var generation := 0
var round_timer := 0.0
var round_active := false

var drones: Array = []
var drone_start_positions: Array = []

@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"

# Seed parents for generation 0.
var alpha_parent := {
	"extinguish_nearest": 1.0, "extinguish_newest": 1.0, "extinguish_oldest": 1.0,
	"assist_drone": 1.0, "refill_nearest": 1.0, "refill_furthest": 1.0
}
var beta_parent := {
	"extinguish_nearest": 2.0, "extinguish_newest": 0.5, "extinguish_oldest": 0.5,
	"assist_drone": 0.3, "refill_nearest": 2.0, "refill_furthest": 0.2
}


func _ready():
	drones = get_tree().get_nodes_in_group("drones")
	for drone in drones:
		drone_start_positions.append(drone.global_position)


func start_simulation():
	if round_active:
		return
	generation = 0
	print("=== Starting evolutionary run (%d generations, %.0fs rounds) ===" % [NUM_GENERATIONS, ROUND_DURATION])
	_start_generation_zero()


func _start_generation_zero():
	var weight_sets = GeneticAlgorithm.evolve(alpha_parent, beta_parent, drones.size())
	_begin_round(weight_sets)


func _begin_round(weight_sets: Array):
	_reset_world()
	_ignite_fires()

	for i in range(drones.size()):
		drones[i].reset_for_round()
		drones[i].initialize_goap(weight_sets[i])
		drones[i].start_simulation()

	round_timer = 0.0
	round_active = true
	print("--- Generation %d started ---" % generation)


func _process(delta):
	if not round_active:
		return

	round_timer += delta

	# End the round when all fires are out or time runs out.
	var all_out := true
	for f in get_tree().get_nodes_in_group("forest"):
		if f.get("is_on_fire"):
			all_out = false
			break

	if all_out or round_timer >= ROUND_DURATION:
		_end_round()


func _end_round():
	round_active = false

	for drone in drones:
		drone.stop_simulation()

	# Build population entries: weights + fitness.
	var population := []
	for drone in drones:
		var metrics = drone.get_metrics()
		var fitness = GeneticAlgorithm.compute_fitness(metrics)
		population.append({
			"weights": drone.get_weights(),
			"fitness": fitness,
		})

	GeneticAlgorithm.log_generation_stats(generation, population)
	generation += 1

	if generation >= NUM_GENERATIONS:
		print("=== Evolution complete after %d generations ===" % NUM_GENERATIONS)
		return

	# Evolve the next generation and start the next round after a brief pause.
	var next_weights = GeneticAlgorithm.evolve_from_population(population, drones.size())
	await get_tree().create_timer(1.5).timeout
	_begin_round(next_weights)


func _reset_world():
	# Return drones to starting positions.
	for i in range(drones.size()):
		drones[i].global_position = drone_start_positions[i]

	# Extinguish all fires and reset burn timers.
	for f in get_tree().get_nodes_in_group("forest"):
		f.is_on_fire = false
		f.burn_timer = 0.0


func _ignite_fires():
	var forests = get_tree().get_nodes_in_group("forest")
	var shuffled = forests.duplicate()
	shuffled.shuffle()
	var count = min(NUM_FIRES_PER_ROUND, shuffled.size())
	for i in range(count):
		shuffled[i].is_on_fire = true


func _on_button_pressed() -> void:
	start_simulation()
