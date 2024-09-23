extends CharacterBody3D

class_name Player

signal died
signal roll_requested(player: Player)
signal roll_result_recieved
signal action_option_chosen

@export var camera_controller : Marker3D
@export var projectile_scene : PackedScene

enum states {
	MOVING = Globals.movement_states.MOVING,
	ATTACKING = Globals.movement_states.ATTACKING,
	HIT = Globals.movement_states.HIT,
	DYING = Globals.movement_states.DYING,
	BLOCKING = Globals.movement_states.BLOCKING,
	KNOCKBACK = Globals.movement_states.KNOCKBACK,
	KICKING = Globals.movement_states.KICKING,
	DODGING = Globals.movement_states.DODGING
}

enum melee_attack_options {
	BLOCK,
	RECOVER,
	DAMAGE,
	COMBO,
	DODGE
}

const WALK_SPEED = 1.6
const RUN_SPEED = WALK_SPEED * 2
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 10
const ATTACK_ANIMATION_DISTANCE = 1.001
const ATTACK_ANIMATION_ROTATION = deg_to_rad(18.8)
const CAMERA_SMOOTHING = .85
const ACTIVE_COLOR = Color("#2bff0071")
const INACTIVE_COLOR = Color("#ffffff71")
const MELEE_DAMAGE_BASE = 1

var target_change_threshold = 100 * Globals.mouse_sensitivity

var camera_y: float

var state = states.MOVING

var max_health = 5
var health = max_health
var melee_damage = MELEE_DAMAGE_BASE

var max_stamina = 100
var stamina_use_rate = -10 # Amount per second
var stamina_regen_rate = 10 # Amount per second
var stamina = max_stamina

var roll_fail_threshold = 4 #~9% chance to fail

var targeted_times = 0
var health_bar_modulate

var running = false
var cur_speed = WALK_SPEED

var blocking = false

var ranged_mode = false
var ranged_target_change = 0

var attack_hit = true

var target: CharacterBody3D
var close_targets: Array
var melee_targets: Array
var ranged_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var animation_tree
var animation_state

var latest_dice_roll = 0
var cur_action_options = {}
var cur_chosen_action = {"number": null, "name": ""}
var melee_options = {
	melee_attack_options.BLOCK: "Block +1",
	melee_attack_options.RECOVER: "Recover stamina",
	melee_attack_options.DAMAGE: "Damage +1",
	melee_attack_options.COMBO: "Combo +1",
	melee_attack_options.DODGE: "Dodge"
}

var combo = 0

var action_queue = []

func _ready():
	camera_y = camera_controller.global_position.y
	animation_tree = $AnimationTree
	animation_state = animation_tree.get("parameters/playback")
	health_bar_modulate = $HealthBarView/HealthBar.modulate
	
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	if state != states.ATTACKING:
		_toggle_ranged(Input.is_action_pressed("aim_ranged"))
	
	_toggle_blocking(Input.is_action_pressed("block") and state != states.KNOCKBACK)
	
	match state:
		states.MOVING:
			move_state(delta)
		states.ATTACKING:
			attack_state(delta)
		states.BLOCKING:
			block_state()
		states.KNOCKBACK:
			knockback_state()
		states.HIT:
			hit_state()
		states.DODGING:
			dodge_state()
		states.DYING:
			death_state()
	
	var current_rotation = transform.basis.get_rotation_quaternion()
	velocity = (current_rotation.normalized() * $AnimationTree.get_root_motion_position()) / delta
	
	# Add gravity if necessary
	# TODO: Figure out how to apply gravity if ABOVE floor
	if is_on_floor() or state == states.DYING:
		velocity.y = 0
	else:
		velocity.y -= gravity * delta
	
	move_and_slide()
	if not running and state == states.MOVING:
		_change_stamina(stamina_regen_rate * delta)
	
	camera_controller.toggle_mouse_control(not (ranged_mode and target and target in ranged_targets))
	camera_controller.global_position = global_position.lerp(camera_controller.global_position, CAMERA_SMOOTHING)
	camera_controller.global_position.y = camera_y

func move_state(delta):
	if Input.is_action_pressed("run"):
		if stamina > 10:
			running = true
	if not Input.is_action_pressed("run") || stamina <= 0:
		running = false
	
	var input_dir = Input.get_vector("move_right", "move_left", "move_back", "move_forward")
	
	if ranged_mode and target and target in ranged_targets:
		camera_controller.transform.basis = camera_controller.transform.basis.slerp(transform.looking_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true).basis, delta * TURN_SPEED) 
	
	if input_dir != Vector2.ZERO:
		if running:
			animation_tree.set("parameters/Run/Run/blend_position", input_dir)
			animation_state.travel("Run")
			cur_speed = RUN_SPEED
			_change_stamina(stamina_use_rate * delta)
		elif not running:
			animation_tree.set("parameters/Walk/blend_position", input_dir)
			animation_state.travel("Walk")
			cur_speed = WALK_SPEED
		
		# Have player move smoothly to line up with camera
		var camera_basis_filtered = Basis(camera_controller.transform.basis.x * Vector3(1,0,1), Vector3(0,1,0), camera_controller.transform.basis.z * Vector3(1,0,1))
		transform.basis = transform.basis.slerp(camera_basis_filtered.orthonormalized(), delta * TURN_SPEED/3)
	else:
		running = false
		animation_state.travel("idle")
		velocity.x = move_toward(velocity.x, 0, cur_speed)
		velocity.z = move_toward(velocity.z, 0, cur_speed)
	
	if (Input.is_action_just_pressed("attack") or combo > 0) and target:
		state = states.ATTACKING
	else:
		combo = 0

func attack_state(delta):
	if $Abilities/Attack/AttackCooldownTimer.is_stopped():
		if target:
			# Get the correct rotation for the attack
			var attack_position = transform.looking_at(Vector3(target.global_position.x, 0, target.global_position.z), Vector3.UP, true).rotated_local(Vector3.UP, ATTACK_ANIMATION_ROTATION)
			if target in melee_targets and animation_state.get_current_node() != "Throw":
				# Move toward the enemy if too far, move away if too close
				if attack_position.origin.distance_to(target.transform.origin) > ATTACK_ANIMATION_DISTANCE:
					attack_position.origin = attack_position.origin.move_toward(target.transform.origin * Vector3(1, 0, 1), delta * TURN_SPEED)
				if attack_position.origin.distance_to(target.transform.origin) < ATTACK_ANIMATION_DISTANCE:
					attack_position.origin = attack_position.origin.move_toward(target.transform.origin * Vector3(-1, 0, -1), delta * TURN_SPEED)
				
				animation_state.travel("Punch")
			elif target in ranged_targets and animation_state.get_current_node() != "Punch":
				animation_state.travel("Throw")
			
			# Apply everything
			transform = transform.interpolate_with(attack_position, delta * TURN_SPEED)
			running = false

func hit_state():
	running = false
	animation_state.travel("Hit")

func death_state():
	running = false
	animation_state.travel("Die")

func on_hit(damage):
	damage = -abs(damage) # Make sure damage is negative
	_change_health(damage)
	if health > 0 and state != states.ATTACKING:
		state = states.HIT

func on_block():
	state = states.BLOCKING

# TODO: react to kicks from different angles
func on_knockback(stamina_damage):
	stamina_damage = -abs(stamina_damage) # Make sure stam damage is negative
	if stamina >= -stamina_damage / 2:
		_change_stamina(stamina_damage)
	else:
		_change_health(-1)
	
	if health > 0:
		state = states.KNOCKBACK

func _on_melee_range_body_entered(body):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if body not in melee_targets && body in enemies:
		melee_targets.append(body)
		if not target and not ranged_mode:
			_set_target(body)

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)
		if body == target:
			_get_new_target()

func targeted():
	targeted_times += 1
	$HealthBarView/HealthBar.set_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/HealthBar.set_modulate(health_bar_modulate)
	
func attack_connects():
	if target in melee_targets && attack_hit:
		target.on_hit(melee_damage)
		melee_damage = MELEE_DAMAGE_BASE

func attack_check():
	if target in melee_targets:
		if combo > 0:
			combo -= 1
			attack_hit = true
		else:
			cur_action_options = melee_options
			var attack_target = target
			roll_requested.emit(self)
			await roll_result_recieved
			
			if latest_dice_roll <= roll_fail_threshold:
				attack_hit = false
				if attack_target:
					attack_target.on_miss()
			else:
				attack_hit = true
				await action_option_chosen
				match melee_options.find_key(cur_chosen_action["name"]):
					melee_attack_options.BLOCK:
						_toggle_blocking(true)
						$Abilities/Block/BlockTimer.start()
					melee_attack_options.RECOVER:
						_change_stamina(40)
					melee_attack_options.DAMAGE:
						melee_damage + 1
					melee_attack_options.COMBO:
						combo = 2
					melee_attack_options.DODGE:
						action_queue.append(states.DODGING)
	
func _on_action_animation_finished(call_state):
	if call_state == states.keys()[state]:
		if state == states.ATTACKING and target and combo > 0:
			animation_state.start(animation_state.get_current_node(), true)
			return
		
		attack_hit = true
		
		if not action_queue.is_empty():
			state = action_queue.pop_front()
		else:
			state = states.MOVING
	
func _on_death_animation_finished():
	died.emit()

func set_roll_result(value: int):
	latest_dice_roll = value
	roll_result_recieved.emit()
	if latest_dice_roll <= roll_fail_threshold:
		return false
	else:
		return true
	
func block_state():
	running = false
	animation_state.travel("Block")

func is_blocking():
	return blocking

func knockback_state():
	running = false
	animation_state.travel("Knockback")

func dodge_state():
	running = false
	animation_state.travel("Dodge")
	
func is_invulnerable():
	if state == states.KNOCKBACK:
		return true
	return false

func _on_far_range_body_entered(body):
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if body not in ranged_targets && body in enemies:
		ranged_targets.append(body)
		if not target and ranged_mode:
			_set_target(body)

func _on_far_range_body_exited(body):
	if body in ranged_targets:
		ranged_targets.erase(body)
	if body == target:
		_get_new_target()

# Toggle ranged mode or not and take the first target that had entered the respective range
func _toggle_ranged(is_ranged):
	if ranged_mode != is_ranged:
		ranged_mode = not ranged_mode
		_get_new_target()

func _set_target(new_target):
	if target:
		target.untargeted()
	target = new_target
	if target:
		target.targeted()

func _get_new_target():
	var new_target
	if not ranged_mode and not melee_targets.is_empty():
		new_target = melee_targets[0]
	elif ranged_mode and not ranged_targets.is_empty():
		new_target = ranged_targets[0]
	else:
		new_target = null
	
	_set_target(new_target)

func _input(event):
	if event is InputEventMouseMotion:
		# TODO: Update this to cycle through possible targets from left to right,
			#       rather than in the order that they entered the ranged_targets array
		if ranged_mode and animation_state.get_current_node() != "Throw" and target and target in ranged_targets:
			ranged_target_change += event.relative.x
			if ranged_target_change >= target_change_threshold:
				ranged_target_change = 0
				if target == ranged_targets.back():
					_set_target(ranged_targets.front())
				else:
					_set_target(ranged_targets[ranged_targets.find(target) + 1])
			elif -ranged_target_change >= target_change_threshold:
				ranged_target_change = 0
				if target == ranged_targets.front():
					_set_target(ranged_targets.back())
				else:
					_set_target(ranged_targets[ranged_targets.find(target) - 1])
		else:
			ranged_target_change = 0

func throw_donut():
	if target and target in ranged_targets:
		var right_hand_bone = $Armature/Skeleton3D.find_bone("mixamorig1_RightHand")
		var right_hand_bone_position = $Armature/Skeleton3D.global_transform * $Armature/Skeleton3D.get_bone_global_pose(right_hand_bone)
		var projectile = projectile_scene.instantiate()
		add_sibling(projectile)
		projectile.fire(1, 10, right_hand_bone_position.origin, target)

func _change_stamina(stamina_change):
	stamina = clamp(stamina + stamina_change, 0, max_stamina)
	$Abilities/Run/StaminaBarView/StaminaBar.value = stamina

func _change_health(health_change):
	health = clamp(health + health_change, 0, max_health)
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health
	if health <= 0:
		$CollisionShape3D.queue_free()
		state = states.DYING

func get_action_options():
	return cur_action_options

func set_action_choice(number: int, label: String):
	cur_chosen_action["number"] = number
	cur_chosen_action["name"] = label
	action_option_chosen.emit()

func _toggle_blocking(is_blocking: bool):
	if is_blocking:
		if not blocking:
			blocking = true
			$Abilities/Block/BlockView/BlockBackground.color = ACTIVE_COLOR
	else:
		if blocking and $Abilities/Block/BlockTimer.time_left == 0:
			blocking = false
			$Abilities/Block/BlockView/BlockBackground.color = INACTIVE_COLOR

func _on_block_timer_timeout():
	_toggle_blocking(false)
