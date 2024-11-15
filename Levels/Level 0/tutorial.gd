extends Level

signal tutorial_completed

var remaining_enemies = 0

var tutorial_complete = false

var tutorial_stage = "Introduction"

@export var player: Player
@export var instructions_screen: Control
@export var objective_label: Label

var play_paused = false
var instructions_visible = false

var mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready():
	initialize_self()
	player.disable_movement()
	player.disable_melee()
	player.disable_ranged()
	player.roll_fail_upper_threshold = 1

func _process(delta):
	if tutorial_complete and num_enemies <= 0 and get_tree().get_nodes_in_group("Enemies").size() == 0:
		game_ended = true
		won.emit()

func _input(event):
	if tutorial_stage == "Movement" and (event.is_action("move_forward") or event.is_action("move_back") or event.is_action("move_left") or event.is_action("move_right")):
		if not instructions_visible:
			$TutorialTimer.start()

func spawn_enemy(number: int):
	if number > num_enemies:
		number = num_enemies
	else:
		num_enemies -= number
	
	# Choose a random location on the SpawnPath.
	# We store the reference to the SpawnLocation node.
	var enemy_spawn_location = get_node("SpawnPath/SpawnLocation")
	# And give it a random offset.
	enemy_spawn_location.progress_ratio = randf()

	while number > 0:
		number -= 1
		enemy_spawn_location.progress_ratio += .015
		# Create a new instance of the Enemy scene.
		var enemy = enemy_scene.instantiate()

		# Assign the objective as the enemy's target 
		enemy.initialize(enemy_spawn_location.global_position, objective)

		# Spawn the enemy by adding it to the Main scene.
		$Enemies.add_child(enemy)
		
		# We connect the enemy to the no target found signal so the level can assign the default
		enemy.no_target_found.connect(_on_enemy_no_target_found.bind())
		
		# Tutorial differs from other levels in that we want to track enemies dying to update the counter
		enemy.died.connect(_on_enemy_died)

func pause_play():
	play_paused = true
	freeze_camera()
	get_tree().set_group_flags(0, "Level", "process_mode", PROCESS_MODE_DISABLED)

func resume_play(mouse_mode: int):
	if not bg_music.playing:
		bg_music.play()
	if instructions_visible:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	else:
		Input.mouse_mode = mouse_mode
	play_paused = false
	unfreeze_camera()
	get_tree().set_group_flags(0, "Level", "process_mode", PROCESS_MODE_ALWAYS)

func fight_one_hundred_enemies():
	bg_music.stream = load("res://Levels/Level 0/fight_100_track.tres")
	$Player.add_to_group("PlayerTargets")
	$Player.set_ammo(1000)
	
	player.enable_movement()
	player.enable_melee()
	player.enable_ranged()
	
	num_enemies = 100
	initialize_remaining_enemies(num_enemies)
	max_enemy_group = 1
	spawn_enemy(1)
	$EnemySpawnTimer.start()
	
	tutorial_complete = true
	mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_dummy_enemy_died():
	tutorial_stage = "Wrap Up"
	instructions_screen.show_end()
	
func initialize_remaining_enemies(number: int):
	remaining_enemies = number
	$TutorialUI/TutorialObjective/RemainingEnemiesBar.initialize(remaining_enemies)
	objective_label.text = "Remaining Enemies"
	$TutorialUI/TutorialObjective/RemainingEnemiesBar.show()

func _on_enemy_died():
	remaining_enemies -= 1
	$TutorialUI/TutorialObjective/RemainingEnemiesBar.set_value(remaining_enemies)

func _on_instructions_screen_continue_pressed(title: String):
	if play_paused:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	match title:
		"Introduction":
			tutorial_stage = "Movement"
			instructions_screen.show_movement()
			objective_label.text = "Objective: Move around"
			player.enable_movement()
		"Melee Attacking":
			player.enable_melee()
			player.enable_movement()
		"Melee Hit Options":
			$TutorialTimer.start()
		"Melee Failure":
			player.enable_movement()
			player.enable_melee()
			player.roll_pass_upper_threshold = 13
			player.roll_fail_upper_threshold = 12
		"Ranged Attacking":
			player.disable_melee()
			player.set_ammo(1)
			player.enable_ranged()
			player.enable_movement()
			$Enemies/Enemy.health = 1
		"Wrap Up":
			tutorial_completed.emit()

func _on_tutorial_timer_timeout():
	match tutorial_stage:
		"Introduction":
			instructions_screen.show_intro()
			objective_label.text = "Objective: Welcome"
		"Movement":
			tutorial_stage = "Melee Attacking"
			player.disable_movement()
			instructions_screen.show_melee()
			objective_label.text = "Objective: Punch the cat"
		"Melee Hit Options":
			player.disable_movement()
			player.disable_melee()
			tutorial_stage = "Melee Failure"
			instructions_screen.show_melee_failure()
			objective_label.text = "Objective: Fail a punch roll"
		"Melee Failure":
			$Player.remove_from_group("PlayerTargets")
			$Enemies/Enemy.melee_targets.erase($Player)
			$Enemies/Enemy.target = null
			tutorial_stage = "Ranged Attacking"
			player.disable_movement()
			player.disable_melee()
			instructions_screen.show_ranged()
			objective_label.text = "Objective: Throw a donut at the cat"

func _on_player_attacking(player):
	if tutorial_stage == "Melee Attacking":
		tutorial_stage = "Melee Hit Options"
		instructions_screen.show_hit_options()
		objective_label.text = "Objective: Try out melee follow-up actions"
	elif tutorial_stage == "Melee Failure":
		$Player.add_to_group("PlayerTargets")
		$Enemies/Enemy.target = $Player
		$Enemies/Enemy.melee_targets.append($Player)
	
func _on_player_kicked():
	if tutorial_stage == "Melee Failure":
		player.roll_pass_upper_threshold = 9
		player.roll_fail_upper_threshold = 3
		$TutorialTimer.start()

func _on_instructions_screen_hidden():
	instructions_visible = false

func _on_instructions_screen_shown():
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	instructions_visible = true
