extends CharacterBody3D

class_name Player

const SPEED = 3.8
const JUMP_VELOCITY = 4.5

@export var sensitivity := 5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_right", "move_left", "move_back", "move_forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	$AnimationTree.set("parameters/conditions/idle", input_dir == Vector2.ZERO && is_on_floor())
	$AnimationTree.set("parameters/conditions/walk", input_dir != Vector2.ZERO && is_on_floor())
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x / 1000 * sensitivity)
