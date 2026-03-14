extends Node

const ROUND_DURATION_TICKS := 600  # 10 minutes max per round
const NUM_FIRES_PER_ROUND := 4
const NUM_GENERATIONS := 100
const TICK_INTERVAL := 1.0  # 1 second per tick

## Set > 1 to fast-forward (e.g. 50 = 50x speed). Set to 0 for uncapped (run as fast as possible).
const SIMULATION_SPEED := 100.0  # 1 = real-time, >1 = fast-forward, 0 = uncapped

var generation := 0
var tick_count := 0
var tick_accumulator := 0.0
var round_active := false
var drones_deployed := false

var drones: Array = []
var drone_home_stations: Array = []  # Nearest water station per drone

@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"
@onready var grid_manager = $"../GridManager"

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
	var water_stations = get_tree().get_nodes_in_group("water_station")
	var forests = get_tree().get_nodes_in_group("forest")

	# Initialize the grid from scene nodes.
	grid_manager.initialize(forests, water_stations)

	# Give each drone a reference to the grid manager.
	for drone in drones:
		drone.grid_manager = grid_manager

	# Assign each drone to its nearest water station as home base.
	for drone in drones:
		var best_ws = null
		var best_dist := INF
		for ws in water_stations:
			var d = drone.global_position.distance_to(ws.global_position)
			if d < best_dist:
				best_dist = d
				best_ws = ws
		drone_home_stations.append(best_ws)


func start_simulation():
	if round_active:
		return
	generation = 0
	print("=== Starting evolutionary run (%d generations, %d tick rounds) ===" % [NUM_GENERATIONS, ROUND_DURATION_TICKS])
	_start_generation_zero()


func _start_generation_zero():
	var weight_sets = GeneticAlgorithm.evolve(alpha_parent, beta_parent, drones.size())
	_begin_round(weight_sets)


func _begin_round(weight_sets: Array):
	_reset_world()
	_ignite_fires()

	# Place drones at home water stations and initialize GOAP, but do NOT start yet.
	for i in range(drones.size()):
		var home_ws = drone_home_stations[i]
		drones[i].global_position = home_ws.global_position
		drones[i].reset_for_round()
		drones[i].initialize_goap(weight_sets[i])

	tick_count = 0
	tick_accumulator = 0.0
	round_active = true
	drones_deployed = false
	print("--- Generation %d started ---" % generation)


func _process(delta):
	if not round_active:
		return

	var scaled_delta: float = delta * SIMULATION_SPEED if SIMULATION_SPEED > 0 else delta * 1000.0
	tick_accumulator += scaled_delta

	# Execute discrete ticks (cap per frame to avoid freezing).
	var ticks_this_frame := 0
	var max_ticks_per_frame := 10000
	while tick_accumulator >= TICK_INTERVAL and ticks_this_frame < max_ticks_per_frame:
		tick_accumulator -= TICK_INTERVAL
		_execute_tick()
		ticks_this_frame += 1
		if not round_active:
			return

	# Between ticks: interpolate drone positions for smooth visuals.
	if drones_deployed:
		var fraction := tick_accumulator / TICK_INTERVAL
		for drone in drones:
			if drone.has_method("interpolate_position"):
				drone.interpolate_position(fraction)


func _execute_tick():
	tick_count += 1

	# Update timer display.
	timer_label.text = "Time: " + str(tick_count)

	# 1) Tick fire spread and death.
	grid_manager.tick_fire()

	# 2) Check deployment threshold — deploy drones once 10% is burning.
	if not drones_deployed and grid_manager.should_deploy_drones():
		_deploy_drones()

	# 3) Tick cooperative extinguishing on burning cells (before drone ticks,
	#    so drones that finish this tick still contribute their last increment).
	for cell in grid_manager.get_burning_cells():
		if cell.has_method("tick_extinguish"):
			cell.tick_extinguish()

	# 4) Tick all active drones.
	if drones_deployed:
		for drone in drones:
			if drone.has_method("tick"):
				drone.tick()

	# 5) Check round end: all fires out (and no burning) or timeout.
	var burning = grid_manager.get_burning_cells()
	if burning.is_empty() and drones_deployed:
		_end_round()
	elif tick_count >= ROUND_DURATION_TICKS:
		_end_round()


func _deploy_drones():
	drones_deployed = true
	for drone in drones:
		drone.has_water = true
		drone.start_simulation()
	print("  Drones deployed at tick %d" % tick_count)


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

	# Detailed round stats.
	var alive = grid_manager.get_forest_alive_count()
	var burning = grid_manager.get_burning_cells().size()
	var dead = grid_manager.total_forest - alive
	var total_fires_ext := 0
	for drone in drones:
		total_fires_ext += drone.fires_extinguished
	print("  Round ended at tick %d | Alive: %d/%d | Dead: %d | Still burning: %d | Fires extinguished: %d" % [
		tick_count, alive, grid_manager.total_forest, dead, burning, total_fires_ext])

	GeneticAlgorithm.log_generation_stats(generation, population)
	generation += 1

	if generation >= NUM_GENERATIONS:
		print("=== Evolution complete after %d generations ===" % NUM_GENERATIONS)
		return

	# Evolve the next generation and start the next round after a brief pause.
	var next_weights = GeneticAlgorithm.evolve_from_population(population, drones.size())
	await get_tree().create_timer(0.05).timeout
	_begin_round(next_weights)


func _reset_world():
	# Reset all forest cells via GridManager.
	grid_manager.reset()

	# Return drones to home water stations.
	for i in range(drones.size()):
		var home_ws = drone_home_stations[i]
		drones[i].global_position = home_ws.global_position


func _ignite_fires():
	var forests = get_tree().get_nodes_in_group("forest")
	var shuffled = forests.duplicate()
	shuffled.shuffle()
	var count = min(NUM_FIRES_PER_ROUND, shuffled.size())
	for i in range(count):
		shuffled[i].is_on_fire = true


func _on_button_pressed() -> void:
	start_simulation()
