extends Node

@export var level_scene: PackedScene

var roll_requester
var hud
var level
var dice_roll_canvas
var game_ended = false

# Called when the node enters the scene tree for the first time.
func _ready():
	hud = $HUD
	level = $Level
	_pause_play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_roll_requested(requester):
	# Speed up time while rolling so the simulation goes quick
	# TODO: Add "Dice roll speed" setting in future options menu
	_pause_play()
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
	hud.hide_menus()
	# Return time to normal speed
	Engine.time_scale = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if level.has_method("resume_play"):
		level.resume_play()
	
func _pause_play():
	level.pause_play()

func _on_quit_pressed():
	get_tree().quit()

func _on_play_pressed():
	if game_ended:
		_on_restart_pressed()
	else:
		_resume_play()

func _input(event):
	if event.is_action_pressed("menu"):
		_pause_play()
		hud.show_main_menu()

func _restart_level():
	game_ended = false
	if level:
		level.free()
		var new_level = level_scene.instantiate()
		add_child(new_level)
		new_level.roll_requested.connect(_on_roll_requested)
		new_level.lost.connect(_on_level_lost)
		new_level.won.connect(_on_level_won)
		level = new_level

func _on_restart_pressed():
	_restart_level()
	_resume_play()

func _on_level_lost():
	game_ended = true
	hud.show_loss_screen()

func _on_level_won():
	game_ended = true
	hud.show_win_screen()
