extends Node

class_name Level

signal roll_requested
signal lost
signal won

@export var level_name: String
@export var enemy_scene: PackedScene
@export var bottle_scene: PackedScene
@export var num_enemies = 10
@export var max_enemy_group = 3
@export var bg_music: AudioStreamPlayer

var camera_controller
var roll_requester
var objective
var game_ended = false

var last_spawn_group_size = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	initialize_self()

func _process(delta):
	if num_enemies <= 0 and get_tree().get_nodes_in_group("Enemies").size() == 0 and not game_ended:
		game_ended = true
		won.emit()

func _on_player_died():
	if not game_ended:
		game_ended = true
		freeze_camera()
		lost.emit()

func _on_objective_died():
	if not game_ended:
		game_ended = true
		freeze_camera()
		lost.emit()

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

func _on_enemy_spawn_timer_timeout():
	if $Player && $Player.process_mode != PROCESS_MODE_DISABLED and num_enemies > 0:
		# Space out spawning groups so the player doesn't get overwhelmed by accident
		if last_spawn_group_size == 1:
			last_spawn_group_size = randi_range(1,max_enemy_group)
			spawn_enemy(last_spawn_group_size)
		else:
			last_spawn_group_size = 1
			spawn_enemy(1)
	
func _on_enemy_no_target_found(enemy):
	enemy.set_target(objective)

func _on_player_roll_requested(player):
	roll_requested.emit(player)

func freeze_camera():
	camera_controller.toggle_mouse_control(false)

func unfreeze_camera():
	camera_controller.toggle_mouse_control(true)
	
func pause_play():
	freeze_camera()
	get_tree().set_group_flags(0, "Level", "process_mode", PROCESS_MODE_DISABLED)

func resume_play(mouse_mode: int):
	if not bg_music.playing:
		bg_music.play()
	Input.mouse_mode = mouse_mode
	unfreeze_camera()
	get_tree().set_group_flags(0, "Level", "process_mode", PROCESS_MODE_ALWAYS)

func initialize_self():
	camera_controller = get_node("CameraController")
	objective = get_node("Objective")
	
	# Move trees to pseudorandom locations for a more organic forest feel
	if $Boundaries/TreeLines:
		for tree_line in $Boundaries/TreeLines.get_children():
			for tree in tree_line.get_children():
				var tree_scale = Globals.rng.randf_range(2.4, 5)
				tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
				tree.position.x = Globals.rng.randi_range(-25, -15)
				if tree.has_method("snap_to_ground"):
					tree.snap_to_ground()
	
	# Spawn in some bottles to make the play area a little more interesting
	for n in 10:
		var bottle = bottle_scene.instantiate()
		
		# Place the bottle a random distance from and y-axis rotation around the objective
		bottle.global_position = objective.global_position + Vector3(Globals.rng.randi_range(2, 5), 0, 0).rotated(Vector3.UP, deg_to_rad(Globals.rng.randi_range(0, 360)))
		
		add_child(bottle)
