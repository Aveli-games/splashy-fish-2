extends Node

@export var enemy_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("spawn_enemy"):
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
		
		# We connect the mob to the score label to update the score upon squashing one.
		enemy.no_target_found.connect(_on_enemy_no_target_found.bind())

func _on_player_died():
	if get_tree():
		get_tree().reload_current_scene()

func _on_objective_died():
	if get_tree():
		get_tree().reload_current_scene()


	
func _on_enemy_no_target_found(enemy):
	enemy.set_target(get_node("Objective"))