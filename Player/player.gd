extends CharacterBody3D

class_name Player

signal died
signal roll_requested(player: Player)
signal roll_result_recieved
signal action_queue_set
signal kicked

@export var camera_controller : Marker3D
@export var projectile_scene : PackedScene
@export var reticle_highlight_color: Color
@export var reticle_base_color: Color

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
const DODGE_DIRECTION_DEFAULT = Vector2.DOWN

var target_change_threshold = 100 * Globals.mouse_sensitivity

var camera_y: float

var state = states.MOVING

@export var max_health = 5
var health = max_health
var melee_damage = MELEE_DAMAGE_BASE

var max_stamina = 100
var stamina_use_rate = -10 # Amount per second
var stamina_regen_rate = 10 # Amount per second
var stamina = max_stamina

var roll_fail_upper_threshold = 3 # 2-3, ~8.33% chance to fail
var roll_pass_upper_threshold = 9 # 4-9, ~75% chance to pass; 10-12, ~16.67 chance to critical success

var targeted_times = 0
@export var health_bar_modulate: Color

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

var attack_target: CharacterBody3D

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
	#{"id": melee_attack_options.DAMAGE, "name": "Damage +1", "data": null},
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
var action_basis: Basis

var ranged_camera_offset = Vector3(.5, 0, .5)
var reticle_center

var ammo_holster: Node3D
@export var starting_ammo = 4
var has_ammo = false

var can_move = true
var can_melee = true
var can_throw = true

func _ready():
	health = max_health
	
	# Make sure the player has the assigned number of donuts
	ammo_holster = $Armature/Skeleton3D/BoneAttachment3D/AmmunitionMount
	has_ammo = starting_ammo > 0
	set_ammo(starting_ammo)
	
	camera_y = camera_controller.global_position.y
	animation_tree = $AnimationTree
	animation_state = animation_tree.get("parameters/playback")
	
	$HealthBarView/CountingBar.initialize(health)
	$Abilities/Run/StaminaBarView/CountingBar.initialize_with_text(max_stamina, "Stamina")

func _physics_process(delta):
	reticle_center = $Reticle/Label.global_position
	if state != states.ATTACKING and can_throw:
		_toggle_ranged(Input.is_action_pressed("aim_ranged"))
		
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
	if not is_on_floor():
		velocity.y -= gravity
	
	move_and_slide()
	if not running and state == states.MOVING:
		_change_stamina(stamina_regen_rate * delta)
	
	camera_controller.global_position = global_position.lerp(camera_controller.global_position, CAMERA_SMOOTHING)
	camera_controller.global_position.y = global_position.y + camera_y
	
	# Raycast from the center of the screen/camera to target enemies
	var camera = camera_controller.get_camera()
	var space_state = camera_controller.get_world_3d().direct_space_state
	var origin = camera.project_ray_origin(reticle_center)
	var end = origin + camera.project_ray_normal(reticle_center) * 1000
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	var result = space_state.intersect_ray(query)
	if not result.is_empty() and ((not ranged_mode and result.collider in melee_targets) or (ranged_mode and result.collider in ranged_targets)):
		_set_target(result.collider)
	else: # Get default melee target if available
		_get_new_target()

func move_state(delta):
	if Input.is_action_pressed("run"):
		if stamina > 10:
			running = true
	if not Input.is_action_pressed("run") || stamina <= 0:
		running = false
	
	var input_dir = Vector2.ZERO
	if can_move:
		input_dir = Input.get_vector("move_right", "move_left", "move_back", "move_forward")
	
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
	
	if ((can_melee and not ranged_mode) or (can_throw and ranged_mode)) and (Input.is_action_just_pressed("attack") or combo > 0) and target:
		attack_target = target
		state = states.ATTACKING
	else:
		combo = 0

func attack_state(delta):
	if $Abilities/Attack/AttackCooldownTimer.is_stopped():
		if attack_target:
			# Get the correct rotation for the attack
			var attack_position = transform.looking_at(Vector3(attack_target.global_position.x, transform.origin.y, attack_target.global_position.z), Vector3.UP, true).rotated_local(Vector3.UP, ATTACK_ANIMATION_ROTATION)
			if attack_target in melee_targets and animation_state.get_current_node() != "Throw":
				# Move toward the enemy if too far, move away if too close
				if attack_position.origin.distance_to(attack_target.transform.origin) > ATTACK_ANIMATION_DISTANCE:
					attack_position.origin = attack_position.origin.move_toward(attack_target.transform.origin * Vector3(1, 0, 1), delta * Globals.TURN_SPEED)
				if attack_position.origin.distance_to(attack_target.transform.origin) < ATTACK_ANIMATION_DISTANCE:
					attack_position.origin = attack_position.origin.move_toward(attack_target.transform.origin * Vector3(-1, 0, -1), delta * Globals.TURN_SPEED)
				
				animation_state.travel("Punch")
			elif attack_target in ranged_targets and animation_state.get_current_node() != "Punch" and animation_state.get_current_node() != "Throw":
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
	if blocking:
		on_block()
	else:
		damage = -abs(damage) # Make sure damage is negative
		_change_health(damage)
		$HitSound.play()
		if health > 0 and state != states.ATTACKING:
			state = states.HIT

func on_block():
	# Only do the blocking animation if in the moving state
	if $Abilities/Block/BlockTimer.time_left == 0 and state == states.MOVING:
		state = states.BLOCKING

# TODO: react to kicks from different angles
func on_knockback(stamina_damage):
	stamina_damage = -abs(stamina_damage) # Make sure stam damage is negative
	$KickedSound.play()
	if stamina >= -stamina_damage / 2:
		_change_stamina(stamina_damage)
	else:
		_change_health(-1)
	
	if health > 0:
		state = states.KNOCKBACK
	
	kicked.emit()

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
	$HealthBarView/CountingBar.set_bar_modulate(Color.CRIMSON)

func untargeted():
	targeted_times -= 1
	if targeted_times <= 0:
		$HealthBarView/CountingBar.set_bar_modulate(health_bar_modulate)
	
func attack_connects():
	if attack_target and attack_hit:
		attack_target.on_hit(melee_damage)
		melee_damage = MELEE_DAMAGE_BASE

func attack_check():
	if attack_target:
		if combo > 0:
			combo -= 1
			attack_hit = true
		else:
			action_basis = camera_controller.transform.basis
			cur_action_options = melee_options
			roll_requested.emit(self)
			await roll_result_recieved
			
			if latest_dice_roll <= roll_fail_upper_threshold:
				attack_hit = false
				attack_target.on_miss()
			else:
				attack_hit = true
				await action_queue_set
	
func _on_action_animation_finished(call_state):
	if call_state == states.keys()[state]:
		if call_state == states.keys()[states.DODGING]:
			_toggle_blocking(false)
		attack_hit = true
		# Process the options the cause an additional action to happen
		var action_processed = false
		while not action_queue.is_empty() and not action_processed:
			cur_action = action_queue.pop_front()
			match cur_action["id"]:
				melee_attack_options.COMBO:
					if target and target in melee_targets:
						combo += 1
						state = states.ATTACKING
						attack_target = target
						animation_state.travel("Punch")
						animation_state.start(animation_state.get_current_node(), true)
						action_processed = true
						return
				melee_attack_options.DODGE:
					dodge_direction = cur_action["data"]["direction"]
					if dodge_direction:
						# Rotate so we dodge in the desired direction
						# In this case, we need to invert the direction in the data due to 2d and 3d differences
						var dodge_rotation = action_basis.rotated(Vector3.UP, Vector2(-dodge_direction.y, -dodge_direction.x).angle())
						
						# Filter the dodge rotation so the player model only rotates around the y axis
						transform.basis = Basis(dodge_rotation.x * Vector3(1,0,1), Vector3.UP, dodge_rotation.z * Vector3(1,0,1)).orthonormalized()
						dodge_direction = null
					state = states.DODGING
					dodge_state()
					animation_state.start(animation_state.get_current_node(), true)
					action_processed = true
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

func _on_far_range_body_exited(body):
	if body in ranged_targets:
		ranged_targets.erase(body)

# Toggle ranged mode or not and take the first target that had entered the respective range
func _toggle_ranged(is_ranged):
	if not has_ammo:
		is_ranged = false
	if ranged_mode != is_ranged:
		ranged_mode = not ranged_mode
		_get_new_target()
		if ranged_mode:
			$Reticle.show()
			camera_controller.offset_camera(ranged_camera_offset)
		else:
			$Reticle.hide()
			camera_controller.offset_camera(-ranged_camera_offset)

func _set_target(new_target):
	if target:
		target.untargeted()
		$Reticle/Label.add_theme_color_override("font_color", reticle_base_color)
	target = new_target
	if target:
		target.targeted()
		$Reticle/Label.add_theme_color_override("font_color", reticle_highlight_color)

func _get_new_target():
	var new_target
	if not ranged_mode and not melee_targets.is_empty():
		new_target = melee_targets.back()
	else:
		new_target = null
	
	_set_target(new_target)

func throw_donut():
	if attack_target:
		if has_ammo:
			if ammo_holster.has_method("use_ammo"):
				ammo_holster.use_ammo()
			var right_hand_bone = $Armature/Skeleton3D.find_bone("mixamorig1_RightHand")
			var right_hand_bone_position = $Armature/Skeleton3D.global_transform * $Armature/Skeleton3D.get_bone_global_pose(right_hand_bone)
			var projectile = projectile_scene.instantiate()
			add_sibling(projectile)
			projectile.fire(1, 10, right_hand_bone_position.origin, attack_target)
	attack_target = null

func _change_stamina(stamina_change):
	stamina = clamp(stamina + stamina_change, 0, max_stamina)
	$Abilities/Run/StaminaBarView/CountingBar.set_value(stamina)

func _change_health(health_change):
	health = clamp(health + health_change, 0, max_health)
	$HealthBarView/CountingBar.set_value(health)
	if health <= 0:
		collision_layer = 0
		collision_mask = 1
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
		if blocking and $Abilities/Block/BlockTimer.time_left == 0:
			blocking = false
			$Abilities/Block/BlockView/BlockBackground.color = INACTIVE_COLOR

func _on_block_timer_timeout():
	_toggle_blocking(false)
	
func set_ammo(number: int):
	if ammo_holster.has_method("set_ammo"):
		ammo_holster.set_ammo(number)
	has_ammo = number > 0

func _on_ammo_depleted():
	has_ammo = false

func enable_movement():
	can_move = true

func disable_movement():
	can_move = false

func enable_melee():
	can_melee = true

func disable_melee():
	can_melee = false

func enable_ranged():
	can_throw = true

func disable_ranged():
	can_throw = false
