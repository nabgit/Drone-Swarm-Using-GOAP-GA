extends Node2D

@export var npc_index: int = 1

enum State { IDLE, MOVING, EXTINGUISHING, REFILLING }
var current_state = State.IDLE

var simulation_started := false
var has_water := false
var goap: GOAPInterface = null
var grid_manager: GridManager = null

# Grid movement
var grid_coord := Vector2i(-1, -1)
var move_path: Array[Vector2i] = []

# Visual interpolation between grid cells
var visual_from := Vector2.ZERO
var visual_to := Vector2.ZERO

# Action countdown (20 ticks for extinguish/refill)
var action_ticks_remaining := 0
var current_target_object = null
var current_action_name := ""

# Fitness metrics
var fires_extinguished: int = 0
var total_burn_time_reduced: float = 0.0

@onready var npc_labels = [
	$"../CanvasLayer_UI/Control/Label-NPC_Status",
	$"../CanvasLayer_UI/Control/Label-NPC_Status2",
	$"../CanvasLayer_UI/Control/Label-NPC_Status3",
	$"../CanvasLayer_UI/Control/Label-NPC_Status4",
	$"../CanvasLayer_UI/Control/Label-NPC_Status5",
	$"../CanvasLayer_UI/Control/Label-NPC_Status6",
	$"../CanvasLayer_UI/Control/Label-NPC_Status7",
	$"../CanvasLayer_UI/Control/Label-NPC_Status8",
	$"../CanvasLayer_UI/Control/Label-NPC_Status9",
	$"../CanvasLayer_UI/Control/Label-NPC_Status10",
	$"../CanvasLayer_UI/Control/Label-NPC_Status11",
	$"../CanvasLayer_UI/Control/Label-NPC_Status12"
]


func initialize_goap(custom_weights: Dictionary):
	if goap != null:
		goap.queue_free()
	goap = GOAPInterface.new(custom_weights)
	if grid_manager:
		goap.set_grid_manager(grid_manager)
	add_child(goap)


func start_simulation():
	simulation_started = true
	# Snap grid_coord from current world position.
	if grid_manager:
		grid_coord = grid_manager.world_to_grid(global_position)
		visual_from = global_position
		visual_to = global_position
	_enter_idle()


func stop_simulation():
	simulation_started = false
	# Unregister from any target we were extinguishing.
	if current_state == State.EXTINGUISHING and current_target_object:
		current_target_object.extinguisher_count -= 1
	current_target_object = null
	current_action_name = ""
	current_state = State.IDLE


func get_weights() -> Dictionary:
	if goap:
		return goap.weights.duplicate()
	return {}


func get_metrics() -> Dictionary:
	var alive = 0
	if grid_manager:
		alive = grid_manager.get_forest_alive_count()
	else:
		for f in get_tree().get_nodes_in_group("forest"):
			if not f.get("is_on_fire") and not f.get("is_dead"):
				alive += 1
	return {
		"fires_extinguished": fires_extinguished,
		"total_burn_time_reduced": total_burn_time_reduced,
		"forest_alive_at_end": alive,
	}


func reset_for_round():
	simulation_started = false
	has_water = false
	current_target_object = null
	current_action_name = ""
	move_path = []
	action_ticks_remaining = 0
	current_state = State.IDLE
	fires_extinguished = 0
	total_burn_time_reduced = 0.0


func tick():
	if not simulation_started:
		return

	match current_state:
		State.IDLE:
			_plan_next_action()
		State.MOVING:
			_tick_move()
		State.EXTINGUISHING:
			_tick_extinguish()
		State.REFILLING:
			_tick_refill()


func interpolate_position(fraction: float):
	if current_state == State.MOVING:
		global_position = visual_from.lerp(visual_to, clampf(fraction, 0.0, 1.0))
	else:
		global_position = visual_to


# --- State transitions ---

func _enter_idle():
	current_state = State.IDLE
	update_npc_status(npc_index, "Idle")


func _plan_next_action():
	if goap == null:
		return

	var plan = goap.get_next_plan(has_water, self)
	if plan.is_empty() or plan.get("target") == null:
		update_npc_status(npc_index, "Idle (no target)")
		return

	current_target_object = plan["target"]
	current_action_name = plan["action"]

	# Get path from grid_manager.
	var target_grid: Vector2i = current_target_object.grid_coord
	move_path = grid_manager.find_path(grid_coord, target_grid)

	# Remove the first element (current position).
	if not move_path.is_empty() and move_path[0] == grid_coord:
		move_path.remove_at(0)

	if move_path.is_empty():
		# Already at target — go straight to action.
		_arrive_at_target()
	else:
		current_state = State.MOVING
		update_npc_status(npc_index, "Moving to: " + current_target_object.name)


func _tick_move():
	# Re-plan if target fire went out during movement.
	if current_target_object and current_action_name.begins_with("extinguish"):
		if not current_target_object.get("is_on_fire"):
			current_target_object = null
			move_path = []
			_enter_idle()
			return

	if move_path.is_empty():
		_arrive_at_target()
		return

	# Move one cell per tick.
	var next_cell: Vector2i = move_path[0]
	move_path.remove_at(0)

	visual_from = grid_manager.grid_to_world(grid_coord)
	grid_coord = next_cell
	visual_to = grid_manager.grid_to_world(grid_coord)

	# Don't call _arrive_at_target here — let this tick's interpolation play out fully.
	# The next tick will see move_path.is_empty() and arrive cleanly.


func _arrive_at_target():
	if current_target_object == null:
		_enter_idle()
		return

	# Snap to target world position.
	visual_from = grid_manager.grid_to_world(grid_coord)
	visual_to = visual_from

	if current_action_name.begins_with("extinguish") or current_action_name == "assist_drone":
		# Check fire is still burning.
		if not current_target_object.get("is_on_fire"):
			current_target_object = null
			_enter_idle()
			return

		# Register as extinguisher for cooperative mechanic.
		current_target_object.extinguisher_count += 1
		action_ticks_remaining = 20
		current_state = State.EXTINGUISHING
		# Snapshot burn timer for fitness credit.
		total_burn_time_reduced += max(100.0 - current_target_object.burn_timer, 0.0)
		update_npc_status(npc_index, "Extinguishing: " + current_target_object.name)

	elif current_action_name.begins_with("refill"):
		action_ticks_remaining = 20
		current_state = State.REFILLING
		update_npc_status(npc_index, "Refilling")

	else:
		_enter_idle()


func _tick_extinguish():
	# Re-plan if fire went out (cooperatively extinguished by others).
	if current_target_object == null or not current_target_object.get("is_on_fire"):
		if current_target_object:
			current_target_object.extinguisher_count -= 1
			fires_extinguished += 1
		current_target_object = null
		has_water = false
		_enter_idle()
		return

	action_ticks_remaining -= 1

	if action_ticks_remaining <= 0:
		# Time's up — unregister and move on.
		current_target_object.extinguisher_count -= 1
		fires_extinguished += 1
		has_water = false
		current_target_object = null
		_enter_idle()


func _tick_refill():
	action_ticks_remaining -= 1

	if action_ticks_remaining <= 0:
		has_water = true
		current_target_object = null
		_enter_idle()


func update_npc_status(index, text):
	if index > 0 and index <= npc_labels.size():
		npc_labels[index - 1].text = "Drone " + str(index) + ": " + text
