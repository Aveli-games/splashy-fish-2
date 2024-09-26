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
	var num_actions = 0
	if roll_requester and roll_requester.has_method("set_roll_result"):
		match roll_requester.set_roll_result(value):
			Globals.roll_result_types.SUCCESS:
				num_actions = 1
			Globals.roll_result_types.CRITICAL:
				num_actions = 2
	if num_actions > 0:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		if level.has_method("freeze_camera"):
			level.freeze_camera()
		if roll_requester.has_method("get_action_options"):
			var action_options = roll_requester.get_action_options()
			if not action_options.is_empty():
				hud.show_action_options(roll_requester, action_options, num_actions)
				return
	_resume_play()

func _on_hud_actions_chosen(action_queue: Array):
	if roll_requester.has_method("set_action_queue"):
		roll_requester.set_action_queue(action_queue)
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
