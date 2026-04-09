extends Node
class_name GeneticAlgorithm

const WEIGHT_MIN := 0.01
const WEIGHT_MAX := 10.0

const DEFAULT_MUTATION_RATE := 0.1
const DEFAULT_MUTATION_MAGNITUDE := 2.0
const DEFAULT_DISCARD_FRACTION := 0.25


# --- Public API -----------------------------------------------------------

## Generation 0: crossover + mutate from two seed parents.
static func evolve(
	parent_a: Dictionary,
	parent_b: Dictionary,
	count: int = 12,
	mutation_rate: float = DEFAULT_MUTATION_RATE,
	mutation_magnitude: float = DEFAULT_MUTATION_MAGNITUDE
) -> Array[Dictionary]:
	var offspring: Array[Dictionary] = []
	for i in range(count):
		var child := _crossover(parent_a, parent_b)
		child = _mutate(child, mutation_rate, mutation_magnitude)
		offspring.append(child)
	return offspring


## Generation 1+: sort by fitness, discard worst %, elitism for top
## performer, breed the rest via roulette-wheel parent selection.
static func evolve_from_population(
	population: Array,
	offspring_count: int,
	discard_fraction: float = DEFAULT_DISCARD_FRACTION,
	mutation_rate: float = DEFAULT_MUTATION_RATE,
	mutation_magnitude: float = DEFAULT_MUTATION_MAGNITUDE
) -> Array[Dictionary]:
	var sorted_pop := population.duplicate()
	sorted_pop.sort_custom(func(a, b): return a["fitness"] > b["fitness"])

	var keep_count := int(ceil(sorted_pop.size() * (1.0 - discard_fraction)))
	keep_count = max(keep_count, 2)
	var mating_pool: Array = sorted_pop.slice(0, keep_count)

	var offspring: Array[Dictionary] = []

	# Elitism: copy the top performer unchanged.
	offspring.append(mating_pool[0]["weights"].duplicate())

	while offspring.size() < offspring_count:
		var pa: Dictionary = _select_parent(mating_pool)
		var pb: Dictionary = _select_parent(mating_pool)
		var child := _crossover(pa, pb)
		child = _mutate(child, mutation_rate, mutation_magnitude)
		offspring.append(child)

	return offspring


const W_ALIVE := 10.0
const W_FIRES :=  3.0
const W_BURN  :=  1.0
const W_SPEED :=  5.0
const MAX_FITNESS := 19.0


## Compute team fitness — one shared score for all drones based on collective outcome.
static func compute_team_fitness(all_metrics: Array) -> float:
	# Aggregate metrics across all drones
	var total_fires: float = 0.0
	var total_burn: float = 0.0
	var alive: float = 0.0
	var tick: float = 600.0

	for m in all_metrics:
		total_fires += m.get("fires_extinguished", 0.0)
		total_burn += m.get("total_burn_time_reduced", 0.0)

	# These are global — same for all drones, just take from the first
	if not all_metrics.is_empty():
		alive = all_metrics[0].get("forest_alive_at_end", 0.0)
		tick = all_metrics[0].get("tick", 600.0)

	var alive_norm: float = clampf(alive / 96.0, 0.0, 1.0)
	var fires_norm: float = clampf(total_fires / 100.0, 0.0, 1.0)
	var burn_norm:  float = clampf(total_burn / 6000.0, 0.0, 1.0)
	var speed_norm: float = 1.0 - clampf(tick / 600.0, 0.0, 1.0)

	return ((alive_norm * W_ALIVE) + (fires_norm * W_FIRES) + (burn_norm * W_BURN) + (speed_norm * W_SPEED)) / MAX_FITNESS * 100.0


## Legacy per-drone fitness — kept for reference but no longer used.
static func compute_fitness(metrics: Dictionary) -> float:
	var fires: float = metrics.get("fires_extinguished", 0.0)
	var burn:  float = metrics.get("total_burn_time_reduced", 0.0)
	var alive: float = metrics.get("forest_alive_at_end", 0.0)
	var tick:  float = metrics.get("tick", 600.0)

	var alive_norm: float = clampf(alive / 96.0, 0.0, 1.0)
	var fires_norm: float = clampf(fires / 100.0, 0.0, 1.0)
	var burn_norm:  float = clampf(burn / 6000.0, 0.0, 1.0)
	var speed_norm: float = 1.0 - clampf(tick / 600.0, 0.0, 1.0)

	return ((alive_norm * W_ALIVE) + (fires_norm * W_FIRES) + (burn_norm * W_BURN) + (speed_norm * W_SPEED)) / MAX_FITNESS * 100.0


static func log_generation_stats(generation: int, population: Array) -> void:
	print("===== Generation %d =====" % generation)
	var total_fitness := 0.0
	var best_fitness := -INF
	var best_index := 0

	for i in range(population.size()):
		var entry: Dictionary = population[i]
		var fit: float = entry.get("fitness", 0.0)
		total_fitness += fit
		if fit > best_fitness:
			best_fitness = fit
			best_index = i
		print("  Drone %d | fitness: %.2f | weights: %s" % [i, fit, entry.get("weights", {})])

	var avg_fitness = total_fitness / max(population.size(), 1)
	print("  --- Summary ---")
	print("  Best: Drone %d (%.2f)  Avg: %.2f  Total: %.2f" % [best_index, best_fitness, avg_fitness, total_fitness])
	print("")


# --- Private helpers -------------------------------------------------------

static func _crossover(parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
	var child := {}
	for key in parent_a.keys():
		if randf() < 0.5:
			child[key] = parent_a[key]
		else:
			child[key] = parent_b.get(key, parent_a[key])
	return child


static func _mutate(child: Dictionary, rate: float, magnitude: float) -> Dictionary:
	for key in child.keys():
		if randf() < rate:
			var delta := randf_range(-magnitude, magnitude)
			child[key] = clampf(child[key] + delta, WEIGHT_MIN, WEIGHT_MAX)
	return child


## Tournament selection (k=2): pick 2 random, take the fitter one.
static func _select_parent(mating_pool: Array) -> Dictionary:
	var a = mating_pool[randi() % mating_pool.size()]
	var b = mating_pool[randi() % mating_pool.size()]
	if a["fitness"] >= b["fitness"]:
		return a["weights"]
	return b["weights"]
