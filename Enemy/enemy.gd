extends CharacterBody3D

signal no_target_found
signal died

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

var target : Node3D

const SPEED = 1.2
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 6

var state = states.MOVING

@export var max_health = 1

var health = max_health
var melee_damage = 1
var kick_stamina_damage = 40

var close_targets: Array
var melee_targets: Array

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var animation_tree
var animation_state

var attack_hit = false

var obstacle_avoid_angle = 0
var obstacles_colliding = []

func _ready():
	health = max_health
	
	animation_tree = $AnimationTree
	animation_state = animation_tree.get("parameters/playback")
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.max_value = max_health
	$HealthBarView/HealthBar.value = health

func _physics_process(delta):
	# Use raycast to cehck if below the ground after spawning, then disable it
	if $RayCast3D.is_colliding():
		global_transform.origin = $RayCast3D.get_collision_point()
		$RayCast3D.enabled = false
	else:
		match state:
			states.MOVING:
				move_state()
			states.ATTACKING:
				attack_state(delta)
			states.HIT:
				hit_state()
			states.DYING:
				death_state()
			states.BLOCKING:
				block_state()
			states.KICKING:
				kick_state()
		
		if obstacles_colliding.size() > 0:
			obstacle_avoid_angle = clamp(obstacle_avoid_angle + Globals.TURN_SPEED * delta / 5, deg_to_rad(0), deg_to_rad(180))
		else:
			obstacle_avoid_angle = clamp(obstacle_avoid_angle - Globals.TURN_SPEED * delta / 5, deg_to_rad(0), deg_to_rad(180))
		
		transform.basis = transform.basis.rotated(Vector3.UP, obstacle_avoid_angle)
		
		var current_rotation = transform.basis.get_rotation_quaternion()
		velocity = (current_rotation.normalized() * $AnimationTree.get_root_motion_position()) / delta
		
		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity
		move_and_slide()

# This function will be called from the Main scene.
func initialize(start_position, start_target):
	# We position the enemy by placing it at start_position
	position = start_position
	add_to_group("Enemies")
	set_target(start_target)
	
func move_state():
	if target:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true)
		
		if target not in close_targets:
			animation_state.travel("Walk")
		else:
			animation_state.travel("idle")
		
		if target in melee_targets:
			if not target.has_method("is_invulnerable") or not target.is_invulnerable():
				state = states.ATTACKING
	else:
		animation_state.travel("idle")

func attack_state(delta):
	transform = transform.interpolate_with(transform.looking_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP, true), delta * TURN_SPEED)
	animation_state.travel("Attack")

func hit_state():
	animation_state.travel("Hit")

func death_state():
	animation_state.travel("Die")

func block_state():
	animation_state.travel("Block")

func kick_state():
	animation_state.travel("Kick")

func attack(atk_target):
	velocity = Vector3.ZERO
	atk_target.on_hit(melee_damage)

func kick(atk_target):
	velocity = Vector3.ZERO
	atk_target.on_knockback(kick_stamina_damage)

# TODO: Redo the logic in this script to simply inform the target it is taking an attack
#          The target should be what determines its reaction to the attack and report to this entity how it reacted, if necessary
func attack_check():
	attack_hit = false
	if target.has_method("is_blocking") and target.is_blocking():
		target.on_block()
	else:
		attack_hit = true

func _on_melee_range_body_entered(body):
	var player_targets = get_tree().get_nodes_in_group("PlayerTargets")
	if body not in melee_targets && body in player_targets:
		melee_targets.append(body)
		if body is Player:
			set_target(body)
		if body == target && body.has_method("targeted"):
			body.targeted()

func _on_melee_range_body_exited(body):
	if body in melee_targets:
		melee_targets.erase(body)
		if body == target && body.has_method("untargeted"):
			body.untargeted()
		
		# When current target leaves melee range, target the latest added melee target
		# If no available melee targets, signal that you have none
		# TODO: Add aggro range
		if melee_targets.is_empty():
			no_target_found.emit(self)
		else:
			if body == target:
				set_target(melee_targets.back())

func _on_close_range_body_entered(body):
	if body not in close_targets && body in get_tree().get_nodes_in_group("PlayerTargets"):
		close_targets.append(body)

func _on_close_range_body_exited(body):
	if body in close_targets:
		close_targets.erase(body)

func on_hit(damage):
	health = clamp(health - damage, 0, max_health)
	$HealthBarView/HealthLabel.text = str(health)
	$HealthBarView/HealthBar.value = health
	if health > 0:
		if state == states.HIT:
			animation_state.start(animation_state.get_current_node(), true)
		state = states.HIT
	else:
		# Remove collision and info so it's just untargetable animation left
		collision_layer = 0
		collision_mask = 1
		$HealthBarSprite.hide()
		state = states.DYING

func on_miss():
	state = states.KICKING

func set_target(new_target):
	target = new_target

func attack_connects():
	if target in melee_targets and attack_hit:
		attack(target)
	attack_hit = false

func kick_connects():
	if target in melee_targets:
		kick(target)

func _on_action_animation_finished(call_state):
	if call_state == states.keys()[state]:
		state = states.MOVING

func _on_death_animation_finished():
	remove_from_group("Enemies")
	died.emit()

func get_targeting_position():
	return transform.origin + $TargetingPostion.transform.origin

func targeted():
	$Armature/Skeleton3D/HighlightMesh.show()

func untargeted():
	$Armature/Skeleton3D/HighlightMesh.hide()
	
func _on_wall_collider_body_entered(body):
	obstacles_colliding.append(body)

func _on_wall_collider_body_exited(body):
	obstacles_colliding.erase(body)
