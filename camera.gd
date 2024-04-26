extends SpringArm3D

@export var focus_point: Marker3D

@export var ZOOM_SPEED := 10

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	look_at(focus_point.global_position, Vector3.UP)
	if Input.is_action_just_pressed("zoom_in"):
		if global_position.distance_to(focus_point.global_position) > 1:
			global_position = global_position.move_toward(focus_point.global_position, ZOOM_SPEED * delta)
	elif Input.is_action_just_pressed("zoom_out"):
		if global_position.distance_to(focus_point.global_position) < 3:
			global_position = global_position.move_toward(focus_point.global_position, -ZOOM_SPEED * delta)
