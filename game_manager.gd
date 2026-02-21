extends Node

var simulation_started = false
var timer = 0

@onready var start_button = $"../CanvasLayer_UI/Control/Button"
@onready var timer_label = $"../CanvasLayer_UI/Control/Label-Timer"
@onready var npc_labels = [
	$"../CanvasLayer_UI/Control/Label-NPC_Status",
	$"../CanvasLayer_UI/Control/Label-NPC_Status2",
	$"../CanvasLayer_UI/Control/Label-NPC_Status3",
	$"../CanvasLayer_UI/Control/Label-NPC_Status4"
]

#func _ready():

func start_simulation():
	simulation_started = true
	print("Simulation started!")

func _process(delta):
	if simulation_started:
		timer += delta
		timer_label.text = "Time: " + str(int(timer))

func update_npc_status(npc_index, text):
	npc_labels[npc_index-1].text = text


func _on_button_pressed() -> void:
	start_simulation()
