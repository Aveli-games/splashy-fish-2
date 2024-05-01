extends RigidBody3D

var start_pos
@export var roll_strength = 30

func _ready():
	start_pos = global_position

func roll():
	global_position = start_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	transform.basis *= Basis(Vector3.RIGHT, randf_range(0, 2 * PI))
	transform.basis *= Basis(Vector3.UP, randf_range(0, 2 * PI))
	transform.basis *= Basis(Vector3.FORWARD, randf_range(0, 2 * PI))
	
	var throw_vector = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	angular_velocity = throw_vector * roll_strength / 2
	apply_central_impulse(throw_vector * roll_strength)
	
func _input(event):
	if event.is_action_pressed("ui_accept"):
		roll()
