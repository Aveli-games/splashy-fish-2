extends Node

@export var dice_roller_scene: PackedScene

var roll_requester
var hud
var dice_roll_canvas

# Called when the node enters the scene tree for the first time.
func _ready():
	hud = $HUD
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("Splashy")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_roll_requested(requester):
	# Speed up time while rolling so the simulation goes quick
	# TODO: Add "Dice roll speed" setting in future options menu
	get_tree().set_group_flags(0, "RollPause", "process_mode", PROCESS_MODE_DISABLED)
	Engine.time_scale = 3
	hud.show_dice_roll()
	roll_requester = requester
	hud.roll()

func _on_roll_finished(value):
	# Return time to normal speed
	Engine.time_scale = 1
	await get_tree().create_timer(.75).timeout # Give time for player to understand result
	get_tree().set_group_flags(0, "RollPause", "process_mode", PROCESS_MODE_ALWAYS)
	if roll_requester and roll_requester.has_method("set_roll_result"):
		roll_requester.set_roll_result(value)
		roll_requester = null
	hud.hide_dice_roll()
