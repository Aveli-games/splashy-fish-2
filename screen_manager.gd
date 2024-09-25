extends Node

var roll_requester
var hud
var level
var dice_roll_canvas

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = $HUD
	level = $Level
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
	var is_success = null
	if roll_requester and roll_requester.has_method("set_roll_result"):
		is_success = roll_requester.set_roll_result(value)
	if is_success:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		if level.has_method("freeze_camera"):
			level.freeze_camera()
		if roll_requester.has_method("get_action_options"):
			var action_options = roll_requester.get_action_options()
			if not action_options.is_empty():
				hud.show_action_options(roll_requester ,action_options)
				return
	_resume_play()

func _on_hud_action_chosen(option: Dictionary):
	if roll_requester.has_method("set_action_choice"):
		roll_requester.set_action_choice(option)
	_resume_play()
	
func _resume_play():
	roll_requester = null
	hud.hide_dice_roll()
	# Return time to normal speed
	Engine.time_scale = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if level.has_method("unfreeze_camera"):
		level.unfreeze_camera()
	get_tree().set_group_flags(0, "RollPause", "process_mode", PROCESS_MODE_ALWAYS)
