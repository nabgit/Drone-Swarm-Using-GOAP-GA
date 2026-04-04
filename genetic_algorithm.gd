extends Node
class_name GeneticAlgorithm

const WEIGHT_MIN := 0.01
const WEIGHT_MAX := 10.0

const DEFAULT_MUTATION_RATE := 0.15
const DEFAULT_MUTATION_MAGNITUDE := 0.5
const DEFAULT_DISCARD_FRACTION := 0.25


# --- Public API -----------------------------------------------------------

## Generation 0: crossover + mutate from two seed parents.
## Preserves existing call signature — new params are optional.
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
## Each element of `population` must have a "weights" key (Dictionary)
## and a "fitness" key (float).
static func evolve_from_population(
	population: Array,
	offspring_count: int,
	discard_fraction: float = DEFAULT_DISCARD_FRACTION,
	mutation_rate: float = DEFAULT_MUTATION_RATE,
	mutation_magnitude: float = DEFAULT_MUTATION_MAGNITUDE
) -> Array[Dictionary]:
	# Sort descending by fitness (best first).
	var sorted_pop := population.duplicate()
	sorted_pop.sort_custom(func(a, b): return a["fitness"] > b["fitness"])

	# Discard the worst fraction.
	var keep_count := int(ceil(sorted_pop.size() * (1.0 - discard_fraction)))
	keep_count = max(keep_count, 2)  # need at least 2 parents
	var mating_pool: Array = sorted_pop.slice(0, keep_count)

	var offspring: Array[Dictionary] = []

	# Elitism: copy the top performer unchanged.
	offspring.append(mating_pool[0]["weights"].duplicate())

	# Breed the rest.
	while offspring.size() < offspring_count:
		var pa: Dictionary = _select_parent(mating_pool)
		var pb: Dictionary = _select_parent(mating_pool)
		var child := _crossover(pa, pb)
		child = _mutate(child, mutation_rate, mutation_magnitude)
		offspring.append(child)

	return offspring


## Compute fitness from round metrics.
static func compute_fitness(metrics: Dictionary) -> float:
	var fires: float = metrics.get("fires_extinguished", 0.0)
	var burn: float  = metrics.get("total_burn_time_reduced", 0.0)
	var alive: float = metrics.get("forest_alive_at_end", 0.0)
	return fires * 10.0 + burn * 0.1 + alive * 2.0


## Print per-drone fitness, weights, and generation summary.
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

## Uniform crossover: 50/50 chance per gene from each parent.
static func _crossover(parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
	var child := {}
	for key in parent_a.keys():
		if randf() < 0.5:
			child[key] = parent_a[key]
		else:
			child[key] = parent_b.get(key, parent_a[key])
	return child


## Per-gene random perturbation, clamped to [WEIGHT_MIN, WEIGHT_MAX].
static func _mutate(child: Dictionary, rate: float, magnitude: float) -> Dictionary:
	for key in child.keys():
		if randf() < rate:
			var delta := randf_range(-magnitude, magnitude)
			child[key] = clampf(child[key] + delta, WEIGHT_MIN, WEIGHT_MAX)
	return child


## Fitness-proportionate (roulette-wheel) selection.
## Returns the *weights* dictionary of the chosen parent.
static func _select_parent(mating_pool: Array) -> Dictionary:
	var total_fitness := 0.0
	for entry in mating_pool:
		total_fitness += max(entry["fitness"], 0.0)

	# If all fitness is zero, pick uniformly at random.
	if total_fitness <= 0.0:
		return mating_pool[randi() % mating_pool.size()]["weights"]

	var spin := randf() * total_fitness
	var running := 0.0
	for entry in mating_pool:
		running += max(entry["fitness"], 0.0)
		if running >= spin:
			return entry["weights"]

	# Fallback (shouldn't happen).
	return mating_pool[-1]["weights"]
