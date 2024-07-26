extends Node

@export var enemy_scene: PackedScene

var roll_requester

# Called when the node enters the scene tree for the first time.
func _ready():
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("Splashy")
	for tree_line in $Boundaries/TreeLines.get_children():
		for tree in tree_line.get_children():
			var tree_scale = rng.randf_range(2.4, 5)
			tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
			tree.position.x = rng.randi_range(-25, -15)

func _on_player_died():
	if get_tree():
		get_tree().reload_current_scene()

func _on_objective_died():
	if get_tree():
		get_tree().reload_current_scene()

func _on_enemy_spawn_timer_timeout():
	if $Player && $Player.process_mode != PROCESS_MODE_DISABLED:
		# Create a new instance of the Enemy scene.
		var enemy = enemy_scene.instantiate()

		# Choose a random location on the SpawnPath.
		# We store the reference to the SpawnLocation node.
		var enemy_spawn_location = get_node("SpawnPath/SpawnLocation")
		# And give it a random offset.
		enemy_spawn_location.progress_ratio = randf()

		# Assign the objective as the enemy's target 
		var objective = get_node("Objective")
		enemy.initialize(enemy_spawn_location.position, objective)

		# Spawn the enemy by adding it to the Main scene.
		add_child(enemy)
		
		# We connect the enemy to the no target found signal so the level can assign the default
		enemy.no_target_found.connect(_on_enemy_no_target_found.bind())
	
func _on_enemy_no_target_found(enemy):
	enemy.set_target(get_node("Objective"))

func _on_player_roll_requested(player):
	# Speed up time while rolling so the simulation goes quick
	# TODO: Add "Dice roll speed" setting in future options menu
	get_tree().set_group_flags(0, "RollPause", "process_mode", PROCESS_MODE_DISABLED)
	Engine.time_scale = 3
	$DiceRollCanvas.show()
	roll_requester = player
	$DiceRollCanvas/DiceRollViewport.roll()

func _on_roll_finished(value):
	# Return time to normal speed
	Engine.time_scale = 1
	await get_tree().create_timer(.75).timeout # Give time for player to understand result
	get_tree().set_group_flags(0, "RollPause", "process_mode", PROCESS_MODE_ALWAYS)
	if roll_requester and roll_requester.has_method("set_roll_result"):
		roll_requester.set_roll_result(value)
		roll_requester = null
	$DiceRollCanvas.hide()