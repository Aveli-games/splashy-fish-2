extends CharacterBody3D

class_name Player

signal died

enum states {
	MOVING = Globals.movement_states.MOVING,
	ATTACKING = Globals.movement_states.ATTACKING,
	HIT = Globals.movement_states.HIT,
	DYING = Globals.movement_states.DYING
}

const WALK_SPEED = 1.6
const RUN_SPEED = WALK_SPEED * 2
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 10
const ATTACK_ANIMATION_DISTANCE = 1.001
const ATTACK_ANIMATION_ROTATION = deg_to_rad(18.8)

@export var sensitivity := 5

var state = states.MOVING

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

var target: CharacterBody3D
var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var animation_tree
var animation_state

func _ready():
	animation_tree = $AnimationTree
	animation_state = animation_tree.get("parameters/playback")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_bar_modulate = $HealthBarView/HealthBar.modulate
	
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		states.MOVING:
			move_state(delta)
		states.ATTACKING:
			attack_state(delta)
		states.HIT:
			hit_state(delta)
		states.DYING:
			death_state(delta)
	
	if not running:
		stamina = clamp(stamina + stamina_regen_rate * delta, 0, 100)
	
	$Abilities/Run/StaminaBarView/StaminaBar.value = stamina

func _input(event):
	if event is InputEventMouseMotion && state == states.MOVING:
		rotate_y(-event.relative.x / 1000 * sensitivity)

func move_state(delta):
	if Input.is_action_pressed("run"):
		if stamina > 10:
			running = true
	if not Input.is_action_pressed("run") || stamina <= 0:
		running = false
	
	var input_dir = Input.get_vector("move_right", "move_left", "move_back", "move_forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if input_dir != Vector2.ZERO:
		if running:
			animation_tree.set("parameters/Run/blend_position", input_dir)
			animation_state.travel("Run")
			cur_speed = RUN_SPEED
			stamina = clamp(stamina - stamina_use_rate * delta, 0, 100)
		elif not running:
			animation_tree.set("parameters/Walk/blend_position", input_dir)
			animation_state.travel("Walk")
			cur_speed = WALK_SPEED
	else:
		running = false
		animation_state.travel("idle")
	
	if direction:
		velocity.x = direction.x * cur_speed
		velocity.z = direction.z * cur_speed
	else:
		velocity.x = move_toward(velocity.x, 0, cur_speed)
		velocity.z = move_toward(velocity.z, 0, cur_speed)

	move_and_slide()
	
	if Input.is_action_just_pressed("attack") && target:
		state = states.ATTACKING

func attack_state(delta):
	running = false
	if target:
		# Get the correct rotation for the punch attack
		var attack_position = transform.looking_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true).rotated_local(Vector3.UP, ATTACK_ANIMATION_ROTATION)
		
		# Move toward the enemy if too far, move away if too close
		if attack_position.origin.distance_to(target.transform.origin) > ATTACK_ANIMATION_DISTANCE:
			attack_position.origin = attack_position.origin.move_toward(target.transform.origin, delta * TURN_SPEED)
		if attack_position.origin.distance_to(target.transform.origin) < ATTACK_ANIMATION_DISTANCE:
			attack_position.origin = attack_position.origin.move_toward(target.transform.origin * Vector3(-1, 0, -1), delta * TURN_SPEED)
		
		# Apply everything
		transform = transform.interpolate_with(attack_position, delta * TURN_SPEED)
		
	if $Abilities/Attack/AttackCooldownTimer.is_stopped():
		animation_state.travel("Attack")

func hit_state(delta):
	running = false
	animation_state.travel("Hit")

func death_state(delta):
	running = false
	animation_state.travel("Die")

func on_hit(damage):
	health = clamp(health - damage, 0, max_health)
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health
	if health > 0:
		state = states.HIT
	else:
		$CollisionShape3D.queue_free()
		state = states.DYING

func _on_melee_range_body_entered(body):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if body not in melee_targets && body in enemies:
		melee_targets.append(body)
		if not target:
			target = body

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)
		if body == target:
			if not melee_targets.is_empty():
				target = melee_targets[0]
			else:
				target = null

func targeted():
	targeted_times += 1
	$HealthBarView/HealthBar.set_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/HealthBar.set_modulate(health_bar_modulate)
	
func attack_connects():
	if target:
		target.on_hit(melee_damage)
	
func _on_action_animation_finished():
	state = states.MOVING
	
func _on_death_animation_finished():
	died.emit()
