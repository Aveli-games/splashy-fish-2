extends Marker3D

@export var sensitivity := 0.25

var mouse_position = Vector2.ZERO
var total_pitch = 0.0
var mouse_control = true

func _process(delta):
	transform.basis = transform.basis.orthonormalized()

func _input(event):
	if mouse_control and event is InputEventMouseMotion:
		mouse_position = event.relative * sensitivity
		var yaw = mouse_position.x
		var pitch = -mouse_position.y
		mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -45 - total_pitch, 75 - total_pitch)
		total_pitch += pitch
	
		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg_to_rad(-pitch))

func toggle_mouse_control(is_mouse_controlled):
	if mouse_control != is_mouse_controlled:
		mouse_control = not mouse_control
