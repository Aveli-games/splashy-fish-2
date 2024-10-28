extends Node3D

@export var spawn_raycasts: Array[RayCast3D]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func snap_to_ground():
	# Correct any spawning under or above floor
	var spawn_corrected = false
	for spawn_raycast in spawn_raycasts:
		spawn_raycast.force_raycast_update()
		if not spawn_corrected and spawn_raycast.is_colliding():
			global_transform.origin.y = spawn_raycast.get_collision_point().y
			spawn_corrected = true
		spawn_raycast.enabled = false
