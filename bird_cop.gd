extends CharacterBody3D

const FLYING_HEIGHT = 3

var speed = 10

var target

func _ready():
	look_at(Vector3(target.global_position.x, FLYING_HEIGHT, target.global_position.z), Vector3.UP, false)
	pass

func _physics_process(delta):
	if velocity == Vector3.ZERO:
		velocity = -transform.basis.z.normalized() * speed

	move_and_slide()

	if global_position.distance_to(target.global_position) > 50:
		queue_free()

	# This function will be called from the Main scene.
func initialize(start_position, start_target):
	# We position the enemy by placing it at start_position
	position = start_position + Vector3(0,FLYING_HEIGHT,0)
	#add_to_group("Enemies")
	set_target(start_target)
	
func set_target(new_target):
	target = new_target
