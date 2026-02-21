extends CharacterBody2D

@export var speed = 100.0
@export var action_time = 2.0

enum State { GO_TO_OBJECT, PERFORM_ACTION }
var state = State.GO_TO_OBJECT

var target = null
var action_timer = 0.0

func _ready():
	target = find_closest_target()

func _physics_process(delta):
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

func go_to_object(delta):
	if target == null or not is_instance_valid(target):
		target = find_closest_target()
		return

	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func perform_action(delta):
	velocity = Vector2.ZERO
	action_timer -= delta
	
	if action_timer <= 0:
		state = State.GO_TO_OBJECT
		target = null


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == target:
		state = State.PERFORM_ACTION
		action_timer = action_time
