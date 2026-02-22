extends Node2D

@export var is_on_fire: bool = false:
	set(value):
		is_on_fire = value
		update_sprite()

var tree_tex = preload("res://Assets/icon-tree.png")
var burning_tex = preload("res://Assets/icon-burning.png")

@onready var sprite = $Sprite2D

func _ready():
	update_sprite()

func update_sprite():
	if not sprite: return # Safety check for initialization
	
	if is_on_fire:
		sprite.texture = burning_tex
	else:
		sprite.texture = tree_tex

func animate_smart_object(action_type: String, data: Array) -> bool:
	print("Object ", name, " starting action: ", action_type, " with data: ", data)
	
	await get_tree().create_timer(2.0).timeout
	
	var success = true 
	
	if success and action_type.begins_with("extinguish"):
		is_on_fire = false
	
	print("Object ", name, " finished action. Result: ", success)
	return success
