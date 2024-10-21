extends RigidBody3D

signal roll_finished(value: int)

var start_pos
@export var roll_strength = 30

var is_rolling = false

var raycasts: Array[RayCast3D]

func _ready():
	start_pos = global_position
	for side in $Sides.get_children():
		for node in side.get_children():
			if node is RayCast3D:
				raycasts.append(node)

func roll():
	sleeping = false
	
	global_position = start_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	transform.basis *= Basis(Vector3.RIGHT, randf_range(0, 2 * PI))
	transform.basis *= Basis(Vector3.UP, randf_range(0, 2 * PI))
	transform.basis *= Basis(Vector3.FORWARD, randf_range(0, 2 * PI))
	
	var throw_vector = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	angular_velocity = throw_vector * roll_strength / 2
	apply_central_impulse(throw_vector * roll_strength)
	is_rolling = true
	$RollTimer.start()
	
func _input(event):
	if event.is_action_pressed("ui_accept") && not is_rolling:
		roll()

func _on_sleeping_state_changed():
	if sleeping:
		var landed_on_side = false
		for raycast in raycasts:
			if raycast.is_colliding():
				roll_finished.emit(raycast.opposite_side)
				is_rolling = false
				landed_on_side = true
		
		if not landed_on_side:
			roll()

func _on_roll_timer_timeout():
	if is_rolling:
		roll()
