extends CharacterBody3D

class_name Player

signal died

const WALK_SPEED = 1.6
const RUN_SPEED = WALK_SPEED * 2
const JUMP_VELOCITY = 4.5

@export var sensitivity := 5

var max_health = 5
var health = max_health
var melee_damage = 1

var max_stamina = 100
var stamina_use_rate = 10 # Amount per second
var stamina_regen_rate = 10 # Amount per second
var stamina = max_stamina

var targeted_times = 0
var health_bar_modulate

var running = false
var cur_speed = WALK_SPEED

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
	var speed = WALK_SPEED
	if health <= 0:
		die()
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	 # Can only run if you have stamina, need to not run for stamina to regen
	if Input.is_action_just_pressed("run"):
		if stamina > 10:
			running = true

	if Input.is_action_just_released("run") || stamina <= 0:
		running = false

	# Stamina use and regen triggered based on running status
	# TODO: Require X time from not running as "recovery" period to start regen 
	if running:
		stamina = clamp(stamina - stamina_use_rate * delta, 0, 100)
	else:
		stamina = clamp(stamina + stamina_regen_rate * delta, 0, 100)

	$Abilities/Run/StaminaBarView/StaminaBar.value = stamina

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

	set_motion(direction)
	
	if direction:
		velocity.x = direction.x * cur_speed
		velocity.z = direction.z * cur_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

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
		
func set_motion(direction):
	reset_animation()
	
	if direction == Vector3.ZERO:
		$AnimationTree.set("parameters/conditions/idle", is_on_floor())
	else:
		if running:
			cur_speed = RUN_SPEED
			$AnimationTree.set("parameters/conditions/run", is_on_floor())
		else:
			cur_speed = WALK_SPEED
			$AnimationTree.set("parameters/conditions/walk", is_on_floor())

func reset_animation():
	$AnimationTree.set("parameters/conditions/run", false)
	$AnimationTree.set("parameters/conditions/idle", false)
	$AnimationTree.set("parameters/conditions/walk", false)
