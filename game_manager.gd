extends Node

const ROUND_DURATION_TICKS := 600
const NUM_FIRES_PER_ROUND := 4
const NUM_GENERATIONS := 100
const TICK_INTERVAL := 1.0

const POPULATION_SIZE := 20
const ROUNDS_PER_CANDIDATE := 3

const LOG_FITNESS_STATS := true
const MAX_LUCK_RATIO := 1.75

const SIMULATION_SPEED := 1
const USE_GENETIC_ALGORITHM := true

var log_file : FileAccess
var log_path := "user://simulation_log.csv"
const WEIGHT_FILE_PATH := "user://best_drone_brain.json"
const TEST_MODE := false
const RESUME_TRAINING := false
const FIXED_SPAWNS := false

const FIXED_SPAWN_INDICES := [10, 25, 70, 85]

var generation := 0
var tick_count := 0
var tick_accumulator := 0.0
var round_active := false
var drones_deployed := false

var generation_seed: int = 0

var drones: Array = []
var drone_home_stations: Array = []

var best_alive := -1
var best_fitness_ever := -INF
var best_weights: Dictionary = {}

# Population tracking
var population: Array = []
var current_candidate_index := 0
var candidate_round_scores: Array[float] = []

@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"
@onready var grid_manager = $"../GridManager"

var alpha_parent := {
	"extinguish_nearest": 1.0, "extinguish_newest": 1.0, "extinguish_oldest": 1.0,
	"extinguish_smallest": 1.0, "extinguish_high_spread": 1.0, "extinguish_isolated": 1.0,
	"extinguish_near_water": 1.0, "patrol_unburned": 1.0, "assist_drone": 1.0,
	"refill_nearest": 1.0, "refill_furthest": 1.0, "refill_if_nearby": 1.0
}
var beta_parent := {
	"extinguish_nearest": 2.0, "extinguish_newest": 0.5, "extinguish_oldest": 0.5,
	"extinguish_smallest": 1.5, "extinguish_high_spread": 2.5, "extinguish_isolated": 0.8,
	"extinguish_near_water": 1.2, "patrol_unburned": 0.8, "assist_drone": 0.3,
	"refill_nearest": 2.0, "refill_furthest": 0.2, "refill_if_nearby": 1.5
}

func _init_logger():
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file:
		log_file.store_line("generation,candidate,round,tick,alive,dead,burning,fires_extinguished,fitness")

func _ready():
	drones = get_tree().get_nodes_in_group("drones")
	var water_stations = get_tree().get_nodes_in_group("water_station")
	var forests = get_tree().get_nodes_in_group("forest")

	grid_manager.initialize(forests, water_stations)

	for drone in drones:
		drone.grid_manager = grid_manager

	for drone in drones:
		var best_ws = null
		var best_dist := INF
		for ws in water_stations:
			var d = drone.global_position.distance_to(ws.global_position)
			if d < best_dist:
				best_dist = d
				best_ws = ws
		drone_home_stations.append(best_ws)

func log_csv(line: String):
	print(line)
	if log_file:
		log_file.store_line(line)

func start_simulation():
	if round_active:
		return

	_init_logger()

	generation = 0
	best_alive = -1
	best_fitness_ever = -INF
	best_weights = {}
	generation_seed = randi()

	print("=== Starting evolutionary run (%d generations, pop=%d, %d rounds/candidate) ===" % [
		NUM_GENERATIONS, POPULATION_SIZE, ROUNDS_PER_CANDIDATE])

	_start_generation_zero()


func _start_generation_zero():
	population = []

	if TEST_MODE:
		print("TEST MODE ON: Loading static brain from file...")
		var loaded_weights = _load_saved_brain()
		for i in range(POPULATION_SIZE):
			population.append({"weights": loaded_weights.duplicate(true), "fitness": 0.0})

	elif RESUME_TRAINING and FileAccess.file_exists("user://best_drone_brain.json"):
		print("RESUMING TRAINING: Mutating from saved brain...")
		var loaded_weights = _load_saved_brain()
		var weight_sets = GeneticAlgorithm.evolve(loaded_weights, loaded_weights, POPULATION_SIZE)
		for ws in weight_sets:
			population.append({"weights": ws, "fitness": 0.0})

	elif USE_GENETIC_ALGORITHM:
		print("NEW EVOLUTION: Starting from alpha/beta parents...")
		var weight_sets = GeneticAlgorithm.evolve(alpha_parent, beta_parent, POPULATION_SIZE)
		for ws in weight_sets:
			population.append({"weights": ws, "fitness": 0.0})

	else:
		print("BASELINE MODE: Using alpha_parent with no learning.")
		for i in range(POPULATION_SIZE):
			population.append({"weights": alpha_parent.duplicate(true), "fitness": 0.0})

	current_candidate_index = 0
	candidate_round_scores.clear()
	_begin_candidate_round()


func _begin_candidate_round():
	_reset_world()

	# Seed: deterministic per (generation, candidate, round) — all candidates
	# face the same fire scenarios per round index for fair comparison
	var round_index = candidate_round_scores.size()
	seed(generation_seed + round_index)
	_ignite_fires()

	# All drones get the SAME weights — homogeneous team
	var candidate_weights: Dictionary = population[current_candidate_index]["weights"]
	for i in range(drones.size()):
		var home_ws = drone_home_stations[i]
		drones[i].global_position = home_ws.global_position
		drones[i].reset_for_round()
		drones[i].initialize_goap(candidate_weights.duplicate(true))

	tick_count = 0
	tick_accumulator = 0.0
	round_active = true
	drones_deployed = false
	print("--- Gen %d | Candidate %d/%d | Round %d/%d ---" % [
		generation, current_candidate_index + 1, POPULATION_SIZE,
		round_index + 1, ROUNDS_PER_CANDIDATE])


func _process(delta):
	if not round_active:
		return

	var scaled_delta: float = delta * SIMULATION_SPEED if SIMULATION_SPEED > 0 else delta * 1000.0
	tick_accumulator += scaled_delta

	var ticks_this_frame := 0
	var max_ticks_per_frame := 10000
	while tick_accumulator >= TICK_INTERVAL and ticks_this_frame < max_ticks_per_frame:
		tick_accumulator -= TICK_INTERVAL
		_execute_tick()
		ticks_this_frame += 1
		if not round_active:
			return

	if drones_deployed:
		var fraction := tick_accumulator / TICK_INTERVAL
		for drone in drones:
			if drone.has_method("interpolate_position"):
				drone.interpolate_position(fraction)


func _execute_tick():
	tick_count += 1
	timer_label.text = "Time: " + str(tick_count)

	grid_manager.tick_fire()

	if not drones_deployed and grid_manager.should_deploy_drones():
		_deploy_drones()

	for cell in grid_manager.get_burning_cells():
		if cell.has_method("tick_extinguish"):
			cell.tick_extinguish()

	if drones_deployed:
		for drone in drones:
			if drone.has_method("tick"):
				drone.tick()

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

	var all_metrics := []
	for drone in drones:
		all_metrics.append(drone.get_metrics())
	var team_fitness: float = GeneticAlgorithm.compute_team_fitness(all_metrics)

	var alive = grid_manager.get_forest_alive_count()
	var burning = grid_manager.get_burning_cells().size()
	var dead = grid_manager.total_forest - alive
	var total_fires_ext := 0
	for drone in drones:
		total_fires_ext += drone.fires_extinguished

	if LOG_FITNESS_STATS:
		var csv_line = "%d,%d,%d,%d,%d,%d,%d,%d,%.4f" % [
			generation, current_candidate_index, candidate_round_scores.size(),
			tick_count, alive, dead, burning, total_fires_ext, team_fitness]
		log_csv(csv_line)

	print("  Alive: %d/%d | Dead: %d | Ext: %d | Fitness: %.2f" % [
		alive, grid_manager.total_forest, dead, total_fires_ext, team_fitness])

	candidate_round_scores.append(team_fitness)

	# More rounds for this candidate?
	if candidate_round_scores.size() < ROUNDS_PER_CANDIDATE:
		await get_tree().create_timer(0.05).timeout
		_begin_candidate_round()
		return

	# Average this candidate's fitness
	var avg_fitness: float = 0.0
	for s in candidate_round_scores:
		avg_fitness += s
	avg_fitness /= float(candidate_round_scores.size())

	population[current_candidate_index]["fitness"] = avg_fitness
	print("  Candidate %d avg fitness: %.4f" % [current_candidate_index, avg_fitness])

	candidate_round_scores.clear()
	current_candidate_index += 1

	# More candidates?
	if current_candidate_index < POPULATION_SIZE:
		await get_tree().create_timer(0.05).timeout
		_begin_candidate_round()
		return

	# All candidates done — finish generation
	_finish_generation()


func _finish_generation():
	var gen_best_fitness := -INF
	var gen_best_weights: Dictionary = {}
	var gen_avg_fitness := 0.0

	for entry in population:
		gen_avg_fitness += entry["fitness"]
		if entry["fitness"] > gen_best_fitness:
			gen_best_fitness = entry["fitness"]
			gen_best_weights = entry["weights"]

	gen_avg_fitness /= float(population.size())

	var fitness_delta: float = gen_best_fitness - best_fitness_ever

	print("===== Generation %d Summary =====" % generation)
	for i in range(population.size()):
		print("  Candidate %d | fitness: %.4f" % [i, population[i]["fitness"]])
	print("  Best: %.4f | Avg: %.4f | Delta: %.4f" % [gen_best_fitness, gen_avg_fitness, fitness_delta])

	var accepted := false
	var reject_reason := ""

	if best_weights.is_empty():
		accepted = true
	elif gen_best_fitness <= best_fitness_ever:
		reject_reason = "No improvement (%.4f <= %.4f)" % [gen_best_fitness, best_fitness_ever]
	else:
		var ratio: float = gen_best_fitness / best_fitness_ever
		if ratio > MAX_LUCK_RATIO:
			reject_reason = "Leap too large (x%.2f > x%.2f cap)" % [ratio, MAX_LUCK_RATIO]
		else:
			accepted = true

	if accepted:
		var ratio_str := "x%.3f" % [gen_best_fitness / best_fitness_ever] if best_fitness_ever > 0.0 else "seed"
		print("  ACCEPTED | Fitness: %.4f (%s)" % [gen_best_fitness, ratio_str])
		best_fitness_ever = gen_best_fitness
		best_weights = gen_best_weights.duplicate(true)
		if not TEST_MODE:
			_save_best_brain_weights(best_weights)
	else:
		print("  REJECTED | %s" % reject_reason)

	generation += 1

	if generation >= NUM_GENERATIONS:
		print("=== Evolution complete after %d generations ===" % NUM_GENERATIONS)
		if log_file:
			log_file.close()
		return

	generation_seed = randi()

	# Breed next generation
	if TEST_MODE:
		var loaded_weights = _load_saved_brain()
		population = []
		for i in range(POPULATION_SIZE):
			population.append({"weights": loaded_weights.duplicate(true), "fitness": 0.0})

	elif USE_GENETIC_ALGORITHM:
		# Inject all-time best as extra elite
		var breeding_pool: Array = population.duplicate(true)
		if not best_weights.is_empty():
			breeding_pool.append({"weights": best_weights.duplicate(true), "fitness": best_fitness_ever})

		var next_weight_sets = GeneticAlgorithm.evolve_from_population(breeding_pool, POPULATION_SIZE)
		population = []
		for ws in next_weight_sets:
			population.append({"weights": ws, "fitness": 0.0})

	else:
		population = []
		for i in range(POPULATION_SIZE):
			population.append({"weights": alpha_parent.duplicate(true), "fitness": 0.0})

	current_candidate_index = 0
	candidate_round_scores.clear()
	await get_tree().create_timer(0.05).timeout
	_begin_candidate_round()


func _reset_world():
	grid_manager.reset()
	for i in range(drones.size()):
		var home_ws = drone_home_stations[i]
		drones[i].global_position = home_ws.global_position


func _ignite_fires():
	var forests = get_tree().get_nodes_in_group("forest")

	if TEST_MODE or (not FIXED_SPAWNS):
		var shuffled = forests.duplicate()
		shuffled.shuffle()
		var count = min(NUM_FIRES_PER_ROUND, shuffled.size())
		for i in range(count):
			shuffled[i].is_on_fire = true
		print("  Fires ignited at seeded-random positions")
	else:
		var count = min(FIXED_SPAWN_INDICES.size(), forests.size())
		for i in range(count):
			var idx = FIXED_SPAWN_INDICES[i]
			if idx < forests.size():
				forests[idx].is_on_fire = true
		print("  Fires ignited at fixed positions")


func _on_button_pressed() -> void:
	start_simulation()


func _save_best_brain_weights(w: Dictionary) -> void:
	var file = FileAccess.open(WEIGHT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(w, "\t"))
	file.close()
	print("💾 Saved new best brain to JSON!")


func _load_saved_brain(fallback_weights: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(WEIGHT_FILE_PATH):
		print("⚠️ No saved brain found! Using fallback.")
		return fallback_weights.duplicate(true)

	var file = FileAccess.open(WEIGHT_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for reading: %s" % FileAccess.get_open_error())
		return fallback_weights.duplicate(true)

	var json_string = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_string)
	if data == null:
		push_warning("Failed to parse JSON, using fallback")
		return fallback_weights.duplicate(true)

	return data
