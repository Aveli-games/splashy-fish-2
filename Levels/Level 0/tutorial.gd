extends Level

signal tutorial_completed

var remaining_enemies = 0

var tutorial_complete = false

func _process(delta):
	if tutorial_complete and num_enemies <= 0 and get_tree().get_nodes_in_group("Enemies").size() == 0:
		game_ended = true
		won.emit()

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

func fight_one_hundred_enemies():
	$Player.add_to_group("PlayerTargets")
	$Player.set_ammo(1000)
	
	num_enemies = 100
	initialize_remaining_enemies(num_enemies)
	max_enemy_group = 1
	spawn_enemy(1)
	$EnemySpawnTimer.start()
	
	tutorial_complete = true

func _on_dummy_enemy_died():
	tutorial_completed.emit()
	
func initialize_remaining_enemies(number: int):
	remaining_enemies = number
	$RemainingEnemiesUI/RemainingEnemiesBar.initialize(remaining_enemies)
	$RemainingEnemiesUI.show()

func _on_enemy_died():
	remaining_enemies -= 1
	$RemainingEnemiesUI/RemainingEnemiesBar.set_value(remaining_enemies)
