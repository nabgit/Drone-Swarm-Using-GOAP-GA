extends CharacterBody2D

@export var speed = 100.0
@export var action_time = 2.0
@export var npc_id = 1

@onready var game_manager = get_tree().get_first_node_in_group("game_manager")

enum State { GO_TO_OBJECT, PERFORM_ACTION }
var state = State.GO_TO_OBJECT

var target = null
var action_timer = 0.0

func _ready():
	target = find_closest_target()

func update_status(text):
	game_manager.update_npc_status(npc_id, text)

func _physics_process(delta):
	if not game_manager.simulation_started:
		return
	
	match state:
		State.GO_TO_OBJECT:
			go_to_object(delta)
		State.PERFORM_ACTION:
			perform_action(delta)

func find_closest_target():
	var targets = get_tree().get_nodes_in_group("target_objects")
	var closest = null
	var closest_dist = INF

	for t in targets:
		var dist = global_position.distance_to(t.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = t

	return closest

func perform_action(delta):
	update_status("DRONE %d: Performing action" % npc_id)
	velocity = Vector2.ZERO
	action_timer -= delta
	
	if action_timer <= 0:
		state = State.GO_TO_OBJECT
		target = null

func go_to_object(delta):
	update_status("DRONE %d: Going to target" % npc_id)
	if target == null or not is_instance_valid(target):
		target = find_closest_target()
		return

	# 1. Movement logic
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# 2. Manual proximity check (The "Collision" substitute)
	# 15.0 is the 'arrival' radius in pixels
	if global_position.distance_to(target.global_position) < 15.0:
		start_action()

func start_action():
	state = State.PERFORM_ACTION
	action_timer = action_time
	print("Reached target! Switching state.")
