extends Level

signal tutorial_completed

var tutorial_complete = false

func _process(delta):
	if tutorial_complete and num_enemies <= 0 and get_tree().get_nodes_in_group("Enemies").size() == 0:
		game_ended = true
		won.emit()

func fight_one_hundred_enemies():
	$Player.add_to_group("PlayerTargets")
	$Player.set_ammo(1000)
	
	num_enemies = 100
	max_enemy_group = 1
	spawn_enemy(1)
	$EnemySpawnTimer.start()
	
	tutorial_complete = true

func _on_dummy_enemy_died():
	tutorial_completed.emit()
