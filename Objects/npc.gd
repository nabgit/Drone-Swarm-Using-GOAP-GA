extends Node2D

@export var npc_index: int = 1
@export var movement_speed: float = 200.0

enum State { GO_TO_LOCATION, PERFORM_ACTION }
var current_state = State.GO_TO_LOCATION

var simulation_started = false
var timer = 0

var current_target_object = null
var current_action_name = ""
var action_data = []

@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"
@onready var npc_labels = [
	$"../CanvasLayer_UI/Control/Label-NPC_Status",
	$"../CanvasLayer_UI/Control/Label-NPC_Status2",
	$"../CanvasLayer_UI/Control/Label-NPC_Status3",
	$"../CanvasLayer_UI/Control/Label-NPC_Status4"
]

var has_water = false
var goap: GOAPInterface = null

# --- Fitness metrics (PR 2) -----------------------------------------------
var fires_extinguished: int = 0
var total_burn_time_reduced: float = 0.0

#func _ready():

func initialize_goap(custom_weights: Dictionary):
	# Remove old GOAP child if re-initializing between generations.
	if goap != null:
		goap.queue_free()
	goap = GOAPInterface.new(custom_weights)
	add_child(goap)

func start_simulation():
	simulation_started = true
	enter_state(State.GO_TO_LOCATION)

func stop_simulation():
	simulation_started = false
	current_target_object = null
	current_action_name = ""
	action_data = []

## Return this drone's weight dictionary (for building population entries).
func get_weights() -> Dictionary:
	if goap:
		return goap.weights.duplicate()
	return {}

## Gather metrics used by GeneticAlgorithm.compute_fitness().
func get_metrics() -> Dictionary:
	var forests = get_tree().get_nodes_in_group("forest")
	var alive = 0
	for f in forests:
		if not f.get("is_on_fire"):
			alive += 1
	return {
		"fires_extinguished": fires_extinguished,
		"total_burn_time_reduced": total_burn_time_reduced,
		"forest_alive_at_end": alive,
	}

## Reset drone state for a new generation round.
func reset_for_round():
	simulation_started = false
	has_water = false
	current_target_object = null
	current_action_name = ""
	action_data = []
	timer = 0
	fires_extinguished = 0
	total_burn_time_reduced = 0.0

func _process(delta):
	if simulation_started:
		if npc_index == 1:
			timer += delta
			timer_label.text = "Time: " + str(int(timer))

		if current_state == State.GO_TO_LOCATION and current_target_object:
			var distance = global_position.distance_to(current_target_object.global_position)

			if distance > 5.0:
				var direction = global_position.direction_to(current_target_object.global_position)
				global_position += direction * movement_speed * delta
			else:
				global_position = current_target_object.global_position
				enter_state(State.PERFORM_ACTION)


func enter_state(new_state):
	if goap == null:
		print("Drone ", npc_index, " waiting for GOAP initialization...")
		return

	current_state = new_state
	match current_state:
		State.GO_TO_LOCATION:
			var plan = goap.get_next_plan(has_water, self)
			if plan.is_empty() or plan.get("target") == null:
				update_npc_status(npc_index, "Idle (no target)")
				return
			current_target_object = plan["target"]
			current_action_name = plan["action"]
			action_data = plan["data"]

			update_npc_status(npc_index, "Moving to: " + current_target_object.name)

		State.PERFORM_ACTION:
			update_npc_status(npc_index, "Performing: " + current_action_name)
			_handle_action()

func _handle_action():
	var target = current_target_object
	if target == null:
		enter_state(State.GO_TO_LOCATION)
		return

	# Snapshot burn timer before the action (for burn-time-reduced credit).
	var burn_before: float = 0.0
	if current_action_name.begins_with("extinguish") and target.has_method("_process"):
		burn_before = target.get("burn_timer") if target.get("burn_timer") != null else 0.0

	var success = await target.animate_smart_object(current_action_name, action_data)
	current_target_object = null

	if success:
		if current_action_name.begins_with("extinguish") or current_action_name == "assist_drone":
			has_water = false
			if current_action_name.begins_with("extinguish"):
				fires_extinguished += 1
				# Credit = how quickly the drone responded.
				# Lower burn_before means faster response → more credit.
				# Use action duration (2s) + burn_before as reference so credit is always positive.
				total_burn_time_reduced += max(10.0 - burn_before, 0.0)
		elif current_action_name.begins_with("refill"):
			has_water = true

	await get_tree().process_frame
	enter_state(State.GO_TO_LOCATION)

func update_npc_status(index, text):
	if index > 0 and index <= npc_labels.size():
		npc_labels[index-1].text = "Drone " + str(index) + ": " + text

func _on_button_pressed() -> void:
	start_simulation()
