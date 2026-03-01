extends Node2D

@export var is_on_fire: bool = false:
	set(value):
		is_on_fire = value
		if is_on_fire:
			burn_timer = 0
			extinguish_progress = 0
			extinguisher_count = 0
		update_sprite()

## Ticks this tree has been burning continuously (managed by GridManager).
var burn_timer: int = 0

var is_dead: bool = false
var extinguisher_count: int = 0
var extinguish_progress: int = 0
var grid_coord: Vector2i = Vector2i(-1, -1)

var tree_tex = preload("res://Assets/icon-tree.png")
var burning_tex = preload("res://Assets/icon-burning.png")
var dead_tex = preload("res://Assets/icon-dead.png")

@onready var sprite = $Sprite2D

func _ready():
	update_sprite()

func update_sprite():
	if not sprite:
		return
	if is_dead:
		sprite.texture = dead_tex
	elif is_on_fire:
		sprite.texture = burning_tex
	else:
		sprite.texture = tree_tex

func kill():
	is_on_fire = false
	is_dead = true
	update_sprite()

func tick_extinguish():
	extinguish_progress += extinguisher_count
	if extinguish_progress >= 20:
		is_on_fire = false

func reset():
	is_on_fire = false
	is_dead = false
	burn_timer = 0
	extinguisher_count = 0
	extinguish_progress = 0
	update_sprite()

func animate_smart_object(action_type: String, data: Array) -> bool:
	print("Object ", name, " starting action: ", action_type, " with data: ", data)

	await get_tree().create_timer(2.0).timeout

	var success = true

	if success and action_type.begins_with("extinguish"):
		is_on_fire = false

	print("Object ", name, " finished action. Result: ", success)
	return success
