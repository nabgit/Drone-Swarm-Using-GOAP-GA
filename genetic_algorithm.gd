extends Node
class_name GeneticAlgorithm

static func evolve(parent_a: Dictionary, parent_b: Dictionary, count: int = 4) -> Array[Dictionary]:
	var offspring: Array[Dictionary] = []
	
	for i in range(count):
		var child = {}
		for key in parent_a.keys():
			child[key] = 1.0
		offspring.append(child)
	
	return offspring
