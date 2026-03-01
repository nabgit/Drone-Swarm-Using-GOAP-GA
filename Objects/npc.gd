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

#func _ready():
	
func initialize_goap(custom_weights: Dictionary):
	goap = GOAPInterface.new(custom_weights)
	add_child(goap)

func start_simulation():
	simulation_started = true
	enter_state(State.GO_TO_LOCATION)

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
	
	var success = await target.animate_smart_object(current_action_name, action_data)
	current_target_object = null

	if success:
		if current_action_name.begins_with("extinguish") or current_action_name == "assist_drone":
			has_water = false
		elif current_action_name.begins_with("refill"):
			has_water = true
	
	await get_tree().process_frame
	enter_state(State.GO_TO_LOCATION)

func update_npc_status(index, text):
	if index > 0 and index <= npc_labels.size():
		npc_labels[index-1].text = "Drone " + str(index) + ": " + text

func _on_button_pressed() -> void:
	start_simulation()
