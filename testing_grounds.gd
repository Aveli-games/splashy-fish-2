extends Node

@export var enemy_scene: PackedScene
@export var bird_scene: PackedScene

var roll_requester
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("spawn_enemy"):
		# Create a new instance of the Enemy scene.
		var enemy = enemy_scene.instantiate()
		var bird = bird_scene.instantiate()

		# Choose a random location on the SpawnPath.
		# We store the reference to the SpawnLocation node.
		var enemy_spawn_location = get_node("SpawnPath/SpawnLocation")
		# And give it a random offset.
		enemy_spawn_location.progress_ratio = randf()

		# Assign the objective as the enemy's target 
		var objective = get_node("Objective")
		enemy.initialize(enemy_spawn_location.position, objective)
		bird.initialize(enemy_spawn_location.position, objective)

		# Spawn the enemy by adding it to the Main scene.
		add_child(enemy)
		add_child(bird)
		
		# We connect the mob's signal to give it a new target when none found.
		enemy.no_target_found.connect(_on_enemy_no_target_found.bind())

func _on_player_died():
	if get_tree():
		get_tree().reload_current_scene()

func _on_objective_died():
	if get_tree():
		get_tree().reload_current_scene()

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
