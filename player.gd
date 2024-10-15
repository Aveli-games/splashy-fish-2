extends CharacterBody3D

class_name Player

signal died
signal roll_requested(player: Player)
signal roll_result_recieved
signal action_queue_set

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
const ATTACK_ANIMATION_DISTANCE = 1.001
const ATTACK_ANIMATION_ROTATION = deg_to_rad(18.8)
const CAMERA_SMOOTHING = .85
const ACTIVE_COLOR = Color("#2bff0071")
const INACTIVE_COLOR = Color("#ffffff71")
const MELEE_DAMAGE_BASE = 1
const DODGE_DIRECTION_DEFAULT = Vector3.BACK

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

var roll_fail_upper_threshold = 3 # 2-3, ~8.33% chance to fail
var roll_pass_upper_threshold = 9 # 4-9, ~75% chance to pass; 10-12, ~16.67 chance to critical success

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

var throw_target = CharacterBody3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var animation_tree
var animation_state

var latest_dice_roll = 0
var cur_action_options = []
var cur_action = {"id": null, "name": "", "data": null}
var melee_options = [
	{"id": melee_attack_options.BLOCK, "name": "Block +1", "data": null},
	{"id": melee_attack_options.RECOVER, "name": "Recover stamina", "data": null},
	{"id": melee_attack_options.DAMAGE, "name": "Damage +1", "data": null},
	{"id": melee_attack_options.COMBO, "name": "Combo +1", "data": null},
	{
		"id": melee_attack_options.DODGE,
		"name": "Dodge", 
		"data": {
			"title": "Choose direction",
			"type": Globals.interface_types.DIRECTION,
			"direction": DODGE_DIRECTION_DEFAULT
		}
	}
]

var combo = 0

var action_queue = []

var dodge_direction = DODGE_DIRECTION_DEFAULT

var ranged_camera_offset = Vector3(.5, 0, .5)
var screen_center

func _ready():
	screen_center = get_viewport().size / 2
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
	
	camera_controller.global_position = global_position.lerp(camera_controller.global_position, CAMERA_SMOOTHING)
	camera_controller.global_position.y = camera_y
	if ranged_mode:
		var camera = camera_controller.get_camera()
		var space_state = camera_controller.get_world_3d().direct_space_state
		var origin = camera.project_ray_origin(screen_center)
		var end = origin + camera.project_ray_normal(screen_center) * 1000
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_bodies = true
		query.collision_mask = collision_mask
		var result = space_state.intersect_ray(query)
		if not result.is_empty() and result.collider in ranged_targets:
			_set_target(result.collider)
		else:
			_get_new_target()

func move_state(delta):
	if Input.is_action_pressed("run"):
		if stamina > 10:
			running = true
	if not Input.is_action_pressed("run") || stamina <= 0:
		running = false
	
	var input_dir = Input.get_vector("move_right", "move_left", "move_back", "move_forward")
	
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
		var new_basis = camera_basis_filtered.rotated(Vector3.UP, Vector2(input_dir.y, input_dir.x).angle()).orthonormalized()
		transform.basis = transform.basis.slerp(new_basis, delta * Globals.TURN_SPEED)
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
					attack_position.origin = attack_position.origin.move_toward(target.transform.origin * Vector3(1, 0, 1), delta * Globals.TURN_SPEED)
				if attack_position.origin.distance_to(target.transform.origin) < ATTACK_ANIMATION_DISTANCE:
					attack_position.origin = attack_position.origin.move_toward(target.transform.origin * Vector3(-1, 0, -1), delta * Globals.TURN_SPEED)
				
				animation_state.travel("Punch")
			elif target in ranged_targets and animation_state.get_current_node() != "Punch" and animation_state.get_current_node() != "Throw":
				throw_target = target
				animation_state.travel("Throw")
			
			# Apply everything
			transform = transform.interpolate_with(attack_position, delta * Globals.TURN_SPEED)
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
	if $Abilities/Block/BlockTimer.time_left == 0:
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
			
			if latest_dice_roll <= roll_fail_upper_threshold:
				attack_hit = false
				if attack_target:
					attack_target.on_miss()
			else:
				attack_hit = true
				await action_queue_set
	
func _on_action_animation_finished(call_state):
	if call_state == states.keys()[state]:
		attack_hit = true
		# Process the options the cause an additional action to happen
		if not action_queue.is_empty():
			cur_action = action_queue.pop_front()
			match cur_action["id"]:
				melee_attack_options.COMBO:
					if target:
						combo += 1
						state = states.ATTACKING
						animation_state.travel("Punch")
						animation_state.start(animation_state.get_current_node(), true)
						return
				melee_attack_options.DODGE:
					dodge_direction = cur_action["data"]["direction"]
					if dodge_direction:
						# Rotate so we dodge in the desired direction
						# In this case, we need to invert the direction in the data due to 2d and 3d differences
						transform = transform.rotated_local(Vector3.UP, Vector2(-dodge_direction.z, -dodge_direction.x).angle())
						print("Dodge direction = ", dodge_direction)
						dodge_direction = null
					state = states.DODGING
					dodge_state()
					animation_state.start(animation_state.get_current_node(), true)
					return
					
		state = states.MOVING
	
func _on_death_animation_finished():
	died.emit()

func set_roll_result(value: int):
	latest_dice_roll = value
	roll_result_recieved.emit()
	if latest_dice_roll <= roll_fail_upper_threshold: # Fail - no actions
		return Globals.roll_result_types.FAIL
	elif latest_dice_roll <= roll_pass_upper_threshold: # Success - choose 1 action
		return Globals.roll_result_types.SUCCESS
	else: # Critical success - choose 2 actions
		return Globals.roll_result_types.CRITICAL
	
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
	_toggle_blocking(true)
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
		if is_ranged:
			$Reticle.show()
			camera_controller.offset_camera(ranged_camera_offset)
		else:
			$Reticle.hide()
			camera_controller.offset_camera(-ranged_camera_offset)

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
	else:
		new_target = null
	
	_set_target(new_target)

func throw_donut():
	if throw_target:
		var right_hand_bone = $Armature/Skeleton3D.find_bone("mixamorig1_RightHand")
		var right_hand_bone_position = $Armature/Skeleton3D.global_transform * $Armature/Skeleton3D.get_bone_global_pose(right_hand_bone)
		var projectile = projectile_scene.instantiate()
		add_sibling(projectile)
		projectile.fire(1, 10, right_hand_bone_position.origin, throw_target)
	throw_target = null

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

func set_action_queue(new_action_queue: Array):
	action_queue = new_action_queue
	for i in action_queue.size():
		var action = action_queue[i-1]
		match action["id"]:
			melee_attack_options.BLOCK:
				_toggle_blocking(true)
				$Abilities/Block/BlockTimer.start()
				new_action_queue.erase(action)
			melee_attack_options.RECOVER:
				_change_stamina(40)
				new_action_queue.erase(action)
			melee_attack_options.DAMAGE:
				if target:
					melee_damage += 1
				new_action_queue.erase(action)
	action_queue = new_action_queue
	action_queue_set.emit()

func _toggle_blocking(is_blocking: bool):
	if is_blocking:
		if not blocking:
			blocking = true
			$Abilities/Block/BlockView/BlockBackground.color = ACTIVE_COLOR
	else:
		if blocking and $Abilities/Block/BlockTimer.time_left == 0 and state != states.DODGING:
			blocking = false
			$Abilities/Block/BlockView/BlockBackground.color = INACTIVE_COLOR

func _on_block_timer_timeout():
	_toggle_blocking(false)
