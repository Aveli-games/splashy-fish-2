extends RigidBody3D

@export var spawn_raycast: RayCast3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Correct any spawning under floor
	spawn_raycast.force_raycast_update()
	if spawn_raycast.is_colliding():
		global_transform.origin.y += spawn_raycast.get_collision_point().y
	spawn_raycast.enabled = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
