extends CharacterBody3D

class_name Player

signal died

const SPEED = 1.6
const JUMP_VELOCITY = 4.5

@export var sensitivity := 5

var max_health = 5

var health = max_health
var melee_damage = 1

var targeted_times = 0
var health_bar_modulate

var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_bar_modulate = $HealthBarView/HealthBar.modulate
	
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	if health <= 0:
		die()
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("attack"):
		#TODO: Player selection of what enemy in range to target
		if not melee_targets.is_empty():
			attack(melee_targets[0])

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

func on_hit(damage):
	health = clamp(health - damage, 0, max_health)
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health

func die():
	died.emit()

func _on_melee_range_body_entered(body):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if body not in melee_targets && body in enemies:
		melee_targets.append(body)

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)
		
func attack(target):
	if $Abilities/Attack/AttackCooldownTimer.is_stopped():
		$Abilities/Attack.use()
		target.on_hit(melee_damage)

func targeted():
	targeted_times += 1
	$HealthBarView/HealthBar.set_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/HealthBar.set_modulate(health_bar_modulate)
